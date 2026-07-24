"""Правила доступа к бобам (харид, обуна)."""
from django.utils import timezone

from books.models import Purchase, PurchasedChapter, Subscription


def user_has_chapter_access(user, chapter) -> bool:
    """
    Боб дастрас аст, агар:
    - ройгон бошад;
    - боб ё тамоми китоб харида шуда бошад;
    - обунаи фаъол барои ин китоб бошад:
      • дар нақша рӯйхати «Бобҳои дастрас» холӣ → ҳамаи бобҳо;
      • агар бобҳо интихоб шудаанд → танҳо онҳо.
    """
    if chapter.is_free:
        return True
    if PurchasedChapter.objects.filter(user=user, chapter=chapter).exists():
        return True
    if Purchase.objects.filter(user=user, book=chapter.book).exists():
        return True

    subscriptions = Subscription.objects.filter(
        user=user,
        expires_at__gt=timezone.now(),
        plan__is_active=True,
        plan__book=chapter.book,
    ).prefetch_related('plan__chapters')

    for subscription in subscriptions:
        plan = subscription.plan
        if not plan.chapters.exists():
            return True
        if plan.chapters.filter(pk=chapter.pk).exists():
            return True

    return False
