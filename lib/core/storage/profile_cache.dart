import 'package:sembast/sembast.dart';

import '../../shared/models/auth_user.dart';
import 'app_database.dart';

/// Snapshot of `GET /me` so the app can start offline with the right
/// permissions. Contains no secrets (the token is only in secure storage).
class ProfileCache {
  ProfileCache(this._db);

  final AppDatabase _db;
  static final _store = stringMapStoreFactory.store('profile');
  static const _meKey = 'me';

  Future<AuthUser?> read() async {
    final json = await _store.record(_meKey).get(_db.db);
    if (json == null) return null;
    try {
      return AuthUser.fromJson(Map<String, dynamic>.from(json));
    } on Object {
      return null;
    }
  }

  Future<void> write(AuthUser user) =>
      _store.record(_meKey).put(_db.db, user.toJson());

  Future<void> clear() => _store.delete(_db.db);
}
