import 'package:sembast/sembast.dart';

import '../../../core/storage/app_database.dart';
import 'call_models.dart';
import 'calls_config.dart';
import 'meetings.dart';

class CachedCallsPage {
  const CachedCallsPage({required this.calls, required this.fetchedAt});
  final List<CallInfo> calls;
  final DateTime fetchedAt;
}

/// Local calls data: the first history page per filter (offline reading,
/// ТЗ п.24.16) and the last `GET /calls/config`. No tokens, wiped on sign-out.
class CallsCache {
  CallsCache(this._db);
  final AppDatabase _db;

  static final _history = stringMapStoreFactory.store('calls_history');
  static final _meta = stringMapStoreFactory.store('calls_meta');
  static const _configKey = 'config';

  static String _key(bool missedOnly) => missedOnly ? 'missed' : 'all';

  Future<CachedCallsPage?> history({required bool missedOnly}) async {
    final row = await _history.record(_key(missedOnly)).get(_db.db);
    if (row == null) return null;
    try {
      return CachedCallsPage(
        fetchedAt: DateTime.parse(row['fetched_at']! as String),
        calls: ((row['calls'] as List?) ?? const [])
            .map((e) => CallInfo.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
    } on Object {
      return null;
    }
  }

  Future<void> putHistory({required bool missedOnly, required List<CallInfo> calls, required DateTime fetchedAt}) =>
      _history.record(_key(missedOnly)).put(_db.db, {
        'fetched_at': fetchedAt.toUtc().toIso8601String(),
        'calls': [for (final c in calls) c.toJson()],
      });

  /// A call from any cached page (call card opened offline).
  Future<CallInfo?> findCall(String id) async {
    for (final missed in const [false, true]) {
      final page = await history(missedOnly: missed);
      final hit = page?.calls.where((c) => c.id == id).firstOrNull;
      if (hit != null) return hit;
    }
    return null;
  }

  Future<CallsConfig?> config() async {
    final row = await _meta.record(_configKey).get(_db.db);
    return row == null ? null : CallsConfig.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> putConfig(CallsConfig config) => _meta.record(_configKey).put(_db.db, config.toJson());

  static const _audioKey = 'audio_quality';

  /// Microphone processing and traffic saving chosen on this device.
  Future<({CallAudioSettings audio, CallDataSaver dataSaver})?> audioSettings() async {
    final row = await _meta.record(_audioKey).get(_db.db);
    if (row == null) return null;
    final map = Map<String, dynamic>.from(row);
    return (audio: CallAudioSettings.fromJson(map), dataSaver: CallDataSaver.parse(map['data_saver'] as String?));
  }

  Future<void> putAudioSettings(CallAudioSettings audio, CallDataSaver dataSaver) =>
      _meta.record(_audioKey).put(_db.db, {...audio.toJson(), 'data_saver': dataSaver.name});

  Future<void> clear() async {
    await _history.delete(_db.db);
    await _meta.delete(_db.db);
  }
}
