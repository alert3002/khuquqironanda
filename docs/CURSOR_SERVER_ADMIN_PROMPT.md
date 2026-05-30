# Промпт барои Cursor дар сервер (Django + Admin)

## Файлҳои тағйирёфта — рӯйхати пурра

### Админка Django (`/admin/`)

| Файл | Ҳолат | Чӣ иваз шуд |
|------|--------|-------------|
| **`books/admin.py`** | **ИВАЗ** | `LegalDocumentAdmin` — қонунҳои PDF дар админ; sync PDF ба `legal_documents/` |
| `users/admin.py` | тағйир нест | — |

### Китобҳо ва бобҳо (API + модел)

| Файл | Ҳолат |
|------|--------|
| `books/models.py` | иваз — `LegalDocument` |
| `books/serializers.py` | иваз — `LegalDocumentSerializer`, `pdf_url` |
| `books/views.py` | иваз — legal documents API |
| `books/urls.py` | иваз — `legal-documents/` |
| `books/legal_docs.py` | **НАВ** |
| `books/migrations/0011_legaldocument.py` | **НАВ** — `python manage.py migrate` |
| `books/management/commands/sync_legal_documents.py` | **НАВ** |

### Корбарон ва Telegram

| Файл | Ҳолат |
|------|--------|
| `users/models.py` | иваз — `telegram_id`, `device_id`, `phone` nullable |
| `users/views.py` | иваз — SMS, `TelegramLoginView`, OAuth start/callback |
| `users/utils.py` | иваз — SMS, `verify_telegram_login` |
| `users/urls.py` | иваз — `telegram/` |
| `users/telegram_oauth.py` | **НАВ** — OIDC (ҷои widget deprecated) |
| `users/templates/users/telegram_login.html` | **НАВ** |
| `users/migrations/0007_customuser_telegram_device.py` | **НАВ** |

### Лоиҳа (core)

| Файл | Ҳолат |
|------|--------|
| `core/settings.py` | иваз — TELEGRAM_*, OTP, OSONSMS аз .env |
| `core/urls.py` | иваз — `telegram-login/`, oauth callback, legal PDF |
| `requirements.txt` | иваз — `PyJWT[crypto]` |

---

## Промпт — нусха барои Cursor дар сервер

```
Лоиҳа: Django backend https://books.1week.tj (китобҳо + админка + Telegram OAuth).

Ман ин файлҳоро аз репозитории маҳаллӣ ба сервер мегузорам. Лутфан синхрон кун, migrate иҷро кун, restart.

### 1. Админка
- books/admin.py — LegalDocumentAdmin (боркунии PDF, sync ба legal_documents/)
- Санҷиш: /admin/ → Қонунҳо / Legal documents

### 2. Китоб + бобҳо (барнома «Бобҳо»)
- books/models.py, serializers.py, views.py, urls.py
- GET /api/books/1/ бояд 200 ва JSON бо "chapters" (на 500)
- Агар 500: OperationalError books_subscriptionplan.is_active → python manage.py migrate books

### 3. Қонунҳои PDF
- books/legal_docs.py, migration 0011_legaldocument
- GET /api/legal-documents/
- /legal_documents/*.pdf ё /media/legal_documents/

### 4. Telegram (OIDC нав — widget deprecated)
Файлҳо:
- users/telegram_oauth.py (НАВ)
- users/views.py — telegram_login_page, telegram_oauth_start, telegram_oauth_callback, TelegramLoginView
- users/templates/users/telegram_login.html
- core/urls.py:
  - /telegram-login/
  - /telegram-login/oauth/start/
  - /telegram-login/oauth/callback/

.env:
TELEGRAM_BOT_TOKEN=...
TELEGRAM_BOT_USERNAME=huquqironanda_bot
TELEGRAM_CLIENT_ID=8357142087
TELEGRAM_CLIENT_SECRET=...

BotFather → Web Login / Login Widget:
- Redirect URI: https://books.1week.tj/telegram-login/oauth/callback/
- Trusted Origin: https://books.1week.tj

### 5. Корбарон
- users/models.py, migration 0007 (telegram_id, device_id)
- users/urls.py — path('telegram/', ...)
- POST /api/auth/telegram/ (legacy hash, агар лозим)

### 6. Пас аз deploy
pip install "PyJWT[crypto]>=2.8.0"
python manage.py migrate books
python manage.py migrate users
python manage.py migrate
python manage.py check
sudo systemctl restart gunicorn

### 7. Санҷиш
curl -s -o /dev/null -w "%{http_code}" https://books.1week.tj/api/books/1/
# → 200

curl -s -o /dev/null -w "%{http_code}" https://books.1week.tj/telegram-login/
# → 200

curl -s -o /dev/null -w "%{http_code}" "https://books.1week.tj/telegram-login/oauth/start/?app=1"
# → 302 (redirect ба oauth.telegram.org)

Натиҷаи санҷишҳоро хулоса кун.
```

---

## Танҳо админка — 3 файл

Агар танҳо админро мехоҳед:

1. `books/admin.py`
2. `books/models.py` (LegalDocument)
3. `books/migrations/0011_legaldocument.py` + `books/legal_docs.py`

```bash
python manage.py migrate books
```
