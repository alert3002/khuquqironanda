"""Controller: SmartPay API v2 endpoints."""

import uuid
from decimal import Decimal

from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from rest_framework.authentication import TokenAuthentication
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from books.models import Transaction
from books.payments.exceptions import SmartPayError, SmartPayRegionError
from books.payments.geo import is_smartpay_region_allowed, smartpay_availability
from books.payment_utils import (
    apply_smartpay_success,
    build_smartpay_transaction_description,
    find_transaction_for_smartpay,
)
from books.payments.services.balance import credit_transaction_if_charged, is_charged_status
from books.payments.services.smartpay_service import SmartPayService
from books.payments.webhook_auth import verify_smartpay_webhook


def _require_tajikistan(request, user):
    if not is_smartpay_region_allowed(request, user):
        raise SmartPayRegionError()


def _error_response(exc):
    if isinstance(exc, SmartPayError):
        return Response(
            {
                'error': exc.message,
                'code': exc.code,
                'details': exc.details,
            },
            status=exc.status_code,
        )
    return Response({'error': str(exc)}, status=500)


class SmartPayAvailabilityView(APIView):
    """GET /api/payments/smartpay/availability/ — барои пинҳон кардани дар дигар кишварҳо."""

    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(smartpay_availability(request, request.user))


class SmartPayBanksView(APIView):
    """GET /api/payments/banks/ — рӯйхати бонкҳо барои интихоб дар дохили барнома."""

    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            _require_tajikistan(request, request.user)
            banks = SmartPayService().list_banks()
            return Response({'banks': banks})
        except SmartPayError as exc:
            return _error_response(exc)


@method_decorator(csrf_exempt, name='dispatch')
class CreateInvoiceView(APIView):
    """
    POST /api/payments/create-invoice/
    Body: amount, order_id (optional), bank_id (optional), description (optional)
    """

    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            _require_tajikistan(request, request.user)

            amount = request.data.get('amount')
            if amount is None:
                return Response({'error': 'Маблағро ворид кунед', 'code': 'amount_required'}, status=400)

            order_id = (
                request.data.get('order_id')
                or request.data.get('transaction_id')
                or f'SP-{uuid.uuid4().hex[:16]}'
            )
            order_id = str(order_id).strip()
            bank_id = request.data.get('bank_id')
            description = request.data.get('description') or (
                f'Пуркунии баланс: {amount} сомонӣ'
            )

            service = SmartPayService()
            amount_decimal = service.validate_amount(amount)

            phone = getattr(request.user, 'phone', '') or ''
            result = service.create_invoice(
                amount=amount_decimal,
                order_id=order_id,
                bank_id=bank_id,
                description=description,
                customer_phone=phone,
            )

            smartpay_id = result.get('smartpay_id') or ''
            invoice_uuid = result.get('invoice_uuid') or ''
            txn_description = build_smartpay_transaction_description(
                description,
                smartpay_id=smartpay_id,
                invoice_id=invoice_uuid,
            )
            txn_order_id = str(result.get('order_id') or order_id)

            Transaction.objects.update_or_create(
                transaction_id=txn_order_id,
                defaults={
                    'user': request.user,
                    'amount': amount_decimal,
                    'status': 'PENDING',
                    'description': txn_description,
                    'invoice_uuid': invoice_uuid,
                    'payment_provider': 'smartpay',
                },
            )

            return Response({
                'order_id': result['order_id'],
                'invoice_uuid': result.get('invoice_uuid'),
                'smartpay_id': result.get('smartpay_id'),
                'payment_link': result.get('payment_link'),
                'deeplink_url': result.get('deeplink_url'),
                'amount': result['amount'],
                'use_deeplink': bool(result.get('deeplink_url')),
            })
        except SmartPayError as exc:
            return _error_response(exc)


@method_decorator(csrf_exempt, name='dispatch')
class OrderStatusView(APIView):
    """
    GET /api/payments/order-status/?order_id=...
    Барои навсозии фаврӣ пас аз бозгашт аз бонк (агар webhook таъхир шавад).
    """

    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        order_id = request.query_params.get('order_id')
        if not order_id:
            return Response({'error': 'order_id лозим аст'}, status=400)

        try:
            _require_tajikistan(request, request.user)
            data = SmartPayService().get_order_status(order_id)
            status = data.get('status')

            credited = False
            new_balance = None
            if is_charged_status(status):
                try:
                    txn = Transaction.objects.get(
                        transaction_id=order_id,
                        user=request.user,
                    )
                    if credit_transaction_if_charged(txn, status_hint=status):
                        credited = True
                        request.user.refresh_from_db()
                        new_balance = str(request.user.balance)
                except Transaction.DoesNotExist:
                    pass

            payload = {
                'order_id': data.get('order_id', order_id),
                'status': status,
                'amount': data.get('amount'),
                'paid_amount': data.get('paid_amount'),
                'paid_at': data.get('paid_at'),
                'credited': credited,
            }
            if new_balance is not None:
                payload['new_balance'] = new_balance
            return Response(payload)
        except SmartPayError as exc:
            return _error_response(exc)


@method_decorator(csrf_exempt, name='dispatch')
class SmartPayWebhookView(APIView):
    """POST /api/payments/smartpay/webhook/ — ҳамон логикаи legacy webhook."""

    permission_classes = [AllowAny]

    def post(self, request):
        if not verify_smartpay_webhook(request):
            return Response({'error': 'Unauthorized'}, status=401)

        data = request.data if isinstance(request.data, dict) else {}
        status = data.get('status') or data.get('Status')
        order_id = data.get('order_id') or data.get('orderId')
        smartpay_id = data.get('smartpay_id') or data.get('smartpayId')
        invoice_id = (
            data.get('invoice_id')
            or data.get('invoiceId')
            or data.get('invoice_uuid')
            or data.get('invoiceUuid')
        )

        if is_charged_status(status):
            txn = find_transaction_for_smartpay(
                order_id=order_id,
                smartpay_id=smartpay_id,
                invoice_id=invoice_id,
            )
            if txn:
                apply_smartpay_success(txn, status_hint=status)

        return Response({'status': 'accepted'})
