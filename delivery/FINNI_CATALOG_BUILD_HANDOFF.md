# FINNI: debug APK каталога и взрослого раздела

Историческая сборка. [Актуальная передача с подсказками и release-кандидатом](FINNI_GUIDANCE_BUILD_HANDOFF.md).

Дата: 26.09.2026. Ветка: `logic/android-catalog`.
База PR: `frontend/service-integration`. PR: https://github.com/glagolller/finni/pull/9

## Исходники и результат

Коммит сборки: `2ef394e71966b1dfa84a29f5d1b43d1dda4814cf`.
Он объединяет обычным merge нашу передачу c249137 и UI 2bf92ca без конфликтов.
Рабочее дерево на момент сборки чистое. Main не объединялся.
Контракт RC2.1, экономика, SQLite, контент, зависимости и Android не изменялись.
Авторство изменений экранов и дополнительных assertions принадлежит стороне интерфейса.

Локальный APK: `C:/Users/fpp/Documents/ChatGPT/хакатон/finni/delivery/finni-catalog-debug.apk`.
Размер: 171883463 байт.
SHA-256: `1fbd84607c8e3a757605b1a198864cfb879afdb37efea06717bacaed8ba717b6`.
Исходный результат сборки: `build/app/outputs/flutter-apk/app-debug.apk`.
APK и ключи исключены из Git; файл нужно передать участнику отдельно.

## Что вошло

- Удержание кнопки для входа во взрослый раздел; текстовые подтверждения reset/delete сохранены.
- Доступные задания показаны первыми, выполненные свёрнуты.
- Скрыты будущие и купленные товары; лимит и закрытый период объяснены заглушками.
- Текущий товар с недостатком денег остаётся видимым, отказ определяет сервис.
- Фон покупки соответствует категории.
- Убраны переключатель звука и SystemSound.click; поле soundEnabled сохранено для совместимости.
- Новые звуки, tutorial и миссии не добавлялись.

## Совместимость обновления

Сертификат прежнего UI-feedback APK проверен до сборки, нового — после.
SHA-256 обоих сертификатов:
`9c37926302ddd662d4202e2546ffb0f21d714952ba301a909b89d8145e369af1`.
apksigner verify: Verifies, схема v2.
Package `ru.finni.pet`, versionName `0.1.0`, versionCode `1` сохранены.
minSdk 26, targetSdk 36. Условия для обновления с сохранением профиля соблюдены;
фактическое обновление этого APK на Samsung ещё не проверено.

Установить поверх текущего приложения, не удаляя его и не очищая данные.
Через USB: `adb -s SERIAL install -r delivery/finni-catalog-debug.apk`.
При ошибке установки сохранить её текст и доказательства; удаление согласовать отдельно.
Версия отображается прежняя: различать сборки по SHA-256 и изменениям интерфейса.

## Проверки и воспроизведение

```powershell
$env:JAVA_HOME = 'C:/Users/fpp/.cache/finni/jdk-17.0.20.1/jdk-17.0.20.1+1'
$env:ANDROID_HOME = 'C:/Users/fpp/.cache/finni/android-sdk'
$env:PATH = "$env:JAVA_HOME/bin;C:/Users/fpp/.cache/finni/flutter-3.47.5/flutter/bin;$env:ANDROID_HOME/platform-tools;$env:PATH"
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub --target lib/main.dart
```

Выполнено из ASCII-junction на тот же checkout: analyzer 0 issues, tests 20/20,
assembleDebug успешно за 11.1 секунды. Тесты включают полный сценарий пяти периодов
с SQLite FFI и assertions нового каталога/удержания/цветов/настроек.
Подпись и package/Android-версии проверены apksigner и aapt.
adb devices -l пуст: device smoke новой сборки не выполнен.

Toolchain: Flutter 3.47.5 / Dart 3.13.4, JDK 17.0.20.1, Gradle 9.3.1,
AGP 9.1.0, Kotlin 2.4.0, SDK 36, Build Tools 36.0.0,
NDK 28.2.13676358, platform-tools 37.0.1.

## Следующая приёмка

Предыдущая UI-feedback сборка, по отчёту Ф, прошла три пользовательские проверки:
обновление с сохранением состояния, inline-покупка, экран награды.
Это не подтверждение новой сборки.
На Samsung проверить сохранение питомца после обновления, удержание и TalkBack,
каталоги и пустые состояния, отсутствие звука, настройки и офлайн-перезапуск.
Полные пять периодов на телефоне ещё ожидаются: финал 5/25, 15 баллов, grown.
Release готовить после приёмки обновлённого интерфейса.
