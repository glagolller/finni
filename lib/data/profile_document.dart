import '../contracts/contracts.dart';
import '../domain/content/game_content.dart';

class ProfileDocument {
  ProfileDocument(this.data);

  final JsonMap data;

  String get id => data['id']! as String;
  ProfileMode get mode => ProfileMode.values.byName(data['mode']! as String);
  int get generation => data['generation']! as int;
  set generation(int value) => data['generation'] = value;
  int get revision => data['revision']! as int;
  set revision(int value) => data['revision'] = value;
  int get available => data['available']! as int;
  set available(int value) => data['available'] = value;
  int get savings => data['savings']! as int;
  set savings(int value) => data['savings'] = value;
  JsonMap get period => _map(data['period']);
  JsonMap get pet => _map(data['pet']);
  JsonMap get settings => _map(data['settings']);
  JsonMap? get activeGoal =>
      data['activeGoal'] == null ? null : _map(data['activeGoal']);
  set activeGoal(JsonMap? value) => data['activeGoal'] = value;
  JsonMap get taskProgress => _map(data['taskProgress']);
  List<Object?> get transactions => data['transactions']! as List<Object?>;
  List<Object?> get periodSummaries =>
      data['periodSummaries']! as List<Object?>;
  List<Object?> get completedGoals => data['completedGoals']! as List<Object?>;
  List<Object?> get stageHistory => data['stageHistory']! as List<Object?>;
  int get completedPeriods => data['completedPeriods']! as int;
  set completedPeriods(int value) => data['completedPeriods'] = value;
  int get qualityPoints => data['qualityPoints']! as int;
  set qualityPoints(int value) => data['qualityPoints'] = value;

  String get updatedAt => data['updatedAt']! as String;
  set updatedAt(String value) => data['updatedAt'] = value;

  static ProfileDocument create({
    required String id,
    required ProfileMode mode,
    required String? displayName,
    required String petName,
    required String formId,
    required String paletteId,
    required DateTime now,
    required PeriodTemplate template,
  }) {
    final timestamp = now.toUtc().toIso8601String();
    return ProfileDocument({
      'id': id,
      'mode': mode.name,
      'displayName': displayName,
      'petName': petName,
      'formId': formId,
      'paletteId': paletteId,
      'generation': 1,
      'revision': 1,
      'createdAt': timestamp,
      'updatedAt': timestamp,
      'available': 100,
      'savings': 0,
      'period': newPeriod(
        profileId: id,
        generation: 1,
        number: 1,
        now: now,
        template: template,
      ),
      'pet': {
        'satiety': 60,
        'mood': 60,
        'stage': PetStage.baby.name,
        'lastReasonCode': 'profile_created',
        'explanationForChild': 'Финни готов учиться вместе с тобой.',
      },
      'activeGoal': null,
      'taskProgress': <String, Object?>{},
      'completedPeriods': 0,
      'qualityPoints': 0,
      'stageHistory': <Object?>[],
      'settings': {
        'soundEnabled': true,
        'reducedMotion': false,
        'largeTextPreferred': false,
      },
      'transactions': <Object?>[
        transactionJson(
          id: 'tx.$id.g1.p1.income',
          profileId: id,
          generation: 1,
          periodId: '$id.g1.p1',
          type: TransactionType.periodIncome,
          amount: 100,
          availableChange: 100,
          savingsChange: 0,
          actionId: 'profile-created',
          createdAt: now,
        ),
      ],
      'periodSummaries': <Object?>[],
      'completedGoals': <Object?>[],
    });
  }

  static JsonMap newPeriod({
    required String profileId,
    required int generation,
    required int number,
    required DateTime now,
    required PeriodTemplate template,
  }) {
    final timestamp = now.toUtc().toIso8601String();
    return {
      'id': '$profileId.g$generation.p$number',
      'number': number,
      'status': PeriodStatus.open.name,
      'incomeCredited': 100,
      'incomeCreditedAt': timestamp,
      'availableItemIds': List<String>.from(template.availableItemIds),
      'requiredItemIds': List<String>.from(template.requiredItemIds),
      'purchaseSlotsTotal': 3,
      'purchaseSlotsUsed': 0,
      'purchasedItemIds': <String>[],
      'budgetPlan': null,
      'actual': {
        'periodIncome': 100,
        'taskRewards': 0,
        'needsSpent': 0,
        'wantsSpent': 0,
        'savingsDeposited': 0,
        'ordinarySavingsWithdrawn': 0,
        'goalRedemptionSpent': 0,
        'savingsMoodBonusGranted': false,
      },
      'startedAt': timestamp,
      'closedAt': null,
    };
  }

  void reset({required DateTime now, required PeriodTemplate template}) {
    generation += 1;
    available = 100;
    savings = 0;
    data['period'] = newPeriod(
      profileId: id,
      generation: generation,
      number: 1,
      now: now,
      template: template,
    );
    pet
      ..['satiety'] = 60
      ..['mood'] = 60
      ..['stage'] = PetStage.baby.name
      ..['lastReasonCode'] = 'demo_reset'
      ..['explanationForChild'] = 'Финни готов учиться вместе с тобой.';
    activeGoal = null;
    data['taskProgress'] = <String, Object?>{};
    completedPeriods = 0;
    qualityPoints = 0;
    data['stageHistory'] = <Object?>[];
    data['transactions'] = <Object?>[
      transactionJson(
        id: 'tx.$id.g$generation.p1.income',
        profileId: id,
        generation: generation,
        periodId: period['id']! as String,
        type: TransactionType.periodIncome,
        amount: 100,
        availableChange: 100,
        savingsChange: 0,
        actionId: 'demo-reset',
        createdAt: now,
      ),
    ];
    data['periodSummaries'] = <Object?>[];
    data['completedGoals'] = <Object?>[];
    updatedAt = now.toUtc().toIso8601String();
  }

  GameState snapshot(GameContent content) {
    final actual = _actual(period, content);
    final stage = PetStage.values.byName(pet['stage']! as String);
    return GameState(
      contractVersion: logicContractVersion,
      contentVersion: contentVersion,
      stateRevision: revision,
      profile: Profile(
        id: id,
        mode: mode,
        displayName: data['displayName'] as String?,
        petName: data['petName']! as String,
        generation: generation,
        createdAt: DateTime.parse(data['createdAt']! as String),
        updatedAt: DateTime.parse(updatedAt),
      ),
      currentPeriod: PeriodState(
        id: period['id']! as String,
        number: period['number']! as int,
        status: PeriodStatus.values.byName(period['status']! as String),
        incomeCredited: period['incomeCredited']! as int,
        incomeCreditedAt: DateTime.parse(period['incomeCreditedAt']! as String),
        availableItemIds: _strings(period['availableItemIds']),
        requiredPurchases: _strings(period['requiredItemIds'])
            .map(
              (itemId) => RequiredPurchase(
                itemId: itemId,
                quantity: 1,
                fulfilled: _strings(period['purchasedItemIds'])
                    .contains(itemId),
              ),
            )
            .toList(),
        purchaseSlotsTotal: period['purchaseSlotsTotal']! as int,
        purchaseSlotsUsed: period['purchaseSlotsUsed']! as int,
        purchasedItemIds: _strings(period['purchasedItemIds']),
        budgetPlan: _budgetPlan(period),
        actual: actual,
        startedAt: DateTime.parse(period['startedAt']! as String),
        closedAt: period['closedAt'] == null
            ? null
            : DateTime.parse(period['closedAt']! as String),
      ),
      availableBalance: available,
      savingsBalance: savings,
      activeGoal: _goalProgress(content),
      pet: PetState(
        name: data['petName']! as String,
        formId: data['formId']! as String,
        paletteId: data['paletteId']! as String,
        satiety: pet['satiety']! as int,
        mood: pet['mood']! as int,
        moodCode: moodCode(pet['mood']! as int),
        stage: stage,
        lastReasonCode: pet['lastReasonCode'] as String?,
        explanationForChild: pet['explanationForChild'] as String?,
      ),
      taskHub: taskHub(content),
      learningProgress: LearningProgress(
        completedPeriods: completedPeriods,
        qualityPoints: qualityPoints,
        taskProgress: content.tasks.keys.map(taskProgressModel).toList(),
        stageHistory: stageHistory.map((value) {
          final row = _map(value);
          return StageHistoryEntry(
            stage: PetStage.values.byName(row['stage']! as String),
            reachedAfterPeriod: row['reachedAfterPeriod']! as int,
            qualityPoints: row['qualityPoints']! as int,
            reachedAt: DateTime.parse(row['reachedAt']! as String),
          );
        }).toList(),
      ),
      settings: ProfileSettings(
        soundEnabled: settings['soundEnabled']! as bool,
        reducedMotion: settings['reducedMotion']! as bool,
        largeTextPreferred: settings['largeTextPreferred']! as bool,
      ),
    );
  }

  TaskHub taskHub(GameContent content) {
    final summaries = content.tasks.values.map((task) {
      final progress = taskProgressModel(task.id);
      final periodStatus = PeriodStatus.values.byName(
        period['status']! as String,
      );
      final availability = periodStatus == PeriodStatus.demoCompleted
          ? TaskAvailabilityCode.demoCompletedReview
          : periodStatus == PeriodStatus.closed
          ? TaskAvailabilityCode.periodClosed
          : progress.completed
          ? TaskAvailabilityCode.completedReview
          : progress.attemptsThisPeriod >= task.maxAttemptsPerPeriod
          ? TaskAvailabilityCode.attemptLimitReached
          : TaskAvailabilityCode.available;
      return TaskSummary(
        id: task.id,
        title: task.title,
        theme: task.theme,
        interactionType: task.interactionType,
        rewardAmount: task.rewardAmount,
        availability: availability,
        unavailableReason:
            availability == TaskAvailabilityCode.available ||
                availability == TaskAvailabilityCode.completedReview
            ? null
            : 'Задание сейчас недоступно.',
        completed: progress.completed,
        rewardState: progress.completed
            ? RewardState.alreadyGranted
            : RewardState.available,
        attemptsThisPeriod: progress.attemptsThisPeriod,
        remainingAttempts:
            (task.maxAttemptsPerPeriod - progress.attemptsThisPeriod).clamp(
              0,
              task.maxAttemptsPerPeriod,
            ),
      );
    }).toList();
    final availableTasks = summaries.where(
      (task) => task.availability == TaskAvailabilityCode.available,
    );
    return TaskHub(
      tasks: summaries,
      recommendedTask: availableTasks.isEmpty ? null : availableTasks.first,
    );
  }

  TaskProgress taskProgressModel(String taskId) {
    final row = taskProgress[taskId] == null
        ? <String, Object?>{}
        : _map(taskProgress[taskId]);
    return TaskProgress(
      taskId: taskId,
      completed: row['completed'] as bool? ?? false,
      attemptsTotal: row['attemptsTotal'] as int? ?? 0,
      attemptsThisPeriod: row['attemptsThisPeriod'] as int? ?? 0,
      lastOutcome: row['lastOutcome'] == null
          ? null
          : TaskAttemptOutcome.values.byName(row['lastOutcome']! as String),
      rewardState: (row['completed'] as bool? ?? false)
          ? RewardState.granted
          : RewardState.available,
      completedAt: row['completedAt'] == null
          ? null
          : DateTime.parse(row['completedAt']! as String),
    );
  }

  List<TransactionRecord> transactionModels() => transactions.map((value) {
    final row = _map(value);
    return TransactionRecord(
      id: row['id']! as String,
      profileId: id,
      profileGeneration: row['generation']! as int,
      periodId: row['periodId']! as String,
      type: TransactionType.values.byName(row['type']! as String),
      amount: row['amount']! as int,
      availableChange: row['availableChange']! as int,
      savingsChange: row['savingsChange']! as int,
      relatedEntityId: row['relatedEntityId'] as String?,
      unitPrice: row['unitPrice'] as int?,
      contentVersion: contentVersion,
      actionId: row['actionId']! as String,
      createdAt: DateTime.parse(row['createdAt']! as String),
    );
  }).toList();

  List<CompletedGoalRecord> completedGoalModels() =>
      completedGoals.map((value) {
        final row = _map(value);
        return CompletedGoalRecord(
          goalId: row['goalId']! as String,
          title: row['title']! as String,
          amountSpent: row['amountSpent']! as int,
          completedAt: DateTime.parse(row['completedAt']! as String),
          transactionId: row['transactionId']! as String,
        );
      }).toList();

  static JsonMap transactionJson({
    required String id,
    required String profileId,
    required int generation,
    required String periodId,
    required TransactionType type,
    required int amount,
    required int availableChange,
    required int savingsChange,
    required String actionId,
    required DateTime createdAt,
    String? relatedEntityId,
    int? unitPrice,
  }) => {
    'id': id,
    'profileId': profileId,
    'generation': generation,
    'periodId': periodId,
    'type': type.name,
    'amount': amount,
    'availableChange': availableChange,
    'savingsChange': savingsChange,
    'relatedEntityId': relatedEntityId,
    'unitPrice': unitPrice,
    'actionId': actionId,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static MoodCode moodCode(int mood) => mood >= 70
      ? MoodCode.happy
      : mood >= 40
      ? MoodCode.calm
      : MoodCode.needsAttention;

  static JsonMap _map(Object? value) => (value! as Map).cast<String, Object?>();
  static List<String> _strings(Object? value) =>
      (value! as List<Object?>).cast<String>();

  BudgetPlan? _budgetPlan(JsonMap period) {
    if (period['budgetPlan'] == null) return null;
    final row = _map(period['budgetPlan']);
    return BudgetPlan(
      periodId: period['id']! as String,
      needsLimit: row['needsLimit']! as int,
      wantsLimit: row['wantsLimit']! as int,
      savingsTarget: row['savingsTarget']! as int,
      unallocatedAmount: row['unallocatedAmount']! as int,
      requiredNeedsCostAtConfirmation:
          row['requiredNeedsCostAtConfirmation']! as int,
      confirmedAt: DateTime.parse(row['confirmedAt']! as String),
    );
  }

  BudgetActual _actual(JsonMap period, GameContent content) {
    final row = _map(period['actual']);
    final purchased = _strings(period['purchasedItemIds']);
    final requiredMet = _strings(period['requiredItemIds'])
        .every(purchased.contains);
    final plan = _budgetPlan(period);
    final qualifying =
        ((row['savingsDeposited']! as int) -
                (row['ordinarySavingsWithdrawn']! as int))
            .clamp(0, 1 << 31);
    final planKept =
        plan != null &&
        (row['needsSpent']! as int) <= plan.needsLimit &&
        (row['wantsSpent']! as int) <= plan.wantsLimit &&
        qualifying >= plan.savingsTarget;
    return BudgetActual(
      periodIncome: row['periodIncome']! as int,
      taskRewards: row['taskRewards']! as int,
      needsSpent: row['needsSpent']! as int,
      wantsSpent: row['wantsSpent']! as int,
      savingsDeposited: row['savingsDeposited']! as int,
      ordinarySavingsWithdrawn: row['ordinarySavingsWithdrawn']! as int,
      goalRedemptionSpent: row['goalRedemptionSpent']! as int,
      qualifyingSavings: qualifying,
      savingsMoodBonusGranted: row['savingsMoodBonusGranted']! as bool,
      requiredNeedsMet: requiredMet,
      planKept: planKept,
      savingsHabitKept: qualifying >= 20,
    );
  }

  GoalProgress? _goalProgress(GameContent content) {
    final row = activeGoal;
    if (row == null) return null;
    final goal = content.goals[row['goalId']]!;
    final status = savings >= goal.targetAmount
        ? GoalStatus.reachable
        : GoalStatus.selected;
    return GoalProgress(
      goalId: goal.id,
      title: goal.title,
      targetAmount: goal.targetAmount,
      savedAmount: savings,
      remainingAmount: (goal.targetAmount - savings).clamp(
        0,
        goal.targetAmount,
      ),
      status: status,
      selectedAt: DateTime.parse(row['selectedAt']! as String),
    );
  }
}
