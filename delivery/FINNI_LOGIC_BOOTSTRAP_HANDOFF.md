# FINNI: передача каркаса и контракта стороне интерфейса

Дата: 24.09.2026

Ветка: `logic/bootstrap`

Pull request: https://github.com/glagolller/finni/pull/2

Зависимость: PR основан на `frontend/stage3-design`, потому что исправляет RC2 из PR #1. Сначала следует принять PR #1; после этого diff PR #2 автоматически сократится до изменений стороны логики.

## 1. Статус и границы

Подготовлен единый Android-only Flutter-каркас общего приложения. В нем есть общие контрактные модели, `LogicService`, контент шести заданий, Android-конфигурация и проверки. Экраны, навигация и визуальные assets не реализовывались: это зона стороны интерфейса.

Экономика, SQLite-схема, миграции и конкретная реализация `LogicService` также пока не реализованы. Текущий этап фиксирует общий компилируемый контракт и сборочную основу, чтобы обе стороны не создавали конкурирующие Flutter-проекты.

Нормативный документ: `docs/contracts/logic_contract_v0.1-RC2.md`, редакция RC2.1. Все числа экономики и эффектов ниже являются проектными предложениями до балансировки на тестах.

## 2. Единый патч R1-R6

| Пункт | Исправление |
| --- | --- |
| R1 | Плохая серия дает ровно 1 балл `planKept` за период: после пяти периодов `qualityPoints = 5`, стадия остается `baby`. |
| R2 | Проверка недостатка денег на `item.music_player` выполняется в открытом периоде 1 до `finishPeriod`; `insufficient_funds` ничего не меняет. Затем проверяются закрытие, перезапуск и отсутствие повторного дохода. |
| R3 | `TaskInput` и `TaskAnswer` получили обязательный discriminator `type`; определены шесть типов, ответы, критерии и feedback. Полные definition находятся в `assets/content/tasks.json`. Добавлен закрытый словарь `NextAction.code/params`. |
| R4 | Добавлен `getBootstrapConfig()`: три формы и три палитры, всего 9 комбинаций. Неизвестные ID дают `invalid_pet_form` / `invalid_pet_palette`. Подтверждения reset/delete: `СБРОСИТЬ` / `УДАЛИТЬ`. Неотключаемые подтверждения покупок удалены из настроек. Demo заканчивается на периоде 5, normal циклически использует шаблоны пяти периодов без сброса прогресса. |
| R5 | Зафиксированы результаты неверного ответа, replayed, reset и delete. `replayed` возвращает исходные дельты, но актуальный полный snapshot и не повторяет UI-анимации. История дополнена `CompletedGoalRecord`. |
| R6 | `completed_review` и `demo_completed_review` являются чтением без эффектов и новой ревизии. Mood +2 за накопления дается один раз за период при первом положительном `qualifyingSavings`; это хранит `savingsMoodBonusGranted`. |

Неизвестный `NextAction.code` UI игнорирует, записывает в диагностику и безопасно возвращается на home. Свободный текст не используется как команда навигации.

## 3. Общие модели и сервис

- `lib/contracts/contracts.dart` экспортирует константы, enum, модели, requests и `LogicService`.
- `LogicService` содержит bootstrap/read/catalog/history/progress API, preview-команды и изменяющие команды.
- `GameState` является полным снимком; UI не применяет меньшую revision в пределах `(profileId, generation)`.
- Все денежные операции используют целые монеты.
- Команды изменения передают `actionId` и поддерживают идемпотентный replay.
- Задания представлены sealed-классами `TaskInput`, `TaskAnswer`, `TaskCriterion`.
- `TaskDefinition` включает input, criterion и оба текста `TaskFeedback`.

UI-адаптер должен использовать эти типы и полные состояния разделов 11-12 RC2.1, не воспроизводя экономику самостоятельно.

## 4. Экономика v0.2

| Правило | Проектное значение |
| --- | --- |
| Доход периода | 100 при создании профиля и каждом `startNextPeriod`; `finishPeriod` доход не начисляет |
| Задания | 6 заданий, по 5 монет однократно за поколение профиля; максимум 30 |
| Покупки | 4 позиции в периоде, максимум 3 успешные покупки, один товар не чаще одного раза |
| Качество периода | по 1 баллу за обязательные покупки, соблюдение плана, `qualifyingSavings >= 20` |
| Рост | `junior`: 2 периода и 6 баллов; `grown`: 4 периода и 12 баллов |
| Цели | playground 120, bicycle 180, telescope 240; списание только через подтвержденный `redeemGoal` |
| Накопления | `max(0, deposits - ordinaryWithdrawals)`; redemption цели не уменьшает показатель |
| Питомец | satiety/mood 0-100; начальные значения 60/60 |

Эффекты: confirm budget `mood +2`; первое положительное накопление периода `mood +2`; верное задание `mood +4`; неверное `mood -2`; цель `mood +12`; завершение периода всегда `satiety -10`, а mood меняется на `+4/+1/-2` для 2-3/1/0 баллов. Покупки используют таблицу раздела 7.3 RC2.1.

## 5. Контрольный сценарий пяти периодов

| Период | Старт: available/savings, S/M | План | Действия | Финиш: available/savings, S/M | Баллы; стадия |
| ---: | --- | --- | --- | --- | --- |
| 1 | 100/0, 60/60 | 50/20/30 | 2 задания +10; food 30, hygiene 20, deposit 30 | 30/30, 65/84 | 3; baby |
| 2 | 130/30, 65/84 | 45/35/30 | задание +5; lunch 25, hygiene 20, ball 35, deposit 30 | 25/60, 65/100 | 6; junior |
| 3 | 125/60, 65/100 | 50/45/30 | ошибка, затем верно +5; food 30, hygiene 20, hat 45, deposit 30 | 5/90, 70/100 | 9; junior |
| 4 | 105/90, 70/100 | 70/0/25 | задание +5; health 40, food 30, deposit 25 | 15/115, 80/100 | 12; grown |
| 5 | 115/115, 80/100 | 50/35/30 | задание +5; food 30, hygiene 20, ball 35, deposit 30, redeem 120 | 5/25, 85/100 | 15; grown |

Контроль денег: доходы 500 + награды 30 - покупки 380 - цель 120 = 30 общих монет (`5 available + 25 savings`).

## 6. Структура каркаса

```text
finni/
|-- android/                         # Android Gradle project, ru.finni.pet, minSdk 26
|-- assets/content/
|   |-- content_manifest.json
|   `-- tasks.json                  # 6 полных TaskDefinition
|-- lib/
|   |-- contracts/
|   |   |-- constants.dart
|   |   |-- contracts.dart
|   |   |-- enums.dart
|   |   |-- logic_service.dart
|   |   |-- requests.dart
|   |   `-- models/
|   |       |-- core_models.dart
|   |       |-- result_models.dart
|   |       `-- task_models.dart
|   `-- main.dart                   # пустой integration root, без экранов
|-- test/bootstrap_test.dart
|-- BUILD.md
|-- analysis_options.yaml
|-- pubspec.yaml
`-- pubspec.lock
```

Будущие файлы стороны логики: `lib/domain/economy/`, `lib/domain/tasks/`, `lib/domain/progress/`, `lib/domain/services/`, `lib/data/database/`, `lib/data/repositories/`, `lib/data/content/`, дополнительные catalog JSON, domain/data tests и `integration_test/demo_flow_test.dart`.

Сторона интерфейса добавляет `lib/ui/`, маршрутизацию, визуальные assets и временный fake adapter поверх общего контракта.

## 7. Зафиксированные версии

| Компонент | Версия |
| --- | --- |
| Flutter | 3.47.5 stable, revision `6a19cca56475dbfba1478ee68d7bd0c2ef891da1` |
| Dart | 3.13.4 |
| DevTools | 2.60.0 |
| sqflite | 2.4.4 |
| path | 1.9.1 |
| flutter_lints | 6.0.0 |
| Android Gradle Plugin | 9.1.0 |
| Kotlin plugin | 2.4.0 |
| Java target | 17 |
| Android applicationId | `ru.finni.pet` |
| minSdk | API 26 |

## 8. Запуск и проверки

```powershell
git switch logic/bootstrap
flutter doctor -v
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter devices
flutter run
flutter build apk --debug
```

Фактически выполнено 24.09.2026:

| Проверка | Результат |
| --- | --- |
| `flutter pub get` | успешно |
| `dart format lib test` | успешно, 10 файлов без изменений |
| `flutter analyze` | успешно, 0 issues; использована временная ASCII-junction из-за сбоя analysis server на кириллическом пути |
| `flutter test` | успешно, 4/4 |
| Content JSON | 2/2 успешно разобраны |
| JSON-примеры RC2.1 | 11/11 успешно разобраны |
| `git diff --check` | успешно; только предупреждение Git о будущей нормализации LF/CRLF |
| `flutter build apk --debug` | не выполнено: `No Android SDK found` |

## 9. Оставшиеся препятствия

На проверочном хосте отсутствуют Android SDK, `adb` и JDK; глобальный PATH не менялся, Flutter использовался переносимо вне Git. Поэтому APK, установка на Android 8.0+, offline-запуск и release signing не проверены.

Release-конфигурация намеренно не использует debug-ключ. Нужны локальный keystore и `key.properties` вне Git. Также остается проверить UI-интеграцию с `LogicService`, визуальные ID и fake adapter после изменений стороны интерфейса.

Полная реализация экономики и SQLite должна быть отдельным этапом после принятия контракта.
