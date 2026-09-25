# FINNI: LogicService и SQLite — передача стороне интерфейса

Дата: 25.09.2026

Ветка: `logic/sqlite-service`

Pull request: https://github.com/glagolller/finni/pull/4

База PR: `logic/bootstrap`. Зависимость: сначала принять PR #2. UI PR #3 остается параллельной веткой от той же базы; UI и логика в PR #4 не смешаны.

## Что готово

Реализован настоящий `LogicService` поверх принятого RC2.1 без изменения публичных contracts:

- создание, список и загрузка профилей;
- каталоги товаров, целей и заданий;
- preview/confirm бюджета, покупок, накоплений и целей;
- шесть типов заданий с проверкой ответов, попытками и однократными наградами;
- finish/start периодов, demo 1–5 и циклический normal;
- прогресс, стадии, история транзакций/периодов/целей;
- настройки, reset demo и delete;
- SQLite-транзакции, durable receipts, action conflict, replay и tombstones.

Экраны, навигация, `PetAvatar`, шрифты и прочие UI assets не изменялись. Элементы стадий питомца не стали товарами или полями БД.

## Подключение к FinniApp

Фабрика находится в `lib/logic.dart`:

```dart
import 'package:finni/logic.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final service = await createLogicService();
  runApp(FinniApp(service: service));
}
```

`PreviewService` остается только preview/test-инструментом UI и не включается в production composition root.

## Хранение

SQLite schema v1:

| Таблица | Назначение |
| --- | --- |
| `profiles` | Актуальный versioned JSON snapshot профиля |
| `action_receipts` | Durable receipt: actionId, операция, canonical fingerprint, revision и исходные дельты |
| `deleted_profile_tombstones` | Факт удаления и время |

Снимок включает профиль, поколение/revision, текущий период, деньги, питомца, план/факт, задания, прогресс, настройки, транзакции, итоги периодов и завершенные цели. При открытии включается `PRAGMA foreign_keys = ON`; schema version хранится через SQLite `user_version`.

Каждая мутация выполняет в одной SQLite-транзакции изменение snapshot, запись receipt и при необходимости tombstone. Receipt проверяется раньше generation/revision. Replayed возвращает исходные дельты, но актуальный snapshot; UI не должен повторять анимацию.

## Контент

Добавлены versioned assets:

- `assets/content/items.json`;
- `assets/content/goals.json`;
- `assets/content/demo_periods.json`;
- существующий `assets/content/tasks.json` используется как источник шести полных TaskDefinition.

Неизвестный task discriminator отклоняется как `invalid_task_answer`. Словарь `NextActionCode` не расширялся.

## Проверенные сценарии

`flutter test --no-pub`: 8/8.

| Сценарий | Фактический результат |
| --- | --- |
| Перезапуск SQLite | Балансы и revision сохранены; доход не начисляется повторно |
| Повтор команды | `replayed`, исходная delta, без второго перевода |
| Тот же actionId с другим payload | `action_conflict`, состояние не меняется |
| Отклоненная покупка | Revision и purchase slots не меняются |
| Пять успешных периодов | 5 available, 25 savings, 15 quality points, `grown`, demo complete |
| Плохая серия | По 1 `planKept` за период, 5 quality points, `baby`, demo complete |
| Неверное задание | `needs_retry`, без денег, mood -2, попытка сохранена |
| Reset replay | Generation увеличивается один раз, доход остается 100 |
| Delete replay | Snapshot остается null, профиль отсутствует, receipt сохранен |

`flutter analyze --no-pub`: 0 issues. Все пять JSON assets синтаксически разобраны.

## Версии

- Flutter 3.47.5, Dart 3.13.4, DevTools 2.60.0;
- sqflite 2.4.4;
- sqflite_common_ffi 2.4.3 только для desktop/unit tests;
- path 1.9.1, flutter_lints 6.0.0;
- Microsoft OpenJDK 17.0.20.1 подготовлен переносимо вне Git;
- Android Gradle Plugin 9.1.0, Kotlin 2.4.0, minSdk 26.

## Команды

```powershell
git fetch origin
git switch logic/sqlite-service
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

При кириллице в пути analysis server Flutter 3.47.5 может ломать LSP JSON. Проверка выполнялась через временную ASCII-junction без копирования исходников.

## Android-блокер

Переносимый JDK проверен: `17.0.20.1`, SHA-256 архива `3d9006956fc8af5601cd24ffc4f468bef48279c7ebd8171b9bdf90d0aabfbf1f`.

Фактическая команда `flutter build apk --debug --no-pub` остановилась с `No Android SDK found`. Android SDK и `adb` отсутствуют. Автоматическое принятие лицензий не выполнялось.

Официальный command-line tools package на дату проверки: `commandlinetools-win-15859902_latest.zip`, опубликованный SHA-256 `90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a`. После ручного принятия условий пользователем нужны platform-tools, platform соответствующего `compileSdk` и build-tools; затем повторяются `flutter doctor -v` и debug build.

APK, установка на Samsung Galaxy A34 5G, offline-перезапуск на устройстве и release signing пока не проверены.
