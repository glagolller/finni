# FINNI: APK после UI-feedback, 26.09.2026

Это предыдущая сборка. [Новый APK каталога и взрослого раздела](FINNI_CATALOG_BUILD_HANDOFF.md).

Ветка: `logic/android-ui-feedback`. База: `frontend/service-integration`.
PR: https://github.com/glagolller/finni/pull/8
Коммит APK: `8e8d50baf4ce9835af0c2e5eb759eed031fcb67b`.
Обновление получено fast-forward merge в существующем репозитории.
Контракт RC2.1, экономика, SQLite, контент, зависимости и Android не изменялись.
Экраны и UI-тесты реализованы стороной интерфейса. Tutorial/миссии не добавлялись.

## Новый файл

`C:/Users/fpp/Documents/ChatGPT/хакатон/finni/delivery/finni-ui-feedback-debug.apk`

Размер: 171881005 байт.
SHA-256: `b1af4d39022c666c6fdd91da864940252bf50039ec57722aeb250e0bcf2e74ba`.
Исходный результат: `build/app/outputs/flutter-apk/app-debug.apk`.
APK локальный, исключён из Git; участнику передать сам файл отдельно.

## Обновление с сохранением питомца

До пересборки проверена подпись старого APK с хешем
`39c08fd69e22708eb9e545e3d15cc3f03f60997ffec13e637bf5dbe36ba9a7be`.
После пересборки проверена подпись нового APK. SHA-256 сертификата обоих одинаков:
`9c37926302ddd662d4202e2546ffb0f21d714952ba301a909b89d8145e369af1`.

apksigner: Verifies, схема v2. Package `ru.finni.pet`, versionName `0.1.0`,
versionCode `1` сохранены. minSdk 26, targetSdk 36.
Условия обновления поверх прежней debug-установки соблюдены; физическая проверка
сохранения данных после обновления ещё не выполнена.

Открыть APK на Samsung и выбрать обновление. Не удалять приложение и не очищать
данные. Если установка отклонена, передать точный текст ошибки; сначала сохранить
доказательства и согласовать дальнейшие действия. Через USB:

```powershell
adb -s SERIAL install -r delivery/finni-ui-feedback-debug.apk
```

Одинаковый versionCode оставлен для повторной debug-установки. Различать APK по
SHA-256 и интерфейсу. Release готовить после приёмки обновлённого UI.

## Команды и результаты

```powershell
$env:JAVA_HOME = 'C:/Users/fpp/.cache/finni/jdk-17.0.20.1/jdk-17.0.20.1+1'
$env:ANDROID_HOME = 'C:/Users/fpp/.cache/finni/android-sdk'
$env:PATH = "$env:JAVA_HOME/bin;C:/Users/fpp/.cache/finni/flutter-3.47.5/flutter/bin;$env:ANDROID_HOME/platform-tools;$env:PATH"
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub --target lib/main.dart
```

Команды выполнены из ASCII-junction на тот же checkout.
Analyzer: 0 issues. Tests: 20/20, включая пять периодов и новые UI-проверки.
assembleDebug: успешно, 78.6 секунды. Подпись и aapt-метаданные проверены.
Предупреждение SDK XML v4/v3 сохранилось, сборку не остановило.
adb devices -l: пусто. Установка и запуск нового APK на телефоне не проверены.

Toolchain: Flutter 3.47.5 / Dart 3.13.4, JDK 17.0.20.1, Gradle 9.3.1,
AGP 9.1.0, Kotlin plugin 2.4.0, API 36, Build Tools 36.0.0,
NDK 28.2.13676358, platform-tools 37.0.1.

## Проверка Samsung

По отчёту Ф на старом APK подтверждены Android 16, установка, 100 монет,
офлайн-перезапуск и первый период 30/30 с 3 баллами. Это не проверка нового APK.

1. Перед обновлением записать питомца, период и балансы; после обновления сравнить.
2. Проверить inline-подтверждения, отдельный жёлтый результат и понятность план/факт.
3. Изменить сумму после preview, проверить новое подтверждение и защиту от двойного нажатия.
4. Проверить Back, клавиатуру, крупный текст, настройки и офлайн-перезапуск.
5. Пройти пять периодов: 5 доступно, 25 в копилке, 15 баллов, grown.

Полные пять периодов на физическом устройстве пока не подтверждены.
