import 'package:flutter/material.dart';

import '../contracts/contracts.dart';

enum ArtKind {
  coin,
  food,
  mood,
  savings,
  toy,
  care,
  health,
  clothing,
  decor,
  star,
}

ArtKind resourceKind(IconData icon) => icon == Icons.monetization_on
    ? ArtKind.coin
    : icon == Icons.savings
    ? ArtKind.savings
    : icon == Icons.restaurant
    ? ArtKind.food
    : ArtKind.mood;
ArtKind itemKind(String id) => switch (id.replaceFirst('purchase_', 'item.')) {
  'item.food' || 'item.school_lunch' => ArtKind.food,
  'item.hygiene' => ArtKind.care,
  'item.health' || 'item.health_check' => ArtKind.health,
  'item.hat' => ArtKind.clothing,
  'item.room_decor' => ArtKind.decor,
  _ => ArtKind.toy,
};

Color purchaseBackground(ArtKind kind) => switch (kind) {
  ArtKind.food => const Color(0xffffcd91),
  ArtKind.toy => const Color(0xffc0d5ff),
  ArtKind.care => const Color(0xffabe4e4),
  ArtKind.health => const Color(0xffffc7ce),
  ArtKind.clothing => const Color(0xffdfc9f3),
  ArtKind.decor => const Color(0xffc0e8ce),
  _ => const Color(0xffffdf58),
};

class ResourceArt extends StatelessWidget {
  const ResourceArt({super.key, required this.kind, this.size = 24});
  final ArtKind kind;
  final double size;
  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (kind) {
      ArtKind.coin => (Icons.star_rounded, const Color(0xffa56600), 'монеты'),
      ArtKind.food => (
        Icons.lunch_dining_rounded,
        const Color(0xffc76520),
        'сытость',
      ),
      ArtKind.mood => (
        Icons.sentiment_very_satisfied_rounded,
        const Color(0xffcf497a),
        'настроение',
      ),
      ArtKind.savings => (
        Icons.savings_rounded,
        const Color(0xffb94886),
        'копилка',
      ),
      ArtKind.toy => (Icons.toys_rounded, const Color(0xff5b75c9), 'игрушка'),
      ArtKind.care => (Icons.soap_rounded, const Color(0xff258f99), 'уход'),
      ArtKind.health => (
        Icons.medical_services_rounded,
        const Color(0xffda5365),
        'здоровье',
      ),
      ArtKind.clothing => (
        Icons.checkroom_rounded,
        const Color(0xff9168ba),
        'одежда',
      ),
      ArtKind.decor => (Icons.weekend_rounded, const Color(0xff5ba17b), 'уют'),
      ArtKind.star => (
        Icons.star_rounded,
        const Color(0xffad6f00),
        'баллы заботы',
      ),
    };
    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kind == ArtKind.coin
                ? const Color(0xffffc83d)
                : color.withValues(alpha: 0.14),
            border: kind == ArtKind.coin
                ? Border.all(color: const Color(0xffdf940e), width: size * .06)
                : null,
          ),
          child: Icon(icon, color: color, size: size * .7),
        ),
      ),
    );
  }
}

/// Written units stay in accessibility speech, while children see resource pictures.
class ResourceText extends StatelessWidget {
  const ResourceText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.semanticsLabel,
  });
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final String? semanticsLabel;
  @override
  Widget build(BuildContext context) {
    // Dart word boundaries are ASCII; use an explicit Cyrillic boundary below.
    final parts = RegExp(
      r'монет(?:ами|ах|ам|ы|а|у)?(?![а-яё])|[Сс]ытость|[Нн]астроение|[Бб]аллы заботы',
    ).allMatches(data).toList();
    if (parts.isEmpty) {
      return Text(
        data,
        style: style,
        textAlign: textAlign,
        semanticsLabel: semanticsLabel,
      );
    }
    final spans = <InlineSpan>[];
    var end = 0;
    for (final m in parts) {
      spans.add(TextSpan(text: data.substring(end, m.start)));
      final word = m.group(0)!.toLowerCase();
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: ResourceArt(
            kind: word.startsWith('монет')
                ? ArtKind.coin
                : word == 'сытость'
                ? ArtKind.food
                : word == 'настроение'
                ? ArtKind.mood
                : ArtKind.star,
            size: (style?.fontSize ?? 16) * 1.2,
          ),
        ),
      );
      end = m.end;
    }
    spans.add(TextSpan(text: data.substring(end)));
    return Semantics(
      label: semanticsLabel ?? data,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(children: spans),
          style: style,
          textAlign: textAlign,
        ),
      ),
    );
  }
}

String signed(int value) => value > 0 ? '+$value' : '$value';
Widget moneyChanges(MoneyDelta money) => Wrap(
  spacing: 16,
  runSpacing: 8,
  children: [
    if (money.availableChange != 0)
      ResourceText('${signed(money.availableChange)} монет'),
    if (money.savingsChange != 0)
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ResourceArt(kind: ArtKind.savings),
          Text(' ${signed(money.savingsChange)}'),
        ],
      ),
  ],
);
Widget petChanges(PetDelta pet) => Wrap(
  spacing: 16,
  children: [
    if (pet.satietyAfter != pet.satietyBefore)
      ResourceText('Сытость ${signed(pet.satietyAfter - pet.satietyBefore)}'),
    if (pet.moodAfter != pet.moodBefore)
      ResourceText('Настроение ${signed(pet.moodAfter - pet.moodBefore)}'),
  ],
);
Widget planFactCard(BudgetPlan plan, BudgetActual actual) => Card(
  child: Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in [
          ('Нужное', plan.needsLimit, actual.needsSpent),
          ('Желания', plan.wantsLimit, actual.wantsSpent),
          ('В копилку', plan.savingsTarget, actual.qualifyingSavings),
        ]) ...[
          Text(row.$1, style: const TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 16,
            children: [
              ResourceText('План: ${row.$2} монет'),
              ResourceText(
                '${row.$1 == 'В копилку' ? 'Отложено' : 'Потрачено'}: ${row.$3} монет',
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    ),
  ),
);
