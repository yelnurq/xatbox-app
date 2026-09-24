import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/lifecycle/app_visibility.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/ds/x_badge.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/state_view.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/call_native.dart';
import '../data/call_preview.dart';
import '../data/meetings.dart';
import 'calls_format.dart';
import 'calls_providers.dart';

/// Pre-join of a scheduled meeting (link, calendar, «Встречи»): camera
/// preview, microphone and camera toggles, the devices that will be used,
/// then join — or wait in the lobby until the organizer lets you in.
class MeetingPrejoinScreen extends ConsumerStatefulWidget {
  const MeetingPrejoinScreen({super.key, required this.code});

  /// Meeting code (or a guest token opened on a staff phone).
  final String code;

  @override
  ConsumerState<MeetingPrejoinScreen> createState() => _MeetingPrejoinScreenState();
}

class _MeetingPrejoinScreenState extends ConsumerState<MeetingPrejoinScreen> {
  Meeting? _meeting;
  Object? _error;
  bool _loading = true;
  bool _mic = true;
  bool _cam = true;
  bool _joining = false;
  LobbyTicket? _lobby;
  CallCameraPreview? _preview;
  bool _previewOn = false;
  String? _micLabel;
  String? _camLabel;
  Timer? _poll;
  ForegroundPeriodic? _tick;
  StreamSubscription<Object?>? _frames;

  bool get _guestLink => XatBoxMeetingLinks.isGuestToken(widget.code);

  @override
  void initState() {
    super.initState();
    if (_guestLink) {
      _loading = false;
      return;
    }
    Future.microtask(_load);
    _tick = ForegroundPeriodic(ref.read(appVisibilityProvider), const Duration(seconds: 30), () {
      if (mounted) setState(() {});
    });
    if (ref.read(chatEnabledProvider)) {
      _frames = ref.read(chatRepositoryProvider).events.where((e) => e.type == 'meeting.lobby').listen((e) {
        if (!mounted || e.payload['meeting_code'] != widget.code || _lobby == null) return;
        final status = e.payload['status'];
        if (status == 'admitted') {
          unawaited(_join());
        } else if (status == 'denied') {
          _stopPolling();
          setState(() => _lobby = const LobbyTicket(id: '', status: 'denied'));
        }
      });
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.dispose();
    unawaited(_frames?.cancel());
    unawaited(_preview?.stop());
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final m = await ref.read(callsApiProvider).meeting(widget.code);
      if (!mounted) return;
      setState(() {
        _meeting = m;
        _error = null;
        _loading = false;
      });
      if (_cam && !_previewOn) unawaited(_startPreview());
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _startPreview() async {
    final native = ref.read(callNativeProvider);
    if (await native.ensurePermissions(video: true) != MediaPermission.granted) {
      if (mounted) setState(() => _cam = false);
      return;
    }
    final preview = _preview ??= ref.read(callCameraPreviewFactoryProvider)();
    final ok = await preview.start();
    final mic = await preview.microphoneLabel();
    final cam = await preview.cameraLabel();
    if (!mounted) {
      unawaited(preview.stop());
      return;
    }
    setState(() {
      _previewOn = ok;
      _micLabel = mic;
      _camLabel = cam;
    });
  }

  Future<void> _toggleCamera() async {
    setState(() => _cam = !_cam);
    if (_cam) {
      await _startPreview();
    } else {
      await _preview?.stop();
      if (mounted) setState(() => _previewOn = false);
    }
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _join() async {
    if (_joining) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final controller = ref.read(callControllerProvider.notifier);
    if (ref.read(callControllerProvider).inCall) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.callsErrAlreadyInCall)));
      return;
    }
    setState(() => _joining = true);
    // The call opens its own camera track.
    await _preview?.stop();
    _previewOn = false;
    try {
      final result = await controller.joinMeeting(widget.code, micOn: _mic, cameraOn: _cam);
      if (!mounted) return;
      if (result == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.meetingPermissionDenied)));
        if (_cam) unawaited(_startPreview());
        return;
      }
      if (result.joined) {
        _stopPolling();
        unawaited(router.pushReplacement(Routes.call));
        return;
      }
      final ticket = result.lobby;
      setState(() {
        _lobby = ticket;
        _meeting = result.meeting.code.isEmpty ? _meeting : result.meeting;
      });
      if (ticket != null && !ticket.denied) {
        _poll ??= Timer.periodic(const Duration(seconds: 3), (_) => unawaited(_join()));
      } else {
        _stopPolling();
      }
    } on AppException catch (e) {
      _stopPolling();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(CallsFormat.error(l10n, e))));
      if (e is ApiException && const {'MEETING_NOT_STARTED', 'MEETING_ENDED', 'MEETING_CANCELLED'}.contains(e.code)) {
        unawaited(_load());
      } else if (_cam) {
        unawaited(_startPreview());
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _cancelLobby() {
    _stopPolling();
    setState(() => _lobby = null);
    if (_cam) unawaited(_startPreview());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      key: const Key('meet_prejoin'),
      appBar: AppBar(title: Text(l10n.meetingPrejoinTitle)),
      body: _guestLink
          ? _GuestLinkNotice(code: widget.code)
          : _meeting == null
          ? (_loading
                ? const StateView.loading()
                : StateView.error(
                    message: _error is ApiException && (_error! as ApiException).code == 'MEETING_NOT_FOUND'
                        ? l10n.meetingNotFound
                        : CallsFormat.error(l10n, _error ?? l10n.meetingNotFound),
                    onRetry: _load,
                  ))
          : LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth >= 720;
                final preview = _PreviewBox(
                  preview: _previewOn ? _preview : null,
                  micOn: _mic,
                  camOn: _cam,
                  onMic: () => setState(() => _mic = !_mic),
                  onCam: _toggleCamera,
                );
                final panel = _panel(context, _meeting!);
                if (wide) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: preview),
                        const SizedBox(width: Space.lg),
                        Expanded(flex: 2, child: panel),
                      ],
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.xl),
                  children: [preview, const SizedBox(height: Space.md), panel],
                );
              },
            ),
    );
  }

  Widget _panel(BuildContext context, Meeting m) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final now = ref.watch(callClockProvider)();
    final joinable = meetingJoinableAt(m, now);
    final lobby = _lobby;
    final (String badge, BadgeTone tone) = switch (m.status) {
      MeetingStatus.live => (l10n.meetingLive, BadgeTone.success),
      MeetingStatus.cancelled => (l10n.meetingCancelled, BadgeTone.danger),
      MeetingStatus.ended => (l10n.meetingEnded, BadgeTone.neutral),
      _ when joinable => (l10n.meetingOpenNow, BadgeTone.info),
      _ => (l10n.meetingOpensAt(CallsFormat.time(context, m.opensAt)), BadgeTone.neutral),
    };

    Widget device(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: t.textTertiary),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.textSecondary))),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(alignment: Alignment.centerLeft, child: XBadge(badge, tone: tone, icon: LucideIcons.video)),
        const SizedBox(height: Space.sm),
        Text(m.title, key: const Key('meet_title'), style: theme.textTheme.titleLarge?.copyWith(color: t.textPrimary, fontWeight: t.titleWeight)),
        const SizedBox(height: Space.xs),
        Text(
          '${CallsFormat.day(context, m.startsAt.toLocal())}, ${CallsFormat.time(context, m.startsAt)}–${CallsFormat.time(context, m.endsAt)}',
          style: TextStyle(color: t.textSecondary),
        ),
        if (m.organizerName.isNotEmpty) Text(l10n.calendarOrganizer(m.organizerName), style: TextStyle(color: t.textTertiary)),
        const SizedBox(height: Space.md),
        Text(l10n.meetingDevices, style: theme.textTheme.titleSmall?.copyWith(color: t.textPrimary)),
        device(_mic ? LucideIcons.mic : LucideIcons.micOff, l10n.meetingDeviceMic(_mic ? (_micLabel ?? l10n.meetingDeviceDefault) : l10n.meetingDeviceOff)),
        device(_cam ? LucideIcons.video : LucideIcons.videoOff, l10n.meetingDeviceCamera(_cam ? (_camLabel ?? l10n.meetingDeviceDefault) : l10n.meetingDeviceOff)),
        const SizedBox(height: Space.lg),
        if (lobby != null)
          _LobbyCard(denied: lobby.denied, onCancel: _cancelLobby)
        else ...[
          FilledButton.icon(
            key: const Key('meet_join'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: joinable && !_joining ? _join : null,
            icon: _joining
                ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: t.onBrand))
                : const Icon(LucideIcons.video),
            label: Text(l10n.meetingJoin),
          ),
          if (!joinable && m.status != MeetingStatus.cancelled && m.status != MeetingStatus.ended)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Text(
                l10n.meetingOpensSoonHint,
                key: const Key('meet_join_hint'),
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textTertiary, fontSize: t.display.fontSizeMeta + 1),
              ),
            ),
        ],
      ],
    );
  }
}

class _PreviewBox extends ConsumerWidget {
  const _PreviewBox({required this.preview, required this.micOn, required this.camOn, required this.onMic, required this.onCam});
  final CallCameraPreview? preview;
  final bool micOn;
  final bool camOn;
  final VoidCallback onMic;
  final VoidCallback onCam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final me = ref.watch(currentUserProvider);
    final name = me?.displayName.isNotEmpty == true ? me!.displayName : (me?.email ?? '');

    Widget toggle(Key key, bool on, IconData onIcon, IconData offIcon, String label, VoidCallback tap) => Semantics(
      button: true,
      toggled: on,
      label: label,
      child: Material(
        color: on ? Colors.white.withValues(alpha: 0.18) : t.danger,
        shape: const CircleBorder(),
        child: InkWell(
          key: key,
          customBorder: const CircleBorder(),
          onTap: tap,
          child: SizedBox.square(dimension: 52, child: Icon(on ? onIcon : offIcon, color: Colors.white)),
        ),
      ),
    );

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(t.radiusLg),
        child: DecoratedBox(
          key: const Key('meet_preview'),
          decoration: const BoxDecoration(color: Color(0xFF0B111A)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (camOn && preview != null)
                preview!.view()
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InitialsAvatar(label: name, colorKey: me?.id ?? name, radius: 36),
                      const SizedBox(height: Space.sm),
                      Text(camOn ? l10n.meetingPreviewUnavailable : l10n.meetingCameraOff, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: Space.md,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    toggle(const Key('meet_mic_toggle'), micOn, LucideIcons.mic, LucideIcons.micOff, l10n.callsMic, onMic),
                    const SizedBox(width: Space.md),
                    toggle(const Key('meet_cam_toggle'), camOn, LucideIcons.video, LucideIcons.videoOff, l10n.callsCamera, onCam),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LobbyCard extends StatelessWidget {
  const _LobbyCard({required this.denied, required this.onCancel});
  final bool denied;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return DecoratedBox(
      key: Key(denied ? 'meet_lobby_denied' : 'meet_lobby_waiting'),
      decoration: BoxDecoration(
        color: denied ? t.dangerSoft : t.infoSoft,
        borderRadius: t.cardRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (denied)
                  Icon(LucideIcons.userX, color: t.danger)
                else
                  SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: t.info)),
                const SizedBox(width: Space.smd),
                Expanded(
                  child: Text(
                    denied ? l10n.meetingLobbyDenied : l10n.meetingLobbyTitle,
                    style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (!denied) ...[
              const SizedBox(height: Space.xs),
              Text(l10n.meetingLobbyText, style: TextStyle(color: t.textSecondary)),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(key: const Key('meet_lobby_cancel'), onPressed: onCancel, child: Text(denied ? l10n.close : l10n.cancel)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A guest link opened on a staff phone: guests join from a browser.
class _GuestLinkNotice extends ConsumerWidget {
  const _GuestLinkNotice({required this.code});
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final base = ref.watch(appEnvProvider).callsBaseUrl;
    return StateView.empty(
      icon: LucideIcons.link,
      title: l10n.meetingGuestLinkTitle,
      subtitle: l10n.meetingGuestLinkText,
      actionLabel: l10n.meetingOpenInBrowser,
      // In-app browser tab: the system would hand an external https link back
      // to XatBox (it handles meeting links).
      onAction: base.isEmpty ? null : () => launchUrl(Uri.parse('$base/meet/$code'), mode: LaunchMode.inAppBrowserView),
    );
  }
}
