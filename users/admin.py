from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import CustomUser, PhoneOTP


@admin.register(CustomUser)
class CustomUserAdmin(UserAdmin):
    model = CustomUser

    list_display = (
        'login_label',
        'phone',
        'telegram_username',
        'telegram_id',
        'first_name',
        'last_name',
        'balance',
        'is_staff',
        'date_joined',
    )
    list_display_links = ('login_label', 'phone')
    search_fields = (
        'phone',
        'telegram_username',
        'telegram_id',
        'first_name',
        'last_name',
    )
    ordering = ('-date_joined',)

    fieldsets = (
        ('Маълумоти асосӣ', {'fields': ('phone', 'password')}),
        (
            'Telegram',
            {'fields': ('telegram_id', 'telegram_username')},
        ),
        ('Маълумоти шахсӣ', {'fields': ('first_name', 'last_name', 'balance')}),
        (
            'Ҳуқуқ ва Дастрасӣ',
            {
                'fields': (
                    'is_active',
                    'is_staff',
                    'is_superuser',
                    'groups',
                    'user_permissions',
                ),
            },
        ),
        ('Санаҳо', {'fields': ('last_login', 'date_joined')}),
    )

    add_fieldsets = (
        (
            None,
            {
                'classes': ('wide',),
                'fields': ('phone', 'password'),
            },
        ),
    )


@admin.register(PhoneOTP)
class PhoneOTPAdmin(admin.ModelAdmin):
    list_display = ('phone', 'code', 'updated_at')
    search_fields = ('phone',)
