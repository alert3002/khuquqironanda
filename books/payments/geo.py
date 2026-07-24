"""Маҳдудияти минтақавӣ: SmartPay танҳо барои Тоҷикистон."""

from django.conf import settings

TJ_CODES = frozenset({'TJ', 'TJK', 'TAJIKISTAN', 'TOJIKISTON'})


def _normalize_country(value):
    if not value:
        return ''
    return str(value).strip().upper()


def country_from_request(request):
    """Кишвар аз сарлавҳа ё body (Flutter метавонад фиристад)."""
    for header in (
        'HTTP_CF_IPCOUNTRY',
        'HTTP_X_APP_COUNTRY',
        'HTTP_X_COUNTRY_CODE',
    ):
        code = _normalize_country(request.META.get(header, ''))
        if code and code != 'XX':
            return code

    if hasattr(request, 'data') and isinstance(request.data, dict):
        for key in ('country_code', 'country', 'countryCode'):
            code = _normalize_country(request.data.get(key))
            if code:
                return code
    return ''


def is_tajikistan_phone(phone):
    if not phone:
        return False
    digits = ''.join(c for c in str(phone) if c.isdigit())
    return digits.startswith('992') or str(phone).strip().startswith('+992')


def is_smartpay_region_allowed(request, user=None):
    """
    SmartPay фаъол аст, агар:
    - кишвар = TJ (аз IP/сарлавҳа/body), ё
    - рақами корбар +992 (ва кишвари хориҷӣ ҳатман густанохта нашуда бошад).
    """
    allowed = {
        _normalize_country(c)
        for c in getattr(settings, 'SMARTPAY_ALLOWED_COUNTRIES', ['TJ', 'TJK'])
    }
    country = country_from_request(request)

    if country:
        return country in allowed

    if user is not None and is_tajikistan_phone(getattr(user, 'phone', None)):
        return True

    # Бе маълумоти кишвар — барои бехатарӣ хомӯш (танҳо TJ)
    return False


def smartpay_availability(request, user=None):
    """Барои Flutter: оё SmartPay намоиш дода шавад."""
    country = country_from_request(request)
    allowed = is_smartpay_region_allowed(request, user)
    return {
        'smartpay_available': allowed,
        'country_code': country or None,
        'reason': None if allowed else 'SmartPay танҳо дар Тоҷикистон дастрас аст.',
    }
