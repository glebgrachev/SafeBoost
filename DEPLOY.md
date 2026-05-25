# SafeBoost — Памятка сборки и деплоя iOS

## Хранилище ключей

Все ключи хранятся на **Google Drive → Проекты → SafeBoost → Ключи → Новые ключи для подписания 25.05.26**:

| Файл | Описание | Где используется |
|------|----------|-----------------|
| `safeboost_distribution (1).p12` | Distribution сертификат с приватным ключом | Codemagic → Code signing identities |
| `SafeBoost_AppStore (1).mobileprovision` | Provisioning Profile для App Store | Codemagic → Code signing identities |
| `AuthKeyT2L3M93GBL.p8` | App Store Connect API ключ | Codemagic → Environment variables |

**Пароль от `.p12`**: `gIg13A7I` (хранить надёжно!)

---

## Аккаунты и идентификаторы

| Параметр | Значение |
|----------|----------|
| Apple Developer Team ID | `JGB45NH7DY` |
| Bundle ID | `com.safeboost.app` |
| App Store Connect API Key ID | `T2L3M93GBL` |
| App Store Connect API Key Name | `Codemagic` |
| App Store Connect Issuer ID | `f40eff60-94e6-42b3-bcaf-5857b7a53f77` |
| Provisioning Profile Name | `SafeBoost AppStore` |
| Certificate Reference в Codemagic | `SafeBoost AppStore` |
| Android Keystore | `android/app/safeboost.jks` |
| Android Key Alias | `safeboost` |

---

## Одноразовая настройка (делается один раз)

### 1. Apple Developer — developer.apple.com

**App ID:**
- Certificates, Identifiers & Profiles → Identifiers → +
- Bundle ID: `com.safeboost.app`
- Capabilities: включить **Network Extensions**

**Distribution сертификат:**
- НЕ создавать вручную в Apple Developer
- Создавать через Codemagic → Code signing identities → Generate certificate
- Тип: `Apple Distribution`, API key: `Codemagic`
- **Сразу скачать `.p12` и сохранить пароль** — показывается только один раз
- Сохранить как `safeboost_distribution (1).p12` на Google Drive

**Provisioning Profile:**
- Certificates, Identifiers & Profiles → Profiles → +
- Тип: **App Store Connect** (Distribution)
- App ID: `com.safeboost.app`
- Certificate: выбрать сертификат созданный через Codemagic (дата до мая 2027)
- Name: `SafeBoost AppStore`
- Скачать и сохранить как `SafeBoost_AppStore (1).mobileprovision` на Google Drive

### 2. App Store Connect API ключ — appstoreconnect.apple.com

- Users and Access → Integrations → App Store Connect API → +
- Name: `Codemagic`
- Access: **App Manager**
- Нажать Generate → скачать `.p8` файл — **только один раз!**
- Записать **Issuer ID** и **Key ID**
- Сохранить как `AuthKeyT2L3M93GBL.p8` на Google Drive

### 3. Codemagic — codemagic.io

**Создание приложения:**
- Add application → выбрать репозиторий SafeBoost
- Тип: **codemagic.yaml** (НЕ Flutter Workflow Editor!)

**Загрузка сертификата:**
- Team settings → Code signing identities → iOS certificates
- Upload → загрузить `safeboost_distribution (1).p12`
- Пароль: `gIg13A7I`
- Reference name: `SafeBoost AppStore`

**Загрузка профиля:**
- Team settings → Code signing identities → iOS provisioning profiles
- Upload → загрузить `SafeBoost_AppStore (1).mobileprovision`
- Reference name: `SafeBoost AppStore`

**Environment variables:**
- В приложении → Environment variables → создать группу `app_store`
- Добавить три переменные (все отметить как Secret):

| Переменная | Значение |
|------------|----------|
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID из App Store Connect |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | `T2L3M93GBL` |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Содержимое `AuthKeyT2L3M93GBL.p8` целиком |

### 4. Проект Flutter — настройки подписания

**Редактировать только в VSCode (не через PowerShell!)**

`ios/Runner.xcodeproj/project.pbxproj` — найти и установить:
```
DEVELOPMENT_TEAM = JGB45NH7DY;
CODE_SIGN_IDENTITY[sdk=iphoneos*] = "iPhone Distribution";
TARGETED_DEVICE_FAMILY = "1";
```

`ios/Runner/Info.plist` — добавить перед `</dict>`:
```xml
<key>UIDeviceFamily</key>
<array>
    <integer>1</integer>
</array>
```

---

## Сборка и деплой (каждый раз)

**1. Увеличить build number в `pubspec.yaml`:**
```yaml
version: 1.0.0+N  # N увеличивать на 1 каждый раз
```

**2. Редактировать файлы только в VSCode** — не через PowerShell!
Иначе добавится BOM (`\xEF`) и сборка упадёт.

**3. Закоммитить и запушить:**
```powershell
git add .
git commit -m "release build N"
git push
```

**4. Codemagic → Start new build → branch: main → workflow: ios-release**

**5. После успешной сборки** — IPA автоматически загружается в App Store Connect → TestFlight

---

## Рабочий codemagic.yaml

```yaml
workflows:
  ios-release:
    name: iOS Release
    max_build_duration: 60
    environment:
      flutter: stable
      groups:
        - app_store
      ios_signing:
        provisioning_profiles:
          - SafeBoost AppStore
        certificates:
          - SafeBoost AppStore
    scripts:
      - name: Get Flutter packages
        script: flutter pub get
      - name: Set up code signing
        script: xcode-project use-profiles
      - name: Build iOS
        script: |
          flutter build ipa --release \
            --export-options-plist=/Users/builder/export_options.plist
      - name: Create export options
        script: |
          cat > /Users/builder/export_options.plist << EOF
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
            <key>method</key>
            <string>app-store</string>
            <key>teamID</key>
            <string>JGB45NH7DY</string>
            <key>provisioningProfiles</key>
            <dict>
              <key>com.safeboost.app</key>
              <string>SafeBoost AppStore</string>
            </dict>
          </dict>
          </plist>
          EOF
    artifacts:
      - build/ios/ipa/*.ipa
    publishing:
      app_store_connect:
        api_key: $APP_STORE_CONNECT_PRIVATE_KEY
        key_id: $APP_STORE_CONNECT_KEY_IDENTIFIER
        issuer_id: $APP_STORE_CONNECT_ISSUER_ID
        submit_to_testflight: false
```

---

## Частые ошибки

| Ошибка | Причина | Решение |
|--------|---------|---------|
| `Unable to decode the provided data` | Повреждён `.p12` или неверный пароль | Перегенерировать сертификат в Codemagic, сохранить новый `.p12` |
| `Invalid character \xEF` | BOM в `project.pbxproj` | Редактировать только в VSCode |
| `Bundle version must be higher` | Не увеличили build number | Увеличить `+N` в `pubspec.yaml` |
| `No matching profiles found` | Используется Flutter Workflow Editor | Пересоздать приложение в yaml режиме |
| `ClassNotFoundException MainActivity` | Неверный package в kotlin файле | Проверить `android/app/src/main/kotlin/com/safeboost/app/MainActivity.kt` |
| `Failed to set code signing for macos` | macOS проект мешает | Убрать `--project` флаг из `use-profiles` |
| `fetch-signing-files` запускается автоматически | Flutter Workflow Editor перехватывает | Пересоздать приложение через codemagic.yaml режим |

---

## Обновление сертификата (раз в год)

Сертификат истекает **24 мая 2027 года**. За месяц до истечения:

1. Codemagic → Code signing identities → удалить старый сертификат
2. Generate new certificate → скачать новый `.p12` → сохранить на Google Drive
3. Apple Developer → Profiles → Edit `SafeBoost AppStore` → выбрать новый сертификат → Save → Download
4. Codemagic → загрузить новый `.mobileprovision`
5. Запустить новую сборку

---

## Репозиторий

```
https://github.com/glebgrachev/SafeBoost.git
```
