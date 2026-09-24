import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:finni/contracts/contracts.dart';
import 'package:finni/ui/finni_app.dart';
import 'package:finni/ui/game_controller.dart';
import 'package:finni/ui/preview/fixture_states.dart';
import 'package:finni/ui/preview/preview_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

GameState changed(GameState s, {int? revision, int? generation}) => GameState(
  contractVersion: s.contractVersion,
  contentVersion: s.contentVersion,
  stateRevision: revision ?? s.stateRevision,
  profile: Profile(
    id: s.profile.id,
    mode: s.profile.mode,
    petName: s.profile.petName,
    generation: generation ?? s.profile.generation,
    createdAt: s.profile.createdAt,
    updatedAt: s.profile.updatedAt,
  ),
  currentPeriod: s.currentPeriod,
  availableBalance: s.availableBalance,
  savingsBalance: s.savingsBalance,
  pet: s.pet,
  taskHub: s.taskHub,
  learningProgress: s.learningProgress,
  settings: s.settings,
  activeGoal: s.activeGoal,
);

ActionResult applied(GameState snapshot, String id) => ActionResult(
  success: true,
  outcome: ActionOutcome.applied,
  actionId: id,
  messageForChild: 'Сохранено',
  nextActions: const [],
  stateSnapshot: snapshot,
);

class _BudgetService extends PreviewService {
  _BudgetService() : super(snapshot: newDemoFixture());
  BudgetCommand? command;
  @override
  Future<PreviewResult> previewBudget(BudgetQuery query) async => PreviewResult(
    allowed: true,
    warnings: const [
      WarningMessage(
        code: WarningCode.needsUnderfunded,
        messageForChild: 'На нужное запланировано мало.',
        requiresConfirmation: true,
      ),
    ],
    messageForChild: 'План ничего не списывает.',
    nextActions: const [],
    stateSnapshot: snapshot,
  );
  @override
  Future<ActionResult> confirmBudget(BudgetCommand value) async {
    command = value;
    return applied(snapshot, value.actionId);
  }
}

Future<void> start(WidgetTester tester, PreviewService service) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('capture'),
      child: FinniApp(service: service, previewMode: true),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Продолжить: Финни · демо'));
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('FINNI_CAPTURE')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('evidence/ui-first/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('FINNI_CAPTURE') && Platform.isWindows) {
      final bytes = await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes();
      final font = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });
  test('late snapshots cannot roll back revision or reset generation', () {
    final c = GameController(PreviewService());
    addTearDown(c.dispose);
    final state = openPeriodFixture();
    expect(c.acceptSnapshot(state), isTrue);
    expect(c.acceptSnapshot(changed(state, revision: 8)), isFalse);
    expect(
      c.acceptSnapshot(changed(state, generation: 2, revision: 10)),
      isTrue,
    );
    expect(
      c.acceptSnapshot(changed(state, generation: 1, revision: 99)),
      isFalse,
    );
    expect(c.state!.profile.generation, 2);
  });

  test(
    'uncertain response retries the same command and blocks new intentions',
    () async {
      final c = GameController(PreviewService());
      addTearDown(c.dispose);
      final id = c.newActionId();
      var calls = 0;
      Future<ActionResult> action() async {
        calls++;
        if (calls == 1) throw Exception('Lost response');
        return applied(openPeriodFixture(), id);
      }

      await c.execute(action);
      expect(c.canRetry, isTrue);
      var otherCalled = false;
      await c.execute(() async {
        otherCalled = true;
        return applied(newDemoFixture(), 'new');
      });
      expect(otherCalled, isFalse);
      expect((await c.retryLast())!.actionId, id);
      expect(c.canRetry, isFalse);
      expect(calls, 2);
    },
  );

  test('double submit is blocked while a command is in flight', () async {
    final c = GameController(PreviewService());
    addTearDown(c.dispose);
    final pending = Completer<ActionResult>();
    final first = c.execute(() => pending.future);
    expect(await c.execute(() => throw StateError('must not execute')), isNull);
    pending.complete(applied(openPeriodFixture(), 'first'));
    await first;
  });

  testWidgets(
    'home and insufficient funds render at 360 px without changing money',
    (tester) async {
      final service = PreviewService();
      await start(tester, service);
      expect(find.text('Привет, Финни!'), findsOneWidget);
      expect(find.text('Сравни план и факт'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'home-360');
      await tester.tap(find.text('Покупки'));
      await tester.pumpAndSettle();
      final purchase = find
          .widgetWithText(FilledButton, 'Посмотреть покупку')
          .last;
      await tester.ensureVisible(purchase);
      await tester.pumpAndSettle();
      await tester.tap(purchase);
      await tester.pumpAndSettle();
      expect(find.textContaining('Не хватает 40 монет'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Подтвердить'), findsNothing);
      expect(service.snapshot.availableBalance, 30);
      expect(tester.takeException(), isNull);
      await capture(tester, 'insufficient-funds-360');
    },
  );

  testWidgets(
    'budget cancellation never sends command; confirmation passes warning and revision',
    (tester) async {
      final service = _BudgetService();
      await start(tester, service);
      await tester.scrollUntilVisible(find.text('Мой бюджет'), 180);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Мой бюджет'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '0');
      await tester.enterText(find.byType(TextField).at(1), '50');
      await tester.enterText(find.byType(TextField).at(2), '50');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await capture(tester, 'budget-360');
      await tester.ensureVisible(find.text('Посмотреть план'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Посмотреть план'));
      await tester.pumpAndSettle();
      expect(find.text('На нужное запланировано мало.'), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(service.command, isNull);
      await tester.tap(find.text('Посмотреть план'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      expect(
        service.command!.acceptedWarnings,
        contains(WarningCode.needsUnderfunded),
      );
      expect(service.command!.expectedRevision, 1);
      expect(service.command!.needsLimit, 0);
      expect(service.command!.actionId, isNotEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
