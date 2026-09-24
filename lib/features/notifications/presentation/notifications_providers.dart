import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_session.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../data/notification_models.dart';
import '../data/notifications_api.dart';

/// Notifications live in the Mail API (same client, token and 401 handling).
final notificationsApiProvider = Provider<NotificationsApi>(
  (ref) => NotificationsApi(ref.watch(apiClientProvider)),
);

/// Injectable clock for optimistic `read_at` values.
final notificationsClockProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);

class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.visibleCount = 0,
    this.loading = false,
    this.loaded = false,
    this.markingAll = false,
    this.error,
  });

  /// Everything the server returned (≤ 100, newest first).
  final List<AppNotification> items;

  /// The list endpoint has no pagination: rows are revealed page by page
  /// while scrolling, without extra requests.
  final int visibleCount;
  final bool loading;
  final bool loaded;
  final bool markingAll;
  final Object? error;

  List<AppNotification> get visible =>
      items.take(visibleCount.clamp(0, items.length)).toList();
  bool get hasMore => visibleCount < items.length;
  int get unread => items.where((n) => !n.isRead).length;

  NotificationsState copyWith({
    List<AppNotification>? items,
    int? visibleCount,
    bool? loading,
    bool? loaded,
    bool? markingAll,
    Object? error,
    bool clearError = false,
  }) => NotificationsState(
    items: items ?? this.items,
    visibleCount: visibleCount ?? this.visibleCount,
    loading: loading ?? this.loading,
    loaded: loaded ?? this.loaded,
    markingAll: markingAll ?? this.markingAll,
    error: clearError ? null : (error ?? this.error),
  );
}

class NotificationsNotifier extends Notifier<NotificationsState> {
  static const pageSize = 20;

  NotificationsApi get _api => ref.read(notificationsApiProvider);

  @override
  NotificationsState build() {
    final signedIn =
        ref.watch(authStateProvider.select((s) => s.status)) ==
        AuthStatus.authenticated;
    if (!signedIn) return const NotificationsState();
    Future.microtask(refresh);
    return const NotificationsState(loading: true);
  }

  /// `GET /notifications`. Keeps already revealed rows visible.
  Future<void> refresh() async {
    if (!ref.mounted) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await _api.list();
      if (!ref.mounted) return;
      final visible = state.visibleCount < pageSize
          ? pageSize
          : state.visibleCount;
      state = NotificationsState(
        items: page.items,
        visibleCount: visible.clamp(0, page.items.length),
        loaded: true,
      );
    } on AppException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, loaded: true, error: e);
    }
  }

  /// Reveals the next page of the already loaded list.
  void loadMore() {
    if (!state.hasMore) return;
    state = state.copyWith(
      visibleCount: (state.visibleCount + pageSize).clamp(
        0,
        state.items.length,
      ),
    );
  }

  /// Optimistic mark-read; the server call is idempotent, failures are logged
  /// and corrected by the next refresh.
  Future<void> markRead(String id) async {
    final index = state.items.indexWhere((n) => n.id == id);
    if (index < 0 || state.items[index].isRead) return;
    final now = ref.read(notificationsClockProvider)();
    state = state.copyWith(
      items: [
        for (final n in state.items) n.id == id ? n.markedRead(now) : n,
      ],
    );
    try {
      await _api.markRead(id);
    } on AppException catch (e) {
      DiagnosticLog.warn('notifications', 'mark read failed', error: e);
    }
  }

  /// `POST /notifications/read-all`. Returns the failure (if any) for a
  /// snackbar; the local list is only changed after the server confirmed.
  Future<AppException?> markAllRead() async {
    if (state.markingAll) return null;
    state = state.copyWith(markingAll: true);
    try {
      await _api.markAllRead();
      if (!ref.mounted) return null;
      final now = ref.read(notificationsClockProvider)();
      state = state.copyWith(
        items: [for (final n in state.items) n.markedRead(now)],
        markingAll: false,
      );
      return null;
    } on AppException catch (e) {
      DiagnosticLog.warn('notifications', 'read-all failed', error: e);
      if (ref.mounted) state = state.copyWith(markingAll: false);
      return e;
    }
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(
      NotificationsNotifier.new,
    );

/// Unread badge (among the latest 100, as the API counts it).
final notificationsUnreadBadgeProvider = Provider<int>((ref) {
  if (ref.watch(authStateProvider.select((s) => s.status)) !=
      AuthStatus.authenticated) {
    return 0;
  }
  return ref.watch(notificationsProvider.select((s) => s.unread));
});
