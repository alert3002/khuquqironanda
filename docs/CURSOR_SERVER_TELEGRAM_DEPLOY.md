# Telegram Login — deploy дар сервер (books.1week.tj)

## Файлҳо

| Файл | Амал |
|------|------|
| `users/templates/users/telegram_login.html` | Саҳифаи Widget |
| `users/views.py` | `telegram_login_page` + `TelegramLoginView` |
| `users/utils.py` | `verify_telegram_login` |
| `users/models.py` | `telegram_id`, `device_id` |
| `users/urls.py` | `POST /api/auth/telegram/` |
| `core/urls.py` | `GET /telegram-login/` |
| `core/settings.py` | `TELEGRAM_BOT_TOKEN`, `TELEGRAM_BOT_USERNAME` |
| `users/migrations/0002_auth_telegram_device.py` | `python manage.py migrate users` |

## URL-ҳо

- **Саҳифа (WebView):** `https://books.1week.tj/telegram-login/?app=1&device_id=UUID`
- **API:** `POST https://books.1week.tj/api/auth/telegram/`

## BotFather (ду хат)

1. `/setdomain` → домени Widget: **`books.1week.tj`**
2. Токенро дар `.env` гузоред:

```env
TELEGRAM_BOT_TOKEN=123456:ABC...
TELEGRAM_BOT_USERNAME=huquqironanda_bot
```

## Сервер

```bash
cd /www/wwwroot/books.payvandtrans.com
cp .env.example .env   # агар .env нест
# .env-ро пур кунед

source 7d8949bcbf85067fceda9f84a6affb6b_venv/bin/activate
python manage.py migrate users
sudo systemctl restart gunicorn   # ё ҳамон service-и шумо
```

## Санҷиш

```bash
curl -sI https://books.1week.tj/telegram-login/ | head -1
# HTTP/1.1 200 OK

curl -s -X POST https://books.1week.tj/api/auth/telegram/ \
  -H 'Content-Type: application/json' \
  -d '{"id":1,"hash":"invalid"}'
# {"error":"Маълумоти Telegram нодуруст аст"}
```

## Flutter

WebView URL:

```
https://books.1week.tj/telegram-login/?app=1&device_id=<device_uuid>
```

Handler (flutter_inappwebview):

```dart
webViewController.addJavaScriptHandler(
  handlerName: 'telegramAuth',
  callback: (args) async {
    final data = args[0] as Map;
    final token = data['token'] ?? data['hash']; // пас аз redirect: token
    // нигоҳ доштан ва пӯшидани WebView
  },
);
```

## Body-и API (пас аз Widget)

```json
{
  "id": 123456789,
  "first_name": "Имрӯз",
  "last_name": "",
  "username": "user",
  "photo_url": "https://...",
  "auth_date": 1710000000,
  "hash": "...",
  "device_id": "optional-uuid"
}
```

**Ҷавоб:**

```json
{"token": "...", "user_id": 1, "created": true}
```
