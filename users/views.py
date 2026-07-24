import logging
import random
from datetime import timedelta
from urllib.parse import urlencode

from django.apps import apps
from django.conf import settings
from django.contrib.auth import get_user_model
from django.utils import timezone
from django.utils.decorators import method_decorator
from django.shortcuts import redirect, render
from django.urls import reverse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET
from rest_framework.authentication import TokenAuthentication
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import PhoneOTP
from .serializers import UserSerializer
from .telegram_oauth import (
    app_auth_redirect_url,
    app_scheme_redirect,
    build_authorization_url,
    decode_id_token,
    exchange_code_for_tokens,
    oauth_configured,
    parse_telegram_user_id,
    pop_oauth_state,
)
from .utils import (
    link_phone_login_to_telegram,
    resolve_telegram_user,
    send_osonsms,
    verify_telegram_login,
)

logger = logging.getLogger(__name__)
User = get_user_model()

OTP_EXPIRY_MINUTES = getattr(settings, 'OTP_EXPIRY_MINUTES', 5)
OTP_RATE_LIMIT_SECONDS = getattr(settings, 'OTP_RATE_LIMIT_SECONDS', 60)


def _normalize_phone(phone):
    return str(phone).replace(' ', '')


def _save_device_id(user, device_id):
    if not device_id:
        return
    device_id = str(device_id).strip()[:255]
    if device_id and user.device_id != device_id:
        user.device_id = device_id
        user.save(update_fields=['device_id'])


def _flatten_payload(data):
    flat = {}
    for key, value in data.items():
        if isinstance(value, list):
            flat[key] = value[0] if value else ''
        else:
            flat[key] = value
    return flat


@method_decorator(csrf_exempt, name='dispatch')
class SendCodeView(APIView):
    def post(self, request):
        phone = request.data.get('phone')
        if not phone:
            return Response({'error': 'Телефонро ворид кунед'}, status=400)

        phone = _normalize_phone(phone)
        demo_map = getattr(settings, 'DEMO_OTP_MAP', {})
        demo_mode = getattr(settings, 'DEMO_MODE', False)

        existing_otp = PhoneOTP.objects.filter(phone=phone).first()
        if existing_otp:
            elapsed = (timezone.now() - existing_otp.updated_at).total_seconds()
            if elapsed < OTP_RATE_LIMIT_SECONDS:
                retry_after = int(OTP_RATE_LIMIT_SECONDS - elapsed) + 1
                return Response(
                    {
                        'error': 'Лутфан пас аз чанд сония дубора кӯшиш кунед',
                        'retry_after': retry_after,
                    },
                    status=429,
                )

        if demo_mode and phone in demo_map:
            code = str(demo_map[phone])
        else:
            code = str(random.randint(1000, 9999))

        PhoneOTP.objects.update_or_create(phone=phone, defaults={'code': code})

        if demo_mode and phone in demo_map:
            response = {'message': 'Код фиристода шуд!', 'success': True}
            if getattr(settings, 'DEBUG', False):
                response['code'] = code
            return Response(response)

        sms_result = send_osonsms(phone, code)
        if not sms_result['success']:
            return Response(
                {
                    'error': sms_result['error'] or 'Ирсоли SMS ноком шуд',
                    'success': False,
                },
                status=502,
            )

        response = {'message': 'Код фиристода шуд!', 'success': True}
        if getattr(settings, 'DEBUG', False):
            response['code'] = code
        return Response(response)


@method_decorator(csrf_exempt, name='dispatch')
class VerifyCodeView(APIView):
    def post(self, request):
        phone = request.data.get('phone')
        code = request.data.get('code')

        if not phone or not code:
            return Response({'error': 'Маълумотро пурра ворид кунед'}, status=400)

        phone = _normalize_phone(phone)
        code = str(code).strip()

        try:
            otp_obj = PhoneOTP.objects.get(phone=phone)
        except PhoneOTP.DoesNotExist:
            return Response({'error': 'Код нодуруст аст'}, status=400)

        if otp_obj.updated_at < timezone.now() - timedelta(minutes=OTP_EXPIRY_MINUTES):
            return Response(
                {'error': 'Код кӯҳна шудааст, дубора фиристед'},
                status=400,
            )

        if otp_obj.code != code:
            return Response({'error': 'Код нодуруст аст'}, status=400)

        telegram_id = request.data.get('telegram_id')
        user, _ = link_phone_login_to_telegram(phone, telegram_id=telegram_id)
        _save_device_id(user, request.data.get('device_id'))

        TokenModel = apps.get_model('authtoken', 'Token')
        token, _ = TokenModel.objects.get_or_create(user=user)

        otp_obj.delete()

        return Response({'token': token.key, 'user_id': user.id})


def telegram_login_page(request):
    """Саҳифаи воридшавӣ — Telegram OIDC (oauth.telegram.org)."""
    return render(
        request,
        'users/telegram_login.html',
        {
            'oauth_ready': oauth_configured(),
            'error': request.GET.get('error'),
        },
    )


@require_GET
def telegram_oauth_start(request):
    if not oauth_configured():
        return redirect(
            reverse('telegram-login')
            + '?error=OAuth+танзим+нашудааст',
        )
    redirect_uri = getattr(settings, 'TELEGRAM_OAUTH_REDIRECT_URI', '').strip()
    device_id = request.GET.get('device_id', '')
    app_mode = request.GET.get('app') == '1'
    auth_url = build_authorization_url(
        redirect_uri=redirect_uri,
        device_id=device_id,
        app_mode=app_mode,
    )
    return redirect(auth_url)


@require_GET
def telegram_oauth_callback(request):
    error = request.GET.get('error')
    if error:
        return redirect(
            reverse('telegram-login') + f'?error={error}',
        )

    code = request.GET.get('code')
    state = request.GET.get('state')
    oauth_ctx = pop_oauth_state(state or '')
    if not code or not oauth_ctx:
        return redirect(
            reverse('telegram-login') + '?error=state+ё+code+нодуруст',
        )

    redirect_uri = getattr(settings, 'TELEGRAM_OAUTH_REDIRECT_URI', '').strip()
    try:
        tokens = exchange_code_for_tokens(
            code=code,
            verifier=oauth_ctx['verifier'],
            redirect_uri=redirect_uri,
        )
        claims = decode_id_token(tokens['id_token'])
    except Exception as exc:
        logger.exception('Telegram OAuth callback failed')
        return redirect(
            reverse('telegram-login') + f'?error={exc}',
        )

    telegram_id = parse_telegram_user_id(claims)
    if not telegram_id:
        return redirect(
            reverse('telegram-login') + '?error=telegram+id+нест',
        )

    user, _ = resolve_telegram_user(telegram_id, claims=claims)
    _save_device_id(user, oauth_ctx.get('device_id'))

    TokenModel = apps.get_model('authtoken', 'Token')
    token, _ = TokenModel.objects.get_or_create(user=user)

    if oauth_ctx.get('app'):
        return app_scheme_redirect(
            app_auth_redirect_url(
                token=token.key,
                user_id=user.id,
                device_id=oauth_ctx.get('device_id') or '',
            )
        )

    params = {
        'success': '1',
        'token': token.key,
        'user_id': str(user.id),
    }
    if oauth_ctx.get('device_id'):
        params['device_id'] = oauth_ctx['device_id']

    return redirect(f"{reverse('telegram-login')}?{urlencode(params)}")


@method_decorator(csrf_exempt, name='dispatch')
class TelegramLoginView(APIView):
    """POST /api/auth/telegram/ — Telegram Login Widget."""

    def post(self, request):
        bot_token = getattr(settings, 'TELEGRAM_BOT_TOKEN', '') or ''
        if not bot_token:
            return Response(
                {'error': 'Telegram Login танзим нашудааст'},
                status=503,
            )

        data = _flatten_payload(request.data)
        if not verify_telegram_login(data, bot_token):
            return Response({'error': 'Маълумоти Telegram нодуруст аст'}, status=400)

        try:
            telegram_id = str(int(data['id']))
        except (KeyError, TypeError, ValueError):
            return Response({'error': 'id-и Telegram лозим аст'}, status=400)

        user, created = resolve_telegram_user(telegram_id, widget_data=data)
        _save_device_id(user, request.data.get('device_id'))

        TokenModel = apps.get_model('authtoken', 'Token')
        token, _ = TokenModel.objects.get_or_create(user=user)

        return Response(
            {
                'token': token.key,
                'user_id': user.id,
                'created': created,
            }
        )


class UserProfileView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = UserSerializer(request.user)
        return Response(serializer.data)

    def patch(self, request):
        serializer = UserSerializer(request.user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=400)
    def delete(self, request):
        request.user.delete()
        return Response(status=204)
