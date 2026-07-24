"""Сопоставление Transaction с идентификаторами SmartPay (webhook / status)."""
import re
from typing import Optional

from django.db.models import Q

from books.models import Transaction

SMARTPAY_TAG_RE = re.compile(r'\[smartpay_id:([^\]]+)\]', re.I)
INVOICE_TAG_RE = re.compile(r'\[invoice_id:([^\]]+)\]', re.I)


def _normalize_id(value) -> str:
    if value is None:
        return ''
    return str(value).strip()


def extract_smartpay_id_from_description(description: str) -> str:
    match = SMARTPAY_TAG_RE.search(description or '')
    return match.group(1).strip() if match else ''


def extract_invoice_id_from_description(description: str) -> str:
    match = INVOICE_TAG_RE.search(description or '')
    return match.group(1).strip() if match else ''


def build_smartpay_transaction_description(
    base_description: str,
    *,
    smartpay_id: str = '',
    invoice_id: str = '',
) -> str:
    """Метки [smartpay_id:...] и [invoice_id:...] для поиска из webhook."""
    parts = [(_normalize_id(base_description) or '').strip()]
    sp = _normalize_id(smartpay_id)
    inv = _normalize_id(invoice_id)
    if sp:
        parts.append(f'[smartpay_id:{sp}]')
    if inv:
        parts.append(f'[invoice_id:{inv}]')
    desc = ' '.join(part for part in parts if part)
    return desc[:255]


def _candidate_ids(order_id=None, smartpay_id=None, invoice_id=None):
    seen = []
    for raw in (order_id, smartpay_id, invoice_id):
        value = _normalize_id(raw)
        if value and value not in seen:
            seen.append(value)
    return seen


def apply_smartpay_success(txn: Transaction, *, status_hint=None) -> bool:
    """Пуркунии баланс пас аз пардохти муваффақ (идемпотент)."""
    from books.payments.services.balance import credit_transaction_if_charged, is_charged_status

    if status_hint is not None and not is_charged_status(status_hint):
        return False
    return credit_transaction_if_charged(txn, status_hint=status_hint)


def find_transaction_for_smartpay(
    *,
    order_id=None,
    smartpay_id=None,
    invoice_id=None,
    user=None,
) -> Optional[Transaction]:
    """
    Ищет Transaction по:
    - transaction_id / invoice_uuid (order_id, smartpay_id, SP-..., UUID);
    - метке [smartpay_id:...] в description;
    - суффиксу числового ID (000000201) из формата 721-000000201.
    """
    candidates = _candidate_ids(order_id, smartpay_id, invoice_id)
    if not candidates:
        return None

    qs = Transaction.objects.all()
    if user is not None:
        qs = qs.filter(user=user)

    for cid in candidates:
        txn = qs.filter(Q(transaction_id=cid) | Q(invoice_uuid=cid)).first()
        if txn:
            return txn

    for cid in candidates:
        txn = qs.filter(description__icontains=f'[smartpay_id:{cid}]').first()
        if txn:
            return txn

    for cid in candidates:
        txn = qs.filter(description__icontains=f'[invoice_id:{cid}]').first()
        if txn:
            return txn

    for cid in candidates:
        if '-' in cid:
            suffix = cid.split('-', 1)[-1]
            if suffix.isdigit():
                txn = qs.filter(description__icontains=suffix).order_by('-created_at').first()
                if txn and extract_smartpay_id_from_description(txn.description).endswith(suffix):
                    return txn

    return None


def smartpay_status_lookup_id(txn: Transaction, fallback_order_id: str = '') -> str:
    """ID для запроса GET /order/status/ в SmartPay API."""
    from_description = extract_smartpay_id_from_description(txn.description)
    if from_description:
        return from_description
    if txn.invoice_uuid:
        return txn.invoice_uuid
    return fallback_order_id or txn.transaction_id
