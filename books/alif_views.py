"""Alif Bank payment API views."""
from __future__ import annotations

import json
import logging
import uuid
from decimal import Decimal, InvalidOperation

from django.http import HttpResponse
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from rest_framework.authentication import TokenAuthentication
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .alif_payment import (
    build_payment_html,
    check_transaction_status,
    is_failed_status,
    is_success_status,
    verify_callback_token,
)
from .models import Transaction
from .payment_utils import apply_smartpay_success

logger = logging.getLogger(__name__)


def _parse_callback_payload(request) -> dict:
    data = {}
    if getattr(request, 'data', None):
        if isinstance(request.data, dict):
            data = dict(request.data)
        else:
            try:
                data = dict(request.data)
            except Exception:
                data = {}
    if not data and request.body:
        try:
            parsed = json.loads(request.body.decode('utf-8'))
            if isinstance(parsed, dict):
                data = parsed
        except Exception:
            pass
    if not data and request.POST:
        data = {k: v for k, v in request.POST.items()}
    # Normalize keys
    if 'order_id' in data and 'orderId' not in data:
        data['orderId'] = data['order_id']
    if 'transaction_id' in data and 'transactionId' not in data:
        data['transactionId'] = data['transaction_id']
    return data


@method_decorator(csrf_exempt, name='dispatch')
class AlifInitView(APIView):
    """POST /api/payment/alif/init/ — HTML form барои саҳифаи Alif."""

    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        amount_raw = request.data.get('amount')
        if amount_raw is None or str(amount_raw).strip() == '':
            return Response({'error': 'Маблағро ворид кунед'}, status=400)
        try:
            amount = Decimal(str(amount_raw))
            if amount <= 0:
                return Response({'error': 'Маблағ бояд мусбат бошад'}, status=400)
        except (InvalidOperation, ValueError, TypeError):
            return Response({'error': 'Маблағи нодуруст'}, status=400)

        description = request.data.get('description') or (
            f'Пур кардани баланси барномаи ҳуқуқи ронанда: {amount} сомонӣ'
        )
        order_id = f"ALF-{uuid.uuid4().hex[:12].upper()}"
        phone = getattr(request.user, 'phone', '') or ''
        email = getattr(request.user, 'email', '') or ''

        try:
            form = build_payment_html(
                order_id=order_id,
                amount=amount,
                phone=phone,
                info=description,
                email=email,
            )
        except ValueError as exc:
            return Response({'error': str(exc)}, status=503)
        except Exception as exc:
            logger.exception('Alif init failed')
            return Response({'error': f'Хатогӣ ҳангоми Alif: {exc}'}, status=500)

        Transaction.objects.create(
            user=request.user,
            amount=amount,
            status='PENDING',
            transaction_id=order_id,
            description=f'{description} [alif]',
        )

        return Response({
            'success': True,
            'order_id': order_id,
            'html_form': form['html_form'],
            'payment_url': form['payment_url'],
            'payment_link': form['payment_url'],
            'amount': form['amount'],
        })


@method_decorator(csrf_exempt, name='dispatch')
class AlifCallbackView(APIView):
    """
    POST /api/payment/alif/callback/ — webhook аз Alif (Service-Name: Alifpay).
    Ҷавоб: OK / ERROR (мисли плагини WordPress).
    """

    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        data = _parse_callback_payload(request)
        logger.info('Alif callback: %s', data)

        order_id = str(data.get('orderId') or '')
        status = str(data.get('status') or '')
        if not order_id or not status:
            return HttpResponse('ERROR: Invalid data', status=400)

        # Токенро санҷ (агар омада бошад)
        if data.get('token') and not verify_callback_token(data):
            logger.warning('Alif callback token mismatch for %s', order_id)
            return HttpResponse('ERROR: Invalid token', status=403)

        txn = Transaction.objects.filter(transaction_id=order_id).first()
        if not txn:
            logger.warning('Alif callback: order not found %s', order_id)
            return HttpResponse('ERROR: Order not found', status=404)

        if is_success_status(status):
            apply_smartpay_success(txn)
            alif_txn = data.get('transactionId') or ''
            if alif_txn and alif_txn not in (txn.description or ''):
                txn.refresh_from_db()
                note = f' alif_txn:{alif_txn}'
                if note.strip() not in (txn.description or ''):
                    txn.description = ((txn.description or '') + note)[:255]
                    txn.save(update_fields=['description'])
            return HttpResponse('OK')

        if is_failed_status(status):
            if txn.status != 'SUCCESS':
                txn.status = 'FAILED'
                txn.save(update_fields=['status'])
            return HttpResponse('ERROR')

        # pending ва ғайра — ҳоло PENDING мемонад
        return HttpResponse('OK')

    def get(self, request):
        # Баъзе шлюзҳо GET мефиристанд
        return self.post(request)


@method_decorator(csrf_exempt, name='dispatch')
class AlifReturnView(APIView):
    """Саҳифаи бозгашт баъди пардохт (барои WebView)."""

    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        order_id = request.GET.get('order_id', '')
        txn = Transaction.objects.filter(transaction_id=order_id).first() if order_id else None
        status = (txn.status if txn else 'PENDING').upper()

        # Агар ҳанӯз PENDING — аз Alif пурсед
        if txn and txn.status == 'PENDING':
            remote = check_transaction_status(order_id)
            remote_status = remote.get('status')
            if is_success_status(remote_status):
                apply_smartpay_success(txn)
                status = 'SUCCESS'
            elif is_failed_status(remote_status):
                txn.status = 'FAILED'
                txn.save(update_fields=['status'])
                status = 'FAILED'

        color = '#2e7d32' if status == 'SUCCESS' else (
            '#c62828' if status == 'FAILED' else '#1565c0'
        )
        title = {
            'SUCCESS': 'Пардохт муваффақ шуд',
            'FAILED': 'Пардохт рад шуд',
        }.get(status, 'Пардохт дар интизорӣ')
        html = f"""<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title}</title>
<style>body{{font-family:sans-serif;display:flex;align-items:center;justify-content:center;
min-height:100vh;margin:0;background:#f5f7fa}} .c{{text-align:center;padding:24px}}
h1{{color:{color};font-size:20px}} p{{color:#555}}</style></head>
<body><div class="c"><h1>{title}</h1>
<p>Шумо метавонед ба барнома баргардед. Баланс автоматӣ нав мешавад.</p>
<p id="status">{status}</p></div></body></html>"""
        return HttpResponse(html)


@method_decorator(csrf_exempt, name='dispatch')
class AlifStatusView(APIView):
    """GET/POST /api/payment/alif/status/ — санҷиши ҳолат + пуркунии баланс."""

    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return self._handle(request)

    def post(self, request):
        return self._handle(request)

    def _handle(self, request):
        order_id = (
            request.query_params.get('order_id')
            or request.data.get('order_id')
            or request.data.get('orderId')
        )
        if not order_id:
            return Response({'error': 'order_id лозим аст'}, status=400)

        txn = Transaction.objects.filter(
            user=request.user,
            transaction_id=order_id,
        ).first()
        if not txn:
            return Response({'status': 'unknown', 'order_id': order_id})

        credited = False
        if txn.status == 'PENDING':
            remote = check_transaction_status(order_id)
            remote_status = remote.get('status')
            if is_success_status(remote_status):
                credited = bool(apply_smartpay_success(txn))
                txn.refresh_from_db()
            elif is_failed_status(remote_status):
                txn.status = 'FAILED'
                txn.save(update_fields=['status'])

        request.user.refresh_from_db()
        return Response({
            'status': txn.status,
            'order_id': txn.transaction_id,
            'amount': str(txn.amount),
            'credited': credited,
            'balance': str(request.user.balance),
        })
