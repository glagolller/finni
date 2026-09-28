# SQLite-хранение

Реализация находится в `lib/data/` и `lib/domain/services/sqlite_logic_service.dart`. Публичный RC2.1 не изменен.

## Схема v1

- `profiles`: актуальный versioned JSON snapshot профиля;
- `action_receipts`: глобально уникальный `actionId`, операция, канонический fingerprint, примененная revision и исходные дельты результата;
- `deleted_profile_tombstones`: факт удаления профиля и время.

При открытии включается `PRAGMA foreign_keys = ON`; версия задается через `OpenDatabaseOptions(version: 1)` и SQLite `user_version`. Снимок профиля содержит периоды, план/факт, транзакции, прогресс заданий, историю стадий и завершенных целей, настройки и состояние питомца.

Каждая мутация читает receipt до проверки generation/revision. Изменение снимка, receipt и tombstone выполняются в одной SQLite-транзакции. Reset очищает игровое поколение, но не таблицу receipts. Delete удаляет snapshot, оставляя receipt и tombstone.

## Подключение UI

```dart
import 'package:finni/logic.dart';

final service = await createLogicService();
runApp(FinniApp(service: service));
```

`PreviewService` из UI-ветки не должен попадать в production composition root.

## Тесты

`test/logic/sqlite_logic_service_test.dart` использует `sqflite_common_ffi` и отдельный временный файл БД на каждый тест. Проверяются перезапуск, rollback отклоненной покупки, replay/conflict, пять периодов, плохая серия и durable reset/delete.
