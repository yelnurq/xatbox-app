import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/platform/desktop.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/initials_avatar.dart';
import '../../data/call_chat.dart';
import '../call_controller.dart';
import '../calls_providers.dart';
import 'call_style.dart';
import '../../../../shared/widgets/app_sheet.dart';

/// From this width the chat is a side panel inside the call screen; below it
/// a frosted bottom sheet. Always a panel on the desktop.
const callChatSidePanelMinWidth = 720.0;
const callChatSidePanelWidth = 360.0;

bool callChatAsSidePanel(BuildContext context) => isDesktop || MediaQuery.sizeOf(context).width >= callChatSidePanelMinWidth;

/// The side panel is open (wide layouts).
class CallChatPanelOpen extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool open) {
    if (ref.mounted) state = open;
  }
}

final callChatPanelOpenProvider = NotifierProvider<CallChatPanelOpen, bool>(CallChatPanelOpen.new);

/// Desktop: the participants list is open as the call screen's side panel
/// (in the chat's place: one panel at a time).
final callParticipantsPanelOpenProvider = NotifierProvider<CallChatPanelOpen, bool>(CallChatPanelOpen.new);

/// Opens (or, for the side panel, toggles) the in-call chat.
Future<void> openCallChat(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  if (callChatAsSidePanel(context)) {
    final open = !container.read(callChatPanelOpenProvider);
    container.read(callChatPanelOpenProvider.notifier).set(open);
    if (open && isDesktop) container.read(callParticipantsPanelOpenProvider.notifier).set(false);
    return;
  }
  await showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (sheet) => _CallChatSheet(onClose: () => Navigator.of(sheet).pop()),
  );
}

class _CallChatSheet extends StatelessWidget {
  const _CallChatSheet({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final pal = context.callPalette;
    final size = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final height = math.max(220.0, math.min(size.height * 0.75, size.height - keyboard - 16));
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [pal.bgTop.withValues(alpha: 0.94), pal.bgBottom.withValues(alpha: 0.97)],
              ),
              border: Border(top: BorderSide(color: pal.glassBorder)),
            ),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: CallPalette.ink),
              child: CallChatView(onClose: onClose),
            ),
          ),
        ),
      ),
    );
  }
}

/// Side panel of wide layouts (placed by the call screen).
class CallChatSidePanel extends ConsumerWidget {
  const CallChatSidePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => CallGlass(
    radius: 24,
    strong: true,
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: CallPalette.ink),
      child: CallChatView(onClose: () => ref.read(callChatPanelOpenProvider.notifier).set(false)),
    ),
  );
}

const _emojis = ['👍', '👏', '😂', '❤️', '🎉', '🤔', '😊', '😉', '😍', '🙏', '🔥', '✅', '👌', '🙌', '😅', '😮', '😢', '👋', '💯', '🤝', '☕', '📌', '⏰', '👀'];

/// Message list and composer. While mounted, incoming messages count as read.
class CallChatView extends ConsumerStatefulWidget {
  const CallChatView({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  ConsumerState<CallChatView> createState() => _CallChatViewState();
}

class _CallChatViewState extends ConsumerState<CallChatView> {
  late final CallController _controller;
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _emoji = false;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(callControllerProvider.notifier);
    // Providers must not change while the tree builds: defer.
    Future.microtask(() => _controller.setChatOpen(true));
  }

  @override
  void dispose() {
    final controller = _controller;
    Future.microtask(() => controller.setChatOpen(false));
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text;
    if (text.trim().isEmpty) return;
    _text.clear();
    final sent = await _controller.sendChatMessage(text);
    if (!sent && mounted && _text.text.isEmpty) _text.text = text;
  }

  void _insert(String emoji) {
    final value = _text.value;
    final sel = value.selection;
    final start = sel.isValid ? sel.start : value.text.length;
    final end = sel.isValid ? sel.end : value.text.length;
    if (value.text.length - (end - start) + emoji.length > callChatMaxLength) return;
    _text.value = TextEditingValue(
      text: value.text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pal = context.callPalette;
    final messages = ref.watch(callControllerProvider.select((s) => s.chat));
    final linked = ref.watch(callControllerProvider.select((s) => (s.call?.conversationId ?? '').isNotEmpty));
    final selfId = ref.watch(currentUserProvider)?.id ?? '';

    return Column(
      key: const Key('call_chat_panel'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.xs, Space.xs),
          child: Row(
            children: [
              const ExcludeSemantics(child: Icon(LucideIcons.messagesSquare, size: 20, color: CallPalette.ink)),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  l10n.callsChatTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: CallPalette.ink, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                key: const Key('call_chat_close'),
                tooltip: l10n.callsChatClose,
                onPressed: widget.onClose,
                icon: const Icon(LucideIcons.x, color: CallPalette.ink, size: 20),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: pal.glassBorder),
        Expanded(
          child: messages.isEmpty
              ? _EmptyChat(linked: linked)
              : ListView.builder(
                  key: const Key('call_chat_list'),
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: Space.smd, vertical: Space.sm),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final index = messages.length - 1 - i;
                    final m = messages[index];
                    final prev = index > 0 ? messages[index - 1] : null;
                    final grouped = prev != null && prev.senderId == m.senderId && m.createdAt.difference(prev.createdAt).inMinutes < 3;
                    return _Bubble(message: m, mine: m.local || m.senderId == selfId, showName: !grouped, onRetry: () => _controller.retryChatMessage(m.id));
                  },
                ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: _emoji ? _EmojiGrid(onPick: _insert) : const SizedBox(width: double.infinity),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.xs, Space.xs, Space.sm, Space.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  key: const Key('call_chat_emoji'),
                  tooltip: l10n.callsChatEmoji,
                  onPressed: () {
                    setState(() => _emoji = !_emoji);
                    if (!_emoji) _focus.requestFocus();
                  },
                  icon: Icon(_emoji ? LucideIcons.keyboard : LucideIcons.smile, color: pal.inkSecondary, size: 22),
                ),
                Expanded(
                  child: TextField(
                    key: const Key('call_chat_input'),
                    controller: _text,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: callChatMaxLength,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    onTap: () {
                      if (_emoji) setState(() => _emoji = false);
                    },
                    cursorColor: CallPalette.ink,
                    style: const TextStyle(color: CallPalette.ink, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: l10n.callsChatHint,
                      hintStyle: TextStyle(color: pal.inkTertiary),
                      counterText: '',
                      isDense: true,
                      filled: true,
                      fillColor: pal.glassStrong,
                      contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.smd - 2),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: Space.xs + 2),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _text,
                  builder: (_, value, _) {
                    final enabled = value.text.trim().isNotEmpty;
                    // 42 dp circle inside a 48 dp hit area.
                    return Semantics(
                      button: true,
                      enabled: enabled,
                      label: l10n.callsChatSend,
                      onTap: enabled ? _send : null,
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        excludeFromSemantics: true,
                        onTap: enabled ? _send : null,
                        child: SizedBox.square(
                          dimension: 48,
                          child: Center(
                            child: Material(
                              color: enabled ? pal.activeFill : pal.glassStrong,
                              shape: const CircleBorder(),
                              child: InkWell(
                                key: const Key('call_chat_send'),
                                customBorder: const CircleBorder(),
                                onTap: enabled ? _send : null,
                                child: SizedBox.square(
                                  dimension: 42,
                                  child: Icon(LucideIcons.sendHorizontal, size: 20, color: enabled ? pal.activeInk : pal.inkTertiary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.linked});
  final bool linked;

  @override
  Widget build(BuildContext context) {
    final pal = context.callPalette;
    final l10n = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(LucideIcons.messageSquareText, size: 36, color: pal.inkTertiary)),
            const SizedBox(height: Space.smd),
            Text(
              linked ? l10n.callsChatEmptyLinked : l10n.callsChatEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(color: pal.inkSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

String _hm(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// Readable name colour on the dark stage.
Color _nameColor(BuildContext context, String key) => HSLColor.fromColor(context.tokens.avatarColorFor(key)).withLightness(0.74).withSaturation(0.6).toColor();

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, required this.showName, required this.onRetry});
  final CallChatMessage message;
  final bool mine;
  final bool showName;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final pal = context.callPalette;
    final l10n = context.l10n;
    final failed = message.status == CallChatStatus.failed;
    final maxWidth = math.min(300.0, MediaQuery.sizeOf(context).width * 0.78);
    const r = Radius.circular(18);
    const tail = Radius.circular(6);
    // Sender, text, time and delivery state as one node; a failed message
    // is a button that retries.
    final semanticLabel = [
      if (!mine && message.senderName.isNotEmpty) message.senderName,
      message.body,
      _hm(message.createdAt),
      if (message.status == CallChatStatus.sending) l10n.chatPending,
      if (failed) l10n.callsChatFailed,
    ].join(', ');
    return Align(
      key: ValueKey('call_chat_msg_${message.id}'),
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(top: showName ? Space.sm : Space.xxs),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Semantics(
            container: true,
            button: failed,
            label: semanticLabel,
            onTap: failed ? onRetry : null,
            onTapHint: failed ? l10n.chatRetry : null,
            excludeSemantics: true,
            child: GestureDetector(
              key: failed ? ValueKey('call_chat_retry_${message.id}') : null,
              onTap: failed ? onRetry : null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: mine ? pal.glow.withValues(alpha: 0.34) : pal.glassStrong,
                  borderRadius: BorderRadius.only(topLeft: r, topRight: r, bottomLeft: mine ? r : tail, bottomRight: mine ? tail : r),
                  border: failed ? Border.all(color: pal.danger.withValues(alpha: 0.7)) : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.smd, Space.xs + 3, Space.smd, Space.xs + 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showName && !mine && message.senderName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            message.senderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _nameColor(context, message.senderId), fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      Text(message.body, style: const TextStyle(color: CallPalette.ink, fontSize: 15, height: 1.3)),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (failed) ...[
                            Icon(LucideIcons.circleAlert, size: 12, color: pal.danger),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(l10n.callsChatFailed, style: TextStyle(color: pal.danger, fontSize: 11)),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(_hm(message.createdAt), style: TextStyle(color: pal.inkTertiary, fontSize: 11)),
                          if (message.status == CallChatStatus.sending) ...[
                            const SizedBox(width: 4),
                            Icon(LucideIcons.clock3, size: 11, color: pal.inkTertiary),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmojiGrid extends StatelessWidget {
  const _EmojiGrid({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final pal = context.callPalette;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 136),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: pal.glassBorder)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
        child: Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (final (i, e) in _emojis.indexed)
              InkWell(
                key: ValueKey('call_chat_emoji_$i'),
                customBorder: const CircleBorder(),
                onTap: () => onPick(e),
                child: SizedBox.square(
                  dimension: 48,
                  child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small counter badge (chat unread).
class CallCountBadge extends StatelessWidget {
  const CallCountBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final pal = context.callPalette;
    final l10n = context.l10n;
    return Semantics(
      label: l10n.a11yUnreadCount(count),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 18),
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: pal.danger,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: pal.bgBottom, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(color: CallPalette.ink, fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.1),
        ),
      ),
    );
  }
}

/// Preview bubble of a new message while the chat is closed; a tap opens it.
class CallChatToasts extends ConsumerStatefulWidget {
  const CallChatToasts({super.key});

  @override
  ConsumerState<CallChatToasts> createState() => _CallChatToastsState();
}

class _CallChatToastsState extends ConsumerState<CallChatToasts> {
  CallChatMessage? _shown;
  Timer? _timer;
  StreamSubscription<CallChatMessage>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(callControllerProvider.notifier).chatToasts.listen((m) {
      if (!mounted) return;
      setState(() => _shown = m);
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _shown = null);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a),
          child: child,
        ),
      ),
      child: shown == null
          ? const SizedBox.shrink()
          : KeyedSubtree(
              key: ValueKey(shown.id),
              child: _ToastBubble(
                message: shown,
                onTap: () {
                  _timer?.cancel();
                  setState(() => _shown = null);
                  unawaited(openCallChat(context));
                },
              ),
            ),
    );
  }
}

class _ToastBubble extends StatelessWidget {
  const _ToastBubble({required this.message, required this.onTap});
  final CallChatMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.callPalette;
    final name = message.senderName;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      // Announced when it appears; a tap opens the chat.
      child: Semantics(
        container: true,
        button: true,
        liveRegion: true,
        label: [if (name.isNotEmpty) name, message.body].join(': '),
        onTap: onTap,
        onTapHint: context.l10n.callsChat,
        excludeSemantics: true,
        child: GestureDetector(
          key: const Key('call_chat_toast'),
          onTap: onTap,
          child: CallGlass(
            radius: 20,
            strong: true,
            padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.smd, Space.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InitialsAvatar(label: name.isEmpty ? '?' : name, colorKey: message.senderId, radius: 16),
                const SizedBox(width: Space.sm),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (name.isNotEmpty)
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: CallPalette.ink, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      Text(
                        message.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: pal.inkSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
