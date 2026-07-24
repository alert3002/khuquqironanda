from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import CustomUser, PhoneOTP

# 1. Танзими Админка барои Корбарон (CustomUser)
@admin.register(CustomUser)
class CustomUserAdmin(UserAdmin):
    model = CustomUser
    
    # Ин сутунҳо дар рӯйхати корбарон (ҷадвали умумӣ) нишон дода мешаванд
    list_display = ('phone', 'first_name', 'last_name', 'balance', 'is_staff', 'date_joined')
    
    # Имкони ҷустуҷӯ аз рӯи рақам ва ном
    search_fields = ('phone', 'first_name', 'last_name')
    
    # Тартиби навкунӣ (аз рӯи рақам)
    ordering = ('phone',)

    # --- ҚИСМИ МУҲИМ: ФОРМАИ ТАҒЙИРДИҲӢ (EDIT) ---
    # Дар ин ҷо мо майдони 'balance'-ро илова мекунем
    fieldsets = (
        ('Маълумоти асосӣ', {'fields': ('phone', 'password')}),
        ('Маълумоти шахсӣ', {'fields': ('first_name', 'last_name', 'balance')}), # <--- БАЛАНС ИНҶОСТ
        ('Ҳуқуқ ва Дастрасӣ', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('Санаҳо', {'fields': ('last_login', 'date_joined')}),
    )

    # Формаи иловакунии корбари нав (Add User)
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('phone', 'password'), # Вақте new user месозед, аввал танҳо инҳоро мепурсад
        }),
    )

