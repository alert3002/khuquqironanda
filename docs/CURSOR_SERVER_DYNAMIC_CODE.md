# Коди динамикӣ — ҷойгиркунӣ ва промпт барои Cursor (сервер)

## Мушкил: «Китоб ёфт нашуд»

Ин **аз Telegram вобаста нест**. Барнома китобро аз API мегирад:

```
GET https://books.1week.tj/api/books/1/
```

Агар ҷавоб 200 набошад ё кеш холӣ бошад → экрани хато.

Telegram танҳо барои **воридшавӣ** аст (`/api/auth/telegram/`, `/telegram-login/`).

---

## Кадом файл дар сервер (Django)

| Масъала | Файл | URL |
|---------|------|-----|
| **Китоб + бобҳо** | `books/models.py` (Book, Chapter) | — |
| **API китоб** | `books/views.py` → `BookViewSet` | `GET /api/books/`, `GET /api/books/{id}/` |
| **JSON китоб** | `books/serializers.py` → `BookSerializer`, `ChapterSerializer` | — |
| **Маршрутҳо** | `books/urls.py` (router `books`) | зери `path('api/', include('books.urls'))` дар `core/urls.py` |
| **Қонунҳо (PDF)** | `books/models.py` LegalDocument, `books/legal_docs.py` | `GET /api/legal-documents/` |
| **Воридшавӣ SMS** | `users/views.py` SendCode, VerifyCode | `POST /api/auth/send-code/`, `verify-code/` |
| **Воридшавӣ Telegram** | `users/views.py` TelegramLoginView, `users/utils.py` | `POST /api/auth/telegram/` |
| **Саҳифаи Telegram Widget** | `users/templates/users/telegram_login.html`, `users/views.py` telegram_login_page | `GET /telegram-login/` (дар `core/urls.py`) |
| **Танзимот** | `core/settings.py` | `TELEGRAM_BOT_TOKEN`, `TELEGRAM_BOT_USERNAME` |
| **Медиа PDF** | `MEDIA_ROOT`, `core/urls.py` | `/media/...`, `/legal_documents/...` |

---

## Кадом файл дар барнома (Flutter — `app/`)

| Масъала | Файл |
|---------|------|
| API | `app/lib/api/api_service.dart` |
| Экрани асосӣ, бобҳо | `app/lib/screens/home_screen.dart` |
| Хондани боб | `app/lib/screens/book_reader_screen.dart` |
| Қонунҳо PDF | `app/lib/screens/legal_documents_list_screen.dart` |
| Telegram | `app/lib/screens/telegram_login_screen.dart` |

---

## Промпт барои Cursor дар сервер (нусха кунед)

```
Лоиҳа: Django backend — https://books.1week.tj
Мушкил: барномаи Flutter «Китоб ёфт нашуд» нишон медиҳад.

Вазифа: таъмин кун, ки API китоб кор кунад (ин ба Telegram вобаста нест).

### Санҷишҳои зарурӣ
1. curl -s -o /dev/null -w "%{http_code}" https://books.1week.tj/api/books/
   → бояд 200
2. curl -s https://books.1week.tj/api/books/1/ | head -c 500
   → бояд JSON бо "title", "chapters" (数组 не холӣ)
3. curl -I https://books.1week.tj/telegram-login/
   → 200 (барои Telegram Login Widget)

### Файлҳои асосӣ (динамика)
- books/models.py — Book, Chapter, LegalDocument
- books/serializers.py — BookSerializer (chapters nested)
- books/views.py — BookViewSet (ReadOnly)
- books/urls.py — router.register('books', BookViewSet)
- core/urls.py — path('api/', include('books.urls'))
- users/views.py — TelegramLoginView (POST /api/auth/telegram/)
- users/views.py — telegram_login_page (GET /telegram-login/)
- users/templates/users/telegram_login.html
- core/settings.py — TELEGRAM_BOT_TOKEN, TELEGRAM_BOT_USERNAME

### Агар /api/books/1/ 500 (ҳозир ҳамин аст!)

Хатои сервер (санҷиш шуд):
```
OperationalError: no such column: books_subscriptionplan.is_active
```

**Ҳал:** дар сервер:
```bash
cd /path/to/project
source venv/bin/activate
python manage.py migrate books
python manage.py migrate users
python manage.py migrate
sudo systemctl restart gunicorn
```

Пас аз migrate:
```bash
curl -s -o /dev/null -w "%{http_code}" https://books.1week.tj/api/books/1/
# бояд 200 бошад, на 500
```

### Агар /api/books/1/ 404 ё chapters холӣ
- Дар admin Django китоб ID=1 ва бобҳо илова кун

### Агар 500-и дигар
- journalctl / логи gunicornро бин

### BotFather (дастӣ)
- /setdomain → books.1week.tj барои @huquqironanda_bot
- TELEGRAM_BOT_TOKEN дар .env

Пас аз ислоҳ: натиҷаи curl-ҳоро хулоса кун.
```

---

## Санҷиши зуд (ҳамин компютер)

```bash
curl -s -w "\nHTTP:%{http_code}\n" "https://books.1week.tj/api/books/1/" | head -c 800
```

Агар `HTTP:200` ва `"chapters":[...]` бошад — сервер дуруст; барномаро навсозӣ кунед ва ↻ Навсозӣ пахш кунед.
