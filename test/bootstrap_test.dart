import 'dart:convert';

import 'package:finni/contracts/contracts.dart';
import 'package:finni/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('production root never silently starts the preview adapter', (
    tester,
  ) async {
    await tester.pumpWidget(const FinniBootstrapRoot());

    expect(
      find.textContaining('Игровой сервис ещё не подключён'),
      findsOneWidget,
    );
    expect(find.textContaining('Тестовый UI'), findsNothing);
  });

  test('appearance contract exposes nine combinations', () {
    expect(supportedPetFormIds.length, 3);
    expect(supportedPetPaletteIds.length, 3);
    expect(supportedPetFormIds.length * supportedPetPaletteIds.length, 9);
    expect(petFormLabels.keys.toSet(), supportedPetFormIds);
    expect(petPaletteLabels.keys.toSet(), supportedPetPaletteIds);
  });

  test('destructive confirmations are exact', () {
    expect(resetDemoConfirmationText, 'СБРОСИТЬ');
    expect(deleteProfileConfirmationText, 'УДАЛИТЬ');
  });

  testWidgets('task asset exposes six typed simulations', (tester) async {
    final raw = await rootBundle.loadString('assets/content/tasks.json');
    final document = jsonDecode(raw) as Map<String, Object?>;
    final tasks = document['tasks']! as List<Object?>;

    expect(tasks, hasLength(6));
    for (final value in tasks) {
      final task = value! as Map<String, Object?>;
      expect(task['simulationOnly'], isTrue);
      expect(task['rewardAmount'], 5);
      final input = task['input']! as Map<String, Object?>;
      expect(input['type'], task['interactionType']);
    }
  });
}
