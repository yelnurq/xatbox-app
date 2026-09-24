import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop_keys.dart';
import '../../../core/platform/desktop_layout.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/skin_backdrop.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/desktop_drop_target.dart';
import '../../../shared/widgets/ds/x_badge.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/state_view.dart';
import '../../calls/presentation/calls_providers.dart';
import '../../calls/presentation/calls_screen.dart' show startCallFromUi;
import '../../mail/presentation/compose_screen.dart' show ComposeArgs;
import '../data/chat_models.dart';
import '../data/chat_photo.dart';
import '../data/chat_translation.dart';
import 'broadcast/broadcast_providers.dart';
import 'channels/channel_widgets.dart';
import 'chat_avatar.dart';
import 'chat_composer.dart';
import 'chat_emoji_picker.dart';
import 'chat_formatters.dart' as fmt;
import 'chat_forward_sheet.dart';
import 'chat_media_viewer.dart';
import 'chat_providers.dart';
import 'chat_share.dart';
import 'chat_wallpaper.dart';
import 'group_info_screen.dart';
import 'message_bubble.dart';
import 'open_direct_chat.dart';
import 'messenger2_providers.dart';
import 'moderation/report_message_sheet.dart';
import 'poll/poll_create_sheet.dart';
import 'protected/chat_protection.dart';
import 'reminders/reminders_screen.dart';
import 'requests/request_widgets.dart';
import 'scheduled/scheduled_widgets.dart';
import 'status/chat_status_providers.dart';
import 'translation/translation_providers.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../mail/presentation/compose_window.dart';

/// Conversation screen (ТЗ п.24.7): virtualised list with cursor pagination
/// upwards, grouped bubbles on a skin wallpaper, unread separator, floating
/// day chip, scroll-to-bottom button, swipe to reply, jump to replied /
/// pinned / searched messages, multi-select (copy / forward / delete),
/// in-chat search, media viewer, drafts, typing and recording indicators.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    super.key,
    required this.conversationId,
    this.embedded = false,
  });
  final String conversationId;

  /// Right pane of the wide layout: no back button.
  final bool embedded;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _listKey = GlobalKey();
  ChatMessage? _replyTo;
  ChatMessage? _editing;
  int _lastMarkedSeq = 0;

  final _showFab = ValueNotifier<bool>(false);
  final _floatingDay = ValueNotifier<DateTime?>(null);
  Timer? _dayHide;
  bool _dayScheduled = false;

  /// Built rows by message key (for jumps and the floating day chip).
  final Map<String, _TrackedState> _tracked = {};
  String? _highlightKey;
  Timer? _highlightTimer;

  final Set<String> _selected = {};

  /// The first unread message when the chat was opened (separator).
  String? _unreadKey;
  bool _unreadCaptured = false;
  String? _pendingJump;

  bool _searching = false;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'chat_search');

  /// Desktop: the details panel (the web's ⓘ aside) beside the chat.
  bool _infoOpen = false;
  Timer? _searchDebounce;
  List<ChatMessage> _hits = const [];
  int _hitIndex = 0;
  bool _searchBusy = false;

  String _draftInitial = '';
  List<ChatPickedFile> _sharedFiles = const [];
  Timer? _draftSave;
  String? _draftPending;
  late final ChatDraftsNotifier _drafts = ref.read(chatDraftsProvider.notifier);

  // memoised per messages list / conversation
  List<ChatMessage>? _source;
  List<ChatMessage> _items = const [];
  Map<String, int> _indexByKey = const {};
  ChatConversation? _namesFor;
  Map<String, String> _names = const {};

  /// Member addresses by user id, for the sender photos in the bubbles.
  Map<String, String> _emails = const {};
  Map<String, String> _mentionNames = const {};

  ConversationNotifier get _notifier =>
      ref.read(conversationProvider(widget.conversationId).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _draftInitial = ref.read(chatDraftsProvider)[widget.conversationId] ?? '';
    // Content shared from another app: text into the input, files above it.
    // Read now, removed after the build (providers cannot change in initState).
    final shared = ref.read(chatSharePrefillProvider)[widget.conversationId];
    if (shared != null) {
      final prefill = ref.read(chatSharePrefillProvider.notifier);
      Future.microtask(() => prefill.take(widget.conversationId));
      _sharedFiles = shared.files;
      if (shared.text.trim().isNotEmpty) _draftInitial = shared.text;
    }
    if (_draftInitial.isEmpty) {
      unawaited(
        ref.read(chatRepositoryProvider).draft(widget.conversationId).then((d) {
          if (mounted && d.isNotEmpty) setState(() => _draftInitial = d);
        }),
      );
    }
    _pendingJump = ref
        .read(chatJumpRequestProvider.notifier)
        .take(widget.conversationId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    _showFab.dispose();
    _floatingDay.dispose();
    _dayHide?.cancel();
    _highlightTimer?.cancel();
    _expiryTimer?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    if (_draftSave?.isActive ?? false) {
      _draftSave!.cancel();
      unawaited(_drafts.save(widget.conversationId, _draftPending ?? ''));
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(chatRepositoryProvider).kick();
      _maybeMarkRead();
    }
  }

  // ---- memoisation ----------------------------------------------------------------

  static String keyOf(ChatMessage m) =>
      m.clientMessageId.isNotEmpty ? 'c:${m.clientMessageId}' : 'i:${m.id}';

  void _prepare(List<ChatMessage> messages) {
    if (identical(messages, _source)) return;
    _source = messages;
    _items = messages.reversed.toList(growable: false);
    _indexByKey = {for (var i = 0; i < _items.length; i++) keyOf(_items[i]): i};
  }

  void _prepareNames(ChatConversation? c) {
    if (identical(c, _namesFor) && _names.isNotEmpty) return;
    _namesFor = c;
    final names = <String, String>{};
    final emails = <String, String>{};
    if (c != null) {
      for (final m in c.members) {
        names[m.userId] = m.label;
        if (m.email.isNotEmpty) emails[m.userId] = m.email;
      }
      if (c.peer != null) {
        names[c.peer!.userId] = c.peer!.label;
        if (c.peer!.email.isNotEmpty) emails[c.peer!.userId] = c.peer!.email;
      }
    }
    _emails = emails;
    names[ref.read(chatRepositoryProvider).selfId] = context.l10n.chatYou;
    _names = names;
    // Real member labels (the caller included) for `@mention` matching.
    _mentionNames = {
      for (final m in c?.members ?? const <ChatMember>[]) m.userId: m.label,
    };
  }

  // ---- scrolling ------------------------------------------------------------------

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    // Reversed list: the top of history is at maxScrollExtent.
    if (pos.pixels >= pos.maxScrollExtent - 300) unawaited(_notifier.loadOlder());
    _showFab.value = pos.pixels > 400;
    if (pos.pixels < 120) _maybeMarkRead();
    _scheduleDayUpdate();
  }

  void _scheduleDayUpdate() {
    if (_dayScheduled) return;
    _dayScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dayScheduled = false;
      if (!mounted) return;
      final listBox = _listKey.currentContext?.findRenderObject() as RenderBox?;
      if (listBox == null || !listBox.attached) return;
      DateTime? day;
      var best = double.infinity;
      for (final t in _tracked.values) {
        final box = t.context.findRenderObject() as RenderBox?;
        if (box == null || !box.attached || !box.hasSize) continue;
        final top = box.localToGlobal(Offset.zero, ancestor: listBox).dy;
        final bottom = top + box.size.height;
        if (bottom <= Space.lg) continue; // scrolled past the chip
        if (top < best) {
          best = top;
          day = t.widget.at;
        }
      }
      if (day == null) return;
      _floatingDay.value = day;
      _dayHide?.cancel();
      _dayHide = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) _floatingDay.value = null;
      });
    });
  }

  void _maybeMarkRead() {
    if (_scroll.hasClients && _scroll.offset > 120) return;
    final selfId = ref.read(chatRepositoryProvider).selfId;
    final messages = ref
        .read(conversationProvider(widget.conversationId))
        .messages;
    ChatMessage? last;
    for (final m in messages.reversed) {
      if (m.seq > 0 && m.senderId != selfId) {
        last = m;
        break;
      }
    }
    if (last == null || last.seq == _lastMarkedSeq) return;
    _lastMarkedSeq = last.seq;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_notifier.markReadLatest());
    });
  }

  void _onMessages(ConversationState s) {
    if (s.messages.isEmpty) return;
    if (!_unreadCaptured && s.conversation != null && !s.loading) {
      _unreadCaptured = true;
      _captureUnread(s);
      final jump = _pendingJump;
      _pendingJump = null;
      if (jump != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_jumpTo(jump));
        });
      } else if (_unreadKey != null) {
        final key = _unreadKey!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_reveal(key, alignment: 0.85, animate: false));
        });
      }
    }
    _maybeMarkRead();
  }

  /// The first unread message from the others: the `unread`-th newest one.
  void _captureUnread(ConversationState s) {
    final conv = s.conversation!;
    if (conv.unread <= 0) return;
    final selfId = ref.read(chatRepositoryProvider).selfId;
    var count = 0;
    ChatMessage? anchor;
    for (final m in s.messages.reversed) {
      if (m.seq <= 0 || m.senderId == selfId || m.isServiceLike) continue;
      if (conv.settings.lastReadSeq > 0 && m.seq <= conv.settings.lastReadSeq) {
        break;
      }
      anchor = m;
      if (++count >= conv.unread) break;
    }
    if (anchor != null) _unreadKey = keyOf(anchor);
  }

  /// Scrolls the list so the message is visible. Rows are built lazily:
  /// jump towards the estimated offset until the row exists, then reveal it.
  Future<bool> _reveal(
    String key, {
    double alignment = 0.5,
    bool animate = true,
  }) async {
    for (var attempt = 0; attempt < 14; attempt++) {
      if (!mounted || !_scroll.hasClients) return false;
      final tracked = _tracked[key];
      if (tracked != null && tracked.mounted) {
        await Scrollable.ensureVisible(
          tracked.context,
          alignment: alignment,
          duration: animate ? const Duration(milliseconds: 260) : Duration.zero,
          curve: Curves.easeOutCubic,
        );
        return true;
      }
      final index = _indexByKey[key];
      if (index != null) {
        final pos = _scroll.position;
        final avg =
            (pos.maxScrollExtent + pos.viewportDimension) /
            math.max(_items.length, 1);
        _scroll.jumpTo(
          (index * avg - pos.viewportDimension * (1 - alignment)).clamp(
            0.0,
            pos.maxScrollExtent,
          ),
        );
      }
      await WidgetsBinding.instance.endOfFrame;
    }
    return false;
  }

  /// Loads history around the message when needed, scrolls to it and
  /// flashes it.
  Future<void> _jumpTo(String messageId) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    ChatMessage? target;
    try {
      target = await _notifier.locate(messageId);
    } on AppException {
      target = null;
    }
    if (!mounted) return;
    if (target == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.chatMessageNotFound)));
      return;
    }
    final key = keyOf(target);
    // Let the list rebuild with a freshly loaded page first.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _reveal(key);
    if (!mounted) return;
    setState(() => _highlightKey = key);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _highlightKey = null);
    });
  }

  Future<void> _scrollToBottom() async {
    if (!_scroll.hasClients) return;
    if (_scroll.offset > 3000) _scroll.jumpTo(600);
    await _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    _maybeMarkRead();
  }

  // ---- drafts ---------------------------------------------------------------------

  void _onDraftChanged(String text) {
    if (_editing != null) return;
    _draftPending = text;
    _draftSave?.cancel();
    _draftSave = Timer(const Duration(milliseconds: 400), () {
      unawaited(_drafts.save(widget.conversationId, text));
    });
  }

  void _clearDraft() {
    _draftSave?.cancel();
    _draftPending = null;
    _draftInitial = '';
    unawaited(_drafts.save(widget.conversationId, ''));
  }

  // ---- actions --------------------------------------------------------------------

  void _snackError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(fmt.ChatFormat.error(context.l10n, e))),
    );
  }

  Future<void> _react(ChatMessage m, String emoji) async {
    unawaited(ref.read(chatRecentEmojiProvider.notifier).use(emoji));
    try {
      await _notifier.react(m, emoji);
    } on AppException catch (e) {
      _snackError(e);
    }
  }

  /// Files and photos of a message that can go into an e-mail.
  static List<ChatAttachment> _mailableAttachments(ChatMessage m) => m
      .attachments
      .where((a) => a.kind != 'voice' && a.scanStatus != 'infected')
      .toList();

  /// «Отправить по почте»: downloads the files (chat media cache) and opens
  /// the mail composer with them attached.
  Future<void> _sendByMail(ChatMessage m) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(chatRepositoryProvider);
    final files = <({String path, String name})>[];
    messenger.showSnackBar(SnackBar(content: Text(l10n.mailUxDownloading)));
    try {
      for (final a in _mailableAttachments(m)) {
        final file = await repo.attachmentFile(a);
        files.add((path: file.path, name: a.filename.isEmpty ? file.uri.pathSegments.last : a.filename));
      }
    } on AppException catch (e) {
      messenger.hideCurrentSnackBar();
      _snackError(e);
      return;
    }
    messenger.hideCurrentSnackBar();
    if (!mounted) return;
    openCompose(ref, ComposeArgs.files(files));
  }

  Future<void> _messageActions(ChatMessage m, ChatConversation? conv, {Offset? at}) async {
    if (_selected.isNotEmpty) {
      _toggleSelect(m);
      return;
    }
    final l10n = context.l10n;
    final selfId = ref.read(chatRepositoryProvider).selfId;
    final isOwn = m.senderId == selfId;
    // «Заявки»: requests are neither replied to, edited, reported nor deleted.
    final requestsChat = conv?.isRequests == true;
    final canDelete = (isOwn || (conv?.isAdmin ?? false)) && !requestsChat;
    // Protected chat: no forward / copy / save (the server refuses forwards).
    final noForward = conv?.protection.noForward ?? false;
    final translationOn = ref.read(translationAvailableProvider);
    final quick = ref.read(chatRecentEmojiProvider.notifier).quick();
    final canMail = ref.read(hasPermissionProvider(Permissions.mailSend));
    if (at == null) unawaited(HapticFeedback.selectionClick());
    final action = at != null
        ? await _messageMenu(m, conv, at, quick: quick.take(3).toList(), canMail: canMail, translationOn: translationOn)
        : await showAppSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final t = ctx.tokens;
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m.seq > 0 && !requestsChat)
                  // Six emoji + «ещё» share the width evenly so each keeps a
                  // ≥48 dp target on a 360 dp phone at any text scale.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final e in quick)
                          Expanded(
                            child: Semantics(
                              button: true,
                              label: '${l10n.chatReact} $e',
                              excludeSemantics: true,
                              child: InkResponse(
                                key: ValueKey('quick_react_$e'),
                                radius: 24,
                                onTap: () => Navigator.pop(ctx, 'react:$e'),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        e,
                                        style: const TextStyle(fontSize: 26),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        IconButton.filledTonal(
                          key: const Key('react_more'),
                          tooltip: l10n.chatMoreReactions,
                          style: IconButton.styleFrom(
                            backgroundColor: t.surfaceMuted,
                            foregroundColor: t.textSecondary,
                          ),
                          onPressed: () => Navigator.pop(ctx, 'react_more'),
                          icon: const Icon(LucideIcons.plus),
                        ),
                      ],
                    ),
                  ),
                if (m.seq > 0 && !requestsChat) const Divider(height: Space.lg),
                if (m.seq > 0 && !requestsChat)
                  ListTile(
                    leading: const Icon(LucideIcons.reply),
                    title: Text(l10n.chatReply),
                    onTap: () => Navigator.pop(ctx, 'reply'),
                  ),
                if (m.seq > 0 && !noForward && !m.isPoll)
                  ListTile(
                    leading: const Icon(LucideIcons.forward),
                    title: Text(l10n.chatForward),
                    onTap: () => Navigator.pop(ctx, 'forward'),
                  ),
                if (m.seq > 0 && conv?.isSaved != true && !noForward)
                  ListTile(
                    key: const Key('message_save_to_saved'),
                    leading: const Icon(LucideIcons.bookmark),
                    title: Text(l10n.chatSaveToSaved),
                    onTap: () => Navigator.pop(ctx, 'save'),
                  ),
                if (m.seq > 0 && !m.isSystem)
                  ListTile(
                    key: const Key('message_remind'),
                    leading: const Icon(LucideIcons.alarmClock),
                    title: Text(l10n.remindAction),
                    onTap: () => Navigator.pop(ctx, 'remind'),
                  ),
                if (m.seq > 0 && canMail && !noForward && _mailableAttachments(m).isNotEmpty)
                  ListTile(
                    key: const Key('message_send_by_mail'),
                    leading: const Icon(LucideIcons.mail),
                    title: Text(l10n.mailUxSendByMail),
                    onTap: () => Navigator.pop(ctx, 'mail'),
                  ),
                if (translationOn && chatMessageTranslatable(m))
                  ListTile(
                    key: const Key('message_translate'),
                    leading: const Icon(LucideIcons.languages),
                    title: Text(l10n.translateAction),
                    onTap: () => Navigator.pop(ctx, 'translate'),
                  ),
                if (m.body.isNotEmpty && !m.isContact && !m.isSticker && !noForward)
                  ListTile(
                    leading: const Icon(LucideIcons.copy),
                    title: Text(l10n.chatCopy),
                    onTap: () => Navigator.pop(ctx, 'copy'),
                  ),
                if (isOwn && m.type == 'text' && m.seq > 0)
                  ListTile(
                    leading: const Icon(LucideIcons.pencil),
                    title: Text(l10n.chatEdit),
                    onTap: () => Navigator.pop(ctx, 'edit'),
                  ),
                if ((conv?.isGroup == true || conv?.isChannel == true) &&
                    conv?.isAdmin == true &&
                    m.seq > 0)
                  ListTile(
                    leading: Icon(
                      conv?.pinnedMessageId == m.id
                          ? LucideIcons.pinOff
                          : LucideIcons.pin,
                    ),
                    title: Text(
                      conv?.pinnedMessageId == m.id
                          ? l10n.chatUnpinMessage
                          : l10n.chatPinMessage,
                    ),
                    onTap: () => Navigator.pop(ctx, 'pin'),
                  ),
                if (m.seq > 0)
                  ListTile(
                    key: const Key('message_select'),
                    leading: const Icon(LucideIcons.squareCheck),
                    title: Text(l10n.chatSelect),
                    onTap: () => Navigator.pop(ctx, 'select'),
                  ),
                if (!isOwn && m.seq > 0 && conv?.isSaved != true && !requestsChat && !m.isDeleted)
                  ListTile(
                    key: const Key('message_report'),
                    leading: const Icon(LucideIcons.flag),
                    title: Text(l10n.chatReport),
                    onTap: () => Navigator.pop(ctx, 'report'),
                  ),
                if (isOwn && conv?.isGroup == true && m.seq > 0)
                  ListTile(
                    key: const Key('message_info'),
                    leading: const Icon(LucideIcons.info),
                    title: Text(l10n.chatMessageInfo),
                    onTap: () => Navigator.pop(ctx, 'info'),
                  ),
                if (m.seq > 0)
                  ListTile(
                    key: const Key('message_delete_for_me'),
                    leading: Icon(
                      conv?.isSaved == true
                          ? LucideIcons.trash2
                          : LucideIcons.eyeOff,
                      color: t.danger,
                    ),
                    title: Text(
                      conv?.isSaved == true
                          ? l10n.chatDelete
                          : l10n.chatDeleteForMe,
                      style: TextStyle(color: t.danger),
                    ),
                    onTap: () => Navigator.pop(ctx, 'delete_me'),
                  ),
                if (canDelete && m.seq > 0 && conv?.isSaved != true)
                  ListTile(
                    key: const Key('message_delete_for_all'),
                    leading: Icon(LucideIcons.trash2, color: t.danger),
                    title: Text(
                      l10n.chatDeleteForAll,
                      style: TextStyle(color: t.danger),
                    ),
                    onTap: () => Navigator.pop(ctx, 'delete'),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (action == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (action.startsWith('react:')) {
        await _react(m, action.substring(6));
        return;
      }
      switch (action) {
        case 'react_more':
          final emoji = await ChatEmojiPickerSheet.show(context);
          if (emoji != null) await _react(m, emoji);
        case 'reply':
          _startReply(m);
        case 'edit':
          setState(() {
            _editing = m;
            _replyTo = null;
          });
        case 'translate':
          try {
            await ref
                .read(chatTranslationsProvider.notifier)
                .request(m, translateTarget(ref, context, listen: false));
          } on AppException catch (e) {
            messenger.showSnackBar(
              SnackBar(content: Text(translateErrorText(l10n, e))),
            );
          }
        case 'copy':
          await Clipboard.setData(ClipboardData(text: m.body));
          messenger.showSnackBar(SnackBar(content: Text(l10n.chatCopied)));
        case 'delete':
          await _notifier.delete(m);
        case 'delete_me':
          await _notifier.hideForMe(m);
        case 'save':
          await ref.read(chatRepositoryProvider).saveToSaved([m]);
          messenger.showSnackBar(SnackBar(content: Text(l10n.chatSavedDone)));
        case 'forward':
          await _forward([m]);
        case 'mail':
          await _sendByMail(m);
        case 'remind':
          await remindMessageFlow(context, ref, m);
        case 'select':
          _toggleSelect(m);
        case 'info':
          if (mounted) await _showReceipts(m);
        case 'report':
          if (mounted) await ReportMessageSheet.show(context, m);
        case 'pin':
          final repo = ref.read(chatRepositoryProvider);
          if (conv?.pinnedMessageId == m.id) {
            await repo.patchChat(widget.conversationId, clearPinned: true);
          } else {
            await repo.patchChat(widget.conversationId, pinnedMessageId: m.id);
          }
      }
    } on AppException catch (e) {
      _snackError(e);
    }
  }

  /// Desktop: the message's actions as a menu at the pointer [at] (right
  /// click, «⋯» of the hover bar), same choices as the phone's sheet.
  Future<String?> _messageMenu(
    ChatMessage m,
    ChatConversation? conv,
    Offset at, {
    required List<String> quick,
    required bool canMail,
    required bool translationOn,
  }) {
    final l10n = context.l10n;
    final t = context.tokens;
    final isOwn = m.senderId == ref.read(chatRepositoryProvider).selfId;
    // «Заявки»: requests are neither replied to, edited nor deleted.
    final requests = conv?.isRequests == true;
    final canDelete = (isOwn || (conv?.isAdmin ?? false)) && !requests;
    final noForward = conv?.protection.noForward ?? false;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    PopupMenuItem<String> item(String value, IconData icon, String label, {Key? key, bool danger = false}) => PopupMenuItem(
      key: key,
      value: value,
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, size: 18, color: danger ? t.danger : null),
        title: Text(label, style: danger ? TextStyle(color: t.danger) : null),
      ),
    );
    final items = <PopupMenuEntry<String>>[
      if (m.seq > 0 && !requests) ...[
        _ReactionMenuRow(emoji: quick, moreLabel: l10n.chatMoreReactions, reactLabel: l10n.chatReact),
        const PopupMenuDivider(),
        item('reply', LucideIcons.reply, l10n.chatReply, key: const Key('message_menu_reply')),
      ],
      if (m.seq > 0 && !noForward && !m.isPoll) item('forward', LucideIcons.forward, l10n.chatForward),
      if (m.seq > 0 && conv?.isSaved != true && !noForward) item('save', LucideIcons.bookmark, l10n.chatSaveToSaved),
      if (m.seq > 0 && !m.isSystem) item('remind', LucideIcons.alarmClock, l10n.remindAction),
      if (m.seq > 0 && canMail && !noForward && _mailableAttachments(m).isNotEmpty)
        item('mail', LucideIcons.mail, l10n.mailUxSendByMail),
      if (translationOn && chatMessageTranslatable(m)) item('translate', LucideIcons.languages, l10n.translateAction),
      if (m.body.isNotEmpty && !m.isContact && !m.isSticker && !noForward)
        item('copy', LucideIcons.copy, l10n.chatCopy, key: const Key('message_menu_copy')),
      if (isOwn && m.type == 'text' && m.seq > 0)
        item('edit', LucideIcons.pencil, l10n.chatEdit, key: const Key('message_menu_edit')),
      if ((conv?.isGroup == true || conv?.isChannel == true) && conv?.isAdmin == true && m.seq > 0)
        item(
          'pin',
          conv?.pinnedMessageId == m.id ? LucideIcons.pinOff : LucideIcons.pin,
          conv?.pinnedMessageId == m.id ? l10n.chatUnpinMessage : l10n.chatPinMessage,
        ),
      if (m.seq > 0) item('select', LucideIcons.squareCheck, l10n.chatSelect),
      if (!isOwn && m.seq > 0 && conv?.isSaved != true && !requests && !m.isDeleted)
        item('report', LucideIcons.flag, l10n.chatReport),
      if (isOwn && conv?.isGroup == true && m.seq > 0) item('info', LucideIcons.info, l10n.chatMessageInfo),
      if (m.seq > 0) ...[
        const PopupMenuDivider(),
        item(
          'delete_me',
          conv?.isSaved == true ? LucideIcons.trash2 : LucideIcons.eyeOff,
          conv?.isSaved == true ? l10n.chatDelete : l10n.chatDeleteForMe,
          danger: true,
        ),
      ],
      if (canDelete && m.seq > 0 && conv?.isSaved != true)
        item('delete', LucideIcons.trash2, l10n.chatDeleteForAll, danger: true),
    ];
    // A message still being sent may have nothing to offer.
    if (items.isEmpty) return Future.value();
    return showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(at & const Size(1, 1), Offset.zero & overlay.size),
      items: items,
    );
  }

  // ---- desktop keys ---------------------------------------------------------------

  /// Esc: leaves the innermost state first — selection, search, reply or
  /// edit, the details panel — then closes the conversation pane.
  void _onEscape() {
    if (_selected.isNotEmpty) {
      setState(_selected.clear);
    } else if (_searching) {
      _closeSearch();
    } else if (_replyTo != null || _editing != null) {
      setState(() {
        _replyTo = null;
        _editing = null;
      });
    } else if (_infoOpen) {
      setState(() => _infoOpen = false);
    } else if (widget.embedded) {
      ref.read(chatSelectedConversationProvider.notifier).select(null);
    }
  }

  /// Ctrl/⌘+F: the in-chat search (focused again when already open).
  void _openSearch() {
    if (_selected.isNotEmpty) return;
    if (_searching) {
      _searchFocus.requestFocus();
    } else {
      setState(() => _searching = true);
    }
  }

  /// ↑ in the empty composer: the caller's last text message to edit.
  void _editLast() {
    final selfId = ref.read(chatRepositoryProvider).selfId;
    final messages = ref.read(conversationProvider(widget.conversationId)).messages;
    for (final m in messages.reversed) {
      if (m.senderId != selfId || m.seq <= 0 || m.isDeleted || m.type != 'text') continue;
      setState(() {
        _editing = m;
        _replyTo = null;
      });
      return;
    }
  }

  /// Desktop: the web's messenger keys around the conversation and the
  /// details panel on its right. Phones get [screen] unchanged.
  Widget _desktopShell(BuildContext context, ChatConversation? conv, Widget screen) {
    if (!ref.watch(desktopLayoutProvider)) return screen;
    final t = context.tokens;
    return DesktopKeyBindings(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _onEscape,
        commandShortcut(LogicalKeyboardKey.keyF): _openSearch,
      },
      // In the composer or the search field Esc still leaves (the bindings
      // above skip plain keys while typing).
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (DesktopKeyBindings.editingText) _onEscape();
          },
        },
        // One Row whether the panel is open or not: the conversation keeps
        // its state (composer text, scroll) when the panel toggles.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: screen),
            if (_infoOpen && conv != null) ...[
              SizedBox(
                key: const Key('chat_info_panel'),
                width: _infoPanelWidth,
                // Glass skins («Свой фон» above all): the panel frosts the
                // picture behind it and sits on the translucent surface, as
                // the chat list and the page cards do — otherwise its text
                // lies straight on the photo and cannot be read.
                // The dividing line is the panel's own left border: a
                // separate divider stood outside the frosted surface and
                // showed a raw strip of the picture beside it.
                child: GlassBlur(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.surface,
                      border: Border(left: BorderSide(color: t.divider, width: t.borderWidth)),
                    ),
                    child: GroupInfoScreen(
                      conversationId: widget.conversationId,
                      onClose: () => setState(() => _infoOpen = false),
                      onShowMessage: _jumpTo,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const _infoPanelWidth = 340.0;

  /// «Отправить позже» from the composer (text, shared files, reply).
  Future<bool> _scheduleText(
    String text,
    List<String> mentions,
    DateTime at,
  ) async {
    final ok = await scheduleMessageFlow(
      context,
      ref,
      conversationId: widget.conversationId,
      text: text,
      at: at,
      files: _sharedFiles,
      replyToId: _replyTo?.id,
      mentions: mentions,
    );
    if (ok && mounted) {
      setState(() {
        _sharedFiles = const [];
        _replyTo = null;
      });
      _clearDraft();
    }
    return ok;
  }

  /// «Отправить, когда появится в сети» (1:1 chats).
  Future<bool> _scheduleWhenOnline(String text, List<String> mentions) async {
    final ok = await scheduleMessageFlow(
      context,
      ref,
      conversationId: widget.conversationId,
      text: text,
      whenOnline: true,
      files: _sharedFiles,
      replyToId: _replyTo?.id,
      mentions: mentions,
    );
    if (ok && mounted) {
      setState(() {
        _sharedFiles = const [];
        _replyTo = null;
      });
      _clearDraft();
    }
    return ok;
  }

  void _startReply(ChatMessage m) => setState(() {
    _replyTo = m;
    _editing = null;
  });

  void _toggleSelect(ChatMessage m) {
    if (m.seq <= 0) return;
    setState(() {
      if (!_selected.remove(m.id)) _selected.add(m.id);
    });
  }

  List<ChatMessage> get _selectedMessages {
    final list = ref
        .read(conversationProvider(widget.conversationId))
        .messages
        .where((m) => _selected.contains(m.id))
        .toList();
    return list;
  }

  Future<void> _forward(List<ChatMessage> messages) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final targets = await ChatForwardSheet.show(context);
    if (targets == null || targets.isEmpty || !mounted) return;
    final repo = ref.read(chatRepositoryProvider);
    final ordered = [...messages]..sort((a, b) => a.seq.compareTo(b.seq));
    for (final target in targets) {
      for (final m in ordered) {
        await repo.sendText(target.id, '', forwardOfId: m.id);
      }
    }
    if (mounted) setState(_selected.clear);
    messenger.showSnackBar(SnackBar(content: Text(l10n.chatForwarded)));
  }

  Future<void> _copySelected() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final text = _selectedMessages
        .where((m) => m.body.isNotEmpty && !m.isContact && !m.isDeleted)
        .map((m) => m.body)
        .join('\n\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) setState(_selected.clear);
    messenger.showSnackBar(SnackBar(content: Text(l10n.chatCopied)));
  }

  Future<void> _deleteSelected(ChatConversation? conv) async {
    final l10n = context.l10n;
    final selfId = ref.read(chatRepositoryProvider).selfId;
    final list = _selectedMessages;
    final canForAll =
        conv?.isSaved != true &&
        list.every(
          (m) =>
              !m.isDeleted && (m.senderId == selfId || (conv?.isAdmin ?? false)),
        );
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.chatDeleteSelected(list.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('confirm_delete_for_me'),
            style: TextButton.styleFrom(foregroundColor: ctx.tokens.danger),
            onPressed: () => Navigator.pop(ctx, 'me'),
            child: Text(
              conv?.isSaved == true ? l10n.chatDelete : l10n.chatDeleteForMe,
            ),
          ),
          if (canForAll)
            FilledButton(
              key: const Key('confirm_delete_selected'),
              style: FilledButton.styleFrom(backgroundColor: ctx.tokens.danger),
              onPressed: () => Navigator.pop(ctx, 'all'),
              child: Text(l10n.chatDeleteForAll),
            ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    try {
      for (final m in list) {
        if (choice == 'all') {
          await _notifier.delete(m);
        } else {
          await _notifier.hideForMe(m);
        }
      }
    } on AppException catch (e) {
      _snackError(e);
    }
    if (mounted) setState(_selected.clear);
  }

  Future<void> _saveSelected() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(chatRepositoryProvider).saveToSaved(_selectedMessages);
      messenger.showSnackBar(SnackBar(content: Text(l10n.chatSavedDone)));
    } on AppException catch (e) {
      _snackError(e);
    }
    if (mounted) setState(_selected.clear);
  }

  Future<void> _showReceipts(ChatMessage m) => showAppSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _ReceiptsSheet(message: m, names: _names),
  );

  Future<void> _send(String text, List<String> mentions) async {
    try {
      if (_editing == null && _sharedFiles.isNotEmpty) {
        final files = _sharedFiles;
        setState(() => _sharedFiles = const []);
        for (final f in files) {
          await _notifier.sendFile(path: f.path, filename: f.name);
        }
        if (text.trim().isEmpty) {
          unawaited(_scrollToBottom());
          return;
        }
      }
      if (_editing != null) {
        await _notifier.edit(_editing!, text);
        setState(() => _editing = null);
      } else {
        await _notifier.sendText(
          text,
          replyToId: _replyTo?.id,
          mentions: mentions,
        );
        _clearDraft();
        setState(() {
          _replyTo = null;
          _unreadKey = null;
        });
        unawaited(_scrollToBottom());
      }
    } on AppException catch (e) {
      _snackError(e);
    }
  }

  Future<void> _sendSticker(ChatSticker sticker) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendSticker(widget.conversationId, sticker);
      unawaited(_scrollToBottom());
    } on AppException catch (e) {
      _snackError(e);
    }
  }

  Future<void> _sendContact(ChatUser user) async {
    try {
      await _notifier.sendContact(user);
    } on AppException catch (e) {
      _snackError(e);
    }
  }

  void _openMedia(ChatAttachment a) {
    final items = chatMediaItems(
      ref.read(conversationProvider(widget.conversationId)).messages,
    );
    final index = items.indexWhere((i) => i.attachment.id == a.id);
    if (index < 0) return;
    unawaited(
      ChatMediaViewer.open(context, items: items, index: index, names: _names),
    );
  }

  Future<void> _openLink(Uri uri) async {
    final ok = await ref.read(chatLinkOpenerProvider)(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.attachmentNoApp)));
    }
  }

  // ---- in-chat search -------------------------------------------------------------

  void _onSearch(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final query = q.trim();
      if (query.length < 2) {
        if (mounted) setState(() => _hits = const []);
        return;
      }
      setState(() => _searchBusy = true);
      try {
        final hits = await ref
            .read(chatRepositoryProvider)
            .search(query, conversationId: widget.conversationId);
        if (!mounted) return;
        setState(() {
          _hits = hits;
          _hitIndex = 0;
        });
        if (hits.isNotEmpty) await _jumpTo(hits.first.id);
      } on AppException catch (e) {
        _snackError(e);
      } finally {
        if (mounted) setState(() => _searchBusy = false);
      }
    });
  }

  void _stepHit(int delta) {
    if (_hits.isEmpty) return;
    final next = (_hitIndex + delta).clamp(0, _hits.length - 1);
    if (next == _hitIndex) return;
    setState(() => _hitIndex = next);
    unawaited(_jumpTo(_hits[next].id));
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _searching = false;
      _hits = const [];
    });
  }

  // ---- build ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final id = widget.conversationId;
    final conv = ref.watch(conversationProvider(id).select((s) => s.conversation));
    _prepareNames(conv);
    ref.listen<ConversationState>(conversationProvider(id), (prev, next) {
      if (!identical(prev?.messages, next.messages) ||
          prev?.loading != next.loading ||
          !identical(prev?.conversation, next.conversation)) {
        _onMessages(next);
      }
    });
    ref.listen<ChatJumpRequest?>(chatJumpRequestProvider, (_, next) {
      if (next?.conversationId != id) return;
      final target = ref.read(chatJumpRequestProvider.notifier).take(id);
      if (target != null) unawaited(_jumpTo(target));
    });
    // «Ваша жалоба рассмотрена» (neutral, whatever the outcome).
    ref.listen<AsyncValue<ChatEvent>>(chatReportReviewedProvider, (_, next) {
      if (next.value?.payload['status'] != 'reviewed') return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.chatReportReviewed)));
    });
    final selfId = ref.read(chatRepositoryProvider).selfId;
    final selecting = _selected.isNotEmpty;

    return _desktopShell(context, conv, PopScope(
      canPop: !selecting && !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (selecting) {
          setState(_selected.clear);
        } else if (_searching) {
          _closeSearch();
        }
      },
      child: Scaffold(
        appBar: selecting
            ? _selectionBar(context, conv)
            : (_searching ? _searchBar(context) : _titleBar(context, conv)),
        // Desktop: files dropped on the conversation or pasted with Ctrl+V
        // wait above the input, like shared ones, and go with the message.
        body: DesktopDropTarget(
          enabled:
              !selecting &&
              !(conv != null && conv.isChannel && !conv.isAdmin) &&
              conv?.isRequests != true,
          onFiles: (paths) async {
            // Photos go scaled down and upright, like from the phone's picker.
            final ready = [for (final f in paths) await prepareChatPhoto(f, p.basename(f))];
            if (mounted) setState(() => _sharedFiles = [..._sharedFiles, ...ready]);
          },
          child: ChatProtectedScope(
          protection: conv?.protection ?? const ChatProtection(),
          child: Column(
          children: [
            if (!selecting && !_searching && conv?.pinnedMessageId != null)
              _PinnedBar(
                conversation: conv!,
                onOpen: _jumpTo,
                onUnpin: conv.isAdmin
                    ? () async {
                        try {
                          await ref
                              .read(chatRepositoryProvider)
                              .patchChat(id, clearPinned: true);
                        } on AppException catch (e) {
                          _snackError(e);
                        }
                      }
                    : null,
              ),
            Expanded(
              child: ChatWallpaper(
                child: Stack(
                  children: [
                    Positioned.fill(child: _desktopColumn(_list(context, conv, selfId))),
                    Positioned(
                      top: Space.sm,
                      left: 0,
                      right: 0,
                      // Duplicates the in-list day chip: silent for readers.
                      child: IgnorePointer(
                        child: ExcludeSemantics(
                        child: ValueListenableBuilder<DateTime?>(
                          valueListenable: _floatingDay,
                          builder: (context, day, _) => AnimatedOpacity(
                            opacity: day == null ? 0 : 1,
                            duration: const Duration(milliseconds: 180),
                            child: Center(
                              child: day == null
                                  ? const SizedBox.shrink()
                                  : _DayChip(day: day, floating: true),
                            ),
                          ),
                        ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: Space.md,
                      bottom: Space.md,
                      child: _ScrollDownButton(
                        visible: _showFab,
                        conversationId: id,
                        onTap: _scrollToBottom,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!selecting && conv != null && conv.isChannel && !conv.isAdmin)
              ChannelReadOnlyBar(conversation: conv)
            // «Заявки» (desktop): the request form instead of the composer.
            else if (!selecting && conv != null && conv.isRequests)
              _desktopComposer(context, SafeArea(top: false, child: RequestForm(key: ValueKey('request_form_$id'))))
            else if (!selecting)
              _desktopComposer(context, ChatComposer(
                key: ValueKey('composer_$id'),
                replyTo: _replyTo,
                editing: _editing,
                memberNames: _names,
                initialText: _draftInitial,
                onTextChanged: _onDraftChanged,
                pendingFiles: _sharedFiles,
                onRemovePending: (i) => setState(
                  () => _sharedFiles = [..._sharedFiles]..removeAt(i),
                ),
                mentionCandidates: conv?.isGroup == true
                    ? conv!.members.where((m) => m.userId != selfId).toList()
                    : const [],
                onSendContact: _sendContact,
                // Polls: groups and channels (chat-service 0010).
                onCreatePoll: conv != null && (conv.isGroup || conv.isChannel)
                    ? () => createPollFlow(context, ref, id)
                    : null,
                onScheduleText: _scheduleText,
                onScheduleWhenOnline:
                    conv != null &&
                        conv.isDirect &&
                        conv.peer != null &&
                        !conv.peer!.presenceHidden
                    ? _scheduleWhenOnline
                    : null,
                scheduledCount:
                    ref.watch(scheduledMessagesProvider(id)).value?.length ?? 0,
                onOpenScheduled: () => openScheduledMessages(context, id),
                onCancelContext: () => setState(() {
                  _replyTo = null;
                  _editing = null;
                }),
                onSendText: _send,
                onSendFile:
                    ({
                      required path,
                      required filename,
                      voice = false,
                      durationMs,
                    }) async {
                      await _notifier.sendFile(
                        path: path,
                        filename: filename,
                        voice: voice,
                        durationMs: durationMs,
                      );
                      unawaited(_scrollToBottom());
                    },
                onTyping: _notifier.typing,
                onRecording: _notifier.recording,
                onSendSticker: _sendSticker,
                onEditLast: ref.watch(desktopLayoutProvider) ? _editLast : null,
              )),
          ],
        ),
        ),
        ),
      ),
    ));
  }

  PreferredSizeWidget _titleBar(BuildContext context, ChatConversation? conv) {
    final l10n = context.l10n;
    final id = widget.conversationId;
    final desktop = ref.watch(desktopLayoutProvider);
    return AppBar(
      automaticallyImplyLeading: !widget.embedded,
      titleSpacing: widget.embedded ? Space.md : 0,
      title: _ConversationTitle(
        conversationId: id,
        // Info → «Медиа, файлы…» → «Показать в чате» pops back with the id.
        onTap: conv == null || conv.isRequests
            ? null
            // Desktop: the details panel beside the chat, as the web's ⓘ.
            : desktop
            ? () => setState(() => _infoOpen = true)
            : () async {
                final target = await context.push<String>(
                  Routes.chatInfoPath(id),
                );
                if (target != null && mounted) unawaited(_jumpTo(target));
              },
      ),
      actions: [
        // Calls from the chat: 1:1 with the peer, or the whole group.
        if (conv != null &&
            !conv.isSaved &&
            !conv.isRequests &&
            !conv.isChannel &&
            ref.watch(callsEnabledProvider)) ...[
          for (final video in const [false, true])
            IconButton(
              key: Key(video ? 'chat_video_call' : 'chat_audio_call'),
              tooltip: video ? l10n.callsVideo : l10n.callsAudio,
              icon: Icon(video ? LucideIcons.video : LucideIcons.phone),
              onPressed: () => startCallFromUi(
                context,
                ref,
                calleeIds: conv.isGroup
                    ? const []
                    : [if (conv.peer != null) conv.peer!.userId],
                video: video,
                conversationId: conv.id,
                mode: conv.isGroup ? 'group' : 'direct',
              ),
            ),
        ],
        if (conv != null && conv.protection.active)
          ChatProtectionHeaderButton(conversation: conv),
        if (conv?.isSaved == true)
          IconButton(
            key: const Key('chat_reminders_open'),
            tooltip: l10n.remindersTitle,
            icon: const Icon(LucideIcons.alarmClock),
            onPressed: () => openRemindersScreen(context),
          ),
        IconButton(
          key: const Key('chat_search_open'),
          tooltip: l10n.chatSearchInChat,
          icon: const Icon(LucideIcons.search),
          onPressed: () => setState(() => _searching = true),
        ),
        if (desktop && conv != null && !conv.isRequests)
          IconButton(
            key: const Key('chat_info_toggle'),
            tooltip: l10n.desktopChatDetails,
            isSelected: _infoOpen,
            icon: const Icon(LucideIcons.info),
            onPressed: () => setState(() => _infoOpen = !_infoOpen),
          ),
      ],
    );
  }

  PreferredSizeWidget _searchBar(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return AppBar(
      leading: IconButton(
        tooltip: l10n.close,
        icon: const Icon(LucideIcons.arrowLeft),
        onPressed: _closeSearch,
      ),
      titleSpacing: 0,
      title: TextField(
        key: const Key('chat_search_field'),
        controller: _searchCtrl,
        focusNode: _searchFocus,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: _onSearch,
        decoration: InputDecoration(
          hintText: l10n.chatSearchInChat,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
        ),
      ),
      actions: [
        if (_searchBusy)
          const Padding(
            padding: EdgeInsets.all(Space.md),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_searchCtrl.text.trim().length >= 2)
          Center(
            child: Text(
              _hits.isEmpty
                  ? l10n.chatSearchNoResults
                  : l10n.chatSearchPosition(_hitIndex + 1, _hits.length),
              key: const Key('chat_search_counter'),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: t.textTertiary),
            ),
          ),
        IconButton(
          key: const Key('chat_search_older'),
          tooltip: l10n.a11ySearchPrevious,
          icon: const Icon(LucideIcons.chevronUp),
          onPressed: _hitIndex < _hits.length - 1 ? () => _stepHit(1) : null,
        ),
        IconButton(
          key: const Key('chat_search_newer'),
          tooltip: l10n.a11ySearchNext,
          icon: const Icon(LucideIcons.chevronDown),
          onPressed: _hitIndex > 0 ? () => _stepHit(-1) : null,
        ),
      ],
    );
  }

  PreferredSizeWidget _selectionBar(
    BuildContext context,
    ChatConversation? conv,
  ) {
    final l10n = context.l10n;
    final list = _selectedMessages;
    final noForward = conv?.protection.noForward ?? false;
    final canCopy =
        !noForward &&
        list.any((m) => m.body.isNotEmpty && !m.isContact && !m.isDeleted);
    return AppBar(
      key: const Key('chat_selection_bar'),
      leading: IconButton(
        tooltip: l10n.cancel,
        icon: const Icon(LucideIcons.x),
        onPressed: () => setState(_selected.clear),
      ),
      title: Text(
        l10n.chatSelectedMembers(_selected.length),
        key: const Key('chat_selection_count'),
      ),
      actions: [
        if (canCopy)
          IconButton(
            key: const Key('selection_copy'),
            tooltip: l10n.chatCopy,
            icon: const Icon(LucideIcons.copy),
            onPressed: _copySelected,
          ),
        if (!noForward)
        IconButton(
          key: const Key('selection_forward'),
          tooltip: l10n.chatForward,
          icon: const Icon(LucideIcons.forward),
          onPressed: () => _forward(list),
        ),
        if (conv?.isSaved != true && !noForward)
          IconButton(
            key: const Key('selection_save'),
            tooltip: l10n.chatSaveToSaved,
            icon: const Icon(LucideIcons.bookmark),
            onPressed: _saveSelected,
          ),
        IconButton(
          key: const Key('selection_delete'),
          tooltip: l10n.chatDelete,
          icon: const Icon(LucideIcons.trash2),
          onPressed: () => _deleteSelected(conv),
        ),
      ],
    );
  }

  /// Desktop: messages and composer in a centred column (the web's
  /// `max-w-4xl`), so on a wide window one's own messages do not end up at
  /// the far edge.
  static const _desktopColumnWidth = 896.0;

  Widget _desktopColumn(Widget child) => ref.watch(desktopLayoutProvider)
      ? Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: _desktopColumnWidth), child: child),
        )
      : child;

  Widget _desktopComposer(BuildContext context, Widget composer) {
    if (!ref.watch(desktopLayoutProvider)) return composer;
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.divider, width: t.borderWidth)),
      ),
      child: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: _desktopColumnWidth), child: composer),
      ),
    );
  }

  Widget _list(BuildContext context, ChatConversation? conv, String selfId) {
    final l10n = context.l10n;
    final id = widget.conversationId;
    final (messages, loading, error, loadingOlder) = ref.watch(
      conversationProvider(
        id,
      ).select((s) => (s.messages, s.loading, s.error, s.loadingOlder)),
    );
    if (loading && messages.isEmpty) return const StateView.loading();
    if (error != null && messages.isEmpty) {
      return StateView.error(
        message: fmt.ChatFormat.error(l10n, error),
        onRetry: _notifier.load,
      );
    }
    if (messages.isEmpty) {
      if (conv?.isRequests == true) {
        return StateView.empty(
          title: l10n.requestsEmptyTitle,
          subtitle: l10n.requestsEmptyHint,
          icon: LucideIcons.clipboardList,
        );
      }
      return StateView.empty(
        title: l10n.chatNoMessages,
        subtitle: l10n.chatEmptyHint,
        icon: LucideIcons.messagesSquare,
      );
    }
    // Disappearing messages vanish locally when their timer runs out.
    final now = DateTime.now();
    _scheduleExpiry(nextExpiry(messages, now));
    _prepare(withoutExpired(messages, now));
    final items = _items;
    final isGroup = conv?.isGroup ?? false;
    // «Заявки»: a request card shows the status of the newest answer.
    final requests = conv?.isRequests == true
        ? latestRequests(messages)
        : const <String, ChatRequest>{};
    final mediaAuto = ref.watch(chatMediaAutoAllowedProvider);
    final selecting = _selected.isNotEmpty;
    final desktop = ref.watch(desktopLayoutProvider);
    // Desktop hover bar: the three most recent reactions (web ❤️ 👍 😂).
    if (desktop) ref.watch(chatRecentEmojiProvider);
    final quick = desktop ? ref.read(chatRecentEmojiProvider.notifier).quick(3) : const <String>[];
    return ListView.builder(
      key: _listKey,
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      itemCount: items.length + (loadingOlder ? 1 : 0),
      findChildIndexCallback: (key) =>
          key is ValueKey<String> ? _indexByKey[key.value] : null,
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Padding(
            key: ValueKey('loading_older'),
            padding: EdgeInsets.all(Space.md),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final m = items[index];
        final key = keyOf(m);
        final older = index + 1 < items.length ? items[index + 1] : null;
        final newer = index > 0 ? items[index - 1] : null;
        final showDay = older == null || !_sameDay(older.createdAt, m.createdAt);
        final unreadHere = key == _unreadKey;
        final newerStartsUnread = newer != null && keyOf(newer) == _unreadKey;
        final first =
            older == null ||
            showDay ||
            unreadHere ||
            !MessageBubble.sameGroup(older, m);
        final last =
            newer == null ||
            newerStartsUnread ||
            !_sameDay(m.createdAt, newer.createdAt) ||
            !MessageBubble.sameGroup(m, newer);
        return _Tracked(
          key: ValueKey(key),
          registry: _tracked,
          id: key,
          at: m.createdAt,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDay)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.sm),
                  child: _DayChip(day: m.createdAt),
                ),
              if (unreadHere) const _UnreadSeparator(),
              _desktopHover(
                m,
                conv,
                selfId: selfId,
                selecting: selecting,
                isGroup: isGroup,
                quick: quick,
                child: MessageBubble(
                message: m,
                currentRequest: requests[m.request?.id],
                isOwn: m.senderId == selfId,
                isGroup: isGroup,
                selfId: selfId,
                senderName: _names[m.senderId] ?? '',
                senderEmail: _emails[m.senderId] ?? '',
                memberNames: _names,
                mentionNames: _mentionNames,
                firstInGroup: first,
                lastInGroup: last,
                mediaAuto: mediaAuto,
                highlighted: key == _highlightKey,
                selecting: selecting,
                selected: _selected.contains(m.id),
                onTap: () => _toggleSelect(m),
                onLongPress: () => _messageActions(m, conv),
                onReactionTap: (e) => _react(m, e),
                onRetry: () => _notifier.retry(m.clientMessageId),
                onDiscard: () => _notifier.discard(m.clientMessageId),
                onReply: conv?.isRequests == true ? null : () => _startReply(m),
                onReplyTap: _jumpTo,
                onOpenMedia: _openMedia,
                onLinkTap: _openLink,
                onOpenComments:
                    conv != null && conv.isChannel && m.seq > 0
                    ? () => context.push(Routes.chatCommentsPath(id, m.id))
                    : null,
                // Desktop: right click opens the menu at the pointer, a
                // double click reacts ❤️ (the web's bubble).
                onContextMenu: desktop ? (at) => _messageActions(m, conv, at: at) : null,
                // Desktop groups: the sender's name or picture opens the
                // one-to-one chat with them.
                // Groups: the sender's name or picture opens the one-to-one chat.
                onSenderTap: isGroup && m.senderId != selfId && m.senderId.isNotEmpty
                    ? () => unawaited(openDirectChat(context, ref, m.senderId))
                    : null,
                // Double click / double tap reacts ❤️ (not on requests).
                onDoubleClick: m.seq > 0 && conv?.isRequests != true ? () => _react(m, '❤️') : null,
              ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Desktop: [child] with the web's hover bar over it (quick reactions,
  /// «Ответить», «⋯»); phones and rows without actions get [child].
  Widget _desktopHover(
    ChatMessage m,
    ChatConversation? conv, {
    required String selfId,
    required bool selecting,
    required bool isGroup,
    required List<String> quick,
    required Widget child,
  }) {
    if (quick.isEmpty ||
        selecting ||
        m.seq <= 0 ||
        m.isDeleted ||
        m.isServiceLike ||
        _editing?.id == m.id ||
        conv?.isRequests == true) {
      return child;
    }
    final isOwn = m.senderId == selfId;
    return _MessageHoverBar(
      messageId: m.id,
      isOwn: isOwn,
      // Past the sender's avatar in groups, like the bubble itself.
      inset: !isOwn && isGroup ? Space.sm + InitialsAvatar.radiusSm * 2 + Space.md : Space.lg,
      quick: quick,
      onReact: (e) => _react(m, e),
      onReply: () => _startReply(m),
      onMore: (at) => _messageActions(m, conv, at: at),
      child: child,
    );
  }

  Timer? _expiryTimer;
  DateTime? _expiryAt;

  /// Rebuilds when the next disappearing message expires.
  void _scheduleExpiry(DateTime? at) {
    if (at == _expiryAt) return;
    _expiryTimer?.cancel();
    _expiryAt = at;
    if (at == null) return;
    final wait = at.difference(DateTime.now()) + const Duration(milliseconds: 50);
    _expiryTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      _expiryAt = null;
      if (mounted) setState(() {});
    });
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }
}

/// The quick reactions and «+» (the emoji picker) as the first row of the
/// desktop message menu.
class _ReactionMenuRow extends PopupMenuEntry<String> {
  const _ReactionMenuRow({required this.emoji, required this.moreLabel, required this.reactLabel});
  final List<String> emoji;
  final String moreLabel;
  final String reactLabel;

  @override
  double get height => 44;

  @override
  bool represents(String? value) => false;

  @override
  State<_ReactionMenuRow> createState() => _ReactionMenuRowState();
}

class _ReactionMenuRowState extends State<_ReactionMenuRow> {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in widget.emoji)
            Tooltip(
              message: '${widget.reactLabel} $e',
              child: InkResponse(
                key: ValueKey('menu_react_$e'),
                radius: 18,
                onTap: () => Navigator.pop(context, 'react:$e'),
                child: SizedBox(width: 36, height: 36, child: Center(child: Text(e, style: const TextStyle(fontSize: 20)))),
              ),
            ),
          IconButton(
            key: const Key('menu_react_more'),
            tooltip: widget.moreLabel,
            iconSize: 18,
            color: t.textSecondary,
            onPressed: () => Navigator.pop(context, 'react_more'),
            icon: const Icon(LucideIcons.plus),
          ),
        ],
      ),
    );
  }
}

/// Desktop: the web's pill over a hovered message (`group-hover/message`):
/// three quick reactions, «Ответить» and «⋯» with the message menu.
class _MessageHoverBar extends StatefulWidget {
  const _MessageHoverBar({
    required this.messageId,
    required this.isOwn,
    required this.inset,
    required this.quick,
    required this.onReact,
    required this.onReply,
    required this.onMore,
    required this.child,
  });
  final String messageId;
  final bool isOwn;

  /// Distance of the pill from the row's edge on the bubble's side.
  final double inset;
  final List<String> quick;
  final ValueChanged<String> onReact;
  final VoidCallback onReply;
  final ValueChanged<Offset> onMore;
  final Widget child;

  @override
  State<_MessageHoverBar> createState() => _MessageHoverBarState();
}

class _MessageHoverBarState extends State<_MessageHoverBar> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  bool _overRow = false;
  bool _overBar = false;

  /// The bar floats in the overlay (it rises above the row, as the web's
  /// `-top-3`) and stays while the pointer is on the row or on the bar.
  void _hover({bool? row, bool? bar}) {
    _overRow = row ?? _overRow;
    _overBar = bar ?? _overBar;
    if (_overRow || _overBar) {
      if (!_portal.isShowing) _portal.show();
    } else if (_portal.isShowing) {
      _portal.hide();
    }
  }

  /// How far the bar rises above the row.
  static const _rise = 14.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    Widget button({required Key key, required String tooltip, required VoidCallback onTap, required Widget child}) => Tooltip(
      message: tooltip,
      child: InkResponse(
        key: key,
        radius: 16,
        onTap: onTap,
        child: SizedBox(width: 28, height: 28, child: Center(child: child)),
      ),
    );
    final id = widget.messageId;
    final bar = Material(
      key: ValueKey('hover_bar_$id'),
      color: t.surface,
      elevation: 2,
      shadowColor: t.shadowSm.isEmpty ? Colors.transparent : t.shadowSm.first.color,
      shape: StadiumBorder(side: BorderSide(color: t.border, width: t.borderWidth)),
      child: Padding(
        padding: const EdgeInsets.all(Space.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in widget.quick)
              button(
                key: ValueKey('hover_react_${id}_$e'),
                tooltip: '${l10n.chatReact} $e',
                onTap: () => widget.onReact(e),
                child: Text(e, style: const TextStyle(fontSize: 14)),
              ),
            Container(width: 1, height: 20, margin: const EdgeInsets.symmetric(horizontal: Space.xxs), color: t.border),
            button(
              key: ValueKey('hover_reply_$id'),
              tooltip: l10n.chatReply,
              onTap: widget.onReply,
              child: Icon(LucideIcons.reply, size: 14, color: t.textSecondary),
            ),
            Builder(
              builder: (context) => button(
                key: ValueKey('hover_more_$id'),
                tooltip: l10n.mailMoreActions,
                onTap: () {
                  final box = context.findRenderObject()! as RenderBox;
                  widget.onMore(box.localToGlobal(box.size.bottomLeft(Offset.zero)));
                },
                child: Icon(LucideIcons.ellipsis, size: 14, color: t.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
    final own = widget.isOwn;
    return MouseRegion(
      onEnter: (_) => _hover(row: true),
      onExit: (_) => _hover(row: false),
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (_) => Align(
            alignment: Alignment.topLeft,
            child: CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: own ? Alignment.topRight : Alignment.topLeft,
              followerAnchor: own ? Alignment.topRight : Alignment.topLeft,
              offset: Offset(own ? -widget.inset : widget.inset, -_rise),
              child: MouseRegion(
                onEnter: (_) => _hover(bar: true),
                onExit: (_) => _hover(bar: false),
                child: bar,
              ),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Registers a built row by message key while it is mounted.
class _Tracked extends StatefulWidget {
  const _Tracked({
    super.key,
    required this.registry,
    required this.id,
    required this.at,
    required this.child,
  });
  final Map<String, _TrackedState> registry;
  final String id;
  final DateTime at;
  final Widget child;

  @override
  State<_Tracked> createState() => _TrackedState();
}

class _TrackedState extends State<_Tracked> {
  @override
  void initState() {
    super.initState();
    widget.registry[widget.id] = this;
  }

  @override
  void didUpdateWidget(covariant _Tracked old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      if (identical(old.registry[old.id], this)) old.registry.remove(old.id);
      widget.registry[widget.id] = this;
    }
  }

  @override
  void dispose() {
    if (identical(widget.registry[widget.id], this)) {
      widget.registry.remove(widget.id);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// App bar title: avatar, name and the presence / typing line. Only this
/// widget rebuilds on typing and presence changes.
class _ConversationTitle extends ConsumerWidget {
  const _ConversationTitle({required this.conversationId, this.onTap});
  final String conversationId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final (conv, typing, recording) = ref.watch(
      conversationProvider(
        conversationId,
      ).select((s) => (s.conversation, s.typing, s.recording)),
    );
    // 1:1: the peer's status («📅 На совещании · до 15:00») replaces the
    // presence line; typing / recording still win.
    final peer = conv?.peer;
    final peerStatus = conv != null && conv.isDirect && peer != null
        ? watchUserStatus(ref, peer.userId, peer.status)
        : null;
    String? subtitle;
    final active = typing.isNotEmpty || recording.isNotEmpty;
    if (recording.isNotEmpty) {
      subtitle = conv?.isGroup == true
          ? l10n.chatRecording(recording.values.first)
          : l10n.chatRecordingShort;
    } else if (typing.isNotEmpty) {
      subtitle = typing.length == 1
          ? (conv?.isGroup == true
                ? l10n.chatTyping(typing.values.first)
                : l10n.chatTyping(typing.values.first))
          : l10n.chatTypingMany;
    } else if (conv != null) {
      subtitle = conv.isSaved
          ? l10n.chatSavedHint
          : conv.isChannel
          ? l10n.channelSubscribersCount(conv.memberCount)
          : conv.isGroup
          ? l10n.chatMembersCount(conv.memberCount)
          : peerStatus != null
          ? ChatStatusFormat.line(context, peerStatus)
          : fmt.ChatFormat.presence(context, conv.peer);
    }
    final title = conv?.isSaved == true ? l10n.chatSaved : (conv?.title ?? '');
    // One node «Имя, в сети»; the name comes from the label, the presence /
    // typing line from the Text below, announced politely when it changes.
    return Semantics(
      container: true,
      button: onTap != null,
      header: true,
      liveRegion: active,
      label: title,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(t.radiusSm),
      child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          if (conv != null) ...[
            ExcludeSemantics(
              child: ChatAvatar(conversation: conv, radius: 18, showOnline: true),
            ),
            const SizedBox(width: Space.sm + 2),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Text(
                      subtitle,
                      key: ValueKey(subtitle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: active || conv?.peer?.online == true
                            ? t.primary
                            : t.textTertiary,
                      ),
                    ),
                  ),
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

/// The pinned message of a group; tap jumps to it, even when it is outside
/// the loaded page (fetched by id).
class _PinnedBar extends ConsumerWidget {
  const _PinnedBar({
    required this.conversation,
    required this.onOpen,
    this.onUnpin,
  });
  final ChatConversation conversation;
  final Future<void> Function(String messageId) onOpen;
  final VoidCallback? onUnpin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final pinnedId = conversation.pinnedMessageId!;
    final loaded = ref.watch(
      conversationProvider(conversation.id).select(
        (s) => s.messages.where((m) => m.id == pinnedId).firstOrNull,
      ),
    );
    final message =
        loaded ??
        ref
            .watch(
              chatPinnedMessageProvider((
                conversationId: conversation.id,
                messageId: pinnedId,
              )),
            )
            .value;
    final preview = message == null
        ? '…'
        : fmt.ChatFormat.preview(l10n, message);
    return Material(
      color: t.surface,
      // One button «Закреплённое сообщение, <текст>»; the unpin IconButton
      // below stays a separate node.
      child: Semantics(
        container: true,
        button: true,
        label: '${l10n.chatPinnedMessage}, $preview',
        child: InkWell(
        key: const Key('pinned_bar'),
        onTap: () => onOpen(pinnedId),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: t.divider, width: t.borderWidth),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.xs, Space.xs),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 34,
                decoration: BoxDecoration(
                  color: t.primary,
                  borderRadius: BorderRadius.circular(XatBoxTokens.radiusPill),
                ),
              ),
              const SizedBox(width: Space.sm),
              Icon(LucideIcons.pin, size: 16, color: t.primary),
              const SizedBox(width: Space.sm),
              Expanded(
                child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.chatPinnedMessage,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: t.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                    ),
                  ],
                ),
                ),
              ),
              if (onUnpin != null)
                IconButton(
                  key: const Key('pinned_unpin'),
                  tooltip: l10n.chatUnpinMessage,
                  icon: Icon(LucideIcons.x, size: 18, color: t.textTertiary),
                  onPressed: onUnpin,
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day, this.floating = false});
  final DateTime day;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.smd, vertical: 3),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: floating ? 0.96 : 0.88),
        borderRadius: BorderRadius.circular(XatBoxTokens.radiusPill),
        border: Border.all(color: t.border, width: t.borderWidth),
        boxShadow: floating ? t.shadowSm : null,
      ),
      child: Text(
        fmt.ChatFormat.daySeparator(context, day),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: t.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _UnreadSeparator extends StatelessWidget {
  const _UnreadSeparator();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      key: const Key('chat_unread_separator'),
      margin: const EdgeInsets.symmetric(vertical: Space.sm),
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      color: t.surface.withValues(alpha: 0.9),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.chevronsDown, size: 14, color: t.primary),
          const SizedBox(width: Space.xs),
          Text(
            context.l10n.chatUnreadMessages,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: t.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Round "scroll to the newest" button with the unread counter.
class _ScrollDownButton extends ConsumerWidget {
  const _ScrollDownButton({
    required this.visible,
    required this.conversationId,
    required this.onTap,
  });
  final ValueListenable<bool> visible;
  final String conversationId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return ValueListenableBuilder<bool>(
      valueListenable: visible,
      builder: (context, show, _) => IgnorePointer(
        ignoring: !show,
        child: AnimatedScale(
          scale: show ? 1 : 0.6,
          duration: const Duration(milliseconds: 160),
          child: AnimatedOpacity(
            opacity: show ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  color: t.surface,
                  shape: CircleBorder(
                    side: BorderSide(color: t.border, width: t.borderWidth),
                  ),
                  elevation: 2,
                  shadowColor: t.shadowSm.isEmpty
                      ? Colors.transparent
                      : t.shadowSm.first.color,
                  child: InkWell(
                    key: const Key('chat_scroll_bottom'),
                    customBorder: const CircleBorder(),
                    onTap: onTap,
                    child: Padding(
                      // 12 + 24 + 12 = 48 dp tap target.
                      padding: const EdgeInsets.all(Space.smd),
                      child: Icon(
                        LucideIcons.chevronDown,
                        color: t.textSecondary,
                        semanticLabel: context.l10n.chatScrollToBottom,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -Space.sm,
                  left: 0,
                  right: 0,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final unread = ref.watch(
                        conversationProvider(
                          conversationId,
                        ).select((s) => s.conversation?.unread ?? 0),
                      );
                      if (unread <= 0) return const SizedBox.shrink();
                      return Center(
                        child: CountPill(
                          unread,
                          color: t.textInverse,
                          background: t.primary,
                        ),
                      );
                    },
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

/// Who got / read an own group message.
class _ReceiptsSheet extends ConsumerWidget {
  const _ReceiptsSheet({required this.message, required this.names});
  final ChatMessage message;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final receipts = ref.watch(chatReceiptsProvider(message.id));
    String when(DateTime at) =>
        '${fmt.ChatFormat.daySeparator(context, at)}, ${fmt.ChatFormat.time(context, at)}';
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.5,
        child: receipts.when(
          loading: () => const StateView.loading(),
          error: (e, _) => StateView.error(
            message: fmt.ChatFormat.error(l10n, e),
            onRetry: () => ref.invalidate(chatReceiptsProvider(message.id)),
          ),
          data: (list) {
            final read = list.where((r) => r.readAt != null).toList();
            final delivered = list
                .where((r) => r.readAt == null && r.deliveredAt != null)
                .toList();
            if (read.isEmpty && delivered.isEmpty) {
              return StateView.empty(
                title: l10n.chatNoReceipts,
                icon: LucideIcons.checkCheck,
              );
            }
            Widget tile(ChatReceipt r, DateTime at, IconData icon) => ListTile(
              leading: InitialsAvatar(
                label: names[r.userId] ?? '?',
                colorKey: r.userId,
              ),
              title: Text(names[r.userId] ?? r.userId),
              subtitle: Text(when(at), style: TextStyle(color: t.textTertiary)),
              trailing: Icon(
                icon,
                size: 18,
                color: t.primary,
                semanticLabel: icon == LucideIcons.checkCheck
                    ? l10n.chatStatusRead
                    : l10n.chatStatusDelivered,
              ),
            );
            return ListView(
              key: const Key('chat_receipts'),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.sm),
                  child: Text(
                    l10n.chatMessageInfo,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (read.isNotEmpty) ...[
                  _SheetLabel(l10n.chatReadBy),
                  for (final r in read) tile(r, r.readAt!, LucideIcons.checkCheck),
                ],
                if (delivered.isNotEmpty) ...[
                  _SheetLabel(l10n.chatStatusDelivered),
                  for (final r in delivered)
                    tile(r, r.deliveredAt!, LucideIcons.check),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.xs),
    child: Text(
      context.tokens.sectionLabel(text),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: context.tokens.textTertiary,
        letterSpacing: 0.6,
      ),
    ),
  );
}
