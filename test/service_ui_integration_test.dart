import 'dart:io';

import 'package:finni/contracts/contracts.dart';
import 'package:finni/domain/services/sqlite_logic_service.dart';
import 'package:finni/ui/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test(
    'UI controller accepts real SQLite mutations and reopens saved profile',
    () async {
      final dir = await Directory.systemTemp.createTemp('finni_ui_sqlite_');
      final db = '${dir.path}/game.sqlite3';
      var service = await SqliteLogicService.open(
        databaseFactory: databaseFactoryFfi,
        databasePath: db,
      );
      var controller = GameController(service);
      try {
        await controller.initialize();
        expect(controller.error, isNull);
        expect(controller.profiles, isEmpty);
        final created = await controller.execute(
          () => service.createProfile(
            CreateProfileCommand(
              actionId: controller.newActionId(),
              mode: ProfileMode.demo,
              petName: 'Финни',
              formId: 'pet.form.02',
              paletteId: 'pet.palette.03',
            ),
          ),
        );
        expect(created?.success, isTrue);
        final state = controller.state!;
        final plan = await controller.execute(
          () => service.confirmBudget(
            BudgetCommand(
              actionId: controller.newActionId(),
              profileId: state.profile.id,
              expectedGeneration: state.profile.generation,
              expectedRevision: state.stateRevision,
              needsLimit: 50,
              wantsLimit: 20,
              savingsTarget: 30,
            ),
          ),
        );
        expect(plan?.success, isTrue);
        final planned = controller.state!;
        final bought = await controller.execute(
          () => service.buyItem(
            PurchaseCommand(
              actionId: controller.newActionId(),
              profileId: planned.profile.id,
              expectedGeneration: planned.profile.generation,
              expectedRevision: planned.stateRevision,
              itemId: 'item.food',
            ),
          ),
        );
        expect(bought?.success, isTrue);
        expect(controller.state!.availableBalance, 70);
        final revision = controller.state!.stateRevision;
        controller.dispose();
        await service.close();
        service = await SqliteLogicService.open(
          databaseFactory: databaseFactoryFfi,
          databasePath: db,
        );
        controller = GameController(service);
        await controller.initialize();
        expect(controller.profiles.length, 1);
        await controller.openProfile(state.profile.id);
        expect(controller.error, isNull);
        expect(controller.state!.availableBalance, 70);
        expect(controller.state!.stateRevision, revision);
        expect(controller.state!.pet.paletteId, 'pet.palette.03');
      } finally {
        controller.dispose();
        await service.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
