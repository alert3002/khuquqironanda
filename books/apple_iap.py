"""
Apple StoreKit 2 JWS — ҷудо кардани payload (бидуни санҷиши имзо).
Дар production бояд тасдиқи расмӣ тавассути App Store Server API / санҷиши пурраи JWS иҷро шавад.
"""

from __future__ import annotations

import base64
import json


def decode_apple_jws_payload(jws: str) -> dict:
    """
    Қисми дуюми JWS (payload)-ро аз base64url мечинонад ва JSON бармегардонад.
    Имзо санҷида намешавад — дар production бояд App Store Server API / санҷиши JWS истифода шавад.
    """
    parts = jws.split('.')
    if len(parts) < 2:
        raise ValueError('JWS нодуруст аст: қисмҳои кофӣ нестанд')
    payload_b64 = parts[1]
    pad = (-len(payload_b64)) % 4
    if pad:
        payload_b64 += '=' * pad
    raw = base64.urlsafe_b64decode(payload_b64)
    return json.loads(raw.decode('utf-8'))
