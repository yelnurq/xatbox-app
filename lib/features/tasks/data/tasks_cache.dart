import 'package:sembast/sembast.dart';

import '../../../core/storage/app_database.dart';
import 'task_models.dart';

class CachedTasks {
  const CachedTasks({required this.tasks, this.savedAt});
  final List<Task> tasks;
  final DateTime? savedAt;
}

/// The last `GET /tasks` and `GET /tasks/boards` answers for offline
/// reading. Bound to the user who loaded them, so another account never sees
/// a foreign list. Wiped on sign-out.
class TasksCache {
  TasksCache(this._db);

  final AppDatabase _db;
  static final _store = stringMapStoreFactory.store('tasks');
  static const _key = 'list';
  static const _boardsKey = 'boards';

  Future<CachedTasks?> read({required String ownerId}) async {
    if (ownerId.isEmpty) return null;
    final row = await _store.record(_key).get(_db.db);
    if (row == null || row['owner_id'] != ownerId) return null;
    try {
      return CachedTasks(
        tasks: ((row['tasks'] as List?) ?? const [])
            .map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        savedAt: DateTime.tryParse((row['saved_at'] as String?) ?? ''),
      );
    } on Object {
      return null;
    }
  }

  Future<void> write({
    required String ownerId,
    required List<Task> tasks,
    required DateTime savedAt,
  }) async {
    if (ownerId.isEmpty) return;
    await _store.record(_key).put(_db.db, {
      'owner_id': ownerId,
      'saved_at': savedAt.toUtc().toIso8601String(),
      'tasks': [for (final t in tasks) t.toJson()],
    });
  }

  Future<List<TaskBoard>?> readBoards({required String ownerId}) async {
    if (ownerId.isEmpty) return null;
    final row = await _store.record(_boardsKey).get(_db.db);
    if (row == null || row['owner_id'] != ownerId) return null;
    try {
      return ((row['boards'] as List?) ?? const [])
          .map((e) => TaskBoard.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on Object {
      return null;
    }
  }

  Future<void> writeBoards({
    required String ownerId,
    required List<TaskBoard> boards,
  }) async {
    if (ownerId.isEmpty) return;
    await _store.record(_boardsKey).put(_db.db, {
      'owner_id': ownerId,
      'boards': [for (final b in boards) b.toJson()],
    });
  }

  Future<void> clear() => _store.drop(_db.db);
}
