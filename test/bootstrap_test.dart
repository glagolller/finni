import 'dart:convert';

import 'package:finni/contracts/contracts.dart';
import 'package:finni/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'production startup failure offers retry without preview fallback',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        FinniBootstrapRoot(
          serviceFactory: () async {
            calls++;
            throw StateError('unavailable store');
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Не удалось открыть игру'), findsOneWidget);
      expect(find.textContaining('Тестовый UI'), findsNothing);
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(calls, 2);
    },
  );

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
