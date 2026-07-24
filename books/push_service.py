"""Фиристодани огоҳӣ ба дастгоҳҳо (FCM HTTP v1) + inbox."""
from __future__ import annotations

import json
import logging
import os
from pathlib import Path

import requests
from django.conf import settings
from django.utils import timezone

logger = logging.getLogger(__name__)

_firebase_app = None


def _credentials_path() -> str:
    path = (
        getattr(settings, 'FIREBASE_CREDENTIALS_PATH', '')
        or os.environ.get('FIREBASE_CREDENTIALS_PATH', '')
        or ''
    ).strip()
    if path:
        return path
    # Default: project root / firebase-service-account.json
    base = Path(settings.BASE_DIR)
    candidate = base / 'firebase-service-account.json'
    return str(candidate) if candidate.is_file() else ''


def _project_id_from_credentials(path: str) -> str:
    try:
        with open(path, encoding='utf-8') as f:
            data = json.load(f)
        return (data.get('project_id') or '').strip()
    except Exception:
        return ''


def _get_access_token(cred_path: str) -> str | None:
    """OAuth2 token аз Service Account (FCM HTTP v1)."""
    try:
        from google.auth.transport.requests import Request
        from google.oauth2 import service_account
    except ImportError:
        logger.error('google-auth насб нашудааст: pip install google-auth')
        return None

    scopes = ['https://www.googleapis.com/auth/firebase.messaging']
    try:
        creds = service_account.Credentials.from_service_account_file(
            cred_path, scopes=scopes
        )
        creds.refresh(Request())
        return creds.token
    except Exception:
        logger.exception('FCM access token failed')
        return None


def send_fcm_to_tokens(tokens, title: str, body: str) -> tuple[int, int]:
    """
    FCM HTTP v1 — як ба як (Legacy Server Key дигар кор намекунад).
    Баргашт: (success_count, failure_count)
    """
    tokens = [t for t in (tokens or []) if t]
    if not tokens:
        return 0, 0

    cred_path = _credentials_path()
    if not cred_path or not os.path.isfile(cred_path):
        logger.warning(
            'FIREBASE_CREDENTIALS_PATH нест — FCM фиристода нашуд '
            '(inbox кор мекунад). Service Account JSON гузоред.'
        )
        return 0, 0

    project_id = (
        getattr(settings, 'FIREBASE_PROJECT_ID', '')
        or os.environ.get('FIREBASE_PROJECT_ID', '')
        or _project_id_from_credentials(cred_path)
    ).strip()
    if not project_id:
        logger.error('FIREBASE_PROJECT_ID ёфт нашуд')
        return 0, len(tokens)

    access_token = _get_access_token(cred_path)
    if not access_token:
        return 0, len(tokens)

    url = f'https://fcm.googleapis.com/v1/projects/{project_id}/messages:send'
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json; charset=UTF-8',
    }

    success = 0
    failure = 0
    for token in tokens:
        payload = {
            'message': {
                'token': token,
                'notification': {
                    'title': title,
                    'body': body,
                },
                'data': {
                    'type': 'admin_push',
                    'title': title,
                    'body': body,
                },
                'android': {
                    'priority': 'HIGH',
                    'notification': {
                        'channel_id': 'huquqi_push',
                        'sound': 'default',
                    },
                },
                'apns': {
                    'payload': {
                        'aps': {
                            'sound': 'default',
                            'badge': 1,
                        }
                    }
                },
            }
        }
        try:
            resp = requests.post(url, json=payload, headers=headers, timeout=20)
            if resp.status_code in (200, 201):
                success += 1
            else:
                failure += 1
                logger.warning('FCM v1 error %s: %s', resp.status_code, resp.text[:300])
        except Exception:
            logger.exception('FCM v1 send failed')
            failure += 1
    return success, failure


def dispatch_push_notification(notification) -> dict:
    """Огоҳиро «фиристода» қайд мекунад + кӯшиши FCM."""
    from books.models import DevicePushToken

    tokens = list(
        DevicePushToken.objects.order_by('-updated_at').values_list('token', flat=True)[:5000]
    )
    ok, fail = send_fcm_to_tokens(tokens, notification.title, notification.body)
    notification.is_sent = True
    notification.sent_at = timezone.now()
    notification.fcm_success = ok
    notification.fcm_failure = fail
    notification.save(
        update_fields=['is_sent', 'sent_at', 'fcm_success', 'fcm_failure']
    )
    return {
        'tokens': len(tokens),
        'fcm_success': ok,
        'fcm_failure': fail,
        'inbox': True,
    }
