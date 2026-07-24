"""Пуркунии баланс пас аз пардохти муваффақ (идемпотент)."""

from decimal import Decimal

from django.db import transaction as db_transaction

from books.models import Transaction


CHARGED_STATUSES = frozenset({'CHARGED', 'SUCCESS', 'PAID', 'COMPLETED'})


def normalize_payment_status(status):
    if status is None:
        return ''
    return str(status).strip().upper()


def is_charged_status(status):
    return normalize_payment_status(status) in CHARGED_STATUSES


@db_transaction.atomic
def credit_transaction_if_charged(txn, *, status_hint=None):
    """
    Агар ҳолат Charged бошад — балансро зиёд мекунад (як маротиба).
    """
    txn.refresh_from_db()
    if txn.status == 'SUCCESS':
        return False

    if status_hint is not None and not is_charged_status(status_hint):
        return False

    txn.status = 'SUCCESS'
    txn.save(update_fields=['status'])

    user = txn.user
    user.balance = (user.balance or Decimal('0')) + txn.amount
    user.save(update_fields=['balance'])
    return True
