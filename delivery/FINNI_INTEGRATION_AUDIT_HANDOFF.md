# FINNI: интеграционный аудит логики и хранения

Дата: 25.09.2026

Ветка: `logic/integration-audit`

База: `frontend/service-integration`

Pull request: https://github.com/glagolller/finni/pull/5

## Итог

Интеграция UI с настоящим `SqliteLogicService` принята как база следующего этапа. Публичный контракт RC2.1, общие модели и границы ответственности сохранены:

- сторона логики отвечает за правила игры, SQLite, общую конфигурацию и проверяемость сборки;
- сторона интерфейса отвечает за экраны, навигацию, Pangolin/Neucha, `PetAvatar` и визуальные assets;
- в этой ветке UI-файлы не изменялись.

`lib/main.dart` открывает production-сервис через `createLogicService()` и передает его в `FinniApp`. Ошибка открытия показывает повтор; автоматического перехода на preview нет. `lib/main_preview.dart` остается отдельным тестовым входом.

## Исправление сервиса

`getHistory` приведен к ограничению RC2.1 `limit 1..100`:

- отрицательный cursor нормализуется в 0;
- нечисловой cursor трактуется как 0;
- limit меньше 1 становится 1;
- limit больше 100 становится 100.

До исправления `cursor = "-1"` мог приводить к `RangeError`, а `limit = 0` возвращал пустую страницу с неизменным `nextCursor = "0"`.

Контракт и сигнатуры API не менялись.

## Дополнительные гарантии

Добавлены тесты, подтверждающие:

1. Normal не завершается после периода 5: период 6 открывается с новым ID и номером 6, получает 100 монет, сбрасывает периодические факты и использует ассортимент шаблона 1.
2. Баланс, прогресс и история переносятся в normal между периодами.
3. `getTaskDefinition` для `completed_review` не меняет revision или деньги.
4. `updateSettings` сохраняется после закрытия и повторного открытия SQLite.
5. Некорректные cursor/limit истории не вызывают исключение или зацикленную страницу.

## Проверки

До изменения на интеграционной базе:

- `flutter pub get` — успешно;
- `flutter analyze --no-pub` — 0 issues;
- `flutter test --no-pub` — 16/16.

После изменения:

- `flutter test --no-pub test/logic/sqlite_logic_service_test.dart` — 7/7;
- `flutter test --no-pub` — 19/19;
- `flutter analyze --no-pub` — 0 issues;
- `git diff --check` — успешно.

Полный набор включает bootstrap retry, UI flow, настоящий controller-to-SQLite restart и тесты доменной логики.

## Toolchain

- Flutter 3.47.5 stable, revision `6a19cca564`;
- Dart 3.13.4;
- DevTools 2.60.0;
- Microsoft OpenJDK 17.0.20.1 LTS;
- Windows 11 25H2;
- sqflite 2.4.4;
- sqflite_common_ffi 2.4.3 для desktop/unit tests.

Flutter и Dart запускаются из переносимого SDK, поэтому `flutter doctor` отдельно сообщает, что они не добавлены в глобальный PATH. Для репозитория это не препятствие.

## Команды

```powershell
git fetch origin
git switch logic/integration-audit
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

При проблемах analysis server из-за кириллицы в родительском пути следует открыть тот же checkout через временную ASCII-junction; копия репозитория не нужна.

## Android

Фактический `flutter doctor -v`:

- JDK найден и работает;
- Android SDK не найден;
- `adb` недоступен;
- подключенного Android-устройства нет.

Фактический `flutter build apk --debug --no-pub`:

```text
[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.
```

Android SDK не устанавливался, лицензии автоматически не принимались. Для APK нужны ручное принятие условий Android SDK, platform-tools, platform для project compileSdk и build-tools. После этого следует повторить `flutter doctor -v`, debug APK, установку и offline restart на целевом Samsung Galaxy A34 5G.

Отсутствие Chrome и Visual Studio относится к web/Windows targets и Android APK не блокирует.

## Следующие шаги

Для стороны интерфейса:

- продолжить экраны задач, истории, настроек и финальные UI-состояния поверх существующего `LogicService`;
- для повторного просмотра завершенного задания вызывать `getTaskDefinition`, а не `submitTaskAnswer`;
- не повторять анимацию для `ActionOutcome.replayed`;
- не менять RC2.1 без нового согласования.

Для стороны логики:

- после ручной установки Android SDK повторить сборку и device smoke;
- исправлять только обнаруженные сервисные или persistence-дефекты;
- не забирать реализацию экранов.
