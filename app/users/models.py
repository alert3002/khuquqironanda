from django.db import models
from django.contrib.auth import get_user_model

User = get_user_model()


class SubscriptionPlan(models.Model):
    """
    Model for subscription plans that can be managed by admin.
    """
    name = models.CharField(max_length=255, verbose_name="Номи нақша")
    price = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="Нарх")
    days = models.IntegerField(verbose_name="Рӯзҳо")
    is_active = models.BooleanField(default=True, verbose_name="Фаъол")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Обунашавӣ"
        verbose_name_plural = "Обунашавиҳо"
        ordering = ['price']

    def __str__(self):
        return f"{self.name} - {self.price} сомонӣ ({self.days} рӯз)"


class Subscription(models.Model):
    """
    Model to track user subscriptions.
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='subscriptions')
    plan = models.ForeignKey(SubscriptionPlan, on_delete=models.CASCADE, related_name='subscriptions')
    purchased_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name = "Обуна"
        verbose_name_plural = "Обунаҳо"
        ordering = ['-purchased_at']

    def __str__(self):
        return f"{self.user.phone} - {self.plan.name} (то {self.expires_at.date()})"

