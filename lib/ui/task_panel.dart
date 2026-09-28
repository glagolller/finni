import 'resource_art.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../contracts/contracts.dart';

class TaskDraft {
  final values = <String, String>{};
  String? choice;
  final selected = <String>{};
  final groups = <String, ExpenseType>{};
}

/// Collects typed answers; the service alone checks correctness and rewards.
class TaskPanel extends StatefulWidget {
  const TaskPanel({
    super.key,
    required this.definition,
    required this.draft,
    required this.status,
    required this.blocked,
    required this.onSubmit,
  });
  final TaskDefinition definition;
  final TaskDraft draft;
  final TaskSummary status;
  final bool blocked;
  final Future<void> Function(TaskAnswer) onSubmit;
  @override
  State<TaskPanel> createState() => _TaskPanelState();
}

class _TaskPanelState extends State<TaskPanel> {
  final fields = <String, TextEditingController>{};
  String? get choice => widget.draft.choice;
  set choice(String? value) => widget.draft.choice = value;
  Set<String> get selected => widget.draft.selected;
  Map<String, ExpenseType> get groups => widget.draft.groups;
  String? error;
  @override
  void dispose() {
    for (final entry in fields.entries) {
      widget.draft.values[entry.key] = entry.value.text;
      entry.value.dispose();
    }
    super.dispose();
  }

  bool get editable =>
      !widget.blocked &&
      widget.status.availability == TaskAvailabilityCode.available;
  Widget number(String id, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextField(
      key: ValueKey('task-$id'),
      controller: fields.putIfAbsent(
        id,
        () => TextEditingController(text: widget.draft.values[id] ?? ''),
      ),
      enabled: editable,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(9),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
  Widget option(String id, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: ChoiceChip(
      key: ValueKey('option-$id'),
      label: ResourceText(label),
      selected: choice == id,
      onSelected: editable ? (_) => setState(() => choice = id) : null,
    ),
  );
  int value(String id) {
    final n = int.tryParse(fields[id]?.text ?? '');
    if (n == null) {
      throw const FormatException('Заполни все суммы целыми числами.');
    }
    return n;
  }

  TaskAnswer answer() => switch (widget.definition.input) {
    BudgetAllocationInput() => BudgetAllocationAnswer(
      needs: value('needs'),
      wants: value('wants'),
      savings: value('savings'),
    ),
    PlanFactChoiceInput() => PlanFactChoiceAnswer(
      selectedOptionId: requireChoice(),
    ),
    SavingsScheduleInput(:final periodCount) => SavingsScheduleAnswer(
      amountsByPeriod: List.generate(periodCount, (i) => value('period-$i')),
    ),
    SavingsComparisonInput() => SavingsComparisonAnswer(
      selectedOptionId: requireChoice(),
    ),
    PurchaseBasketInput() => PurchaseBasketAnswer(
      selectedItemIds: selected.toList(),
    ),
    ExpenseClassificationInput(:final entries) => ExpenseClassificationAnswer(
      groupByEntryId: {
        for (final e in entries)
          e.id:
              groups[e.id] ??
              (throw const FormatException(
                'Выбери группу для каждого предмета.',
              )),
      },
    ),
  };
  String requireChoice() =>
      choice ?? (throw const FormatException('Выбери один вариант.'));
  @override
  Widget build(BuildContext context) {
    final input = widget.definition.input;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResourceText(
          widget.definition.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        ResourceText(widget.definition.prompt),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: ResourceText('Учебная игра: покупки и копилка не меняются.'),
        ),
        ResourceText(
          widget.status.completed
              ? 'Выполнено. Награда уже получена.'
              : 'Награда: ${widget.definition.rewardAmount} монет · попыток осталось: ${widget.status.remainingAttempts}',
        ),
        if (widget.status.availability != TaskAvailabilityCode.available)
          ResourceText(
            widget.status.unavailableReason ??
                'Можно посмотреть задание. Новые ответы сейчас недоступны.',
          ),
        ...switch (input) {
          BudgetAllocationInput(
            :final income,
            :final minimumNeeds,
            :final minimumSavings,
          ) =>
            [
              ResourceText(
                'Всего $income. На нужное — хотя бы $minimumNeeds, в копилку — $minimumSavings.',
              ),
              number('needs', 'Нужное'),
              number('wants', 'Желания'),
              number('savings', 'В копилку'),
            ],
          PlanFactChoiceInput(
            :final plans,
            :final actualNeeds,
            :final actualWants,
            :final actualSavings,
          ) =>
            [
              ResourceText(
                'Факт: нужное $actualNeeds · желания $actualWants · копилка $actualSavings',
              ),
              for (var i = 0; i < plans.length; i++)
                option(
                  plans[i].id,
                  'План ${i + 1}: ${plans[i].needs} / ${plans[i].wants} / ${plans[i].savings}',
                ),
            ],
          SavingsScheduleInput(:final periodCount, :final minimumPerPeriod) => [
            ResourceText('В каждом шаге — хотя бы $minimumPerPeriod монет.'),
            for (var i = 0; i < periodCount; i++)
              number('period-$i', 'Шаг ${i + 1}'),
          ],
          SavingsComparisonInput(:final operations, :final options) => [
            for (final op in operations)
              ResourceText(
                '${op.direction == TransferDirection.toSavings ? 'Положили' : 'Взяли'} ${op.amount} монет',
              ),
            for (final opt in options) option(opt.id, opt.label),
          ],
          PurchaseBasketInput(
            :final items,
            :final maxSelectedItems,
            :final budget,
          ) =>
            [
              ResourceText('До $maxSelectedItems предметов · $budget монет'),
              for (final item in items)
                CheckboxListTile(
                  key: ValueKey('basket-${item.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: ResourceText('${item.title} · ${item.price}'),
                  value: selected.contains(item.id),
                  onChanged: editable
                      ? (v) => setState(() {
                          if (v == true) {
                            selected.add(item.id);
                          } else {
                            selected.remove(item.id);
                          }
                        })
                      : null,
                ),
            ],
          ExpenseClassificationInput(:final entries, :final targetGroups) => [
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResourceText(entry.label),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final group in targetGroups)
                          ChoiceChip(
                            key: ValueKey('group-${entry.id}-${group.name}'),
                            label: ResourceText(
                              group == ExpenseType.need ? 'Нужное' : 'Желание',
                            ),
                            selected: groups[entry.id] == group,
                            onSelected: editable
                                ? (_) =>
                                      setState(() => groups[entry.id] = group)
                                : null,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        },
        if (error != null)
          ResourceText(error!, semanticsLabel: 'Ошибка: $error'),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('submit-task'),
          onPressed: editable
              ? () async {
                  TaskAnswer input;
                  try {
                    input = answer();
                  } on FormatException catch (e) {
                    setState(() => error = e.message);
                    return;
                  }
                  setState(() => error = null);
                  await widget.onSubmit(input);
                }
              : null,
          child: const ResourceText('Проверить ответ'),
        ),
      ],
    );
  }
}
