import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/ds/x_badge.dart';
import '../../../../shared/widgets/initials_avatar.dart';
import '../../data/meetings.dart';
import '../calls_format.dart';
import '../calls_providers.dart';
import 'call_style.dart';
import '../../../../shared/widgets/app_sheet.dart';

/// «Ожидают: N» in the participants sheet: moderators admit or deny people
/// knocking through a guest link or a meeting link.
class CallLobbySection extends ConsumerWidget {
  const CallLobbySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = ref.watch(callControllerProvider.select((s) => s.lobby.waiting));
    final moderator = ref.watch(callControllerProvider.select((s) => s.call?.isModerator ?? false));
    if (waiting.isEmpty || !moderator) return const SizedBox.shrink();
    final l10n = context.l10n;
    final t = context.tokens;
    return Column(
      key: const Key('call_lobby_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.mlg, Space.smd, Space.mlg, Space.xs),
          child: Row(
            children: [
              Icon(LucideIcons.hourglass, size: 14, color: t.warning),
              const SizedBox(width: Space.xs),
              Text(
                l10n.callsLobbyWaiting(waiting.length).toUpperCase(),
                style: TextStyle(color: t.warning, fontSize: t.display.fontSizeMeta, fontWeight: FontWeight.w700, letterSpacing: 0.6),
              ),
            ],
          ),
        ),
        for (final e in waiting) _LobbyRow(entry: e),
      ],
    );
  }
}

class _LobbyRow extends ConsumerStatefulWidget {
  const _LobbyRow({required this.entry});
  final CallLobbyEntry entry;

  @override
  ConsumerState<_LobbyRow> createState() => _LobbyRowState();
}

class _LobbyRowState extends ConsumerState<_LobbyRow> {
  bool _busy = false;

  Future<void> _decide(bool admit) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(callControllerProvider.notifier).decideLobby(widget.entry.id, admit: admit);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(CallsFormat.error(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final e = widget.entry;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.sm, Space.xs),
      child: Row(
        children: [
          InitialsAvatar(label: e.name, colorKey: e.id, radius: 20),
          const SizedBox(width: Space.smd),
          Expanded(
            // Name and «Гость» / staff badge are read together.
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: Space.xxs),
                  XBadge(e.isGuest ? l10n.callsGuest : l10n.callsLobbyStaff, tone: e.isGuest ? BadgeTone.warning : BadgeTone.info, small: true),
                ],
              ),
            ),
          ),
          IconButton(
            key: ValueKey('lobby_deny_${e.id}'),
            tooltip: l10n.callsLobbyDeny,
            onPressed: _busy ? null : () => _decide(false),
            icon: Icon(LucideIcons.x, color: t.danger),
          ),
          FilledButton.tonal(
            key: ValueKey('lobby_admit_${e.id}'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: Space.smd)),
            onPressed: _busy ? null : () => _decide(true),
            child: Text(l10n.callsLobbyAdmit),
          ),
        ],
      ),
    );
  }
}

/// Guests in the room with the «Гость» badge (everyone sees who has no
/// account); moderators can remove them.
class CallGuestsSection extends ConsumerWidget {
  const CallGuestsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participants = ref.watch(callControllerProvider.select((s) => s.participants));
    final lobbyGuests = ref.watch(callControllerProvider.select((s) => s.lobby.guests));
    final moderator = ref.watch(callControllerProvider.select((s) => s.call?.isModerator ?? false));
    final inRoom = {
      for (final p in participants)
        if (!p.isLocal && isGuestIdentity(p.identity)) p.identity.substring(6).split('#').first: p.name,
    };
    final guests = <String, String>{...inRoom};
    for (final g in lobbyGuests) {
      if (g.joinedAt != null || inRoom.containsKey(g.id)) guests[g.id] = g.name;
    }
    if (guests.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final t = context.tokens;
    return Column(
      key: const Key('call_guests_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.mlg, Space.smd, Space.mlg, Space.xs),
          child: Text(
            l10n.callsGuestsSection.toUpperCase(),
            style: TextStyle(color: t.textTertiary, fontSize: t.display.fontSizeMeta, fontWeight: FontWeight.w600, letterSpacing: 0.6),
          ),
        ),
        for (final entry in guests.entries)
          ListTile(
            key: ValueKey('guest_${entry.key}'),
            contentPadding: const EdgeInsets.only(left: Space.md, right: Space.xs),
            leading: InitialsAvatar(label: entry.value, colorKey: entry.key),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    entry.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: Space.xs + 2),
                XBadge(l10n.callsGuest, key: ValueKey('guest_badge_${entry.key}'), tone: BadgeTone.warning, small: true),
              ],
            ),
            subtitle: inRoom.containsKey(entry.key) ? null : Text(l10n.callsSectionNotInCall, style: TextStyle(color: t.textTertiary)),
            trailing: moderator
                ? IconButton(
                    key: ValueKey('guest_remove_${entry.key}'),
                    tooltip: l10n.callsModRemove,
                    icon: Icon(LucideIcons.userMinus, color: t.danger, size: 20),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await ref.read(callControllerProvider.notifier).removeGuest(entry.key);
                      } on AppException catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text(CallsFormat.error(l10n, e))));
                      }
                    },
                  )
                : null,
          ),
      ],
    );
  }
}

/// «Пригласить гостя»: a link for people without an account (browser page),
/// with expiry, a use limit and manual admission by default.
Future<void> showGuestLinkSheet(BuildContext context) {
  final t = context.tokens;
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: t.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusXl))),
    builder: (_) => const _GuestLinkSheet(),
  );
}

class _GuestLinkSheet extends ConsumerStatefulWidget {
  const _GuestLinkSheet();

  @override
  ConsumerState<_GuestLinkSheet> createState() => _GuestLinkSheetState();
}

class _GuestLinkSheetState extends ConsumerState<_GuestLinkSheet> {
  int _minutes = 60;
  int _uses = 5;
  bool _lobby = true;
  bool _screen = false;
  bool _busy = false;
  CallGuestLink? _link;

  Future<void> _create() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final link = await ref
          .read(callControllerProvider.notifier)
          .createGuestLink(expiresInMinutes: _minutes, maxUses: _uses, requireLobby: _lobby, allowScreenShare: _screen);
      if (mounted) setState(() => _link = link);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(CallsFormat.error(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    final link = _link;
    if (link == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final text = context.l10n.callsGuestLinkCopied;
    await Clipboard.setData(ClipboardData(text: link.url));
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final link = _link;
    final options = [(60, l10n.callsGuestLinkHour), (1440, l10n.callsGuestLinkDay), (10080, l10n.callsGuestLinkWeek)];
    return SingleChildScrollView(
      key: const Key('guest_link_sheet'),
      padding: const EdgeInsets.fromLTRB(Space.mlg, 0, Space.mlg, Space.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.callsGuestLinkTitle,
            style: theme.textTheme.titleMedium?.copyWith(color: t.textPrimary, fontWeight: t.titleWeight),
          ),
          const SizedBox(height: Space.xs),
          Text(l10n.callsGuestLinkHint, style: TextStyle(color: t.textSecondary)),
          const SizedBox(height: Space.md),
          if (link == null) ...[
            Text(
              l10n.callsGuestLinkExpires,
              style: TextStyle(color: t.textTertiary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Space.xs),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.xs,
              children: [
                for (final (minutes, label) in options)
                  ChoiceChip(
                    key: ValueKey('guest_link_expiry_$minutes'),
                    label: Text(label),
                    selected: _minutes == minutes,
                    onSelected: (_) => setState(() => _minutes = minutes),
                  ),
              ],
            ),
            const SizedBox(height: Space.smd),
            Row(
              children: [
                Expanded(
                  child: Text(l10n.callsGuestLinkUses, style: TextStyle(color: t.textPrimary)),
                ),
                IconButton(
                  key: const Key('guest_link_uses_minus'),
                  tooltip: l10n.a11yDecrease,
                  onPressed: _uses > 1 ? () => setState(() => _uses--) : null,
                  icon: const Icon(LucideIcons.minus),
                ),
                Semantics(
                  label: l10n.callsGuestLinkUses,
                  value: '$_uses',
                  liveRegion: true,
                  excludeSemantics: true,
                  child: SizedBox(
                    width: 32,
                    child: Text(
                      '$_uses',
                      key: const Key('guest_link_uses'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('guest_link_uses_plus'),
                  tooltip: l10n.a11yIncrease,
                  onPressed: _uses < 50 ? () => setState(() => _uses++) : null,
                  icon: const Icon(LucideIcons.plus),
                ),
              ],
            ),
            SwitchListTile(
              key: const Key('guest_link_lobby'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.callsGuestLinkLobby),
              value: _lobby,
              onChanged: (v) => setState(() => _lobby = v),
            ),
            SwitchListTile(
              key: const Key('guest_link_screen'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.callsGuestLinkScreen),
              value: _screen,
              onChanged: (v) => setState(() => _screen = v),
            ),
            const SizedBox(height: Space.sm),
            FilledButton.icon(
              key: const Key('guest_link_create'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: _busy ? null : _create,
              icon: const Icon(LucideIcons.link),
              label: Text(l10n.callsGuestLinkCreate),
            ),
          ] else ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: t.surfaceSubtle,
                borderRadius: t.cardRadius,
                border: Border.all(color: t.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Space.smd),
                child: SelectableText(
                  link.url,
                  key: const Key('guest_link_url'),
                  style: TextStyle(color: t.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(
              [if (link.expiresAt != null) CallsFormat.dateTime(context, link.expiresAt), l10n.callsGuestLinkUsesValue(link.maxUses)].join(' · '),
              style: TextStyle(color: t.textTertiary, fontSize: t.display.fontSizeMeta + 1),
            ),
            const SizedBox(height: Space.md),
            FilledButton.icon(
              key: const Key('guest_link_copy'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: _copy,
              icon: const Icon(LucideIcons.copy),
              label: Text(l10n.callsGuestLinkCopy),
            ),
          ],
        ],
      ),
    );
  }
}

/// «Ожидают входа: N» over the call stage when somebody knocks (moderators).
class CallLobbyBanner extends ConsumerStatefulWidget {
  const CallLobbyBanner({super.key, required this.onOpen});
  final VoidCallback onOpen;

  @override
  ConsumerState<CallLobbyBanner> createState() => _CallLobbyBannerState();
}

class _CallLobbyBannerState extends ConsumerState<CallLobbyBanner> {
  int? _count;
  Timer? _timer;
  StreamSubscription<int>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(callControllerProvider.notifier).lobbyKnocks.listen((n) {
      if (!mounted) return;
      setState(() => _count = n);
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 10), _hide);
    });
  }

  void _hide() {
    if (mounted) setState(() => _count = null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = ref.watch(callControllerProvider.select((s) => s.lobby.waiting.length));
    final count = _count == null || waiting == 0 ? null : waiting;
    final l10n = context.l10n;
    final pal = context.callPalette;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: count == null
          ? const SizedBox.shrink()
          : Padding(
              key: const Key('call_lobby_banner'),
              padding: const EdgeInsets.only(top: Space.sm),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: CallGlass(
                  radius: 18,
                  strong: true,
                  padding: const EdgeInsets.fromLTRB(Space.smd, Space.xs, Space.xs, Space.xs),
                  child: Row(
                    children: [
                      ExcludeSemantics(child: Icon(LucideIcons.hourglass, size: 18, color: pal.warning)),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        // Announced when somebody knocks.
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            l10n.callsLobbyBanner(count),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: CallPalette.ink, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('call_lobby_banner_open'),
                        onPressed: () {
                          _hide();
                          widget.onOpen();
                        },
                        child: Text(l10n.callsLobbyOpen, style: const TextStyle(color: CallPalette.ink)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
