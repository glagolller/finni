import 'package:flutter_test/flutter_test.dart';
import 'package:finni/contracts/contracts.dart';
import 'package:finni/ui/home_guidance.dart';
import 'package:finni/ui/preview/fixture_states.dart';

GameState scenario({
  int money = 0,
  int saved = 0,
  bool tasks = true,
  bool plan = true,
  bool needs = false,
  int slots = 0,
  PeriodStatus status = PeriodStatus.open,
}) {
  final s = newDemoFixture(), p = newDemoFixture().currentPeriod;
  return GameState(
    contractVersion: s.contractVersion,
    contentVersion: s.contentVersion,
    stateRevision: s.stateRevision,
    profile: s.profile,
    currentPeriod: PeriodState(
      id: p.id,
      number: p.number,
      status: status,
      incomeCredited: p.incomeCredited,
      incomeCreditedAt: p.incomeCreditedAt,
      availableItemIds: p.availableItemIds,
      requiredPurchases: [
        RequiredPurchase(itemId: 'item.food', quantity: 1, fulfilled: needs),
      ],
      purchaseSlotsTotal: 3,
      purchaseSlotsUsed: slots,
      purchasedItemIds: [],
      actual: p.actual,
      startedAt: p.startedAt,
      budgetPlan: plan
          ? BudgetPlan(
              periodId: p.id,
              needsLimit: 50,
              wantsLimit: 20,
              savingsTarget: 30,
              unallocatedAmount: 0,
              requiredNeedsCostAtConfirmation: 50,
              confirmedAt: p.startedAt,
            )
          : null,
    ),
    availableBalance: money,
    savingsBalance: saved,
    pet: s.pet,
    taskHub: tasks ? s.taskHub : const TaskHub(tasks: []),
    learningProgress: s.learningProgress,
    settings: s.settings,
    activeGoal: s.activeGoal,
  );
}

void main() {
  test('new period points to a plan without mutating state', () {
    final s = scenario(plan: false, money: 100);
    expect(nextAdvice(s, []).destination, GuideDestination.budget);
    expect(s.currentPeriod.budgetPlan, isNull);
    expect(s.availableBalance, 100);
  });
  test('shortfall offers only an available task', () {
    expect(nextAdvice(scenario(), []).destination, GuideDestination.tasks);
  });
  test('shortfall without tasks may review savings', () {
    expect(
      nextAdvice(scenario(tasks: false, saved: 10), []).destination,
      GuideDestination.savings,
    );
  });
  test('no funds or tasks never promises a reward', () {
    expect(
      nextAdvice(scenario(tasks: false), []).destination,
      GuideDestination.period,
    );
  });
  test('purchase limit never sends child back to buy', () {
    expect(
      nextAdvice(scenario(slots: 3), []).destination,
      GuideDestination.period,
    );
  });
  test('closed period leads to summary', () {
    expect(
      nextAdvice(scenario(status: PeriodStatus.closed), []).destination,
      GuideDestination.period,
    );
  });
  test('completed demo leads to history not more income', () {
    expect(
      nextAdvice(scenario(status: PeriodStatus.demoCompleted), []).destination,
      GuideDestination.history,
    );
  });
  test('needs bought and remaining funds can be saved', () {
    expect(
      nextAdvice(
        scenario(needs: true, tasks: false, money: 30),
        [],
      ).destination,
      GuideDestination.savings,
    );
  });
}
