import 'dart:io';

import 'package:finni/contracts/contracts.dart';
import 'package:finni/domain/services/sqlite_logic_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDirectory;
  late String databasePath;
  late TestClock clock;
  late int action;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('finni_logic_test_');
    databasePath = path.join(tempDirectory.path, 'finni.sqlite3');
    clock = TestClock();
    action = 0;
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  String nextAction(String prefix) => '$prefix.${action++}';

  Future<SqliteLogicService> open() => SqliteLogicService.open(
    databaseFactory: databaseFactoryFfi,
    databasePath: databasePath,
    now: clock.call,
  );

  Future<GameState> create(SqliteLogicService service) async {
    final result = await service.createProfile(
      CreateProfileCommand(
        actionId: nextAction('create'),
        mode: ProfileMode.demo,
        petName: 'Финни',
        formId: 'pet.form.01',
        paletteId: 'pet.palette.01',
      ),
    );
    expect(result.success, isTrue);
    return result.stateSnapshot!;
  }

  test(
    'persists state and replays a committed transfer after restart',
    () async {
      var service = await open();
      var state = await create(service);
      state = await confirmPlan(service, state, 50, 20, 30, nextAction);
      state = await buy(service, state, 'item.food', nextAction);
      state = await buy(service, state, 'item.hygiene', nextAction);

      final command = SavingsTransferCommand(
        profileId: state.profile.id,
        expectedGeneration: state.profile.generation,
        expectedRevision: state.stateRevision,
        actionId: nextAction('deposit'),
        direction: TransferDirection.toSavings,
        amount: 30,
      );
      final deposit = await service.transferSavings(command);
      state = deposit.stateSnapshot!;
      expect(state.availableBalance, 20);
      expect(state.savingsBalance, 30);

      final preview = await service.previewPurchase(
        PurchaseQuery(
          profileId: state.profile.id,
          expectedGeneration: state.profile.generation,
          expectedRevision: state.stateRevision,
          itemId: 'item.music_player',
        ),
      );
      expect(preview.allowed, isFalse);
      expect(preview.errorCode, LogicErrorCode.insufficientFunds);
      final rejectedPurchase = await service.buyItem(
        PurchaseCommand(
          profileId: state.profile.id,
          expectedGeneration: state.profile.generation,
          expectedRevision: state.stateRevision,
          actionId: nextAction('rejected-buy'),
          itemId: 'item.music_player',
        ),
      );
      expect(rejectedPurchase.errorCode, LogicErrorCode.insufficientFunds);
      expect(
        rejectedPurchase.stateSnapshot!.stateRevision,
        state.stateRevision,
      );
      expect(
        rejectedPurchase.stateSnapshot!.currentPeriod.purchaseSlotsUsed,
        2,
      );

      await service.close();
      service = await open();
      final loaded = await service.loadState(state.profile.id);
      expect(loaded.stateSnapshot!.availableBalance, 20);
      expect(loaded.stateSnapshot!.savingsBalance, 30);

      final replay = await service.transferSavings(command);
      expect(replay.outcome, ActionOutcome.replayed);
      expect(replay.moneyDelta!.savingsChange, 30);
      expect(replay.stateSnapshot!.savingsBalance, 30);
      expect(replay.stateSnapshot!.stateRevision, state.stateRevision);
      final conflict = await service.transferSavings(
        SavingsTransferCommand(
          profileId: command.profileId,
          expectedGeneration: command.expectedGeneration,
          expectedRevision: command.expectedRevision,
          actionId: command.actionId,
          direction: command.direction,
          amount: 20,
        ),
      );
      expect(conflict.errorCode, LogicErrorCode.actionConflict);
      expect(conflict.stateSnapshot!.savingsBalance, 30);
      await service.close();
    },
  );

  test(
    'runs the agreed five-period scenario with exact final totals',
    () async {
      final service = await open();
      var state = await create(service);
      state = (await service.changeGoal(
        GoalCommand(
          profileId: state.profile.id,
          expectedGeneration: state.profile.generation,
          expectedRevision: state.stateRevision,
          actionId: nextAction('goal'),
          goalId: 'goal.playground',
        ),
      )).stateSnapshot!;

      state = await successfulPeriod(
        service,
        state,
        nextAction,
        plan: const [50, 20, 30],
        tasks: const [
          BudgetAllocationAnswer(needs: 50, wants: 20, savings: 30),
          SavingsScheduleAnswer(amountsByPeriod: [30, 30, 30, 30]),
        ],
        taskIds: const ['task.budget.01', 'task.savings.01'],
        purchases: const ['item.food', 'item.hygiene'],
        depositAmount: 30,
      );
      expect((state.availableBalance, state.savingsBalance), (30, 30));
      state = await startNext(service, state, nextAction);

      state = await successfulPeriod(
        service,
        state,
        nextAction,
        plan: const [45, 35, 30],
        tasks: const [
          PurchaseBasketAnswer(selectedItemIds: ['item.food']),
        ],
        taskIds: const ['task.payments.01'],
        purchases: const ['item.school_lunch', 'item.hygiene', 'item.ball'],
        depositAmount: 30,
      );
      expect((state.availableBalance, state.savingsBalance), (25, 60));
      expect(state.pet.stage, PetStage.junior);
      state = await startNext(service, state, nextAction);

      state = await confirmPlan(service, state, 50, 45, 30, nextAction);
      var attempt = await service.submitTaskAnswer(
        TaskAnswerCommand(
          profileId: state.profile.id,
          expectedGeneration: state.profile.generation,
          expectedRevision: state.stateRevision,
          actionId: nextAction('wrong-task'),
          taskId: 'task.payments.02',
          answer: const ExpenseClassificationAnswer(
            groupByEntryId: {'item.food': ExpenseType.want},
          ),
        ),
      );
      expect(attempt.taskAttempt!.outcome, TaskAttemptOutcome.needsRetry);
      expect(attempt.moneyDelta, isNull);
      state = attempt.stateSnapshot!;
      attempt = await service.submitTaskAnswer(
        TaskAnswerCommand(
          profileId: state.profile.id,
          expectedGeneration: state.profile.generation,
          expectedRevision: state.stateRevision,
          actionId: nextAction('correct-task'),
          taskId: 'task.payments.02',
          answer: const ExpenseClassificationAnswer(
            groupByEntryId: {
              'item.food': ExpenseType.need,
              'item.hygiene': ExpenseType.need,
              'item.school_lunch': ExpenseType.need,
              'item.health_check': ExpenseType.need,
              'item.ball': ExpenseType.want,
              'item.hat': ExpenseType.want,
            },
          ),
        ),
      );
      state = attempt.stateSnapshot!;
      for (final item in ['item.food', 'item.hygiene', 'item.hat']) {
        state = await buy(service, state, item, nextAction);
      }
      state = await deposit(service, state, 30, nextAction);
      state = await finish(service, state, nextAction);
      expect((state.availableBalance, state.savingsBalance), (5, 90));
      state = await startNext(service, state, nextAction);

      state = await successfulPeriod(
        service,
        state,
        nextAction,
        plan: const [70, 0, 25],
        tasks: const [PlanFactChoiceAnswer(selectedOptionId: 'option.plan_b')],
        taskIds: const ['task.budget.02'],
        purchases: const ['item.health_check', 'item.food'],
        depositAmount: 25,
      );
      expect((state.availableBalance, state.savingsBalance), (15, 115));
      expect(state.pet.stage, PetStage.grown);
      state = await startNext(service, state, nextAction);

      state = await successfulPeriod(
        service,
        state,
        nextAction,
        plan: const [50, 35, 30],
        tasks: const [SavingsComparisonAnswer(selectedOptionId: 'option.25')],
        taskIds: const ['task.savings.02'],
        purchases: const ['item.food', 'item.hygiene', 'item.ball'],
        depositAmount: 30,
        closePeriod: false,
      );
      state = (await service.redeemGoal(
        GoalCommand(
          profileId: state.profile.id,
          expectedGeneration: state.profile.generation,
          expectedRevision: state.stateRevision,
          actionId: nextAction('redeem'),
          goalId: 'goal.playground',
          acceptedWarnings: const {WarningCode.goalRedemption},
        ),
      )).stateSnapshot!;
      state = await finish(service, state, nextAction);
      expect((state.availableBalance, state.savingsBalance), (5, 25));
      expect(state.learningProgress.qualityPoints, 15);
      expect(state.pet.stage, PetStage.grown);
      expect(state.currentPeriod.status, PeriodStatus.demoCompleted);
      final history = await service.getHistory(state.profile.id);
      expect(history.periodSummaries, hasLength(5));
      expect(history.completedGoals.single.amountSpent, 120);
      await service.close();
    },
  );

  test('bad five-period series grants five points and remains baby', () async {
    final service = await open();
    var state = await create(service);
    final wants = [
      'item.ball',
      'item.ball',
      'item.hat',
      'item.room_decor',
      'item.ball',
    ];
    for (var period = 1; period <= 5; period++) {
      final result = await service.confirmBudget(
        BudgetCommand(
          profileId: state.profile.id,
          expectedGeneration: state.profile.generation,
          expectedRevision: state.stateRevision,
          actionId: nextAction('bad-plan'),
          needsLimit: 0,
          wantsLimit: 100,
          savingsTarget: 0,
          acceptedWarnings: const {WarningCode.needsUnderfunded},
        ),
      );
      state = result.stateSnapshot!;
      state = await buy(service, state, wants[period - 1], nextAction);
      state = await finish(
        service,
        state,
        nextAction,
        acceptMissingNeeds: true,
      );
      expect(state.learningProgress.qualityPoints, period);
      expect(state.pet.stage, PetStage.baby);
      if (period < 5) state = await startNext(service, state, nextAction);
    }
    expect(state.currentPeriod.status, PeriodStatus.demoCompleted);
    expect(state.learningProgress.completedPeriods, 5);
    await service.close();
  });

  test('reset and delete keep durable receipts', () async {
    final service = await open();
    var state = await create(service);
    final reset = ConfirmedProfileCommand(
      profileId: state.profile.id,
      expectedGeneration: state.profile.generation,
      expectedRevision: state.stateRevision,
      actionId: nextAction('reset'),
      confirmationText: resetDemoConfirmationText,
    );
    final firstReset = await service.resetDemoProfile(reset);
    state = firstReset.stateSnapshot!;
    expect(state.profile.generation, 2);
    expect(state.availableBalance, 100);
    final replayedReset = await service.resetDemoProfile(reset);
    expect(replayedReset.outcome, ActionOutcome.replayed);
    expect(replayedReset.stateSnapshot!.profile.generation, 2);
    expect(replayedReset.stateSnapshot!.availableBalance, 100);

    final delete = ConfirmedProfileCommand(
      profileId: state.profile.id,
      expectedGeneration: state.profile.generation,
      expectedRevision: state.stateRevision,
      actionId: nextAction('delete'),
      confirmationText: deleteProfileConfirmationText,
    );
    final firstDelete = await service.deleteProfile(delete);
    expect(firstDelete.success, isTrue);
    expect(firstDelete.stateSnapshot, isNull);
    final replayedDelete = await service.deleteProfile(delete);
    expect(replayedDelete.outcome, ActionOutcome.replayed);
    expect(replayedDelete.stateSnapshot, isNull);
    expect((await service.listProfiles()).profiles, isEmpty);
    await service.close();
  });
}

class TestClock {
  DateTime value = DateTime.utc(2026, 9, 25, 8);

  DateTime call() {
    final result = value;
    value = value.add(const Duration(seconds: 1));
    return result;
  }
}

typedef ActionId = String Function(String prefix);

Future<GameState> confirmPlan(
  SqliteLogicService service,
  GameState state,
  int needs,
  int wants,
  int savings,
  ActionId nextAction,
) async {
  final result = await service.confirmBudget(
    BudgetCommand(
      profileId: state.profile.id,
      expectedGeneration: state.profile.generation,
      expectedRevision: state.stateRevision,
      actionId: nextAction('plan'),
      needsLimit: needs,
      wantsLimit: wants,
      savingsTarget: savings,
    ),
  );
  expect(result.success, isTrue);
  return result.stateSnapshot!;
}

Future<GameState> buy(
  SqliteLogicService service,
  GameState state,
  String itemId,
  ActionId nextAction,
) async {
  final result = await service.buyItem(
    PurchaseCommand(
      profileId: state.profile.id,
      expectedGeneration: state.profile.generation,
      expectedRevision: state.stateRevision,
      actionId: nextAction('buy'),
      itemId: itemId,
    ),
  );
  expect(result.success, isTrue, reason: result.messageForChild);
  return result.stateSnapshot!;
}

Future<GameState> deposit(
  SqliteLogicService service,
  GameState state,
  int amount,
  ActionId nextAction,
) async {
  final result = await service.transferSavings(
    SavingsTransferCommand(
      profileId: state.profile.id,
      expectedGeneration: state.profile.generation,
      expectedRevision: state.stateRevision,
      actionId: nextAction('deposit'),
      direction: TransferDirection.toSavings,
      amount: amount,
    ),
  );
  expect(result.success, isTrue);
  return result.stateSnapshot!;
}

Future<GameState> finish(
  SqliteLogicService service,
  GameState state,
  ActionId nextAction, {
  bool acceptMissingNeeds = false,
}) async {
  final result = await service.finishPeriod(
    PeriodCommand(
      profileId: state.profile.id,
      expectedGeneration: state.profile.generation,
      expectedRevision: state.stateRevision,
      actionId: nextAction('finish'),
      periodId: state.currentPeriod.id,
      acceptedWarnings: acceptMissingNeeds
          ? const {WarningCode.mandatoryNeedsUnmet}
          : const {},
    ),
  );
  expect(result.success, isTrue, reason: result.messageForChild);
  return result.stateSnapshot!;
}

Future<GameState> startNext(
  SqliteLogicService service,
  GameState state,
  ActionId nextAction,
) async {
  final result = await service.startNextPeriod(
    PeriodCommand(
      profileId: state.profile.id,
      expectedGeneration: state.profile.generation,
      expectedRevision: state.stateRevision,
      actionId: nextAction('start'),
      periodId: state.currentPeriod.id,
    ),
  );
  expect(result.success, isTrue);
  return result.stateSnapshot!;
}

Future<GameState> successfulPeriod(
  SqliteLogicService service,
  GameState state,
  ActionId nextAction, {
  required List<int> plan,
  required List<TaskAnswer> tasks,
  required List<String> taskIds,
  required List<String> purchases,
  required int depositAmount,
  bool closePeriod = true,
}) async {
  state = await confirmPlan(
    service,
    state,
    plan[0],
    plan[1],
    plan[2],
    nextAction,
  );
  for (var index = 0; index < tasks.length; index++) {
    final result = await service.submitTaskAnswer(
      TaskAnswerCommand(
        profileId: state.profile.id,
        expectedGeneration: state.profile.generation,
        expectedRevision: state.stateRevision,
        actionId: nextAction('task'),
        taskId: taskIds[index],
        answer: tasks[index],
      ),
    );
    expect(result.taskAttempt!.outcome, TaskAttemptOutcome.correct);
    state = result.stateSnapshot!;
  }
  for (final item in purchases) {
    state = await buy(service, state, item, nextAction);
  }
  state = await deposit(service, state, depositAmount, nextAction);
  return closePeriod ? finish(service, state, nextAction) : state;
}
