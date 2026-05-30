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
    telegram_id = models.BigIntegerField(
        unique=True,
        null=True,
        blank=True,
        verbose_name='Telegram ID',
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

    def __str__(self):
        if self.phone:
            return self.phone
        if self.telegram_id:
            return f'tg:{self.telegram_id}'
        return f'user:{self.pk}'


class PhoneOTP(models.Model):
    phone = models.CharField(max_length=15, unique=True)
    code = models.CharField(max_length=6)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'{self.phone} - {self.code}'
