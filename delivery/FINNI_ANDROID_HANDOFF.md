# FINNI: debug APK готов, 26.09.2026

Ветка: `logic/android-build`. База PR: `frontend/service-integration`.
PR: https://github.com/glagolller/finni/pull/7

## Исходники и ответственность

Коммит APK: `f622971aa101fb287a6ee126a9b8bd2e862a3b70`, чистое дерево на момент сборки.
Проверенный тестами коммит приложения: `99fbcc502f66bcf8c8f61cfe5c307aeef2aac505`.
Он объединяет UI `22ac7fea1258efc47d591d07989539baeb52ff97` и аудит
`26414c3` (PR #5) обычным merge без дублирования коммитов.
Начальное рабочее дерево было чистым. Main не объединялся.
RC2.1, экономика, UI и модели в этом этапе не изменялись.
Л отвечает за интеграцию исправлений логики, SQLite, окружение и сборку.
Авторство экранов и полного UI-теста остается у Ф.

## Фактические проверки

| Проверка | Результат |
| --- | --- |
| flutter pub get | Успешно |
| flutter analyze --no-pub | 0 issues |
| flutter test --no-pub | 20/20, включая полный UI-проход пяти периодов с SQLite FFI |
| flutter build apk --debug --no-pub --target lib/main.dart | Успешно, assembleDebug 456 секунд |
| flutter doctor -v | Android toolchain OK, все лицензии приняты пользователем |
| adb devices -l | Пустой список |
| apksigner verify --verbose | Verifies, подпись APK v2 |
| Установка и запуск на Galaxy A34 | Не выполнены: телефон не подключен |

APK: `C:/Users/fpp/Documents/ChatGPT/хакатон/finni/build/app/outputs/flutter-apk/app-debug.apk`.
Размер: 156408469 байт. Файл локальный, не добавлен в Git.
SHA-256: `39c08fd69e22708eb9e545e3d15cc3f03f60997ffec13e637bf5dbe36ba9a7be`.
Метаданные aapt: `ru.finni.pet`, versionName `0.1.0`, versionCode `1`,
minSdk 26, target/compileSdk 36, ABI arm64-v8a/armeabi-v7a/x86_64.
Это debug APK с debug-подписью, не финальный release.
Исходники после 20/20 тестов не изменялись: повторный прогон не требовался.
При первой сборке было предупреждение SDK XML v4/v3, сборка завершилась успешно.
Тесты SQLite FFI не заменяют проверку sqflite на Android.

## Версии и компоненты

| Компонент | Версия / состояние |
| --- | --- |
| Flutter / Dart | 3.47.5 / 3.13.4, установленный переносимый SDK |
| JDK | Microsoft OpenJDK 17.0.20.1 |
| Gradle wrapper | 9.3.1, выполнение и сборка подтверждены |
| AGP / Kotlin plugin | 9.1.0 / 2.4.0, сборка прошла |
| compileSdk / targetSdk / minSdk | 36 / 36 / 26 |
| SDK Build Tools | Установлен 36.0.0 |
| NDK | Установлен 28.2.13676358 |
| Android SDK / platform-tools | API 36 / 37.0.1 |
| Command-line tools | 22.0, архив 15859902 |

Требования семейства AGP 9.1 к Gradle 9.3.1 и JDK 17 согласуются с проектом:
[официальная таблица](https://developer.android.com/build/releases/agp-9-1-0-release-notes).
Практическая совместимость текущей конфигурации подтверждена debug-сборкой.

## Подготовка SDK и воспроизведение

Выполнено: пользователь скачал ZIP, его SHA-256 проверен и совпал с опубликованным,
инструменты распакованы в `C:/Users/fpp/.cache/finni/android-sdk`.
Пользователь лично выполнил `--licenses` и сообщил о завершении.
После проверки файлов лицензий агент установил компоненты и собрал APK.
Следующие инструкции сохранены для нового окружения; повторять принятие на этом хосте не нужно.

На [официальной странице](https://developer.android.com/studio#command-tools)
пользователь выбирает Windows command-line tools, читает и принимает условия,
скачивает `commandlinetools-win-15859902_latest.zip` и сообщает локальный путь.
Принятие условий требуется уже перед скачиванием. Агент этого не выполнял.
Опубликованный SHA-256: `90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a`.
Локальный архив: `D:/яндекс загрузки/commandlinetools-win-15859902_latest.zip`.

После получения архива агент проверяет хеш и распаковывает его так, чтобы
существовал `C:/Users/fpp/.cache/finni/android-sdk/cmdline-tools/latest/bin/sdkmanager.bat`.
Следующие команды применимы ПОСЛЕ этой распаковки. Пользователь запускает
лицензии интерактивно и отвечает самостоятельно после чтения каждого текста:

```powershell
$env:JAVA_HOME = 'C:/Users/fpp/.cache/finni/jdk-17.0.20.1/jdk-17.0.20.1+1'
$env:ANDROID_HOME = 'C:/Users/fpp/.cache/finni/android-sdk'
$sdkmanager = "$env:ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager.bat"
& $sdkmanager "--sdk_root=$env:ANDROID_HOME" --licenses
```

Затем установить компоненты, не передавая автоматические ответы согласия:

```powershell
& $sdkmanager "--sdk_root=$env:ANDROID_HOME" 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0' 'ndk;28.2.13676358'
$env:PATH = "$env:JAVA_HOME/bin;C:/Users/fpp/.cache/finni/flutter-3.47.5/flutter/bin;$env:ANDROID_HOME/platform-tools;$env:PATH"
flutter doctor -v
flutter build apk --debug --no-pub --target lib/main.dart
Get-FileHash build/app/outputs/flutter-apk/app-debug.apk -Algorithm SHA256
```

Команды сборки выполняются из корня проекта. Для диагностики кириллического
пути использовалась ASCII-junction `C:/Users/fpp/AppData/Local/Temp/finni-android`
на тот же checkout. Это не второй Flutter-проект.
Если новые tools требуют более новый JDK, сначала проверить сообщение версии;
требования самого sdkmanager и Gradle могут различаться.

## Galaxy A34: проверка после сборки

1. Записать версию Android, модель, коммит, SHA-256 APK. Включить USB debugging
   и лично разрешить подключение компьютера. Проверить `adb devices -l`.
2. Для выбранного serial выполнить `adb -s SERIAL install -r build/app/outputs/flutter-apk/app-debug.apk`.
   Запустить приложение с иконки; убедиться, что открывается production UI.
3. Создать тестовый профиль, подтвердить план, купить предмет, пополнить накопления.
   Записать деньги и период. Включить авиарежим, закрыть приложение принудительно
   и открыть снова. Проверить сохранение состояния и отсутствие повторного дохода.
4. Проверить системный Back в формах и диалогах, отмену опасных действий,
   показ/скрытие клавиатуры и доступность кнопок при вводе.
5. Проверить крупный системный шрифт, TalkBack, reduced motion и настройку звука.
   Отсутствующие звуки зафиксировать как ограничение, не считать переключатель доказательством воспроизведения.
6. Пройти пять периодов: 5 available, 25 savings, 15 баллов, grown.
   Проверить reset/delete только на тестовом профиле.
7. Записать фактическое время холодного старта и отклика на покупку на устройстве.
   Результаты debug не выдавать за release-производительность.

Release signing и конкурсные материалы остаются отдельными этапами.
