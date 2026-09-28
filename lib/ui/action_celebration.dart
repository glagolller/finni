import 'package:flutter/material.dart';

import '../contracts/contracts.dart';
import 'resource_art.dart';

class ActionCelebration extends StatelessWidget {
  const ActionCelebration({
    super.key,
    required this.result,
    required this.onContinue,
  });
  final ActionResult result;
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext context) {
    final replay = result.outcome == ActionOutcome.replayed;
    final task = result.taskAttempt;
    final money = result.moneyDelta;
    final pet = result.petDelta;
    final reason = money?.reasonCode ?? pet?.reasonCode ?? '';
    final purchase = reason.startsWith('purchase_');
    final kind = replay
        ? ArtKind.star
        : purchase
        ? itemKind(reason)
        : reason.startsWith('savings_')
        ? ArtKind.savings
        : result.periodSummary != null
        ? ArtKind.star
        : reason == 'goal_redeemed'
        ? ArtKind.toy
        : ArtKind.coin;
    final title = replay
        ? 'Уже сохранено'
        : task != null
        ? (task.rewardGranted ? 'Ты молодец!' : 'Попробуй ещё!')
        : purchase
        ? 'Для Финни!'
        : result.periodSummary != null
        ? 'Период завершён!'
        : reason == 'savings_deposit'
        ? 'Мечта ближе!'
        : reason == 'savings_withdrawal'
        ? 'Взяли из копилки'
        : reason == 'goal_redeemed'
        ? 'Мечта сбылась!'
        : money?.incomeChange != 0 && money != null
        ? 'Новый запас!'
        : 'Готово!';
    final explanations = <String>{
      if (!replay) result.messageForChild,
      if (!replay && task != null) task.explanation,
      if (!replay && pet != null) pet.explanationForChild,
      if (!replay && result.periodSummary != null)
        result.periodSummary!.explanationForChild,
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onContinue();
      },
      child: Scaffold(
        backgroundColor: purchase && !replay
            ? purchaseBackground(kind)
            : const Color(0xffffdf58),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            children: [
              const SizedBox(height: 24),
              Center(child: ResourceArt(kind: kind, size: 160)),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Pangolin',
                  fontSize: 34,
                  color: Color(0xff38295c),
                ),
              ),
              const SizedBox(height: 16),
              if (replay)
                const Text(
                  'Повторного списания или награды нет.',
                  textAlign: TextAlign.center,
                )
              else ...[
                if (task != null) ...[
                  if (task.rewardGranted)
                    Center(
                      child: ResourceText(
                        '+${task.rewardAmount} монет',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const Text(
                      'Награда не начислена',
                      textAlign: TextAlign.center,
                    ),
                  if (!task.rewardGranted)
                    Text(
                      'Попыток осталось: ${task.remainingAttempts}',
                      textAlign: TextAlign.center,
                    ),
                ] else if (money != null)
                  Center(child: moneyChanges(money)),
                if (purchase && pet != null) Center(child: petChanges(pet)),
                if (result.periodSummary case final summary?) ...[
                  Center(
                    child: ResourceText(
                      'Отложено ${summary.actual.qualifyingSavings} монет',
                    ),
                  ),
                  Center(
                    child: ResourceText(
                      'Баллы заботы +${summary.qualityPointsGranted}',
                    ),
                  ),
                ],
                if (explanations.isNotEmpty)
                  ExpansionTile(
                    title: const Text('Почему?'),
                    children: [
                      for (final text in explanations)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ResourceText(text),
                        ),
                    ],
                  ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onContinue,
                child: const Text('Продолжить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
