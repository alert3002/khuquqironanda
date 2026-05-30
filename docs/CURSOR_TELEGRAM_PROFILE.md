# Промпт: телефон / @Telegram дар профил (Cursor сервер)

Telegram login кор мекунад, аммо дар профил танҳо «+992» намоиш дода мешуд.
Сабаб: phone холӣ буд, formatter ҳамеша +992 мезод.

---

## ПРОМПТ (нусха кунед)

```
Telegram login кор мекунад. Дар профил бояд рақам ё @username намоиш дода шавад.

=== 1. users/models.py ===
Илова кун:
    telegram_username = models.CharField(max_length=64, blank=True, default='', verbose_name='Telegram @username')

@property login_label — phone ё @username ё Telegram ID

=== 2. Migration ===
users/migrations/0008_customuser_telegram_username.py
python manage.py migrate users

=== 3. users/utils.py ===
- normalize_phone_number(raw)
- apply_telegram_profile(user, claims=..., widget_data=...)
  Аз JWT: preferred_username, phone_number, name
  Аз widget: username, first_name, last_name

=== 4. users/telegram_oauth.py ===
scope: 'openid profile phone'  (phone барои phone_number дар JWT)

=== 5. users/views.py ===
telegram_oauth_callback ва TelegramLoginView:
  user, _ = User.objects.update_or_create(telegram_id=..., ...)
  apply_telegram_profile(user, claims=claims)  # ё widget_data=data

=== 6. users/serializers.py ===
UserSerializer fields:
  telegram_id, telegram_username, login_label (SerializerMethodField)

=== 7. users/admin.py ===
list_display: phone, telegram_username, telegram_id
fieldsets: бахши Telegram

=== Restart ===
sudo systemctl restart gunicorn

=== Санҷиш ===
Пас аз воридшавии нав бо Telegram:
GET /api/auth/profile/ (бо token)
→ phone ё telegram_username ё login_label

/admin/ → Корбарон → телефон ё @username пур бошад
```

---

## Эзоҳ барои корбар

- Агар телефон дар Telegram иҷозат дода нашавад → @username намоиш дода мешавад
- Барои намоиши рақам: дар воридшавӣ «Share phone number»-ро интихоб кунед
- Корбарони қадим: як бор аз нав Telegram login кунанд
