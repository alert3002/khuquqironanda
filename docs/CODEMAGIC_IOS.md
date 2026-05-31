# Codemagic iOS — Workflow UI (бе codemagic.yaml)

## Мушкил
```
No valid code signing certificates were found
```
Ин дар **Codemagic → Code signing**, на дар git.  
`win32_registry`, `xml`, SPM — warning, build-ро вайрон намекунанд.

## Мушкил 2 — build аз реша, на аз app/
Агар дар log бинед `Archiving com.khuquqironanda.week...` — Codemagic папкаи `app/`-ро намехонад.
Дар script **`cd app`** зарур аст.

---

## Workflow-и Visual (монанди версияи 1)

### 1. Distribution → iOS code signing
| Танзим | Қимат |
|--------|--------|
| Code signing | **On** / Automatic |
| Distribution type | **App Store** |
| Bundle identifier | `tj.book.books` |

### 2. Team settings → Integrations
**App Store Connect API key** (.p8) бояд илова шуда бошад.

### 3. Team settings → Code signing identities → iOS
- **Generate certificate** (App Store Distribution)
- ё **Fetch certificate** (агар expired шуда бошад)

### 4. Build scripts (2 қадам — муҳим!)

**Script 1 — Code signing** (пеш аз build):
```bash
cd app
keychain initialize
app-store-connect fetch-signing-files "tj.book.books" \
  --type IOS_APP_STORE \
  --create
keychain add-certificates
xcode-project use-profiles
```

**Script 2 — Build IPA**:
```bash
cd app
flutter pub get
flutter build ipa --release
```

⚠️ **`cd app` зарур аст** — Flutter дар папкаи `app/`, на дар реша.

### 5. Start build
Workflow-и **Visual** → branch `main` → Start.

---

## Git
```powershell
cd C:\Users\ALIJOn\Desktop\books
git add .
git commit -m "Your message"
git push origin main
```
Агар `nothing to commit` — ҳама аллакай дар GitHub аст.

---

## Android (локалӣ)
```powershell
cd C:\Users\ALIJOn\Desktop\books\app
flutter build appbundle --release
```
