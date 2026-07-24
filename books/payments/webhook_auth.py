"""Аутентификатсияи webhook аз SmartPay (сарлавҳаи X-Api-Token)."""

from django.conf import settings


def webhook_token_from_request(request):
    """Токен аз сарлавҳаҳое, ки дар админкаи SmartPay гузошта мешаванд."""
    return (
        request.headers.get('X-Api-Token')
        or request.headers.get('x-api-token')
        or request.headers.get('Api-Token')
        or request.headers.get('api_token')
        or request.headers.get('x-app-token')
        or ''
    ).strip()


def verify_smartpay_webhook(request):
    expected = getattr(settings, 'SMARTPAY_WEBHOOK_TOKEN', '').strip()
    if not expected:
        return True
    return webhook_token_from_request(request) == expected
