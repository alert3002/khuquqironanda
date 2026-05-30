# Промпт барои Cursor дар сервер (пурра — бе гузоштани ҳамаи код)

Ман ҳамаи кодро ба сервер гузаронида наметавонам. Лутфан тағйиротҳоро **дар ҷои худ** иҷро кун.

Лоиҳа: Django `https://books.1week.tj`  
Масир: `/var/www/books` (ё ҳар ҷое ки `manage.py` аст)

---

## ПРОМПТ (нусха кунед ба Cursor сервер)

```
Ман кодро пурра upload карда наметавонам. Лутфан ин тағйиротҳоро дар сервери Django иҷро кун —
файлҳоро хон, илова/тағйир диҳ, migrate кун, restart.

=== 1. MIGRATE (аввал инро санҷ) ===
python manage.py migrate books
python manage.py migrate users
python manage.py migrate
pip install "PyJWT[crypto]>=2.8.0"

Хатои маъмул: no such column books_subscriptionplan.is_active → migrate books иҷро нашуда.

=== 2. АДМИНКА — books/admin.py ===

A) AboutPageAdmin — fieldsets бо дастурамали харид:
@admin.register(AboutPage)
class AboutPageAdmin(admin.ModelAdmin):
    list_display = ('title', 'updated_at')
    search_fields = ('title',)
    fieldsets = (
        ('Дар бораи мо', {
            'fields': ('title', 'content', 'phone', 'email', 'telegram_url', 'whatsapp_url'),
        }),
        ('Дастурамал: харид ва обуна (барнома)', {
            'fields': ('purchase_guide_title', 'purchase_guide_content'),
            'description': 'Нархҳо аз «Нақшаҳои обуна» (SubscriptionPlan) гирифта мешаванд.',
        }),
    )

B) LegalDocumentAdmin (агар нест) — қонунҳои PDF:
- list_display: order, title, save_model sync PDF ба legal_documents/

=== 3. МОДЕЛ — books/models.py ===

AboutPage — илова кун:
    purchase_guide_title = models.CharField(
        max_length=200, blank=True,
        default='Чӣ тавр харидан мумкин аст',
        verbose_name='Сарлавҳаи дастурамал (харид)',
    )
    purchase_guide_content = RichTextUploadingField(
        verbose_name='Дастурамал: чӣ тавр харидан', blank=True,
    )

LegalDocument — агар нест, модел барои PDF-ҳои «Қоидаҳои ҳаракат».

=== 4. MIGRATION НАВ ===

books/migrations/0012_aboutpage_purchase_guide.py — AddField purchase_guide_title, purchase_guide_content
(агар 0011_legaldocument нест, аввал онро эҷод кун)

=== 5. SERIALIZER — books/serializers.py ===

AboutPageSerializer fields илова:
    'purchase_guide_title', 'purchase_guide_content',

=== 6. API — books/views.py ===

AboutPageView — дар Response холӣ илова:
    'purchase_guide_title': 'Чӣ тавр харидан мумкин аст',
    'purchase_guide_content': '',

BookViewSet — GET /api/books/1/ бояд chapters + plans баргардонад.

=== 7. TELEGRAM OAuth (deprecated widget → OIDC) ===

Файлҳои НАВ/тағйир:
- users/telegram_oauth.py (НАВ)
- users/views.py: telegram_login_page, telegram_oauth_start, telegram_oauth_callback, TelegramLoginView
- users/templates/users/telegram_login.html — тугма → /telegram-login/oauth/start/
- core/urls.py:
    path('telegram-login/', ...)
    path('telegram-login/oauth/start/', ...)
    path('telegram-login/oauth/callback/', ...)
- users/urls.py: path('telegram/', TelegramLoginView)
- users/models.py: telegram_id, device_id
- users/migrations/0007_customuser_telegram_device.py

core/settings.py:
TELEGRAM_BOT_TOKEN = os.environ.get('TELEGRAM_BOT_TOKEN', '').strip()
TELEGRAM_BOT_USERNAME = os.environ.get('TELEGRAM_BOT_USERNAME', 'huquqironanda_bot').strip()
TELEGRAM_CLIENT_ID = os.environ.get('TELEGRAM_CLIENT_ID', '').strip()
TELEGRAM_CLIENT_SECRET = os.environ.get('TELEGRAM_CLIENT_SECRET', '').strip()

.env:
TELEGRAM_CLIENT_ID=8357142087
TELEGRAM_CLIENT_SECRET=...
TELEGRAM_BOT_TOKEN=...
TELEGRAM_BOT_USERNAME=huquqironanda_bot

BotFather → Web Login:
Redirect URI: https://books.1week.tj/telegram-login/oauth/callback/
Trusted Origin: https://books.1week.tj

=== 8. ҚОНУНҲО PDF ===
- books/legal_docs.py
- books/migrations/0011_legaldocument.py
- GET /api/legal-documents/
- core/urls.py: serve legal_documents PDF

=== 9. ПАС АЗ ТАҒЙИРОТ ===
python manage.py makemigrations books  # агар migration нест
python manage.py migrate
python manage.py check
sudo systemctl restart gunicorn

=== 10. САНҶИШ ===
curl -s -o /dev/null -w "%{http_code}" https://books.1week.tj/api/books/1/
→ 200

curl -s https://books.1week.tj/api/books/about/ | head -c 400
→ бояд purchase_guide_title, purchase_guide_content дошта бошад

curl -s -o /dev/null -w "%{http_code}" https://books.1week.tj/telegram-login/
→ 200

/admin/ → «Дар бораи мо» → бахши «Дастурамал: харид ва обуна»
/admin/ → «Нақшаҳои обуна» → нархҳо барои барнома

Хулоса: чӣ иваз шуд, чӣ migrate шуд, натиҷаи curl.
```

---

## Рӯйхати файлҳо (барои Cursor — кадомро тағйир диҳад)

| Файл | Амал |
|------|------|
| `books/admin.py` | AboutPage fieldsets + LegalDocumentAdmin |
| `books/models.py` | AboutPage purchase_guide_* + LegalDocument |
| `books/serializers.py` | AboutPageSerializer, LegalDocumentSerializer, BookSerializer |
| `books/views.py` | AboutPageView, LegalDocuments, BookViewSet |
| `books/urls.py` | legal-documents routes |
| `books/legal_docs.py` | **нав** |
| `books/migrations/0011_legaldocument.py` | **нав** |
| `books/migrations/0012_aboutpage_purchase_guide.py` | **нав** |
| `users/models.py` | telegram_id, device_id |
| `users/views.py` | SMS + Telegram OAuth |
| `users/utils.py` | verify_telegram_login |
| `users/telegram_oauth.py` | **нав** |
| `users/urls.py` | telegram/ |
| `users/templates/users/telegram_login.html` | **нав** |
| `users/migrations/0007_*.py` | **нав** |
| `core/settings.py` | TELEGRAM_*, OTP |
| `core/urls.py` | telegram-login, legal PDF |
| `requirements.txt` | PyJWT[crypto] |

---

## Дар админка пас аз deploy чӣ пур кунед

1. **Дар бораи мо** → «Дастурамал: харид ва обуна» — матни қадамҳо
2. **Нақшаҳои обуна** — ном, нарх (сомонӣ), рӯзҳо, фаъол
3. **Қонунҳо / Legal documents** — PDF-ҳо (агар лозим)

Барнома (Flutter) ин маълумотро аз API мегирад — сервер танҳо бояд API дуруст баргардонад.
