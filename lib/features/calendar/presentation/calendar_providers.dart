import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/link_router.dart';
import '../../../core/routing/routes.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../calls/data/meetings.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/calendar_api.dart';
import '../data/calendar_cache.dart';
import '../data/calendar_models.dart';
import '../data/calendar_ops.dart';
import '../data/calendar_reminders.dart';
import '../data/calendar_repository.dart';
import '../data/local_reminder_scheduler.dart';
import '../domain/calendar_time.dart';

// ---------------------------------------------------------------------------
// Wiring
// ---------------------------------------------------------------------------

final calendarEnabledProvider = Provider<bool>(
  (ref) => ref.watch(hasPermissionProvider(Permissions.calendarRead)),
);

final calendarCanCreateProvider = Provider<bool>(
  (ref) => ref.watch(hasPermissionProvider(Permissions.calendarCreate)),
);

final calendarApiProvider = Provider<CalendarApi>(
  (ref) => CalendarApi(ref.watch(apiClientProvider)),
);

/// Chat Service relay for realtime/push to colleagues; absent without chat.
final calendarRelayProvider = Provider<CalendarRelay>(
  (ref) => CalendarRelay(
    ref.watch(chatEnabledProvider) ? ref.watch(chatApiClientProvider) : null,
  ),
);

final calendarCacheProvider = Provider<CalendarCache>(
  (ref) => CalendarCache(ref.watch(appDatabaseProvider)),
);

final calendarClockProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  final repo = CalendarRepository(
    api: ref.watch(calendarApiProvider),
    cache: ref.watch(calendarCacheProvider),
    relay: ref.watch(calendarRelayProvider),
    selfId: () => ref.read(currentUserProvider)?.id ?? '',
    clock: ref.watch(calendarClockProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

// ---------------------------------------------------------------------------
// Device zone
// ---------------------------------------------------------------------------

/// Looked up once in main before the first frame (no flash of UTC times).
final initialDeviceZoneProvider = Provider<String>((_) => 'UTC');

Future<String> readDeviceZone() async {
  CalendarZones.ensureInitialized();
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    if (CalendarZones.isKnown(info.identifier)) return info.identifier;
  } on Object catch (e) {
    DiagnosticLog.warn('calendar', 'device zone lookup failed', error: e);
  }
  return 'UTC';
}

/// IANA zone of the device; refreshed when the app resumes, so a zone change
/// in system settings re-renders every time without a restart.
class DeviceZoneNotifier extends Notifier<String> {
  @override
  String build() => ref.watch(initialDeviceZoneProvider);

  Future<void> refresh() async {
    final zone = await readDeviceZone();
    if (ref.mounted && zone != state) state = zone;
  }

  void set(String zone) => state = zone;
}

final deviceZoneProvider = NotifierProvider<DeviceZoneNotifier, String>(
  DeviceZoneNotifier.new,
);

final deviceLocationProvider = Provider<tz.Location>(
  (ref) => CalendarZones.location(ref.watch(deviceZoneProvider)),
);

/// Today in the device zone.
final calendarTodayProvider = Provider<CalendarDate>(
  (ref) => EventTime.dateIn(
    ref.watch(calendarClockProvider)(),
    ref.watch(deviceLocationProvider),
  ),
);

// ---------------------------------------------------------------------------
// View state (survives leaving the screen: mode and selected date)
// ---------------------------------------------------------------------------

enum CalendarViewMode { month, week, day, agenda }

class CalendarViewState {
  const CalendarViewState({required this.mode, required this.selected});
  final CalendarViewMode mode;
  final CalendarDate selected;

  CalendarViewState copyWith({CalendarViewMode? mode, CalendarDate? selected}) =>
      CalendarViewState(
        mode: mode ?? this.mode,
        selected: selected ?? this.selected,
      );
}

class CalendarViewNotifier extends Notifier<CalendarViewState> {
  @override
  CalendarViewState build() => CalendarViewState(
    mode: CalendarViewMode.month,
    selected: ref.read(calendarTodayProvider),
  );

  /// Switching the view keeps the selected date.
  void setMode(CalendarViewMode mode) => state = state.copyWith(mode: mode);
  void select(CalendarDate date) => state = state.copyWith(selected: date);
  void today() => select(ref.read(calendarTodayProvider));

  void shift(int step) {
    final d = state.selected;
    select(switch (state.mode) {
      CalendarViewMode.month => d.addMonths(step),
      CalendarViewMode.week => d.addDays(7 * step),
      CalendarViewMode.day => d.addDays(step),
      CalendarViewMode.agenda => d.addDays(30 * step),
    });
  }
}

final calendarViewProvider =
    NotifierProvider<CalendarViewNotifier, CalendarViewState>(
      CalendarViewNotifier.new,
    );

// ---------------------------------------------------------------------------
// Sync
// ---------------------------------------------------------------------------

class CalendarSyncState {
  const CalendarSyncState({
    this.syncing = false,
    this.offline = false,
    this.error,
    this.lastSync,
  });
  final bool syncing;
  final bool offline;
  final Object? error;
  final DateTime? lastSync;
}

class CalendarSyncNotifier extends Notifier<CalendarSyncState> {
  @override
  CalendarSyncState build() => const CalendarSyncState();

  Future<void> sync({CalendarDate? around}) async {
    if (state.syncing) return;
    final repo = ref.read(calendarRepositoryProvider);
    state = CalendarSyncState(syncing: true, lastSync: state.lastSync);
    try {
      await repo.sync(
        around: around ?? ref.read(calendarViewProvider).selected,
        device: ref.read(deviceLocationProvider),
      );
      if (ref.mounted) {
        state = CalendarSyncState(lastSync: ref.read(calendarClockProvider)());
      }
    } on NetworkException catch (e) {
      if (ref.mounted) {
        state = CalendarSyncState(
          offline: true,
          error: e,
          lastSync: state.lastSync,
        );
      }
    } on AppException catch (e) {
      DiagnosticLog.warn('calendar', 'sync failed', error: e);
      if (ref.mounted) {
        state = CalendarSyncState(error: e, lastSync: state.lastSync);
      }
    }
  }

  /// Loads a month the user navigated to if it is not cached yet.
  Future<void> ensureMonth(CalendarDate date) async {
    final repo = ref.read(calendarRepositoryProvider);
    if (await repo.hasMonth(date.year, date.month)) return;
    try {
      await repo.refreshMonth(date.year, date.month);
    } on NetworkException catch (e) {
      if (ref.mounted) {
        state = CalendarSyncState(offline: true, error: e, lastSync: state.lastSync);
      }
    } on AppException catch (e) {
      DiagnosticLog.warn('calendar', 'month load failed', error: e);
    }
  }
}

final calendarSyncProvider =
    NotifierProvider<CalendarSyncNotifier, CalendarSyncState>(
      CalendarSyncNotifier.new,
    );

// ---------------------------------------------------------------------------
// Data for screens (re-read from the cache on every repository change)
// ---------------------------------------------------------------------------

typedef CalendarRange = ({CalendarDate from, CalendarDate to});

abstract class _RepoWatcher<T> extends Notifier<AsyncValue<T>> {
  StreamSubscription<void>? _sub;

  Future<T> read(CalendarRepository repo, tz.Location device);

  @override
  AsyncValue<T> build() {
    final repo = ref.watch(calendarRepositoryProvider);
    ref.watch(deviceLocationProvider);
    _sub?.cancel();
    _sub = repo.changes.listen((_) => reload());
    ref.onDispose(() => _sub?.cancel());
    Future.microtask(reload);
    return AsyncLoading<T>();
  }

  Future<void> reload() async {
    try {
      final value = await read(
        ref.read(calendarRepositoryProvider),
        ref.read(deviceLocationProvider),
      );
      if (ref.mounted) state = AsyncData(value);
    } on Object catch (e, st) {
      if (ref.mounted) state = AsyncError(e, st);
    }
  }
}

class CalendarRangeNotifier extends _RepoWatcher<List<CalendarOccurrence>> {
  CalendarRangeNotifier(this.range);
  final CalendarRange range;

  @override
  Future<List<CalendarOccurrence>> read(
    CalendarRepository repo,
    tz.Location device,
  ) => repo.occurrences(from: range.from, to: range.to, device: device);
}

final calendarRangeProvider = NotifierProvider.autoDispose
    .family<
      CalendarRangeNotifier,
      AsyncValue<List<CalendarOccurrence>>,
      CalendarRange
    >(CalendarRangeNotifier.new);

class CalendarInvitationsNotifier
    extends _RepoWatcher<List<CalendarOccurrence>> {
  @override
  Future<List<CalendarOccurrence>> read(
    CalendarRepository repo,
    tz.Location device,
  ) => repo.invitations(device: device);
}

final calendarInvitationsProvider =
    NotifierProvider<
      CalendarInvitationsNotifier,
      AsyncValue<List<CalendarOccurrence>>
    >(CalendarInvitationsNotifier.new);

/// Badge on the calendar entry: invitations waiting for an answer.
final calendarBadgeProvider = Provider<int>((ref) {
  if (ref.watch(authStateProvider).status != AuthStatus.authenticated ||
      !ref.watch(calendarEnabledProvider)) {
    return 0;
  }
  return ref.watch(calendarInvitationsProvider).value?.length ?? 0;
});

class CalendarProblemsNotifier extends _RepoWatcher<List<CalendarOp>> {
  @override
  Future<List<CalendarOp>> read(CalendarRepository repo, tz.Location device) =>
      repo.problems();
}

final calendarProblemsProvider =
    NotifierProvider<CalendarProblemsNotifier, AsyncValue<List<CalendarOp>>>(
      CalendarProblemsNotifier.new,
    );

/// Ticks on every repository change (for FutureProviders that must refresh).
final calendarChangesProvider = StreamProvider<int>((ref) {
  var n = 0;
  return ref.watch(calendarRepositoryProvider).changes.map((_) => ++n);
});

class CalendarCachedMonthsNotifier extends _RepoWatcher<Set<String>> {
  @override
  Future<Set<String>> read(CalendarRepository repo, tz.Location device) async =>
      (await repo.cache.windowKeys()).toSet();
}

final calendarCachedMonthsProvider =
    NotifierProvider<CalendarCachedMonthsNotifier, AsyncValue<Set<String>>>(
      CalendarCachedMonthsNotifier.new,
    );

/// The occurrence behind `/calendar/event/:id?occ=` (deep link, reminder
/// tap, or after an edit); falls back to the stored event.
final calendarOccurrenceProvider = FutureProvider.autoDispose
    .family<CalendarOccurrence?, (String, String?)>((ref, key) async {
      ref.watch(calendarChangesProvider);
      final repo = ref.watch(calendarRepositoryProvider);
      final device = ref.watch(deviceLocationProvider);
      final (id, occ) = key;
      var at = EventTime.parse(occ);
      CalendarEventDetail? detail;
      if (at == null && !id.startsWith('local:')) {
        detail = await repo.detail(id);
        at = detail?.event.startsAt;
      }
      if (at != null) {
        final day = EventTime.dateIn(at, device);
        final list = await repo.occurrences(
          from: day.addDays(-1),
          to: day.addDays(2),
          device: device,
        );
        final hit = list
            .where(
              (o) =>
                  o.event.id == id &&
                  (occ == null || o.event.occurrenceStartRaw == occ),
            )
            .firstOrNull;
        if (hit != null) return hit;
      }
      final e = detail?.event;
      if (e == null) return null;
      if (e.allDay) {
        final (first, end) = EventTime.allDayRange(
          e.startsAt,
          e.endsAt,
          CalendarZones.location(e.timezone),
        );
        return CalendarOccurrence(
          event: e,
          start: e.startsAt,
          end: e.endsAt,
          allDayStart: first,
          allDayEnd: end,
        );
      }
      return CalendarOccurrence(event: e, start: e.startsAt, end: e.endsAt);
    });

final calendarSearchProvider = FutureProvider.autoDispose
    .family<List<CalendarOccurrence>, String>(
      (ref, q) => ref
          .watch(calendarRepositoryProvider)
          .search(q, device: ref.watch(deviceLocationProvider)),
    );

final calendarDetailProvider = FutureProvider.autoDispose
    .family<CalendarEventDetail?, String>(
      (ref, id) =>
          ref.watch(calendarRepositoryProvider).detail(id, refresh: true),
    );

/// Bookable rooms of the organization (only `active` ones).
final calendarResourcesProvider =
    FutureProvider.autoDispose<List<CalendarResource>>((ref) async {
      final all = await ref.watch(calendarApiProvider).resources();
      return all.where((r) => r.isActive).toList();
    });

final calendarLocalRemindersProvider = FutureProvider.autoDispose
    .family<List<int>?, String>(
      (ref, key) => ref.watch(calendarCacheProvider).reminders(key),
    );

// ---------------------------------------------------------------------------
// Reminders, notification taps, lifecycle
// ---------------------------------------------------------------------------

/// `<event id>|<occurrence start>` requested by a reminder tap; the app root
/// navigates to the event.
final calendarOpenRequestProvider =
    NotifierProvider<_CalendarOpenRequest, String?>(_CalendarOpenRequest.new);

class _CalendarOpenRequest extends Notifier<String?> {
  @override
  String? build() => null;
  void request(String? payload) => state = payload;
}

AppLocalizations _systemL10n() {
  final code = Platform.localeName.split(RegExp('[_-]')).first;
  final supported = AppLocalization.supportedLocales.map((l) => l.languageCode);
  return lookupAppLocalizations(
    Locale(supported.contains(code) ? code : 'ru'),
  );
}

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final l10n = _systemL10n();
  return LocalReminderScheduler(
    channelName: l10n.calendarReminderChannel,
    channelDescription: l10n.calendarReminderChannelDescription,
    onOpen: (payload) {
      // Meeting reminder («Подключиться» or a tap): the pre-join screen.
      if (payload.startsWith(ReminderPlanner.meetingPayloadPrefix)) {
        final code = payload.substring(ReminderPlanner.meetingPayloadPrefix.length);
        ref.read(pendingNavigationProvider.notifier).request(Routes.meetPath(code));
        return;
      }
      ref.read(calendarOpenRequestProvider.notifier).request(payload);
    },
  );
});

final calendarReminderServiceProvider = Provider<CalendarReminderService>(
  (ref) => CalendarReminderService(
    scheduler: ref.watch(reminderSchedulerProvider),
    cache: ref.watch(calendarCacheProvider),
  ),
);

String _reminderBody(CalendarOccurrence o, tz.Location device) {
  String two(int v) => v.toString().padLeft(2, '0');
  final place = o.event.location.isEmpty ? '' : ' · ${o.event.location}';
  if (o.allDay) return '${o.allDayStart}$place';
  final s = EventTime.inZone(o.start, device);
  final e = EventTime.inZone(o.end, device);
  return '${two(s.hour)}:${two(s.minute)}–${two(e.hour)}:${two(e.minute)}$place';
}

/// Plans local notifications for the next two weeks from the cache.
Future<void> rescheduleCalendarReminders(Ref ref) async {
  final repo = ref.read(calendarRepositoryProvider);
  final device = ref.read(deviceLocationProvider);
  final now = ref.read(calendarClockProvider)().toUtc();
  final today = EventTime.dateIn(now, device);
  final occurrences = await repo.occurrences(
    from: today,
    to: today.addDays(15),
    device: device,
  );
  final plan = ReminderPlanner.plan(
    occurrences: occurrences,
    localReminders: await repo.cache.allReminders(),
    now: now,
    device: device,
    describe: (o) => _reminderBody(o, device),
    meetingCodeOf: (e) => XatBoxMeetingLinks.meetingCodeIn('${e.meetingLink}\n${e.description}'),
    meetingBody: _systemL10n().calendarMeetingReminderBody,
    joinLabel: _systemL10n().meetingJoin,
  );
  await ref.read(calendarReminderServiceProvider).apply(plan);
}

/// Watched from the app root: first sync after sign-in, sync on resume and on
/// `calendar.changed` frames of the chat socket, reminders after changes.
final calendarLifecycleProvider = Provider<void>((ref) {
  if (ref.watch(authStateProvider).status != AuthStatus.authenticated ||
      !ref.watch(calendarEnabledProvider)) {
    return;
  }
  final repo = ref.watch(calendarRepositoryProvider);
  Timer? remindersTimer;
  Timer? syncTimer;

  void reminders() {
    remindersTimer?.cancel();
    remindersTimer = Timer(const Duration(seconds: 2), () {
      unawaited(
        rescheduleCalendarReminders(ref).catchError(
          (Object e) =>
              DiagnosticLog.warn('calendar', 'reminders failed', error: e),
        ),
      );
    });
  }

  void syncSoon() {
    syncTimer?.cancel();
    syncTimer = Timer(
      const Duration(seconds: 1),
      () => unawaited(ref.read(calendarSyncProvider.notifier).sync()),
    );
  }

  final changes = repo.changes.listen((_) => reminders());
  StreamSubscription<Object?>? chatFrames;
  if (ref.read(chatEnabledProvider)) {
    chatFrames = ref
        .read(chatRepositoryProvider)
        .events
        .where((e) => e.type == 'calendar.changed')
        .listen((_) => syncSoon());
  }
  final lifecycle = AppLifecycleListener(
    onResume: () async {
      await ref.read(deviceZoneProvider.notifier).refresh();
      syncSoon();
    },
  );
  Future.microtask(() {
    unawaited(ref.read(calendarSyncProvider.notifier).sync());
    reminders();
  });
  ref.onDispose(() {
    remindersTimer?.cancel();
    syncTimer?.cancel();
    changes.cancel();
    chatFrames?.cancel();
    lifecycle.dispose();
  });
});

/// Sign-out hook: cancel scheduled reminders, wipe calendar data.
Future<void> calendarSignOut(ProviderContainer container) async {
  try {
    await container.read(calendarReminderServiceProvider).clear();
  } on Object catch (e) {
    DiagnosticLog.warn('calendar', 'reminder cleanup failed', error: e);
  }
  await container.read(calendarRepositoryProvider).clear();
}
