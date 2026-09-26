import 'package:flutter/material.dart';

import '../contracts/contracts.dart';
import 'resource_art.dart';

enum GuideDestination { budget, shop, savings, tasks, period, history }

class GuideAdvice {
  const GuideAdvice(this.message, this.button, this.destination);
  final String message, button;
  final GuideDestination destination;
}

GuideAdvice nextAdvice(GameState s, List<ItemSummary> items) {
  final p = s.currentPeriod;
  if (p.status == PeriodStatus.demoCompleted) {
    return const GuideAdvice(
      'Вы прошли всё демо! Посмотри, чему научился Финни.',
      'Посмотреть достижения',
      GuideDestination.history,
    );
  }
  if (p.status == PeriodStatus.closed) {
    return const GuideAdvice(
      'Этот период завершён. Посмотрим итог и начнём новый?',
      'К итогу периода',
      GuideDestination.period,
    );
  }
  final tasks = s.taskHub.tasks.any(
    (t) => !t.completed && t.availability == TaskAvailabilityCode.available,
  );
  if (p.budgetPlan == null) {
    return const GuideAdvice(
      'Реши, сколько потратить и сколько отложить. План ничего не списывает.',
      'Составить план',
      GuideDestination.budget,
    );
  }
  final missing = p.requiredPurchases
      .where((r) => !r.fulfilled)
      .map((r) => r.itemId)
      .toSet();
  if (missing.isNotEmpty) {
    final possible = items.any(
      (i) =>
          missing.contains(i.id) &&
          i.availableThisPeriod &&
          !i.purchasedThisPeriod &&
          i.price <= s.availableBalance,
    );
    if (possible && p.purchaseSlotsUsed < p.purchaseSlotsTotal) {
      return const GuideAdvice(
        'Выбери нужное для Финни. Цену увидишь до покупки.',
        'Выбрать нужное',
        GuideDestination.shop,
      );
    }
    if (p.purchaseSlotsUsed >= p.purchaseSlotsTotal) {
      return const GuideAdvice(
        'Лимит покупок исчерпан. Посмотри итог — в новом периоде попробуем другой план.',
        'Посмотреть итог',
        GuideDestination.period,
      );
    }
    if (tasks) {
      return const GuideAdvice(
        'На нужное пока не хватает. За выполненное задание можно получить награду.',
        'Попробовать задание',
        GuideDestination.tasks,
      );
    }
    if (s.savingsBalance > 0) {
      return const GuideAdvice(
        'На нужное не хватает. Можно обдумать снятие из копилки — до подтверждения ничего не изменится.',
        'Посмотреть копилку',
        GuideDestination.savings,
      );
    }
    return const GuideAdvice(
      'Сейчас средств на нужное не хватает. Можно завершить период и попробовать снова.',
      'Посмотреть итог',
      GuideDestination.period,
    );
  }
  if (s.activeGoal?.status == GoalStatus.reachable) {
    return const GuideAdvice(
      'На мечту уже накоплено! Её можно получить в копилке.',
      'Получить мечту',
      GuideDestination.savings,
    );
  }
  if (tasks && p.actual.taskRewards == 0) {
    return const GuideAdvice(
      'Поиграем и узнаем что-нибудь новое? За верный ответ есть награда.',
      'Выбрать задание',
      GuideDestination.tasks,
    );
  }
  final target = p.budgetPlan!.savingsTarget;
  if (p.actual.qualifyingSavings < target) {
    if (s.availableBalance > 0) {
      return const GuideAdvice(
        'Нужное куплено. Теперь можно отложить часть на мечту.',
        'Открыть копилку',
        GuideDestination.savings,
      );
    }
    if (tasks) {
      return const GuideAdvice(
        'Чтобы пополнить копилку, попробуй задание с наградой.',
        'Выбрать задание',
        GuideDestination.tasks,
      );
    }
    return const GuideAdvice(
      'Сейчас откладывать нечего. Посмотрим, что получилось за период.',
      'Посмотреть итог',
      GuideDestination.period,
    );
  }
  return const GuideAdvice(
    'Можно подвести итог! Или ещё поиграть — порядок выбираешь ты.',
    'Подвести итог',
    GuideDestination.period,
  );
}

class HomeGuidance extends StatefulWidget {
  const HomeGuidance({
    super.key,
    required this.state,
    required this.service,
    required this.blocked,
    required this.onNavigate,
  });
  final GameState state;
  final LogicService service;
  final bool blocked;
  final void Function(GuideDestination) onNavigate;
  @override
  State<HomeGuidance> createState() => _HomeGuidanceState();
}

class _HomeGuidanceState extends State<HomeGuidance> {
  late Future<CatalogResult<ItemSummary>> catalog;
  void load() {
    catalog = widget.service.getItemCatalog(widget.state.profile.id);
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant HomeGuidance old) {
    super.didUpdateWidget(old);
    if (old.state.profile.id != widget.state.profile.id ||
        old.state.profile.generation != widget.state.profile.generation ||
        old.state.stateRevision != widget.state.stateRevision) {
      load();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<CatalogResult<ItemSummary>>(
    future: catalog,
    builder: (context, snapshot) {
      final s = widget.state;
      final p = s.currentPeriod;
      final ready =
          snapshot.connectionState == ConnectionState.done &&
          snapshot.hasData &&
          snapshot.data!.errorCode == null;
      final advice = ready ? nextAdvice(s, snapshot.data!.items) : null;
      final planned = p.budgetPlan != null;
      final needed = p.requiredPurchases.every((r) => r.fulfilled);
      final saved =
          planned && p.actual.qualifyingSavings >= p.budgetPlan!.savingsTarget;
      return Card(
        color: const Color(0xffe9defb),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Сейчас попробуй',
                style: TextStyle(fontFamily: 'Pangolin', fontSize: 24),
              ),
              if (advice != null) ...[
                ResourceText(advice.message),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: widget.blocked
                      ? null
                      : () => widget.onNavigate(advice.destination),
                  child: Text(advice.button),
                ),
              ] else if (snapshot.connectionState != ConnectionState.done)
                const Text('Подбираем подсказку…')
              else ...[
                const Text(
                  'Подсказку не удалось загрузить. Можно играть через меню.',
                ),
                TextButton(
                  onPressed: widget.blocked ? null : () => setState(load),
                  child: const Text('Повторить подсказку'),
                ),
              ],
              const SizedBox(height: 8),
              const Text('Дела периода · порядок выбираешь ты'),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  for (final entry in [
                    ('План', planned),
                    ('Нужное', needed),
                    ('Копилка', saved),
                    ('Итог', p.status != PeriodStatus.open),
                  ])
                    Semantics(
                      label:
                          '${entry.$1}: ${entry.$2 ? 'готово' : 'ещё можно сделать'}',
                      child: ExcludeSemantics(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              entry.$2
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 18,
                              color: entry.$2
                                  ? const Color(0xff36734f)
                                  : const Color(0xff6851a5),
                            ),
                            const SizedBox(width: 4),
                            Text(entry.$1),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                s.taskHub.tasks.every((t) => t.completed)
                    ? 'Все задания уже выполнены!'
                    : p.actual.taskRewards > 0
                    ? 'Награда за задание получена'
                    : 'Задания — по желанию',
              ),
            ],
          ),
        ),
      );
    },
  );
}
