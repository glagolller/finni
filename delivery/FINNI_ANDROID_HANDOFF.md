# FINNI: Android-подготовка, 26.09.2026

Ветка: `logic/android-build`. База PR: `frontend/service-integration`.
PR: ссылка добавляется после публикации.

## Исходники и ответственность

Проверенный коммит приложения: `99fbcc502f66bcf8c8f61cfe5c307aeef2aac505`.
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
| flutter build apk --debug --no-pub --target lib/main.dart | Exit 1: No Android SDK found |
| flutter devices | Windows и Edge; Android не обнаружен средствами Flutter |
| Установка и запуск на Galaxy A34 | Не выполнены: SDK/adb и APK отсутствуют |

APK не создан, фактического пути к артефакту и SHA-256 нет.
Ожидаемый путь после успешной сборки: `build/app/outputs/flutter-apk/app-debug.apk`.
Тесты SQLite FFI не заменяют проверку sqflite на Android.

## Версии и компоненты

| Компонент | Версия / состояние |
| --- | --- |
| Flutter / Dart | 3.47.5 / 3.13.4, установленный переносимый SDK |
| JDK | Microsoft OpenJDK 17.0.20.1 |
| Gradle wrapper | 9.3.1, объявлен в проекте; выполнение Gradle не подтверждено |
| AGP / Kotlin plugin | 9.1.0 / 2.4.0, объявлены; разрешение Android-зависимостей не проверено |
| compileSdk / targetSdk / minSdk | 36 / 36 / 26 |
| SDK Build Tools | Требуется 36.0.0 |
| NDK | Требуется 28.2.13676358 из FlutterExtension.kt |
| Android SDK / platform-tools | Не установлены на проверенном хосте |

Требования семейства AGP 9.1 к Gradle 9.3.1 и JDK 17 согласуются с проектом:
[официальная таблица](https://developer.android.com/build/releases/agp-9-1-0-release-notes).
Полная совместимость Kotlin/плагинов будет установлена только сборкой.

## Ручное принятие лицензий и продолжение

На [официальной странице](https://developer.android.com/studio#command-tools)
пользователь выбирает Windows command-line tools, читает и принимает условия,
скачивает `commandlinetools-win-15859902_latest.zip` и сообщает локальный путь.
Принятие условий требуется уже перед скачиванием. Агент этого не выполнял.
Опубликованный SHA-256: `90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a`.
Архив на этом этапе не скачан и его локальный хеш не проверен.

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
