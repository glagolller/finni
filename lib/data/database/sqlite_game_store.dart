import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../contracts/models/core_models.dart';
import '../profile_document.dart';

class StoredReceipt {
  const StoredReceipt({
    required this.actionId,
    required this.profileId,
    required this.operation,
    required this.fingerprint,
    required this.operationRevision,
    required this.result,
  });

  final String actionId;
  final String? profileId;
  final String operation;
  final String fingerprint;
  final int operationRevision;
  final JsonMap result;
}

class SqliteGameStore {
  SqliteGameStore._(this.database);

  final Database database;

  static Future<SqliteGameStore> open({
    DatabaseFactory? factory,
    String? databasePath,
  }) async {
    final selectedFactory = factory ?? databaseFactory;
    final selectedPath =
        databasePath ?? path.join(await getDatabasesPath(), 'finni_v1.sqlite3');
    final database = await selectedFactory.openDatabase(
      selectedPath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE profiles(
              id TEXT PRIMARY KEY,
              updated_at TEXT NOT NULL,
              payload TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE action_receipts(
              action_id TEXT PRIMARY KEY,
              profile_id TEXT,
              operation TEXT NOT NULL,
              fingerprint TEXT NOT NULL,
              operation_revision INTEGER NOT NULL,
              result_json TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE deleted_profile_tombstones(
              profile_id TEXT PRIMARY KEY,
              deleted_at TEXT NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX receipts_profile_id ON action_receipts(profile_id)',
          );
        },
      ),
    );
    return SqliteGameStore._(database);
  }

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) =>
      database.transaction(action);

  Future<ProfileDocument?> loadProfile(
    String profileId, {
    DatabaseExecutor? executor,
  }) async {
    final rows = await (executor ?? database).query(
      'profiles',
      columns: ['payload'],
      where: 'id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ProfileDocument(
      (jsonDecode(rows.first['payload']! as String)! as Map)
          .cast<String, Object?>(),
    );
  }

  Future<List<ProfileDocument>> loadProfiles() async {
    final rows = await database.query('profiles', orderBy: 'updated_at DESC');
    return rows
        .map(
          (row) => ProfileDocument(
            (jsonDecode(row['payload']! as String)! as Map)
                .cast<String, Object?>(),
          ),
        )
        .toList();
  }

  Future<void> saveProfile(
    ProfileDocument profile, {
    required DatabaseExecutor executor,
  }) async {
    await executor.insert('profiles', {
      'id': profile.id,
      'updated_at': profile.updatedAt,
      'payload': jsonEncode(profile.data),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteProfile(
    String profileId, {
    required DatabaseExecutor executor,
    required DateTime deletedAt,
  }) async {
    await executor.delete('profiles', where: 'id = ?', whereArgs: [profileId]);
    await executor.insert('deleted_profile_tombstones', {
      'profile_id': profileId,
      'deleted_at': deletedAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<StoredReceipt?> loadReceipt(
    String actionId, {
    DatabaseExecutor? executor,
  }) async {
    final rows = await (executor ?? database).query(
      'action_receipts',
      where: 'action_id = ?',
      whereArgs: [actionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return StoredReceipt(
      actionId: actionId,
      profileId: row['profile_id'] as String?,
      operation: row['operation']! as String,
      fingerprint: row['fingerprint']! as String,
      operationRevision: row['operation_revision']! as int,
      result: (jsonDecode(row['result_json']! as String)! as Map)
          .cast<String, Object?>(),
    );
  }

  Future<void> saveReceipt(
    StoredReceipt receipt, {
    required DatabaseExecutor executor,
    required DateTime createdAt,
  }) async {
    await executor.insert('action_receipts', {
      'action_id': receipt.actionId,
      'profile_id': receipt.profileId,
      'operation': receipt.operation,
      'fingerprint': receipt.fingerprint,
      'operation_revision': receipt.operationRevision,
      'result_json': jsonEncode(receipt.result),
      'created_at': createdAt.toUtc().toIso8601String(),
    });
  }

  Future<void> close() => database.close();
}
