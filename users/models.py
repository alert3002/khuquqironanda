from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models


class CustomUserManager(BaseUserManager):
    def create_user(self, phone=None, password=None, **extra_fields):
        if not phone and not extra_fields.get('telegram_id'):
            raise ValueError('Рақами телефон ё telegram_id ҳатмист')
        if phone:
            phone = str(phone).replace(' ', '')
        user = self.model(phone=phone, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, phone, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        return self.create_user(phone, password, **extra_fields)


class CustomUser(AbstractUser):
    username = None
    phone = models.CharField(
        max_length=15,
        unique=True,
        null=True,
        blank=True,
        verbose_name='Рақами телефон',
    )
    telegram_id = models.CharField(
        max_length=32,
        unique=True,
        null=True,
        blank=True,
        verbose_name='Telegram ID',
    )
    telegram_username = models.CharField(
        max_length=64,
        blank=True,
        default='',
        verbose_name='Telegram @username',
    )
    device_id = models.CharField(
        max_length=255,
        blank=True,
        default='',
        verbose_name='Device ID (Flutter)',
    )
    balance = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        verbose_name='Баланс',
    )
    USERNAME_FIELD = 'phone'
    REQUIRED_FIELDS = []

    objects = CustomUserManager()

    @property
    def login_label(self) -> str:
        """Барои профил: телефон ё @username."""
        if self.phone:
            return self.phone
        username = (self.telegram_username or '').strip().lstrip('@')
        if username:
            return f'@{username}'
        name = f'{self.first_name or ""} {self.last_name or ""}'.strip()
        if name:
            return name
        if self.telegram_id:
            return f'Telegram {self.telegram_id}'
        return f'Корбар #{self.pk}'

    def __str__(self):
        return self.login_label


class PhoneOTP(models.Model):
    phone = models.CharField(max_length=15, unique=True)
    code = models.CharField(max_length=6)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'{self.phone} - {self.code}'
