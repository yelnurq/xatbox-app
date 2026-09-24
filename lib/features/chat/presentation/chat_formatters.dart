import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../shared/utils/error_text.dart';
import '../data/chat_models.dart';

/// Text helpers for the chat UI (previews, dates, system messages, errors).
abstract final class ChatFormat {
  static String preview(AppLocalizations l10n, ChatMessage m) {
    if (m.isDeleted) return l10n.chatDeleted;
    if (m.isServiceLike) return systemText(l10n, m, names: const {});
    switch (m.type) {
      case 'image':
        return '📷 ${l10n.chatAttachmentImage}';
      case 'video':
        return '🎬 ${l10n.chatAttachmentVideo}';
      case 'voice':
        return '🎤 ${l10n.chatAttachmentVoice}';
      case 'audio':
        return '🎵 ${l10n.chatAttachmentAudio}';
      case 'file':
        return '📎 ${m.attachments.isNotEmpty ? m.attachments.first.filename : l10n.chatAttachmentFile}';
      case 'sticker':
        final emoji = m.sticker?.emoji ?? '';
        return '${emoji.isEmpty ? '🙂' : emoji} ${l10n.chatAttachmentSticker}';
      case 'contact':
        final label = m.contact?.label ?? '';
        return '👤 ${label.isEmpty ? l10n.chatAttachContact : label}';
    }
    return m.body;
  }

  /// System messages carry `kind` in the body (member_added, …); names are
  /// resolved from the conversation members when known.
  static String systemText(
    AppLocalizations l10n,
    ChatMessage m, {
    required Map<String, String> names,
  }) {
    // «Автоответ: …» of a user with a status (1:1 chats).
    if (m.isAutoReply) return l10n.chatAutoReplyText(m.body);
    String name(String? id) => id == null ? '' : (names[id] ?? '…');
    final actor = name(m.senderId);
    switch (m.body) {
      case 'member_added':
        return l10n.chatSystemMemberAdded(actor, name(_meta(m, 'user_id')));
      case 'members_removed':
      case 'member_removed':
        return l10n.chatSystemMemberRemoved(actor, name(_meta(m, 'user_id')));
      case 'member_left':
        return l10n.chatSystemMemberLeft(actor);
      case 'title_changed':
        return l10n.chatSystemTitleChanged(actor, _meta(m, 'title') ?? '');
      case 'protection_changed':
        return l10n.chatSystemProtectionChanged(actor);
      case 'moderation_warning':
        return l10n.chatSystemModerationWarning;
      case 'member_restricted':
        return l10n.chatSystemMemberRestricted;
      case 'description_changed':
        return l10n.chatSystemDescriptionChanged(actor);
    }
    return l10n.chatSystemGeneric;
  }

  static String? _meta(ChatMessage m, String key) =>
      null; // metadata is not exposed to the client yet

  static String time(BuildContext context, DateTime t) =>
      DateFormat.Hm(Localizations.localeOf(context).toString())
          .format(t.toLocal());

  static String daySeparator(BuildContext context, DateTime t) {
    final l10n = context.l10n;
    final local = t.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) return l10n.chatToday;
    if (day == today.subtract(const Duration(days: 1))) {
      return l10n.chatYesterday;
    }
    final locale = Localizations.localeOf(context).toString();
    return day.year == now.year
        ? DateFormat.MMMMd(locale).format(local)
        : DateFormat.yMMMd(locale).format(local);
  }

  static String listTime(BuildContext context, DateTime? t) {
    if (t == null) return '';
    final local = t.toLocal();
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).toString();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return DateFormat.Hm(locale).format(local);
    }
    if (now.difference(local).inDays < 7) {
      return DateFormat.E(locale).format(local);
    }
    return DateFormat.Md(locale).format(local);
  }

  static String presence(BuildContext context, ChatUser? user) {
    final l10n = context.l10n;
    if (user == null) return '';
    if (user.online) return l10n.chatOnline;
    final seen = user.lastSeenAt;
    if (seen == null) return '';
    return l10n.chatLastSeen(_relative(context, seen));
  }

  static String _relative(BuildContext context, DateTime t) {
    final diff = DateTime.now().difference(t.toLocal());
    final locale = Localizations.localeOf(context).toString();
    if (diff.inMinutes < 1) return time(context, t);
    if (diff.inHours < 24) return time(context, t);
    return DateFormat.MMMd(locale).add_Hm().format(t.toLocal());
  }

  static String duration(int? ms) {
    final d = Duration(milliseconds: ms ?? 0);
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Chat-specific error codes on top of the shared mapping.
  static String error(AppLocalizations l10n, Object e) {
    if (e is ApiException) {
      switch (e.code) {
        case 'RATE_LIMITED':
          return l10n.chatRateLimited;
        case 'FILE_TOO_LARGE':
          return l10n.chatFileTooLarge;
        case 'FILE_TYPE_FORBIDDEN':
          return l10n.chatFileTypeForbidden;
        case 'FILE_INFECTED':
          return l10n.chatFileInfected;
        case 'AV_UNAVAILABLE':
          return l10n.chatAvUnavailable;
        case 'MESSAGE_TOO_LONG':
          return l10n.chatMessageTooLong;
        case 'FORWARD_FORBIDDEN':
          return l10n.chatForwardForbidden;
        case 'MEMBER_RESTRICTED':
          return l10n.chatMemberRestricted;
        case 'TRANSCRIPTION_BUSY':
          return l10n.chatTranscriptionBusy;
        case 'NOT_TRANSCRIBABLE':
        case 'FEATURE_DISABLED':
          return l10n.chatTranscriptFailed;
        case 'INVALID_STICKER':
          return l10n.chatStickerUnavailable;
        case 'REPORT_CLOSED':
          return l10n.moderationAlreadyHandled;
        case 'INVALID_CONTACT':
          return l10n.chatContactInvalid;
        case 'CONVERSATION_NOT_FOUND':
        case 'NOT_MEMBER':
          return l10n.chatConversationGone;
        case 'NO_ORGANIZATION':
        case 'FORBIDDEN':
          return l10n.chatNoAccess;
      }
    }
    return ErrorText.describe(l10n, e);
  }
}
