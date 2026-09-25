import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../contracts/contracts.dart';
import '../../data/database/sqlite_game_store.dart';
import '../../data/profile_document.dart';
import '../content/game_content.dart';

typedef Now = DateTime Function();

class SqliteLogicService implements LogicService {
  SqliteLogicService._(this._store, this._content, this._now);

  final SqliteGameStore _store;
  final GameContent _content;
  final Now _now;
  int _idCounter = 0;

  static Future<SqliteLogicService> open({
    DatabaseFactory? databaseFactory,
    String? databasePath,
    AssetBundle? bundle,
    Now? now,
  }) async {
    final values = await Future.wait<Object>([
      SqliteGameStore.open(
        factory: databaseFactory,
        databasePath: databasePath,
      ),
      GameContent.load(bundle ?? rootBundle),
    ]);
    return SqliteLogicService._(
      values[0] as SqliteGameStore,
      values[1] as GameContent,
      now ?? DateTime.now,
    );
  }

  Future<void> close() => _store.close();

  @override
  Future<BootstrapConfig> getBootstrapConfig() async => BootstrapConfig(
    contractVersion: logicContractVersion,
    contentVersion: contentVersion,
    petForms: petFormLabels.entries
        .map((entry) => PetAppearanceOption(id: entry.key, label: entry.value))
        .toList(),
    petPalettes: petPaletteLabels.entries
        .map((entry) => PetAppearanceOption(id: entry.key, label: entry.value))
        .toList(),
  );

  @override
  Future<ListProfilesResult> listProfiles() async {
    try {
      final profiles = await _store.loadProfiles();
      return ListProfilesResult(
        profiles: profiles
            .map(
              (profile) => ProfileSummary(
                id: profile.id,
                mode: profile.mode,
                displayName: profile.data['displayName'] as String?,
                petName: profile.data['petName']! as String,
                generation: profile.generation,
                updatedAt: DateTime.parse(profile.updatedAt),
              ),
            )
            .toList(),
      );
    } on DatabaseException {
      return const ListProfilesResult(
        profiles: [],
        errorCode: LogicErrorCode.storageError,
        messageForChild: 'Не удалось прочитать профили.',
      );
    }
  }

  @override
  Future<LoadStateResult> loadState(String profileId) async {
    try {
      final profile = await _store.loadProfile(profileId);
      return LoadStateResult(
        found: profile != null,
        stateSnapshot: profile?.snapshot(_content),
        errorCode: profile == null ? LogicErrorCode.profileNotFound : null,
        messageForChild: profile == null ? 'Профиль не найден.' : null,
      );
    } on DatabaseException {
      return const LoadStateResult(
        found: false,
        errorCode: LogicErrorCode.storageError,
        messageForChild: 'Не удалось загрузить игру.',
      );
    }
  }

  @override
  Future<CatalogResult<ItemSummary>> getItemCatalog(String profileId) async {
    final profile = await _store.loadProfile(profileId);
    if (profile == null) return _missingCatalog();
    final available = _strings(profile.period['availableItemIds']);
    final purchased = _strings(profile.period['purchasedItemIds']);
    return CatalogResult(
      items: _content.items.values
          .map(
            (item) => ItemSummary(
              id: item.id,
              title: item.title,
              expenseType: item.expenseType,
              price: item.price,
              visualAssetId: item.visualAssetId,
              availableThisPeriod: available.contains(item.id),
              purchasedThisPeriod: purchased.contains(item.id),
              availabilityReason: available.contains(item.id)
                  ? null
                  : 'Товар появится в другом периоде.',
              petEffect: item.effect,
            ),
          )
          .toList(),
      stateRevision: profile.revision,
      profileGeneration: profile.generation,
    );
  }

  @override
  Future<CatalogResult<GoalSummary>> getGoalCatalog(String profileId) async {
    final profile = await _store.loadProfile(profileId);
    if (profile == null) return _missingCatalog();
    return CatalogResult(
      items: _content.goals.values
          .map(
            (goal) => GoalSummary(
              id: goal.id,
              title: goal.title,
              targetAmount: goal.targetAmount,
              visualAssetId: goal.visualAssetId,
              selected: profile.activeGoal?['goalId'] == goal.id,
              reachable: profile.savings >= goal.targetAmount,
            ),
          )
          .toList(),
      stateRevision: profile.revision,
      profileGeneration: profile.generation,
    );
  }

  @override
  Future<CatalogResult<TaskSummary>> getTaskCatalog(String profileId) async {
    final profile = await _store.loadProfile(profileId);
    if (profile == null) return _missingCatalog();
    return CatalogResult(
      items: profile.taskHub(_content).tasks,
      stateRevision: profile.revision,
      profileGeneration: profile.generation,
    );
  }

  CatalogResult<T> _missingCatalog<T>() => const CatalogResult(
    items: [],
    stateRevision: 0,
    profileGeneration: 0,
    errorCode: LogicErrorCode.profileNotFound,
    messageForChild: 'Профиль не найден.',
  );

  @override
  Future<TaskDefinitionResult> getTaskDefinition(
    String profileId,
    String taskId,
  ) async {
    final profile = await _store.loadProfile(profileId);
    final definition = _content.tasks[taskId];
    if (profile == null || definition == null) {
      return TaskDefinitionResult(
        availability: TaskAvailabilityCode.periodClosed,
        errorCode: profile == null
            ? LogicErrorCode.profileNotFound
            : LogicErrorCode.taskNotFound,
        messageForChild: 'Задание не найдено.',
      );
    }
    final summary = profile
        .taskHub(_content)
        .tasks
        .firstWhere((task) => task.id == taskId);
    return TaskDefinitionResult(
      definition: definition,
      availability: summary.availability,
    );
  }

  @override
  Future<HistoryPage> getHistory(
    String profileId, {
    String? cursor,
    int limit = 50,
  }) async {
    final profile = await _store.loadProfile(profileId);
    if (profile == null) {
      return const HistoryPage(
        transactions: [],
        periodSummaries: [],
        completedGoals: [],
        errorCode: LogicErrorCode.profileNotFound,
      );
    }
    final offset = int.tryParse(cursor ?? '') ?? 0;
    final transactions = profile.transactionModels().reversed.toList();
    final page = transactions.skip(offset).take(limit).toList();
    return HistoryPage(
      transactions: page,
      periodSummaries: profile.periodSummaries
          .map((value) => _periodSummaryFromJson(_map(value)))
          .toList(),
      completedGoals: profile.completedGoalModels(),
      nextCursor: offset + page.length < transactions.length
          ? '${offset + page.length}'
          : null,
    );
  }

  @override
  Future<ProgressResult> getProgress(String profileId) async {
    final profile = await _store.loadProfile(profileId);
    if (profile == null) {
      return const ProgressResult(
        errorCode: LogicErrorCode.profileNotFound,
        messageForChild: 'Профиль не найден.',
      );
    }
    return ProgressResult(
      progress: profile.snapshot(_content).learningProgress,
    );
  }

  @override
  Future<ActionResult> createProfile(CreateProfileCommand command) async {
    final fingerprint = _fingerprint({
      'mode': command.mode.name,
      'displayName': command.displayName,
      'petName': command.petName.trim(),
      'formId': command.formId,
      'paletteId': command.paletteId,
      'contractVersion': command.contractVersion,
    });
    try {
      return await _store.transaction((txn) async {
        final receipt = await _store.loadReceipt(
          command.actionId,
          executor: txn,
        );
        if (receipt != null) {
          return _replayOrConflict(
            receipt,
            operation: 'createProfile',
            fingerprint: fingerprint,
            executor: txn,
          );
        }
        if (command.contractVersion != logicContractVersion) {
          return _rejected(
            command.actionId,
            LogicErrorCode.contractVersionMismatch,
            'Версия приложения не совпадает с данными.',
          );
        }
        if (command.petName.trim().isEmpty) {
          return _rejected(
            command.actionId,
            LogicErrorCode.invalidPetName,
            'Дай питомцу имя.',
          );
        }
        if (!supportedPetFormIds.contains(command.formId)) {
          return _rejected(
            command.actionId,
            LogicErrorCode.invalidPetForm,
            'Выбери доступную форму питомца.',
          );
        }
        if (!supportedPetPaletteIds.contains(command.paletteId)) {
          return _rejected(
            command.actionId,
            LogicErrorCode.invalidPetPalette,
            'Выбери доступную палитру питомца.',
          );
        }
        final now = _now().toUtc();
        final profileId = _newId('profile');
        final profile = ProfileDocument.create(
          id: profileId,
          mode: command.mode,
          displayName: command.displayName?.trim(),
          petName: command.petName.trim(),
          formId: command.formId,
          paletteId: command.paletteId,
          now: now,
          template: _content.periodFor(1),
        );
        profile.transactions.first = ProfileDocument.transactionJson(
          id: _newId('tx'),
          profileId: profileId,
          generation: 1,
          periodId: profile.period['id']! as String,
          type: TransactionType.periodIncome,
          amount: 100,
          availableChange: 100,
          savingsChange: 0,
          actionId: command.actionId,
          createdAt: now,
        );
        await _store.saveProfile(profile, executor: txn);
        final result = ActionResult(
          success: true,
          outcome: ActionOutcome.applied,
          actionId: command.actionId,
          operationAppliedRevision: 1,
          messageForChild:
              'Профиль создан. Финни готов учиться вместе с тобой.',
          stateSnapshot: profile.snapshot(_content),
          moneyDelta: const MoneyDelta(
            availableChange: 100,
            savingsChange: 0,
            incomeChange: 100,
            rewardChange: 0,
            reasonCode: 'period_income',
          ),
          nextActions: const [NextAction(code: NextActionCode.openHome)],
        );
        await _saveReceipt(
          txn,
          command.actionId,
          profileId,
          'createProfile',
          fingerprint,
          result,
          now,
        );
        return result;
      });
    } on DatabaseException {
      return _storageFailure(command.actionId);
    }
  }

  @override
  Future<PreviewResult> previewBudget(BudgetQuery query) => _preview(query, (
    profile,
  ) {
    if (profile.period['budgetPlan'] != null) {
      return _previewRejected(
        LogicErrorCode.planAlreadyConfirmed,
        'План уже подтвержден.',
        profile,
      );
    }
    final total = query.needsLimit + query.wantsLimit + query.savingsTarget;
    if (query.needsLimit < 0 ||
        query.wantsLimit < 0 ||
        query.savingsTarget < 0 ||
        total > profile.available) {
      return _previewRejected(
        LogicErrorCode.invalidBudget,
        'Проверь суммы плана.',
        profile,
      );
    }
    final warnings = query.needsLimit < _requiredNeedsCost(profile)
        ? const [
            WarningMessage(
              code: WarningCode.needsUnderfunded,
              messageForChild: 'На обязательные покупки запланировано мало.',
              requiresConfirmation: true,
            ),
          ]
        : const <WarningMessage>[];
    return PreviewResult(
      allowed: true,
      warnings: warnings,
      messageForChild: 'План готов к подтверждению.',
      stateSnapshot: profile.snapshot(_content),
      expectedPetDelta: _petDelta(
        profile,
        0,
        2,
        'plan_confirmed',
        'План помогает Финни понимать следующий шаг.',
      ),
      nextActions: const [NextAction(code: NextActionCode.openBudget)],
    );
  });

  @override
  Future<ActionResult> confirmBudget(BudgetCommand command) => _mutate(
    command,
    'confirmBudget',
    {
      'needsLimit': command.needsLimit,
      'wantsLimit': command.wantsLimit,
      'savingsTarget': command.savingsTarget,
      'acceptedWarnings': _warningNames(command.acceptedWarnings),
    },
    (profile, now) {
      if (profile.period['budgetPlan'] != null) {
        return _deny(
          LogicErrorCode.planAlreadyConfirmed,
          'План уже подтвержден.',
        );
      }
      final total =
          command.needsLimit + command.wantsLimit + command.savingsTarget;
      if (command.needsLimit < 0 ||
          command.wantsLimit < 0 ||
          command.savingsTarget < 0 ||
          total > profile.available) {
        return _deny(LogicErrorCode.invalidBudget, 'Проверь суммы плана.');
      }
      final requiredCost = _requiredNeedsCost(profile);
      if (command.needsLimit < requiredCost &&
          !command.acceptedWarnings.contains(WarningCode.needsUnderfunded)) {
        return _deny(
          LogicErrorCode.confirmationRequired,
          'Подтверди предупреждение о нужном.',
        );
      }
      profile.period['budgetPlan'] = {
        'needsLimit': command.needsLimit,
        'wantsLimit': command.wantsLimit,
        'savingsTarget': command.savingsTarget,
        'unallocatedAmount': profile.available - total,
        'requiredNeedsCostAtConfirmation': requiredCost,
        'confirmedAt': now.toIso8601String(),
      };
      return _applied(
        message: 'План сохранен.',
        petDelta: _applyPet(
          profile,
          0,
          2,
          'plan_confirmed',
          'План помогает Финни понимать следующий шаг.',
        ),
        nextActions: const [NextAction(code: NextActionCode.continuePeriod)],
      );
    },
  );

  @override
  Future<PreviewResult> previewPurchase(PurchaseQuery query) =>
      _preview(query, (profile) {
        final item = _content.items[query.itemId];
        if (item == null) {
          return _previewRejected(
            LogicErrorCode.itemNotFound,
            'Товар не найден.',
            profile,
          );
        }
        final error = _purchaseError(profile, item);
        if (error != null) return _previewRejected(error.$1, error.$2, profile);
        return PreviewResult(
          allowed: true,
          warnings: _purchaseWarnings(profile, item),
          messageForChild: 'Покупку можно подтвердить.',
          expectedMoneyDelta: MoneyDelta(
            availableChange: -item.price,
            savingsChange: 0,
            incomeChange: 0,
            rewardChange: 0,
            reasonCode: item.effect.reasonCode,
          ),
          expectedPetDelta: _petDelta(
            profile,
            item.effect.satietyChange,
            item.effect.moodChange,
            item.effect.reasonCode,
            item.title,
          ),
          stateSnapshot: profile.snapshot(_content),
          nextActions: const [NextAction(code: NextActionCode.openCatalog)],
        );
      });

  @override
  Future<ActionResult> buyItem(PurchaseCommand command) => _mutate(
    command,
    'buyItem',
    {
      'itemId': command.itemId,
      'acceptedWarnings': _warningNames(command.acceptedWarnings),
    },
    (profile, now) {
      final item = _content.items[command.itemId];
      if (item == null) {
        return _deny(LogicErrorCode.itemNotFound, 'Товар не найден.');
      }
      final error = _purchaseError(profile, item);
      if (error != null) return _deny(error.$1, error.$2);
      final warnings = _purchaseWarnings(profile, item);
      if (warnings.any(
        (warning) => !command.acceptedWarnings.contains(warning.code),
      )) {
        return _deny(
          LogicErrorCode.confirmationRequired,
          'Подтверди выход за рамки плана.',
        );
      }
      profile.available -= item.price;
      profile.period['purchaseSlotsUsed'] =
          (profile.period['purchaseSlotsUsed']! as int) + 1;
      _strings(profile.period['purchasedItemIds']).add(item.id);
      final actual = _map(profile.period['actual']);
      final key = item.expenseType == ExpenseType.need
          ? 'needsSpent'
          : 'wantsSpent';
      actual[key] = (actual[key]! as int) + item.price;
      final money = MoneyDelta(
        availableChange: -item.price,
        savingsChange: 0,
        incomeChange: 0,
        rewardChange: 0,
        reasonCode: item.effect.reasonCode,
      );
      _addTransaction(
        profile,
        now,
        command.actionId,
        TransactionType.purchase,
        item.price,
        -item.price,
        0,
        relatedEntityId: item.id,
        unitPrice: item.price,
      );
      return _applied(
        message: '${item.title}: покупка сохранена.',
        moneyDelta: money,
        petDelta: _applyPet(
          profile,
          item.effect.satietyChange,
          item.effect.moodChange,
          item.effect.reasonCode,
          item.title,
        ),
        nextActions: const [NextAction(code: NextActionCode.continuePeriod)],
      );
    },
  );

  @override
  Future<PreviewResult> previewSavingsTransfer(SavingsTransferQuery query) =>
      _preview(query, (profile) {
        final error = _transferError(profile, query.direction, query.amount);
        if (error != null) return _previewRejected(error.$1, error.$2, profile);
        final toSavings = query.direction == TransferDirection.toSavings;
        return PreviewResult(
          allowed: true,
          warnings: toSavings
              ? const []
              : const [
                  WarningMessage(
                    code: WarningCode.savingsWithdrawal,
                    messageForChild:
                        'Снятие уменьшит накопления этого периода.',
                    requiresConfirmation: true,
                  ),
                ],
          messageForChild: 'Перевод можно подтвердить.',
          expectedMoneyDelta: MoneyDelta(
            availableChange: toSavings ? -query.amount : query.amount,
            savingsChange: toSavings ? query.amount : -query.amount,
            incomeChange: 0,
            rewardChange: 0,
            reasonCode: toSavings ? 'savings_deposit' : 'savings_withdrawal',
          ),
          stateSnapshot: profile.snapshot(_content),
          nextActions: const [NextAction(code: NextActionCode.openSavings)],
        );
      });

  @override
  Future<ActionResult> transferSavings(
    SavingsTransferCommand command,
  ) => _mutate(
    command,
    'transferSavings',
    {
      'direction': command.direction.name,
      'amount': command.amount,
      'acceptedWarnings': _warningNames(command.acceptedWarnings),
    },
    (profile, now) {
      final error = _transferError(profile, command.direction, command.amount);
      if (error != null) return _deny(error.$1, error.$2);
      final toSavings = command.direction == TransferDirection.toSavings;
      if (!toSavings &&
          !command.acceptedWarnings.contains(WarningCode.savingsWithdrawal)) {
        return _deny(
          LogicErrorCode.confirmationRequired,
          'Подтверди снятие накоплений.',
        );
      }
      profile.available += toSavings ? -command.amount : command.amount;
      profile.savings += toSavings ? command.amount : -command.amount;
      final actual = _map(profile.period['actual']);
      final key = toSavings ? 'savingsDeposited' : 'ordinarySavingsWithdrawn';
      actual[key] = (actual[key]! as int) + command.amount;
      final firstPositive =
          toSavings &&
          actual['savingsMoodBonusGranted'] == false &&
          (actual['savingsDeposited']! as int) -
                  (actual['ordinarySavingsWithdrawn']! as int) >
              0;
      if (firstPositive) actual['savingsMoodBonusGranted'] = true;
      final reason = toSavings
          ? firstPositive
                ? 'savings_deposit_first_positive'
                : 'savings_deposit'
          : 'savings_withdrawal';
      final explanation = toSavings
          ? firstPositive
                ? 'Часть монет стала ближе к цели.'
                : 'Накопления обновлены.'
          : 'Монеты снова доступны; прогресс этого периода пересчитан.';
      final money = MoneyDelta(
        availableChange: toSavings ? -command.amount : command.amount,
        savingsChange: toSavings ? command.amount : -command.amount,
        incomeChange: 0,
        rewardChange: 0,
        reasonCode: reason,
      );
      _addTransaction(
        profile,
        now,
        command.actionId,
        toSavings
            ? TransactionType.savingsDeposit
            : TransactionType.savingsWithdrawal,
        command.amount,
        money.availableChange,
        money.savingsChange,
      );
      return _applied(
        message: explanation,
        moneyDelta: money,
        petDelta: _applyPet(
          profile,
          0,
          firstPositive ? 2 : 0,
          reason,
          explanation,
        ),
        nextActions: const [NextAction(code: NextActionCode.continuePeriod)],
      );
    },
  );

  @override
  Future<PreviewResult> previewGoalChange(GoalQuery query) => _preview(query, (
    profile,
  ) {
    final goal = _content.goals[query.goalId];
    if (goal == null) {
      return _previewRejected(
        LogicErrorCode.goalNotFound,
        'Цель не найдена.',
        profile,
      );
    }
    return PreviewResult(
      allowed: true,
      warnings:
          profile.activeGoal == null || profile.activeGoal?['goalId'] == goal.id
          ? const []
          : const [
              WarningMessage(
                code: WarningCode.goalChange,
                messageForChild: 'Накопления сохранятся для новой цели.',
                requiresConfirmation: true,
              ),
            ],
      messageForChild: 'Цель можно выбрать.',
      stateSnapshot: profile.snapshot(_content),
      nextActions: const [NextAction(code: NextActionCode.openGoals)],
    );
  });

  @override
  Future<ActionResult> changeGoal(GoalCommand command) => _mutate(
    command,
    'changeGoal',
    {
      'goalId': command.goalId,
      'acceptedWarnings': _warningNames(command.acceptedWarnings),
    },
    (profile, now) {
      final goal = _content.goals[command.goalId];
      if (goal == null) {
        return _deny(LogicErrorCode.goalNotFound, 'Цель не найдена.');
      }
      final changing =
          profile.activeGoal != null &&
          profile.activeGoal?['goalId'] != goal.id;
      if (changing &&
          !command.acceptedWarnings.contains(WarningCode.goalChange)) {
        return _deny(
          LogicErrorCode.confirmationRequired,
          'Подтверди смену цели.',
        );
      }
      profile.activeGoal = {
        'goalId': goal.id,
        'selectedAt': now.toIso8601String(),
      };
      return _applied(
        message: 'Цель выбрана.',
        petDelta: _applyPet(
          profile,
          0,
          0,
          'goal_changed',
          'Накопления сохранились для новой цели.',
        ),
        nextActions: const [NextAction(code: NextActionCode.openSavings)],
      );
    },
  );

  @override
  Future<PreviewResult> previewGoalRedemption(GoalQuery query) =>
      _preview(query, (profile) {
        final goal = _content.goals[query.goalId];
        if (goal == null || profile.activeGoal?['goalId'] != query.goalId) {
          return _previewRejected(
            LogicErrorCode.goalNotFound,
            'Активная цель не найдена.',
            profile,
          );
        }
        if (profile.savings < goal.targetAmount) {
          return _previewRejected(
            LogicErrorCode.goalNotReachable,
            'Для цели пока не хватает накоплений.',
            profile,
          );
        }
        return PreviewResult(
          allowed: true,
          warnings: const [
            WarningMessage(
              code: WarningCode.goalRedemption,
              messageForChild: 'Стоимость цели будет списана из накоплений.',
              requiresConfirmation: true,
            ),
          ],
          messageForChild: 'Цель достигнута и готова к получению.',
          expectedMoneyDelta: MoneyDelta(
            availableChange: 0,
            savingsChange: -goal.targetAmount,
            incomeChange: 0,
            rewardChange: 0,
            reasonCode: 'goal_redeemed',
          ),
          expectedPetDelta: _petDelta(
            profile,
            0,
            12,
            'goal_redeemed',
            'Цель достигнута, а лишние монеты сохранились.',
          ),
          stateSnapshot: profile.snapshot(_content),
          nextActions: const [NextAction(code: NextActionCode.openGoals)],
        );
      });

  @override
  Future<ActionResult> redeemGoal(GoalCommand command) => _mutate(
    command,
    'redeemGoal',
    {
      'goalId': command.goalId,
      'acceptedWarnings': _warningNames(command.acceptedWarnings),
    },
    (profile, now) {
      final goal = _content.goals[command.goalId];
      if (goal == null || profile.activeGoal?['goalId'] != command.goalId) {
        return _deny(LogicErrorCode.goalNotFound, 'Активная цель не найдена.');
      }
      if (profile.savings < goal.targetAmount) {
        return _deny(
          LogicErrorCode.goalNotReachable,
          'Для цели пока не хватает накоплений.',
        );
      }
      if (!command.acceptedWarnings.contains(WarningCode.goalRedemption)) {
        return _deny(
          LogicErrorCode.confirmationRequired,
          'Подтверди получение цели.',
        );
      }
      profile.savings -= goal.targetAmount;
      final actual = _map(profile.period['actual']);
      actual['goalRedemptionSpent'] =
          (actual['goalRedemptionSpent']! as int) + goal.targetAmount;
      final transactionId = _newId('tx');
      profile.transactions.add(
        ProfileDocument.transactionJson(
          id: transactionId,
          profileId: profile.id,
          generation: profile.generation,
          periodId: profile.period['id']! as String,
          type: TransactionType.goalRedemption,
          amount: goal.targetAmount,
          availableChange: 0,
          savingsChange: -goal.targetAmount,
          actionId: command.actionId,
          createdAt: now,
          relatedEntityId: goal.id,
          unitPrice: goal.targetAmount,
        ),
      );
      profile.completedGoals.add({
        'goalId': goal.id,
        'title': goal.title,
        'amountSpent': goal.targetAmount,
        'completedAt': now.toIso8601String(),
        'transactionId': transactionId,
      });
      profile.activeGoal = null;
      return _applied(
        message: 'Цель достигнута.',
        moneyDelta: MoneyDelta(
          availableChange: 0,
          savingsChange: -goal.targetAmount,
          incomeChange: 0,
          rewardChange: 0,
          reasonCode: 'goal_redeemed',
        ),
        petDelta: _applyPet(
          profile,
          0,
          12,
          'goal_redeemed',
          'Цель достигнута, а лишние монеты сохранились.',
        ),
        nextActions: const [NextAction(code: NextActionCode.openGoals)],
      );
    },
  );

  @override
  Future<ActionResult> submitTaskAnswer(TaskAnswerCommand command) => _mutate(
    command,
    'submitTaskAnswer',
    {'taskId': command.taskId, 'answer': _answerFingerprint(command.answer)},
    (profile, now) {
      final definition = _content.tasks[command.taskId];
      if (definition == null) {
        return _deny(LogicErrorCode.taskNotFound, 'Задание не найдено.');
      }
      if (definition.interactionType != command.answer.type) {
        return _deny(
          LogicErrorCode.invalidTaskAnswer,
          'Формат ответа не подходит заданию.',
        );
      }
      final periodStatus = PeriodStatus.values.byName(
        profile.period['status']! as String,
      );
      final progress = profile.taskProgressModel(command.taskId);
      if (periodStatus != PeriodStatus.open || progress.completed) {
        return _deny(
          LogicErrorCode.periodClosed,
          'Доступен только просмотр задания.',
        );
      }
      if (progress.attemptsThisPeriod >= definition.maxAttemptsPerPeriod) {
        return _deny(
          LogicErrorCode.attemptLimitReached,
          'Попытки этого периода закончились.',
        );
      }
      final correct = _isCorrect(definition, command.answer);
      final row = profile.taskProgress[command.taskId] == null
          ? <String, Object?>{}
          : _map(profile.taskProgress[command.taskId]);
      final attemptNumber = progress.attemptsThisPeriod + 1;
      row['attemptsTotal'] = progress.attemptsTotal + 1;
      row['attemptsThisPeriod'] = attemptNumber;
      row['lastOutcome'] =
          (correct ? TaskAttemptOutcome.correct : TaskAttemptOutcome.needsRetry)
              .name;
      row['completed'] = correct;
      row['completedAt'] = correct ? now.toIso8601String() : null;
      profile.taskProgress[command.taskId] = row;
      final reward = correct ? definition.rewardAmount : 0;
      if (correct) {
        profile.available += reward;
        final actual = _map(profile.period['actual']);
        actual['taskRewards'] = (actual['taskRewards']! as int) + reward;
        _addTransaction(
          profile,
          now,
          command.actionId,
          TransactionType.taskReward,
          reward,
          reward,
          0,
          relatedEntityId: definition.id,
        );
      }
      final explanation = correct
          ? definition.feedback.correct
          : definition.feedback.needsRetry;
      final attempt = TaskAttemptResult(
        taskId: definition.id,
        attemptNumberThisPeriod: attemptNumber,
        outcome: correct
            ? TaskAttemptOutcome.correct
            : TaskAttemptOutcome.needsRetry,
        explanation: explanation,
        rewardGranted: correct,
        rewardAmount: reward,
        rewardState: correct ? RewardState.granted : RewardState.notEarned,
        remainingAttempts: (definition.maxAttemptsPerPeriod - attemptNumber)
            .clamp(0, definition.maxAttemptsPerPeriod),
        completedNow: correct,
      );
      return _applied(
        message: explanation,
        moneyDelta: correct
            ? MoneyDelta(
                availableChange: reward,
                savingsChange: 0,
                incomeChange: 0,
                rewardChange: reward,
                reasonCode: 'task_reward',
              )
            : null,
        petDelta: _applyPet(
          profile,
          0,
          correct ? 4 : -2,
          correct ? 'task_correct' : 'task_needs_retry',
          explanation,
        ),
        taskAttempt: attempt,
        nextActions: correct
            ? const [NextAction(code: NextActionCode.openTasks)]
            : [
                NextAction(
                  code: NextActionCode.retryTask,
                  params: {
                    'taskId': definition.id,
                    'attemptsLeft': attempt.remainingAttempts,
                  },
                ),
              ],
      );
    },
  );

  @override
  Future<PreviewResult> previewFinishPeriod(PeriodQuery query) =>
      _preview(query, (profile) {
        if (profile.period['id'] != query.periodId ||
            profile.period['status'] != PeriodStatus.open.name) {
          return _previewRejected(
            LogicErrorCode.periodClosed,
            'Период уже закрыт.',
            profile,
          );
        }
        if (profile.period['budgetPlan'] == null) {
          return _previewRejected(
            LogicErrorCode.planRequired,
            'Сначала подтверди план.',
            profile,
          );
        }
        final actual = profile.snapshot(_content).currentPeriod.actual;
        return PreviewResult(
          allowed: true,
          warnings: actual.requiredNeedsMet
              ? const []
              : const [
                  WarningMessage(
                    code: WarningCode.mandatoryNeedsUnmet,
                    messageForChild: 'Не все обязательные покупки сделаны.',
                    requiresConfirmation: true,
                  ),
                ],
          messageForChild: 'Период готов к завершению.',
          stateSnapshot: profile.snapshot(_content),
          nextActions: const [NextAction(code: NextActionCode.finishPeriod)],
        );
      });

  @override
  Future<ActionResult> finishPeriod(PeriodCommand command) => _mutate(
    command,
    'finishPeriod',
    {
      'periodId': command.periodId,
      'acceptedWarnings': _warningNames(command.acceptedWarnings),
    },
    (profile, now) {
      if (profile.period['id'] != command.periodId ||
          profile.period['status'] != PeriodStatus.open.name) {
        return _deny(LogicErrorCode.periodClosed, 'Период уже закрыт.');
      }
      if (profile.period['budgetPlan'] == null) {
        return _deny(LogicErrorCode.planRequired, 'Сначала подтверди план.');
      }
      final before = profile.snapshot(_content);
      final actual = before.currentPeriod.actual;
      if (!actual.requiredNeedsMet &&
          !command.acceptedWarnings.contains(WarningCode.mandatoryNeedsUnmet)) {
        return _deny(
          LogicErrorCode.confirmationRequired,
          'Подтверди завершение без обязательных покупок.',
        );
      }
      final granted =
          (actual.requiredNeedsMet ? 1 : 0) +
          (actual.planKept ? 1 : 0) +
          (actual.savingsHabitKept ? 1 : 0);
      profile.completedPeriods += 1;
      profile.qualityPoints += granted;
      final stageBefore = before.pet.stage;
      final stageAfter =
          profile.completedPeriods >= 4 && profile.qualityPoints >= 12
          ? PetStage.grown
          : profile.completedPeriods >= 2 && profile.qualityPoints >= 6
          ? PetStage.junior
          : PetStage.baby;
      final moodChange = granted >= 2
          ? 4
          : granted == 1
          ? 1
          : -2;
      final reason = granted >= 2
          ? 'period_finished_strong'
          : granted == 1
          ? 'period_finished_mixed'
          : 'period_finished_recoverable';
      final explanation = granted >= 2
          ? 'Хороший период: нужное и план помогли Финни.'
          : granted == 1
          ? 'Часть плана получилась; в новом периоде можно продолжить.'
          : 'Этот период был сложным, но следующий даст новый шанс.';
      final basePetDelta = _applyPet(
        profile,
        -10,
        moodChange,
        reason,
        explanation,
      );
      profile.pet['stage'] = stageAfter.name;
      final petDelta = PetDelta(
        satietyBefore: basePetDelta.satietyBefore,
        satietyAfter: basePetDelta.satietyAfter,
        moodBefore: basePetDelta.moodBefore,
        moodAfter: basePetDelta.moodAfter,
        moodCodeBefore: basePetDelta.moodCodeBefore,
        moodCodeAfter: basePetDelta.moodCodeAfter,
        stageBefore: stageBefore,
        stageAfter: stageAfter,
        reasonCode: reason,
        explanationForChild: explanation,
      );
      profile.period['status'] =
          profile.mode == ProfileMode.demo && profile.period['number'] == 5
          ? PeriodStatus.demoCompleted.name
          : PeriodStatus.closed.name;
      profile.period['closedAt'] = now.toIso8601String();
      if (stageAfter != stageBefore) {
        profile.stageHistory.add({
          'stage': stageAfter.name,
          'reachedAfterPeriod': profile.completedPeriods,
          'qualityPoints': profile.qualityPoints,
          'reachedAt': now.toIso8601String(),
        });
      }
      final summary = PeriodSummary(
        periodId: before.currentPeriod.id,
        number: before.currentPeriod.number,
        plan: before.currentPeriod.budgetPlan!,
        actual: actual,
        qualityPointsGranted: granted,
        qualityPointsTotal: profile.qualityPoints,
        stageBefore: stageBefore,
        stageAfter: stageAfter,
        satietyAfter: profile.pet['satiety']! as int,
        moodAfter: profile.pet['mood']! as int,
        explanationForChild: explanation,
        closedAt: now,
      );
      profile.periodSummaries.add(_periodSummaryJson(summary));
      return _applied(
        message: explanation,
        petDelta: petDelta,
        periodSummary: summary,
        nextActions: profile.period['status'] == PeriodStatus.demoCompleted.name
            ? const [NextAction(code: NextActionCode.resetDemo)]
            : [
                NextAction(
                  code: NextActionCode.startNextPeriod,
                  params: {'number': before.currentPeriod.number + 1},
                ),
              ],
      );
    },
  );

  @override
  Future<ActionResult> startNextPeriod(PeriodCommand command) => _mutate(
    command,
    'startNextPeriod',
    {'periodId': command.periodId},
    (profile, now) {
      if (profile.period['id'] != command.periodId ||
          profile.period['status'] == PeriodStatus.open.name) {
        return _deny(
          LogicErrorCode.periodNotFinished,
          'Сначала заверши текущий период.',
        );
      }
      if (profile.period['status'] == PeriodStatus.demoCompleted.name) {
        return _deny(LogicErrorCode.demoComplete, 'Демо завершено.');
      }
      final number = (profile.period['number']! as int) + 1;
      profile.available += 100;
      profile.data['period'] = ProfileDocument.newPeriod(
        profileId: profile.id,
        generation: profile.generation,
        number: number,
        now: now,
        template: _content.periodFor(number),
      );
      for (final value in profile.taskProgress.values) {
        _map(value)['attemptsThisPeriod'] = 0;
      }
      _addTransaction(
        profile,
        now,
        command.actionId,
        TransactionType.periodIncome,
        100,
        100,
        0,
      );
      return _applied(
        message: 'Новый период начался.',
        moneyDelta: const MoneyDelta(
          availableChange: 100,
          savingsChange: 0,
          incomeChange: 100,
          rewardChange: 0,
          reasonCode: 'period_income',
        ),
        nextActions: const [NextAction(code: NextActionCode.openBudget)],
      );
    },
  );

  @override
  Future<ActionResult> resetDemoProfile(ConfirmedProfileCommand command) =>
      _mutate(
        command,
        'resetDemoProfile',
        {'confirmationText': command.confirmationText.trim()},
        (profile, now) {
          if (profile.mode != ProfileMode.demo ||
              command.confirmationText.trim() != resetDemoConfirmationText) {
            return _deny(
              LogicErrorCode.confirmationRequired,
              'Введи СБРОСИТЬ для сброса демо.',
            );
          }
          profile.reset(now: now, template: _content.periodFor(1));
          profile.transactions.first = ProfileDocument.transactionJson(
            id: _newId('tx'),
            profileId: profile.id,
            generation: profile.generation,
            periodId: profile.period['id']! as String,
            type: TransactionType.periodIncome,
            amount: 100,
            availableChange: 100,
            savingsChange: 0,
            actionId: command.actionId,
            createdAt: now,
          );
          return _applied(
            message: 'Демо начато заново.',
            moneyDelta: const MoneyDelta(
              availableChange: 100,
              savingsChange: 0,
              incomeChange: 100,
              rewardChange: 0,
              reasonCode: 'period_income',
            ),
            nextActions: const [NextAction(code: NextActionCode.openHome)],
          );
        },
      );

  @override
  Future<ActionResult> deleteProfile(ConfirmedProfileCommand command) =>
      _mutate(
        command,
        'deleteProfile',
        {'confirmationText': command.confirmationText.trim()},
        (profile, now) {
          if (command.confirmationText.trim() !=
              deleteProfileConfirmationText) {
            return _deny(
              LogicErrorCode.confirmationRequired,
              'Введи УДАЛИТЬ для удаления профиля.',
            );
          }
          return _applied(
            message: 'Профиль удален.',
            deleteProfile: true,
            nextActions: const [NextAction(code: NextActionCode.openProfile)],
          );
        },
      );

  @override
  Future<ActionResult> updateSettings(UpdateSettingsCommand command) => _mutate(
    command,
    'updateSettings',
    {
      'soundEnabled': command.settings.soundEnabled,
      'reducedMotion': command.settings.reducedMotion,
      'largeTextPreferred': command.settings.largeTextPreferred,
    },
    (profile, now) {
      profile.settings
        ..['soundEnabled'] = command.settings.soundEnabled
        ..['reducedMotion'] = command.settings.reducedMotion
        ..['largeTextPreferred'] = command.settings.largeTextPreferred;
      return _applied(
        message: 'Настройки сохранены.',
        nextActions: const [NextAction(code: NextActionCode.closeDialog)],
      );
    },
  );

  // SERVICE_METHODS

  Future<PreviewResult> _preview(
    StateQuery query,
    PreviewResult Function(ProfileDocument profile) build,
  ) async {
    try {
      final profile = await _store.loadProfile(query.profileId);
      if (profile == null) {
        return const PreviewResult(
          allowed: false,
          errorCode: LogicErrorCode.profileNotFound,
          warnings: [],
          messageForChild: 'Профиль не найден.',
          nextActions: [NextAction(code: NextActionCode.openProfile)],
        );
      }
      if (profile.generation != query.expectedGeneration) {
        return _previewRejected(
          LogicErrorCode.staleGeneration,
          'Игра уже начата заново.',
          profile,
        );
      }
      if (profile.revision != query.expectedRevision) {
        return _previewRejected(
          LogicErrorCode.staleState,
          'Состояние изменилось. Проверь последствия еще раз.',
          profile,
        );
      }
      return build(profile);
    } on DatabaseException {
      return const PreviewResult(
        allowed: false,
        errorCode: LogicErrorCode.storageError,
        warnings: [],
        messageForChild: 'Не удалось проверить действие.',
        nextActions: [NextAction(code: NextActionCode.retrySameAction)],
      );
    }
  }

  Future<ActionResult> _mutate(
    StateCommand command,
    String operation,
    JsonMap payload,
    _Decision Function(ProfileDocument profile, DateTime now) change,
  ) async {
    final fingerprint = _fingerprint({
      ...payload,
      'contractVersion': command.contractVersion,
      'profileId': command.profileId,
    });
    try {
      return await _store.transaction((txn) async {
        final receipt = await _store.loadReceipt(
          command.actionId,
          executor: txn,
        );
        if (receipt != null) {
          return _replayOrConflict(
            receipt,
            operation: operation,
            fingerprint: fingerprint,
            profileId: command.profileId,
            executor: txn,
          );
        }
        final profile = await _store.loadProfile(
          command.profileId,
          executor: txn,
        );
        if (profile == null) {
          return _rejected(
            command.actionId,
            LogicErrorCode.profileNotFound,
            'Профиль не найден.',
          );
        }
        if (command.contractVersion != logicContractVersion) {
          return _rejected(
            command.actionId,
            LogicErrorCode.contractVersionMismatch,
            'Версия приложения не совпадает с данными.',
            profile: profile,
          );
        }
        if (profile.generation != command.expectedGeneration) {
          return _rejected(
            command.actionId,
            LogicErrorCode.staleGeneration,
            'Игра уже начата заново.',
            profile: profile,
          );
        }
        if (profile.revision != command.expectedRevision) {
          return _rejected(
            command.actionId,
            LogicErrorCode.staleState,
            'Состояние изменилось. Проверь обновленные последствия еще раз.',
            profile: profile,
          );
        }
        final now = _now().toUtc();
        final decision = change(profile, now);
        if (!decision.success) {
          return _rejected(
            command.actionId,
            decision.errorCode!,
            decision.message,
            profile: profile,
          );
        }
        profile.revision += 1;
        profile.updatedAt = now.toIso8601String();
        final result = ActionResult(
          success: true,
          outcome: ActionOutcome.applied,
          actionId: command.actionId,
          operationAppliedRevision: profile.revision,
          messageForChild: decision.message,
          stateSnapshot: decision.deleteProfile
              ? null
              : profile.snapshot(_content),
          moneyDelta: decision.moneyDelta,
          petDelta: decision.petDelta,
          taskAttempt: decision.taskAttempt,
          periodSummary: decision.periodSummary,
          nextActions: decision.nextActions,
        );
        if (decision.deleteProfile) {
          await _store.deleteProfile(profile.id, executor: txn, deletedAt: now);
        } else {
          await _store.saveProfile(profile, executor: txn);
        }
        await _saveReceipt(
          txn,
          command.actionId,
          profile.id,
          operation,
          fingerprint,
          result,
          now,
        );
        return result;
      });
    } on DatabaseException {
      return _storageFailure(command.actionId);
    }
  }

  Future<ActionResult> _replayOrConflict(
    StoredReceipt receipt, {
    required String operation,
    required String fingerprint,
    String? profileId,
    DatabaseExecutor? executor,
  }) async {
    if (receipt.operation != operation ||
        receipt.fingerprint != fingerprint ||
        (profileId != null && receipt.profileId != profileId)) {
      final profile = profileId == null
          ? null
          : await _store.loadProfile(profileId, executor: executor);
      return _rejected(
        receipt.actionId,
        LogicErrorCode.actionConflict,
        'Этот идентификатор уже использован для другого действия.',
        profile: profile,
      );
    }
    final profile = receipt.profileId == null
        ? null
        : await _store.loadProfile(receipt.profileId!, executor: executor);
    return _resultFromReceipt(receipt, profile?.snapshot(_content));
  }

  Future<void> _saveReceipt(
    DatabaseExecutor executor,
    String actionId,
    String? profileId,
    String operation,
    String fingerprint,
    ActionResult result,
    DateTime now,
  ) => _store.saveReceipt(
    StoredReceipt(
      actionId: actionId,
      profileId: profileId,
      operation: operation,
      fingerprint: fingerprint,
      operationRevision: result.operationAppliedRevision!,
      result: _resultJson(result),
    ),
    executor: executor,
    createdAt: now,
  );

  PreviewResult _previewRejected(
    LogicErrorCode error,
    String message,
    ProfileDocument profile,
  ) => PreviewResult(
    allowed: false,
    errorCode: error,
    warnings: const [],
    messageForChild: message,
    stateSnapshot: profile.snapshot(_content),
    nextActions: const [NextAction(code: NextActionCode.closeDialog)],
  );

  ActionResult _rejected(
    String actionId,
    LogicErrorCode error,
    String message, {
    ProfileDocument? profile,
  }) => ActionResult(
    success: false,
    outcome: ActionOutcome.rejected,
    actionId: actionId,
    errorCode: error,
    messageForChild: message,
    stateSnapshot: profile?.snapshot(_content),
    nextActions: error == LogicErrorCode.staleState
        ? const [NextAction(code: NextActionCode.repeatPreview)]
        : const [NextAction(code: NextActionCode.closeDialog)],
  );

  ActionResult _storageFailure(String actionId) => ActionResult(
    success: false,
    outcome: ActionOutcome.rejected,
    actionId: actionId,
    errorCode: LogicErrorCode.storageError,
    messageForChild: 'Не удалось сохранить действие. Попробуй еще раз.',
    nextActions: const [NextAction(code: NextActionCode.retrySameAction)],
  );

  _Decision _deny(LogicErrorCode error, String message) =>
      _Decision.rejected(error, message);

  _Decision _applied({
    required String message,
    MoneyDelta? moneyDelta,
    PetDelta? petDelta,
    TaskAttemptResult? taskAttempt,
    PeriodSummary? periodSummary,
    bool deleteProfile = false,
    List<NextAction> nextActions = const [],
  }) => _Decision.applied(
    message: message,
    moneyDelta: moneyDelta,
    petDelta: petDelta,
    taskAttempt: taskAttempt,
    periodSummary: periodSummary,
    deleteProfile: deleteProfile,
    nextActions: nextActions,
  );

  (LogicErrorCode, String)? _purchaseError(
    ProfileDocument profile,
    ItemDefinition item,
  ) {
    if (profile.period['status'] != PeriodStatus.open.name) {
      return (LogicErrorCode.periodClosed, 'Период закрыт.');
    }
    if (profile.period['budgetPlan'] == null) {
      return (LogicErrorCode.planRequired, 'Сначала подтверди план.');
    }
    if (!_strings(profile.period['availableItemIds']).contains(item.id)) {
      return (
        LogicErrorCode.itemUnavailable,
        'Товар недоступен в этом периоде.',
      );
    }
    if (_strings(profile.period['purchasedItemIds']).contains(item.id)) {
      return (
        LogicErrorCode.itemAlreadyPurchasedThisPeriod,
        'Этот товар уже куплен в периоде.',
      );
    }
    if ((profile.period['purchaseSlotsUsed']! as int) >=
        (profile.period['purchaseSlotsTotal']! as int)) {
      return (
        LogicErrorCode.purchaseLimitReached,
        'Лимит покупок периода исчерпан.',
      );
    }
    if (profile.available < item.price) {
      return (LogicErrorCode.insufficientFunds, 'Не хватает монет.');
    }
    return null;
  }

  List<WarningMessage> _purchaseWarnings(
    ProfileDocument profile,
    ItemDefinition item,
  ) {
    final plan = _map(profile.period['budgetPlan']);
    final actual = _map(profile.period['actual']);
    final spent = item.expenseType == ExpenseType.need
        ? actual['needsSpent']! as int
        : actual['wantsSpent']! as int;
    final limit = item.expenseType == ExpenseType.need
        ? plan['needsLimit']! as int
        : plan['wantsLimit']! as int;
    return spent + item.price > limit
        ? const [
            WarningMessage(
              code: WarningCode.budgetExceeded,
              messageForChild: 'Покупка выйдет за рамки плана.',
              requiresConfirmation: true,
            ),
          ]
        : const [];
  }

  (LogicErrorCode, String)? _transferError(
    ProfileDocument profile,
    TransferDirection direction,
    int amount,
  ) {
    if (profile.period['status'] != PeriodStatus.open.name) {
      return (LogicErrorCode.periodClosed, 'Период закрыт.');
    }
    if (amount <= 0) {
      return (LogicErrorCode.invalidAmount, 'Сумма должна быть больше нуля.');
    }
    if ((direction == TransferDirection.toSavings &&
            profile.available < amount) ||
        (direction == TransferDirection.fromSavings &&
            profile.savings < amount)) {
      return (LogicErrorCode.insufficientFunds, 'Не хватает монет.');
    }
    return null;
  }

  int _requiredNeedsCost(ProfileDocument profile) =>
      _strings(profile.period['requiredItemIds'])
          .fold(0, (sum, id) => sum + _content.items[id]!.price);

  PetDelta _petDelta(
    ProfileDocument profile,
    int satietyChange,
    int moodChange,
    String reason,
    String explanation,
  ) {
    final oldSatiety = profile.pet['satiety']! as int;
    final oldMood = profile.pet['mood']! as int;
    final stage = PetStage.values.byName(profile.pet['stage']! as String);
    final newSatiety = (oldSatiety + satietyChange).clamp(0, 100);
    final newMood = (oldMood + moodChange).clamp(0, 100);
    return PetDelta(
      satietyBefore: oldSatiety,
      satietyAfter: newSatiety,
      moodBefore: oldMood,
      moodAfter: newMood,
      moodCodeBefore: ProfileDocument.moodCode(oldMood),
      moodCodeAfter: ProfileDocument.moodCode(newMood),
      stageBefore: stage,
      stageAfter: stage,
      reasonCode: reason,
      explanationForChild: explanation,
    );
  }

  PetDelta _applyPet(
    ProfileDocument profile,
    int satietyChange,
    int moodChange,
    String reason,
    String explanation,
  ) {
    final delta = _petDelta(
      profile,
      satietyChange,
      moodChange,
      reason,
      explanation,
    );
    final stageAfter = PetStage.values.byName(profile.pet['stage']! as String);
    profile.pet
      ..['satiety'] = delta.satietyAfter
      ..['mood'] = delta.moodAfter
      ..['lastReasonCode'] = reason
      ..['explanationForChild'] = explanation;
    return PetDelta(
      satietyBefore: delta.satietyBefore,
      satietyAfter: delta.satietyAfter,
      moodBefore: delta.moodBefore,
      moodAfter: delta.moodAfter,
      moodCodeBefore: delta.moodCodeBefore,
      moodCodeAfter: delta.moodCodeAfter,
      stageBefore: delta.stageBefore,
      stageAfter: stageAfter,
      reasonCode: reason,
      explanationForChild: explanation,
    );
  }

  bool _isCorrect(TaskDefinition definition, TaskAnswer answer) {
    final criterion = definition.criterion;
    if (answer is BudgetAllocationAnswer &&
        criterion is BudgetAllocationCriterion) {
      return answer.needs + answer.wants + answer.savings ==
              criterion.requiredTotal &&
          answer.needs >= criterion.minimumNeeds &&
          answer.savings >= criterion.minimumSavings;
    }
    if (answer is PlanFactChoiceAnswer && criterion is SingleChoiceCriterion) {
      return answer.selectedOptionId == criterion.correctOptionId;
    }
    if (answer is SavingsComparisonAnswer &&
        criterion is SingleChoiceCriterion) {
      return answer.selectedOptionId == criterion.correctOptionId;
    }
    if (answer is SavingsScheduleAnswer &&
        criterion is SavingsScheduleCriterion) {
      return answer.amountsByPeriod.length == criterion.requiredPeriodCount &&
          answer.amountsByPeriod.every(
            (amount) => amount >= criterion.minimumEachPeriod,
          ) &&
          answer.amountsByPeriod.fold(0, (sum, amount) => sum + amount) >=
              criterion.minimumTotal;
    }
    if (answer is PurchaseBasketAnswer &&
        criterion is PurchaseBasketCriterion) {
      final selected = answer.selectedItemIds.toSet();
      final input = definition.input as PurchaseBasketInput;
      final total = input.items
          .where((item) => selected.contains(item.id))
          .fold(0, (sum, item) => sum + item.price);
      return selected.length == answer.selectedItemIds.length &&
          selected.length <= criterion.maximumItems &&
          criterion.requiredItemIds.every(selected.contains) &&
          total <= criterion.maximumTotal;
    }
    if (answer is ExpenseClassificationAnswer &&
        criterion is ExpenseClassificationCriterion) {
      return answer.groupByEntryId.length == criterion.groupByEntryId.length &&
          criterion.groupByEntryId.entries.every(
            (entry) => answer.groupByEntryId[entry.key] == entry.value,
          );
    }
    return false;
  }

  JsonMap _answerFingerprint(TaskAnswer answer) => switch (answer) {
    BudgetAllocationAnswer value => {
      'type': value.type.name,
      'needs': value.needs,
      'wants': value.wants,
      'savings': value.savings,
    },
    PlanFactChoiceAnswer value => {
      'type': value.type.name,
      'selectedOptionId': value.selectedOptionId,
    },
    SavingsScheduleAnswer value => {
      'type': value.type.name,
      'amountsByPeriod': value.amountsByPeriod,
    },
    SavingsComparisonAnswer value => {
      'type': value.type.name,
      'selectedOptionId': value.selectedOptionId,
    },
    PurchaseBasketAnswer value => {
      'type': value.type.name,
      'selectedItemIds': value.selectedItemIds,
    },
    ExpenseClassificationAnswer value => {
      'type': value.type.name,
      'groupByEntryId': value.groupByEntryId.map(
        (key, item) => MapEntry(key, item.name),
      ),
    },
  };

  void _addTransaction(
    ProfileDocument profile,
    DateTime now,
    String actionId,
    TransactionType type,
    int amount,
    int availableChange,
    int savingsChange, {
    String? relatedEntityId,
    int? unitPrice,
  }) {
    profile.transactions.add(
      ProfileDocument.transactionJson(
        id: _newId('tx'),
        profileId: profile.id,
        generation: profile.generation,
        periodId: profile.period['id']! as String,
        type: type,
        amount: amount,
        availableChange: availableChange,
        savingsChange: savingsChange,
        actionId: actionId,
        createdAt: now,
        relatedEntityId: relatedEntityId,
        unitPrice: unitPrice,
      ),
    );
  }

  String _newId(String prefix) =>
      '$prefix.${_now().toUtc().microsecondsSinceEpoch}.${_idCounter++}.${Random().nextInt(1 << 20)}';

  static JsonMap _map(Object? value) => (value! as Map).cast<String, Object?>();
  static List<String> _strings(Object? value) =>
      (value! as List<Object?>).cast<String>();
  static List<String> _warningNames(Set<WarningCode> values) =>
      values.map((value) => value.name).toList()..sort();
  static String _fingerprint(JsonMap payload) =>
      jsonEncode(_canonical(payload));

  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: _canonical(value[key]),
      };
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }
}

class _Decision {
  const _Decision._({
    required this.success,
    required this.message,
    required this.nextActions,
    this.errorCode,
    this.moneyDelta,
    this.petDelta,
    this.taskAttempt,
    this.periodSummary,
    this.deleteProfile = false,
  });

  factory _Decision.rejected(LogicErrorCode error, String message) =>
      _Decision._(
        success: false,
        errorCode: error,
        message: message,
        nextActions: const [],
      );

  factory _Decision.applied({
    required String message,
    required List<NextAction> nextActions,
    MoneyDelta? moneyDelta,
    PetDelta? petDelta,
    TaskAttemptResult? taskAttempt,
    PeriodSummary? periodSummary,
    bool deleteProfile = false,
  }) => _Decision._(
    success: true,
    message: message,
    nextActions: nextActions,
    moneyDelta: moneyDelta,
    petDelta: petDelta,
    taskAttempt: taskAttempt,
    periodSummary: periodSummary,
    deleteProfile: deleteProfile,
  );

  final bool success;
  final LogicErrorCode? errorCode;
  final String message;
  final MoneyDelta? moneyDelta;
  final PetDelta? petDelta;
  final TaskAttemptResult? taskAttempt;
  final PeriodSummary? periodSummary;
  final bool deleteProfile;
  final List<NextAction> nextActions;
}

JsonMap _resultJson(ActionResult result) => {
  'message': result.messageForChild,
  'moneyDelta': result.moneyDelta == null
      ? null
      : {
          'availableChange': result.moneyDelta!.availableChange,
          'savingsChange': result.moneyDelta!.savingsChange,
          'incomeChange': result.moneyDelta!.incomeChange,
          'rewardChange': result.moneyDelta!.rewardChange,
          'reasonCode': result.moneyDelta!.reasonCode,
        },
  'petDelta': result.petDelta == null
      ? null
      : {
          'satietyBefore': result.petDelta!.satietyBefore,
          'satietyAfter': result.petDelta!.satietyAfter,
          'moodBefore': result.petDelta!.moodBefore,
          'moodAfter': result.petDelta!.moodAfter,
          'moodCodeBefore': result.petDelta!.moodCodeBefore.name,
          'moodCodeAfter': result.petDelta!.moodCodeAfter.name,
          'stageBefore': result.petDelta!.stageBefore.name,
          'stageAfter': result.petDelta!.stageAfter.name,
          'reasonCode': result.petDelta!.reasonCode,
          'explanation': result.petDelta!.explanationForChild,
        },
  'taskAttempt': result.taskAttempt == null
      ? null
      : {
          'taskId': result.taskAttempt!.taskId,
          'attempt': result.taskAttempt!.attemptNumberThisPeriod,
          'outcome': result.taskAttempt!.outcome.name,
          'explanation': result.taskAttempt!.explanation,
          'rewardGranted': result.taskAttempt!.rewardGranted,
          'rewardAmount': result.taskAttempt!.rewardAmount,
          'rewardState': result.taskAttempt!.rewardState.name,
          'remainingAttempts': result.taskAttempt!.remainingAttempts,
          'completedNow': result.taskAttempt!.completedNow,
        },
  'periodSummary': result.periodSummary == null
      ? null
      : _periodSummaryJson(result.periodSummary!),
  'nextActions': result.nextActions
      .map((action) => {'code': action.code.name, 'params': action.params})
      .toList(),
};

ActionResult _resultFromReceipt(StoredReceipt receipt, GameState? snapshot) {
  final row = receipt.result;
  return ActionResult(
    success: true,
    outcome: ActionOutcome.replayed,
    actionId: receipt.actionId,
    operationAppliedRevision: receipt.operationRevision,
    messageForChild: row['message']! as String,
    stateSnapshot: snapshot,
    moneyDelta: _moneyDelta(row['moneyDelta']),
    petDelta: _petDeltaFromJson(row['petDelta']),
    taskAttempt: _taskAttemptFromJson(row['taskAttempt']),
    periodSummary: row['periodSummary'] == null
        ? null
        : _periodSummaryFromJson(_mapGlobal(row['periodSummary'])),
    nextActions: (row['nextActions']! as List<Object?>).map((value) {
      final action = _mapGlobal(value);
      return NextAction(
        code: NextActionCode.values.byName(action['code']! as String),
        params: _mapGlobal(action['params']),
      );
    }).toList(),
  );
}

MoneyDelta? _moneyDelta(Object? value) {
  if (value == null) return null;
  final row = _mapGlobal(value);
  return MoneyDelta(
    availableChange: row['availableChange']! as int,
    savingsChange: row['savingsChange']! as int,
    incomeChange: row['incomeChange']! as int,
    rewardChange: row['rewardChange']! as int,
    reasonCode: row['reasonCode']! as String,
  );
}

PetDelta? _petDeltaFromJson(Object? value) {
  if (value == null) return null;
  final row = _mapGlobal(value);
  return PetDelta(
    satietyBefore: row['satietyBefore']! as int,
    satietyAfter: row['satietyAfter']! as int,
    moodBefore: row['moodBefore']! as int,
    moodAfter: row['moodAfter']! as int,
    moodCodeBefore: MoodCode.values.byName(row['moodCodeBefore']! as String),
    moodCodeAfter: MoodCode.values.byName(row['moodCodeAfter']! as String),
    stageBefore: PetStage.values.byName(row['stageBefore']! as String),
    stageAfter: PetStage.values.byName(row['stageAfter']! as String),
    reasonCode: row['reasonCode']! as String,
    explanationForChild: row['explanation']! as String,
  );
}

TaskAttemptResult? _taskAttemptFromJson(Object? value) {
  if (value == null) return null;
  final row = _mapGlobal(value);
  return TaskAttemptResult(
    taskId: row['taskId']! as String,
    attemptNumberThisPeriod: row['attempt']! as int,
    outcome: TaskAttemptOutcome.values.byName(row['outcome']! as String),
    explanation: row['explanation']! as String,
    rewardGranted: row['rewardGranted']! as bool,
    rewardAmount: row['rewardAmount']! as int,
    rewardState: RewardState.values.byName(row['rewardState']! as String),
    remainingAttempts: row['remainingAttempts']! as int,
    completedNow: row['completedNow']! as bool,
  );
}

JsonMap _periodSummaryJson(PeriodSummary summary) => {
  'periodId': summary.periodId,
  'number': summary.number,
  'plan': {
    'periodId': summary.plan.periodId,
    'needsLimit': summary.plan.needsLimit,
    'wantsLimit': summary.plan.wantsLimit,
    'savingsTarget': summary.plan.savingsTarget,
    'unallocatedAmount': summary.plan.unallocatedAmount,
    'requiredNeedsCostAtConfirmation':
        summary.plan.requiredNeedsCostAtConfirmation,
    'confirmedAt': summary.plan.confirmedAt.toIso8601String(),
  },
  'actual': {
    'periodIncome': summary.actual.periodIncome,
    'taskRewards': summary.actual.taskRewards,
    'needsSpent': summary.actual.needsSpent,
    'wantsSpent': summary.actual.wantsSpent,
    'savingsDeposited': summary.actual.savingsDeposited,
    'ordinarySavingsWithdrawn': summary.actual.ordinarySavingsWithdrawn,
    'goalRedemptionSpent': summary.actual.goalRedemptionSpent,
    'qualifyingSavings': summary.actual.qualifyingSavings,
    'savingsMoodBonusGranted': summary.actual.savingsMoodBonusGranted,
    'requiredNeedsMet': summary.actual.requiredNeedsMet,
    'planKept': summary.actual.planKept,
    'savingsHabitKept': summary.actual.savingsHabitKept,
  },
  'qualityPointsGranted': summary.qualityPointsGranted,
  'qualityPointsTotal': summary.qualityPointsTotal,
  'stageBefore': summary.stageBefore.name,
  'stageAfter': summary.stageAfter.name,
  'satietyAfter': summary.satietyAfter,
  'moodAfter': summary.moodAfter,
  'explanation': summary.explanationForChild,
  'closedAt': summary.closedAt.toIso8601String(),
};

PeriodSummary _periodSummaryFromJson(JsonMap row) {
  final plan = _mapGlobal(row['plan']);
  final actual = _mapGlobal(row['actual']);
  return PeriodSummary(
    periodId: row['periodId']! as String,
    number: row['number']! as int,
    plan: BudgetPlan(
      periodId: plan['periodId']! as String,
      needsLimit: plan['needsLimit']! as int,
      wantsLimit: plan['wantsLimit']! as int,
      savingsTarget: plan['savingsTarget']! as int,
      unallocatedAmount: plan['unallocatedAmount']! as int,
      requiredNeedsCostAtConfirmation:
          plan['requiredNeedsCostAtConfirmation']! as int,
      confirmedAt: DateTime.parse(plan['confirmedAt']! as String),
    ),
    actual: BudgetActual(
      periodIncome: actual['periodIncome']! as int,
      taskRewards: actual['taskRewards']! as int,
      needsSpent: actual['needsSpent']! as int,
      wantsSpent: actual['wantsSpent']! as int,
      savingsDeposited: actual['savingsDeposited']! as int,
      ordinarySavingsWithdrawn: actual['ordinarySavingsWithdrawn']! as int,
      goalRedemptionSpent: actual['goalRedemptionSpent']! as int,
      qualifyingSavings: actual['qualifyingSavings']! as int,
      savingsMoodBonusGranted: actual['savingsMoodBonusGranted']! as bool,
      requiredNeedsMet: actual['requiredNeedsMet']! as bool,
      planKept: actual['planKept']! as bool,
      savingsHabitKept: actual['savingsHabitKept']! as bool,
    ),
    qualityPointsGranted: row['qualityPointsGranted']! as int,
    qualityPointsTotal: row['qualityPointsTotal']! as int,
    stageBefore: PetStage.values.byName(row['stageBefore']! as String),
    stageAfter: PetStage.values.byName(row['stageAfter']! as String),
    satietyAfter: row['satietyAfter']! as int,
    moodAfter: row['moodAfter']! as int,
    explanationForChild: row['explanation']! as String,
    closedAt: DateTime.parse(row['closedAt']! as String),
  );
}

JsonMap _mapGlobal(Object? value) => (value! as Map).cast<String, Object?>();
