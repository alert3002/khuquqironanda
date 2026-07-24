import hashlib
import hmac
import json
import logging
import time
import uuid

import requests
from django.conf import settings

logger = logging.getLogger(__name__)

OSONSMS_URL = 'https://api.osonsms.com/sendsms_v1.php'
OSONSMS_TIMEOUT = 20


def send_osonsms(phone, code):
    """
    Ирсоли SMS тавассути OsonSMS.
    Бармегардонад: {'success': bool, 'error': str|None, 'txn_id': str|None, 'detail': ...}
    """
    login = getattr(settings, 'OSONSMS_LOGIN', '') or ''
    sender = getattr(settings, 'OSONSMS_SENDER', '') or ''
    hash_key = getattr(settings, 'OSONSMS_HASH', '') or ''

    if not all([login, sender, hash_key]):
        return {
            'success': False,
            'error': 'Танзимоти SMS нопурра аст (OSONSMS_LOGIN, OSONSMS_SENDER, OSONSMS_HASH)',
            'txn_id': None,
            'detail': None,
        }

    txn_id = str(uuid.uuid4())
    message = (
        f'Код: {code} барои тасдиқи китобхона. '
        'Онро ба ҳеҷ кас надиҳед! Ҳатто ба коргарони китобхона.'
    )

    str_source = f'{txn_id};{login};{sender};{phone};{hash_key}'
    str_hash = hashlib.sha256(str_source.encode('utf-8')).hexdigest()

    params = {
        'from': sender,
        'phone_number': phone,
        'msg': message,
        'str_hash': str_hash,
        'txn_id': txn_id,
        'login': login,
    }

    try:
        response = requests.get(
            OSONSMS_URL,
            params=params,
            timeout=OSONSMS_TIMEOUT,
        )
    except requests.RequestException as exc:
        logger.exception('OsonSMS request failed for %s', phone)
        return {
            'success': False,
            'error': 'Хатогии пайвастшавӣ ба хидмати SMS',
            'txn_id': txn_id,
            'detail': str(exc),
        }

    raw_text = (response.text or '').strip()
    logger.info(
        'OsonSMS response phone=%s status=%s body=%s',
        phone,
        response.status_code,
        raw_text[:500],
    )

    parsed = _parse_osonsms_response(raw_text)
    if parsed.get('status') == 'ok':
        return {
            'success': True,
            'error': None,
            'txn_id': parsed.get('txn_id') or txn_id,
            'detail': parsed,
        }

    if response.status_code == 409:
        # txn_id такрор — SMS дубора фиристода намешавад (қабул кардан ҳамчун муваффақият)
        return {
            'success': True,
            'error': None,
            'txn_id': txn_id,
            'detail': parsed or raw_text,
        }

    error_msg = _osonsms_error_message(parsed, raw_text, response.status_code)
    return {
        'success': False,
        'error': error_msg,
        'txn_id': txn_id,
        'detail': parsed if parsed else raw_text,
    }


def _parse_osonsms_response(raw_text):
    if not raw_text:
        return None
    try:
        data = json.loads(raw_text)
        if isinstance(data, dict):
            return data
    except json.JSONDecodeError:
        pass
    if raw_text.lower() in ('ok', 'success', '1', 'true'):
        return {'status': 'ok'}
    return {'status': 'error', 'message': raw_text}


def _osonsms_error_message(parsed, raw_text, http_status):
    if isinstance(parsed, dict):
        if parsed.get('message'):
            return str(parsed['message'])
        if parsed.get('error'):
            return str(parsed['error'])
        if parsed.get('status') and parsed['status'] != 'ok':
            return str(parsed.get('status'))
    if http_status >= 400:
        return f'Хатогии SMS (HTTP {http_status})'
    if raw_text:
        return raw_text[:200]
    return 'Ирсоли SMS ноком шуд'


def verify_telegram_login(auth_data, bot_token):
    """
    Тасдиқи маълумоти Telegram Login Widget.
    https://core.telegram.org/widgets/login#checking-authorization
    """
    if not bot_token:
        return False

    data = {k: v for k, v in auth_data.items() if v is not None and k != 'hash'}
    check_hash = auth_data.get('hash')
    if not check_hash:
        return False

    auth_date = data.get('auth_date')
    if auth_date is not None:
        try:
            if int(time.time()) - int(auth_date) > 86400:
                return False
        except (TypeError, ValueError):
            return False

    data_check_string = '\n'.join(
        f'{k}={data[k]}' for k in sorted(data.keys())
    )
    secret_key = hashlib.sha256(bot_token.encode('utf-8')).digest()
    calculated = hmac.new(
        secret_key,
        data_check_string.encode('utf-8'),
        hashlib.sha256,
    ).hexdigest()
    return hmac.compare_digest(calculated, check_hash)


def normalize_phone_number(raw) -> str | None:
    """Тоза кардани рақам ба формати +992..."""
    if raw is None:
        return None
    s = str(raw).strip().replace(' ', '').replace('-', '')
    if not s:
        return None
    if s.startswith('+'):
        digits = ''.join(c for c in s[1:] if c.isdigit())
        if not digits:
            return None
        return f'+{digits}'
    digits = ''.join(c for c in s if c.isdigit())
    if not digits:
        return None
    if digits.startswith('992'):
        return f'+{digits}'
    if len(digits) == 9:
        return f'+992{digits}'
    return f'+{digits}'


def _telegram_username_from_payload(data: dict) -> str:
    for key in ('preferred_username', 'username', 'telegram_username'):
        val = data.get(key)
        if val:
            return str(val).strip().lstrip('@')[:64]
    return ''


def _phone_from_payload(data: dict):
    for key in ('phone_number', 'phone', 'phone_number_verified'):
        val = data.get(key)
        if val:
            return normalize_phone_number(val)
    return None


def _merge_telegram_payload(*, claims=None, widget_data=None) -> dict:
    data = {}
    if claims:
        data.update(claims)
    if widget_data:
        data.update(widget_data)
    return data


def _merge_accounts_by_telegram(canonical, telegram_id: str):
    """
    Як ҳисоб барои як одам: телефон + Telegram.
    Ҳисобҳои дубликати telegram_id-ро ба canonical пайваст/нест мекунад.
    """
    from decimal import Decimal
    from django.contrib.auth import get_user_model

    User = get_user_model()
    telegram_id = str(telegram_id).strip()
    if not telegram_id:
        return canonical

    dupes = list(
        User.objects.filter(telegram_id=telegram_id).exclude(pk=canonical.pk)
    )
    extra_balance = Decimal('0')
    for dup in dupes:
        extra_balance += dup.balance or Decimal('0')
        dup.telegram_id = None
        dup.save(update_fields=['telegram_id'])
        if not dup.phone:
            dup.delete()

    update_fields = []
    if canonical.telegram_id != telegram_id:
        canonical.telegram_id = telegram_id
        update_fields.append('telegram_id')
    if extra_balance:
        canonical.balance = (canonical.balance or Decimal('0')) + extra_balance
        update_fields.append('balance')
    if update_fields:
        canonical.save(update_fields=update_fields)
    return canonical


def resolve_telegram_user(telegram_id: str, *, claims=None, widget_data=None):
    """
    Як аккаунт: агар телефон ва Telegram як одам бошанд — ҳамон корбар.
    1) Ҳисоб бо phone (SMS) + telegram_id
    2) Ҳисоб бо telegram_id (агар phone дар JWT набошад)
    3) Эҷоди нав
    """
    from django.contrib.auth import get_user_model

    User = get_user_model()
    data = _merge_telegram_payload(claims=claims, widget_data=widget_data)
    phone = _phone_from_payload(data)
    telegram_id = str(telegram_id).strip()

    if phone:
        by_phone = User.objects.filter(phone=phone).first()
        if by_phone:
            _merge_accounts_by_telegram(by_phone, telegram_id)
            apply_telegram_profile(by_phone, claims=claims, widget_data=widget_data)
            return by_phone, False

    by_tg = User.objects.filter(telegram_id=telegram_id).first()
    if by_tg:
        apply_telegram_profile(by_tg, claims=claims, widget_data=widget_data)
        if phone and not by_tg.phone:
            if not User.objects.filter(phone=phone).exclude(pk=by_tg.pk).exists():
                by_tg.phone = phone
                by_tg.save(update_fields=['phone'])
        return by_tg, False

    user, created = User.objects.update_or_create(
        telegram_id=telegram_id,
        defaults={},
    )
    apply_telegram_profile(user, claims=claims, widget_data=widget_data)
    return user, created


def link_phone_login_to_telegram(phone: str, telegram_id: str | None = None):
    """
    Барои SMS verify: ҳисоб бо phone; агар telegram_id дода шавад — як аккаунт.
    """
    from django.contrib.auth import get_user_model

    User = get_user_model()
    phone_key = str(phone).replace(' ', '')
    user, created = User.objects.get_or_create(phone=phone_key)
    if telegram_id:
        _merge_accounts_by_telegram(user, str(telegram_id).strip())
    return user, created


def apply_telegram_profile(user, *, claims: dict | None = None, widget_data: dict | None = None):
    """Навсозии профил аз OIDC claims ё маълумоти Login Widget."""
    from django.contrib.auth import get_user_model

    User = get_user_model()
    data = _merge_telegram_payload(claims=claims, widget_data=widget_data)

    if not data:
        return user

    update_fields = []

    username = _telegram_username_from_payload(data)
    if username and user.telegram_username != username:
        user.telegram_username = username
        update_fields.append('telegram_username')

    phone = _phone_from_payload(data)
    if phone and not user.phone:
        if not User.objects.filter(phone=phone).exclude(pk=user.pk).exists():
            user.phone = phone
            update_fields.append('phone')

    first_name = (data.get('first_name') or data.get('given_name') or '').strip()
    if first_name and user.first_name != first_name:
        user.first_name = first_name[:150]
        update_fields.append('first_name')

    last_name = (data.get('last_name') or data.get('family_name') or '').strip()
    if last_name and user.last_name != last_name:
        user.last_name = last_name[:150]
        update_fields.append('last_name')

    if update_fields:
        user.save(update_fields=update_fields)
    return user
