import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/localization/localization.dart';
import '../../../../shared/utils/diagnostic_log.dart';
import '../../data/chat_status.dart';
import '../chat_providers.dart';

/// Statuses with auto-reply: the caller's own status, live status changes
/// of colleagues (`user.status`) and the display helpers.

final chatStatusApiProvider = Provider<ChatStatusApi>(
  (ref) => ChatStatusApi(ref.watch(chatApiClientProvider)),
);

/// The caller's status (`GET /me/status`, with the auto-reply). Reloads when
/// another device of the user changes it.
class MyChatStatusNotifier extends AsyncNotifier<ChatUserStatus?> {
  ChatStatusApi get _api => ref.read(chatStatusApiProvider);

  @override
  Future<ChatUserStatus?> build() async {
    final selfId = ref.watch(currentUserProvider.select((u) => u?.id));
    if (!ref.watch(chatEnabledProvider) || selfId == null) return null;
    final repo = ref.watch(chatRepositoryProvider);
    final sub = repo.events.listen((ev) {
      // The public copy has no auto-reply: fetch the own status again.
      if (ev.type == 'user.status' && ev.userId == selfId) unawaited(reload());
    });
    ref.onDispose(sub.cancel);
    try {
      return await _api.fetch();
    } on AppException catch (e) {
      DiagnosticLog.warn('chat', 'own status unavailable', error: e);
      return null;
    }
  }

  Future<void> reload() async {
    try {
      final s = await _api.fetch();
      if (ref.mounted) state = AsyncData(s);
    } on AppException catch (e) {
      DiagnosticLog.warn('chat', 'own status reload failed', error: e);
    }
  }

  Future<ChatUserStatus?> save(ChatUserStatus status) async {
    final saved = await _api.save(status) ?? status;
    if (ref.mounted) state = AsyncData(saved);
    return saved;
  }

  Future<void> clear() async {
    await _api.clear();
    if (ref.mounted) state = const AsyncData(null);
  }
}

final myChatStatusProvider =
    AsyncNotifierProvider<MyChatStatusNotifier, ChatUserStatus?>(
      MyChatStatusNotifier.new,
    );

/// Status changes received over the socket since start: user id → status
/// (null = cleared). Screens whose data is not in the chat cache (contacts,
/// subscribers) layer these over what they loaded.
class ChatStatusOverridesNotifier
    extends Notifier<Map<String, ChatUserStatus?>> {
  @override
  Map<String, ChatUserStatus?> build() {
    if (!ref.watch(chatEnabledProvider)) return const {};
    final repo = ref.watch(chatRepositoryProvider);
    final sub = repo.events.listen((ev) {
      final withStatus =
          ev.type == 'user.status' ||
          (ev.type == 'presence.changed' && ev.payload.containsKey('status'));
      if (!withStatus || ev.userId.isEmpty) return;
      state = {
        ...state,
        ev.userId: ChatUserStatus.fromJsonOrNull(ev.payload['status']),
      };
    });
    ref.onDispose(sub.cancel);
    return const {};
  }
}

final chatStatusOverridesProvider =
    NotifierProvider<ChatStatusOverridesNotifier, Map<String, ChatUserStatus?>>(
      ChatStatusOverridesNotifier.new,
    );

/// The status to show for [userId]: a live update when one arrived, else
/// [loaded]; expired statuses are hidden.
ChatUserStatus? watchUserStatus(
  WidgetRef ref,
  String userId,
  ChatUserStatus? loaded,
) {
  final (overridden, live) = ref.watch(
    chatStatusOverridesProvider.select(
      (m) => (m.containsKey(userId), m[userId]),
    ),
  );
  final status = overridden ? live : loaded;
  if (status == null || !status.isActiveAt(DateTime.now())) return null;
  return status;
}

/// Labels of statuses: «📅 На совещании · до 15:00».
abstract final class ChatStatusFormat {
  static String presetLabel(AppLocalizations l10n, ChatStatusPreset p) =>
      switch (p) {
        ChatStatusPreset.inClass => l10n.statusPresetInClass,
        ChatStatusPreset.meeting => l10n.statusPresetMeeting,
        ChatStatusPreset.businessTrip => l10n.statusPresetBusinessTrip,
        ChatStatusPreset.vacation => l10n.statusPresetVacation,
        ChatStatusPreset.sick => l10n.statusPresetSick,
        ChatStatusPreset.dnd => l10n.statusPresetDnd,
        ChatStatusPreset.custom => l10n.statusPresetCustom,
      };

  /// The user's text, else the localized preset name (empty for a custom
  /// status with an emoji only).
  static String label(AppLocalizations l10n, ChatUserStatus s) {
    final text = s.text.trim();
    if (text.isNotEmpty) return text;
    return s.preset == ChatStatusPreset.custom ? '' : presetLabel(l10n, s.preset);
  }

  /// «до 15:00» today, «до 20 сент., 09:00» on another day.
  static String until(BuildContext context, DateTime at, {DateTime? now}) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final local = at.toLocal();
    final n = (now ?? DateTime.now()).toLocal();
    final sameDay =
        local.year == n.year && local.month == n.month && local.day == n.day;
    final time = sameDay
        ? DateFormat.Hm(locale).format(local)
        : DateFormat.MMMd(locale).add_Hm().format(local);
    return l10n.statusUntilShort(time);
  }

  /// Emoji, label and (optionally) the end time.
  static String line(
    BuildContext context,
    ChatUserStatus s, {
    bool withUntil = true,
  }) {
    final head = '${s.displayEmoji} ${label(context.l10n, s)}'.trim();
    return [
      head,
      if (withUntil && s.until != null) until(context, s.until!),
    ].join(' · ');
  }
}
