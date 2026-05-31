# Codemagic iOS — дастури ислоҳ

## Мушкил
```
No valid code signing certificates were found
```
Ин **хато дар Codemagic/Apple**, на дар git. Файлҳои SmartPay аллакай дар GitHub ҳастанд.

## Workflow-и дуруст
❌ Visual / Default workflow — signing намекунад  
✅ **iOS Release IPA** (аз `codemagic.yaml`)

## Қадамҳо дар Codemagic

### 1. App Store Connect API Key
Team settings → Integrations → App Store Connect:
- Issuer ID
- Key ID  
- Private key (.p8)

### 2. Certificate
Team settings → Code signing identities → iOS:
- **Generate certificate** (App Store Distribution)
- Bundle ID: `com.khuquqironanda.week`

### 3. Integration name
Агар ном `codemagic` нест, дар `codemagic.yaml` иваз кунед:
```yaml
app_store_connect: НОМИ_ШУМО
```

### 4. Build
Start new build → workflow **iOS Release IPA** → branch `main`

## Git
Агар `nothing to commit` — ҳама чиз аллакай push шуда. Ин хуб аст.
