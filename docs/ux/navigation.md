# Навигация и граница модулей

Проектирование от 24.09.2026, не схема уже работающего приложения.

```mermaid
flowchart TD
    Start[Запуск / listProfiles] --> Exists{Профиль найден?}
    Exists -- Нет --> E01[Знакомство E01]
    Exists -- Ошибка --> Retry[Повтор чтения]
    Retry --> Start
    E01 --> E02[Создание E02]
    E02 -- createProfile --> Home[Главный E03]
    Exists -- Да / loadState --> Home
    Home --> Budget[Бюджет E04]
    Budget -- preview / confirm --> Home
    Home --> Shop[Покупки E05]
    Shop --> Purchase[Подтверждение D01]
    Purchase -- отмена --> Shop
    Purchase -- buyItem --> Result[Результат D04]
    Home --> Savings[Копилка E06]
    Savings --> Transfer[Предпросмотр / перевод D02]
    Transfer --> Result
    Home --> Tasks[Задания E07 / T1–T6]
    Tasks -- submitTaskAnswer --> Result
    Result --> Home
    Home --> Finish[Предпросмотр итога / finishPeriod]
    Finish --> Summary[Итог E08]
    Summary -- startNextPeriod --> Budget
    Summary -- demo_completed --> Progress[Прогресс E09]
    Home --> Progress
    Home --> Help[Справка E10]
    Home --> AdultGate[Барьер E11]
    AdultGate --> Adult[Взрослый E12]
    Adult --> Settings[Настройки E13]
    Adult --> Delete[Подтверждение D03]
    Delete -- отмена --> Adult
    Delete -- reset demo --> Home
    Delete -- delete выбранного --> E01
```

Все дочерние экраны имеют возврат; на схеме он не дублируется для каждого ребра. Для reset и delete реальный переход определяется ответом сервиса и оставшимися профилями; нельзя создавать обычный профиль автоматически.

```mermaid
flowchart LR
    Child[Ребёнок] --> UI[Ф: экраны, ввод и обратная связь]
    Adult[Взрослый] --> UI
    UI --> Contract[Общие модели / LogicService]
    Contract --> Logic[Л: экономика, задания, периоды]
    Logic --> Storage[Л: SQLite и транзакции]
    Logic --> Content[Л: локальный JSON-контент]
    Storage --> Snapshot[Снимок и результат команды]
    Snapshot --> UI
```

UI не обращается к SQLite и не определяет правильность задания, цену, награду, остатки или рост. Л не строит второй набор экранов. Самостоятельное состояние Ф ограничено черновиком ввода, выбором вкладки, состоянием загрузки и отображением подтверждения.
