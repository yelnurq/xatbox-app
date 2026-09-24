import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/platform/desktop.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../calls/presentation/calls_providers.dart';
import '../data/chat_mentions.dart';
import '../data/chat_models.dart';
import '../data/chat_photo.dart';
import '../data/chat_text.dart';
import '../data/chat_translation.dart';
import 'chat_formatters.dart';
import 'chat_providers.dart';
import 'poll/poll_card.dart';
import 'requests/request_widgets.dart';
import 'stickers/chat_sticker_view.dart';
import 'transcription/voice_transcript.dart';
import 'translation/message_translation_view.dart';

/// One message row (ТЗ п.24.7): bubble with a tail on the last message of a
/// group, sender name / avatar once per group, reply and forward headers,
/// attachments, contact card, mentions and links, reactions, time and
/// delivery status inside the bubble, edited/deleted markers; system
/// messages are centred pills. Swipe left to reply.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.isGroup,
    required this.senderName,
    required this.memberNames,
    this.senderEmail = '',
    required this.onLongPress,
    required this.onReactionTap,
    required this.onRetry,
    required this.onDiscard,
    this.mentionNames = const {},
    this.selfId = '',
    this.firstInGroup = true,
    this.lastInGroup = true,
    this.mediaAuto = false,
    this.highlighted = false,
    this.selecting = false,
    this.selected = false,
    this.onTap,
    this.onReply,
    this.onReplyTap,
    this.onOpenMedia,
    this.onLinkTap,
    this.onOpenComments,
    this.onContextMenu,
    this.onDoubleClick,
    this.onSenderTap,
    this.currentRequest,
  });

  /// «Заявки»: the newest state of this message's request (the card of a
  /// filed request shows the current status); null = [ChatMessage.request].
  final ChatRequest? currentRequest;

  /// Desktop: right click with the pointer position (the menu opens there);
  /// null: right click is [onLongPress].
  final ValueChanged<Offset>? onContextMenu;

  /// Desktop: double click on the bubble (the web's ❤️ reaction).
  final VoidCallback? onDoubleClick;

  /// Desktop groups: a click on the sender's name or picture opens the
  /// one-to-one chat with them («Написать лично»).
  final VoidCallback? onSenderTap;

  /// Channel posts with comments enabled: «N комментариев» opens the thread.
  final VoidCallback? onOpenComments;

  final ChatMessage message;
  final bool isOwn;
  final bool isGroup;
  final String senderName;

  /// Address of the sender, when the conversation knows it: the profile
  /// photo is looked up with it, exactly as in the mail list.
  final String senderEmail;
  final Map<String, String> memberNames;

  /// Real member labels by user id, used to find `@Name` in the body.
  final Map<String, String> mentionNames;
  final String selfId;

  /// Consecutive messages of one sender within a few minutes form a group:
  /// the name is shown on the first, the avatar and tail on the last.
  final bool firstInGroup;
  final bool lastInGroup;

  /// Whether previews and voice notes may be fetched without a tap.
  final bool mediaAuto;

  /// Flash after a jump to this message.
  final bool highlighted;
  final bool selecting;
  final bool selected;
  final VoidCallback onLongPress;
  final void Function(String emoji) onReactionTap;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  /// Tap on the row (selection mode).
  final VoidCallback? onTap;

  /// Swipe-to-reply.
  final VoidCallback? onReply;

  /// Tap on the quoted message: jump to it.
  final void Function(String messageId)? onReplyTap;

  /// Tap on a photo: open the in-app viewer.
  final void Function(ChatAttachment attachment)? onOpenMedia;
  final void Function(Uri uri)? onLinkTap;

  static const groupGap = Duration(minutes: 5);

  /// Whether [a] and [b] (neighbours) belong to one visual group.
  static bool sameGroup(ChatMessage a, ChatMessage b) {
    if (a.isServiceLike || b.isServiceLike || a.senderId != b.senderId) {
      return false;
    }
    final la = a.createdAt.toLocal();
    final lb = b.createdAt.toLocal();
    if (la.year != lb.year || la.month != lb.month || la.day != lb.day) {
      return false;
    }
    return la.difference(lb).abs() <= groupGap;
  }

  bool get _visualOnly =>
      message.body.isEmpty &&
      !message.isContact &&
      !message.isDeleted &&
      message.replyTo == null &&
      message.forwardOfId == null &&
      message.attachments.isNotEmpty &&
      message.attachments.every(
        (a) =>
            (a.kind == 'image' || a.kind == 'video') &&
            a.hasThumbnail &&
            !a.id.startsWith('local:'),
      );

  /// Content a screen-reader user operates on its own (links, media, voice,
  /// reactions, quotes, polls, contact buttons, retry): the row then stays a
  /// container so those children remain reachable. Otherwise the whole
  /// message is announced as one node.
  bool get _hasActionableContent {
    final m = message;
    return m.attachments.isNotEmpty ||
        _showComments ||
        m.reactions.isNotEmpty ||
        m.failed ||
        m.isPoll ||
        m.isContact ||
        m.isSticker ||
        m.replyTo != null ||
        m.linkPreview != null ||
        (!m.isDeleted &&
            m.body.isNotEmpty &&
            ChatText.links(m.body).any((l) => l.uri != null));
  }

  bool get _showComments =>
      onOpenComments != null &&
      message.commentCount != null &&
      !message.isDeleted;

  /// «Имя, [переслано], [текст], [вложения], время, [изменено], [просмотры],
  /// [статус]» — the body only when the row is announced as one node.
  String _semanticsLabel(BuildContext context, {required bool withBody}) {
    final l10n = context.l10n;
    final m = message;
    final kinds = <String>{
      for (final a in m.attachments)
        switch (a.kind) {
          'image' => l10n.chatAttachmentImage,
          'video' => l10n.chatAttachmentVideo,
          'voice' => l10n.chatAttachmentVoice,
          'audio' => l10n.chatAttachmentAudio,
          _ => l10n.chatAttachmentFile,
        },
    };
    final String? status = m.failed
        ? l10n.chatFailed
        : (!isOwn
              ? null
              : (m.pending
                    ? l10n.chatPending
                    : switch (m.status) {
                        'read' => l10n.chatStatusRead,
                        'delivered' => l10n.chatStatusDelivered,
                        _ => l10n.chatStatusSent,
                      }));
    final body = m.isDeleted ? l10n.chatDeleted : m.body;
    return [
      if (isOwn) l10n.chatYou else if (senderName.isNotEmpty) senderName,
      if (m.forwardOfId != null) _ForwardHeader.label(l10n, m, memberNames),
      if (withBody && body.isNotEmpty) body,
      ...kinds,
      if (m.expiresAt != null && !m.isDeleted) l10n.chatDisappearingMessage,
      ChatFormat.time(context, m.createdAt),
      if (m.editedAt != null && !m.isDeleted) l10n.chatEdited,
      if (m.views != null && !m.isDeleted) l10n.channelViews(m.views!),
      ?status,
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final m = message;
    // System messages and «Автоответ: …» are centred service pills.
    if (m.isServiceLike) return _SystemPill(message: m, names: memberNames);

    final mentionsMe =
        !isOwn && selfId.isNotEmpty && m.mentions.contains(selfId);
    final emojiOnly =
        !m.isDeleted &&
        m.attachments.isEmpty &&
        m.replyTo == null &&
        m.forwardOfId == null &&
        m.type == 'text' &&
        ChatText.isEmojiOnly(m.body);
    // A sticker is drawn large without a bubble (with a quote or a forward
    // header it stays inside one).
    final stickerOnly =
        m.isSticker &&
        !m.isDeleted &&
        m.replyTo == null &&
        m.forwardOfId == null;
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = math.min(width * 0.8, 520.0);
    final showAvatar = isGroup && !isOwn;
    final visualOnly = _visualOnly;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isGroup && !isOwn && firstInGroup && !emojiOnly && !stickerOnly)
          Padding(
            padding: EdgeInsets.fromLTRB(
              visualOnly ? Space.sm : 0,
              visualOnly ? Space.xs : 0,
              0,
              2,
            ),
            // Announced by the row label.
            child: ExcludeSemantics(
              child: _SenderTap(
                onTap: onSenderTap,
                child: Text(
                  senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: t.avatarTextColorFor(m.senderId),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        if (m.forwardOfId != null) _ForwardHeader(message: m, names: memberNames),
        if (m.replyTo != null)
          _ReplyPreview(
            preview: m.replyTo!,
            names: memberNames,
            isOwn: isOwn,
            onTap: onReplyTap == null ? null : () => onReplyTap!(m.replyTo!.id),
          ),
        for (final a in m.attachments)
          _AttachmentView(
            key: ValueKey('att_${a.id}'),
            attachment: a,
            message: m,
            mediaAuto: mediaAuto,
            onOpenMedia: onOpenMedia,
            bare: visualOnly,
          ),
        if (m.isDeleted)
          _TextWithMeta(
            meta: _Meta(message: m, isOwn: isOwn),
            child: Text(
              context.l10n.chatDeleted,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: t.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else if (m.isPoll && m.poll != null) ...[
          PollCard(message: m, selfId: selfId),
          Align(
            alignment: Alignment.centerRight,
            child: _Meta(message: m, isOwn: isOwn),
          ),
        ] else if (m.isRequest && m.request != null) ...[
          RequestCard(request: currentRequest ?? m.request!),
          Align(
            alignment: Alignment.centerRight,
            child: _Meta(message: m, isOwn: isOwn),
          ),
        ] else if (m.isRequestUpdate && m.request != null) ...[
          RequestUpdateView(message: m),
          Align(
            alignment: Alignment.centerRight,
            child: _Meta(message: m, isOwn: isOwn),
          ),
        ] else if (m.isContact) ...[
          _ContactCard(message: m, selfId: selfId),
          Align(
            alignment: Alignment.centerRight,
            child: _Meta(message: m, isOwn: isOwn),
          ),
        ] else if (m.isSticker) ...[
          ChatStickerMessage(message: m, size: stickerOnly ? 168 : 128),
          Align(
            // Desktop: as wide as the sticker, so a wide pane keeps it at
            // the edge instead of the middle of the bubble's max width.
            widthFactor: isDesktop ? 1 : null,
            alignment: Alignment.centerRight,
            child: _Meta(message: m, isOwn: isOwn, pill: stickerOnly),
          ),
        ] else if (emojiOnly) ...[
          Text(
            m.body,
            key: ValueKey('emoji_only_${m.id}'),
            style: const TextStyle(fontSize: 44, height: 1.15),
          ),
          Align(
            widthFactor: isDesktop ? 1 : null,
            alignment: Alignment.centerRight,
            child: _Meta(message: m, isOwn: isOwn, pill: true),
          ),
        ] else if (m.body.isNotEmpty && m.linkPreview != null) ...[
          _MessageText(
            message: m,
            names: mentionNames,
            selfId: selfId,
            onLinkTap: onLinkTap,
          ),
          _LinkPreviewCard(
            key: ValueKey('link_preview_${m.id}'),
            message: m,
            isOwn: isOwn,
            mediaAuto: mediaAuto,
            onTap: onLinkTap,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _Meta(message: m, isOwn: isOwn),
          ),
        ] else if (m.body.isNotEmpty)
          _TextWithMeta(
            meta: _Meta(message: m, isOwn: isOwn),
            child: _MessageText(
              message: m,
              names: mentionNames,
              selfId: selfId,
              onLinkTap: onLinkTap,
            ),
          )
        else if (!visualOnly)
          Align(
            alignment: Alignment.centerRight,
            child: _Meta(message: m, isOwn: isOwn),
          ),
        // «Перевести» / auto translation (translation/, hidden when off).
        if (chatMessageTranslatable(m))
          MessageTranslationView(message: m, isOwn: isOwn),
        if (m.reactions.isNotEmpty)
          Padding(
            // Each chip sits in a 48 dp touch box, which already gives the
            // visual gap above and between rows.
            padding: EdgeInsets.fromLTRB(
              visualOnly ? Space.xs : 0,
              0,
              visualOnly ? Space.xs : 0,
              0,
            ),
            child: Wrap(
              spacing: Space.xs,
              runSpacing: 0,
              children: [
                for (final r in m.reactions)
                  _ReactionChip(
                    reaction: r,
                    onTap: () => onReactionTap(r.reaction),
                  ),
              ],
            ),
          ),
        if (m.failed)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // The status is part of the row label.
              ExcludeSemantics(
                child: Text(
                  context.l10n.chatFailed,
                  style: theme.textTheme.labelSmall?.copyWith(color: t.danger),
                ),
              ),
              TextButton(onPressed: onRetry, child: Text(context.l10n.chatRetry)),
              TextButton(
                onPressed: onDiscard,
                child: Text(context.l10n.chatDiscard),
              ),
            ],
          ),
        if (_showComments)
          _CommentsButton(message: m, onTap: onOpenComments!),
      ],
    );

    final bubbleColor = emojiOnly || stickerOnly
        ? null
        : (isOwn ? t.primarySoft : t.surface);
    final tail = lastInGroup && !emojiOnly && !stickerOnly;
    final bubble = CustomPaint(
      key: mentionsMe ? ValueKey('mentions_me_${m.id}') : null,
      painter: bubbleColor == null
          ? null
          : BubblePainter(
              color: bubbleColor,
              border: mentionsMe
                  ? t.primary
                  : (isOwn || t.shadowSm.isNotEmpty ? null : t.border),
              borderWidth: mentionsMe ? 1.5 : t.borderWidth,
              radius: t.radiusLg.clamp(10, 20),
              smallRadius: t.radiusXs.clamp(3, 8),
              isOwn: isOwn,
              tail: tail,
              joinTop: !firstInGroup,
              shadow: t.shadowSm.isEmpty ? null : t.shadowSm.last.color,
            ),
      child: Padding(
        padding: visualOnly
            ? EdgeInsets.fromLTRB(
                isOwn ? 3 : 3 + BubblePainter.tailWidth,
                3,
                isOwn ? 3 + BubblePainter.tailWidth : 3,
                3,
              )
            : EdgeInsets.fromLTRB(
                isOwn ? Space.smd - 2 : Space.smd - 2 + BubblePainter.tailWidth,
                Space.xs + 2,
                isOwn ? Space.smd - 2 + BubblePainter.tailWidth : Space.smd - 2,
                Space.xs + 1,
              ),
        child: content,
      ),
    );

    Widget row = Row(
      mainAxisAlignment: isOwn
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (selecting)
          Padding(
            padding: const EdgeInsets.only(right: Space.sm, bottom: Space.xs),
            child: Icon(
              selected ? LucideIcons.circleCheck : LucideIcons.circle,
              key: ValueKey('select_${m.id}'),
              size: 22,
              color: selected ? t.primary : t.textTertiary,
            ),
          ),
        if (isOwn) const SizedBox(width: Space.xxxl),
        if (showAvatar)
          Padding(
            padding: const EdgeInsets.only(right: Space.xxs),
            child: lastInGroup
                ? ExcludeSemantics(
                    child: _SenderTap(
                      onTap: onSenderTap,
                      child: senderEmail.isEmpty
                        ? InitialsAvatar(
                            label: senderName.isEmpty ? '?' : senderName,
                            colorKey: m.senderId,
                            radius: InitialsAvatar.radiusSm,
                          )
                        : UserAvatar(
                            email: senderEmail,
                            label: senderName.isEmpty ? '?' : senderName,
                            radius: InitialsAvatar.radiusSm,
                            excludeFromSemantics: true,
                          ),
                    ),
                  )
                : const SizedBox(width: InitialsAvatar.radiusSm * 2),
          ),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            // While selecting, a tap anywhere toggles the row instead of
            // opening files, links or quotes inside it.
            child: IgnorePointer(
              ignoring: selecting,
              child: onDoubleClick == null || selecting || m.isDeleted
                  ? bubble
                  : _DoubleClick(onDoubleClick: onDoubleClick!, child: bubble),
            ),
          ),
        ),
        if (!isOwn) const SizedBox(width: Space.xxl),
      ],
    );

    // Screen readers: plain messages are one node («Имя, текст, время,
    // прочитано»); messages with links, media, reactions etc. keep a summary
    // label and expose those children separately. The Semantics sits above
    // the GestureDetector so tap / long press land on this node.
    final merged = !_hasActionableContent;
    final canReply = onReply != null && !selecting && m.seq > 0 && !m.isDeleted;
    row = Semantics(
      container: true,
      label: _semanticsLabel(context, withBody: merged),
      selected: selecting ? selected : null,
      customSemanticsActions: canReply
          ? {CustomSemanticsAction(label: context.l10n.chatReply): onReply!}
          : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selecting ? onTap : null,
        onLongPress: m.isDeleted && !selecting ? null : onLongPress,
        onSecondaryTap: (m.isDeleted && !selecting) || onContextMenu != null ? null : onLongPress,
        onSecondaryTapUp: (m.isDeleted && !selecting) || onContextMenu == null
            ? null
            : (d) => onContextMenu!(d.globalPosition),
        child: ExcludeSemantics(
          excluding: merged,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            color: highlighted || selected ? t.selection : t.selection.withValues(alpha: 0),
            padding: EdgeInsets.only(
              left: Space.sm,
              right: Space.sm,
              top: firstInGroup ? Space.xs + 1 : 1,
              bottom: lastInGroup ? Space.xxs : 1,
            ),
            child: row,
          ),
        ),
      ),
    );
    // Desktop: a mouse drag selects text; reply is in the right-click menu.
    if (canReply && !isDesktop) {
      row = SwipeToReply(onReply: onReply!, child: row);
    }
    return row;
  }
}

/// Two primary clicks close together, seen without joining the gesture
/// arena, so links, photos and text selection inside react at once.
class _DoubleClick extends StatefulWidget {
  const _DoubleClick({required this.onDoubleClick, required this.child});
  final VoidCallback onDoubleClick;
  final Widget child;

  @override
  State<_DoubleClick> createState() => _DoubleClickState();
}

class _DoubleClickState extends State<_DoubleClick> {
  Duration? _lastAt;
  Offset? _lastPosition;

  void _onDown(PointerDownEvent e) {
    if (e.buttons != kPrimaryButton) return;
    final last = _lastAt;
    final lastPosition = _lastPosition;
    if (last != null &&
        lastPosition != null &&
        e.timeStamp - last <= kDoubleTapTimeout &&
        (e.position - lastPosition).distance <= kDoubleTapSlop) {
      _lastAt = null;
      widget.onDoubleClick();
      return;
    }
    _lastAt = e.timeStamp;
    _lastPosition = e.position;
  }

  @override
  Widget build(BuildContext context) => Listener(onPointerDown: _onDown, child: widget.child);
}

/// Paints a chat bubble: rounded rectangle, smaller corners where it joins
/// the neighbour of the same group, and a curved tail at the bottom corner
/// of the last message of a group.
class BubblePainter extends CustomPainter {
  const BubblePainter({
    required this.color,
    required this.radius,
    required this.smallRadius,
    required this.isOwn,
    required this.tail,
    required this.joinTop,
    this.border,
    this.borderWidth = 1,
    this.shadow,
  });

  static const tailWidth = 6.0;

  final Color color;
  final Color? border;
  final double borderWidth;
  final double radius;
  final double smallRadius;
  final bool isOwn;
  final bool tail;
  final bool joinTop;
  final Color? shadow;

  Path _path(Size size) {
    final rect = isOwn
        ? Rect.fromLTRB(0, 0, size.width - tailWidth, size.height)
        : Rect.fromLTRB(tailWidth, 0, size.width, size.height);
    final big = Radius.circular(radius);
    final small = Radius.circular(smallRadius);
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: !isOwn && joinTop ? small : big,
      topRight: isOwn && joinTop ? small : big,
      bottomLeft: !isOwn ? small : big,
      bottomRight: isOwn ? small : big,
    );
    final path = Path()..addRRect(rrect);
    if (!tail) return path;
    final tailPath = Path();
    if (isOwn) {
      tailPath
        ..moveTo(rect.right - 10, rect.bottom)
        ..lineTo(size.width, rect.bottom)
        ..quadraticBezierTo(
          rect.right + 1,
          rect.bottom - 3,
          rect.right,
          rect.bottom - 12,
        )
        ..lineTo(rect.right - 10, rect.bottom - 12)
        ..close();
    } else {
      tailPath
        ..moveTo(rect.left + 10, rect.bottom)
        ..lineTo(0, rect.bottom)
        ..quadraticBezierTo(
          rect.left - 1,
          rect.bottom - 3,
          rect.left,
          rect.bottom - 12,
        )
        ..lineTo(rect.left + 10, rect.bottom - 12)
        ..close();
    }
    return Path.combine(PathOperation.union, path, tailPath);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _path(size);
    if (shadow != null) canvas.drawShadow(path, shadow!, 1.5, false);
    canvas.drawPath(path, Paint()..color = color);
    if (border != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = border!
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth,
      );
    }
  }

  @override
  bool shouldRepaint(BubblePainter old) =>
      old.color != color ||
      old.border != border ||
      old.borderWidth != borderWidth ||
      old.radius != radius ||
      old.smallRadius != smallRadius ||
      old.isOwn != isOwn ||
      old.tail != tail ||
      old.joinTop != joinTop ||
      old.shadow != shadow;
}

/// Drag the row left to reply; a light haptic tick when the threshold is
/// crossed, then it springs back.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({super.key, required this.onReply, required this.child});
  final VoidCallback onReply;
  final Widget child;

  static const threshold = 56.0;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  late final AnimationController _back = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..addListener(() => setState(() => _dx = _from * (1 - _back.value)));
  double _dx = 0;
  double _from = 0;
  bool _armed = false;

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _update(DragUpdateDetails d) {
    _back.stop();
    final next = (_dx + d.delta.dx).clamp(-SwipeToReply.threshold * 1.4, 0.0);
    final armed = next <= -SwipeToReply.threshold;
    if (armed && !_armed) HapticFeedback.lightImpact();
    setState(() {
      _dx = next;
      _armed = armed;
    });
  }

  void _end(DragEndDetails _) {
    if (_armed) widget.onReply();
    _armed = false;
    _from = _dx;
    _back.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final progress = (-_dx / SwipeToReply.threshold).clamp(0.0, 1.0);
    return GestureDetector(
      // Screen readers get a «Ответить» custom action on the message row
      // instead of scroll actions from the drag.
      excludeFromSemantics: true,
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: () => _end(DragEndDetails()),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          if (_dx < 0)
            Positioned(
              right: Space.md,
              child: ExcludeSemantics(
                child: Opacity(
                opacity: progress,
                child: Transform.scale(
                  scale: 0.6 + 0.4 * progress,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: _armed ? t.primary : t.surfaceMuted,
                    child: Icon(
                      LucideIcons.reply,
                      size: 18,
                      color: _armed ? t.textInverse : t.textSecondary,
                    ),
                  ),
                ),
              ),
              ),
            ),
          Transform.translate(offset: Offset(_dx, 0), child: widget.child),
        ],
      ),
    );
  }
}

/// «12 комментариев» / «Комментировать» under a channel post (48 dp).
class _CommentsButton extends StatelessWidget {
  const _CommentsButton({required this.message, required this.onTap});
  final ChatMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final count = message.commentCount ?? 0;
    final label = count == 0 ? l10n.commentsLeave : l10n.commentsCount(count);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('comments_${message.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(t.radiusSm),
        child: Container(
          constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
          margin: const EdgeInsets.only(top: Space.xs),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: t.divider, width: t.borderWidth),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.messageSquare, size: 16, color: t.primary),
              const SizedBox(width: Space.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: t.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: Space.xs),
              Icon(LucideIcons.chevronRight, size: 16, color: t.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemPill extends StatelessWidget {
  const _SystemPill({required this.message, required this.names});
  final ChatMessage message;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: Space.xs,
        horizontal: Space.md,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.smd,
            vertical: Space.xs,
          ),
          decoration: BoxDecoration(
            color: t.surfaceSubtle.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(XatBoxTokens.radiusPill),
            border: Border.all(color: t.border, width: t.borderWidth),
          ),
          child: Text(
            ChatFormat.systemText(context.l10n, message, names: names),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// Text followed by the time/status: on the same line when it fits,
/// otherwise below, aligned right.
class _TextWithMeta extends StatelessWidget {
  const _TextWithMeta({required this.child, required this.meta});
  final Widget child;
  final Widget meta;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.end,
    crossAxisAlignment: WrapCrossAlignment.end,
    spacing: Space.sm,
    children: [child, meta],
  );
}

/// Edited marker, time and (own messages) delivery status.
class _Meta extends StatelessWidget {
  const _Meta({required this.message, required this.isOwn, this.pill = false});
  final ChatMessage message;
  final bool isOwn;

  /// Over media / emoji: a contrasting pill.
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final color = pill ? scheme.onInverseSurface : t.textTertiary;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: color,
      fontSize: 11 * t.display.scale,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final m = message;
    // A Wrap, not a Row: in narrow sticker / emoji pills at large text sizes
    // the items move to a second line instead of overflowing. Everything
    // here is announced by the message row label.
    final row = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (m.editedAt != null && !m.isDeleted)
          Text('${context.l10n.chatEdited} ', style: style),
        if (m.expiresAt != null && !m.isDeleted)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Tooltip(
              message: context.l10n.chatDisappearingMessage,
              child: Icon(
                LucideIcons.timer,
                key: ValueKey('disappearing_${m.id}'),
                size: 11 * t.display.scale,
                color: color,
              ),
            ),
          ),
        if (m.views != null && !m.isDeleted) ...[
          // Channel posts: subscribers who read it.
          Icon(
            LucideIcons.eye,
            key: ValueKey('views_${m.id}'),
            size: 12 * t.display.scale,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '${m.views} ',
            style: style,
            semanticsLabel: context.l10n.channelViews(m.views!),
          ),
        ],
        Text(ChatFormat.time(context, m.createdAt), style: style),
        if (isOwn) ...[
          const SizedBox(width: 3),
          _StatusIcon(message: m, color: pill ? color : null),
        ],
      ],
    );
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: pill
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.inverseSurface.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(XatBoxTokens.radiusPill),
                ),
                child: row,
              )
            : row,
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.reaction, required this.onTap});
  final ChatReaction reaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = reaction;
    // The visible chip stays ~24 dp; the transparent box around it makes a
    // 48 × 48 dp touch target. The chip's own InkWell keeps the ripple and
    // stays out of semantics so the node has a single tap action.
    return Semantics(
      container: true,
      button: true,
      selected: r.me,
      label: context.l10n.a11yReaction(r.reaction, r.count),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kMinInteractiveDimension,
            minHeight: kMinInteractiveDimension,
          ),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            child: Material(
              color: r.me ? t.primary : t.surfaceSubtle,
              shape: StadiumBorder(
                side: BorderSide(color: r.me ? t.primary : t.border, width: t.borderWidth),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                excludeFromSemantics: true,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
                  child: ExcludeSemantics(
                    child: Text(
                      '${r.reaction} ${r.count}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: r.me ? t.textInverse : t.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

/// Body text: `@Name` of mentioned members highlighted (the caller's own
/// mention with a background) and links (http/https, www, e-mail) tappable.
/// Segments and gesture recognizers are built once per body.
class _MessageText extends StatefulWidget {
  const _MessageText({
    required this.message,
    required this.names,
    required this.selfId,
    this.onLinkTap,
  });
  final ChatMessage message;
  final Map<String, String> names;
  final String selfId;
  final void Function(Uri uri)? onLinkTap;

  @override
  State<_MessageText> createState() => _MessageTextState();
}

typedef _Piece = ({String text, String? mentionId, Uri? uri});

class _MessageTextState extends State<_MessageText> {
  List<_Piece> _pieces = const [];
  bool _hasMention = false;
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void didUpdateWidget(covariant _MessageText old) {
    super.didUpdateWidget(old);
    if (old.message.body != widget.message.body ||
        old.message.mentions != widget.message.mentions ||
        old.names != widget.names) {
      _build();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _build() {
    _disposeRecognizers();
    final m = widget.message;
    final segments = m.mentions.isEmpty
        ? [MentionSegment(m.body)]
        : ChatMentions.segments(m.body, m.mentions, widget.names);
    _hasMention = segments.any((s) => s.isMention);
    final pieces = <_Piece>[];
    for (final s in segments) {
      if (s.isMention) {
        pieces.add((text: s.text, mentionId: s.userId, uri: null));
        continue;
      }
      for (final l in ChatText.links(s.text)) {
        pieces.add((text: l.text, mentionId: null, uri: l.uri));
      }
    }
    _pieces = pieces;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: t.textPrimary,
      fontSize: t.display.fontSizeBase,
      height: 1.35,
    );
    final m = widget.message;
    final hasLink = _pieces.any((p) => p.uri != null);
    if (!_hasMention && !hasLink) return Text(m.body, style: style);
    if (_recognizers.isEmpty && hasLink) {
      for (final p in _pieces) {
        if (p.uri == null) continue;
        _recognizers.add(
          TapGestureRecognizer()..onTap = () => widget.onLinkTap?.call(p.uri!),
        );
      }
    }
    var link = 0;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final p in _pieces)
            if (p.mentionId != null)
              TextSpan(
                text: p.text,
                style: TextStyle(
                  color: t.primary,
                  fontWeight: p.mentionId == widget.selfId
                      ? FontWeight.w800
                      : FontWeight.w600,
                  backgroundColor: p.mentionId == widget.selfId
                      ? t.selection
                      : null,
                ),
              )
            else if (p.uri != null)
              TextSpan(
                text: p.text,
                recognizer: _recognizers[link++],
                style: TextStyle(
                  color: t.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: t.primary,
                ),
              )
            else
              TextSpan(text: p.text),
        ],
      ),
      key: ValueKey(
        _hasMention ? 'mention_text_${m.id}' : 'link_text_${m.id}',
      ),
    );
  }
}

/// Compact card of a server-side link preview: site, title, description and
/// the proxied picture (fetched per the media auto-download setting). A tap
/// opens the link.
class _LinkPreviewCard extends ConsumerStatefulWidget {
  const _LinkPreviewCard({
    super.key,
    required this.message,
    required this.isOwn,
    required this.mediaAuto,
    this.onTap,
  });
  final ChatMessage message;
  final bool isOwn;
  final bool mediaAuto;
  final void Function(Uri uri)? onTap;

  @override
  ConsumerState<_LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends ConsumerState<_LinkPreviewCard> {
  File? _image;
  bool _requested = false;

  ChatLinkPreview get _p => widget.message.linkPreview!;

  @override
  void initState() {
    super.initState();
    if (_p.hasImage) unawaited(_loadCached());
  }

  Future<void> _loadCached() async {
    final f = await ref
        .read(chatRepositoryProvider)
        .cachedLinkPreviewImage(widget.message);
    if (f != null && mounted && _image == null) setState(() => _image = f);
  }

  Future<void> _download() async {
    _requested = true;
    try {
      final f = await ref
          .read(chatRepositoryProvider)
          .linkPreviewImageFile(widget.message);
      if (mounted) setState(() => _image = f);
    } on AppException catch (e) {
      DiagnosticLog.warn('chat', 'link preview image failed', error: e);
    } on FileSystemException catch (e) {
      DiagnosticLog.warn('chat', 'link preview image write failed', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final p = _p;
    if (p.hasImage && widget.mediaAuto && _image == null && !_requested) {
      _requested = true;
      Future.microtask(_download);
    }
    final uri = p.uri;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, c) {
        final width = math.min(c.maxWidth, 300.0);
        final inner = math.max(width - 3 - Space.sm * 2, 40.0);
        final ratio = (p.imageWidth ?? 0) > 0 && (p.imageHeight ?? 0) > 0
            ? (p.imageWidth! / p.imageHeight!).clamp(1.0, 2.2)
            : 1.9;
        return Padding(
          padding: const EdgeInsets.only(top: Space.xs, bottom: 2),
          child: Semantics(
            container: true,
            link: uri != null,
            label: [
              p.siteName,
              p.title,
              p.description,
            ].where((s) => s.isNotEmpty).join(', '),
            child: Material(
            color: widget.isOwn
                ? t.surface.withValues(alpha: 0.55)
                : t.surfaceSubtle,
            borderRadius: BorderRadius.circular(t.radiusSm),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: uri == null || widget.onTap == null
                  ? null
                  : () => widget.onTap!(uri),
              // Texts are in the label; the picture is decorative.
              child: ExcludeSemantics(
              child: Container(
                width: width,
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: t.primary, width: 3)),
                ),
                padding: const EdgeInsets.fromLTRB(
                  Space.sm,
                  Space.xs,
                  Space.sm,
                  Space.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (p.siteName.isNotEmpty)
                      Text(
                        p.siteName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: t.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (p.title.isNotEmpty)
                      Text(
                        p.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: t.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (p.description.isNotEmpty)
                      Text(
                        p.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: t.textSecondary,
                        ),
                      ),
                    if (_image != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.xs),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(t.radiusXs),
                          child: Image.file(
                            _image!,
                            key: ValueKey('link_preview_image_${widget.message.id}'),
                            width: inner,
                            height: inner / ratio,
                            cacheWidth: (inner * dpr).round(),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ),
            ),
          ),
          ),
        );
      },
    );
  }
}

class _ForwardHeader extends StatelessWidget {
  const _ForwardHeader({required this.message, required this.names});
  final ChatMessage message;
  final Map<String, String> names;

  /// «Переслано от …» (also used in the message row's semantics label).
  static String label(
    AppLocalizations l10n,
    ChatMessage message,
    Map<String, String> names,
  ) {
    final from = message.forwardedFrom;
    final name = from == null
        ? ''
        : (from.displayName.isNotEmpty
              ? from.displayName
              : (names[from.senderId] ?? ''));
    return name.isEmpty ? l10n.chatForwarded : l10n.chatForwardedFrom(name);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Announced by the message row label.
    return ExcludeSemantics(
      child: Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.forward, size: 13, color: t.primary),
          const SizedBox(width: Space.xs),
          Flexible(
            child: Text(
              label(context.l10n, message, names),
              key: ValueKey('forwarded_${message.id}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: t.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Colleague card of a contact message: name, e-mail, «Написать» (open or
/// create the direct chat) and «Позвонить» (only when calls are enabled).
class _ContactCard extends ConsumerStatefulWidget {
  const _ContactCard({required this.message, required this.selfId});
  final ChatMessage message;
  final String selfId;

  @override
  ConsumerState<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends ConsumerState<_ContactCard> {
  bool _busy = false;

  Future<void> _write(String userId) async {
    if (_busy) return;
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final conv = await ref.read(chatRepositoryProvider).createDirect(userId);
      unawaited(router.push(Routes.chatConversationPath(conv.id)));
    } on AppException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ChatFormat.error(l10n, e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _call(String userId) async {
    if (!ref.read(callsEnabledProvider)) return;
    final router = GoRouter.of(context);
    final future = ref
        .read(callControllerProvider.notifier)
        .startCall(calleeIds: [userId], video: false);
    unawaited(router.push(Routes.call));
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final m = widget.message;
    final contact = m.contact;
    final userId = contact?.userId ?? ChatContact.userIdFromBody(m.body);
    final label = contact?.label ?? '';
    final actionable =
        userId != null &&
        userId.isNotEmpty &&
        userId != widget.selfId &&
        m.seq > 0;
    final canCall = actionable && ref.watch(callsEnabledProvider);
    return Container(
      key: ValueKey('contact_card_${m.id}'),
      margin: const EdgeInsets.only(bottom: Space.xs, top: 2),
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: t.surfaceSubtle,
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(color: t.border, width: t.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: InitialsAvatar(
                  label: label.isEmpty ? l10n.chatAttachContact : label,
                  colorKey: userId,
                ),
              ),
              const SizedBox(width: Space.sm),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.isEmpty ? l10n.chatAttachContact : label,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((contact?.email ?? '').isNotEmpty)
                      Text(
                        contact!.email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: t.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (actionable)
            Wrap(
              spacing: Space.xs,
              children: [
                TextButton.icon(
                  key: ValueKey('contact_write_$userId'),
                  onPressed: _busy ? null : () => _write(userId),
                  icon: const Icon(LucideIcons.messageCircle, size: 18),
                  label: Text(l10n.chatContactWrite),
                ),
                if (canCall)
                  TextButton.icon(
                    key: ValueKey('contact_call_$userId'),
                    onPressed: () => _call(userId),
                    icon: const Icon(LucideIcons.phone, size: 18),
                    label: Text(l10n.chatContactCall),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.message, this.color});
  final ChatMessage message;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final muted = color ?? t.textTertiary;
    if (message.pending) {
      return Icon(
        LucideIcons.clock,
        size: 13,
        color: muted,
        semanticLabel: l10n.chatPending,
      );
    }
    if (message.failed) {
      return Icon(
        LucideIcons.circleAlert,
        size: 13,
        color: t.danger,
        semanticLabel: l10n.chatFailed,
      );
    }
    return switch (message.status) {
      'read' => Icon(
        LucideIcons.checkCheck,
        size: 15,
        color: color ?? t.primary,
        semanticLabel: l10n.chatStatusRead,
      ),
      'delivered' => Icon(
        LucideIcons.checkCheck,
        size: 15,
        color: muted,
        semanticLabel: l10n.chatStatusDelivered,
      ),
      _ => Icon(
        LucideIcons.check,
        size: 15,
        color: muted,
        semanticLabel: l10n.chatStatusSent,
      ),
    };
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({
    required this.preview,
    required this.names,
    required this.isOwn,
    this.onTap,
  });
  final ChatReplyPreview preview;
  final Map<String, String> names;
  final bool isOwn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final accent = t.avatarTextColorFor(preview.senderId);
    final text = preview.deleted
        ? l10n.chatDeleted
        : switch (preview.type) {
            'contact' => l10n.chatAttachContact,
            'image' => preview.body.isEmpty ? l10n.chatAttachmentImage : preview.body,
            'video' => preview.body.isEmpty ? l10n.chatAttachmentVideo : preview.body,
            'voice' => l10n.chatAttachmentVoice,
            'audio' => l10n.chatAttachmentAudio,
            'file' => preview.body.isEmpty ? l10n.chatAttachmentFile : preview.body,
            _ => preview.body.isEmpty ? preview.type : preview.body,
          };
    final name = names[preview.senderId] ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs, top: 2),
      child: Semantics(
        container: true,
        button: onTap != null,
        label: name.isEmpty ? text : '$name, $text',
        child: Material(
        color: isOwn ? t.surface.withValues(alpha: 0.55) : t.surfaceSubtle,
        borderRadius: BorderRadius.circular(t.radiusSm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('reply_preview_${preview.id}'),
          onTap: onTap,
          child: ExcludeSemantics(
          child: Container(
            // 48 dp touch target even for a one-line quote.
            constraints: const BoxConstraints(
              minWidth: kMinInteractiveDimension,
              minHeight: kMinInteractiveDimension,
            ),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: accent, width: 3)),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: Space.sm,
              vertical: Space.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: t.textSecondary,
                  ),
                ),
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

/// Attachment rendering: image and video previews (thumbnails auto-loaded
/// per the auto-download setting, cached on disk), voice player, generic
/// file tile. Photos open in the in-app viewer; originals of other files
/// are fetched on tap and opened by the system.
class _AttachmentView extends ConsumerStatefulWidget {
  const _AttachmentView({
    super.key,
    required this.attachment,
    required this.message,
    required this.mediaAuto,
    this.onOpenMedia,
    this.bare = false,
  });
  final ChatAttachment attachment;
  final ChatMessage message;
  final bool mediaAuto;
  final void Function(ChatAttachment attachment)? onOpenMedia;

  /// Photo without text: the preview fills the bubble.
  final bool bare;

  @override
  ConsumerState<_AttachmentView> createState() => _AttachmentViewState();
}

class _AttachmentViewState extends ConsumerState<_AttachmentView> {
  File? _thumb;
  bool _busy = false;
  bool _thumbLoading = false;
  bool _thumbRequested = false;

  ChatAttachment get _a => widget.attachment;

  bool get _hasPreview =>
      (_a.kind == 'image' || _a.kind == 'video') &&
      _a.hasThumbnail &&
      !_a.id.startsWith('local:');

  @override
  void initState() {
    super.initState();
    if (_hasPreview) unawaited(_loadCachedThumb());
  }

  Future<void> _loadCachedThumb() async {
    final f = await ref
        .read(chatRepositoryProvider)
        .cachedAttachmentFile(_a, thumbnail: true);
    if (f != null && mounted && _thumb == null) setState(() => _thumb = f);
  }

  Future<void> _loadThumb() async {
    if (_thumbLoading) return;
    _thumbRequested = true;
    setState(() => _thumbLoading = true);
    try {
      final f = await ref
          .read(chatRepositoryProvider)
          .attachmentFile(_a, thumbnail: true);
      if (mounted) setState(() => _thumb = f);
    } on AppException catch (e) {
      DiagnosticLog.warn('chat', 'thumbnail failed', error: e);
    } finally {
      if (mounted) setState(() => _thumbLoading = false);
    }
  }

  Future<void> _open() async {
    if (_busy) return;
    // Photos (with a preview) and videos open in the in-app viewer.
    if (widget.onOpenMedia != null &&
        ((_a.kind == 'image' && _hasPreview) || _a.kind == 'video')) {
      widget.onOpenMedia!(_a);
      return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final opener = ref.read(chatFileOpenerProvider);
    try {
      final f = await ref.read(chatRepositoryProvider).attachmentFile(_a);
      final opened = await opener(f.path, _a.mimeType);
      if (!opened) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.attachmentNoApp)));
      }
    } on AppException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ChatFormat.error(l10n, e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    final l10n = context.l10n;
    final t = context.tokens;
    final local = widget.message.localFilePath;
    if (a.id.startsWith('local:') && isDesktop && local != null && isChatPhoto(local)) {
      // Desktop: the photo on screen at once, in its own proportions, while
      // it uploads.
      return Padding(
        padding: EdgeInsets.only(bottom: widget.bare ? 0 : Space.xs),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(math.max(t.radiusLg.clamp(10, 20) - 3, 4)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.file(
                File(local),
                key: ValueKey('local_photo_${a.id}'),
                width: 240,
                fit: BoxFit.contain,
                cacheWidth: (240 * MediaQuery.devicePixelRatioOf(context)).round(),
                excludeFromSemantics: true,
              ),
              const CircularProgressIndicator(strokeWidth: 2),
            ],
          ),
        ),
      );
    }
    if (a.id.startsWith('local:')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: Space.sm),
            Flexible(
              child: Text(
                a.kind == 'voice' ? l10n.chatAttachmentVoice : a.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.textTertiary),
              ),
            ),
          ],
        ),
      );
    }
    if (_hasPreview) {
      if (widget.mediaAuto && _thumb == null && !_thumbRequested) {
        _thumbRequested = true;
        Future.microtask(_loadThumb);
      }
      return _preview(context);
    }
    switch (a.kind) {
      case 'voice':
      case 'audio':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VoicePlayer(attachment: a, autoFetch: widget.mediaAuto),
            VoiceTranscriptView(message: widget.message),
          ],
        );
      default:
        // One node «имя файла, размер»; the kind circle is decorative.
        return Semantics(
          container: true,
          button: true,
          label: '${a.filename}, ${FormatUtils.bytes(a.size)}',
          child: InkWell(
          key: ValueKey('file_tile_${a.id}'),
          borderRadius: BorderRadius.circular(t.radiusSm),
          onTap: _open,
          child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.primary,
                    shape: BoxShape.circle,
                  ),
                  child: _busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.textInverse,
                          ),
                        )
                      : Icon(
                          a.kind == 'video'
                              ? LucideIcons.video
                              : a.kind == 'image'
                              ? LucideIcons.image
                              : LucideIcons.fileText,
                          size: 20,
                          color: t.textInverse,
                        ),
                ),
                const SizedBox(width: Space.sm),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        FormatUtils.bytes(a.size),
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: t.textTertiary),
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

  /// Thumbnail tile for images and videos. Videos get a play overlay and a
  /// duration badge; without a loaded thumbnail a placeholder offers a manual
  /// preview download.
  Widget _preview(BuildContext context) {
    final a = _a;
    final m = widget.message;
    final l10n = context.l10n;
    final t = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    const width = 240.0;
    final ratio = (a.width ?? 0) > 0 && (a.height ?? 0) > 0
        ? (a.width! / a.height!).clamp(0.6, 1.8)
        : (a.kind == 'video' ? 16 / 9 : 1.4);
    final height = width / ratio;
    final isVideo = a.kind == 'video';
    final radius = BorderRadius.circular(
      math.max(t.radiusLg.clamp(10, 20) - 3, 4),
    );

    final placeholder = Container(
      width: width,
      height: height,
      color: t.surfaceMuted,
      alignment: Alignment.center,
      child: _thumbLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              key: ValueKey('thumb_load_${a.id}'),
              tooltip: l10n.chatMediaLoadPreview,
              onPressed: _loadThumb,
              icon: Icon(
                isVideo ? LucideIcons.video : LucideIcons.image,
                color: t.textTertiary,
              ),
            ),
    );

    return Semantics(
      container: true,
      button: true,
      label: isVideo ? l10n.chatAttachmentVideo : l10n.chatAttachmentImage,
      child: GestureDetector(
      key: ValueKey('${isVideo ? 'video' : 'image'}_tile_${a.id}'),
      onTap: _open,
      child: Padding(
        padding: EdgeInsets.only(bottom: widget.bare ? 0 : Space.xs),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_thumb != null)
                Image.file(
                  _thumb!,
                  key: ValueKey('${isVideo ? 'video' : 'image'}_thumb_${a.id}'),
                  width: width,
                  height: height,
                  cacheWidth: (width * dpr).round(),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => placeholder,
                )
              else
                placeholder,
              if (isVideo && (_thumb != null || _busy))
                Semantics(
                  button: true,
                  label: l10n.chatVideoOpen,
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: scheme.inverseSurface.withValues(
                      alpha: 0.6,
                    ),
                    child: _busy
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onInverseSurface,
                            ),
                          )
                        : Icon(
                            LucideIcons.play,
                            size: 28,
                            color: scheme.onInverseSurface,
                          ),
                  ),
                )
              else if (_busy)
                const CircularProgressIndicator(strokeWidth: 2),
              if (isVideo && (a.durationMs ?? 0) > 0)
                Positioned(
                  left: Space.sm,
                  top: Space.sm,
                  child: Container(
                    key: ValueKey('video_duration_${a.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.inverseSurface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(
                        XatBoxTokens.radiusPill,
                      ),
                    ),
                    child: Text(
                      ChatFormat.duration(a.durationMs),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onInverseSurface,
                      ),
                    ),
                  ),
                ),
              if (widget.bare &&
                  identical(a, m.attachments.last) &&
                  m.body.isEmpty)
                Positioned(
                  right: Space.xs + 2,
                  bottom: Space.xs + 2,
                  child: Builder(
                    builder: (context) => _Meta(
                      message: m,
                      isOwn: m.senderId ==
                          ref.read(chatRepositoryProvider).selfId,
                      pill: true,
                    ),
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

/// Voice message playback (ТЗ п.24.8) on the shared [ChatAudioController]:
/// play/pause, waveform-style progress with seeking, 1× / 1.5× / 2× speed.
/// The file is pre-fetched when auto-download allows it, otherwise on first
/// play.
class VoicePlayer extends ConsumerStatefulWidget {
  const VoicePlayer({
    super.key,
    required this.attachment,
    this.localPath,
    this.autoFetch = false,
  });
  final ChatAttachment attachment;
  final String? localPath;
  final bool autoFetch;

  @override
  ConsumerState<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends ConsumerState<VoicePlayer> {
  bool _loading = false;
  bool _prefetched = false;
  late final ChatAudioController _audio = ref.read(chatAudioProvider);

  String get _id => widget.localPath != null
      ? 'file:${widget.localPath}'
      : widget.attachment.id;

  bool get _remote =>
      widget.localPath == null &&
      widget.attachment.id != 'preview' &&
      !widget.attachment.id.startsWith('local:');

  @override
  void initState() {
    super.initState();
    _maybePrefetch();
  }

  @override
  void didUpdateWidget(covariant VoicePlayer old) {
    super.didUpdateWidget(old);
    _maybePrefetch();
  }

  @override
  void dispose() {
    if (widget.localPath != null) unawaited(_audio.release(_id));
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _audio; // bind the controller while the element is active
  }

  void _maybePrefetch() {
    if (!_remote || _prefetched || !widget.autoFetch) return;
    _prefetched = true;
    final repo = ref.read(chatRepositoryProvider);
    final attachment = widget.attachment;
    Future.microtask(() async {
      if (!mounted) return;
      try {
        await repo.attachmentFile(attachment);
      } on AppException catch (e) {
        DiagnosticLog.warn('chat', 'voice prefetch failed', error: e);
      }
    });
  }

  Future<void> _toggle() async {
    final audio = _audio;
    if (audio.current.value == _id && audio.player.playing) {
      await audio.pause();
      return;
    }
    setState(() => _loading = true);
    try {
      final path =
          widget.localPath ??
          (await ref
                  .read(chatRepositoryProvider)
                  .attachmentFile(widget.attachment))
              .path;
      await audio.play(_id, path);
    } on Object catch (e) {
      DiagnosticLog.warn('chat', 'voice load failed', error: e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = _audio;
    final total = Duration(milliseconds: widget.attachment.durationMs ?? 0);
    return ValueListenableBuilder<String?>(
      valueListenable: audio.current,
      builder: (context, current, _) {
        if (current != _id || !audio.hasPlayer) {
          return _layout(
            context,
            playing: false,
            progress: 0,
            position: Duration.zero,
            total: total,
            active: false,
          );
        }
        final player = audio.player;
        return StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, stateSnap) {
            final playing =
                stateSnap.data?.playing == true &&
                stateSnap.data?.processingState != ProcessingState.completed;
            return StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, posSnap) {
                final dur = player.duration ?? total;
                final pos = posSnap.data ?? Duration.zero;
                final value = dur.inMilliseconds == 0
                    ? 0.0
                    : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
                return _layout(
                  context,
                  playing: playing,
                  progress: value,
                  position: pos,
                  total: dur,
                  active: true,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _layout(
    BuildContext context, {
    required bool playing,
    required double progress,
    required Duration position,
    required Duration total,
    required bool active,
  }) {
    final t = context.tokens;
    final l10n = context.l10n;
    final audio = _audio;
    final label = active && position > Duration.zero
        ? ChatFormat.duration(position.inMilliseconds)
        : ChatFormat.duration(total.inMilliseconds);
    final seekable = active && total > Duration.zero;
    const step = Duration(seconds: 5);
    Duration clamp(Duration d) =>
        d < Duration.zero ? Duration.zero : (d > total ? total : d);
    // Fixed 236 dp width. Touch targets are 48 dp: the play circle stays
    // 42 dp inside a 48 dp box, and the speed pill sits in its own 48 dp
    // slot at the end of the row (reserved even before playback so the
    // waveform does not jump).
    return SizedBox(
      width: 236,
      child: Row(
        children: [
          Semantics(
            container: true,
            button: true,
            enabled: !_loading,
            label: playing ? l10n.chatVideoPause : l10n.chatVideoPlay,
            value: l10n.a11yVoiceMessage(
              ChatFormat.duration(total.inMilliseconds),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: ValueKey('voice_play_${widget.attachment.id}'),
                customBorder: const CircleBorder(),
                onTap: _loading ? null : _toggle,
                child: SizedBox.square(
                  dimension: kMinInteractiveDimension,
                  child: Center(
                    child: Ink(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: t.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: _loading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: t.textInverse,
                                ),
                              )
                            : Icon(
                                playing ? LucideIcons.pause : LucideIcons.play,
                                size: 20,
                                color: t.textInverse,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final wave = GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTapDown: !seekable
                          ? null
                          : (d) => audio.seek(
                              _id,
                              total * (d.localPosition.dx / c.maxWidth).clamp(0.0, 1.0),
                            ),
                      child: CustomPaint(
                        size: Size(c.maxWidth, 26),
                        painter: WaveformPainter(
                          seed: widget.attachment.id,
                          progress: progress,
                          played: t.primary,
                          idle: t.textTertiary.withValues(alpha: 0.45),
                        ),
                      ),
                    );
                    if (!seekable) return ExcludeSemantics(child: wave);
                    // Screen readers seek in 5 s steps (swipe up / down).
                    return Semantics(
                      container: true,
                      slider: true,
                      label: l10n.a11yVoiceSeek,
                      value: ChatFormat.duration(position.inMilliseconds),
                      increasedValue: ChatFormat.duration(
                        clamp(position + step).inMilliseconds,
                      ),
                      decreasedValue: ChatFormat.duration(
                        clamp(position - step).inMilliseconds,
                      ),
                      onIncrease: () => audio.seek(_id, clamp(position + step)),
                      onDecrease: () => audio.seek(_id, clamp(position - step)),
                      child: wave,
                    );
                  },
                ),
                const SizedBox(height: 2),
                // The duration is in the play button's value.
                ExcludeSemantics(
                  child: Text(
                    label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: t.textTertiary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox.square(
            dimension: kMinInteractiveDimension,
            child: !active
                ? null
                : ValueListenableBuilder<double>(
                    valueListenable: audio.speed,
                    builder: (context, speed, _) {
                      final speedText =
                          '${speed == speed.roundToDouble() ? speed.toInt() : speed}×';
                      return Semantics(
                        container: true,
                        button: true,
                        label: l10n.chatPlaybackSpeed,
                        value: speedText,
                        child: InkWell(
                          key: ValueKey('voice_speed_${widget.attachment.id}'),
                          customBorder: const CircleBorder(),
                          onTap: audio.cycleSpeed,
                          child: ExcludeSemantics(
                            child: Center(
                              child: Tooltip(
                                message: l10n.chatPlaybackSpeed,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: t.primarySoft,
                                    borderRadius: BorderRadius.circular(
                                      XatBoxTokens.radiusPill,
                                    ),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      speedText,
                                      maxLines: 1,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: t.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Bars with deterministic heights (from the attachment id) coloured up to
/// the playback [progress].
class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.seed,
    required this.progress,
    required this.played,
    required this.idle,
  });
  final String seed;
  final double progress;
  final Color played;
  final Color idle;

  static const _bar = 3.0;
  static const _gap = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final count = (size.width / (_bar + _gap)).floor();
    if (count <= 0) return;
    var h = seed.hashCode & 0x7fffffff;
    final playedPaint = Paint()..color = played;
    final idlePaint = Paint()..color = idle;
    for (var i = 0; i < count; i++) {
      h = (h * 1103515245 + 12345) & 0x7fffffff;
      final wave = 0.35 + 0.65 * (math.sin(i / 2.3) * 0.5 + 0.5);
      final noise = (h % 1000) / 1000;
      final ratio = (0.25 + 0.75 * (wave * 0.6 + noise * 0.4)).clamp(0.2, 1.0);
      final barH = size.height * ratio;
      final x = i * (_bar + _gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, (size.height - barH) / 2, _bar, barH),
        const Radius.circular(_bar / 2),
      );
      canvas.drawRRect(
        rect,
        (i + 0.5) / count <= progress ? playedPaint : idlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.progress != progress ||
      old.seed != seed ||
      old.played != played ||
      old.idle != idle;
}

/// The sender's name or picture, clickable when [onTap] is set (a hand
/// cursor on the desktop); [child] alone otherwise.
class _SenderTap extends StatelessWidget {
  const _SenderTap({required this.onTap, required this.child});
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
    );
  }
}
