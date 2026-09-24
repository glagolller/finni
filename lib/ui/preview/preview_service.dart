import '../../contracts/contracts.dart';
import 'fixture_states.dart';

/// A fixed scenario adapter for UI review. Never use as the release service.
class PreviewService implements LogicService {
  PreviewService({GameState? snapshot})
    : snapshot = snapshot ?? openPeriodFixture();
  final GameState snapshot;

  @override
  Future<BootstrapConfig> getBootstrapConfig() async => BootstrapConfig(
    contractVersion: logicContractVersion,
    contentVersion: contentVersion,
    petForms: petFormLabels.entries
        .map((e) => PetAppearanceOption(id: e.key, label: e.value))
        .toList(),
    petPalettes: petPaletteLabels.entries
        .map((e) => PetAppearanceOption(id: e.key, label: e.value))
        .toList(),
  );

  @override
  Future<ListProfilesResult> listProfiles() async => ListProfilesResult(
    profiles: [
      ProfileSummary(
        id: snapshot.profile.id,
        mode: snapshot.profile.mode,
        petName: snapshot.profile.petName,
        generation: snapshot.profile.generation,
        updatedAt: snapshot.profile.updatedAt,
      ),
    ],
  );

  @override
  Future<LoadStateResult> loadState(String profileId) async => LoadStateResult(
    found: profileId == snapshot.profile.id,
    stateSnapshot: profileId == snapshot.profile.id ? snapshot : null,
  );

  @override
  Future<CatalogResult<ItemSummary>> getItemCatalog(
    String profileId,
  ) async => CatalogResult(
    stateRevision: snapshot.stateRevision,
    profileGeneration: snapshot.profile.generation,
    items: [
      for (final row in const [
        ('food', 'Полезная еда', 30, ExpenseType.need, 15, 2),
        ('hygiene', 'Набор для ухода', 20, ExpenseType.need, 0, 6),
        ('ball', 'Мяч', 35, ExpenseType.want, 0, 8),
        ('music_player', 'Музыкальная игрушка', 70, ExpenseType.want, 0, 12),
      ])
        ItemSummary(
          id: 'item.${row.$1}',
          title: row.$2,
          price: row.$3,
          expenseType: row.$4,
          visualAssetId: 'item.${row.$1}',
          availableThisPeriod: true,
          purchasedThisPeriod: snapshot.currentPeriod.purchasedItemIds.contains(
            'item.${row.$1}',
          ),
          petEffect: PetEffect(
            satietyChange: row.$5,
            moodChange: row.$6,
            reasonCode: 'purchase_${row.$1}',
            explanationForChild: 'Сытость +${row.$5}, настроение +${row.$6}',
          ),
        ),
    ],
  );

  @override
  Future<CatalogResult<GoalSummary>> getGoalCatalog(String profileId) async =>
      CatalogResult(
        stateRevision: snapshot.stateRevision,
        profileGeneration: snapshot.profile.generation,
        items: const [
          GoalSummary(
            id: 'goal.playground',
            title: 'Игровая площадка',
            targetAmount: 120,
            visualAssetId: 'goal.playground',
            selected: true,
            reachable: false,
          ),
          GoalSummary(
            id: 'goal.bicycle',
            title: 'Велосипедная прогулка',
            targetAmount: 180,
            visualAssetId: 'goal.bicycle',
            selected: false,
            reachable: false,
          ),
          GoalSummary(
            id: 'goal.telescope',
            title: 'Домашний телескоп',
            targetAmount: 240,
            visualAssetId: 'goal.telescope',
            selected: false,
            reachable: false,
          ),
        ],
      );

  PreviewResult _notConnected() => PreviewResult(
    allowed: false,
    warnings: const [],
    messageForChild: 'Это просмотр интерфейса. Расчёт этого действия появится после подключения игрового сервиса.',
    stateSnapshot: snapshot,
    nextActions: const [],
  );

  @override
  Future<PreviewResult> previewPurchase(PurchaseQuery query) async {
    // One exact, documented test case. Other inputs are not simulated.
    if (query.itemId == 'item.music_player' &&
        snapshot.stateRevision == 9 &&
        snapshot.availableBalance == 30) {
      return PreviewResult(
        allowed: false,
        errorCode: LogicErrorCode.insufficientFunds,
        warnings: const [],
        messageForChild:
            'Не хватает 40 монет. Можно выбрать другой предмет или накопить.',
        stateSnapshot: snapshot,
        nextActions: const [NextAction(code: NextActionCode.openCatalog)],
      );
    }
    return _notConnected();
  }

  @override
  Future<PreviewResult> previewBudget(BudgetQuery query) async =>
      _notConnected();
  @override
  Future<PreviewResult> previewSavingsTransfer(
    SavingsTransferQuery query,
  ) async => _notConnected();
  @override
  Future<PreviewResult> previewGoalChange(GoalQuery query) async =>
      _notConnected();

  // Unsupported operations fail explicitly rather than pretending to save.
  // Future<Never> also satisfies the unused read methods during preview.
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<Never>.error(
    UnsupportedError('Preview adapter: ${invocation.memberName}'),
  );
}
