# FINNI: контракт логики `logic_contract_v0.1`, редакция RC2.1

Дата: 24.09.2026

Статус: архитектурная основа с примененным патчем R1–R6 от 24.09.2026.

Основание: `FINNI_HANDOFF.md`, `FINNI_REPLY_TO_LOGIC.md`, предыдущий ответ Л и замечания `FINNI_CONTRACT_REVIEW_FOR_FRIEND.md`.

Этот файл полностью заменяет предыдущую проектную спецификацию `FINNI_RESPONSE_TO_INTERFACE.md` для дальнейшего согласования. Приложение, Flutter-каркас, БД и тестовый адаптер пока не реализованы. Все числовые значения экономики и эффектов остаются проектными предложениями до фиксации обеими сторонами.

## 1. Принятые решения и исправления RC2

Остаются принятыми Flutter/Dart, Android API 26+, SQLite через `sqflite`, локальный JSON-контент, отсутствие сервера и разделение ответственности: Л владеет общей конфигурацией, логикой, данными и сборкой; Ф — UI, визуальными ресурсами и подключением сервисов.

RC2 исправляет замечания интерфейсной стороны:

- у профиля есть обязательное игровое `petName`; реальное имя ребенка не требуется;
- UI получает профили, каталоги, рекомендуемое задание и причины недоступности только через сервис;
- все модели, nullability, payload команд и результаты заданы явно;
- задания являются шестью интерактивными симуляциями, а не набором вопросов;
- правильность задания передается через `TaskAttemptResult`, а не через `ActionResult.success`;
- лимит двух наград за период удален: каждое из шести заданий дает 5 монет один раз за профиль, поэтому отложенные награды не нужны;
- ограниченность выбора сохраняется при любом балансе: период предлагает четыре товара, но разрешает не более трех покупок;
- план с недостаточной суммой на нужды разрешен после предупреждения, чтобы ребенок мог ошибиться и восстановиться;
- числовые эффекты питомца определены для каждого действия;
- повтор команды возвращает исход операции и актуальный снимок, а не старую ревизию;
- `profileGeneration` защищает новое состояние после reset от старых команд;
- добавлены полные состояния и самостоятельные сценарии для UI-адаптера.

## 2. Нормативные правила контракта

Версия API: `logic_contract_v0.1`. Редакция документа: `RC2`. Версия проектного контента: `content_v0.2`.

Слова «обязан», «запрещено» и «только» в этом файле являются правилами предлагаемого контракта. После подтверждения Ф документ можно заморозить без изменения машинной версии. Несовместимое изменение после заморозки требует `logic_contract_v0.2`.

Все методы асинхронны. UI не читает SQLite или JSON напрямую и не вычисляет цены, остатки, эффекты, правильность заданий, доступность, пороги настроения или рост. Деньги и счетчики — целые числа. Состояния денег неотрицательны; денежные дельты могут быть отрицательными.

Preview-методы не изменяют БД, историю, ревизию или показатели. Изменяющая команда считается успешной только после commit транзакции SQLite.

## 3. Перечисления

| Тип | Допустимые значения |
| --- | --- |
| `ProfileMode` | `normal`, `demo` |
| `PeriodStatus` | `open`, `closed`, `demo_completed` |
| `PetStage` | `baby`, `junior`, `grown` |
| `MoodCode` | `happy`, `calm`, `needs_attention` |
| `ExpenseType` | `need`, `want` |
| `GoalStatus` | `selected`, `reachable`, `completed` |
| `TaskTheme` | `budget`, `savings`, `payments_and_purchases` |
| `TaskInteractionType` | `budget_allocation`, `plan_fact_choice`, `savings_schedule`, `savings_comparison`, `purchase_basket`, `expense_classification` |
| `TaskAvailabilityCode` | `available`, `completed_review`, `attempt_limit_reached`, `period_closed`, `demo_completed_review` |
| `TaskAttemptOutcome` | `correct`, `needs_retry` |
| `RewardState` | `available`, `granted`, `already_granted`, `not_earned` |
| `TransferDirection` | `to_savings`, `from_savings` |
| `ActionOutcome` | `applied`, `replayed`, `rejected` |
| `TransactionType` | `period_income`, `task_reward`, `purchase`, `savings_deposit`, `savings_withdrawal`, `goal_redemption` |
| `WarningCode` | `needs_underfunded`, `budget_exceeded`, `savings_withdrawal`, `goal_change`, `goal_redemption`, `mandatory_needs_unmet` |

`LogicErrorCode`:

- `profile_not_found`;
- `profile_already_exists`;
- `invalid_profile_mode`;
- `invalid_pet_name`;
- `invalid_amount`;
- `invalid_budget`;
- `plan_required`;
- `plan_already_confirmed`;
- `insufficient_funds`;
- `purchase_limit_reached`;
- `item_not_found`;
- `item_unavailable`;
- `item_already_purchased_this_period`;
- `goal_not_found`;
- `goal_not_reachable`;
- `task_not_found`;
- `attempt_limit_reached`;
- `period_closed`;
- `period_not_finished`;
- `demo_complete`;
- `stale_state`;
- `stale_generation`;
- `action_conflict`;
- `confirmation_required`;
- `contract_version_mismatch`;
- `content_version_mismatch`;
- `storage_error`.

Нулевая сумма категории бюджета допустима. Нулевая сумма перевода недопустима и дает `invalid_amount`.

## 4. Полные модели данных

### 4.1. Идентификаторы и время

`ProfileId`, `PeriodId`, `ItemId`, `GoalId`, `TaskId`, `TransactionId` и `ActionId` — непустые строки. Семантические ID контента стабильны: `item.food`, `goal.playground`, `task.budget.01`, `pet.form.01`. Время сериализуется строкой UTC ISO 8601. `Money`, `StateRevision` и `ProfileGeneration` сериализуются целыми числами.

### 4.2. `ProfileSummary`

| Поле | Тип | Nullable | Правило |
| --- | --- | --- | --- |
| `id` | `String` | нет | локальный уникальный ID, не переиспользуется после удаления |
| `mode` | `ProfileMode` | нет | режим профиля |
| `displayName` | `String` | да | игровой псевдоним ребенка; реальное имя не запрашивается |
| `petName` | `String` | нет | 1–20 отображаемых символов после trim |
| `generation` | `int` | нет | начинается с 1, увеличивается reset |
| `updatedAt` | `String` | нет | UTC ISO 8601 |

### 4.3. `Profile`

| Поле | Тип | Nullable |
| --- | --- | --- |
| `id` | `String` | нет |
| `mode` | `ProfileMode` | нет |
| `displayName` | `String` | да |
| `petName` | `String` | нет |
| `generation` | `int` | нет |
| `createdAt` | `String` | нет |
| `updatedAt` | `String` | нет |

### 4.4. `ProfileSettings`

| Поле | Тип | Nullable | Default |
| --- | --- | --- | --- |
| `soundEnabled` | `bool` | нет | `true` |
| `reducedMotion` | `bool` | нет | `false` |
| `largeTextPreferred` | `bool` | нет | `false` |

Обязательные подтверждения покупок не являются настройкой и не могут быть отключены. Поле `purchaseConfirmationEnabled` удалено из контракта и не показывается в UI.

### 4.5. `BudgetPlan`

| Поле | Тип | Nullable |
| --- | --- | --- |
| `periodId` | `String` | нет |
| `needsLimit` | `int` | нет |
| `wantsLimit` | `int` | нет |
| `savingsTarget` | `int` | нет |
| `unallocatedAmount` | `int` | нет |
| `requiredNeedsCostAtConfirmation` | `int` | нет |
| `confirmedAt` | `String` | нет |

Все суммы категорий могут быть нулевыми. Они не могут быть отрицательными. Сумма трех категорий не может превышать доступный баланс на момент подтверждения. `needsLimit < requiredNeedsCostAtConfirmation` дает предупреждение `needs_underfunded`, но не блокирует подтверждение.

### 4.6. `BudgetActual`

| Поле | Тип | Nullable |
| --- | --- | --- |
| `periodIncome` | `int` | нет |
| `taskRewards` | `int` | нет |
| `needsSpent` | `int` | нет |
| `wantsSpent` | `int` | нет |
| `savingsDeposited` | `int` | нет |
| `ordinarySavingsWithdrawn` | `int` | нет |
| `goalRedemptionSpent` | `int` | нет |
| `qualifyingSavings` | `int` | нет |
| `savingsMoodBonusGranted` | `bool` | нет |
| `requiredNeedsMet` | `bool` | нет |
| `planKept` | `bool` | нет |
| `savingsHabitKept` | `bool` | нет |

`qualifyingSavings = max(0, savingsDeposited - ordinarySavingsWithdrawn)`. Снятие не является доходом. Списание на достигнутую цель не уменьшает `qualifyingSavings`.

`savingsMoodBonusGranted` предотвращает повторное повышение mood переводами: бонус +2 дается только при первом в периоде переходе `qualifyingSavings` из 0 в положительное значение и больше в этом периоде не повторяется.

### 4.7. `RequiredPurchase`

| Поле | Тип | Nullable |
| --- | --- | --- |
| `itemId` | `String` | нет |
| `quantity` | `int` | нет; RC2 всегда 1 |
| `fulfilled` | `bool` | нет |

### 4.8. `PeriodState`

| Поле | Тип | Nullable |
| --- | --- | --- |
| `id` | `String` | нет |
| `number` | `int` | нет |
| `status` | `PeriodStatus` | нет |
| `incomeCredited` | `int` | нет |
| `incomeCreditedAt` | `String` | нет |
| `availableItemIds` | `List<String>` | нет; ровно 4 для открытого демопериода |
| `requiredPurchases` | `List<RequiredPurchase>` | нет |
| `purchaseSlotsTotal` | `int` | нет; RC2 равно 3 |
| `purchaseSlotsUsed` | `int` | нет |
| `purchasedItemIds` | `List<String>` | нет |
| `budgetPlan` | `BudgetPlan` | да до подтверждения |
| `actual` | `BudgetActual` | нет |
| `startedAt` | `String` | нет |
| `closedAt` | `String` | да до завершения |

### 4.9. `PetState`

| Поле | Тип | Nullable |
| --- | --- | --- |
| `name` | `String` | нет; совпадает с `Profile.petName` |
| `formId` | `String` | нет |
| `paletteId` | `String` | нет |
| `satiety` | `int` | нет; 0–100 |
| `mood` | `int` | нет; 0–100 |
| `moodCode` | `MoodCode` | нет |
| `stage` | `PetStage` | нет |
| `lastReasonCode` | `String` | да до первого изменения |
| `explanationForChild` | `String` | да до первого изменения |

`moodCode`: `happy` для 70–100, `calm` для 40–69, `needs_attention` для 0–39. Нулевые показатели не означают смерть, потерю питомца или блокировку.

### 4.10. `PetEffect` и `PetDelta`

`PetEffect` описывает проектный эффект контента: `satietyChange`, `moodChange`, `reasonCode`, `explanationForChild` — все обязательны.

`PetDelta`:

| Поле | Тип | Nullable |
| --- | --- | --- |
| `satietyBefore` | `int` | нет |
| `satietyAfter` | `int` | нет |
| `moodBefore` | `int` | нет |
| `moodAfter` | `int` | нет |
| `moodCodeBefore` | `MoodCode` | нет |
| `moodCodeAfter` | `MoodCode` | нет |
| `stageBefore` | `PetStage` | нет |
| `stageAfter` | `PetStage` | нет |
| `reasonCode` | `String` | нет |
| `explanationForChild` | `String` | нет |

### 4.11. `ItemSummary`

| Поле | Тип | Nullable |
| --- | --- | --- |
| `id` | `String` | нет |
| `title` | `String` | нет |
| `expenseType` | `ExpenseType` | нет |
| `price` | `int` | нет |
| `visualAssetId` | `String` | нет |
| `availableThisPeriod` | `bool` | нет |
| `purchasedThisPeriod` | `bool` | нет |
| `availabilityReason` | `String` | да, если доступен |
| `petEffect` | `PetEffect` | нет |

### 4.12. `GoalSummary` и `GoalProgress`

`GoalSummary`:

| Поле | Тип | Nullable |
| --- | --- | --- |
| `id` | `String` | нет |
| `title` | `String` | нет |
| `targetAmount` | `int` | нет |
| `visualAssetId` | `String` | нет |
| `selected` | `bool` | нет |
| `reachable` | `bool` | нет |

`GoalProgress`:

| Поле | Тип | Nullable |
| --- | --- | --- |
| `goalId` | `String` | нет |
| `title` | `String` | нет |
| `targetAmount` | `int` | нет |
| `savedAmount` | `int` | нет |
| `remainingAmount` | `int` | нет |
| `status` | `GoalStatus` | нет |
| `selectedAt` | `String` | нет |
| `completedAt` | `String` | да до завершения |

### 4.13. Задания

`TaskSummary`:

| Поле | Тип | Nullable |
| --- | --- | --- |
| `id` | `String` | нет |
| `title` | `String` | нет |
| `theme` | `TaskTheme` | нет |
| `interactionType` | `TaskInteractionType` | нет |
| `rewardAmount` | `int` | нет |
| `availability` | `TaskAvailabilityCode` | нет |
| `unavailableReason` | `String` | да, если `available` |
| `completed` | `bool` | нет |
| `rewardState` | `RewardState` | нет |
| `attemptsThisPeriod` | `int` | нет |
| `remainingAttempts` | `int` | нет |

`TaskHub` содержит обязательные `recommendedTask: TaskSummary?` и `tasks: List<TaskSummary>`. При отсутствии незавершенных заданий `recommendedTask = null`; список все равно содержит задания для режима повторения и причины недоступности.

`TaskDefinition`:

| Поле | Тип | Nullable |
| --- | --- | --- |
| `id` | `String` | нет |
| `title` | `String` | нет |
| `theme` | `TaskTheme` | нет |
| `interactionType` | `TaskInteractionType` | нет |
| `prompt` | `String` | нет |
| `rewardAmount` | `int` | нет |
| `maxAttemptsPerPeriod` | `int` | нет; RC2 равно 3 |
| `simulationOnly` | `bool` | нет; RC2 всегда `true` |
| `input` | `TaskInput` | нет |

`TaskInput` — tagged union по `interactionType`:

- `BudgetAllocationInput`: `income`, `minimumNeeds`, `minimumSavings`, `allowedCategories`;
- `PlanFactChoiceInput`: `plans`, `actual`, `optionIds`;
- `SavingsScheduleInput`: `goalAmount`, `periodCount`, `minimumPerPeriod`;
- `SavingsComparisonInput`: `operations`, `optionIds`;
- `PurchaseBasketInput`: `budget`, `items`, `requiredItemIds`, `maxSelectedItems`;
- `ExpenseClassificationInput`: `entries`, `targetGroups`.

`TaskAnswer` — tagged union:

- `BudgetAllocationAnswer`: `needs`, `wants`, `savings`;
- `PlanFactChoiceAnswer`: `selectedOptionId`;
- `SavingsScheduleAnswer`: `amountsByPeriod`;
- `SavingsComparisonAnswer`: `selectedOptionId`;
- `PurchaseBasketAnswer`: `selectedItemIds`;
- `ExpenseClassificationAnswer`: `groupByEntryId`.

`TaskAttemptResult`:

| Поле | Тип | Nullable |
| --- | --- | --- |
| `taskId` | `String` | нет |
| `attemptNumberThisPeriod` | `int` | нет |
| `outcome` | `TaskAttemptOutcome` | нет |
| `explanation` | `String` | нет |
| `rewardGranted` | `bool` | нет |
| `rewardAmount` | `int` | нет; 0 или 5 |
| `rewardState` | `RewardState` | нет |
| `remainingAttempts` | `int` | нет |
| `completedNow` | `bool` | нет |

`ActionResult.success` для неверной попытки равно `true`, потому что команда сохранена. Правильность определяется только `taskAttempt.outcome`.

### 4.14. Прогресс

`TaskProgress` содержит обязательные `taskId`, `completed`, `attemptsTotal`, `attemptsThisPeriod`, `lastOutcome: TaskAttemptOutcome?`, `rewardState`, `completedAt: String?`.

`StageHistoryEntry` содержит `stage`, `reachedAfterPeriod`, `qualityPoints`, `reachedAt`.

`LearningProgress` содержит `completedPeriods`, `qualityPoints`, `taskProgress: List<TaskProgress>`, `stageHistory: List<StageHistoryEntry>`.

`ProgressResult` содержит `progress: LearningProgress?`, `errorCode: LogicErrorCode?`, `messageForChild: String?`. При успехе `progress` обязателен и `errorCode = null`; при ошибке наоборот.

### 4.15. История и итоги

`Transaction` содержит `id`, `profileId`, `profileGeneration`, `periodId`, `type`, `amount`, `availableChange`, `savingsChange`, `relatedEntityId: String?`, `unitPrice: int?`, `contentVersion`, `actionId`, `createdAt`.

`PeriodSummary` содержит `periodId`, `number`, `plan: BudgetPlan`, `actual: BudgetActual`, `qualityPointsGranted`, `qualityPointsTotal`, `stageBefore`, `stageAfter`, `satietyAfter`, `moodAfter`, `explanationForChild`, `closedAt`.

`HistoryPage` содержит `transactions`, `periodSummaries`, `nextCursor: String?`, `errorCode: LogicErrorCode?`.

### 4.16. Денежные и навигационные результаты

`MoneyDelta` содержит обязательные `availableChange`, `savingsChange`, `incomeChange`, `rewardChange`, `reasonCode`.

`WarningMessage` содержит `code`, `messageForChild`, `requiresConfirmation`.

`NextAction` содержит `code` и `params: Map<String, scalar>`. UI выбирает переход по `code`, а не разбирает текст.

`CatalogResult<T>` содержит `items: List<T>`, `stateRevision`, `profileGeneration`, `errorCode: LogicErrorCode?`, `messageForChild: String?`.

### 4.17. `GameState`

Все поля обязательны, кроме отмеченных nullable:

| Поле | Тип | Nullable |
| --- | --- | --- |
| `contractVersion` | `String` | нет |
| `contentVersion` | `String` | нет |
| `stateRevision` | `int` | нет |
| `profile` | `Profile` | нет |
| `currentPeriod` | `PeriodState` | нет; у завершенного демо хранится период 5 со статусом `demo_completed`; после delete объекта `GameState` нет |
| `availableBalance` | `int` | нет |
| `savingsBalance` | `int` | нет |
| `activeGoal` | `GoalProgress` | да до выбора или после завершения без новой цели |
| `pet` | `PetState` | нет |
| `taskHub` | `TaskHub` | нет |
| `learningProgress` | `LearningProgress` | нет |
| `settings` | `ProfileSettings` | нет |

## 5. Результаты и команды

### 5.1. Чтение

| Метод | Параметры | Результат |
| --- | --- | --- |
| `listProfiles()` | нет | `ListProfilesResult {profiles, errorCode?, messageForChild?}` |
| `getBootstrapConfig()` | нет | версия контракта и доступные form/palette до создания профиля |
| `loadState(profileId)` | `profileId` | `LoadStateResult {found, stateSnapshot?, errorCode?, messageForChild?}` |
| `getItemCatalog(profileId)` | `profileId` | `CatalogResult<ItemSummary>` |
| `getGoalCatalog(profileId)` | `profileId` | `CatalogResult<GoalSummary>` |
| `getTaskCatalog(profileId)` | `profileId` | `CatalogResult<TaskSummary>` |
| `getTaskDefinition(profileId, taskId)` | оба ID | `TaskDefinitionResult {definition?, availability, errorCode?, messageForChild?}` |
| `getHistory(profileId, cursor?, limit)` | `limit` 1–100 | `HistoryPage` |
| `getProgress(profileId)` | `profileId` | `ProgressResult` |

Так UI может найти normal/demo профиль без заранее известного ID и не обращается к JSON или БД.

### 5.2. Общий конверт изменяющей команды

Кроме `CreateProfileCommand`, каждая команда содержит:

- `contractVersion`;
- `actionId`;
- `profileId`;
- `expectedGeneration`;
- `expectedRevision`;
- `acceptedWarnings: List<WarningCode>`.

Preview-query содержит `profileId`, `expectedGeneration`, `expectedRevision` и payload, но не `actionId` и не `acceptedWarnings`.

### 5.3. Payload методов

| Метод | Payload query/command |
| --- | --- |
| `createProfile` | `actionId`, `mode`, `displayName?`, обязательные `petName`, `formId`, `paletteId` |
| `previewBudget` / `confirmBudget` | `needsLimit`, `wantsLimit`, `savingsTarget` |
| `previewPurchase` / `buyItem` | `itemId`; количество в RC2 всегда 1 |
| `previewSavingsTransfer` / `transferSavings` | `direction`, `amount`; `amount > 0` |
| `previewGoalChange` / `changeGoal` | `goalId` |
| `previewGoalRedemption` / `redeemGoal` | `goalId` активной достигнутой цели |
| `submitTaskAnswer` | `taskId`, tagged-union `answer` |
| `previewFinishPeriod` / `finishPeriod` | `periodId` |
| `startNextPeriod` | `closedPeriodId` |
| `resetDemoProfile` | `confirmationText`; только профиль `demo` |
| `deleteProfile` | `confirmationText` |
| `updateSettings` | полный `ProfileSettings` |

### 5.4. `PreviewResult`

Все поля присутствуют:

- `allowed: bool`;
- `errorCode: LogicErrorCode?`;
- `warnings: List<WarningMessage>`;
- `messageForChild: String`;
- `expectedMoneyDelta: MoneyDelta?`;
- `expectedPetDelta: PetDelta?`;
- `stateSnapshot: GameState?`;
- `nextActions: List<NextAction>`.

### 5.5. `ActionResult`

Все поля присутствуют:

- `success: bool`;
- `outcome: ActionOutcome`;
- `actionId: String`;
- `operationAppliedRevision: int?` — ревизия, на которой исходная команда была применена;
- `errorCode: LogicErrorCode?`;
- `messageForChild: String`;
- `stateSnapshot: GameState?` — актуальный снимок на момент ответа, не исторический;
- `moneyDelta: MoneyDelta?` — исходная дельта операции, даже для `replayed`;
- `petDelta: PetDelta?` — исходная дельта операции, даже для `replayed`;
- `taskAttempt: TaskAttemptResult?` — обязателен только для сохраненной попытки задания;
- `periodSummary: PeriodSummary?` — обязателен только для `finishPeriod`;
- `nextActions: List<NextAction>`.

При `applied` и `replayed`: `success = true`, `errorCode = null`. При `rejected`: `success = false`, `operationAppliedRevision = null`; снимок актуален, если чтение возможно. После успешного delete снимок равен `null`.

## 6. Идемпотентность, reset и актуальность UI

1. `actionId` уникален в пределах `profileId` за всю жизнь профиля, включая поколения. Для create действует глобальная уникальность receipt.
2. Durable receipts не удаляются при reset и сохраняют тип команды, канонический hash payload, поколение, примененную ревизию и исходные дельты.
3. Проверка нового запроса: сначала receipt по `actionId`, затем поколение, затем ревизия.
4. Совпавший ID и payload возвращает `replayed`, исходные дельты и текущий достоверный `stateSnapshot`.
5. Совпавший ID с другим типом команды, профилем или payload возвращает `action_conflict`.
6. Неизвестная старая команда после reset имеет старое `expectedGeneration` и получает `stale_generation`; она не применяется к новой игре.
7. Reset увеличивает `profileGeneration` и `stateRevision`, но не обнуляет их. Его receipt хранится вне очищаемых игровых таблиц.
8. Повтор reset не сбрасывает новое поколение еще раз. Повтор delete возвращает `replayed` и `stateSnapshot = null`.
9. UI никогда не применяет снимок с меньшей ревизией для той же пары `(profileId, generation)`. Для `replayed` UI не повторяет анимацию награды, покупки или роста.
10. Все изменения денег, питомца, прогресса, истории, receipt и ревизии проходят одной SQLite-транзакцией.

## 7. Экономика `economy_v0.2`

Все числа разделов 7–10 являются проектными предложениями.

### 7.1. Доход и перенос

- При `createProfile` открывается период 1 и один раз начисляется 100 монет.
- `finishPeriod` только закрывает период.
- `startNextPeriod` один раз начисляет 100 монет и открывает следующий период.
- Уникальность начисления: `(profileId, generation, periodNumber, period_income)`.
- Доступный остаток и накопления полностью переносятся.
- Каждое из шести заданий дает 5 монет только при первом правильном выполнении за жизнь поколения профиля.
- Периодического лимита наград нет. Максимальная награда всех заданий — 30 монет, поэтому farming невозможен и отложенные награды не нужны.
- Завершенное задание остается доступно в review-режиме без награды.

### 7.2. Ограниченный выбор при любом балансе

Каждый период предлагает ровно четыре позиции: две потребности и два желания. За период разрешено не более трех успешных покупок; каждая расходует один непереносимый `purchaseSlot`. Один и тот же товар можно купить не более одного раза за период.

Следствие: даже при доступном балансе 400 или после снятия всех накоплений игрок не может купить все четыре позиции периода и тем более весь каталог из восьми. После двух обязательных покупок остается один слот, поэтому приходится выбрать одно из двух желаний либо не тратить его. Деньги и накопления не исчезают; ограничение относится только к числу осознанных покупок периода.

`purchaseSlot` расходуется только успешной покупкой. Preview, отмена, нехватка денег и ошибка хранения слот не расходуют.

### 7.3. Товары и эффекты

| ID | Название | Тип | Цена | Satiety | Mood | Причина |
| --- | --- | --- | ---: | ---: | ---: | --- |
| `item.food` | Полезная еда | need | 30 | +15 | +2 | `purchase_food` |
| `item.hygiene` | Набор для ухода | need | 20 | 0 | +6 | `purchase_hygiene` |
| `item.school_lunch` | Школьный обед | need | 25 | +10 | +3 | `purchase_school_lunch` |
| `item.health_check` | Забота о здоровье | need | 40 | +5 | +5 | `purchase_health` |
| `item.ball` | Мяч | want | 35 | 0 | +8 | `purchase_ball` |
| `item.hat` | Яркая шапочка | want | 45 | 0 | +7 | `purchase_hat` |
| `item.room_decor` | Украшение комнаты | want | 55 | 0 | +10 | `purchase_room_decor` |
| `item.music_player` | Музыкальная игрушка | want | 70 | 0 | +12 | `purchase_music_player` |

Значения после каждого эффекта ограничиваются диапазоном 0–100.

### 7.4. Ассортимент демопериодов

| Период | Доступны четыре позиции | Обязательны |
| ---: | --- | --- |
| 1 | food, hygiene, ball, music_player | food, hygiene |
| 2 | school_lunch, hygiene, ball, room_decor | school_lunch, hygiene |
| 3 | food, hygiene, hat, music_player | food, hygiene |
| 4 | health_check, food, room_decor, music_player | health_check, food |
| 5 | food, hygiene, ball, hat | food, hygiene |

### 7.5. Цели

| ID | Название | Цена |
| --- | --- | ---: |
| `goal.playground` | Игровая площадка для Финни | 120 |
| `goal.bicycle` | Велосипедная прогулка | 180 |
| `goal.telescope` | Домашний телескоп | 240 |

Смена цели требует предупреждения, но не меняет деньги. Прогресс пересчитывается от текущих накоплений. Достижение суммы не списывает деньги автоматически. `redeemGoal` списывает точную стоимость после подтверждения; избыток остается. Эффект завершения цели: mood +12, satiety 0, причина `goal_redeemed`.

### 7.6. План и факт

Жестко запрещены только отрицательные суммы и сумма плана выше текущего доступного баланса. Нулевая категория разрешена. План с `needsLimit` ниже стоимости обязательного набора возвращает `allowed = true` и предупреждение `needs_underfunded`; confirm требует этот код в `acceptedWarnings`.

План не резервирует и не списывает деньги. После подтверждения он неизменяем. Покупка, выводящая факт категории выше лимита, разрешена при достаточных деньгах после предупреждения `budget_exceeded`. Так ребенок может ошибиться в плане, увидеть последствия и исправить приоритеты действиями, а не получить запрет до обучения.

### 7.7. Накопления и рост

`qualifyingSavings = max(0, deposits - ordinaryWithdrawals)`. Круговой перевод не создает рост. Завершение цели не считается обычным снятием.

За период начисляется по одному баллу за:

- все обязательные покупки;
- соответствие факта плану: расходы категорий не выше лимитов и qualifying savings не ниже цели плана;
- qualifying savings не меньше 20.

`junior`: минимум 2 периода и 6 баллов. `grown`: минимум 4 периода и 12 баллов. Баллы не отнимаются. Задания не заменяют три финансовых критерия.

## 8. Шесть интерактивных заданий

Все задания симуляционные: их входные суммы не списываются с настоящего баланса. Реальное состояние меняется только на 5 монет награды при первом правильном решении и на эффект питомца из раздела 9.

| ID | Тип действия и вход | Критерий correct | Объяснение correct | Объяснение needs_retry |
| --- | --- | --- | --- | --- |
| `task.budget.01` | `budget_allocation`: распределить доход 100 по needs/wants/savings | сумма ровно 100, needs >= 50, savings >= 20 | «Ты сначала учел нужное и оставил часть на цель.» | «Проверь общую сумму, нужное и хотя бы 20 монет накоплений.» |
| `task.budget.02` | `plan_fact_choice`: выбрать из трех планов тот, которому соответствует факт 50/35/30 | выбран `option.plan_b` | «План и факт совпали по всем трем частям.» | «Сравни отдельно нужное, желания и накопления.» |
| `task.savings.01` | `savings_schedule`: разложить цель 120 на четыре периода | 4 целых неотрицательных значения, сумма >= 120, каждое >= 20 | «Регулярные шаги довели накопления до цели.» | «Проверь четыре шага: вместе нужно не меньше 120.» |
| `task.savings.02` | `savings_comparison`: после +30, −10 и +5 выбрать qualifying savings | выбран ответ 25 | «Снятие уменьшает вклад периода: 30 − 10 + 5 = 25.» | «Снятые монеты не считаются новым доходом или накоплением.» |
| `task.payments.01` | `purchase_basket`: при бюджете 70 выбрать корзину, включающую food, не более 2 предметов | food выбран, сумма <= 70, число <= 2 | «Нужное куплено, и корзина помещается в бюджет.» | «Сначала добавь еду и проверь сумму корзины.» |
| `task.payments.02` | `expense_classification`: разнести food, hygiene, lunch, health, ball, hat по need/want | первые четыре — need, последние два — want | «Ты отличил потребности от желаний.» | «Подумай, без чего забота нужна сейчас, а что можно отложить.» |

Три неверные попытки закрывают новые попытки только до следующего периода. В пятом завершенном демопериоде задания доступны как `demo_completed_review`: объяснения можно смотреть, награды не выдаются, UI предлагает `reset_demo`. Ни одно задание не остается без объяснения.

## 9. Эффекты действий на питомца

Начальное состояние: satiety 60, mood 60, `calm`, stage `baby`.

| Действие | Satiety | Mood | Reason | Детское объяснение |
| --- | ---: | ---: | --- | --- |
| создание/reset | установить 60 | установить 60 | `profile_created` / `demo_reset` | «Финни готов учиться вместе с тобой.» |
| confirmBudget | 0 | +2 | `plan_confirmed` | «План помогает Финни понимать следующий шаг.» |
| покупка | по таблице товаров | по таблице товаров | item reason | название результата покупки |
| первое положительное чистое пополнение периода | 0 | +2 один раз | `savings_deposit_first_positive` | «Часть монет стала ближе к цели.» |
| последующие пополнения периода | 0 | 0 | `savings_deposit` | «Накопления обновлены.» |
| обычное снятие | 0 | 0 | `savings_withdrawal` | «Монеты снова доступны; прогресс этого периода пересчитан.» |
| верное задание | 0 | +4 | `task_correct` | текст correct задания |
| неверное задание | 0 | −2 | `task_needs_retry` | спокойная подсказка задания |
| смена цели | 0 | 0 | `goal_changed` | «Накопления сохранились для новой цели.» |
| завершение цели | 0 | +12 | `goal_redeemed` | «Цель достигнута, а лишние монеты сохранились.» |
| finishPeriod с 2–3 баллами | −10 | +4 | `period_finished_strong` | «Хороший период: нужное и план помогли Финни.» |
| finishPeriod с 1 баллом | −10 | +1 | `period_finished_mixed` | «Часть плана получилась; в новом периоде можно продолжить.» |
| finishPeriod с 0 баллов | −10 | −2 | `period_finished_recoverable` | «Этот период был сложным, но следующий даст новый шанс.» |
| rejected/preview/cancel/storage rollback | 0 | 0 | нет | состояние не меняется |

Stage пересчитывается только `finishPeriod`. Изменение стадии включается в тот же `PetDelta`, что эффект завершения. Ошибки не вызывают стыда, угроз жизни, потери питомца или отката достигнутой стадии.

## 10. Демонстрация пяти периодов с эффектами

Активная цель — `goal.playground`. Обозначения плана: needs/wants/savings.

| Период | Начало: деньги; savings; S/M | План | Задания | Покупки и накопления | Конец: деньги; savings; S/M | Качество; стадия |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | 100; 0; 60/60 | 50/20/30 | budget.01 и savings.01, +10 | food 30, hygiene 20, deposit 30 | 30; 30; 65/84 | +3=3; baby |
| 2 | 130; 30; 65/84 | 45/35/30 | payments.01, +5 | lunch 25, hygiene 20, ball 35, deposit 30 | 25; 60; 65/100 | +3=6; junior |
| 3 | 125; 60; 65/100 | 50/45/30 | payments.02: ошибка, затем верно, +5 | food 30, hygiene 20, hat 45, deposit 30 | 5; 90; 70/100 | +3=9; junior |
| 4 | 105; 90; 70/100 | 70/0/25 | budget.02, +5 | health 40, food 30, deposit 25 | 15; 115; 80/100 | +3=12; grown |
| 5 | 115; 115; 80/100 | 50/35/30 | savings.02, +5 | food 30, hygiene 20, ball 35, deposit 30, redeem goal 120 | 5; 25; 85/100 | +3=15; grown |

Арифметика денег остается: конечные пары `(available, savings)` — `(30,30)`, `(25,60)`, `(5,90)`, `(15,115)`, `(5,25)`. Сумма доходов 500, наград 30, покупок 380 и цели 120 дает конечные общие деньги 30.

### 10.1. Обязательные дополнительные шаги демонстрации

После финансовых действий периода 1, пока период еще `open` и `available = 30`, выполняется preview покупки `item.music_player` за 70. Результат: `allowed = false`, `insufficient_funds`, недостача 40, деньги, слот, питомец и история не меняются. Только после этой проверки вызывается `finishPeriod`.

Затем приложение закрывается и запускается. `listProfiles` находит demo, `loadState` возвращает те же 30 доступных, 30 накоплений, завершенный период 1, показатели 65/84 и `stateRevision`. Повторного дохода нет.

После пятого периода взрослый открывает управление данными, подтверждает reset demo. Generation увеличивается, новый период 1 получает ровно 100 монет, обычный профиль не затрагивается. Повтор reset с тем же `actionId` возвращает `replayed` и не начисляет еще 100.

### 10.2. Плохая серия

Контрольный расчет: в каждом из пяти периодов подтвердить план 0/100/0 с `needs_underfunded`, купить только желание, ничего не накопить и завершить период с `mandatory_needs_unmet`. Факт укладывается в такой план, поэтому каждый период дает 1 балл за `planKept`, но 0 за обязательные покупки и накопления. После пяти периодов `qualityPoints = 5`, stage остается `baby`. Mood и satiety ограничиваются нулем, профиль и накопленная история не удаляются.

## 11. Полные примеры состояний

Ниже объекты содержат все поля `GameState`. Время фиксировано только для воспроизводимости фикстур. Списки заданий содержат все шесть ID. Отдельные сценарии не продолжают друг друга, если явно не сказано обратное.

### 11.1. Профиль отсутствует

```json
{
  "found": false,
  "stateSnapshot": null,
  "errorCode": null,
  "messageForChild": null
}
```

### 11.2. Новый демопрофиль `state.new_demo`

```json
{
  "contractVersion": "logic_contract_v0.1",
  "contentVersion": "content_v0.2",
  "stateRevision": 1,
  "profile": {
    "id": "profile.demo.01",
    "mode": "demo",
    "displayName": null,
    "petName": "Финни",
    "generation": 1,
    "createdAt": "2026-09-24T09:00:00Z",
    "updatedAt": "2026-09-24T09:00:00Z"
  },
  "currentPeriod": {
    "id": "profile.demo.01.g1.p1",
    "number": 1,
    "status": "open",
    "incomeCredited": 100,
    "incomeCreditedAt": "2026-09-24T09:00:00Z",
    "availableItemIds": ["item.food", "item.hygiene", "item.ball", "item.music_player"],
    "requiredPurchases": [
      {"itemId": "item.food", "quantity": 1, "fulfilled": false},
      {"itemId": "item.hygiene", "quantity": 1, "fulfilled": false}
    ],
    "purchaseSlotsTotal": 3,
    "purchaseSlotsUsed": 0,
    "purchasedItemIds": [],
    "budgetPlan": null,
    "actual": {
      "periodIncome": 100,
      "taskRewards": 0,
      "needsSpent": 0,
      "wantsSpent": 0,
      "savingsDeposited": 0,
      "ordinarySavingsWithdrawn": 0,
      "goalRedemptionSpent": 0,
      "qualifyingSavings": 0,
      "savingsMoodBonusGranted": false,
      "requiredNeedsMet": false,
      "planKept": false,
      "savingsHabitKept": false
    },
    "startedAt": "2026-09-24T09:00:00Z",
    "closedAt": null
  },
  "availableBalance": 100,
  "savingsBalance": 0,
  "activeGoal": null,
  "pet": {
    "name": "Финни",
    "formId": "pet.form.01",
    "paletteId": "pet.palette.01",
    "satiety": 60,
    "mood": 60,
    "moodCode": "calm",
    "stage": "baby",
    "lastReasonCode": "profile_created",
    "explanationForChild": "Финни готов учиться вместе с тобой."
  },
  "taskHub": {
    "recommendedTask": {"id":"task.budget.01","title":"Распредели доход","theme":"budget","interactionType":"budget_allocation","rewardAmount":5,"availability":"available","unavailableReason":null,"completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3},
    "tasks": [
      {"id":"task.budget.01","title":"Распредели доход","theme":"budget","interactionType":"budget_allocation","rewardAmount":5,"availability":"available","unavailableReason":null,"completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3},
      {"id":"task.budget.02","title":"Сравни план и факт","theme":"budget","interactionType":"plan_fact_choice","rewardAmount":5,"availability":"available","unavailableReason":null,"completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3},
      {"id":"task.savings.01","title":"Составь путь к цели","theme":"savings","interactionType":"savings_schedule","rewardAmount":5,"availability":"available","unavailableReason":null,"completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3},
      {"id":"task.savings.02","title":"Посчитай накопления","theme":"savings","interactionType":"savings_comparison","rewardAmount":5,"availability":"available","unavailableReason":null,"completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3},
      {"id":"task.payments.01","title":"Собери корзину","theme":"payments_and_purchases","interactionType":"purchase_basket","rewardAmount":5,"availability":"available","unavailableReason":null,"completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3},
      {"id":"task.payments.02","title":"Нужное или желаемое","theme":"payments_and_purchases","interactionType":"expense_classification","rewardAmount":5,"availability":"available","unavailableReason":null,"completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3}
    ]
  },
  "learningProgress": {
    "completedPeriods": 0,
    "qualityPoints": 0,
    "taskProgress": [
      {"taskId":"task.budget.01","completed":false,"attemptsTotal":0,"attemptsThisPeriod":0,"lastOutcome":null,"rewardState":"available","completedAt":null},
      {"taskId":"task.budget.02","completed":false,"attemptsTotal":0,"attemptsThisPeriod":0,"lastOutcome":null,"rewardState":"available","completedAt":null},
      {"taskId":"task.savings.01","completed":false,"attemptsTotal":0,"attemptsThisPeriod":0,"lastOutcome":null,"rewardState":"available","completedAt":null},
      {"taskId":"task.savings.02","completed":false,"attemptsTotal":0,"attemptsThisPeriod":0,"lastOutcome":null,"rewardState":"available","completedAt":null},
      {"taskId":"task.payments.01","completed":false,"attemptsTotal":0,"attemptsThisPeriod":0,"lastOutcome":null,"rewardState":"available","completedAt":null},
      {"taskId":"task.payments.02","completed":false,"attemptsTotal":0,"attemptsThisPeriod":0,"lastOutcome":null,"rewardState":"available","completedAt":null}
    ],
    "stageHistory": [
      {"stage":"baby","reachedAfterPeriod":0,"qualityPoints":0,"reachedAt":"2026-09-24T09:00:00Z"}
    ]
  },
  "settings": {
    "soundEnabled": true,
    "reducedMotion": false,
    "largeTextPreferred": false
  }
}
```

### 11.3. Открытый период 1 после действий `state.period1_after_actions`

Это ветка успешного периода до `finishPeriod`. Она используется как полный источник для проверки нехватки средств и снятия.

```json
{
  "contractVersion":"logic_contract_v0.1",
  "contentVersion":"content_v0.2",
  "stateRevision":9,
  "profile":{"id":"profile.demo.01","mode":"demo","displayName":null,"petName":"Финни","generation":1,"createdAt":"2026-09-24T09:00:00Z","updatedAt":"2026-09-24T09:18:00Z"},
  "currentPeriod":{
    "id":"profile.demo.01.g1.p1","number":1,"status":"open","incomeCredited":100,"incomeCreditedAt":"2026-09-24T09:00:00Z",
    "availableItemIds":["item.food","item.hygiene","item.ball","item.music_player"],
    "requiredPurchases":[{"itemId":"item.food","quantity":1,"fulfilled":true},{"itemId":"item.hygiene","quantity":1,"fulfilled":true}],
    "purchaseSlotsTotal":3,"purchaseSlotsUsed":2,"purchasedItemIds":["item.food","item.hygiene"],
    "budgetPlan":{"periodId":"profile.demo.01.g1.p1","needsLimit":50,"wantsLimit":20,"savingsTarget":30,"unallocatedAmount":0,"requiredNeedsCostAtConfirmation":50,"confirmedAt":"2026-09-24T09:02:00Z"},
    "actual":{"periodIncome":100,"taskRewards":10,"needsSpent":50,"wantsSpent":0,"savingsDeposited":30,"ordinarySavingsWithdrawn":0,"goalRedemptionSpent":0,"qualifyingSavings":30,"savingsMoodBonusGranted":true,"requiredNeedsMet":true,"planKept":true,"savingsHabitKept":true},
    "startedAt":"2026-09-24T09:00:00Z","closedAt":null
  },
  "availableBalance":30,
  "savingsBalance":30,
  "activeGoal":{"goalId":"goal.playground","title":"Игровая площадка для Финни","targetAmount":120,"savedAmount":30,"remainingAmount":90,"status":"selected","selectedAt":"2026-09-24T09:03:00Z","completedAt":null},
  "pet":{"name":"Финни","formId":"pet.form.01","paletteId":"pet.palette.01","satiety":75,"mood":80,"moodCode":"happy","stage":"baby","lastReasonCode":"savings_deposit","explanationForChild":"Часть монет стала ближе к цели."},
  "taskHub":{
    "recommendedTask":{"id":"task.budget.02","title":"Сравни план и факт","theme":"budget","interactionType":"plan_fact_choice","rewardAmount":5,"availability":"available","unavailableReason":null,"completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3},
    "tasks":[
      {"id":"task.budget.01","title":"Распредели доход","theme":"budget","interactionType":"budget_allocation","rewardAmount":5,"availability":"completed_review","unavailableReason":null,"completed":true,"rewardState":"granted","attemptsThisPeriod":1,"remainingAttempts":2},
      {"id":"task.budget.02","title":"Сравни план и факт","theme":"budget","interactionType":"plan_fact_choice","rewardAmount":5,"availability":"available","unavailableReason":null,"completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3},
      {"id":"task.savings.01","title":"Составь путь к цели","theme":"savings","interactionType":"savings_schedule","rewardAmount":5,"availability":"completed_review","unavailableReason":null,"completed":true,"rewardState":"granted","attemptsThisPeriod":1,"remainingAttempts":2},
      {"id":"task.savings.02","title":"Посчитай накопления","theme":"savings","interactionType":"savings_comparison","rewardAmount":5,"availability":"available","unavailableReason":null,"completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3},
      {"id":"task.payments.01","title":"Собери корзину","theme":"payments_and_purchases","interactionType":"purchase_basket","rewardAmount":5,"availability":"available","unavailableReason":null,"completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3},
      {"id":"task.payments.02","title":"Нужное или желаемое","theme":"payments_and_purchases","interactionType":"expense_classification","rewardAmount":5,"availability":"available","unavailableReason":null,"completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3}
    ]
  },
  "learningProgress":{
    "completedPeriods":0,"qualityPoints":0,
    "taskProgress":[
      {"taskId":"task.budget.01","completed":true,"attemptsTotal":1,"attemptsThisPeriod":1,"lastOutcome":"correct","rewardState":"granted","completedAt":"2026-09-24T09:05:00Z"},
      {"taskId":"task.budget.02","completed":false,"attemptsTotal":0,"attemptsThisPeriod":0,"lastOutcome":null,"rewardState":"available","completedAt":null},
      {"taskId":"task.savings.01","completed":true,"attemptsTotal":1,"attemptsThisPeriod":1,"lastOutcome":"correct","rewardState":"granted","completedAt":"2026-09-24T09:07:00Z"},
      {"taskId":"task.savings.02","completed":false,"attemptsTotal":0,"attemptsThisPeriod":0,"lastOutcome":null,"rewardState":"available","completedAt":null},
      {"taskId":"task.payments.01","completed":false,"attemptsTotal":0,"attemptsThisPeriod":0,"lastOutcome":null,"rewardState":"available","completedAt":null},
      {"taskId":"task.payments.02","completed":false,"attemptsTotal":0,"attemptsThisPeriod":0,"lastOutcome":null,"rewardState":"available","completedAt":null}
    ],
    "stageHistory":[{"stage":"baby","reachedAfterPeriod":0,"qualityPoints":0,"reachedAt":"2026-09-24T09:00:00Z"}]
  },
  "settings":{"soundEnabled":true,"reducedMotion":false,"largeTextPreferred":false}
}
```

### 11.4. После подтвержденного снятия `state.period1_after_withdrawal`

Это продолжение `state.period1_after_actions`: снято 10 монет. Все поля приведены полностью.

```json
{
  "contractVersion":"logic_contract_v0.1",
  "contentVersion":"content_v0.2",
  "stateRevision":10,
  "profile":{"id":"profile.demo.01","mode":"demo","displayName":null,"petName":"Финни","generation":1,"createdAt":"2026-09-24T09:00:00Z","updatedAt":"2026-09-24T09:19:00Z"},
  "currentPeriod":{
    "id":"profile.demo.01.g1.p1","number":1,"status":"open","incomeCredited":100,"incomeCreditedAt":"2026-09-24T09:00:00Z",
    "availableItemIds":["item.food","item.hygiene","item.ball","item.music_player"],
    "requiredPurchases":[{"itemId":"item.food","quantity":1,"fulfilled":true},{"itemId":"item.hygiene","quantity":1,"fulfilled":true}],
    "purchaseSlotsTotal":3,"purchaseSlotsUsed":2,"purchasedItemIds":["item.food","item.hygiene"],
    "budgetPlan":{"periodId":"profile.demo.01.g1.p1","needsLimit":50,"wantsLimit":20,"savingsTarget":30,"unallocatedAmount":0,"requiredNeedsCostAtConfirmation":50,"confirmedAt":"2026-09-24T09:02:00Z"},
    "actual":{"periodIncome":100,"taskRewards":10,"needsSpent":50,"wantsSpent":0,"savingsDeposited":30,"ordinarySavingsWithdrawn":10,"goalRedemptionSpent":0,"qualifyingSavings":20,"savingsMoodBonusGranted":true,"requiredNeedsMet":true,"planKept":false,"savingsHabitKept":true},
    "startedAt":"2026-09-24T09:00:00Z","closedAt":null
  },
  "availableBalance":40,
  "savingsBalance":20,
  "activeGoal":{"goalId":"goal.playground","title":"Игровая площадка для Финни","targetAmount":120,"savedAmount":20,"remainingAmount":100,"status":"selected","selectedAt":"2026-09-24T09:03:00Z","completedAt":null},
  "pet":{"name":"Финни","formId":"pet.form.01","paletteId":"pet.palette.01","satiety":75,"mood":80,"moodCode":"happy","stage":"baby","lastReasonCode":"savings_withdrawal","explanationForChild":"Монеты снова доступны; прогресс этого периода пересчитан."},
  "taskHub":{
    "recommendedTask":{"id":"task.budget.02","title":"Сравни план и факт","theme":"budget","interactionType":"plan_fact_choice","rewardAmount":5,"availability":"available","unavailableReason":null,"completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3},
    "tasks":[
      {"id":"task.budget.01","title":"Распредели доход","theme":"budget","interactionType":"budget_allocation","rewardAmount":5,"availability":"completed_review","unavailableReason":null,"completed":true,"rewardState":"granted","attemptsThisPeriod":1,"remainingAttempts":2},
      {"id":"task.budget.02","title":"Сравни план и факт","theme":"budget","interactionType":"plan_fact_choice","rewardAmount":5,"availability":"available","unavailableReason":null,"completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3},
      {"id":"task.savings.01","title":"Составь путь к цели","theme":"savings","interactionType":"savings_schedule","rewardAmount":5,"availability":"completed_review","unavailableReason":null,"completed":true,"rewardState":"granted","attemptsThisPeriod":1,"remainingAttempts":2},
      {"id":"task.savings.02","title":"Посчитай накопления","theme":"savings","interactionType":"savings_comparison","rewardAmount":5,"availability":"available","unavailableReason":null,"completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3},
      {"id":"task.payments.01","title":"Собери корзину","theme":"payments_and_purchases","interactionType":"purchase_basket","rewardAmount":5,"availability":"available","unavailableReason":null,"completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3},
      {"id":"task.payments.02","title":"Нужное или желаемое","theme":"payments_and_purchases","interactionType":"expense_classification","rewardAmount":5,"availability":"available","unavailableReason":null,"completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3}
    ]
  },
  "learningProgress":{
    "completedPeriods":0,"qualityPoints":0,
    "taskProgress":[
      {"taskId":"task.budget.01","completed":true,"attemptsTotal":1,"attemptsThisPeriod":1,"lastOutcome":"correct","rewardState":"granted","completedAt":"2026-09-24T09:05:00Z"},
      {"taskId":"task.budget.02","completed":false,"attemptsTotal":0,"attemptsThisPeriod":0,"lastOutcome":null,"rewardState":"available","completedAt":null},
      {"taskId":"task.savings.01","completed":true,"attemptsTotal":1,"attemptsThisPeriod":1,"lastOutcome":"correct","rewardState":"granted","completedAt":"2026-09-24T09:07:00Z"},
      {"taskId":"task.savings.02","completed":false,"attemptsTotal":0,"attemptsThisPeriod":0,"lastOutcome":null,"rewardState":"available","completedAt":null},
      {"taskId":"task.payments.01","completed":false,"attemptsTotal":0,"attemptsThisPeriod":0,"lastOutcome":null,"rewardState":"available","completedAt":null},
      {"taskId":"task.payments.02","completed":false,"attemptsTotal":0,"attemptsThisPeriod":0,"lastOutcome":null,"rewardState":"available","completedAt":null}
    ],
    "stageHistory":[{"stage":"baby","reachedAfterPeriod":0,"qualityPoints":0,"reachedAt":"2026-09-24T09:00:00Z"}]
  },
  "settings":{"soundEnabled":true,"reducedMotion":false,"largeTextPreferred":false}
}
```

### 11.5. Закрытый период 1 после успешного сценария `state.period1_closed`

```json
{
  "contractVersion":"logic_contract_v0.1",
  "contentVersion":"content_v0.2",
  "stateRevision":10,
  "profile":{"id":"profile.demo.01","mode":"demo","displayName":null,"petName":"Финни","generation":1,"createdAt":"2026-09-24T09:00:00Z","updatedAt":"2026-09-24T09:20:00Z"},
  "currentPeriod":{
    "id":"profile.demo.01.g1.p1","number":1,"status":"closed","incomeCredited":100,"incomeCreditedAt":"2026-09-24T09:00:00Z",
    "availableItemIds":["item.food","item.hygiene","item.ball","item.music_player"],
    "requiredPurchases":[{"itemId":"item.food","quantity":1,"fulfilled":true},{"itemId":"item.hygiene","quantity":1,"fulfilled":true}],
    "purchaseSlotsTotal":3,"purchaseSlotsUsed":2,"purchasedItemIds":["item.food","item.hygiene"],
    "budgetPlan":{"periodId":"profile.demo.01.g1.p1","needsLimit":50,"wantsLimit":20,"savingsTarget":30,"unallocatedAmount":0,"requiredNeedsCostAtConfirmation":50,"confirmedAt":"2026-09-24T09:02:00Z"},
    "actual":{"periodIncome":100,"taskRewards":10,"needsSpent":50,"wantsSpent":0,"savingsDeposited":30,"ordinarySavingsWithdrawn":0,"goalRedemptionSpent":0,"qualifyingSavings":30,"savingsMoodBonusGranted":true,"requiredNeedsMet":true,"planKept":true,"savingsHabitKept":true},
    "startedAt":"2026-09-24T09:00:00Z","closedAt":"2026-09-24T09:20:00Z"
  },
  "availableBalance":30,
  "savingsBalance":30,
  "activeGoal":{"goalId":"goal.playground","title":"Игровая площадка для Финни","targetAmount":120,"savedAmount":30,"remainingAmount":90,"status":"selected","selectedAt":"2026-09-24T09:03:00Z","completedAt":null},
  "pet":{"name":"Финни","formId":"pet.form.01","paletteId":"pet.palette.01","satiety":65,"mood":84,"moodCode":"happy","stage":"baby","lastReasonCode":"period_finished_strong","explanationForChild":"Хороший период: нужное и план помогли Финни."},
  "taskHub":{
    "recommendedTask":{"id":"task.budget.02","title":"Сравни план и факт","theme":"budget","interactionType":"plan_fact_choice","rewardAmount":5,"availability":"period_closed","unavailableReason":"Сначала начни следующий период.","completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3},
    "tasks":[
      {"id":"task.budget.01","title":"Распредели доход","theme":"budget","interactionType":"budget_allocation","rewardAmount":5,"availability":"completed_review","unavailableReason":null,"completed":true,"rewardState":"granted","attemptsThisPeriod":1,"remainingAttempts":2},
      {"id":"task.budget.02","title":"Сравни план и факт","theme":"budget","interactionType":"plan_fact_choice","rewardAmount":5,"availability":"period_closed","unavailableReason":"Сначала начни следующий период.","completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3},
      {"id":"task.savings.01","title":"Составь путь к цели","theme":"savings","interactionType":"savings_schedule","rewardAmount":5,"availability":"completed_review","unavailableReason":null,"completed":true,"rewardState":"granted","attemptsThisPeriod":1,"remainingAttempts":2},
      {"id":"task.savings.02","title":"Посчитай накопления","theme":"savings","interactionType":"savings_comparison","rewardAmount":5,"availability":"period_closed","unavailableReason":"Сначала начни следующий период.","completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3},
      {"id":"task.payments.01","title":"Собери корзину","theme":"payments_and_purchases","interactionType":"purchase_basket","rewardAmount":5,"availability":"period_closed","unavailableReason":"Сначала начни следующий период.","completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3},
      {"id":"task.payments.02","title":"Нужное или желаемое","theme":"payments_and_purchases","interactionType":"expense_classification","rewardAmount":5,"availability":"period_closed","unavailableReason":"Сначала начни следующий период.","completed":false,"rewardState":"available","attemptsThisPeriod":0,"remainingAttempts":3}
    ]
  },
  "learningProgress":{
    "completedPeriods":1,"qualityPoints":3,
    "taskProgress":[
      {"taskId":"task.budget.01","completed":true,"attemptsTotal":1,"attemptsThisPeriod":1,"lastOutcome":"correct","rewardState":"granted","completedAt":"2026-09-24T09:05:00Z"},
      {"taskId":"task.budget.02","completed":false,"attemptsTotal":0,"attemptsThisPeriod":0,"lastOutcome":null,"rewardState":"available","completedAt":null},
      {"taskId":"task.savings.01","completed":true,"attemptsTotal":1,"attemptsThisPeriod":1,"lastOutcome":"correct","rewardState":"granted","completedAt":"2026-09-24T09:07:00Z"},
      {"taskId":"task.savings.02","completed":false,"attemptsTotal":0,"attemptsThisPeriod":0,"lastOutcome":null,"rewardState":"available","completedAt":null},
      {"taskId":"task.payments.01","completed":false,"attemptsTotal":0,"attemptsThisPeriod":0,"lastOutcome":null,"rewardState":"available","completedAt":null},
      {"taskId":"task.payments.02","completed":false,"attemptsTotal":0,"attemptsThisPeriod":0,"lastOutcome":null,"rewardState":"available","completedAt":null}
    ],
    "stageHistory":[{"stage":"baby","reachedAfterPeriod":0,"qualityPoints":0,"reachedAt":"2026-09-24T09:00:00Z"}]
  },
  "settings":{"soundEnabled":true,"reducedMotion":false,"largeTextPreferred":false}
}
```

### 11.6. Завершенное демо `state.demo_completed`

```json
{
  "contractVersion":"logic_contract_v0.1",
  "contentVersion":"content_v0.2",
  "stateRevision":46,
  "profile":{"id":"profile.demo.01","mode":"demo","displayName":null,"petName":"Финни","generation":1,"createdAt":"2026-09-24T09:00:00Z","updatedAt":"2026-09-24T10:30:00Z"},
  "currentPeriod":{
    "id":"profile.demo.01.g1.p5","number":5,"status":"demo_completed","incomeCredited":100,"incomeCreditedAt":"2026-09-24T10:00:00Z",
    "availableItemIds":["item.food","item.hygiene","item.ball","item.hat"],
    "requiredPurchases":[{"itemId":"item.food","quantity":1,"fulfilled":true},{"itemId":"item.hygiene","quantity":1,"fulfilled":true}],
    "purchaseSlotsTotal":3,"purchaseSlotsUsed":3,"purchasedItemIds":["item.food","item.hygiene","item.ball"],
    "budgetPlan":{"periodId":"profile.demo.01.g1.p5","needsLimit":50,"wantsLimit":35,"savingsTarget":30,"unallocatedAmount":0,"requiredNeedsCostAtConfirmation":50,"confirmedAt":"2026-09-24T10:02:00Z"},
    "actual":{"periodIncome":100,"taskRewards":5,"needsSpent":50,"wantsSpent":35,"savingsDeposited":30,"ordinarySavingsWithdrawn":0,"goalRedemptionSpent":120,"qualifyingSavings":30,"savingsMoodBonusGranted":true,"requiredNeedsMet":true,"planKept":true,"savingsHabitKept":true},
    "startedAt":"2026-09-24T10:00:00Z","closedAt":"2026-09-24T10:30:00Z"
  },
  "availableBalance":5,
  "savingsBalance":25,
  "activeGoal":null,
  "pet":{"name":"Финни","formId":"pet.form.01","paletteId":"pet.palette.01","satiety":85,"mood":100,"moodCode":"happy","stage":"grown","lastReasonCode":"period_finished_strong","explanationForChild":"Пять периодов завершены. Можно посмотреть результаты или начать демо заново."},
  "taskHub":{
    "recommendedTask":null,
    "tasks":[
      {"id":"task.budget.01","title":"Распредели доход","theme":"budget","interactionType":"budget_allocation","rewardAmount":5,"availability":"demo_completed_review","unavailableReason":"Награда уже получена; доступен просмотр.","completed":true,"rewardState":"already_granted","attemptsThisPeriod":0,"remainingAttempts":3},
      {"id":"task.budget.02","title":"Сравни план и факт","theme":"budget","interactionType":"plan_fact_choice","rewardAmount":5,"availability":"demo_completed_review","unavailableReason":"Награда уже получена; доступен просмотр.","completed":true,"rewardState":"already_granted","attemptsThisPeriod":0,"remainingAttempts":3},
      {"id":"task.savings.01","title":"Составь путь к цели","theme":"savings","interactionType":"savings_schedule","rewardAmount":5,"availability":"demo_completed_review","unavailableReason":"Награда уже получена; доступен просмотр.","completed":true,"rewardState":"already_granted","attemptsThisPeriod":0,"remainingAttempts":3},
      {"id":"task.savings.02","title":"Посчитай накопления","theme":"savings","interactionType":"savings_comparison","rewardAmount":5,"availability":"demo_completed_review","unavailableReason":"Награда уже получена; доступен просмотр.","completed":true,"rewardState":"already_granted","attemptsThisPeriod":1,"remainingAttempts":2},
      {"id":"task.payments.01","title":"Собери корзину","theme":"payments_and_purchases","interactionType":"purchase_basket","rewardAmount":5,"availability":"demo_completed_review","unavailableReason":"Награда уже получена; доступен просмотр.","completed":true,"rewardState":"already_granted","attemptsThisPeriod":0,"remainingAttempts":3},
      {"id":"task.payments.02","title":"Нужное или желаемое","theme":"payments_and_purchases","interactionType":"expense_classification","rewardAmount":5,"availability":"demo_completed_review","unavailableReason":"Награда уже получена; доступен просмотр.","completed":true,"rewardState":"already_granted","attemptsThisPeriod":0,"remainingAttempts":3}
    ]
  },
  "learningProgress":{
    "completedPeriods":5,"qualityPoints":15,
    "taskProgress":[
      {"taskId":"task.budget.01","completed":true,"attemptsTotal":1,"attemptsThisPeriod":0,"lastOutcome":"correct","rewardState":"granted","completedAt":"2026-09-24T09:05:00Z"},
      {"taskId":"task.budget.02","completed":true,"attemptsTotal":1,"attemptsThisPeriod":0,"lastOutcome":"correct","rewardState":"granted","completedAt":"2026-09-24T09:50:00Z"},
      {"taskId":"task.savings.01","completed":true,"attemptsTotal":1,"attemptsThisPeriod":0,"lastOutcome":"correct","rewardState":"granted","completedAt":"2026-09-24T09:07:00Z"},
      {"taskId":"task.savings.02","completed":true,"attemptsTotal":1,"attemptsThisPeriod":1,"lastOutcome":"correct","rewardState":"granted","completedAt":"2026-09-24T10:05:00Z"},
      {"taskId":"task.payments.01","completed":true,"attemptsTotal":1,"attemptsThisPeriod":0,"lastOutcome":"correct","rewardState":"granted","completedAt":"2026-09-24T09:25:00Z"},
      {"taskId":"task.payments.02","completed":true,"attemptsTotal":2,"attemptsThisPeriod":0,"lastOutcome":"correct","rewardState":"granted","completedAt":"2026-09-24T09:38:00Z"}
    ],
    "stageHistory":[
      {"stage":"baby","reachedAfterPeriod":0,"qualityPoints":0,"reachedAt":"2026-09-24T09:00:00Z"},
      {"stage":"junior","reachedAfterPeriod":2,"qualityPoints":6,"reachedAt":"2026-09-24T09:30:00Z"},
      {"stage":"grown","reachedAfterPeriod":4,"qualityPoints":12,"reachedAt":"2026-09-24T10:00:00Z"}
    ]
  },
  "settings":{"soundEnabled":true,"reducedMotion":false,"largeTextPreferred":false}
}
```

## 12. Самостоятельные сценарии результатов для UI-адаптера

Сценарии ниже используют тестовый `FixtureCase`: `sourceStateId` и `expectedStateId` ссылаются только на полностью приведенные объекты раздела 11. Это формат манифеста фикстур, а не модель API. Перед возвратом из fake adapter ссылка обязательно разрешается, и в настоящем `PreviewResult.stateSnapshot` или `ActionResult.stateSnapshot` находится полный объект `GameState`.

### 12.1. Нехватка средств

Исходное состояние: полный `state.period1_after_actions`; цена music_player = 70, доступно 30. Test-only fixture case:

```json
{
  "fixtureCaseId":"case.purchase.insufficient",
  "sourceStateId":"state.period1_after_actions",
  "request":{"method":"previewPurchase","itemId":"item.music_player","expectedGeneration":1,"expectedRevision":9},
  "expectedPreview":{"allowed":false,"errorCode":"insufficient_funds","warnings":[],"messageForChild":"Не хватает 40 монет. Можно выбрать другой предмет или накопить.","expectedMoneyDelta":null,"expectedPetDelta":null,"nextActions":[{"code":"open_catalog","params":{"maxPrice":30}},{"code":"open_tasks","params":{}}]},
  "expectedStateId":"state.period1_after_actions"
}
```

Ожидание: ревизия, деньги, purchaseSlotsUsed, питомец и история неизменны.

### 12.2. Подтвержденное снятие

Исходное состояние: полный `state.period1_after_actions`. Preview снятия 10 возвращает `savings_withdrawal`. После принятия используется test-only fixture case:

```json
{
  "fixtureCaseId":"case.savings.withdraw_confirmed",
  "sourceStateId":"state.period1_after_actions",
  "request":{"method":"transferSavings","actionId":"fixture.withdraw.01","expectedGeneration":1,"expectedRevision":9,"acceptedWarnings":["savings_withdrawal"],"direction":"from_savings","amount":10},
  "expectedActionResult":{"success":true,"outcome":"applied","actionId":"fixture.withdraw.01","operationAppliedRevision":10,"errorCode":null,"messageForChild":"10 монет снова доступны. Накопления этого периода пересчитаны.","moneyDelta":{"availableChange":10,"savingsChange":-10,"incomeChange":0,"rewardChange":0,"reasonCode":"savings_withdrawal"},"petDelta":{"satietyBefore":75,"satietyAfter":75,"moodBefore":80,"moodAfter":80,"moodCodeBefore":"happy","moodCodeAfter":"happy","stageBefore":"baby","stageAfter":"baby","reasonCode":"savings_withdrawal","explanationForChild":"Монеты снова доступны; прогресс этого периода пересчитан."},"taskAttempt":null,"periodSummary":null,"nextActions":[{"code":"continue_period","params":{}}]},
  "expectedStateId":"state.period1_after_withdrawal"
}
```

### 12.3. Неверное задание

Исходное независимое состояние: open period 3, mood 100, первая попытка payments.02. Результат содержит `success = true`, mood 98 и:

```json
{
  "taskId":"task.payments.02",
  "attemptNumberThisPeriod":1,
  "outcome":"needs_retry",
  "explanation":"Подумай, без чего забота нужна сейчас, а что можно отложить.",
  "rewardGranted":false,
  "rewardAmount":0,
  "rewardState":"not_earned",
  "remainingAttempts":2,
  "completedNow":false
}
```

Деньги неизменны. Следующее действие — `retry_task`.

### 12.4. `stale_state`

Исходный UI-снимок: полный `state.period1_after_actions`, generation 1, revision 9. До отправки другая команда создала полный `state.period1_after_withdrawal`, revision 10. Test-only fixture case:

```json
{
  "fixtureCaseId":"case.purchase.stale_state",
  "sourceStateId":"state.period1_after_actions",
  "currentStateId":"state.period1_after_withdrawal",
  "request":{"method":"buyItem","actionId":"fixture.stale.01","expectedGeneration":1,"expectedRevision":9,"acceptedWarnings":[],"itemId":"item.ball"},
  "expectedActionResult":{"success":false,"outcome":"rejected","actionId":"fixture.stale.01","operationAppliedRevision":null,"errorCode":"stale_state","messageForChild":"Состояние изменилось. Проверь обновленные последствия еще раз.","moneyDelta":null,"petDelta":null,"taskAttempt":null,"periodSummary":null,"nextActions":[{"code":"repeat_preview","params":{}}]},
  "expectedStateId":"state.period1_after_withdrawal"
}
```

UI не отправляет старый confirm повторно: показывает актуальный preview и создает новый `actionId` для нового намерения.

### 12.5. Replayed без отката

Покупка A применена на revision 3, затем B создала revision 4. Повтор A возвращает `outcome = replayed`, `operationAppliedRevision = 3`, исходные дельты A, но полный `stateSnapshot` revision 4. UI не повторяет анимацию A и не заменяет экран ревизией 3.

### 12.6. Reset demo

Исходное состояние: полный `state.demo_completed`, generation 1, revision 46. После reset: generation 2, revision 47, новый period 1, available 100, savings 0, pet 60/60 baby, progress пуст, все задания available. Receipt reset сохраняется. Повтор той же команды возвращает `replayed` и актуальный снимок generation 2 без второго дохода.

### 12.7. Delete и повтор delete

Первый delete после подтверждения возвращает `applied`, `stateSnapshot = null`. Профиль исчезает из `listProfiles`, но tombstone и receipt сохраняются. Повтор с тем же `actionId` возвращает `replayed`, `stateSnapshot = null`. Новый профиль получает новый ID.

### 12.8. Ошибка хранения

При rollback:

```json
{
  "success":false,
  "outcome":"rejected",
  "actionId":"fixture.storage.01",
  "operationAppliedRevision":null,
  "errorCode":"storage_error",
  "messageForChild":"Не удалось надежно сохранить действие. Попробуй еще раз.",
  "stateSnapshot":null,
  "moneyDelta":null,
  "petDelta":null,
  "taskAttempt":null,
  "periodSummary":null,
  "nextActions":[{"code":"retry_same_action","params":{"reuseActionId":true}}]
}
```

UI не изображает успех. Повтор использует тот же `actionId`, поскольку неизвестно, получил ли UI ответ commit.

## 13. Хранение и будущие файлы

Предлагаемые SQLite-таблицы: `profiles`, `game_state`, `periods`, `budget_plans`, `transactions`, `task_progress`, `stage_history`, `action_receipts`, `deleted_profile_tombstones`, `settings`. Контент хранится в versioned JSON assets; транзакция хранит ID, цену и contentVersion на момент действия.

Обязательно: `PRAGMA foreign_keys = ON`, миграции через `PRAGMA user_version`, отсутствие автоматического удаления БД при ошибке, reset/delete только явно, сохранение receipts вне очищаемого состояния поколения.

Каркас, созданный по прямому поручению от 24.09.2026:

- `pubspec.yaml`, `pubspec.lock`, `android/`;
- `lib/contracts/constants.dart`, `enums.dart`, `requests.dart`;
- `lib/contracts/models/` и `lib/contracts/logic_service.dart`;
- `assets/content/tasks.json`, `content_manifest.json`;
- `test/bootstrap_test.dart`, `BUILD.md`.

Будущая реализация логики и хранения:

- `lib/domain/economy/`, `lib/domain/tasks/`, `lib/domain/progress/`, `lib/domain/services/`;
- `lib/data/database/`, `lib/data/repositories/`, `lib/data/content/`;
- `assets/content/items.json`, `goals.json`, `tasks.json`, `demo_periods.json`;
- `test/domain/`, `test/data/`, `integration_test/demo_flow_test.dart`;
- `docs/contracts/logic_contract_v0.1.md`, `docs/economy/ECONOMY.md`, `docs/data/DATA.md`, `docs/content/CONTENT.md`, `docs/testing/TESTS.md`, `BUILD.md`.

Сторона интерфейса владеет `lib/ui/`, визуальными assets и временным fake adapter. Fake adapter использует модели этого контракта и фикстуры, но не реализует собственную экономику.

## 14. Организационный статус

Общий private-репозиторий `https://github.com/glagolller/finni.git` проверен 24.09.2026. Основная ветка — `main`, общая история содержит коммит `a45a879`, доступ пользователя `ignatenkof` подтвержден через GitHub CLI.

Независимая история `master` не публикуется. Работа ведется в общем репозитории в ветке `logic/bootstrap`; ветка основана на `frontend/stage3-design`, поскольку исправляет RC2 из PR интерфейсной стороны.

## 15. Согласованные решения

1. RC2.1 с патчем R1–R6 является текущей основой `logic_contract_v0.1`.
2. Действуют четыре доступных товара и максимум три покупки за период.
3. Шесть заданий дают однократную награду по 5 монет; лимита двух наград нет.
4. Шесть типов симуляций, их входы, критерии и feedback зафиксированы в `assets/content/tasks.json`.
5. Числовые эффекты питомца остаются проектными предложениями до балансировки по тестам.
6. Недофинансированный план сохраняется с предупреждением `needs_underfunded`, а не блокируется.
7. `profileGeneration`, durable receipts и актуальный снимок при replayed входят в обязательную семантику будущего хранилища.
8. Package ID — `ru.finni.pet`; формы и палитры перечислены в R4.

Документ является проектной спецификацией. Flutter-каркас и контрактные модели существуют; экономика, SQLite-хранилище, экраны и полноценная Android-сборка еще не реализованы.

## 16. Патч R1–R6 от 24.09.2026

Этот раздел нормативно заменяет противоречащие ему формулировки RC2. R1, R2 и R6 также исправлены непосредственно в разделах 9–10.

### R3. Формат заданий

Каждый `TaskInput` и `TaskAnswer` сериализуется объектом с обязательным discriminator `type`. Значение обязано совпадать с `TaskDefinition.interactionType`; иначе `submitTaskAnswer` возвращает `invalid_task_answer` без попытки, денег и эффектов.

| type | Поля input | Поля answer |
| --- | --- | --- |
| `budget_allocation` | `income`, `minimumNeeds`, `minimumSavings`, `allowedCategories: List<String>` | `needs`, `wants`, `savings` |
| `plan_fact_choice` | `plans: List<{id, needs, wants, savings}>`, `actual: {needs, wants, savings}` | `selectedOptionId` |
| `savings_schedule` | `goalAmount`, `periodCount`, `minimumPerPeriod` | `amountsByPeriod: List<int>` ровно `periodCount` элементов |
| `savings_comparison` | `operations: List<{direction, amount}>`, `options: List<{id, label}>` | `selectedOptionId` |
| `purchase_basket` | `budget`, `maxSelectedItems`, `requiredItemIds`, `items: List<{id, title, price, expenseType}>` | `selectedItemIds` без повторов |
| `expense_classification` | `targetGroups`, `entries: List<{id, label}>` | `groupByEntryId: Map<String, ExpenseType>` для каждого entry |

Полные `TaskDefinition`, критерии и оба текста результата для всех шести заданий находятся в `assets/content/tasks.json`. Этот файл является общей проектной фикстурой; UI получает публичную часть через `getTaskDefinition`, а criterion остается внутри реализации логики.

Словарь `NextAction.code`:

| code | params |
| --- | --- |
| `open_profile`, `open_home`, `open_budget`, `open_savings`, `open_goals`, `open_tasks`, `continue_period`, `preview_finish_period`, `finish_period`, `reset_demo`, `close_dialog`, `open_adult_section` | пустой объект |
| `open_catalog` | необязательный `maxPrice: int` |
| `open_task`, `retry_task` | обязательный `taskId: String`; для retry также `attemptsLeft: int` |
| `start_next_period` | обязательный `number: int` |
| `repeat_preview` | обязательный `operation: String` |
| `retry_same_action` | `reuseActionId: true` |

Неизвестный `code` игнорируется UI с безопасным возвратом на home и записывается в диагностику; свободный текст не разбирается как навигация.

### R4. Создание, подтверждения и normal

До профиля UI вызывает `getBootstrapConfig()`. Ответ содержит `contractVersion`, `contentVersion`, формы `pet.form.01` (округлый), `.02` (ушки), `.03` (хохолок) и палитры `pet.palette.01` (мятный/точки), `.02` (абрикосовый/полосы), `.03` (сиреневый/звезды). Получается 9 комбинаций. Неизвестные ID дают `invalid_pet_form` или `invalid_pet_palette`.

Для reset demo точный `confirmationText` — `СБРОСИТЬ`, для delete — `УДАЛИТЬ`. Сравнение выполняется после trim, с учетом регистра. Несовпадение дает `confirmation_required`; отмена не вызывает команду.

Demo заканчивается после периода 5. Normal не заканчивается: для периода `n > 5` используется шаблон `((n - 1) mod 5) + 1`, но ID периода и номер продолжают возрастать. Доход, попытки, purchase slots и факты создаются заново для нового номера; баланс, накопления, цели, история и развитие переносятся.

### R5. Результаты и история целей

Неверный ответ имеет `ActionResult.success = true`, `taskAttempt.outcome = needs_retry`, `rewardGranted = false`, `moneyDelta = null`; полный новый snapshot отличается увеличенной ревизией, счетчиком попыток и mood −2. Правильность никогда не определяется через `success`.

Replayed возвращает исходные `moneyDelta`, `petDelta`, `taskAttempt` и `operationAppliedRevision`, но `stateSnapshot` всегда является текущим полным состоянием. UI не повторяет анимации для `replayed`.

Reset возвращает полный `state.new_demo` с тем же profileId, `generation + 1`, монотонной `stateRevision + 1`, новым ID периода поколения, `lastReasonCode = demo_reset` и актуальными timestamps. Повтор actionId не выполняет reset снова.

Delete возвращает `stateSnapshot = null`; durable receipt и tombstone остаются. Повтор delete возвращает `replayed` и `null`. `listProfiles` больше не содержит удаленный ID.

`HistoryPage` дополнен `completedGoals: List<CompletedGoalRecord>`. Запись содержит `goalId`, `title`, `amountSpent`, `completedAt`, `transactionId`; поэтому история завершенной цели не зависит от текущего `activeGoal`. Связанная транзакция имеет `relatedEntityId = goalId` и цену на момент завершения.

Полные базовые snapshots для new/open/withdrawn/closed/completed находятся в разделе 11. Fake adapter обязан материализовать полный `GameState`; fixture-ссылки не являются полями API. Ветки с одинаковой revision не объединяются в одну последовательность.

### R6. Эффекты review и накоплений

`completed_review` и `demo_completed_review` являются чтением: они не создают попытку, не меняют revision, деньги, reward, satiety или mood. Для повторного показа определения используется `getTaskDefinition`, а не `submitTaskAnswer`.

Mood +2 начисляется только один раз за период при первом переходе `qualifyingSavings` из 0 в положительное значение. Флаг `BudgetActual.savingsMoodBonusGranted` сохраняется. Последующие пополнения и циклы deposit/withdraw меняют деньги и qualifying savings, но не дают повторный mood-бонус.
