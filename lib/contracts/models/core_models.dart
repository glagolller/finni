import '../enums.dart';
import 'task_models.dart';

typedef JsonMap = Map<String, Object?>;

class PetAppearanceOption {
  const PetAppearanceOption({required this.id, required this.label});

  final String id;
  final String label;
}

class BootstrapConfig {
  const BootstrapConfig({
    required this.contractVersion,
    required this.contentVersion,
    required this.petForms,
    required this.petPalettes,
  });

  final String contractVersion;
  final String contentVersion;
  final List<PetAppearanceOption> petForms;
  final List<PetAppearanceOption> petPalettes;
}

class ProfileSummary {
  const ProfileSummary({
    required this.id,
    required this.mode,
    required this.petName,
    required this.generation,
    required this.updatedAt,
    this.displayName,
  });

  final String id;
  final ProfileMode mode;
  final String? displayName;
  final String petName;
  final int generation;
  final DateTime updatedAt;
}

class Profile {
  const Profile({
    required this.id,
    required this.mode,
    required this.petName,
    required this.generation,
    required this.createdAt,
    required this.updatedAt,
    this.displayName,
  });

  final String id;
  final ProfileMode mode;
  final String? displayName;
  final String petName;
  final int generation;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ProfileSettings {
  const ProfileSettings({
    required this.soundEnabled,
    required this.reducedMotion,
    required this.largeTextPreferred,
  });

  final bool soundEnabled;
  final bool reducedMotion;
  final bool largeTextPreferred;
}

class BudgetPlan {
  const BudgetPlan({
    required this.periodId,
    required this.needsLimit,
    required this.wantsLimit,
    required this.savingsTarget,
    required this.unallocatedAmount,
    required this.requiredNeedsCostAtConfirmation,
    required this.confirmedAt,
  });

  final String periodId;
  final int needsLimit;
  final int wantsLimit;
  final int savingsTarget;
  final int unallocatedAmount;
  final int requiredNeedsCostAtConfirmation;
  final DateTime confirmedAt;
}

class BudgetActual {
  const BudgetActual({
    required this.periodIncome,
    required this.taskRewards,
    required this.needsSpent,
    required this.wantsSpent,
    required this.savingsDeposited,
    required this.ordinarySavingsWithdrawn,
    required this.goalRedemptionSpent,
    required this.qualifyingSavings,
    required this.savingsMoodBonusGranted,
    required this.requiredNeedsMet,
    required this.planKept,
    required this.savingsHabitKept,
  });

  final int periodIncome;
  final int taskRewards;
  final int needsSpent;
  final int wantsSpent;
  final int savingsDeposited;
  final int ordinarySavingsWithdrawn;
  final int goalRedemptionSpent;
  final int qualifyingSavings;
  final bool savingsMoodBonusGranted;
  final bool requiredNeedsMet;
  final bool planKept;
  final bool savingsHabitKept;
}

class RequiredPurchase {
  const RequiredPurchase({
    required this.itemId,
    required this.quantity,
    required this.fulfilled,
  });

  final String itemId;
  final int quantity;
  final bool fulfilled;
}

class PeriodState {
  const PeriodState({
    required this.id,
    required this.number,
    required this.status,
    required this.incomeCredited,
    required this.incomeCreditedAt,
    required this.availableItemIds,
    required this.requiredPurchases,
    required this.purchaseSlotsTotal,
    required this.purchaseSlotsUsed,
    required this.purchasedItemIds,
    required this.actual,
    required this.startedAt,
    this.budgetPlan,
    this.closedAt,
  });

  final String id;
  final int number;
  final PeriodStatus status;
  final int incomeCredited;
  final DateTime incomeCreditedAt;
  final List<String> availableItemIds;
  final List<RequiredPurchase> requiredPurchases;
  final int purchaseSlotsTotal;
  final int purchaseSlotsUsed;
  final List<String> purchasedItemIds;
  final BudgetPlan? budgetPlan;
  final BudgetActual actual;
  final DateTime startedAt;
  final DateTime? closedAt;
}

class PetEffect {
  const PetEffect({
    required this.satietyChange,
    required this.moodChange,
    required this.reasonCode,
    required this.explanationForChild,
  });

  final int satietyChange;
  final int moodChange;
  final String reasonCode;
  final String explanationForChild;
}

class PetState {
  const PetState({
    required this.name,
    required this.formId,
    required this.paletteId,
    required this.satiety,
    required this.mood,
    required this.moodCode,
    required this.stage,
    this.lastReasonCode,
    this.explanationForChild,
  });

  final String name;
  final String formId;
  final String paletteId;
  final int satiety;
  final int mood;
  final MoodCode moodCode;
  final PetStage stage;
  final String? lastReasonCode;
  final String? explanationForChild;
}

class PetDelta {
  const PetDelta({
    required this.satietyBefore,
    required this.satietyAfter,
    required this.moodBefore,
    required this.moodAfter,
    required this.moodCodeBefore,
    required this.moodCodeAfter,
    required this.stageBefore,
    required this.stageAfter,
    required this.reasonCode,
    required this.explanationForChild,
  });

  final int satietyBefore;
  final int satietyAfter;
  final int moodBefore;
  final int moodAfter;
  final MoodCode moodCodeBefore;
  final MoodCode moodCodeAfter;
  final PetStage stageBefore;
  final PetStage stageAfter;
  final String reasonCode;
  final String explanationForChild;
}

class ItemSummary {
  const ItemSummary({
    required this.id,
    required this.title,
    required this.expenseType,
    required this.price,
    required this.visualAssetId,
    required this.availableThisPeriod,
    required this.purchasedThisPeriod,
    required this.petEffect,
    this.availabilityReason,
  });

  final String id;
  final String title;
  final ExpenseType expenseType;
  final int price;
  final String visualAssetId;
  final bool availableThisPeriod;
  final bool purchasedThisPeriod;
  final String? availabilityReason;
  final PetEffect petEffect;
}

class GoalSummary {
  const GoalSummary({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.visualAssetId,
    required this.selected,
    required this.reachable,
  });

  final String id;
  final String title;
  final int targetAmount;
  final String visualAssetId;
  final bool selected;
  final bool reachable;
}

class GoalProgress {
  const GoalProgress({
    required this.goalId,
    required this.title,
    required this.targetAmount,
    required this.savedAmount,
    required this.remainingAmount,
    required this.status,
    required this.selectedAt,
    this.completedAt,
  });

  final String goalId;
  final String title;
  final int targetAmount;
  final int savedAmount;
  final int remainingAmount;
  final GoalStatus status;
  final DateTime selectedAt;
  final DateTime? completedAt;
}

class CompletedGoalRecord {
  const CompletedGoalRecord({
    required this.goalId,
    required this.title,
    required this.amountSpent,
    required this.completedAt,
    required this.transactionId,
  });

  final String goalId;
  final String title;
  final int amountSpent;
  final DateTime completedAt;
  final String transactionId;
}

class StageHistoryEntry {
  const StageHistoryEntry({
    required this.stage,
    required this.reachedAfterPeriod,
    required this.qualityPoints,
    required this.reachedAt,
  });

  final PetStage stage;
  final int reachedAfterPeriod;
  final int qualityPoints;
  final DateTime reachedAt;
}

class LearningProgress {
  const LearningProgress({
    required this.completedPeriods,
    required this.qualityPoints,
    required this.taskProgress,
    required this.stageHistory,
  });

  final int completedPeriods;
  final int qualityPoints;
  final List<TaskProgress> taskProgress;
  final List<StageHistoryEntry> stageHistory;
}

class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.profileId,
    required this.profileGeneration,
    required this.periodId,
    required this.type,
    required this.amount,
    required this.availableChange,
    required this.savingsChange,
    required this.contentVersion,
    required this.actionId,
    required this.createdAt,
    this.relatedEntityId,
    this.unitPrice,
  });

  final String id;
  final String profileId;
  final int profileGeneration;
  final String periodId;
  final TransactionType type;
  final int amount;
  final int availableChange;
  final int savingsChange;
  final String? relatedEntityId;
  final int? unitPrice;
  final String contentVersion;
  final String actionId;
  final DateTime createdAt;
}

class PeriodSummary {
  const PeriodSummary({
    required this.periodId,
    required this.number,
    required this.plan,
    required this.actual,
    required this.qualityPointsGranted,
    required this.qualityPointsTotal,
    required this.stageBefore,
    required this.stageAfter,
    required this.satietyAfter,
    required this.moodAfter,
    required this.explanationForChild,
    required this.closedAt,
  });

  final String periodId;
  final int number;
  final BudgetPlan plan;
  final BudgetActual actual;
  final int qualityPointsGranted;
  final int qualityPointsTotal;
  final PetStage stageBefore;
  final PetStage stageAfter;
  final int satietyAfter;
  final int moodAfter;
  final String explanationForChild;
  final DateTime closedAt;
}

class GameState {
  const GameState({
    required this.contractVersion,
    required this.contentVersion,
    required this.stateRevision,
    required this.profile,
    required this.currentPeriod,
    required this.availableBalance,
    required this.savingsBalance,
    required this.pet,
    required this.taskHub,
    required this.learningProgress,
    required this.settings,
    this.activeGoal,
  });

  final String contractVersion;
  final String contentVersion;
  final int stateRevision;
  final Profile profile;
  final PeriodState currentPeriod;
  final int availableBalance;
  final int savingsBalance;
  final GoalProgress? activeGoal;
  final PetState pet;
  final TaskHub taskHub;
  final LearningProgress learningProgress;
  final ProfileSettings settings;
}
