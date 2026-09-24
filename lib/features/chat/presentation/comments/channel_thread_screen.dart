import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/state_view.dart';
import '../../data/chat_models.dart';
import '../chat_composer.dart';
import '../chat_emoji_picker.dart';
import '../chat_formatters.dart' as fmt;
import '../chat_providers.dart';
import '../chat_wallpaper.dart';
import '../message_bubble.dart';
import '../moderation/report_message_sheet.dart';
import 'channel_thread_providers.dart';
import '../../../../shared/widgets/app_sheet.dart';

/// Error text of the comment calls.
String commentsErrorText(AppLocalizations l10n, Object e) {
  if (e is ApiException) {
    switch (e.code) {
      case 'COMMENTS_DISABLED':
        return l10n.commentsDisabled;
      case 'INVALID_THREAD':
        return l10n.commentsInvalidThread;
    }
  }
  return fmt.ChatFormat.error(l10n, e);
}

/// The conversation of a thread from the cache (no history load), kept in
/// step with local and server changes.
final threadConversationProvider = FutureProvider.autoDispose
    .family<ChatConversation?, String>((ref, id) async {
      final repo = ref.watch(chatRepositoryProvider);
      final sub = repo.events
          .where(
            (e) =>
                e.conversationId == id &&
                (e.type == 'chat.updated' || e.type == 'chat.local'),
          )
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(sub.cancel);
      return repo.conversation(id);
    });

/// Comments of a channel post: the post on top, the comments below and the
/// regular composer (replies, mentions, stickers, files; no polls).
class ChannelThreadScreen extends ConsumerStatefulWidget {
  const ChannelThreadScreen({
    super.key,
    required this.conversationId,
    required this.postId,
  });
  final String conversationId;
  final String postId;

  @override
  ConsumerState<ChannelThreadScreen> createState() =>
      _ChannelThreadScreenState();
}

class _ChannelThreadScreenState extends ConsumerState<ChannelThreadScreen> {
  final _scroll = ScrollController();
  ChatMessage? _replyTo;
  ChatMessage? _editing;

  ChannelThreadKey get _key =>
      (conversationId: widget.conversationId, postId: widget.postId);

  ChannelThreadNotifier get _notifier =>
      ref.read(channelThreadProvider(_key).notifier);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      if (pos.pixels >= pos.maxScrollExtent - 300) {
        unawaited(_notifier.loadOlder());
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _snack(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(commentsErrorText(context.l10n, e))),
    );
  }

  Future<void> _send(String text, List<String> mentions) async {
    try {
      if (_editing != null) {
        await _notifier.edit(_editing!, text);
        if (mounted) setState(() => _editing = null);
        return;
      }
      final reply = _replyTo;
      setState(() => _replyTo = null);
      await _notifier.sendText(text, replyToId: reply?.id, mentions: mentions);
      if (_scroll.hasClients) {
        unawaited(
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          ),
        );
      }
    } on AppException catch (e) {
      _snack(e);
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on AppException catch (e) {
      _snack(e);
    }
  }

  Future<void> _actions(ChatMessage m, ChatConversation? conv) async {
    final l10n = context.l10n;
    final selfId = ref.read(chatRepositoryProvider).selfId;
    final own = m.senderId == selfId;
    final isPost = m.id == widget.postId;
    final noForward = conv?.protection.noForward ?? false;
    unawaited(HapticFeedback.selectionClick());
    final action = await showAppSheet<String>(
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
                if (m.seq > 0) ...[
                  ListTile(
                    key: const Key('thread_reply'),
                    leading: const Icon(LucideIcons.reply),
                    title: Text(l10n.chatReply),
                    onTap: () => Navigator.pop(ctx, 'reply'),
                  ),
                  ListTile(
                    key: const Key('thread_react'),
                    leading: const Icon(LucideIcons.smilePlus),
                    title: Text(l10n.chatReact),
                    onTap: () => Navigator.pop(ctx, 'react'),
                  ),
                ],
                if (m.body.isNotEmpty && m.type == 'text' && !noForward)
                  ListTile(
                    leading: const Icon(LucideIcons.copy),
                    title: Text(l10n.chatCopy),
                    onTap: () => Navigator.pop(ctx, 'copy'),
                  ),
                if (own && !isPost && m.type == 'text' && m.seq > 0)
                  ListTile(
                    key: const Key('thread_edit'),
                    leading: const Icon(LucideIcons.pencil),
                    title: Text(l10n.chatEdit),
                    onTap: () => Navigator.pop(ctx, 'edit'),
                  ),
                if (!own && m.seq > 0 && !m.isDeleted)
                  ListTile(
                    key: const Key('thread_report'),
                    leading: const Icon(LucideIcons.flag),
                    title: Text(l10n.chatReport),
                    onTap: () => Navigator.pop(ctx, 'report'),
                  ),
                if (!isPost && m.seq > 0)
                  ListTile(
                    key: const Key('thread_delete_me'),
                    leading: Icon(LucideIcons.eyeOff, color: t.danger),
                    title: Text(
                      l10n.chatDeleteForMe,
                      style: TextStyle(color: t.danger),
                    ),
                    onTap: () => Navigator.pop(ctx, 'delete_me'),
                  ),
                if (!isPost && m.seq > 0 && (own || (conv?.isAdmin ?? false)))
                  ListTile(
                    key: const Key('thread_delete'),
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
    switch (action) {
      case 'reply':
        setState(() {
          _replyTo = m;
          _editing = null;
        });
      case 'react':
        final emoji = await ChatEmojiPickerSheet.show(context);
        if (emoji != null) await _guard(() => _notifier.react(m, emoji));
      case 'copy':
        final messenger = ScaffoldMessenger.of(context);
        await Clipboard.setData(ClipboardData(text: m.body));
        messenger.showSnackBar(SnackBar(content: Text(l10n.chatCopied)));
      case 'edit':
        setState(() {
          _editing = m;
          _replyTo = null;
        });
      case 'report':
        await ReportMessageSheet.show(context, m);
      case 'delete_me':
        await _guard(() => _notifier.hideForMe(m));
      case 'delete':
        await _guard(() => _notifier.delete(m));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final state = ref.watch(channelThreadProvider(_key));
    final conv = ref.watch(threadConversationProvider(widget.conversationId)).value;
    final selfId = ref.read(chatRepositoryProvider).selfId;
    final names = <String, String>{
      for (final m in conv?.members ?? const <ChatMember>[]) m.userId: m.label,
      selfId: l10n.chatYou,
    };
    final mentionNames = {
      for (final m in conv?.members ?? const <ChatMember>[]) m.userId: m.label,
    };
    final mediaAuto = ref.watch(chatMediaAutoAllowedProvider);
    final post = state.post;

    Widget bubble(ChatMessage m, {required bool isPost, bool first = true}) =>
        MessageBubble(
          key: ValueKey(isPost ? 'thread_post' : 'comment_${m.clientMessageId.isEmpty ? m.id : m.clientMessageId}'),
          message: m,
          isOwn: m.senderId == selfId,
          isGroup: !isPost,
          selfId: selfId,
          senderName: names[m.senderId] ?? '',
          memberNames: names,
          mentionNames: mentionNames,
          firstInGroup: first,
          mediaAuto: mediaAuto,
          onLongPress: () => _actions(m, conv),
          onReactionTap: (e) => _guard(() => _notifier.react(m, e)),
          onRetry: () => _guard(() => _notifier.retry(m.clientMessageId)),
          onDiscard: () => _notifier.discard(m.clientMessageId),
          onReply: m.seq > 0
              ? () => setState(() {
                  _replyTo = m;
                  _editing = null;
                })
              : null,
          onLinkTap: (uri) => ref.read(chatLinkOpenerProvider)(uri),
        );

    Widget body;
    if (post == null && state.loading) {
      body = const StateView.loading();
    } else if (post == null) {
      body = StateView.error(
        message: state.error == null
            ? l10n.commentsPostUnavailable
            : commentsErrorText(l10n, state.error!),
        onRetry: _notifier.load,
      );
    } else {
      final comments = state.comments.reversed.toList(growable: false);
      final count = post.commentCount ?? state.comments.where((m) => m.seq > 0).length;
      body = ListView.builder(
        key: const Key('thread_list'),
        controller: _scroll,
        reverse: true,
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        itemCount: comments.length + 1 + (state.loadingOlder ? 1 : 0),
        itemBuilder: (context, i) {
          if (i < comments.length) {
            final m = comments[i];
            final older = i + 1 < comments.length ? comments[i + 1] : null;
            return bubble(
              m,
              isPost: false,
              first: older == null || !MessageBubble.sameGroup(older, m),
            );
          }
          if (i > comments.length) {
            return const Padding(
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
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              bubble(post, isPost: true),
              Container(
                key: const Key('thread_count'),
                margin: const EdgeInsets.symmetric(
                  horizontal: Space.md,
                  vertical: Space.sm,
                ),
                padding: const EdgeInsets.symmetric(vertical: Space.xs),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: t.divider, width: t.borderWidth),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  count == 0 ? l10n.commentsEmpty : l10n.commentsCount(count),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: t.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.channelComments),
            if (conv != null)
              Text(
                conv.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: ChatWallpaper(child: body)),
          if (post != null && !state.enabled)
            Material(
              key: const Key('comments_disabled_bar'),
              color: t.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Row(
                    children: [
                      Icon(LucideIcons.messageSquareOff, size: 16, color: t.textTertiary),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          l10n.commentsDisabled,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: t.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (post != null)
            ChatComposer(
              key: ValueKey('thread_composer_${widget.postId}'),
              replyTo: _replyTo,
              editing: _editing,
              memberNames: names,
              mentionCandidates: [
                for (final m in conv?.members ?? const <ChatMember>[])
                  if (m.userId != selfId) m,
              ],
              onCancelContext: () => setState(() {
                _replyTo = null;
                _editing = null;
              }),
              onSendText: _send,
              onSendFile:
                  ({required path, required filename, voice = false, durationMs}) =>
                      _guard(
                        () => _notifier.sendFile(
                          path: path,
                          filename: filename,
                          voice: voice,
                          durationMs: durationMs,
                        ),
                      ),
              onSendSticker: (s) => _guard(() => _notifier.sendSticker(s)),
              onTyping: () {},
              onRecording: (_) {},
            ),
        ],
      ),
    );
  }
}
