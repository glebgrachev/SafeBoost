# SafeBoost — Памятка сборки и деплоя iOS

## Одноразовая настройка (делается один раз)

### 1. Apple Developer
- Создать App ID с capability **Network Extensions**
- Создать Distribution сертификат через Codemagic (не через Apple напрямую!)
- Создать Provisioning Profile типа **App Store** привязанный к сертификату Codemagic

### 2. App Store Connect API ключ
- appstoreconnect.apple.com → Users and Access → Integrations → App Store Connect API
- Создать ключ с правами **App Manager**
- Скачать `.p8` — только один раз!
- Записать **Issuer ID** и **Key ID**

### 3. Codemagic
- Создать приложение через **codemagic.yaml** режим (не Flutter Workflow Editor!)
- Team settings → Code signing identities → загрузить сертификат `.p12` с паролем
- Загрузить Provisioning Profile `.mobileprovision`
- Environment variables → группа `app_store`:
  - `APP_STORE_CONNECT_ISSUER_ID`
  - `APP_STORE_CONNECT_KEY_IDENTIFIER`
  - `APP_STORE_CONNECT_PRIVATE_KEY` (содержимое `.p8`)

### 4. Проект Flutter
`ios/Runner.xcodeproj/project.pbxproj` — прописать:
- `DEVELOPMENT_TEAM = JGB45NH7DY`
- `CODE_SIGN_IDENTITY[sdk=iphoneos*] = "iPhone Distribution"`
- `TARGETED_DEVICE_FAMILY = "1"` (только iPhone)

`ios/Runner/Info.plist` — добавить:
```xml
<key>UIDeviceFamily</key>
<array>
    <integer>1</integer>
</array>
```

---

## Сборка и деплой (каждый раз)

**1. Увеличить build number в `pubspec.yaml`:**
```
version: 1.0.0+N  (N увеличивать на 1 каждый раз)
```

**2. Редактировать файлы только в VSCode** — не через PowerShell команды!  
Иначе добавится BOM и сборка упадёт.

**3. Закоммитить и запушить:**
```powershell
git add .
git commit -m "release build N"
git push
```

**4. Codemagic → Start new build → branch: main → workflow: ios-release**

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
| `Unable to decode the provided data` | Неверный пароль `.p12` или повреждён | Перегенерировать сертификат в Codemagic |
| `Invalid character \xEF` | BOM в `project.pbxproj` | Редактировать только в VSCode |
| `Bundle version must be higher` | Не увеличили build number | Увеличить `+N` в `pubspec.yaml` |
| `No matching profiles found` | Используется Flutter Workflow Editor | Пересоздать приложение в yaml режиме |
| `ClassNotFoundException MainActivity` | Неверный package в kotlin файле | Проверить `android/app/src/main/kotlin/` |
| `Failed to set code signing for macos` | macOS проект мешает | Убрать `--project` флаг из `use-profiles` |

---

## Важные данные

- **Bundle ID**: com.safeboost.app
- **Team ID**: JGB45NH7DY
- **Provisioning Profile**: SafeBoost AppStore
- **Certificate reference**: SafeBoost AppStore
- **Keystore Android**: android/app/safeboost.jks, alias: safeboost
- **Репозиторий**: https://github.com/glebgrachev/SafeBoost.git
