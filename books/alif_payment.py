"""
Alif Bank Tajikistan (Корти Милли) — протокол HTML form + callback + checktxn.
Аз плагини WooCommerce ва документатсияи alif.pro.
"""
from __future__ import annotations

import hashlib
import hmac
import logging
from decimal import Decimal
from html import escape
from typing import Any
from urllib.parse import urljoin

import requests
from django.conf import settings

logger = logging.getLogger(__name__)


def _alif_key() -> str:
    return str(getattr(settings, 'ALIF_KEY', '') or '').strip()


def _alif_password() -> str:
    return str(getattr(settings, 'ALIF_PASSWORD', '') or '').strip()


def _alif_gate() -> str:
    return str(getattr(settings, 'ALIF_GATE', 'km') or 'km').strip() or 'km'


def _alif_web_url() -> str:
    """Боевой: https://web.alif.tj/  Тест: https://test-web.alif.tj/"""
    return str(
        getattr(settings, 'ALIF_WEB_URL', 'https://web.alif.tj/') or 'https://web.alif.tj/'
    ).rstrip('/') + '/'


def _alif_check_url() -> str:
    base = _alif_web_url().rstrip('/')
    return f'{base}/checktxn'


def _site_base() -> str:
    return str(
        getattr(settings, 'PUBLIC_BASE_URL', '')
        or getattr(settings, 'DC_BASE_URL', '')
        or 'https://books.1week.tj'
    ).rstrip('/')


def password_hash(key: str | None = None, password: str | None = None) -> str:
    """password = HMAC-SHA256(password, key) — мисли PHP hash_hmac('sha256', password, key)."""
    key = key if key is not None else _alif_key()
    password = password if password is not None else _alif_password()
    return hmac.new(
        key.encode('utf-8'),
        password.encode('utf-8'),
        hashlib.sha256,
    ).hexdigest()


def payment_token(order_id: str, amount: Decimal | float | str, callback_url: str) -> str:
    """
    token = HMAC-SHA256(key + orderId + amount.fixed(2) + callbackUrl, password_hash)
    """
    key = _alif_key()
    amount_str = format_amount(amount)
    message = f'{key}{order_id}{amount_str}{callback_url}'
    return hmac.new(
        password_hash().encode('utf-8'),
        message.encode('utf-8'),
        hashlib.sha256,
    ).hexdigest()


def callback_token(order_id: str, status: str, transaction_id: str) -> str:
    """token = HMAC-SHA256(orderId + status + transactionId, password_hash)"""
    message = f'{order_id}{status}{transaction_id}'
    return hmac.new(
        password_hash().encode('utf-8'),
        message.encode('utf-8'),
        hashlib.sha256,
    ).hexdigest()


def checktxn_token(order_id: str) -> str:
    """token = HMAC-SHA256(key + orderId, password_hash)"""
    key = _alif_key()
    message = f'{key}{order_id}'
    return hmac.new(
        password_hash().encode('utf-8'),
        message.encode('utf-8'),
        hashlib.sha256,
    ).hexdigest()


def format_amount(amount: Decimal | float | str) -> str:
    return f'{Decimal(str(amount)):.2f}'


def verify_callback_token(data: dict[str, Any]) -> bool:
    order_id = str(data.get('orderId') or data.get('order_id') or '')
    status = str(data.get('status') or '')
    transaction_id = str(
        data.get('transactionId') or data.get('transaction_id') or ''
    )
    incoming = str(data.get('token') or '')
    if not order_id or not status or not transaction_id or not incoming:
        return False
    expected = callback_token(order_id, status, transaction_id)
    return hmac.compare_digest(expected.lower(), incoming.lower())


def is_success_status(status: str | None) -> bool:
    return str(status or '').strip().lower() in {'ok', 'success'}


def is_failed_status(status: str | None) -> bool:
    return str(status or '').strip().lower() in {
        'failed',
        'canceled',
        'cancelled',
        'error',
    }


def callback_url() -> str:
    return urljoin(_site_base() + '/', 'api/payment/alif/callback/')


def return_url(order_id: str) -> str:
    return urljoin(_site_base() + '/', f'api/payment/alif/return/?order_id={order_id}')


def build_payment_html(
    *,
    order_id: str,
    amount: Decimal | float | str,
    phone: str,
    info: str = '',
    email: str = '',
) -> dict[str, str]:
    """HTML auto-submit form барои WebView / браузер."""
    key = _alif_key()
    if not key or not _alif_password():
        raise ValueError('Alif танзим нашудааст (ALIF_KEY / ALIF_PASSWORD).')

    amount_str = format_amount(amount)
    cb = callback_url()
    ret = return_url(order_id)
    token = payment_token(order_id, amount_str, cb)
    gate = _alif_gate()
    action = _alif_web_url()
    phone_digits = ''.join(c for c in str(phone or '') if c.isdigit())
    info = info or f'Пур кардани баланс: {amount_str} сомонӣ'

    html = f"""<!DOCTYPE html>
<html lang="tg">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Пардохт — Alif</title>
  <style>
    body {{ font-family: sans-serif; display:flex; align-items:center; justify-content:center;
           min-height:100vh; margin:0; background:#f5f7fa; color:#333; }}
    .box {{ text-align:center; padding:24px; }}
    .spinner {{ width:40px; height:40px; border:4px solid #e0e0e0; border-top-color:#00a651;
               border-radius:50%; animation:spin 1s linear infinite; margin:16px auto; }}
    @keyframes spin {{ to {{ transform: rotate(360deg); }} }}
  </style>
</head>
<body onload="document.getElementById('alifPayForm').submit();">
  <div class="box">
    <div class="spinner"></div>
    <p>Ба саҳифаи Alif Банк гузаронида мешавед...</p>
    <form name="AlifPayForm" action="{escape(action)}" method="post" id="alifPayForm">
      <input type="hidden" name="key" value="{escape(key)}">
      <input type="hidden" name="token" value="{escape(token)}">
      <input type="hidden" name="callbackUrl" value="{escape(cb)}">
      <input type="hidden" name="returnUrl" value="{escape(ret)}">
      <input type="hidden" name="amount" value="{escape(amount_str)}">
      <input type="hidden" name="orderId" value="{escape(order_id)}">
      <input type="hidden" name="gate" value="{escape(gate)}">
      <input type="hidden" name="info" value="{escape(info)}">
      <input type="hidden" name="email" value="{escape(email or '')}">
      <input type="hidden" name="phone" value="{escape(phone_digits)}">
      <noscript><button type="submit">Пардохт бо Alif</button></noscript>
    </form>
  </div>
</body>
</html>"""

    return {
        'html_form': html,
        'payment_url': action,
        'order_id': order_id,
        'callback_url': cb,
        'return_url': ret,
        'amount': amount_str,
        'token': token,
    }


def check_transaction_status(order_id: str) -> dict[str, Any]:
    """POST /checktxn — ҳолати пардохт аз Alif."""
    payload = {
        'orderId': order_id,
        'key': _alif_key(),
        'token': checktxn_token(order_id),
    }
    headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=utf-8',
    }
    try:
        response = requests.post(
            _alif_check_url(),
            json=payload,
            headers=headers,
            timeout=30,
        )
        data: Any = {}
        try:
            data = response.json()
        except Exception:
            data = {'raw': response.text, 'http_status': response.status_code}
        if not isinstance(data, dict):
            data = {'raw': data, 'http_status': response.status_code}
        data.setdefault('http_status', response.status_code)
        return data
    except requests.RequestException as exc:
        logger.exception('Alif checktxn failed: %s', order_id)
        return {'status': 'unknown', 'error': str(exc)}
