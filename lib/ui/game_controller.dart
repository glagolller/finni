import 'dart:math';

import 'package:flutter/foundation.dart';

import '../contracts/contracts.dart';

/// UI orchestration only. Prices, rewards and validation belong to LogicService.
class GameController extends ChangeNotifier {
  GameController(this.service);

  final LogicService service;
  GameState? state;
  BootstrapConfig? bootstrap;
  List<ProfileSummary> profiles = [];
  bool busy = false;
  String? error;
  bool _disposed = false;
  int _readEpoch = 0;
  Future<ActionResult> Function()? _retry;
  bool _retryDeletesProfile = false;
  final _random = Random.secure();

  bool get canRetry => _retry != null;
  String newActionId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  bool acceptSnapshot(GameState snapshot) {
    if (snapshot.contractVersion != logicContractVersion ||
        snapshot.contentVersion != contentVersion) {
      error = 'Версия данных не совпадает с версией приложения.';
      return false;
    }
    final current = state;
    if (current != null) {
      // A response from another profile must never replace the active profile.
      if (current.profile.id != snapshot.profile.id) return false;
      if (snapshot.profile.generation < current.profile.generation) {
        return false;
      }
      if (snapshot.profile.generation == current.profile.generation &&
          snapshot.stateRevision < current.stateRevision) {
        return false;
      }
    }
    state = snapshot;
    return true;
  }

  void leaveProfile() {
    if (busy || canRetry) {
      return;
    }
    ++_readEpoch;
    state = null;
    error = null;
    _retry = null;
    _changed();
  }

  Future<void> initialize() async {
    if (busy) return;
    busy = true;
    error = null;
    _changed();
    try {
      final config = await service.getBootstrapConfig();
      if (config.contractVersion != logicContractVersion ||
          config.contentVersion != contentVersion ||
          config.petForms.isEmpty ||
          config.petPalettes.isEmpty) {
        throw StateError('Incompatible bootstrap');
      }
      bootstrap = config;
      final result = await service.listProfiles();
      if (result.errorCode != null) {
        error = result.messageForChild ?? 'Не удалось прочитать профили.';
      } else {
        profiles = result.profiles;
      }
    } catch (_) {
      error = 'Не удалось загрузить игру. Попробуй ещё раз.';
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> openProfile(String id) async {
    if (busy) return;
    final epoch = ++_readEpoch;
    busy = true;
    error = null;
    _retry = null;
    state = null;
    _changed();
    try {
      final result = await service.loadState(id);
      if (_disposed || epoch != _readEpoch) return;
      if (result.errorCode != null || !result.found) {
        error = result.messageForChild ?? 'Профиль не удалось открыть.';
      } else if (result.stateSnapshot?.profile.id != id) {
        error = 'Получены данные другого профиля. Открой игру ещё раз.';
      } else {
        acceptSnapshot(result.stateSnapshot!);
      }
    } catch (_) {
      error = 'Не удалось открыть сохранение. Оно не удалено.';
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<PreviewResult?> preview(Future<PreviewResult> Function() read) async {
    if (busy || canRetry) return null;
    busy = true;
    error = null;
    _changed();
    try {
      final result = await read();
      if (result.stateSnapshot != null &&
          !acceptSnapshot(result.stateSnapshot!)) {
        error ??= 'Данные изменились. Открой предпросмотр заново.';
        return null;
      }
      return result;
    } catch (_) {
      error = 'Не удалось проверить действие. Монеты не списаны.';
      return null;
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<ActionResult?> execute(
    Future<ActionResult> Function() action, {
    bool retry = false,
    bool deletesProfile = false,
  }) async {
    if (busy || (canRetry && !retry)) return null;
    busy = true;
    error = null;
    _retryDeletesProfile = deletesProfile;
    _changed();
    try {
      final result = await action();
      if (result.success && result.stateSnapshot == null && !deletesProfile) {
        throw StateError('A successful mutation requires a snapshot.');
      }
      _retry = result.errorCode == LogicErrorCode.storageError
          ? () => action()
          : null;
      if (result.stateSnapshot != null) {
        acceptSnapshot(result.stateSnapshot!);
      } else if (result.success && deletesProfile) {
        state = null;
      }
      if (!result.success) error = result.messageForChild;
      return result;
    } on UnsupportedError {
      _retry = null;
      error = 'Тестовый просмотр: это действие ещё не подключено.';
      return null;
    } catch (_) {
      // Keep the exact closure/command, including actionId, after uncertain I/O.
      _retry = action;
      error =
          'Ответ не получен. Повтори это же действие, чтобы узнать результат.';
      return null;
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<ActionResult?> retryLast() async {
    final action = _retry;
    return action == null
        ? null
        : execute(action, retry: true, deletesProfile: _retryDeletesProfile);
  }

  @override
  void dispose() {
    _disposed = true;
    _readEpoch++;
    super.dispose();
  }
}
