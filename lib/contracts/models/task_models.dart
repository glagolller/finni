import '../enums.dart';

class TaskSummary {
  const TaskSummary({
    required this.id,
    required this.title,
    required this.theme,
    required this.interactionType,
    required this.rewardAmount,
    required this.availability,
    required this.completed,
    required this.rewardState,
    required this.attemptsThisPeriod,
    required this.remainingAttempts,
    this.unavailableReason,
  });

  final String id;
  final String title;
  final TaskTheme theme;
  final TaskInteractionType interactionType;
  final int rewardAmount;
  final TaskAvailabilityCode availability;
  final String? unavailableReason;
  final bool completed;
  final RewardState rewardState;
  final int attemptsThisPeriod;
  final int remainingAttempts;
}

class TaskHub {
  const TaskHub({required this.tasks, this.recommendedTask});

  final TaskSummary? recommendedTask;
  final List<TaskSummary> tasks;
}

sealed class TaskInput {
  const TaskInput(this.type);

  final TaskInteractionType type;
}

class BudgetAllocationInput extends TaskInput {
  const BudgetAllocationInput({
    required this.income,
    required this.minimumNeeds,
    required this.minimumSavings,
    required this.allowedCategories,
  }) : super(TaskInteractionType.budgetAllocation);

  final int income;
  final int minimumNeeds;
  final int minimumSavings;
  final List<String> allowedCategories;
}

class BudgetPlanOption {
  const BudgetPlanOption({
    required this.id,
    required this.needs,
    required this.wants,
    required this.savings,
  });

  final String id;
  final int needs;
  final int wants;
  final int savings;
}

class PlanFactChoiceInput extends TaskInput {
  const PlanFactChoiceInput({
    required this.plans,
    required this.actualNeeds,
    required this.actualWants,
    required this.actualSavings,
  }) : super(TaskInteractionType.planFactChoice);

  final List<BudgetPlanOption> plans;
  final int actualNeeds;
  final int actualWants;
  final int actualSavings;
}

class SavingsScheduleInput extends TaskInput {
  const SavingsScheduleInput({
    required this.goalAmount,
    required this.periodCount,
    required this.minimumPerPeriod,
  }) : super(TaskInteractionType.savingsSchedule);

  final int goalAmount;
  final int periodCount;
  final int minimumPerPeriod;
}

class SavingsOperation {
  const SavingsOperation({required this.direction, required this.amount});

  final TransferDirection direction;
  final int amount;
}

class ChoiceOption {
  const ChoiceOption({required this.id, required this.label});

  final String id;
  final String label;
}

class SavingsComparisonInput extends TaskInput {
  const SavingsComparisonInput({
    required this.operations,
    required this.options,
  }) : super(TaskInteractionType.savingsComparison);

  final List<SavingsOperation> operations;
  final List<ChoiceOption> options;
}

class TaskItemOption {
  const TaskItemOption({
    required this.id,
    required this.title,
    required this.price,
    required this.expenseType,
  });

  final String id;
  final String title;
  final int price;
  final ExpenseType expenseType;
}

class PurchaseBasketInput extends TaskInput {
  const PurchaseBasketInput({
    required this.budget,
    required this.items,
    required this.requiredItemIds,
    required this.maxSelectedItems,
  }) : super(TaskInteractionType.purchaseBasket);

  final int budget;
  final List<TaskItemOption> items;
  final List<String> requiredItemIds;
  final int maxSelectedItems;
}

class ClassificationEntry {
  const ClassificationEntry({required this.id, required this.label});

  final String id;
  final String label;
}

class ExpenseClassificationInput extends TaskInput {
  const ExpenseClassificationInput({
    required this.entries,
    required this.targetGroups,
  }) : super(TaskInteractionType.expenseClassification);

  final List<ClassificationEntry> entries;
  final List<ExpenseType> targetGroups;
}

sealed class TaskCriterion {
  const TaskCriterion(this.type);

  final String type;
}

class BudgetAllocationCriterion extends TaskCriterion {
  const BudgetAllocationCriterion({
    required this.requiredTotal,
    required this.minimumNeeds,
    required this.minimumSavings,
  }) : super('budget_allocation');

  final int requiredTotal;
  final int minimumNeeds;
  final int minimumSavings;
}

class SingleChoiceCriterion extends TaskCriterion {
  const SingleChoiceCriterion({required this.correctOptionId})
    : super('single_choice');

  final String correctOptionId;
}

class SavingsScheduleCriterion extends TaskCriterion {
  const SavingsScheduleCriterion({
    required this.minimumTotal,
    required this.minimumEachPeriod,
    required this.requiredPeriodCount,
  }) : super('savings_schedule');

  final int minimumTotal;
  final int minimumEachPeriod;
  final int requiredPeriodCount;
}

class PurchaseBasketCriterion extends TaskCriterion {
  const PurchaseBasketCriterion({
    required this.maximumTotal,
    required this.maximumItems,
    required this.requiredItemIds,
  }) : super('purchase_basket');

  final int maximumTotal;
  final int maximumItems;
  final List<String> requiredItemIds;
}

class ExpenseClassificationCriterion extends TaskCriterion {
  const ExpenseClassificationCriterion({required this.groupByEntryId})
    : super('expense_classification');

  final Map<String, ExpenseType> groupByEntryId;
}

class TaskFeedback {
  const TaskFeedback({required this.correct, required this.needsRetry});

  final String correct;
  final String needsRetry;
}

class TaskDefinition {
  const TaskDefinition({
    required this.id,
    required this.title,
    required this.theme,
    required this.interactionType,
    required this.prompt,
    required this.rewardAmount,
    required this.maxAttemptsPerPeriod,
    required this.simulationOnly,
    required this.input,
    required this.criterion,
    required this.feedback,
  });

  final String id;
  final String title;
  final TaskTheme theme;
  final TaskInteractionType interactionType;
  final String prompt;
  final int rewardAmount;
  final int maxAttemptsPerPeriod;
  final bool simulationOnly;
  final TaskInput input;
  final TaskCriterion criterion;
  final TaskFeedback feedback;
}

sealed class TaskAnswer {
  const TaskAnswer(this.type);

  final TaskInteractionType type;
}

class BudgetAllocationAnswer extends TaskAnswer {
  const BudgetAllocationAnswer({
    required this.needs,
    required this.wants,
    required this.savings,
  }) : super(TaskInteractionType.budgetAllocation);

  final int needs;
  final int wants;
  final int savings;
}

class PlanFactChoiceAnswer extends TaskAnswer {
  const PlanFactChoiceAnswer({required this.selectedOptionId})
    : super(TaskInteractionType.planFactChoice);

  final String selectedOptionId;
}

class SavingsScheduleAnswer extends TaskAnswer {
  const SavingsScheduleAnswer({required this.amountsByPeriod})
    : super(TaskInteractionType.savingsSchedule);

  final List<int> amountsByPeriod;
}

class SavingsComparisonAnswer extends TaskAnswer {
  const SavingsComparisonAnswer({required this.selectedOptionId})
    : super(TaskInteractionType.savingsComparison);

  final String selectedOptionId;
}

class PurchaseBasketAnswer extends TaskAnswer {
  const PurchaseBasketAnswer({required this.selectedItemIds})
    : super(TaskInteractionType.purchaseBasket);

  final List<String> selectedItemIds;
}

class ExpenseClassificationAnswer extends TaskAnswer {
  const ExpenseClassificationAnswer({required this.groupByEntryId})
    : super(TaskInteractionType.expenseClassification);

  final Map<String, ExpenseType> groupByEntryId;
}

class TaskAttemptResult {
  const TaskAttemptResult({
    required this.taskId,
    required this.attemptNumberThisPeriod,
    required this.outcome,
    required this.explanation,
    required this.rewardGranted,
    required this.rewardAmount,
    required this.rewardState,
    required this.remainingAttempts,
    required this.completedNow,
  });

  final String taskId;
  final int attemptNumberThisPeriod;
  final TaskAttemptOutcome outcome;
  final String explanation;
  final bool rewardGranted;
  final int rewardAmount;
  final RewardState rewardState;
  final int remainingAttempts;
  final bool completedNow;
}

class TaskProgress {
  const TaskProgress({
    required this.taskId,
    required this.completed,
    required this.attemptsTotal,
    required this.attemptsThisPeriod,
    required this.rewardState,
    this.lastOutcome,
    this.completedAt,
  });

  final String taskId;
  final bool completed;
  final int attemptsTotal;
  final int attemptsThisPeriod;
  final TaskAttemptOutcome? lastOutcome;
  final RewardState rewardState;
  final DateTime? completedAt;
}
