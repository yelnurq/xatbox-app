import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/platform/desktop.dart';
import '../../../../core/platform/desktop_layout.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/ds/x_badge.dart';
import '../../../../shared/widgets/initials_avatar.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../data/call_media.dart';
import '../../data/call_models.dart';
import '../call_controller.dart';
import '../call_invite_sheet.dart';
import '../calls_format.dart';
import '../calls_providers.dart';
import 'call_chat.dart';
import 'call_lobby.dart';
import 'call_quality.dart';
import 'call_recording.dart';
import 'call_stage.dart';
import '../../../../shared/widgets/app_sheet.dart';

/// Bottom sheet in the skin's own surface, rounded top, drag handle.
Future<T?> showCallSheet<T>(BuildContext context, WidgetBuilder builder) {
  final t = context.tokens;
  return showAppSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: t.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusXl))),
    builder: builder,
  );
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.title, {this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.mlg, 0, Space.md, Space.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: t.textPrimary, fontWeight: t.titleWeight),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.mlg, Space.smd, Space.mlg, Space.xs),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: t.textTertiary, fontSize: t.display.fontSizeMeta, fontWeight: FontWeight.w600, letterSpacing: 0.6),
      ),
    );
  }
}

/// Rounded-square icon used by option rows.
class _IconSquare extends StatelessWidget {
  const _IconSquare({required this.icon, this.selected = false});
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: selected ? t.primarySoft : t.surfaceSubtle, borderRadius: t.controlRadius),
        child: Icon(icon, size: 20, color: selected ? t.primary : t.textSecondary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Audio routes
// ---------------------------------------------------------------------------

IconData _outputIcon(String id) => switch (id) {
  'speaker' => LucideIcons.volume2,
  'earpiece' => LucideIcons.smartphone,
  'wired-headset' => LucideIcons.headphones,
  'bluetooth' => LucideIcons.bluetooth,
  _ => LucideIcons.speaker,
};

/// Sound during the call: where it plays and which microphone is used.
/// Android lists earpiece / speaker / wired / Bluetooth outputs and the
/// microphones; on iOS the system route picker (CallKit) handles devices,
/// so the button just switches the speaker.
Future<void> showCallAudioSheet(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final controller = container.read(callControllerProvider.notifier);
  final outputs = await controller.audioRoutes();
  final inputs = await controller.audioInputs();
  if (!context.mounted) return;
  if (outputs.isEmpty && inputs.isEmpty) {
    await controller.setSpeaker(!container.read(callControllerProvider).speakerOn);
    return;
  }
  await showCallSheet<void>(context, (_) => _AudioSheet(outputs: outputs, inputs: inputs));
}

class _AudioSheet extends ConsumerWidget {
  const _AudioSheet({required this.outputs, required this.inputs});
  final List<AudioRoute> outputs;
  final List<AudioRoute> inputs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(callControllerProvider.notifier);
    final speakerOn = ref.watch(callControllerProvider.select((s) => s.speakerOn));
    final media = controller.media;
    final selectedOutput = media?.selectedAudioRouteId ?? (speakerOn ? 'speaker' : 'earpiece');
    String outputLabel(AudioRoute r) => switch (r.id) {
      'speaker' => l10n.callsSpeaker,
      'earpiece' => l10n.callsAudioEarpiece,
      'wired-headset' => l10n.callsAudioWired,
      'bluetooth' => r.label.isEmpty || r.label.toLowerCase() == 'bluetooth' ? l10n.callsAudioBluetooth : '${l10n.callsAudioBluetooth} · ${r.label}',
      _ => r.label,
    };
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetTitle(l10n.callsAudioSettings),
          if (outputs.isNotEmpty) ...[
            _SectionLabel(l10n.callsAudioOutput),
            for (final r in outputs)
              _RouteTile(
                key: Key('call_output_${r.id}'),
                icon: _outputIcon(r.id),
                label: outputLabel(r),
                selected: selectedOutput == r.id,
                onTap: () {
                  controller.selectAudioRoute(r);
                  Navigator.pop(context);
                },
              ),
          ],
          if (inputs.isNotEmpty) ...[
            _SectionLabel(l10n.callsMic),
            for (final r in inputs)
              _RouteTile(
                key: Key('call_input_${r.id}'),
                icon: LucideIcons.mic,
                label: r.label.isEmpty ? l10n.callsMic : r.label,
                selected: media?.selectedAudioInputId == r.id,
                onTap: () {
                  controller.selectAudioInput(r);
                  Navigator.pop(context);
                },
              ),
          ],
          SizedBox(height: Space.md + MediaQuery.viewPaddingOf(context).bottom),
        ],
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({super.key, required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
          child: Row(
            children: [
              _IconSquare(icon: icon, selected: selected),
              const SizedBox(width: Space.smd),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: t.textPrimary, fontSize: t.display.fontSizeBase, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                ),
              ),
              ExcludeSemantics(
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
                    child: Icon(LucideIcons.check, size: 16, color: t.onBrand),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// More actions (screen share, hand, reactions, layout)
// ---------------------------------------------------------------------------

Future<void> showCallMoreSheet(BuildContext context) =>
    showCallSheet<void>(context, (_) => _MoreSheet(host: context, messenger: ScaffoldMessenger.of(context)));

class _MoreSheet extends ConsumerWidget {
  const _MoreSheet({required this.host, required this.messenger});
  final BuildContext host;
  final ScaffoldMessengerState messenger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final controller = ref.read(callControllerProvider.notifier);
    final group = ref.watch(callControllerProvider.select((s) => s.call?.isGroup ?? false));
    final active = ref.watch(callControllerProvider.select((s) => s.phase == CallPhase.active));
    final sharing = ref.watch(callControllerProvider.select((s) => s.screenSharing));
    final hand = ref.watch(callControllerProvider.select((s) => s.handRaised));
    final layout = ref.watch(callLayoutProvider);
    final cameraOn = ref.watch(callControllerProvider.select((s) => s.cameraOn));
    final recordingEnabled = ref.watch(callsConfigProvider.select((c) => c.recordingEnabled));
    final selfId = ref.watch(currentUserProvider)?.id ?? '';
    final canRecord = ref.watch(callControllerProvider.select((s) => callCanStartRecording(s, enabled: recordingEnabled)));
    final canStopRecording = ref.watch(callControllerProvider.select((s) => callCanStopRecording(s, selfId)));
    final recordingBusy = ref.watch(callControllerProvider.select((s) => s.recordingBusy));
    final narrow = MediaQuery.sizeOf(host.mounted ? host : context).width < 400;

    void close() => Navigator.pop(context);

    Future<void> recording(bool start) async {
      close();
      if (start && (!host.mounted || !await showCallRecordConfirm(host))) return;
      try {
        if (start) {
          await controller.startRecording();
        } else {
          await controller.stopRecording();
          messenger.showSnackBar(SnackBar(content: Text(l10n.callsRecordingStopped)));
        }
      } on AppException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(CallsFormat.error(l10n, e))));
      }
    }

    final actions = <Widget>[
      if (cameraOn && narrow)
        _MoreAction(
          key: const Key('call_switch_camera_more'),
          icon: LucideIcons.switchCamera,
          label: l10n.callsSwitchCamera,
          onTap: () {
            close();
            controller.switchCamera();
          },
        ),
      if (canRecord)
        _MoreAction(key: const Key('call_record'), icon: LucideIcons.circleDot, label: l10n.callsRecord, onTap: recordingBusy ? null : () => recording(true)),
      if (canStopRecording)
        _MoreAction(
          key: const Key('call_record_stop'),
          icon: LucideIcons.circleStop,
          label: l10n.callsRecordStop,
          active: true,
          onTap: recordingBusy ? null : () => recording(false),
        ),
      if (active)
        _MoreAction(
          key: const Key('call_screen_share'),
          icon: sharing ? LucideIcons.monitorOff : LucideIcons.monitorUp,
          label: l10n.callsScreenShare,
          active: sharing,
          toggled: sharing,
          onTap: () async {
            // Desktop: the person picks a screen or a window first.
            String? sourceId;
            if (!sharing && isDesktop) {
              // ignore: experimental_member_use
              sourceId = await lk.ScreenSelectDialog.show(
                context,
                titleText: l10n.callsShareChoose,
                screenTabText: l10n.callsShareEntireScreen,
                windowTabText: l10n.callsShareWindow,
                cancelText: l10n.cancel,
                shareText: l10n.callsShareStart,
              );
              if (sourceId == null) return;
            }
            close();
            final ok = await controller.setScreenShare(!sharing, sourceId: sourceId);
            if (!ok && !sharing) messenger.showSnackBar(SnackBar(content: Text(l10n.callsScreenShareRefused)));
          },
        ),
      if (group) ...[
        _MoreAction(
          key: const Key('call_raise_hand'),
          icon: LucideIcons.hand,
          label: hand ? l10n.callsLowerHand : l10n.callsRaiseHand,
          active: hand,
          toggled: hand,
          onTap: () {
            controller.toggleHand();
            close();
          },
        ),
        _MoreAction(
          key: const Key('call_layout_more'),
          icon: layout == CallLayout.grid ? LucideIcons.layoutPanelTop : LucideIcons.layoutGrid,
          label: layout == CallLayout.grid ? l10n.callsLayoutSpotlight : l10n.callsLayoutGrid,
          onTap: () {
            ref.read(callLayoutProvider.notifier).toggle();
            close();
          },
        ),
        _MoreAction(
          key: const Key('call_participants_more'),
          icon: LucideIcons.users,
          label: l10n.callsParticipants,
          onTap: () {
            close();
            if (host.mounted) showCallParticipantsSheet(host);
          },
        ),
      ],
      _MoreAction(
        key: const Key('call_quality_more'),
        icon: LucideIcons.gauge,
        label: l10n.callsQualitySettings,
        onTap: () {
          close();
          if (host.mounted) showCallQualitySheet(host);
        },
      ),
      _MoreAction(
        key: const Key('call_audio_more'),
        icon: LucideIcons.slidersHorizontal,
        label: l10n.callsAudioSettings,
        onTap: () {
          close();
          if (host.mounted) showCallAudioSheet(host);
        },
      ),
    ];

    // `useSafeArea` leaves the bottom inset to the sheet itself, so without
    // this the last row of actions sits under the gesture bar.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Space.md,
        0,
        Space.md,
        Space.lg + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (group) ...[
            Padding(
              padding: const EdgeInsets.only(left: Space.xs, bottom: Space.sm),
              child: Text(
                l10n.callsReactions,
                style: TextStyle(color: t.textTertiary, fontWeight: FontWeight.w600),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final (i, e) in callReactionEmojis.indexed)
                  _EmojiButton(
                    key: Key('call_react_$i'),
                    emoji: e,
                    onTap: () {
                      controller.sendReaction(e);
                      close();
                    },
                  ),
              ],
            ),
            const SizedBox(height: Space.mlg),
          ],
          LayoutBuilder(
            builder: (_, box) {
              const gap = Space.sm;
              final columns = box.maxWidth > 480 ? 4 : 3;
              final w = (box.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [for (final a in actions) SizedBox(width: w, child: a)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({super.key, required this.emoji, required this.onTap});
  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.surfaceSubtle,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 48,
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
        ),
      ),
    );
  }
}

class _MoreAction extends StatelessWidget {
  const _MoreAction({super.key, required this.icon, required this.label, required this.onTap, this.active = false, this.toggled});
  final IconData icon;
  final String label;

  /// Null while the action is busy (read as disabled).
  final VoidCallback? onTap;
  final bool active;

  /// On / off state for screen readers (null: a plain action).
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: onTap != null,
        toggled: toggled,
        child: Material(
          color: active ? t.primarySoft : t.surfaceSubtle,
          borderRadius: t.cardRadius,
          child: InkWell(
            borderRadius: t.cardRadius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.smd),
              child: Column(
                children: [
                  Icon(icon, color: active ? t.primary : t.textPrimary),
                  const SizedBox(height: Space.xs + 2),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: active ? t.primary : t.textSecondary, fontSize: t.display.fontSizeMeta, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick replies (decline with a message)
// ---------------------------------------------------------------------------

Future<String?> showCallQuickReplySheet(BuildContext context) => showCallSheet<String>(context, (ctx) {
  final l10n = ctx.l10n;
  final t = ctx.tokens;
  final replies = [l10n.callsQuickReplyBusy, l10n.callsQuickReplyLater, l10n.callsQuickReplyMeeting];
  return SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetTitle(l10n.callsDeclineWithMessage),
        for (final (i, r) in replies.indexed)
          InkWell(
            key: Key('call_quick_reply_$i'),
            onTap: () => Navigator.pop(ctx, r),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
              child: Row(
                children: [
                  const _IconSquare(icon: LucideIcons.messageSquareText),
                  const SizedBox(width: Space.smd),
                  Expanded(
                    child: Text(
                      r,
                      style: TextStyle(color: t.textPrimary, fontSize: t.display.fontSizeBase),
                    ),
                  ),
                  Icon(LucideIcons.send, size: 18, color: t.textTertiary),
                ],
              ),
            ),
          ),
        const SizedBox(height: Space.md),
      ],
    ),
  );
});

// ---------------------------------------------------------------------------
// Participants
// ---------------------------------------------------------------------------

Future<void> showCallParticipantsSheet(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  // Moderators see who is waiting right away.
  unawaited(container.read(callControllerProvider.notifier).refreshLobby());
  // Desktop: a panel beside the video instead of a dialog over it.
  if (container.read(desktopLayoutProvider)) {
    _setParticipantsPanel(container, true);
    return Future.value();
  }
  return showCallSheet<void>(context, (_) => const _ParticipantsSheet());
}

/// Desktop: opens or closes the participants panel (the toolbar button and
/// Ctrl+Shift+P).
void toggleCallParticipantsPanel(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(callParticipantsPanelOpenProvider)) {
    _setParticipantsPanel(container, false);
  } else {
    unawaited(showCallParticipantsSheet(context));
  }
}

void _setParticipantsPanel(ProviderContainer container, bool open) {
  container.read(callParticipantsPanelOpenProvider.notifier).set(open);
  if (open) container.read(callChatPanelOpenProvider.notifier).set(false);
}

/// Desktop: the participants list docked on the right of the call screen
/// (placed by the call screen, like [CallChatSidePanel]).
class CallParticipantsSidePanel extends ConsumerWidget {
  const CallParticipantsSidePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Material(
      key: const Key('call_participants_panel'),
      color: t.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: _ParticipantsSheet(onClose: () => ref.read(callParticipantsPanelOpenProvider.notifier).set(false)),
    );
  }
}

/// Participants with their live state; moderators mute microphone / camera /
/// screen share, remove, promote / demote and ring again. The server
/// re-checks every action (403 NOT_MODERATOR otherwise).
class _ParticipantsSheet extends ConsumerWidget {
  const _ParticipantsSheet({this.onClose});

  /// Set in the desktop side panel: its ✕ (the sheet closes by popping).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final call = ref.watch(callControllerProvider.select((s) => s.call));
    if (call == null) return const SizedBox.shrink();
    final participants = ref.watch(callControllerProvider.select((s) => s.participants));
    final hands = ref.watch(callControllerProvider.select((s) => s.raisedHands));
    final selfId = ref.watch(currentUserProvider)?.id ?? '';
    final inRoom = <String, MediaParticipant>{
      for (final p in participants)
        if (!p.isLocal) p.userId: p,
    };
    final handUsers = {for (final id in hands) id.split('#').first};
    final live = call.status == CallStatus.active || call.status.isRinging;
    final guestsEnabled = ref.watch(callsConfigProvider.select((c) => c.guestsEnabled));
    Widget inviteButton() => _inviteButton(context);
    bool connected(CallParticipantInfo p) => inRoom.containsKey(p.userId) || p.userId == selfId || p.status.isInCall;
    final inCall = call.participants.where(connected).toList();
    final waiting = call.participants.where((p) => !connected(p)).toList();

    Widget row(CallParticipantInfo p) => _PersonRow(
      person: p,
      room: inRoom[p.userId],
      self: p.userId == selfId,
      connected: connected(p),
      handRaised: handUsers.contains(p.userId),
      call: call,
      live: live,
    );

    final moderation = call.isGroup && call.isModerator && live
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (guestsEnabled)
                IconButton(
                  key: const Key('call_guest_link'),
                  tooltip: l10n.callsGuestInvite,
                  onPressed: () => showGuestLinkSheet(context),
                  icon: const Icon(LucideIcons.link, size: 20),
                ),
              inviteButton(),
            ],
          )
        : null;
    final close = onClose;
    return SizedBox(
      height: close == null ? MediaQuery.sizeOf(context).height * 0.72 : null,
      child: Column(
        children: [
          if (close != null) const SizedBox(height: Space.smd),
          _SheetTitle(
            l10n.callsParticipantsCount(call.participants.length),
            trailing: close == null
                ? moderation
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ?moderation,
                      IconButton(
                        key: const Key('call_participants_close'),
                        tooltip: l10n.close,
                        onPressed: close,
                        icon: const Icon(LucideIcons.x, size: 20),
                      ),
                    ],
                  ),
          ),
          Expanded(
            child: ListView(
              children: [
                const CallLobbySection(),
                if (inCall.isNotEmpty) ...[_SectionLabel(l10n.callsSectionInCall), for (final p in inCall) row(p)],
                const CallGuestsSection(),
                if (waiting.isNotEmpty) ...[_SectionLabel(l10n.callsSectionNotInCall), for (final p in waiting) row(p)],
              ],
            ),
          ),
          if (call.isModerator)
            _EndForAll(
              onEnd: () {
                if (close != null) {
                  close();
                } else {
                  Navigator.pop(context);
                }
                ref.read(callControllerProvider.notifier).hangUp(forAll: true);
              },
            ),
        ],
      ),
    );
  }

  Widget _inviteButton(BuildContext context) {
    final l10n = context.l10n;
    // The desktop panel is narrow: the icon only.
    return MediaQuery.sizeOf(context).width > 420 && onClose == null
        ? FilledButton.tonalIcon(
            key: const Key('call_invite'),
            onPressed: () => showCallSheet<void>(context, (_) => const CallInviteSheet()),
            icon: const Icon(LucideIcons.userPlus, size: 18),
            label: Text(l10n.callsInvite, maxLines: 1, overflow: TextOverflow.ellipsis),
          )
        : IconButton.filledTonal(
            key: const Key('call_invite'),
            tooltip: l10n.callsInvite,
            onPressed: () => showCallSheet<void>(context, (_) => const CallInviteSheet()),
            icon: const Icon(LucideIcons.userPlus, size: 20),
          );
  }
}

class _EndForAll extends StatelessWidget {
  const _EndForAll({required this.onEnd});
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.md),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('call_end_for_all'),
            style: OutlinedButton.styleFrom(
              foregroundColor: t.danger,
              side: BorderSide(color: t.danger.withValues(alpha: 0.5)),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: onEnd,
            icon: const Icon(LucideIcons.phoneOff, size: 18),
            label: Text(l10n.callsEndForAll),
          ),
        ),
      ),
    );
  }
}

class _PersonRow extends ConsumerWidget {
  const _PersonRow({
    required this.person,
    required this.room,
    required this.self,
    required this.connected,
    required this.handRaised,
    required this.call,
    required this.live,
  });

  final CallParticipantInfo person;
  final MediaParticipant? room;
  final bool self;
  final bool connected;
  final bool handRaised;
  final CallInfo call;
  final bool live;

  static BadgeTone _tone(ParticipantStatus s) => switch (s) {
    ParticipantStatus.invited || ParticipantStatus.ringing => BadgeTone.info,
    ParticipantStatus.accepted || ParticipantStatus.joined => BadgeTone.success,
    ParticipantStatus.declined || ParticipantStatus.missed || ParticipantStatus.busy => BadgeTone.danger,
    _ => BadgeTone.neutral,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final controller = ref.read(callControllerProvider.notifier);
    final p = person;
    final canRingAgain =
        call.isGroup &&
        call.isModerator &&
        live &&
        !self &&
        room == null &&
        const {ParticipantStatus.declined, ParticipantStatus.missed, ParticipantStatus.busy, ParticipantStatus.left}.contains(p.status);

    Future<void> act(Future<void> Function() f, {String? done}) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await f();
        if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
      } on AppException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(CallsFormat.error(l10n, e))));
      }
    }

    PopupMenuItem<String> item(String value, IconData icon, String text, {Color? color}) => PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? t.textSecondary),
          const SizedBox(width: Space.smd),
          Flexible(
            child: Text(text, style: TextStyle(color: color)),
          ),
        ],
      ),
    );

    final avatar = p.email.isNotEmpty ? UserAvatar(email: p.email, label: p.label, radius: 20) : InitialsAvatar(label: p.label, colorKey: p.userId);
    final statusText = CallsFormat.participantStatus(l10n, p.status);
    final role = p.role == 'participant' ? '' : CallsFormat.role(l10n, p.role);

    return ListTile(
      key: ValueKey('participant_${p.userId}'),
      contentPadding: const EdgeInsets.only(left: Space.md, right: Space.xs),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(opacity: connected ? 1 : 0.6, child: avatar),
          if (connected)
            Positioned(
              right: -1,
              bottom: -1,
              child: Semantics(
                label: l10n.callsPStatusJoined,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: t.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.surface, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              self ? '${p.label} (${l10n.callsYou})' : p.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w500),
            ),
          ),
          if (role.isNotEmpty) ...[const SizedBox(width: Space.xs + 2), XBadge(role, tone: BadgeTone.primary, small: true)],
        ],
      ),
      subtitle: connected
          ? null
          : Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: Space.xxs),
                child: XBadge(statusText, tone: _tone(p.status), small: true),
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (handRaised)
            Padding(
              padding: const EdgeInsets.only(right: Space.xs),
              child: Icon(LucideIcons.hand, color: t.warning, size: 18, semanticLabel: l10n.callsHandRaised),
            ),
          if (room != null && room!.screenSharing)
            Padding(
              padding: const EdgeInsets.only(right: Space.xs),
              child: Icon(LucideIcons.monitorUp, color: t.primary, size: 18, semanticLabel: l10n.callsScreenShare),
            ),
          if (room != null && room!.cameraOn)
            Padding(
              padding: const EdgeInsets.only(right: Space.xs),
              child: Icon(LucideIcons.video, color: t.textTertiary, size: 18, semanticLabel: l10n.callsCamera),
            ),
          if (room != null && !room!.micOn) Icon(LucideIcons.micOff, color: t.danger, size: 18, semanticLabel: l10n.a11yMicOff),
          if (canRingAgain)
            IconButton(
              key: ValueKey('ring_again_${p.userId}'),
              tooltip: l10n.callsRingAgain,
              icon: Icon(LucideIcons.phoneCall, color: t.success, size: 20),
              onPressed: () => act(() => controller.ringAgain(p.userId), done: l10n.callsRingAgainSent),
            ),
          if (call.isModerator && !self)
            PopupMenuButton<String>(
              key: ValueKey('moderate_${p.userId}'),
              tooltip: l10n.callsMore,
              icon: Icon(LucideIcons.ellipsisVertical, color: t.textSecondary, size: 20),
              shape: RoundedRectangleBorder(borderRadius: t.cardRadius),
              onSelected: (v) => act(
                () => switch (v) {
                  'mute' => controller.muteParticipant(p.userId, 'microphone'),
                  'mute_camera' => controller.muteParticipant(p.userId, 'camera'),
                  'mute_screen' => controller.muteParticipant(p.userId, 'screen_share'),
                  'remove' => controller.removeParticipant(p.userId),
                  'demote' => controller.setParticipantRole(p.userId, 'participant'),
                  'ring' => controller.ringAgain(p.userId),
                  _ => controller.setParticipantRole(p.userId, 'moderator'),
                },
                done: v == 'ring' ? l10n.callsRingAgainSent : null,
              ),
              itemBuilder: (_) => [
                item('mute', LucideIcons.micOff, l10n.callsModMute),
                if (room == null || room!.cameraOn) item('mute_camera', LucideIcons.videoOff, l10n.callsModMuteCamera),
                if (room != null && room!.screenSharing) item('mute_screen', LucideIcons.monitorOff, l10n.callsModStopScreenShare),
                if (canRingAgain) item('ring', LucideIcons.phoneCall, l10n.callsRingAgain),
                if (call.isHost && p.role == 'participant') item('promote', LucideIcons.shieldCheck, l10n.callsMakeModerator),
                if (call.isHost && p.role == 'moderator') item('demote', LucideIcons.shieldMinus, l10n.callsMakeParticipant),
                item('remove', LucideIcons.userMinus, l10n.callsModRemove, color: t.danger),
              ],
            ),
        ],
      ),
    );
  }
}
