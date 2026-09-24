import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/network/network_status.dart';
import '../../../core/storage/app_database.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../calendar/presentation/calendar_providers.dart';
import '../../chat/presentation/chat_providers.dart';

/// Quiet hours (every day), in the device's IANA zone.
@immutable
class QuietHoursPrefs {
  const QuietHoursPrefs({
    this.enabled = false,
    this.start = '22:00',
    this.end = '07:00',
    this.timezone = 'UTC',
    this.allowCalls = true,
  });

  final bool enabled;
  final String start;
  final String end;
  final String timezone;

  /// «Пропускать звонки в тихие часы»: calls still ring.
  final bool allowCalls;

  QuietHoursPrefs copyWith({
    bool? enabled,
    String? start,
    String? end,
    String? timezone,
    bool? allowCalls,
  }) => QuietHoursPrefs(
    enabled: enabled ?? this.enabled,
    start: start ?? this.start,
    end: end ?? this.end,
    timezone: timezone ?? this.timezone,
    allowCalls: allowCalls ?? this.allowCalls,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'start': start,
    'end': end,
    'timezone': timezone,
    'allow_calls': allowCalls,
  };

  factory QuietHoursPrefs.fromJson(Object? raw) {
    if (raw is! Map) return const QuietHoursPrefs();
    String clock(Object? v, String fallback) =>
        v is String && parseClock(v) != null ? v : fallback;
    return QuietHoursPrefs(
      enabled: raw['enabled'] == true,
      start: clock(raw['start'], '22:00'),
      end: clock(raw['end'], '07:00'),
      timezone: raw['timezone'] is String && (raw['timezone'] as String).isNotEmpty
          ? raw['timezone'] as String
          : 'UTC',
      allowCalls: raw['allow_calls'] != false,
    );
  }

  /// Minutes after midnight of "HH:MM", or null.
  static int? parseClock(String s) {
    final m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(s);
    if (m == null) return null;
    final h = int.parse(m[1]!), min = int.parse(m[2]!);
    return h > 23 || min > 59 ? null : h * 60 + min;
  }

  static String formatClock(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is QuietHoursPrefs &&
      other.enabled == enabled &&
      other.start == start &&
      other.end == end &&
      other.timezone == timezone &&
      other.allowCalls == allowCalls;

  @override
  int get hashCode => Object.hash(enabled, start, end, timezone, allowCalls);
}

/// Server-side push preferences (`GET/PUT /me/notification-settings`).
@immutable
class NotificationPreferences {
  const NotificationPreferences({
    this.directMessages = true,
    this.groupMessages = true,
    this.groupMentionsOnly = false,
    this.calls = true,
    this.quietHours = const QuietHoursPrefs(),
    this.channels = true,
  });

  final bool directMessages;
  final bool groupMessages;
  final bool groupMentionsOnly;
  final bool calls;
  final QuietHoursPrefs quietHours;

  /// Posts of subscribed channels (chat-service 0010).
  final bool channels;

  NotificationPreferences copyWith({
    bool? directMessages,
    bool? groupMessages,
    bool? groupMentionsOnly,
    bool? calls,
    QuietHoursPrefs? quietHours,
    bool? channels,
  }) => NotificationPreferences(
    directMessages: directMessages ?? this.directMessages,
    groupMessages: groupMessages ?? this.groupMessages,
    groupMentionsOnly: groupMentionsOnly ?? this.groupMentionsOnly,
    calls: calls ?? this.calls,
    quietHours: quietHours ?? this.quietHours,
    channels: channels ?? this.channels,
  );

  Map<String, Object?> toJson() => {
    'direct_messages': directMessages,
    'group_messages': groupMessages,
    'group_mentions_only': groupMentionsOnly,
    'calls': calls,
    'quiet_hours': quietHours.toJson(),
    'channels': channels,
  };

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        directMessages: json['direct_messages'] != false,
        groupMessages: json['group_messages'] != false,
        groupMentionsOnly: json['group_mentions_only'] == true,
        calls: json['calls'] != false,
        quietHours: QuietHoursPrefs.fromJson(json['quiet_hours']),
        channels: json['channels'] != false,
      );

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.directMessages == directMessages &&
      other.groupMessages == groupMessages &&
      other.groupMentionsOnly == groupMentionsOnly &&
      other.calls == calls &&
      other.quietHours == quietHours &&
      other.channels == channels;

  @override
  int get hashCode => Object.hash(
    directMessages,
    groupMessages,
    groupMentionsOnly,
    calls,
    quietHours,
    channels,
  );
}

class NotificationPreferencesApi {
  NotificationPreferencesApi(this._client);
  final ApiClient _client;

  static const path = '/me/notification-settings';

  Future<NotificationPreferences> fetch() async =>
      NotificationPreferences.fromJson(await _client.getJson(path));

  Future<NotificationPreferences> save(NotificationPreferences p) async =>
      NotificationPreferences.fromJson(
        await _client.putJson(path, body: p.toJson()),
      );
}

/// Last known preferences and whether a local change still has to reach the
/// server (offline edits survive a restart).
class NotificationPreferencesStore {
  NotificationPreferencesStore(this._db);
  final AppDatabase _db;

  static final _store = stringMapStoreFactory.store('settings');
  static const _key = 'notification_prefs';

  Future<({NotificationPreferences prefs, bool dirty})?> read() async {
    final raw = await _store.record(_key).get(_db.db);
    final prefs = raw?['prefs'];
    if (prefs is! Map) return null;
    return (
      prefs: NotificationPreferences.fromJson(Map<String, dynamic>.from(prefs)),
      dirty: raw?['dirty'] == true,
    );
  }

  Future<void> write(NotificationPreferences prefs, {required bool dirty}) =>
      _store.record(_key).put(_db.db, {'prefs': prefs.toJson(), 'dirty': dirty});

  Future<void> clear() => _store.record(_key).delete(_db.db);
}

enum NotificationSyncStatus { loading, synced, pending, failed }

@immutable
class NotificationPreferencesState {
  const NotificationPreferencesState({
    this.prefs = const NotificationPreferences(),
    this.status = NotificationSyncStatus.loading,
    this.hasData = false,
  });

  final NotificationPreferences prefs;
  final NotificationSyncStatus status;

  /// False until the cache or the server answered (show a loader).
  final bool hasData;

  NotificationPreferencesState copyWith({
    NotificationPreferences? prefs,
    NotificationSyncStatus? status,
    bool? hasData,
  }) => NotificationPreferencesState(
    prefs: prefs ?? this.prefs,
    status: status ?? this.status,
    hasData: hasData ?? this.hasData,
  );
}

final notificationPreferencesApiProvider = Provider<NotificationPreferencesApi>(
  (ref) => NotificationPreferencesApi(ref.watch(chatApiClientProvider)),
);

final notificationPreferencesStoreProvider =
    Provider<NotificationPreferencesStore>(
      (ref) => NotificationPreferencesStore(ref.watch(appDatabaseProvider)),
    );

/// Optimistic, offline-safe preferences: every change is shown and cached
/// at once, then sent; a failed send stays pending and is retried when the
/// network returns or the screen is opened again.
class NotificationPreferencesNotifier
    extends Notifier<NotificationPreferencesState> {
  int _generation = 0;

  @override
  NotificationPreferencesState build() {
    ref.listen<bool>(isOnlineProvider, (was, online) {
      if (online && was != true && state.status != NotificationSyncStatus.synced) {
        unawaited(sync());
      }
    });
    Future.microtask(_load);
    return const NotificationPreferencesState();
  }

  NotificationPreferencesApi get _api =>
      ref.read(notificationPreferencesApiProvider);
  NotificationPreferencesStore get _store =>
      ref.read(notificationPreferencesStoreProvider);

  Future<void> _load() async {
    try {
      final cached = await _store.read();
      if (!ref.mounted) return;
      if (cached != null) {
        state = state.copyWith(
          prefs: cached.prefs,
          hasData: true,
          status: cached.dirty
              ? NotificationSyncStatus.pending
              : NotificationSyncStatus.loading,
        );
      }
    } on Object catch (e) {
      DiagnosticLog.warn('notifications', 'prefs cache read failed', error: e);
    }
    await sync();
  }

  /// Pushes a pending local change, otherwise refreshes from the server.
  Future<void> sync() async {
    final generation = _generation;
    try {
      final NotificationPreferences result;
      if (state.status == NotificationSyncStatus.pending ||
          state.status == NotificationSyncStatus.failed && state.hasData) {
        result = await _api.save(state.prefs);
      } else {
        result = await _api.fetch();
      }
      if (!ref.mounted || generation != _generation) return;
      // Persist first, publish second: "synced" must mean the cache no longer
      // carries the pending flag (otherwise a restart right after the UI
      // showed synced would resend, and readers of the store race the write).
      try {
        await _store.write(result, dirty: false);
      } on Object catch (e) {
        DiagnosticLog.warn('notifications', 'prefs cache write failed', error: e);
      }
      // A newer local edit (update) wrote dirty=true meanwhile: it wins.
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        prefs: result,
        status: NotificationSyncStatus.synced,
        hasData: true,
      );
    } on Object catch (e) {
      if (!ref.mounted || generation != _generation) return;
      DiagnosticLog.warn('notifications', 'prefs sync failed', error: e);
      state = state.copyWith(
        status: state.hasData
            ? NotificationSyncStatus.pending
            : NotificationSyncStatus.failed,
      );
    }
  }

  Future<void> update(
    NotificationPreferences Function(NotificationPreferences) change,
  ) async {
    _generation++;
    var next = change(state.prefs);
    // Quiet hours are evaluated in the zone the device is in now.
    final zone = ref.read(deviceZoneProvider);
    if (next.quietHours.timezone != zone) {
      next = next.copyWith(quietHours: next.quietHours.copyWith(timezone: zone));
    }
    state = state.copyWith(
      prefs: next,
      status: NotificationSyncStatus.pending,
      hasData: true,
    );
    try {
      await _store.write(next, dirty: true);
    } on Object catch (e) {
      DiagnosticLog.warn('notifications', 'prefs cache write failed', error: e);
    }
    await sync();
  }
}

final notificationPreferencesProvider =
    NotifierProvider<
      NotificationPreferencesNotifier,
      NotificationPreferencesState
    >(NotificationPreferencesNotifier.new);
