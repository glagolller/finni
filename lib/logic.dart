import 'contracts/logic_service.dart';
import 'domain/services/sqlite_logic_service.dart';

/// Production factory used by the interface composition root.
Future<LogicService> createLogicService() => SqliteLogicService.open();
