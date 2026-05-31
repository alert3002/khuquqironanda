# Codemagic iOS — як маротиба инро анҷом диҳед

## 3 хато, 3 ҳал

| Хато | Ҳал |
|------|-----|
| `No matching profiles` | Profile дар Apple нест → қадами 3 |
| `No private key` | Сертификат дар Xcode/Mac → қадами 1-2 |
| `requires provisioning profile` | Profile ба Xcode татбиқ нашуд → yaml нав |

---

## ҚАДАМ 1 — Apple Developer (5 дақиқа)

[developer.apple.com/account/resources/certificates/list](https://developer.apple.com/account/resources/certificates/list)

1. **Certificates** → **iOS Distribution**-ҳои кӯҳна → **Revoke**
2. **Identifiers** → бояд **`tj.book.books`** бошад (агar не → **+** → App IDs → `tj.book.books`)

---

## ҚАДАМ 2 — Codemagic Team (2 дақиқа)

[codemagic.io](https://codemagic.io) → **Teams** → **Code signing identities** → **iOS**

1. Сертификатҳои кӯҳна → **Remove**
2. **Generate certificate** → App Store Distribution
3. ✅ Private key дар Codemagic нигоҳ дошта мешавад

---

## ҚАДАМ 3 — Provisioning Profile (3 дақиқа)

[developer.apple.com/account/resources/profiles/list](https://developer.apple.com/account/resources/profiles/list)

1. **+** → **App Store Connect**
2. App ID: **tj.book.books**
3. Certificate: сертификати нав (қадами 2)
4. **Generate** → Download (ихтиёрӣ)

---

## ҚАДАМ 4 — Build

Codemagic → **Start new build** → **Default Workflow** → `main`

---

## Дар log бояд бинед

```
Load team certificate → Apple Distribution ✅
Fetch provisioning profile ✅
Profile: [ном] ✅
Build IPA ✅
```

---

## Distribution (Visual) — тағйир надиҳед

Automatic + huquqironanda + App Store + Khuquqi Ronanda ✅

---

## Android (локалӣ)

```powershell
cd C:\Users\ALIJOn\Desktop\books\app
flutter build appbundle --release
```

Bundle ID Android: `com.khuquqironanda.week`
