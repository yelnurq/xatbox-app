import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop_layout.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/error_text.dart';
import '../../../shared/widgets/ds/x_badge.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/split_pane.dart';
import '../../../shared/widgets/state_view.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../search/presentation/unified_search_button.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/call_models.dart';
import 'call_details_screen.dart';
import 'calls_format.dart';
import 'calls_providers.dart';
import 'meetings_section.dart';
import 'widgets/call_stage.dart';
import 'widgets/call_style.dart';

/// Root of the "Звонки" tab (ТЗ п.24.9): history grouped by day, missed
/// filter with its counter, call back, new audio/video call.
class CallsScreen extends ConsumerStatefulWidget {
  const CallsScreen({super.key});

  @override
  ConsumerState<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends ConsumerState<CallsScreen> {
  bool _missed = false;

  /// The call card open in the right pane of the wide layout.
  CallInfo? _selected;

  void _open(CallInfo call) {
    if (context.isExpanded) {
      setState(() => _selected = call);
      return;
    }
    context.push(Routes.callDetailsPath(call.id), extra: call);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted || !ref.read(callsEnabledProvider)) return;
      // Asked in context: the user opened calls, incoming calls need it.
      unawaited(ref.read(callNativeProvider).requestIncomingCallPermissions());
    });
  }

  void _setMissed(bool v) {
    setState(() => _missed = v);
    if (v) unawaited(ref.read(missedCallsProvider.notifier).markSeen());
  }

  @override
  Widget build(BuildContext context) {
    final list = _list(context);
    if (!context.isExpanded || !ref.watch(callsEnabledProvider)) return list;
    final selected = _selected;
    return SplitPane(
      list: list,
      placeholderTitle: context.l10n.callsSelect,
      placeholderIcon: LucideIcons.phoneCall,
      detail: selected == null
          ? null
          : CallDetailsScreen(key: ValueKey('pane_${selected.id}'), callId: selected.id, initial: selected),
    );
  }

  Widget _list(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final enabled = ref.watch(callsEnabledProvider);
    final missedCount = enabled ? ref.watch(missedCallsProvider) : 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabCalls),
        actions: [
          const UnifiedSearchButton(),
          const NotificationsBellButton(),
          // Desktop: no pull to refresh with a mouse.
          if (enabled && ref.watch(desktopLayoutProvider))
            IconButton(
              key: const Key('calls_refresh'),
              tooltip: l10n.desktopRefresh,
              icon: const Icon(LucideIcons.refreshCw),
              onPressed: () => ref.read(callsHistoryProvider(_missed).notifier).refresh(),
            ),
          if (enabled)
            IconButton(
              key: const Key('calls_new'),
              tooltip: l10n.callsNew,
              icon: const Icon(LucideIcons.phone),
              // Desktop: a dialog over the list, not a page.
              onPressed: ref.watch(desktopLayoutProvider) ? () => showNewCallDialog(context) : () => context.push(Routes.callsNew),
            ),
        ],
      ),
      body: !enabled
          ? StateView.empty(title: l10n.callsDisabled, icon: LucideIcons.phone)
          : Column(
              children: [
                const _ActiveCallBanner(),
                const CallsMeetingsSection(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.xs),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: false, label: Text(l10n.callsFilterAll)),
                        ButtonSegment(
                          value: true,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  l10n.callsFilterMissed,
                                  key: const Key('calls_filter_missed'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (missedCount > 0) ...[
                                const SizedBox(width: Space.xs + 2),
                                CountPill(missedCount, key: const Key('calls_missed_count'), color: t.danger, background: t.dangerSoft),
                              ],
                            ],
                          ),
                        ),
                      ],
                      selected: {_missed},
                      onSelectionChanged: (s) => _setMissed(s.first),
                    ),
                  ),
                ),
                Expanded(
                  child: _History(
                    missed: _missed,
                    onOpen: _open,
                    selectedId: ref.watch(desktopLayoutProvider) && context.isExpanded ? _selected?.id : null,
                  ),
                ),
              ],
            ),
    );
  }
}

/// The running call as a card at the top of the tab.
class _ActiveCallBanner extends ConsumerWidget {
  const _ActiveCallBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inCall = ref.watch(callControllerProvider.select((s) => s.inCall));
    if (!inCall) return const SizedBox.shrink();
    final t = context.tokens;
    final pal = context.callPalette;
    final l10n = context.l10n;
    final title = ref.watch(callHeroProvider.select((h) => h.title));
    final radius = BorderRadius.circular(t.radiusLg);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [pal.bgTop, pal.bgBottom]),
          borderRadius: radius,
          boxShadow: t.shadowSm,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const Key('active_call_banner'),
            borderRadius: radius,
            onTap: () => context.push(Routes.call),
            child: Semantics(
              label: l10n.callsActiveBanner,
              child: Padding(
                padding: const EdgeInsets.all(Space.smd),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: pal.success, shape: BoxShape.circle),
                      child: const Icon(LucideIcons.phoneCall, size: 18, color: CallPalette.ink),
                    ),
                    const SizedBox(width: Space.smd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.isEmpty ? l10n.callsActiveBanner : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: CallPalette.ink, fontWeight: FontWeight.w600),
                          ),
                          CallStatusLine(withKeys: false, style: TextStyle(color: pal.inkSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(l10n.callsReturnToCall, style: TextStyle(color: pal.inkSecondary, fontSize: 12)),
                    const SizedBox(width: Space.xs),
                    Icon(LucideIcons.chevronRight, color: pal.inkSecondary, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Day {
  const _Day(this.day);
  final DateTime day;
}

class _History extends ConsumerWidget {
  const _History({required this.missed, required this.onOpen, this.selectedId});
  final bool missed;
  final void Function(CallInfo) onOpen;

  /// Desktop: the call open in the right pane (its row is highlighted).
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(callsHistoryProvider(missed));
    final notifier = ref.read(callsHistoryProvider(missed).notifier);
    if (!state.loaded) return const StateView.loading();
    if (state.calls.isEmpty) {
      if (state.error != null) {
        return ErrorText.isOffline(state.error)
            ? StateView.offline(message: ErrorText.describe(l10n, state.error!), onRetry: notifier.refresh)
            : StateView.error(message: CallsFormat.error(l10n, state.error!), onRetry: notifier.refresh);
      }
      return RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 360,
              child: StateView.empty(
                title: missed ? l10n.callsMissedEmpty : l10n.callsEmpty,
                icon: missed ? LucideIcons.phoneMissed : LucideIcons.phone,
              ),
            ),
          ],
        ),
      );
    }
    // Day headers between rows (the list is newest first).
    final items = <Object>[];
    DateTime? lastDay;
    for (final c in state.calls) {
      final local = c.createdAt?.toLocal();
      final day = local == null ? null : DateTime(local.year, local.month, local.day);
      if (day != null && day != lastDay) items.add(_Day(day));
      if (day != null) lastDay = day;
      items.add(c);
    }
    return Column(
      children: [
        // Saved first page while the server is unreachable.
        if (state.error != null && ErrorText.isOffline(state.error))
          OfflineBanner(key: const Key('calls_offline_banner'), text: l10n.offlineBanner, onRetry: notifier.refresh),
        Expanded(
          child: RefreshIndicator(
            onRefresh: notifier.refresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.extentAfter < 300) unawaited(notifier.loadMore());
                return false;
              },
              child: ListView.builder(
                key: const Key('calls_history'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: Space.xl),
                itemCount: items.length,
                itemBuilder: (_, i) => switch (items[i]) {
                  final CallInfo c => _CallTile(call: c, onOpen: onOpen, selected: c.id == selectedId),
                  final _Day d => _DayHeader(day: d.day),
                  _ => const SizedBox.shrink(),
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
      child: Text(
        CallsFormat.day(context, day),
        style: TextStyle(color: t.textTertiary, fontSize: t.display.fontSizeMeta, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
    );
  }
}

class _CallTile extends ConsumerWidget {
  const _CallTile({required this.call, required this.onOpen, this.selected = false});
  final CallInfo call;
  final void Function(CallInfo) onOpen;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final selfId = ref.watch(currentUserProvider)?.id ?? '';
    final missed = call.outcome == CallOutcome.missed;
    final outgoing = call.isOutgoingFor(selfId);
    final title = call.displayTitle(selfId);
    final other = call.others(selfId).firstOrNull;
    final subtitle = [
      CallsFormat.outcome(l10n, call, selfId),
      if (call.durationSec > 0) CallsFormat.duration(Duration(seconds: call.durationSec)),
    ].join(' · ');
    final directionColor = missed ? t.danger : t.textTertiary;

    final Widget avatar = call.isGroup
        ? Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: t.primarySoft, shape: BoxShape.circle),
            child: Icon(LucideIcons.users, size: 20, color: t.primary),
          )
        : (other != null && other.email.isNotEmpty
              ? UserAvatar(email: other.email, label: title, radius: 22)
              : InitialsAvatar(label: title, colorKey: other?.userId ?? call.id, radius: 22));

    final tile = InkWell(
      key: ValueKey('call_${call.id}'),
      // Row tap: the call card (ТЗ п.24.9); the trailing button calls back.
      onTap: () => onOpen(call),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: t.display.rowMinHeight + 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.sm, Space.sm),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  avatar,
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: missed ? t.dangerSoft : t.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.surface, width: 2),
                      ),
                      child: Icon(
                        missed ? LucideIcons.phoneMissed : (outgoing ? LucideIcons.phoneOutgoing : LucideIcons.phoneIncoming),
                        size: 11,
                        color: directionColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: Space.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: missed ? t.danger : t.textPrimary,
                        fontSize: t.display.fontSizeBase,
                        fontWeight: missed ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: Space.xxs),
                    Row(
                      children: [
                        if (call.isVideo) ...[
                          Icon(LucideIcons.video, size: 14, color: t.textTertiary),
                          const SizedBox(width: Space.xs),
                        ],
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: missed ? t.danger : t.textSecondary, fontSize: t.display.fontSizeMeta + 1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              Text(
                CallsFormat.time(context, call.createdAt),
                style: TextStyle(
                  color: t.textTertiary,
                  fontSize: t.display.fontSizeMeta,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: Space.xs),
              IconButton(
                key: ValueKey('redial_${call.id}'),
                tooltip: l10n.callsRedial,
                style: IconButton.styleFrom(backgroundColor: t.primarySoft, foregroundColor: t.primary),
                icon: Icon(call.isVideo ? LucideIcons.video : LucideIcons.phone, size: 18),
                onPressed: () => startCallFromUi(
                  context,
                  ref,
                  calleeIds: call.others(selfId).map((p) => p.userId).toList(),
                  video: call.isVideo,
                  conversationId: call.conversationId,
                  mode: call.mode,
                  title: call.title.isEmpty ? null : call.title,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Desktop split pane: the open call's row, as the chat list's.
    return selected ? Material(color: t.primarySoft, child: tile) : tile;
  }
}

/// Starts a call and opens the call screen; shows the permission hint.
Future<void> startCallFromUi(
  BuildContext context,
  WidgetRef ref, {
  required List<String> calleeIds,
  required bool video,
  String? conversationId,
  String? mode,
  String? title,
}) async {
  if (!ref.read(callsEnabledProvider)) return;
  final router = GoRouter.of(context);
  final future = ref.read(callControllerProvider.notifier).startCall(
    calleeIds: calleeIds,
    video: video,
    conversationId: conversationId,
    mode: mode,
    title: title,
  );
  unawaited(router.push(Routes.call));
  await future;
}

/// Desktop: «Новый звонок» as a dialog over the calls list (its header
/// button, C and Ctrl+N), with «Позвонить» in the footer.
Future<void> showNewCallDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (ctx) => Dialog(
    key: const Key('new_call_dialog'),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      width: 560,
      height: math.min(640.0, MediaQuery.sizeOf(ctx).height * 0.85),
      child: const NewCallScreen(dialog: true),
    ),
  ),
);

/// Pick colleagues from the same directory as chat and call them; a group
/// call can get a title.
class NewCallScreen extends ConsumerStatefulWidget {
  const NewCallScreen({super.key, this.dialog = false});

  /// Inside [showNewCallDialog] (desktop): a title row with ✕ instead of
  /// the app bar, the call buttons in the footer.
  final bool dialog;

  @override
  ConsumerState<NewCallScreen> createState() => _NewCallScreenState();
}

class _NewCallScreenState extends ConsumerState<NewCallScreen> {
  Timer? _debounce;
  String _query = '';
  final Map<String, String> _selected = {};
  final _title = TextEditingController();

  /// The dialog's «С видео».
  bool _video = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    super.dispose();
  }

  Future<void> _call(bool video) async {
    final ids = _selected.keys.toList();
    if (ids.isEmpty) return;
    final group = ids.length > 1;
    final title = _title.text.trim();
    final router = GoRouter.of(context);
    final future = ref.read(callControllerProvider.notifier).startCall(
      calleeIds: ids,
      video: video,
      mode: group ? 'group' : 'direct',
      title: group && title.isNotEmpty ? title : null,
    );
    if (widget.dialog) {
      Navigator.of(context).pop();
      unawaited(router.push(Routes.call));
    } else {
      router.pushReplacement(Routes.call);
    }
    await future;
  }

  Widget _dialogHeader(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.mlg, Space.md, Space.sm, Space.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.callsNew,
              style: TextStyle(fontFamily: t.fontDisplay, fontSize: 18, fontWeight: FontWeight.w600, color: t.textPrimary),
            ),
          ),
          IconButton(
            key: const Key('new_call_close'),
            tooltip: l10n.close,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.x, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _dialogFooter(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final ready = _selected.isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border, width: t.borderWidth))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.sm, Space.smd, Space.md, Space.smd),
        child: Row(
          children: [
            Flexible(
              child: InkWell(
                key: const Key('new_call_with_video'),
                borderRadius: t.controlRadius,
                onTap: () => setState(() => _video = !_video),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(value: _video, onChanged: (v) => setState(() => _video = v == true)),
                    Flexible(
                      child: Text(l10n.desktopCallWithVideo, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.textPrimary)),
                    ),
                    const SizedBox(width: Space.sm),
                  ],
                ),
              ),
            ),
            const Spacer(),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
            const SizedBox(width: Space.sm),
            FilledButton.icon(
              key: const Key('new_call_start'),
              onPressed: ready ? () => _call(_video) : null,
              icon: Icon(_video ? LucideIcons.video : LucideIcons.phone, size: 18),
              label: Text(l10n.desktopCallStart),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(String id, String label, bool on) => setState(() {
    if (on) {
      _selected[id] = label;
    } else {
      _selected.remove(id);
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final selfId = ref.watch(currentUserProvider)?.id ?? '';
    final users = ref.watch(chatUserSearchProvider(_query));
    return Scaffold(
      appBar: widget.dialog ? null : AppBar(title: Text(l10n.callsNew)),
      backgroundColor: widget.dialog ? Colors.transparent : null,
      body: Column(
        children: [
          if (widget.dialog) _dialogHeader(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
            child: TextField(
              key: const Key('call_user_search'),
              autofocus: true,
              decoration: InputDecoration(hintText: l10n.chatSearchUsers, prefixIcon: const Icon(LucideIcons.search)),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() => _query = v.trim());
                });
              },
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _selected.isEmpty
                ? const SizedBox(width: double.infinity)
                : Column(
                    children: [
                      const SizedBox(height: Space.sm),
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: Space.md),
                          itemCount: _selected.length,
                          separatorBuilder: (_, _) => const SizedBox(width: Space.xs + 2),
                          itemBuilder: (_, i) {
                            final e = _selected.entries.elementAt(i);
                            return InputChip(
                              key: ValueKey('call_selected_${e.key}'),
                              avatar: InitialsAvatar(label: e.value, colorKey: e.key, radius: 12),
                              label: Text(e.value),
                              onDeleted: () => _toggle(e.key, e.value, false),
                            );
                          },
                        ),
                      ),
                      if (_selected.length > 1)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
                          child: TextField(
                            key: const Key('call_title_field'),
                            controller: _title,
                            textCapitalization: TextCapitalization.sentences,
                            maxLength: 120,
                            decoration: InputDecoration(
                              hintText: l10n.callsTitleHint,
                              counterText: '',
                              prefixIcon: const Icon(LucideIcons.users),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.smd, Space.md, Space.xs),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(l10n.callsSelectPeople, style: TextStyle(color: t.textTertiary, fontSize: t.display.fontSizeMeta + 1)),
            ),
          ),
          Expanded(
            child: users.when(
              loading: () => const StateView.loading(),
              error: (e, _) => StateView.error(message: CallsFormat.error(l10n, e)),
              data: (list) {
                final visible = list.where((u) => u.userId != selfId).toList();
                if (visible.isEmpty) return StateView.empty(title: l10n.chatNoUsers, icon: LucideIcons.userSearch);
                return ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (_, i) {
                    final u = visible[i];
                    return CheckboxListTile(
                      key: ValueKey('call_pick_${u.userId}'),
                      value: _selected.containsKey(u.userId),
                      secondary: InitialsAvatar(label: u.label, colorKey: u.userId),
                      title: Text(u.label, style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w500)),
                      subtitle: Text(u.email, style: TextStyle(color: t.textTertiary)),
                      onChanged: (v) => _toggle(u.userId, u.label, v == true),
                    );
                  },
                );
              },
            ),
          ),
          if (widget.dialog) _dialogFooter(context),
          if (_selected.isNotEmpty && !widget.dialog)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Space.md),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const Key('new_call_audio'),
                        onPressed: () => _call(false),
                        icon: const Icon(LucideIcons.phone),
                        label: Text(l10n.callsAudio),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('new_call_video'),
                        onPressed: () => _call(true),
                        icon: const Icon(LucideIcons.video),
                        label: Text(l10n.callsVideo),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
