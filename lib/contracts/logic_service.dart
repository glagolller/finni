import 'models/core_models.dart';
import 'models/result_models.dart';
import 'models/task_models.dart';
import 'requests.dart';

abstract interface class LogicService {
  Future<BootstrapConfig> getBootstrapConfig();

  Future<ListProfilesResult> listProfiles();

  Future<LoadStateResult> loadState(String profileId);

  Future<CatalogResult<ItemSummary>> getItemCatalog(String profileId);

  Future<CatalogResult<GoalSummary>> getGoalCatalog(String profileId);

  Future<CatalogResult<TaskSummary>> getTaskCatalog(String profileId);

  Future<TaskDefinitionResult> getTaskDefinition(
    String profileId,
    String taskId,
  );

  Future<HistoryPage> getHistory(
    String profileId, {
    String? cursor,
    int limit = 50,
  });

  Future<ProgressResult> getProgress(String profileId);

  Future<ActionResult> createProfile(CreateProfileCommand command);
  Future<PreviewResult> previewBudget(BudgetQuery query);
  Future<ActionResult> confirmBudget(BudgetCommand command);
  Future<PreviewResult> previewPurchase(PurchaseQuery query);
  Future<ActionResult> buyItem(PurchaseCommand command);
  Future<PreviewResult> previewSavingsTransfer(SavingsTransferQuery query);
  Future<ActionResult> transferSavings(SavingsTransferCommand command);
  Future<PreviewResult> previewGoalChange(GoalQuery query);
  Future<ActionResult> changeGoal(GoalCommand command);
  Future<PreviewResult> previewGoalRedemption(GoalQuery query);
  Future<ActionResult> redeemGoal(GoalCommand command);
  Future<ActionResult> submitTaskAnswer(TaskAnswerCommand command);
  Future<PreviewResult> previewFinishPeriod(PeriodQuery query);
  Future<ActionResult> finishPeriod(PeriodCommand command);
  Future<ActionResult> startNextPeriod(PeriodCommand command);
  Future<ActionResult> resetDemoProfile(ConfirmedProfileCommand command);
  Future<ActionResult> deleteProfile(ConfirmedProfileCommand command);
  Future<ActionResult> updateSettings(UpdateSettingsCommand command);
}
