"""Telegram Login OIDC (oauth.telegram.org) — ҷоигири widget-и deprecated."""

import base64
import hashlib
import logging
import secrets
from urllib.parse import urlencode

import requests
from django.conf import settings
from django.core.cache import cache
from django.http import HttpResponseRedirect

logger = logging.getLogger(__name__)

TELEGRAM_AUTH_URL = 'https://oauth.telegram.org/auth'
TELEGRAM_TOKEN_URL = 'https://oauth.telegram.org/token'
JWKS_URL = 'https://oauth.telegram.org/.well-known/jwks.json'
CACHE_PREFIX = 'tg_oauth:'
CACHE_TTL = 600


def get_telegram_client_id() -> str:
    cid = (getattr(settings, 'TELEGRAM_CLIENT_ID', '') or '').strip()
    if cid:
        return cid
    token = (getattr(settings, 'TELEGRAM_BOT_TOKEN', '') or '').strip()
    if ':' in token:
        return token.split(':', 1)[0]
    return ''


def oauth_configured() -> bool:
    return bool(
        get_telegram_client_id()
        and (getattr(settings, 'TELEGRAM_CLIENT_SECRET', '') or '').strip()
    )


def app_auth_redirect_url(
    *,
    token: str,
    user_id: int | str,
    device_id: str = '',
    **extra: str,
) -> str:
    """
    Deep link барои Flutter (app=1): khuquqironanda://auth?token=...&user_id=...
    """
    scheme = (
        getattr(settings, 'TELEGRAM_APP_CALLBACK_SCHEME', 'khuquqironanda')
        or 'khuquqironanda'
    ).strip().rstrip(':')
    params: dict[str, str] = {
        'token': token,
        'user_id': str(user_id),
    }
    if device_id:
        params['device_id'] = device_id
    for key, value in extra.items():
        if value is not None and value != '':
            params[key] = str(value)
    return f'{scheme}://auth?{urlencode(params)}'


def app_scheme_redirect(url: str) -> HttpResponseRedirect:
    """Redirect ба deep link (Django ба таври пешфарз custom scheme-ро қабул намекунад)."""
    scheme = (
        getattr(settings, 'TELEGRAM_APP_CALLBACK_SCHEME', 'khuquqironanda')
        or 'khuquqironanda'
    ).strip().rstrip(':')

    class _AppRedirect(HttpResponseRedirect):
        allowed_schemes = ['http', 'https', 'ftp', scheme]

    return _AppRedirect(url)


def _generate_pkce():
    verifier = secrets.token_urlsafe(48)
    digest = hashlib.sha256(verifier.encode('ascii')).digest()
    challenge = base64.urlsafe_b64encode(digest).rstrip(b'=').decode('ascii')
    return verifier, challenge


def build_authorization_url(*, redirect_uri: str, device_id: str = '', app_mode: bool = False) -> str:
    client_id = get_telegram_client_id()
    state = secrets.token_urlsafe(24)
    verifier, challenge = _generate_pkce()
    cache.set(
        f'{CACHE_PREFIX}{state}',
        {
            'verifier': verifier,
            'device_id': device_id or '',
            'app': app_mode,
        },
        CACHE_TTL,
    )
    params = {
        'client_id': client_id,
        'redirect_uri': redirect_uri,
        'response_type': 'code',
        'scope': 'openid profile phone',
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
    }
    return f'{TELEGRAM_AUTH_URL}?{urlencode(params)}'


def exchange_code_for_tokens(*, code: str, verifier: str, redirect_uri: str) -> dict:
    client_id = get_telegram_client_id()
    client_secret = (getattr(settings, 'TELEGRAM_CLIENT_SECRET', '') or '').strip()
    basic = base64.b64encode(f'{client_id}:{client_secret}'.encode()).decode()
    response = requests.post(
        TELEGRAM_TOKEN_URL,
        headers={
            'Authorization': f'Basic {basic}',
            'Content-Type': 'application/x-www-form-urlencoded',
        },
        data={
            'grant_type': 'authorization_code',
            'code': code,
            'redirect_uri': redirect_uri,
            'client_id': client_id,
            'code_verifier': verifier,
        },
        timeout=25,
    )
    if response.status_code >= 400:
        logger.warning('Telegram token error %s: %s', response.status_code, response.text[:300])
        response.raise_for_status()
    return response.json()


def decode_id_token(id_token: str) -> dict:
    try:
        import jwt
        from jwt import PyJWKClient
    except ImportError as exc:
        raise RuntimeError('PyJWT лозим аст: pip install PyJWT[crypto]') from exc

    client_id = get_telegram_client_id()
    jwks_client = PyJWKClient(JWKS_URL)
    signing_key = jwks_client.get_signing_key_from_jwt(id_token)
    return jwt.decode(
        id_token,
        signing_key.key,
        algorithms=[signing_key.algorithm_name],
        audience=client_id,
        issuer='https://oauth.telegram.org',
    )


def parse_telegram_user_id(claims: dict) -> str | None:
    """
    ID-и корбари Telegram аз OIDC id_token.
    Танҳо `sub` — `id` дар JWT метавонад рақами дохилии калон бошад (OverflowError дар SQLite).
    """
    raw = claims.get('sub')
    if raw is None or raw == '':
        return None
    user_id = str(raw).strip()
    if user_id.isdigit() and 1 <= len(user_id) <= 20:
        return user_id
    return None


def pop_oauth_state(state: str) -> dict | None:
    if not state:
        return None
    key = f'{CACHE_PREFIX}{state}'
    data = cache.get(key)
    if data:
        cache.delete(key)
    return data
