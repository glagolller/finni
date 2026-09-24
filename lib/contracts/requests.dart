import 'constants.dart';
import 'enums.dart';
import 'models/core_models.dart';
import 'models/task_models.dart';

class StateQuery {
  const StateQuery({
    required this.profileId,
    required this.expectedGeneration,
    required this.expectedRevision,
  });

  final String profileId;
  final int expectedGeneration;
  final int expectedRevision;
}

class StateCommand extends StateQuery {
  const StateCommand({
    required super.profileId,
    required super.expectedGeneration,
    required super.expectedRevision,
    required this.actionId,
    this.contractVersion = logicContractVersion,
    this.acceptedWarnings = const {},
  });

  final String contractVersion;
  final String actionId;
  final Set<WarningCode> acceptedWarnings;
}

class CreateProfileCommand {
  const CreateProfileCommand({
    required this.actionId,
    required this.mode,
    required this.petName,
    required this.formId,
    required this.paletteId,
    this.displayName,
    this.contractVersion = logicContractVersion,
  });

  final String contractVersion;
  final String actionId;
  final ProfileMode mode;
  final String? displayName;
  final String petName;
  final String formId;
  final String paletteId;
}

class BudgetQuery extends StateQuery {
  const BudgetQuery({
    required super.profileId,
    required super.expectedGeneration,
    required super.expectedRevision,
    required this.needsLimit,
    required this.wantsLimit,
    required this.savingsTarget,
  });

  final int needsLimit;
  final int wantsLimit;
  final int savingsTarget;
}

class BudgetCommand extends StateCommand {
  const BudgetCommand({
    required super.profileId,
    required super.expectedGeneration,
    required super.expectedRevision,
    required super.actionId,
    required this.needsLimit,
    required this.wantsLimit,
    required this.savingsTarget,
    super.contractVersion,
    super.acceptedWarnings,
  });

  final int needsLimit;
  final int wantsLimit;
  final int savingsTarget;
}

class PurchaseQuery extends StateQuery {
  const PurchaseQuery({
    required super.profileId,
    required super.expectedGeneration,
    required super.expectedRevision,
    required this.itemId,
  });

  final String itemId;
}

class PurchaseCommand extends StateCommand {
  const PurchaseCommand({
    required super.profileId,
    required super.expectedGeneration,
    required super.expectedRevision,
    required super.actionId,
    required this.itemId,
    super.contractVersion,
    super.acceptedWarnings,
  });

  final String itemId;
}

class SavingsTransferQuery extends StateQuery {
  const SavingsTransferQuery({
    required super.profileId,
    required super.expectedGeneration,
    required super.expectedRevision,
    required this.direction,
    required this.amount,
  });

  final TransferDirection direction;
  final int amount;
}

class SavingsTransferCommand extends StateCommand {
  const SavingsTransferCommand({
    required super.profileId,
    required super.expectedGeneration,
    required super.expectedRevision,
    required super.actionId,
    required this.direction,
    required this.amount,
    super.contractVersion,
    super.acceptedWarnings,
  });

  final TransferDirection direction;
  final int amount;
}

class GoalQuery extends StateQuery {
  const GoalQuery({
    required super.profileId,
    required super.expectedGeneration,
    required super.expectedRevision,
    required this.goalId,
  });

  final String goalId;
}

class GoalCommand extends StateCommand {
  const GoalCommand({
    required super.profileId,
    required super.expectedGeneration,
    required super.expectedRevision,
    required super.actionId,
    required this.goalId,
    super.contractVersion,
    super.acceptedWarnings,
  });

  final String goalId;
}

class TaskAnswerCommand extends StateCommand {
  const TaskAnswerCommand({
    required super.profileId,
    required super.expectedGeneration,
    required super.expectedRevision,
    required super.actionId,
    required this.taskId,
    required this.answer,
    super.contractVersion,
  });

  final String taskId;
  final TaskAnswer answer;
}

class PeriodQuery extends StateQuery {
  const PeriodQuery({
    required super.profileId,
    required super.expectedGeneration,
    required super.expectedRevision,
    required this.periodId,
  });

  final String periodId;
}

class PeriodCommand extends StateCommand {
  const PeriodCommand({
    required super.profileId,
    required super.expectedGeneration,
    required super.expectedRevision,
    required super.actionId,
    required this.periodId,
    super.contractVersion,
    super.acceptedWarnings,
  });

  final String periodId;
}

class ConfirmedProfileCommand extends StateCommand {
  const ConfirmedProfileCommand({
    required super.profileId,
    required super.expectedGeneration,
    required super.expectedRevision,
    required super.actionId,
    required this.confirmationText,
    super.contractVersion,
  });

  final String confirmationText;
}

class UpdateSettingsCommand extends StateCommand {
  const UpdateSettingsCommand({
    required super.profileId,
    required super.expectedGeneration,
    required super.expectedRevision,
    required super.actionId,
    required this.settings,
    super.contractVersion,
  });

  final ProfileSettings settings;
}
