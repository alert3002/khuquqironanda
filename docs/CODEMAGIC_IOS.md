# Codemagic iOS — Visual Workflow (монанди версияи 1)

## ⚠️ codemagic.yaml НЕст — Visual workflow истифода баред

yaml workflow `.p12` сертификат мехоҳад. TestFlight версияи 1 бо **Visual + Automatic** кор карда буд.

---

## Танзимот (Codemagic UI)

### 1. Workflow-и Visual (на yaml!)
App → **Workflow Editor** → **Default Workflow** (Visual)

### 2. Distribution → iOS code signing
| | |
|--|--|
| Automatic | ✅ On |
| API key | huquqironanda |
| App Store | ✅ |
| Bundle ID | Khuquqi Ronanda (tj.book.books) |

### 3. Build scripts — ТАНHО ин як script

**Script-ҳои keychain / fetch-signing-files-ро DELETE кунед.**

```bash
cd app
flutter pub get
flutter build ipa --release
```

### 4. Flutter project path (агar бошад)
**Build** → Flutter project directory: **`app`**

### 5. Start build → main

---

## Дар log бояд бинед

```
Building tj.book.books...
Archiving tj.book.books...
```

**НЕ** `com.khuquqironanda.week`

---

## Build number

TestFlight охирин: **24** → `app/pubspec.yaml`:

```yaml
version: 2.1.2+25
```

---

## Android (локалӣ)

```powershell
cd C:\Users\ALIJOn\Desktop\books\app
flutter build appbundle --release
```

---

## Агар Visual workflow боз fail шавад

**Teams** → **Code signing identities** → **iOS** → **Generate certificate**

Баъд Distribution Automatic-ро такрор санҷед.
