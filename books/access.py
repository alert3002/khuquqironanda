"""Chapter access rules (subscription, purchase, free)."""
from django.utils import timezone

from .models import Purchase, PurchasedChapter, Subscription


def subscription_grants_chapter(user, chapter):
    """
    Active subscription unlocks a chapter when:
    - plan is 6+ months (180+ days), or
    - plan has no chapter list (all chapters), or
    - chapter is explicitly included in the plan.
    """
    subs = Subscription.objects.filter(
        user=user,
        expires_at__gt=timezone.now(),
        plan__is_active=True,
        plan__book=chapter.book,
    ).select_related('plan').prefetch_related('plan__chapters')

    for sub in subs:
        plan = sub.plan
        if plan.days >= 180:
            return True
        allowed = set(plan.chapters.values_list('pk', flat=True))
        if not allowed:
            return True
        if chapter.pk in allowed:
            return True
    return False


def user_has_chapter_access(user, chapter):
    if chapter.is_free:
        return True
    if Purchase.objects.filter(user=user, book=chapter.book).exists():
        return True
    if PurchasedChapter.objects.filter(user=user, chapter=chapter).exists():
        return True
    return subscription_grants_chapter(user, chapter)
