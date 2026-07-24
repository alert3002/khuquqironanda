"""SmartPay Ecommerce API v2 — invoices, banks, status."""

import logging
import uuid

import requests
from django.conf import settings
from decimal import Decimal

from books.payments.exceptions import SmartPayError, SmartPayTimeoutError

logger = logging.getLogger(__name__)


class SmartPayService:
    MIN_AMOUNT = Decimal('2')

    def __init__(self):
        base = getattr(settings, 'SMARTPAY_API_BASE_URL', '').rstrip('/')
        if not base:
            base = 'https://ecomm.smartpay.tj/api/merchant'
        self.base_url = base
        self.api_key = getattr(settings, 'SMARTPAY_API_KEY', '') or getattr(
            settings, 'SMARTPAY_API_TOKEN', '',
        )
        self.merchant_site = getattr(
            settings, 'SMARTPAY_MERCHANT_SITE', 'Kharid.tj',
        )
        self.timeout = int(getattr(settings, 'SMARTPAY_REQUEST_TIMEOUT', 30))
        self.webhook_base = getattr(settings, 'SMARTPAY_WEBHOOK_BASE_URL', '').rstrip(
            '/',
        ) or getattr(settings, 'DC_BASE_URL', 'https://books.1week.tj').rstrip('/')

    def _headers(self):
        if not self.api_key:
            raise SmartPayError(
                'SmartPay танзим нашудааст (SMARTPAY_API_KEY).',
                code='not_configured',
                status_code=503,
            )
        return {
            'x-app-token': self.api_key,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
        }

    def _request(self, method, path, *, json=None):
        url = f'{self.base_url}/{path.lstrip("/")}'
        try:
            response = requests.request(
                method,
                url,
                headers=self._headers(),
                json=json,
                timeout=self.timeout,
            )
        except requests.Timeout as exc:
            raise SmartPayTimeoutError() from exc
        except requests.RequestException as exc:
            logger.exception('SmartPay request failed: %s %s', method, url)
            raise SmartPayError(
                'Хатогии пайвастшавӣ ба SmartPay.',
                code='connection_error',
                status_code=502,
            ) from exc

        try:
            data = response.json()
        except ValueError:
            data = {'raw': response.text}

        if response.status_code == 401:
            raise SmartPayError(
                'Калиди SmartPay нодуруст ё ғайрифаъол аст.',
                code='unauthorized',
                status_code=502,
                details=data,
            )

        if response.status_code >= 500:
            raise SmartPayError(
                'Хатогии сервери SmartPay.',
                code='upstream_error',
                status_code=502,
                details=data,
            )

        return response.status_code, data

    def validate_amount(self, amount):
        try:
            value = Decimal(str(amount))
        except Exception as exc:
            raise SmartPayError(
                'Маблағи нодуруст.',
                code='invalid_amount',
            ) from exc

        if value < self.MIN_AMOUNT:
            raise SmartPayError(
                f'Минималӣ {self.MIN_AMOUNT} сомонӣ.',
                code='min_amount',
            )
        return value

    def list_banks(self):
        _, data = self._request('GET', '/banks/')
        return data.get('banks', data if isinstance(data, list) else [])

    def create_invoice(
        self,
        *,
        amount,
        order_id=None,
        bank_id=None,
        description='',
        customer_phone='',
    ):
        amount_decimal = self.validate_amount(amount)
        order_id = order_id or f'SP-{uuid.uuid4().hex[:16]}'

        payload = {
            'order_id': str(order_id),
            'amount': float(amount_decimal),
            'currency': 'TJS',
            'description': description or f'Пуркунии баланс {amount_decimal} сомонӣ',
            'merchant_site': self.merchant_site,
            'return_url': (
                f'{self.webhook_base}/api/payment/smartpay/webhook/'
            ),
        }
        if customer_phone:
            payload['customer_phone'] = str(customer_phone).replace(' ', '')
        if bank_id is not None and str(bank_id).strip() != '':
            payload['deeplink_bank_id'] = int(bank_id)

        _, data = self._request('POST', '/invoices/', json=payload)

        result_code = data.get('result')
        if result_code not in (200, '200', None):
            message = data.get('message') or 'Хатогӣ аз SmartPay'
            if 'минимальн' in message.lower() or '2 сомон' in message.lower():
                raise SmartPayError(
                    f'Минималӣ {self.MIN_AMOUNT} сомонӣ.',
                    code='min_amount',
                    details=data,
                )
            raise SmartPayError(message, code='smartpay_error', details=data)

        return {
            'order_id': data.get('order_id', order_id),
            'invoice_uuid': data.get('invoice_uuid'),
            'smartpay_id': data.get('smartpay_id'),
            'payment_link': data.get('payment_link'),
            'deeplink_url': data.get('deeplink_url'),
            'amount': str(amount_decimal),
            'raw': data,
        }

    def get_order_status(self, order_id):
        _, data = self._request('GET', f'/order/status/{order_id}')
        return data
