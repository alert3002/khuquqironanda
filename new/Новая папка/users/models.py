from django.db import models
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