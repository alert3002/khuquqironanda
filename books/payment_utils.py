"""Helpers for matching SmartPay invoices to local Transaction rows."""
import logging
import re

from django.db import transaction as db_transaction

from .models import Transaction

logger = logging.getLogger(__name__)

SMARTPAY_TAG_RE = re.compile(r'\s*\[smartpay_id:[^\]]+\]', re.IGNORECASE)
INVOICE_TAG_RE = re.compile(r'\s*\[invoice_id:[^\]]+\]', re.IGNORECASE)


def format_smartpay_id(raw):
    """Format SmartPay numeric id as dashboard id (e.g. 721000000201 -> 721-000000201)."""
    if not raw:
        return ''
    s = str(raw).strip()
    if '-' in s:
        return s
    digits = re.sub(r'\D', '', s)
    if len(digits) > 3:
        return f'{digits[:3]}-{digits[3:]}'
    return s


def smartpay_order_lookup_keys(order_id=None, smartpay_id=None, invoice_id=None):
    """Build candidate keys for transaction_id / description lookup."""
    keys = []

    def _add(value):
        if value is None:
            return
        s = str(value).strip()
        if not s:
            return
        keys.append(s)
        keys.append(s.upper())
        keys.append(s.lower())
        digits = re.sub(r'\D', '', s)
        if digits:
            keys.append(digits)
            if len(digits) > 3:
                keys.append(f'{digits[:3]}-{digits[3:]}')
        if s.upper().startswith('SP-'):
            tail = s[3:]
            keys.append(tail)
            td = re.sub(r'\D', '', tail)
            if td:
                keys.append(td)
                if len(td) > 3:
                    keys.append(f'{td[:3]}-{td[3:]}')
        if '-' in s:
            compact = s.replace('-', '')
            keys.append(compact)
            keys.append(f'SP-{compact}')

    _add(order_id)
    _add(smartpay_id)
    formatted = format_smartpay_id(smartpay_id or order_id)
    _add(formatted)
    if invoice_id:
        keys.append(str(invoice_id).strip())

    # Preserve order, drop duplicates
    seen = set()
    out = []
    for k in keys:
        if k and k not in seen:
            seen.add(k)
            out.append(k)
    return out


def find_transaction_for_smartpay(order_id=None, smartpay_id=None, invoice_id=None):
    keys = smartpay_order_lookup_keys(
        order_id=order_id,
        smartpay_id=smartpay_id,
        invoice_id=invoice_id,
    )

    for key in keys:
        txn = Transaction.objects.filter(transaction_id=key).first()
        if txn:
            return txn
        txn = Transaction.objects.filter(transaction_id__iexact=key).first()
        if txn:
            return txn

    for key in keys:
        txn = Transaction.objects.filter(description__icontains=f'smartpay_id:{key}').first()
        if txn:
            return txn
        formatted = format_smartpay_id(key)
        if formatted and formatted != key:
            txn = Transaction.objects.filter(
                description__icontains=f'smartpay_id:{formatted}'
            ).first()
            if txn:
                return txn

    if invoice_id:
        inv = str(invoice_id).strip()
        txn = Transaction.objects.filter(description__icontains=f'invoice_id:{inv}').first()
        if txn:
            return txn

    digits = re.sub(r'\D', '', str(smartpay_id or order_id or ''))
    if len(digits) >= 6:
        suffix = digits[-9:]
        txn = Transaction.objects.filter(transaction_id__icontains=suffix).order_by('-created_at').first()
        if txn:
            return txn
        txn = Transaction.objects.filter(description__icontains=suffix).order_by('-created_at').first()
        if txn:
            return txn

    return None


def extract_smartpay_id_from_description(description):
    if not description:
        return None
    match = re.search(r'smartpay_id:([^\]\s]+)', str(description), re.IGNORECASE)
    return match.group(1).strip() if match else None


def apply_smartpay_success(txn):
    """Mark transaction SUCCESS and credit user balance (idempotent, atomic)."""
    with db_transaction.atomic():
        locked = Transaction.objects.select_for_update().get(pk=txn.pk)
        if locked.status == 'SUCCESS':
            return False
        locked.status = 'SUCCESS'
        locked.save(update_fields=['status'])
        from django.contrib.auth import get_user_model
        user = get_user_model().objects.select_for_update().get(pk=locked.user_id)
        user.balance += locked.amount
        user.save(update_fields=['balance'])
        logger.info(
            'SmartPay SUCCESS txn=%s user=%s amount=%s balance=%s',
            locked.transaction_id,
            user.pk,
            locked.amount,
            user.balance,
        )
    return True
