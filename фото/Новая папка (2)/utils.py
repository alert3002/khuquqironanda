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
