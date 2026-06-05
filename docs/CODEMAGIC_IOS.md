# Codemagic iOS — Visual Workflow

## Bundle ID (Apple Developer)

**iOS (App Store / TestFlight):**
```
com.bookkhuquqronanda.week
```

**Android (Google Play):**
```
com.khuquqironanda.week
```

---

## Codemagic Distribution

| Танзим | Қимат |
|--------|--------|
| Automatic | On |
| API key | huquqironanda |
| App Store | ✅ |
| **Bundle identifier** | **com.bookkhuquqronanda.week** |

⚠️ `tj.book.books` **хато** буд — аз ҳамин signing fail мешуд.

---

## Build script (Visual)

**⚠️ МУХИМ:** Codemagic бояд аз папкаи `app/` build гирад, на аз root!

```bash
cd app
flutter pub get
flutter build ipa --release
```

Агар `cd app` набошад, root `pubspec.yaml` (`+8`) истифода мешавад ва App Store upload fail мешавад.

Дар repo `codemagic.yaml` ҳам ҳаст — workflow `ios-release`.

**codemagic.yaml лозим нест** (Visual Workflow ҳам мешавад), аммо `cd app` ҳатман!

---

## Git push

```powershell
cd C:\Users\ALIJOn\Desktop\books
git add .
git commit -m "Fix iOS bundle ID: com.bookkhuquqronanda.week (match Apple)"
git push origin main
```

---

## Build number

TestFlight охирин: **8** (root build) → `app/pubspec.yaml` **+29** ё болотар.

Формат: `version: 2.1.5+29` — рақами баъди `+` = CFBundleVersion (build number).
