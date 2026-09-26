import 'package:finni/ui/resource_art.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:finni/contracts/contracts.dart';
import 'package:finni/domain/services/sqlite_logic_service.dart';
import 'package:finni/ui/finni_app.dart';
import 'package:finni/ui/task_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  setUpAll(() async {
    for (final entry in {
      'Pangolin': 'assets/fonts/Pangolin-Regular.ttf',
      'Neucha': 'assets/fonts/Neucha.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
    if (Platform.isWindows && const bool.fromEnvironment('FINNI_CAPTURE')) {
      final bytes = await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes();
      await (FontLoader(
        'Roboto',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  testWidgets(
    'five periods through real UI, six task types, goal and adult controls',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('finni_full_ui_'),
      ))!;
      final service = (await tester.runAsync(
        () => SqliteLogicService.open(
          databaseFactory: databaseFactoryFfi,
          databasePath: '${dir.path}/game.sqlite3',
        ),
      ))!;
      addTearDown(() async {
        await tester.runAsync(() async {
          await service.close();
          await dir.delete(recursive: true);
        });
      });
      Future<void> settle() async {
        await tester.pump();
        var quiet = 0;
        for (var i = 0; i < 150; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          if (!tester.binding.hasScheduledFrame &&
              find
                  .byType(LinearProgressIndicator)
                  .evaluate()
                  .where(
                    (e) => (e.widget as LinearProgressIndicator).value == null,
                  )
                  .isEmpty) {
            if (++quiet >= 3) {
              break;
            }
          } else {
            quiet = 0;
          }
        }
        expect(
          quiet,
          greaterThanOrEqualTo(3),
          reason: "UI did not settle after real I/O",
        );
        expect(tester.takeException(), isNull);
      }

      Future<void> tap(Finder finder) async {
        if (finder.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            finder,
            200,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await settle();
      }

      Future<void> click(String text) async {
        if (find.text(text).evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            find.text(text),
            200,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await tap(find.text(text).last);
      }

      Future<void> fill(Finder finder, String text) async {
        if (finder.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            finder,
            200,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.enterText(finder, text);
        tester.testTextInput.hide();
        await tester.pump();
      }

      Future<void> screenshot(String name) async {
        if (!const bool.fromEnvironment('FINNI_CAPTURE')) {
          return;
        }
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('full-capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('evidence/ui-feedback/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      var checkedLargeReward = false;
      Future<void> result() async {
        if (!checkedLargeReward &&
            find.text('Ты молодец!').evaluate().isNotEmpty) {
          checkedLargeReward = true;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await screenshot('reward-large-text');
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          await tester.pumpAndSettle();
        }
        await click('Продолжить');
      }

      Future<void> confirm() async {
        await click('Подтвердить');
        await result();
      }

      Future<void> home() => click('Дом');
      Future<GameState> state() async => (await tester.runAsync(() async {
        final list = await service.listProfiles();
        return (await service.loadState(list.profiles.first.id)).stateSnapshot!;
      }))!;

      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('full-capture'),
          child: FinniApp(service: service),
        ),
      );
      await settle();
      await click('Демо: пять периодов');
      await click('Начать дружбу');
      await result();
      expect((await state()).availableBalance, 100);
      await click('Копилка');
      final goalCard = find.ancestor(
        of: find.byWidgetPredicate(
          (w) =>
              w is ResourceText &&
              w.data == 'Игровая площадка для Финни · 120 монет',
        ),
        matching: find.byType(Card),
      );
      await tap(
        find.descendant(
          of: goalCard,
          matching: find.widgetWithText(FilledButton, 'Выбрать'),
        ),
      );
      await confirm();
      Future<void> plan(List<int> amounts) async {
        await home();
        await click('Мой бюджет');
        for (var i = 0; i < 3; i++) {
          await fill(find.byType(TextField).at(i), '${amounts[i]}');
        }
        await click('Посмотреть план');
        await confirm();
      }

      Future<void> task(
        String title,
        Future<void> Function() answer, {
        bool wrong = false,
      }) async {
        await click('Задания');
        final card = find.ancestor(
          of: find.text(title),
          matching: find.byType(Card),
        );
        // Build the entire task card before locating its button.
        if (card.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            find.text(title),
            200,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await tap(
          find.descendant(
            of: card,
            matching: find.widgetWithText(FilledButton, 'Открыть задание'),
          ),
        );
        expect(find.byType(TaskPanel), findsOneWidget);
        await answer();
        await screenshot(
          'task-${tester.widget<TaskPanel>(find.byType(TaskPanel)).definition.interactionType.name}',
        );
        await click('Проверить ответ');
        await screenshot(
          'feedback-${title.hashCode}-${wrong ? 'wrong' : 'reward'}',
        );
        if (wrong) {
          expect(find.text('Награда не начислена'), findsOneWidget);
        }
        await result();
      }

      Future<void> buy(String title) async {
        await click('Покупки');
        if (find.text(title).evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            find.text(title),
            200,
            scrollable: find.byType(Scrollable).first,
          );
        }
        final card = find.ancestor(
          of: find.text(title),
          matching: find.byType(Card),
        );
        await tap(
          find.descendant(
            of: card,
            matching: find.widgetWithText(FilledButton, 'Посмотреть покупку'),
          ),
        );
        await screenshot('purchase-preview');
        await click('Подтвердить');
        await screenshot('purchase-result');
        await result();
      }

      Future<void> deposit(int n) async {
        await click('Копилка');
        await fill(find.byType(TextField), '$n');
        await click('Положить в копилку');
        await confirm();
      }

      Future<void> finish(int n, int available, int savings) async {
        await home();
        await click('Итог периода');
        await click('Завершить период');
        await click('Подтвердить');
        await screenshot('period-$n-result');
        await result();
        final s = await state();
        expect((s.availableBalance, s.savingsBalance), (available, savings));
        expect(s.learningProgress.completedPeriods, n);
        debugPrint('UI period $n passed');
        if (n < 5) {
          await click('Начать следующий период');
          await result();
        }
      }

      await plan([50, 20, 30]);
      await task('Распредели доход', () async {
        await fill(find.byKey(const ValueKey('task-needs')), '50');
        await fill(find.byKey(const ValueKey('task-wants')), '20');
        await fill(find.byKey(const ValueKey('task-savings')), '30');
        await tap(find.byTooltip('Справка'));
        await click('Вернуться к игре');
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('task-needs')))
              .controller!
              .text,
          '50',
        );
      });
      await task('Составь путь к цели', () async {
        for (var i = 0; i < 4; i++) {
          await fill(find.byKey(ValueKey('task-period-$i')), '30');
        }
      });
      await buy('Полезная еда');
      await buy('Набор для ухода');
      await deposit(30);
      // Cancel a financial preview: no revision/balance change.
      await click('Копилка');
      final before = await state();
      await fill(find.byType(TextField), '10');
      await click('Взять из копилки');
      await click('Отмена');
      expect((await state()).stateRevision, before.stateRevision);
      // Insufficient funds: real service rejects preview and does not expose confirmation.
      await click('Покупки');
      final music = find.ancestor(
        of: find.text('Музыкальная игрушка'),
        matching: find.byType(Card),
      );
      await tap(
        find.descendant(
          of: music,
          matching: find.widgetWithText(FilledButton, 'Посмотреть покупку'),
        ),
      );
      expect(find.widgetWithText(FilledButton, 'Подтвердить'), findsNothing);
      await screenshot('insufficient-funds');
      await click('Отмена');
      await finish(1, 30, 30);
      await plan([45, 35, 30]);
      await task(
        'Собери корзину',
        () => tap(find.byKey(const ValueKey('basket-item.food'))),
      );
      await buy('Школьный обед');
      await buy('Набор для ухода');
      await buy('Мяч');
      await deposit(30);
      await finish(2, 25, 60);
      expect((await state()).pet.stage, PetStage.junior);
      await plan([50, 45, 30]);
      final entries = [
        'item.food',
        'item.hygiene',
        'item.school_lunch',
        'item.health_check',
        'item.ball',
        'item.hat',
      ];
      await task('Нужное или желаемое', () async {
        for (final id in entries) {
          await tap(find.byKey(ValueKey('group-$id-want')));
        }
      }, wrong: true);
      for (var i = 0; i < entries.length; i++) {
        await tap(
          find.byKey(
            ValueKey('group-${entries[i]}-${i < 4 ? 'need' : 'want'}'),
          ),
        );
      }
      await click('Проверить ответ');
      await result();
      await buy('Полезная еда');
      await buy('Набор для ухода');
      await buy('Яркая шапочка');
      await deposit(30);
      await finish(3, 5, 90);
      await plan([70, 0, 25]);
      await task(
        'Сравни план и факт',
        () => tap(find.byKey(const ValueKey('option-option.plan_b'))),
      );
      await buy('Забота о здоровье');
      await buy('Полезная еда');
      await deposit(25);
      await finish(4, 15, 115);
      expect((await state()).pet.stage, PetStage.grown);
      await plan([50, 35, 30]);
      await task(
        'Посчитай накопления',
        () => tap(find.byKey(const ValueKey('option-option.25'))),
      );
      await buy('Полезная еда');
      await buy('Набор для ухода');
      await buy('Мяч');
      await deposit(30);
      await click('Копилка');
      await click('Получить мечту');
      await confirm();
      await finish(5, 5, 25);
      expect((await state()).learningProgress.qualityPoints, 15);
      expect(find.text('Начать следующий период'), findsNothing);
      await click('Посмотреть историю');
      await screenshot('history');
      await click('Показать ещё');
      await click('Задания');
      final reviewCard = find.ancestor(
        of: find.text('Распредели доход'),
        matching: find.byType(Card),
      );
      await tap(
        find.descendant(
          of: reviewCard,
          matching: find.widgetWithText(FilledButton, 'Посмотреть задание'),
        ),
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('submit-task')))
            .onPressed,
        isNull,
      );
      final original = await state();
      await tap(find.byTooltip('Взрослому'));
      await fill(find.byType(TextField), '0');
      await click('Войти во взрослый раздел');
      expect(
        find.text('Проверь ответ или попроси взрослого помочь.'),
        findsOneWidget,
      );
      await fill(find.byType(TextField), '15');
      await click('Войти во взрослый раздел');
      await click('Настройки');
      await click('Крупный текст');
      expect((await state()).settings.largeTextPreferred, isTrue);
      await screenshot('settings-large');
      await click('Крупный текст');
      await tap(find.byTooltip('Взрослому'));
      await fill(find.byType(TextField), '15');
      await click('Войти во взрослый раздел');

      await click('Сбросить демо');
      await fill(
        find.byKey(const ValueKey('destructive-confirmation')),
        'СБРОСИТЬ',
      );
      await click('Отмена');
      expect((await state()).profile.generation, original.profile.generation);

      await click('Сбросить демо');
      await fill(
        find.byKey(const ValueKey('destructive-confirmation')),
        'СБРОСИТЬ',
      );

      await click('Подтвердить сброс');

      await result();
      expect(
        (await state()).profile.generation,
        original.profile.generation + 1,
      );
      expect((await state()).availableBalance, 100);
      await tap(find.byTooltip('Взрослому'));
      await fill(find.byType(TextField), '15');
      await click('Войти во взрослый раздел');
      await click('Удалить профиль');
      await fill(
        find.byKey(const ValueKey('destructive-confirmation')),
        'УДАЛИТЬ',
      );

      await click('Подтвердить удаление');

      await result();
      expect((await tester.runAsync(service.listProfiles))!.profiles, isEmpty);
      expect(find.text('Знакомься, Финни!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
