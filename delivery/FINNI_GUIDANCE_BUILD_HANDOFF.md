# FINNI: подсказки главной, debug и release-кандидат

Дата: 26.09.2026. Ветка `logic/android-guidance-release`.
База PR: `frontend/service-integration`. PR: https://github.com/glagolller/finni/pull/10
Коммит обоих APK: `5eb1095fe7803477cfc3244f21394ce5af7bb24d`.
UI 9b84c23 включён обычным merge 83a19d2; RC2.1, экономика, SQLite и контент сохранены.
Добавлены только настройка release-подписи и tools/build-release.ps1.
Подсказки/список дел и их тесты разработаны Ф, интеграция/сборка/подпись выполнены Л.

## Файлы для передачи

Оба APK находятся локально в `C:/Users/fpp/Documents/ChatGPT/хакатон/finni/delivery/`.
В Git не публикуются; передать файлы отдельно.

| Артефакт | Версия | Размер, байт | Назначение |
| --- | --- | ---: | --- |
| finni-guidance-debug.apk | 0.1.0+1 | 171891351 | Короткая проверка подсказки, обновление текущей debug-установки |
| finni-guidance-release-candidate.apk | 0.1.0+2 | 51062349 | Подписанный release-кандидат, ожидает отдельной приёмки |

SHA-256 debug: `9bf2e6af0406ac100fcf02c586b41b50df955c2fbec8631c23b4d9213e09a900`.
SHA-256 release: `5e26a7fde66cba056ebe42994a45763e8b3d1c4dfe6d1ad1377c9b8bfe8fd67b`.

Package обоих: `ru.finni.pet`; minSdk 26, target/compileSdk 36.
Release содержит arm64-v8a, armeabi-v7a, x86_64; debug и release проходят проверку APK v2-подписи.
Точка входа: lib/main.dart, настоящий LogicService и SQLite.

## Подписи и данные

SHA-256 debug-сертификата сохранён:
`9c37926302ddd662d4202e2546ffb0f21d714952ba301a909b89d8145e369af1`.
Debug можно обновить поверх текущей установки без её удаления. Фактическое
сохранение данных на новой сборке ещё проверяет владелец Samsung.

SHA-256 release-сертификата:
`2a93ee5aafa05dd5b447ade36cb5dc6d84c68a53f967c17ee98ec0766950d5f4`.
Это отдельный RSA-3072 ключ, CN=Finni Release. Он отличается от debug.
Release нельзя считать совместимым обновлением установленного debug с тем же package.
Автоматического переноса сохранений в RC2.1 нет. Приложение и данные не удалялись.
До смены установки сохранить скриншоты/видео и записать состояние; удаление тестовой
версии и потерю её локальных данных отдельно согласовать с владельцем телефона.
Альтернатива для проверки release — отдельное устройство/профиль Android без этой установки.
Ни release, ни новая debug-сборка в этом этапе на устройство не устанавливались.

## Ключ и воспроизведение

Ключ находится вне репозитория: `C:/Users/fpp/.finni-signing/finni-release.jks`.
Alias: `finni-release`. Случайный пароль хранится в password.dpapi в той же папке,
защищён Windows DPAPI текущего пользователя; права каталога ограничены владельцем.
Секреты не печатались и не включались в Git/передачу. Для будущих обновлений нужен
тот же ключ. Владельцу необходимо сохранить защищённую резервную копию ключа и
восстанавливаемого пароля: копии DPAPI-файла одной недостаточно для другого компьютера.
Перенос ключа/пароля второму участнику не выполнялся.

Сценарий tools/build-release.ps1 читает DPAPI и передаёт секрет только через окружение,
восстанавливает прежнее окружение в finally. Gradle использует FINNI_KEYSTORE,
FINNI_STORE_PASSWORD и FINNI_KEY_ALIAS; keyPassword равен storePassword.
Без заполненных параметров сборка Release явно отклоняется, debug продолжает работать.

```powershell
$env:JAVA_HOME = 'C:/Users/fpp/.cache/finni/jdk-17.0.20.1/jdk-17.0.20.1+1'
$env:ANDROID_HOME = 'C:/Users/fpp/.cache/finni/android-sdk'
$env:PATH = "$env:JAVA_HOME/bin;C:/Users/fpp/.cache/finni/flutter-3.47.5/flutter/bin;$env:ANDROID_HOME/platform-tools;$env:PATH"
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub --target lib/main.dart --build-name 0.1.0 --build-number 1
./tools/build-release.ps1 -FlutterSdk 'C:/Users/fpp/.cache/finni/flutter-3.47.5/flutter' -AndroidSdk $env:ANDROID_HOME -JavaHome $env:JAVA_HOME -SigningDirectory 'C:/Users/fpp/.finni-signing' -BuildName '0.1.0' -BuildNumber 2
```

Запускать из checkout; на текущем ПК использована ASCII-junction finni-android.
Скрипт Windows/DPAPI предназначен для текущего аккаунта; другое окружение должно
получить тот же ключ защищённым способом и задать переменные подписи локально.
Побайтовая идентичность повторных сборок не проверялась; хеш относится к переданным файлам.

## Проверки

- Analyze 0; tests 28/28, включая 8 сценариев подсказок и пять периодов через UI/SQLite.
- После тестов изменена только сборочная конфигурация; Dart-код не менялся.
- Release assembleRelease: успешно, 113.0 секунд, версия 0.1.0+2 проверена aapt.
- Финальный debug с новой конфигурацией: успешно, 9.6 секунды; прежний сертификат проверен.
- apksigner verify: обе подписи проходят; release не использует debug-сертификат.
- assembleRelease --dry-run без секретов: ожидаемый exit 1 с сообщением Release requires FINNI_KEYSTORE...
- adb devices -l: пусто. Физическая приёмка и замеры производительности не выполнялись.
- Gradle сообщает о deprecated newDsl/builtInKotlin и Kotlin plugin; текущая сборка успешна,
  переход на Gradle/AGP 10 в этой задаче не выполнялся.

Toolchain: Flutter 3.47.5, Dart 3.13.4, JDK 17.0.20.1, Gradle 9.3.1,
AGP 9.1.0, Kotlin plugin 2.4.0, SDK 36, Build Tools 36.0.0,
NDK 28.2.13676358, platform-tools 37.0.1.

## Следующая приёмка и материалы Ф

Сначала обновить debug, проверить сохранение питомца и подсказки: без плана,
нужная покупка, нехватка денег, лимит, копилка, итог/закрытый период, завершённое демо.
Проверить свободную навигацию, крупный текст, удержание/TalkBack и офлайн-перезапуск.
Затем согласовать установку release и полный пяти-периодный проход, можно с записью видео.
Финал сценария: 5 доступно, 25 в копилке, 15 баллов, grown.
Физический полный проход пока не подтверждён; release-кандидат не объявляется финально принятым.
В презентации отделять widget-снимки Ф от реальной записи именно принятого APK.
Черновики личных отчётов/дневников упомянуты в handoff, но не переданы в этой задаче
и не проверялись; индивидуальное авторство подтверждать участникам по своим журналам.
