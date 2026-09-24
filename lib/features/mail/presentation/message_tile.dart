import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/ds/folder_chip.dart';
import '../../../shared/widgets/ds/x_badge.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../data/mail_models.dart';

/// One action of the swipe tray (a full-height coloured button, 64px).
class SwipeAction {
  const SwipeAction({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

/// A row of the message list as the web draws it (`MessageRow` in
/// `app/mail/[folder]/page.tsx`): checkbox, 40px avatar, sender line
/// (participants of a conversation, thread count pill, smart-folder chip),
/// subject line (unread pip, subject — snippet, paperclip, reply badge) and
/// the date in the mono meta size. Unread rows carry the accent rail and the
/// primary-soft tint; the active row the selected surface. On a phone the
/// row stacks in two lines; from `sm` it is one line.
///
/// On touch a full swipe runs the configured [swipeLeft] / [swipeRight]
/// action (mail settings; past [swipeCommitFraction] of the row width). A
/// direction without an action keeps the web behaviour: left slides over the
/// row's own action tray (bookmark, read / unread, not-spam in Spam, delete),
/// 35% open threshold. No swiping while [swipeEnabled] is false (multi-select).
class MessageTile extends StatefulWidget {
  const MessageTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onToggleStar,
    this.folder = MailFolderType.inbox,
    this.selfAddress = '',
    this.active = false,
    this.checked = false,
    this.selectionMode = false,
    this.onCheck,
    this.onToggleRead,
    this.onDelete,
    this.onRestore,
    this.onLongPress,
    this.swipeLeft,
    this.swipeRight,
    this.swipeEnabled = true,
    this.onOpenInWindow,
    this.onMove,
  });

  final MailListItem item;
  final VoidCallback onTap;
  final VoidCallback onToggleStar;
  final String folder;
  final String selfAddress;
  final bool active;
  final bool checked;

  /// Show the checkbox column (some rows are selected, or a wide screen).
  final bool selectionMode;
  final ValueChanged<bool>? onCheck;
  final VoidCallback? onToggleRead;
  final VoidCallback? onDelete;

  /// "Not spam" (Spam folder only).
  final VoidCallback? onRestore;
  final VoidCallback? onLongPress;

  /// Full-swipe actions (null = none for that direction).
  final SwipeAction? swipeLeft;
  final SwipeAction? swipeRight;
  final bool swipeEnabled;

  /// Desktop context menu: «Открыть в отдельном окне».
  final VoidCallback? onOpenInWindow;

  /// Desktop context menu: «Переместить в…».
  final VoidCallback? onMove;

  static const swipeCommitFraction = 0.35;

  static final _rePrefix = RegExp(r'^(?:\s*re\s*:\s*)+', caseSensitive: false);
  static const trayButtonWidth = 64.0;

  /// "Асет, Вы +2": the reader appears as [you]; at most [max] names.
  static String participantsLabel(List<MailParticipant> participants, String selfAddress, String you, {int max = 3}) {
    final self = selfAddress.toLowerCase();
    final names = <String>{};
    for (final p in participants) {
      names.add(self.isNotEmpty && p.email.toLowerCase() == self ? you : (p.name.trim().isNotEmpty ? p.name.trim() : p.email.split('@').first));
    }
    final list = names.toList();
    return list.length > max ? '${list.take(max).join(', ')} +${list.length - max}' : list.join(', ');
  }

  @override
  State<MessageTile> createState() => _MessageTileState();
}

class _MessageTileState extends State<MessageTile> {
  double _offset = 0;
  double? _dragStart;
  bool _open = false;
  bool _swiped = false;

  /// Desktop: the pointer is over the row (its actions show on the right).
  bool _hover = false;

  /// Desktop: right click opens the row's actions as a context menu.
  Future<void> _contextMenu(TapUpDetails d, List<SwipeAction> actions) async {
    final l10n = context.l10n;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final at = overlay.globalToLocal(d.globalPosition);
    final picked = await showMenu<VoidCallback>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, overlay.size.width - at.dx, overlay.size.height - at.dy),
      items: [
        PopupMenuItem(value: widget.onTap, child: _menuRow(LucideIcons.mailOpen, l10n.mailOpen)),
        if (widget.onOpenInWindow != null)
          PopupMenuItem(value: widget.onOpenInWindow, child: _menuRow(LucideIcons.appWindow, l10n.desktopOpenInWindow)),
        if (widget.onLongPress != null)
          PopupMenuItem(value: widget.onLongPress, child: _menuRow(LucideIcons.squareCheck, l10n.mailSelectMessage)),
        const PopupMenuDivider(),
        for (final a in actions) PopupMenuItem(value: a.onTap, child: _menuRow(a.icon, a.label)),
        if (widget.onMove != null)
          PopupMenuItem(key: const Key('row_menu_move'), value: widget.onMove, child: _menuRow(LucideIcons.folder, l10n.mailMoveTo)),
      ],
    );
    picked?.call();
  }

  static Widget _menuRow(IconData icon, String label) => Row(
    children: [Icon(icon, size: 16), const SizedBox(width: Space.smd), Flexible(child: Text(label))],
  );

  /// Current drag: the tray, or a full swipe to one side.
  _SwipeMode _mode = _SwipeMode.none;
  double _rowWidth = 0;

  List<SwipeAction> _actions(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final m = widget.item;
    return [
      SwipeAction(
        icon: LucideIcons.bookmark,
        label: m.isStarred ? l10n.mailUnstar : l10n.mailStar,
        color: t.warning,
        onTap: widget.onToggleStar,
      ),
      if (widget.onToggleRead != null)
        SwipeAction(
          icon: m.isRead ? LucideIcons.mail : LucideIcons.mailOpen,
          label: m.isRead ? l10n.mailMarkUnread : l10n.mailMarkRead,
          color: t.info,
          onTap: widget.onToggleRead!,
        ),
      if (widget.onRestore != null)
        SwipeAction(icon: LucideIcons.inbox, label: l10n.mailReportNotSpam, color: t.success, onTap: widget.onRestore!),
      if (widget.onDelete != null)
        SwipeAction(
          icon: LucideIcons.trash2,
          label: widget.folder == MailFolderType.trash ? l10n.mailDeleteForever : l10n.delete,
          color: t.danger,
          onTap: widget.onDelete!,
        ),
    ];
  }

  void _setOpen(bool open, double trayWidth) => setState(() {
    _open = open;
    _offset = open ? -trayWidth : 0;
  });

  /// One line needs ~600px (the web's `sm` grid); narrower rows — phones,
  /// and the list pane of the wide layout — stack in two lines.
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, c) {
        _rowWidth = c.maxWidth.isFinite ? c.maxWidth : 400;
        return _build(context, compact: c.maxWidth < 600);
      });

  SwipeAction? get _fullAction => switch (_mode) {
    _SwipeMode.left => widget.swipeLeft,
    _SwipeMode.right => widget.swipeRight,
    _ => null,
  };

  bool get _pastCommit => _offset.abs() >= _rowWidth * MessageTile.swipeCommitFraction;

  Widget _build(BuildContext context, {required bool compact}) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final m = widget.item;
    final unread = !m.isRead;
    final locale = Localizations.localeOf(context).toString();
    final actions = _actions(context);
    final trayWidth = actions.length * MessageTile.trayButtonWidth;

    final isReply = widget.folder == MailFolderType.sent && MessageTile._rePrefix.hasMatch(m.subject);
    final subject = isReply ? m.subject.replaceFirst(MessageTile._rePrefix, '').trim() : m.subject;
    final conversationCount = m.threadCount ?? 0;
    final participants = m.participants ?? const <MailParticipant>[];
    final senderLabel = conversationCount > 1 && participants.isNotEmpty
        ? MessageTile.participantsLabel(participants, widget.selfAddress, l10n.mailThreadYou)
        : m.senderLabel;

    final listSize = t.display.fontSizeList;
    final senderStyle = theme.textTheme.bodyMedium!.copyWith(
      fontSize: listSize,
      height: 20 / listSize,
      color: unread ? t.textPrimary : t.textSecondary,
      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
    );
    final subjectStyle = theme.textTheme.bodyMedium!.copyWith(
      fontSize: listSize,
      height: 20 / listSize,
      color: unread ? t.textPrimary : t.textPrimary.withValues(alpha: 0.82),
      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
    );
    final snippetStyle = subjectStyle.copyWith(color: t.textTertiary, fontWeight: FontWeight.w400);
    final dateStyle = theme.textTheme.labelSmall!.copyWith(
      fontFamily: 'JetBrains Mono',
      fontSize: t.display.fontSizeMeta,
      color: unread ? t.primary : t.textTertiary,
      fontWeight: unread ? FontWeight.w500 : FontWeight.w400,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final background = widget.active
        ? t.surfaceSelected
        : (unread ? t.primarySoft : t.surface);
    final rail = widget.active || unread ? t.primary : Colors.transparent;

    Widget senderLine = Row(
      children: [
        Flexible(child: Text(senderLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: senderStyle)),
        if (conversationCount > 1) ...[
          const SizedBox(width: Space.sm),
          CountPill(conversationCount, accent: false, background: t.surfaceSubtle, color: t.textSecondary),
        ],
        if (m.folderName != null) ...[
          const SizedBox(width: Space.sm),
          Flexible(child: FolderChip(name: m.folderName!, color: m.folderColor, maxWidth: 120)),
        ],
      ],
    );

    // Subject, then " — snippet" in the faint ink, one line, truncated at the
    // end (as the web row); the paperclip and reply badge sit after it.
    Widget subjectLine = Row(
      children: [
        if (unread) ...[const UnreadPip(), const SizedBox(width: Space.sm)],
        // The subject keeps its own width (up to half the line when the
        // snippet competes); the snippet takes what is left.
        Flexible(
          child: Text(subject.isEmpty ? l10n.mailNoSubject : subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: subjectStyle),
        ),
        if (m.snippet.isNotEmpty)
          Expanded(child: Text(' — ${m.snippet}', maxLines: 1, overflow: TextOverflow.ellipsis, style: snippetStyle))
        else
          const Spacer(),
        if (m.hasAttachments) ...[
          const SizedBox(width: 4),
          Icon(LucideIcons.paperclip, size: 12, color: t.textTertiary),
        ],
        if (isReply) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: l10n.mailReplyBadge,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: t.infoSoft,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: t.border, width: t.borderWidth),
              ),
              child: Icon(LucideIcons.reply, size: 10, color: t.info),
            ),
          ),
        ],
      ],
    );

    final date = Text(FormatUtils.listDate(m.date, locale), style: dateStyle, maxLines: 1);

    final checkbox = widget.selectionMode
        ? Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                key: Key('select_${m.id}'),
                value: widget.checked,
                onChanged: widget.onCheck == null ? null : (v) => widget.onCheck!(v ?? false),
                semanticLabel: l10n.mailSelectMessage,
              ),
            ),
          )
        : const SizedBox.shrink();

    final avatar = Padding(
      padding: const EdgeInsets.only(right: 10),
      child: UserAvatar(email: m.from, label: m.senderLabel, radius: InitialsAvatarSizes.lg, domainLogo: true),
    );

    final body = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Expanded(child: senderLine), const SizedBox(width: Space.sm), date]),
              const SizedBox(height: 2),
              subjectLine,
            ],
          )
        : Row(
            children: [
              Flexible(flex: 2, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: senderLine)),
              const SizedBox(width: 10),
              Flexible(flex: 5, fit: FlexFit.tight, child: subjectLine),
              const SizedBox(width: 10),
              Flexible(flex: 0, child: date),
            ],
          );

    final row = Material(
      color: background,
      child: InkWell(
        key: Key('message_${m.id}'),
        onTap: () {
          if (_swiped) {
            _swiped = false;
            return;
          }
          if (_open) {
            _setOpen(false, trayWidth);
            return;
          }
          widget.onTap();
        },
        onLongPress: widget.onLongPress,
        onSecondaryTapUp: isDesktop ? (d) => _contextMenu(d, actions) : null,
        hoverColor: t.surfaceHover,
        child: Container(
          constraints: BoxConstraints(minHeight: t.display.rowMinHeight),
          padding: EdgeInsets.fromLTRB(Space.smd, t.display.rowPaddingY, Space.smd, t.display.rowPaddingY),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: rail, width: 2),
              bottom: BorderSide(color: t.border, width: t.borderWidth),
            ),
          ),
          child: Row(
            crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [checkbox, avatar, Expanded(child: body)],
          ),
        ),
      ),
    );

    // Swipe: a full swipe commits the configured action; otherwise the row
    // tracks the finger over its tray and snaps open or shut on release.
    final full = _fullAction;
    final swipeBackground = full != null
        ? Positioned.fill(
            child: Container(
              key: Key('swipe_bg_${_mode.name}'),
              color: _pastCommit ? full.color : full.color.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              alignment: _mode == _SwipeMode.left ? Alignment.centerRight : Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(full.icon, size: 20, color: t.textInverse),
                  const SizedBox(width: Space.sm),
                  Flexible(
                    child: Text(
                      full.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(color: t.textInverse),
                    ),
                  ),
                ],
              ),
            ),
          )
        : Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: trayWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final a in actions)
                      SizedBox(
                        width: MessageTile.trayButtonWidth,
                        child: Material(
                          color: a.color,
                          child: InkWell(
                            onTap: () {
                              _setOpen(false, trayWidth);
                              a.onTap();
                            },
                            child: Tooltip(message: a.label, child: Icon(a.icon, size: 18, color: t.textInverse)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );

    final slidingRow = AnimatedContainer(
      duration: _dragStart == null ? const Duration(milliseconds: 180) : Duration.zero,
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(_offset, 0, 0),
      child: row,
    );

    if (isDesktop) {
      // A mouse has no swipe: the tray's actions appear over the row's end
      // on hover, and in the right-click menu.
      return MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Stack(
          children: [
            row,
            if (_hover)
              Positioned(
                right: Space.sm,
                top: 0,
                bottom: 0,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(t.radiusMd),
                      border: Border.all(color: t.border, width: t.borderWidth),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final a in actions)
                          IconButton(
                            key: Key('hover_${a.icon.codePoint}'),
                            tooltip: a.label,
                            visualDensity: VisualDensity.compact,
                            iconSize: 16,
                            icon: Icon(a.icon, color: a.color),
                            onPressed: a.onTap,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return ClipRect(
      child: Stack(
        children: [
          // Only the uncovered part is painted: a glass skin's see-through
          // row must not show the swipe colours through.
          if (_offset != 0 || _open)
            Positioned.fill(
              child: ClipRect(
                clipper: _RevealClipper(_offset),
                child: Stack(children: [swipeBackground]),
              ),
            ),
          if (!widget.swipeEnabled)
            slidingRow
          else
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (d) {
                _dragStart = d.localPosition.dx;
                _mode = _open ? _SwipeMode.tray : _SwipeMode.none;
              },
              onHorizontalDragUpdate: (d) {
                final start = _dragStart;
                if (start == null) return;
                final raw = d.localPosition.dx - start;
                _swiped = true;
                if (_mode == _SwipeMode.none && raw != 0) {
                  _mode = raw < 0
                      ? (widget.swipeLeft != null ? _SwipeMode.left : _SwipeMode.tray)
                      : (widget.swipeRight != null ? _SwipeMode.right : _SwipeMode.tray);
                }
                final wasPast = _pastCommit;
                setState(() {
                  switch (_mode) {
                    case _SwipeMode.left:
                      _offset = raw.clamp(-_rowWidth, 0.0);
                    case _SwipeMode.right:
                      _offset = raw.clamp(0.0, _rowWidth);
                    case _SwipeMode.tray || _SwipeMode.none:
                      final dx = raw + (_open ? -trayWidth : 0);
                      // Rubber-band past the tray, never to the right of rest.
                      if (dx > 0) {
                        _offset = dx * 0.15;
                      } else if (dx < -trayWidth) {
                        _offset = -trayWidth + (dx + trayWidth) * 0.25;
                      } else {
                        _offset = dx;
                      }
                  }
                });
                if (_fullAction != null && wasPast != _pastCommit) {
                  HapticFeedback.selectionClick();
                }
              },
              onHorizontalDragEnd: (_) {
                _dragStart = null;
                final action = _fullAction;
                if (action != null) {
                  final commit = _pastCommit;
                  _swiped = false;
                  setState(() {
                    _offset = 0;
                    _open = false;
                    _mode = _SwipeMode.none;
                  });
                  if (commit) action.onTap();
                  return;
                }
                _mode = _SwipeMode.none;
                final open = _open ? _offset < -trayWidth * 0.65 : _offset < -trayWidth * 0.35;
                _setOpen(open, trayWidth);
              },
              onHorizontalDragCancel: () {
                _dragStart = null;
                _mode = _SwipeMode.none;
                _setOpen(_open, trayWidth);
              },
              child: slidingRow,
            ),
        ],
      ),
    );
  }
}

/// The strip a swiped row has moved off: at the right for a left swipe
/// ([offset] < 0), at the left for a right one.
class _RevealClipper extends CustomClipper<Rect> {
  const _RevealClipper(this.offset);
  final double offset;

  @override
  Rect getClip(Size size) {
    final w = offset.abs().clamp(0.0, size.width);
    return offset < 0 ? Rect.fromLTWH(size.width - w, 0, w, size.height) : Rect.fromLTWH(0, 0, w, size.height);
  }

  @override
  bool shouldReclip(_RevealClipper old) => old.offset != offset;
}

enum _SwipeMode { none, tray, left, right }

/// Avatar radii of the web sizes (sm 28 / md 32 / lg 40).
abstract final class InitialsAvatarSizes {
  static const sm = 14.0;
  static const md = 16.0;
  static const lg = 20.0;
}
