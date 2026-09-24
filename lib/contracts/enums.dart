enum ProfileMode { normal, demo }

enum PeriodStatus { open, closed, demoCompleted }

enum PetStage { baby, junior, grown }

enum MoodCode { happy, calm, needsAttention }

enum ExpenseType { need, want }

enum GoalStatus { selected, reachable, completed }

enum TaskTheme { budget, savings, paymentsAndPurchases }

enum TaskInteractionType {
  budgetAllocation,
  planFactChoice,
  savingsSchedule,
  savingsComparison,
  purchaseBasket,
  expenseClassification,
}

enum TaskAvailabilityCode {
  available,
  completedReview,
  attemptLimitReached,
  periodClosed,
  demoCompletedReview,
}

enum TaskAttemptOutcome { correct, needsRetry }

enum RewardState { available, granted, alreadyGranted, notEarned }

enum TransferDirection { toSavings, fromSavings }

enum ActionOutcome { applied, replayed, rejected }

enum TransactionType {
  periodIncome,
  taskReward,
  purchase,
  savingsDeposit,
  savingsWithdrawal,
  goalRedemption,
}

enum WarningCode {
  needsUnderfunded,
  budgetExceeded,
  savingsWithdrawal,
  goalChange,
  goalRedemption,
  mandatoryNeedsUnmet,
}

enum LogicErrorCode {
  profileNotFound,
  profileAlreadyExists,
  invalidProfileMode,
  invalidPetName,
  invalidPetForm,
  invalidPetPalette,
  invalidAmount,
  invalidBudget,
  invalidTaskAnswer,
  planRequired,
  planAlreadyConfirmed,
  insufficientFunds,
  purchaseLimitReached,
  itemNotFound,
  itemUnavailable,
  itemAlreadyPurchasedThisPeriod,
  goalNotFound,
  goalNotReachable,
  taskNotFound,
  attemptLimitReached,
  periodClosed,
  periodNotFinished,
  demoComplete,
  staleState,
  staleGeneration,
  actionConflict,
  confirmationRequired,
  contractVersionMismatch,
  contentVersionMismatch,
  storageError,
}

enum NextActionCode {
  openProfile,
  openHome,
  openBudget,
  openCatalog,
  openSavings,
  openGoals,
  openTasks,
  openTask,
  retryTask,
  continuePeriod,
  previewFinishPeriod,
  finishPeriod,
  startNextPeriod,
  repeatPreview,
  retrySameAction,
  resetDemo,
  closeDialog,
  openAdultSection,
}
