"""Кӯмакгар барои JWS-и StoreKit 2 (transaction)."""
from __future__ import annotations

import base64
import json
from typing import Any


def decode_apple_jws_payload(jws: str) -> dict[str, Any]:
    """
    Баровардани payload аз JWS бе санҷиши имзо.

    Барои амнияти пурра дар production бояд App Store Server API ё санҷиши
    имзои Apple истифода шавад; ин қадам барои ҳамоҳангӣ бо маҳсулот/нақша кофӣ аст.
    """
    if not jws or not isinstance(jws, str):
        raise ValueError("signed_transaction_info холӣ аст")
    parts = jws.split(".")
    if len(parts) < 2:
        raise ValueError("JWS нодуруст")
    payload_b64 = parts[1]
    padding = "=" * (-len(payload_b64) % 4)
    raw = base64.urlsafe_b64decode(payload_b64 + padding)
    return json.loads(raw.decode("utf-8"))
