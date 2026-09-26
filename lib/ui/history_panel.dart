import 'resource_art.dart';

import 'package:flutter/material.dart';

import '../contracts/contracts.dart';

Widget periodSummaryCard(PeriodSummary summary) => Card(
  child: Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResourceText(
          'Итог периода ${summary.number}',
          style: const TextStyle(fontFamily: 'Pangolin', fontSize: 24),
        ),
        ResourceText('Отложено ${summary.actual.qualifyingSavings} монет'),
        ResourceText(
          'Баллы заботы: +${summary.qualityPointsGranted} · всего ${summary.qualityPointsTotal}',
        ),
        ResourceText(
          'Сытость ${summary.satietyAfter}/100 · настроение ${summary.moodAfter}/100',
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const ResourceText('Почему так получилось?'),
          children: [
            ResourceText(summary.explanationForChild),
            planFactCard(summary.plan, summary.actual),
          ],
        ),
      ],
    ),
  ),
);

class HistoryPanel extends StatefulWidget {
  const HistoryPanel({
    super.key,
    required this.service,
    required this.profileId,
  });
  final LogicService service;
  final String profileId;
  @override
  State<HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends State<HistoryPanel> {
  final transactions = <String, TransactionRecord>{};
  final periods = <String, PeriodSummary>{};
  final goals = <String, CompletedGoalRecord>{};
  bool loading = false, failed = false, loaded = false;
  String? cursor;
  final titles = <String, String>{};
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (loading) {
      return;
    }
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      if (!loaded) {
        final items = await widget.service.getItemCatalog(widget.profileId);
        final tasks = await widget.service.getTaskCatalog(widget.profileId);
        final catalog = await widget.service.getGoalCatalog(widget.profileId);
        for (final item in items.items) {
          titles[item.id] = item.title;
        }
        for (final task in tasks.items) {
          titles[task.id] = task.title;
        }
        for (final goal in catalog.items) {
          titles[goal.id] = goal.title;
        }
      }
      final result = await widget.service.getHistory(
        widget.profileId,
        cursor: cursor,
        limit: 10,
      );
      if (result.errorCode != null) {
        throw StateError('history');
      }
      if (!mounted) {
        return;
      }
      setState(() {
        for (final t in result.transactions) {
          transactions[t.id] = t;
        }
        for (final p in result.periodSummaries) {
          periods[p.periodId] = p;
        }
        for (final g in result.completedGoals) {
          goals[g.transactionId] = g;
        }
        cursor = result.nextCursor;
        loaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => failed = true);
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String label(TransactionType type) => switch (type) {
    TransactionType.periodIncome => 'Доход периода',
    TransactionType.taskReward => 'Награда за задание',
    TransactionType.purchase => 'Покупка',
    TransactionType.savingsDeposit => 'В копилку',
    TransactionType.savingsWithdrawal => 'Из копилки',
    TransactionType.goalRedemption => 'Получена мечта',
  };
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ResourceText('История', style: Theme.of(context).textTheme.headlineSmall),
      if (loaded && transactions.isEmpty)
        const ResourceText('Здесь появятся твои решения.'),
      for (final p in periods.values) periodSummaryCard(p),
      for (final goal in goals.values)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ResourceText(
              'Мечта получена: ${goal.title} · ${goal.amountSpent} монет',
            ),
          ),
        ),
      for (final t in transactions.values)
        Card(
          key: ValueKey('history-${t.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResourceText('${label(t.type)} · ${t.amount} монет'),
                if (titles[t.relatedEntityId] case final title?)
                  ResourceText(title),
                ResourceText(
                  'Доступно: ${t.availableChange >= 0 ? '+' : ''}${t.availableChange} · копилка: ${t.savingsChange >= 0 ? '+' : ''}${t.savingsChange}',
                ),
                ResourceText(
                  '${t.createdAt.toLocal().day}.${t.createdAt.toLocal().month} · ${t.createdAt.toLocal().hour}:${t.createdAt.toLocal().minute.toString().padLeft(2, '0')}',
                ),
              ],
            ),
          ),
        ),
      if (loading) const LinearProgressIndicator(),
      if (failed)
        const ResourceText(
          'Историю не удалось загрузить. Сохранения не изменились.',
        ),
      if (!loading && (failed || cursor != null))
        OutlinedButton(
          onPressed: load,
          child: ResourceText(
            failed ? 'Повторить загрузку истории' : 'Показать ещё',
          ),
        ),
    ],
  );
}
