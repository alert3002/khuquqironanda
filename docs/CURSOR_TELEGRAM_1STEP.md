# Telegram — 1 қадам (промпт барои Cursor сервер)

## Мушкил
WebView `tg://` намедонад → 5 экран. Ҳал: OAuth дар **браузери берун** + баргашт `khuquqironanda://auth?token=...`

---

## ПРОМПТ (нусха ба Cursor сервер)

```
Telegram login — 1 қадам барои барномаи Flutter.

=== users/telegram_oauth.py ===
Илова кун функсия:

def app_auth_redirect_url(*, token: str = '', error: str = '') -> str:
    scheme = getattr(settings, 'TELEGRAM_APP_CALLBACK_SCHEME', 'khuquqironanda')
    if token:
        return f'{scheme}://auth?{urlencode({"token": token})}'
    if error:
        return f'{scheme}://auth?{urlencode({"error": error})}'
    return f'{scheme}://auth'

=== users/views.py — telegram_oauth_callback ===
Пас аз сохтани token, агар stored['app'] == True:
    return redirect(app_auth_redirect_url(token=token.key))
На веб-саҳифаи /telegram-login/?success=...

Дар ҳамаи хатоҳо (oauth_error, invalid_state, exception):
    if app_mode: return redirect(app_auth_redirect_url(error=...))

=== core/settings.py ===
TELEGRAM_APP_CALLBACK_SCHEME = os.environ.get('TELEGRAM_APP_CALLBACK_SCHEME', 'khuquqironanda')

=== BotFather (бе тағйир) ===
Redirect URI: https://books.1week.tj/telegram-login/oauth/callback/
Trusted Origin: https://books.1week.tj

.env: TELEGRAM_CLIENT_ID, TELEGRAM_CLIENT_SECRET, TELEGRAM_BOT_TOKEN

=== Restart ===
sudo systemctl restart gunicorn

=== Санҷиш ===
/oauth/start/?app=1 → redirect ба oauth.telegram.org
Пас аз login → redirect ба khuquqironanda://auth?token=...
```

---

## Flutter (аллакай дар репо)

- `login_screen.dart` — 1 тугма, бе WebView
- `telegram_auth_launcher.dart` + `app_links`
- Android: intent-filter `khuquqironanda://auth`
- iOS: CFBundleURLSchemes

`flutter pub get` ва rebuild APK.
