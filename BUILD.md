# Сборка и запуск

## Актуально: подсказки и подписанный release-кандидат

Обе сборки из 5eb1095 проверены; версия, хеши, инструкция и ограничения:
[FINNI_GUIDANCE_BUILD_HANDOFF.md](delivery/FINNI_GUIDANCE_BUILD_HANDOFF.md).
Release требует отдельного локального ключа через FINNI_KEYSTORE, FINNI_STORE_PASSWORD,
FINNI_KEY_ALIAS. Windows helper: tools/build-release.ps1. Секреты остаются вне Git.
Release имеет другую подпись, установка поверх debug не поддерживается.
Приёмка release владельцем Samsung подтверждена 28.09.2026. См. docs/testing/RELEASE-ACCEPTANCE.md. Ниже сохранены исторические этапы.

## Проверенная Android-сборка 26.09.2026

Debug APK из lib/main.dart успешно собран на Flutter 3.47.5, JDK 17.0.20.1,
Gradle 9.3.1, Android API 36, Build Tools 36.0.0 и NDK 28.2.13676358.
Точная команда: `flutter build apk --debug --no-pub --target lib/main.dart`.
Результаты, локальный путь, SHA-256 и сценарий устройства находятся в
[едином Android handoff](delivery/FINNI_ANDROID_HANDOFF.md).
Установка на физический телефон пока не проверена; исторические блокеры ниже сняты.

## Зафиксированный toolchain

- Flutter `3.47.5` stable, framework revision `6a19cca56475dbfba1478ee68d7bd0c2ef891da1`.
- Dart `3.13.4`.
- Android Gradle Plugin `9.1.0`.
- Kotlin Android plugin `2.4.0`.
- Java bytecode target `17`.
- `sqflite 2.4.4`, тестовый `sqflite_common_ffi 2.4.3`, `path 1.9.1`, `flutter_lints 6.0.0`.
- Android applicationId и namespace: `ru.finni.pet`.
- Минимальная Android-версия: API 26 (Android 8.0).

`pubspec.lock` хранится в Git. Версию Flutter фиксируют `.metadata` и документация; SDK не хранится в репозитории.

## Подготовка

Установить Flutter 3.47.5, совместимый JDK и Android SDK. Добавить Flutter `bin` в PATH только локально либо вызывать `flutter` по абсолютному пути. Затем:

```powershell
flutter doctor -v
flutter pub get
flutter analyze
flutter test
```

Если analysis server ломает URI из-за кириллицы в пути, клонировать репозиторий в ASCII-путь. Временная junction допустима только для диагностики, но не должна попадать в Git.

## Запуск

```powershell
flutter devices
flutter run
```

Production-фабрика сервиса:

```dart
final service = await createLogicService();
runApp(FinniApp(service: service));
```

Импорт фабрики: `package:finni/logic.dart`. UI и `FinniApp` остаются в ветке стороны интерфейса.

## Android

Debug APK после установки Android SDK:

```powershell
flutter build apk --debug
```

Release APK:

```powershell
flutter build apk --release
```

Release signing настроен через переменные окружения и отдельный ключ вне Git.
Используйте актуальную инструкцию выше. Передаваемый APK нужно проверить установкой без IDE на Android 8.0+.

## Статус 25.09.2026

- `flutter pub get`: пройдено.
- `dart format lib test`: пройдено.
- `flutter analyze`: пройдено через ASCII-junction, 0 issues.
- `flutter test --no-pub`: пройдено, 8 tests, включая SQLite FFI.
- Microsoft OpenJDK 17.0.20.1: подготовлен переносимо вне Git, SHA-256 проверен.
- Android APK: не выполнено из-за отсутствия Android SDK; принятие лицензий оставлено пользователю.
- Физический телефон: не проверен.
- Release signing: не настроен.
