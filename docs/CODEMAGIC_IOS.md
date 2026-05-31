# Codemagic iOS — ҳалли хатои private key

## Хато
```
Cannot save Signing Certificates without certificate private key
```

**Сабаб:** сертификат дар Apple (Xcode/Mac) сохта шуда, private key дар Codemagic нест.
`fetch-signing-files` аз Apple API сертификат бе private key мегирад → fail.

---

## Ҳал (як маротиба — бе ин build намешавад)

### 1. Apple Developer
[developer.apple.com](https://developer.apple.com) → **Certificates**

- **iOS Distribution**-ҳои кӯҳна → **Revoke** (ҳама, агар Codemagic истифода намекунад)

### 2. Codemagic Team settings
**Teams** → **Code signing identities** → **iOS**

1. Сертификатҳои кӯҳна → **Remove**
2. **Generate certificate** → App Store Distribution
3. Ин сертификат **бо private key** дар Codemagic нигоҳ дошта мешавад

### 3. Codemagic App settings
**Distribution** → **iOS code signing**

| Танзим | Қимат |
|--------|--------|
| Automatic | On |
| API key | huquqironanda |
| App Store | ✅ |
| Bundle ID | Khuquqi Ronanda / tj.book.books |

**Save**

### 4. Build
**Start new build** → Default Workflow → `main`

yaml **бе `fetch-signing-files`** — танҳо сертификати Codemagic Team.

---

## Bundle ID
- iOS: `tj.book.books`
- Android: `com.khuquqironanda.week`
- Flutter project: папка `app/`

## Build number
TestFlight охирин: **24** → дар `app/pubspec.yaml` бояд **+25** ё болотар.
