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

```bash
cd app
flutter pub get
flutter build ipa --release
```

**codemagic.yaml лозим нест.**

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

TestFlight охирин: **24** → `app/pubspec.yaml` **+26** ё болотар.
