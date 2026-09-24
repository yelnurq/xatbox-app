import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/auth/permissions.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../contacts/data/contact_models.dart';
import '../../notifications/presentation/notifications_providers.dart';
import '../data/official_api.dart';
import '../data/official_cache.dart';
import '../data/official_models.dart';
import '../data/official_repository.dart';
import '../../../core/platform/desktop_layout.dart';

/// Official messages live in the Mail API (same client, token, 401 handling).
final officialApiProvider = Provider<OfficialApi>(
  (ref) => OfficialApi(ref.watch(apiClientProvider)),
);

final officialCacheProvider = Provider<OfficialCache>(
  (ref) => OfficialCache(ref.watch(appDatabaseProvider)),
);

/// Injectable clock for optimistic `read_at` / `acknowledged_at` values.
final officialClockProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);

final officialRepositoryProvider = Provider<OfficialRepository>(
  (ref) => OfficialRepository(
    api: ref.watch(officialApiProvider),
    cache: ref.watch(officialCacheProvider),
    selfId: () => ref.read(currentUserProvider)?.id ?? '',
    clock: ref.watch(officialClockProvider),
  ),
);

/// Signed in with `official.read`: without it every entry point is hidden.
final officialEnabledProvider = Provider<bool>((ref) {
  final signedIn =
      ref.watch(authStateProvider.select((s) => s.status)) ==
      AuthStatus.authenticated;
  // The desktop app has no official-messages page.
  return signedIn && !ref.watch(desktopLayoutProvider) && ref.watch(hasPermissionProvider(Permissions.officialRead));
});

/// What the signed-in user may send (decided from the permission list, not
/// from role names, as the API asks).
class OfficialSendRights {
  const OfficialSendRights({
    this.organization = false,
    this.department = false,
  });

  /// `official.send.organization`: whole organization.
  final bool organization;

  /// `official.send.department`: departments.
  final bool department;

  /// Either permission allows sending to specific users.
  bool get any => organization || department;
}

final officialSendRightsProvider = Provider<OfficialSendRights>((ref) {
  if (!ref.watch(officialEnabledProvider)) return const OfficialSendRights();
  return OfficialSendRights(
    organization: ref.watch(
      hasPermissionProvider(Permissions.officialSendOrganization),
    ),
    department: ref.watch(
      hasPermissionProvider(Permissions.officialSendDepartment),
    ),
  );
});

class OfficialState {
  const OfficialState({
    this.messages = const [],
    this.loading = false,
    this.loaded = false,
    this.fromCache = false,
    this.acknowledging = const {},
    this.error,
    this.savedAt,
  });

  /// Newest first, as the server returns them (≤ 200).
  final List<OfficialMessage> messages;
  final bool loading;
  final bool loaded;
  final bool fromCache;

  /// Ids with an acknowledge request in flight.
  final Set<String> acknowledging;
  final Object? error;
  final DateTime? savedAt;

  int get unread => messages.where((m) => !m.isRead).length;
  int get awaitingAcknowledgement =>
      messages.where((m) => m.awaitsAcknowledgement).length;

  OfficialMessage? byId(String id) =>
      messages.where((m) => m.id == id).firstOrNull;

  OfficialState copyWith({
    List<OfficialMessage>? messages,
    bool? loading,
    bool? loaded,
    bool? fromCache,
    Set<String>? acknowledging,
    Object? error,
    bool clearError = false,
    DateTime? savedAt,
  }) => OfficialState(
    messages: messages ?? this.messages,
    loading: loading ?? this.loading,
    loaded: loaded ?? this.loaded,
    fromCache: fromCache ?? this.fromCache,
    acknowledging: acknowledging ?? this.acknowledging,
    error: clearError ? null : (error ?? this.error),
    savedAt: savedAt ?? this.savedAt,
  );
}

class OfficialNotifier extends Notifier<OfficialState> {
  int _generation = 0;

  OfficialRepository get _repo => ref.read(officialRepositoryProvider);

  @override
  OfficialState build() {
    if (!ref.watch(officialEnabledProvider)) {
      return const OfficialState(loaded: true);
    }
    ref.watch(currentUserProvider.select((u) => u?.id));
    // No Mail API realtime socket in the app: a new unread in-app
    // notification of kind `official` triggers a reload instead.
    ref.listen<int>(
      notificationsProvider.select(
        (s) => s.items.where((n) => n.kind == 'official' && !n.isRead).length,
      ),
      (previous, next) {
        if (next > (previous ?? 0) && state.loaded) unawaited(refresh());
      },
    );
    Future.microtask(_initial);
    return const OfficialState(loading: true);
  }

  Future<void> _initial() async {
    final saved = await _repo.cached();
    if (!ref.mounted) return;
    if (saved != null && !state.loaded) {
      state = OfficialState(
        messages: saved.messages,
        loading: true,
        loaded: true,
        fromCache: true,
        savedAt: saved.savedAt,
      );
    }
    await refresh();
  }

  /// `GET /official` (cache fallback when offline).
  Future<void> refresh() async {
    if (!ref.mounted || !ref.read(officialEnabledProvider)) return;
    final gen = ++_generation;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await _repo.load();
      if (!ref.mounted || gen != _generation) return;
      state = OfficialState(
        messages: result.messages,
        loaded: true,
        fromCache: result.fromCache,
        acknowledging: state.acknowledging,
        error: result.error,
        savedAt: result.savedAt,
      );
    } on AppException catch (e) {
      if (!ref.mounted || gen != _generation) return;
      state = state.copyWith(loading: false, loaded: true, error: e);
    }
  }

  void _replace(OfficialMessage updated) {
    state = state.copyWith(
      messages: [
        for (final m in state.messages) m.id == updated.id ? updated : m,
      ],
    );
    unawaited(_repo.saveList(state.messages));
  }

  /// Optimistic mark-read on open; the call is idempotent, a failure is
  /// logged and corrected by the next refresh.
  Future<void> markRead(String id) async {
    final message = state.byId(id);
    if (message == null || message.isRead) return;
    _replace(message.copyWith(readAt: _repo.now()));
    try {
      await _repo.api.markRead(id);
    } on AppException catch (e) {
      DiagnosticLog.warn('official', 'mark read failed', error: e);
    }
  }

  /// «Ознакомлен(а)». The local state changes only after the server confirmed;
  /// returns the failure (if any) for a snackbar.
  Future<AppException?> acknowledge(String id) async {
    if (state.acknowledging.contains(id)) return null;
    state = state.copyWith(acknowledging: {...state.acknowledging, id});
    try {
      await _repo.api.acknowledge(id);
      if (!ref.mounted) return null;
      final now = _repo.now();
      final message = state.byId(id);
      state = state.copyWith(
        acknowledging: {...state.acknowledging}..remove(id),
      );
      if (message != null) {
        _replace(message.copyWith(acknowledgedAt: now, readAt: now));
      }
      return null;
    } on AppException catch (e) {
      DiagnosticLog.warn('official', 'acknowledge failed', error: e);
      if (ref.mounted) {
        state = state.copyWith(
          acknowledging: {...state.acknowledging}..remove(id),
        );
      }
      return e;
    }
  }
}

final officialProvider = NotifierProvider<OfficialNotifier, OfficialState>(
  OfficialNotifier.new,
);

/// Unread official messages (for the drawer badge); 0 without access.
final officialUnreadBadgeProvider = Provider<int>((ref) {
  if (!ref.watch(officialEnabledProvider)) return 0;
  return ref.watch(officialProvider.select((s) => s.unread));
});

/// Messages the user sent from this device (newest first).
final officialSentProvider = FutureProvider.autoDispose<List<SentOfficial>>((
  ref,
) {
  if (!ref.watch(officialSendRightsProvider).any) return const [];
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.read(officialRepositoryProvider).sent();
});

final officialStatsProvider = FutureProvider.autoDispose
    .family<OfficialStats, String>(
      (ref, id) => ref.read(officialRepositoryProvider).api.stats(id),
    );

/// Active departments for the recipient picker.
final officialDepartmentsProvider =
    FutureProvider.autoDispose<List<Department>>(
      (ref) => ref.read(officialRepositoryProvider).api.departments(),
    );

/// Directory search for the recipient picker (query already debounced).
final officialUserSearchProvider = FutureProvider.autoDispose
    .family<List<Contact>, String>(
      (ref, q) => ref.read(officialRepositoryProvider).api.searchUsers(q),
    );

/// Sign-out hook: wipes the cached list and the local sent list.
Future<void> officialSignOut(ProviderContainer container) =>
    container.read(officialCacheProvider).clear();
