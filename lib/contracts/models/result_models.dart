import '../enums.dart';
import 'core_models.dart';
import 'task_models.dart';

class MoneyDelta {
  const MoneyDelta({
    required this.availableChange,
    required this.savingsChange,
    required this.incomeChange,
    required this.rewardChange,
    required this.reasonCode,
  });

  final int availableChange;
  final int savingsChange;
  final int incomeChange;
  final int rewardChange;
  final String reasonCode;
}

class WarningMessage {
  const WarningMessage({
    required this.code,
    required this.messageForChild,
    required this.requiresConfirmation,
  });

  final WarningCode code;
  final String messageForChild;
  final bool requiresConfirmation;
}

class NextAction {
  const NextAction({required this.code, this.params = const {}});

  final NextActionCode code;
  final JsonMap params;
}

class ListProfilesResult {
  const ListProfilesResult({
    required this.profiles,
    this.errorCode,
    this.messageForChild,
  });

  final List<ProfileSummary> profiles;
  final LogicErrorCode? errorCode;
  final String? messageForChild;
}

class LoadStateResult {
  const LoadStateResult({
    required this.found,
    this.stateSnapshot,
    this.errorCode,
    this.messageForChild,
  });

  final bool found;
  final GameState? stateSnapshot;
  final LogicErrorCode? errorCode;
  final String? messageForChild;
}

class CatalogResult<T> {
  const CatalogResult({
    required this.items,
    required this.stateRevision,
    required this.profileGeneration,
    this.errorCode,
    this.messageForChild,
  });

  final List<T> items;
  final int stateRevision;
  final int profileGeneration;
  final LogicErrorCode? errorCode;
  final String? messageForChild;
}

class TaskDefinitionResult {
  const TaskDefinitionResult({
    required this.availability,
    this.definition,
    this.errorCode,
    this.messageForChild,
  });

  final TaskDefinition? definition;
  final TaskAvailabilityCode availability;
  final LogicErrorCode? errorCode;
  final String? messageForChild;
}

class ProgressResult {
  const ProgressResult({this.progress, this.errorCode, this.messageForChild});

  final LearningProgress? progress;
  final LogicErrorCode? errorCode;
  final String? messageForChild;
}

class HistoryPage {
  const HistoryPage({
    required this.transactions,
    required this.periodSummaries,
    required this.completedGoals,
    this.nextCursor,
    this.errorCode,
  });

  final List<TransactionRecord> transactions;
  final List<PeriodSummary> periodSummaries;
  final List<CompletedGoalRecord> completedGoals;
  final String? nextCursor;
  final LogicErrorCode? errorCode;
}

class PreviewResult {
  const PreviewResult({
    required this.allowed,
    required this.warnings,
    required this.messageForChild,
    required this.nextActions,
    this.errorCode,
    this.expectedMoneyDelta,
    this.expectedPetDelta,
    this.stateSnapshot,
  });

  final bool allowed;
  final LogicErrorCode? errorCode;
  final List<WarningMessage> warnings;
  final String messageForChild;
  final MoneyDelta? expectedMoneyDelta;
  final PetDelta? expectedPetDelta;
  final GameState? stateSnapshot;
  final List<NextAction> nextActions;
}

class ActionResult {
  const ActionResult({
    required this.success,
    required this.outcome,
    required this.actionId,
    required this.messageForChild,
    required this.nextActions,
    this.operationAppliedRevision,
    this.errorCode,
    this.stateSnapshot,
    this.moneyDelta,
    this.petDelta,
    this.taskAttempt,
    this.periodSummary,
  });

  final bool success;
  final ActionOutcome outcome;
  final String actionId;
  final int? operationAppliedRevision;
  final LogicErrorCode? errorCode;
  final String messageForChild;
  final GameState? stateSnapshot;
  final MoneyDelta? moneyDelta;
  final PetDelta? petDelta;
  final TaskAttemptResult? taskAttempt;
  final PeriodSummary? periodSummary;
  final List<NextAction> nextActions;
}
