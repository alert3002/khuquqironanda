from django.db import models
<<<<<<< HEAD
from django.contrib.auth.models import AbstractUser, BaseUserManager

# 1. Менеҷери корбар (Барои сохтани корбар бе username)
class CustomUserManager(BaseUserManager):
    def create_user(self, phone, password=None, **extra_fields):
        if not phone:
            raise ValueError('Рақами телефон ҳатмист')
        phone = phone.replace(" ", "") # Тоза кардани пробелҳо
        user = self.model(phone=phone, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, phone, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        return self.create_user(phone, password, **extra_fields)

# 2. Модели Корбар (CustomUser)
class CustomUser(AbstractUser):
    username = None # Мо username-ро истифода намебарем
    phone = models.CharField(max_length=15, unique=True, verbose_name="Рақами телефон")
    balance = models.DecimalField(max_digits=10, decimal_places=2, default=0, verbose_name="Баланс")
    USERNAME_FIELD = 'phone' # Логин акнун рақами телефон аст
    REQUIRED_FIELDS = []

    objects = CustomUserManager()

    def __str__(self):
        return self.phone

# 3. Модели Кодҳои Тасдиқ (OTP)
class PhoneOTP(models.Model):
    phone = models.CharField(max_length=15, unique=True)
    code = models.CharField(max_length=6)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.phone} - {self.code}"
=======
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

>>>>>>> a8f22a8973d7365b3dc32dbc0ffe15ba3b9e85a5
