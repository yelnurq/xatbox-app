import 'package:sembast/sembast.dart';

import '../../../core/storage/app_database.dart';
import 'update_models.dart';

/// Device-local memory of the update check: when it last ran, the last
/// answer (for «Что нового» and the mandatory gate offline) and the version
/// the user postponed.
class UpdateStore {
  UpdateStore(this._db);

  final AppDatabase _db;
  static final _store = stringMapStoreFactory.store('settings');
  static const _key = 'app_update';

  Future<Map<String, Object?>> _read() async =>
      Map<String, Object?>.from(await _store.record(_key).get(_db.db) ?? const {});

  Future<void> _merge(Map<String, Object?> values) async =>
      _store.record(_key).put(_db.db, {...await _read(), ...values});

  Future<DateTime?> checkedAt() async {
    final ms = (await _read())['checked_at'];
    return ms is int ? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true) : null;
  }

  Future<AppRelease?> release() async {
    final raw = (await _read())['release'];
    if (raw is! Map) return null;
    try {
      return AppRelease.fromJson(Map<String, dynamic>.from(raw));
    } on Object {
      return null;
    }
  }

  Future<void> saveCheck(AppRelease release, DateTime at) => _merge({
    'checked_at': at.millisecondsSinceEpoch,
    'release': release.toJson(),
  });

  Future<int> postponedCode() async {
    final v = (await _read())['postponed_code'];
    return v is int ? v : 0;
  }

  Future<void> postpone(int versionCode) => _merge({'postponed_code': versionCode});
}
