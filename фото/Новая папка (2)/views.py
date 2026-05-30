import logging
import random
from datetime import timedelta

from django.apps import apps
from django.conf import settings
from django.contrib.auth import get_user_model
from django.utils import timezone
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from rest_framework.authentication import TokenAuthentication
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import PhoneOTP
from .serializers import UserSerializer
from .utils import send_osonsms, verify_telegram_login

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

        user, _ = User.objects.get_or_create(phone=phone)
        _save_device_id(user, request.data.get('device_id'))

        TokenModel = apps.get_model('authtoken', 'Token')
        token, _ = TokenModel.objects.get_or_create(user=user)

        otp_obj.delete()

        return Response({'token': token.key, 'user_id': user.id})


@method_decorator(csrf_exempt, name='dispatch')
class TelegramLoginView(APIView):
    """
    POST /api/auth/telegram/
    Маълумоти Telegram Login Widget + hash.
    """

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
            telegram_id = int(data['id'])
        except (KeyError, TypeError, ValueError):
            return Response({'error': 'id-и Telegram лозим аст'}, status=400)

        defaults = {
            'first_name': data.get('first_name') or '',
            'last_name': data.get('last_name') or '',
        }

        user, created = User.objects.update_or_create(
            telegram_id=telegram_id,
            defaults=defaults,
        )
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
