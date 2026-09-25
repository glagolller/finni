import 'dart:convert';

import 'package:flutter/services.dart';

import '../../contracts/contracts.dart';

class ItemDefinition {
  const ItemDefinition({
    required this.id,
    required this.title,
    required this.expenseType,
    required this.price,
    required this.visualAssetId,
    required this.effect,
  });

  final String id;
  final String title;
  final ExpenseType expenseType;
  final int price;
  final String visualAssetId;
  final PetEffect effect;
}

class GoalDefinition {
  const GoalDefinition({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.visualAssetId,
  });

  final String id;
  final String title;
  final int targetAmount;
  final String visualAssetId;
}

class PeriodTemplate {
  const PeriodTemplate({
    required this.number,
    required this.availableItemIds,
    required this.requiredItemIds,
  });

  final int number;
  final List<String> availableItemIds;
  final List<String> requiredItemIds;
}

class GameContent {
  GameContent({
    required this.items,
    required this.goals,
    required this.periods,
    required this.tasks,
  });

  final Map<String, ItemDefinition> items;
  final Map<String, GoalDefinition> goals;
  final Map<int, PeriodTemplate> periods;
  final Map<String, TaskDefinition> tasks;

  PeriodTemplate periodFor(int number) {
    final templateNumber = ((number - 1) % periods.length) + 1;
    return periods[templateNumber]!;
  }

  static Future<GameContent> load(AssetBundle bundle) async {
    final values = await Future.wait([
      bundle.loadString('assets/content/items.json'),
      bundle.loadString('assets/content/goals.json'),
      bundle.loadString('assets/content/demo_periods.json'),
      bundle.loadString('assets/content/tasks.json'),
    ]);
    return GameContent(
      items: _parseItems(values[0]),
      goals: _parseGoals(values[1]),
      periods: _parsePeriods(values[2]),
      tasks: _parseTasks(values[3]),
    );
  }

  static Map<String, ItemDefinition> _parseItems(String raw) {
    final rows = (_map(jsonDecode(raw))['items']! as List<Object?>).map(_map);
    return {
      for (final row in rows)
        row['id']! as String: ItemDefinition(
          id: row['id']! as String,
          title: row['title']! as String,
          expenseType: _expenseType(row['expenseType']! as String),
          price: row['price']! as int,
          visualAssetId: row['visualAssetId']! as String,
          effect: PetEffect(
            satietyChange: row['satietyChange']! as int,
            moodChange: row['moodChange']! as int,
            reasonCode: row['reasonCode']! as String,
            explanationForChild: row['title']! as String,
          ),
        ),
    };
  }

  static Map<String, GoalDefinition> _parseGoals(String raw) {
    final rows = (_map(jsonDecode(raw))['goals']! as List<Object?>).map(_map);
    return {
      for (final row in rows)
        row['id']! as String: GoalDefinition(
          id: row['id']! as String,
          title: row['title']! as String,
          targetAmount: row['targetAmount']! as int,
          visualAssetId: row['visualAssetId']! as String,
        ),
    };
  }

  static Map<int, PeriodTemplate> _parsePeriods(String raw) {
    final rows = (_map(jsonDecode(raw))['periods']! as List<Object?>).map(_map);
    return {
      for (final row in rows)
        row['template']! as int: PeriodTemplate(
          number: row['template']! as int,
          availableItemIds: _strings(row['availableItemIds']),
          requiredItemIds: _strings(row['requiredItemIds']),
        ),
    };
  }

  static Map<String, TaskDefinition> _parseTasks(String raw) {
    final rows = (_map(jsonDecode(raw))['tasks']! as List<Object?>).map(_map);
    return {for (final row in rows) row['id']! as String: _task(row)};
  }

  static TaskDefinition _task(JsonMap row) {
    final type = _interaction(row['interactionType']! as String);
    return TaskDefinition(
      id: row['id']! as String,
      title: row['title']! as String,
      theme: _theme(row['theme']! as String),
      interactionType: type,
      prompt: row['prompt']! as String,
      rewardAmount: row['rewardAmount']! as int,
      maxAttemptsPerPeriod: row['maxAttemptsPerPeriod']! as int,
      simulationOnly: row['simulationOnly']! as bool,
      input: _input(type, _map(row['input'])),
      criterion: _criterion(_map(row['criterion'])),
      feedback: TaskFeedback(
        correct: _map(row['feedback'])['correct']! as String,
        needsRetry: _map(row['feedback'])['needsRetry']! as String,
      ),
    );
  }

  static TaskInput _input(TaskInteractionType type, JsonMap row) {
    switch (type) {
      case TaskInteractionType.budgetAllocation:
        return BudgetAllocationInput(
          income: row['income']! as int,
          minimumNeeds: row['minimumNeeds']! as int,
          minimumSavings: row['minimumSavings']! as int,
          allowedCategories: _strings(row['allowedCategories']),
        );
      case TaskInteractionType.planFactChoice:
        final actual = _map(row['actual']);
        return PlanFactChoiceInput(
          plans: (row['plans']! as List<Object?>).map((value) {
            final plan = _map(value);
            return BudgetPlanOption(
              id: plan['id']! as String,
              needs: plan['needs']! as int,
              wants: plan['wants']! as int,
              savings: plan['savings']! as int,
            );
          }).toList(),
          actualNeeds: actual['needs']! as int,
          actualWants: actual['wants']! as int,
          actualSavings: actual['savings']! as int,
        );
      case TaskInteractionType.savingsSchedule:
        return SavingsScheduleInput(
          goalAmount: row['goalAmount']! as int,
          periodCount: row['periodCount']! as int,
          minimumPerPeriod: row['minimumPerPeriod']! as int,
        );
      case TaskInteractionType.savingsComparison:
        return SavingsComparisonInput(
          operations: (row['operations']! as List<Object?>).map((value) {
            final operation = _map(value);
            return SavingsOperation(
              direction: operation['direction'] == 'to_savings'
                  ? TransferDirection.toSavings
                  : TransferDirection.fromSavings,
              amount: operation['amount']! as int,
            );
          }).toList(),
          options: (row['options']! as List<Object?>).map((value) {
            final option = _map(value);
            return ChoiceOption(
              id: option['id']! as String,
              label: option['label']! as String,
            );
          }).toList(),
        );
      case TaskInteractionType.purchaseBasket:
        return PurchaseBasketInput(
          budget: row['budget']! as int,
          maxSelectedItems: row['maxSelectedItems']! as int,
          requiredItemIds: _strings(row['requiredItemIds']),
          items: (row['items']! as List<Object?>).map((value) {
            final item = _map(value);
            return TaskItemOption(
              id: item['id']! as String,
              title: item['title']! as String,
              price: item['price']! as int,
              expenseType: _expenseType(item['expenseType']! as String),
            );
          }).toList(),
        );
      case TaskInteractionType.expenseClassification:
        return ExpenseClassificationInput(
          targetGroups: _strings(row['targetGroups'])
              .map(_expenseType)
              .toList(),
          entries: (row['entries']! as List<Object?>).map((value) {
            final entry = _map(value);
            return ClassificationEntry(
              id: entry['id']! as String,
              label: entry['label']! as String,
            );
          }).toList(),
        );
    }
  }

  static TaskCriterion _criterion(JsonMap row) {
    switch (row['type']) {
      case 'budget_allocation':
        return BudgetAllocationCriterion(
          requiredTotal: row['requiredTotal']! as int,
          minimumNeeds: row['minimumNeeds']! as int,
          minimumSavings: row['minimumSavings']! as int,
        );
      case 'single_choice':
        return SingleChoiceCriterion(
          correctOptionId: row['correctOptionId']! as String,
        );
      case 'savings_schedule':
        return SavingsScheduleCriterion(
          minimumTotal: row['minimumTotal']! as int,
          minimumEachPeriod: row['minimumEachPeriod']! as int,
          requiredPeriodCount: row['requiredPeriodCount']! as int,
        );
      case 'purchase_basket':
        return PurchaseBasketCriterion(
          maximumTotal: row['maximumTotal']! as int,
          maximumItems: row['maximumItems']! as int,
          requiredItemIds: _strings(row['requiredItemIds']),
        );
      case 'expense_classification':
        return ExpenseClassificationCriterion(
          groupByEntryId: _map(
            row['groupByEntryId'],
          ).map((key, value) => MapEntry(key, _expenseType(value! as String))),
        );
      default:
        throw FormatException('Unknown task criterion: ${row['type']}');
    }
  }

  static JsonMap _map(Object? value) => (value! as Map).cast<String, Object?>();
  static List<String> _strings(Object? value) =>
      (value! as List<Object?>).cast<String>();
  static ExpenseType _expenseType(String value) =>
      value == 'need' ? ExpenseType.need : ExpenseType.want;
  static TaskTheme _theme(String value) => switch (value) {
    'budget' => TaskTheme.budget,
    'savings' => TaskTheme.savings,
    _ => TaskTheme.paymentsAndPurchases,
  };
  static TaskInteractionType _interaction(String value) => switch (value) {
    'budget_allocation' => TaskInteractionType.budgetAllocation,
    'plan_fact_choice' => TaskInteractionType.planFactChoice,
    'savings_schedule' => TaskInteractionType.savingsSchedule,
    'savings_comparison' => TaskInteractionType.savingsComparison,
    'purchase_basket' => TaskInteractionType.purchaseBasket,
    'expense_classification' => TaskInteractionType.expenseClassification,
    _ => throw FormatException('Unknown task interaction: $value'),
  };
}
