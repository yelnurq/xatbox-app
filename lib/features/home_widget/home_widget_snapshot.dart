import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/localization/generated/app_localizations.dart';
import '../calendar/data/calendar_models.dart';
import '../chat/data/chat_models.dart';

/// JSON snapshot for the «XatBox» home screen widget, format v1 (read by
/// android/app/src/main/kotlin/kz/xatbox/xatbox_mobile/XatBoxWidgetProvider.kt
/// and ios/XatBoxWidget/XatBoxWidget.swift — change both with the format).
///
/// Privacy rules:
/// * message previews only when the user switched them on (default off —
///   titles only), never for deleted messages;
/// * [hideContent] (PIN lock or «Скрывать содержимое»): no chat titles and no
///   events leave the app, only the unread count;
/// * signed out: [signedOutHomeWidgetSnapshot] (no personal data at all).
const homeWidgetSnapshotVersion = 1;
const homeWidgetMaxChats = 3;
const homeWidgetMaxEvents = 5;
const _previewMaxChars = 80;

String buildHomeWidgetSnapshot({
  required List<ChatConversation> conversations,
  required int unreadTotal,
  required List<CalendarOccurrence> today,
  required tz.Location location,
  required DateTime now,
  required AppLocalizations l10n,
  required bool showPreview,
  required bool hideContent,
  required Color accent,
  required Color accentDark,
  required Color Function(String key) avatarColor,
}) {
  final local = tz.TZDateTime.from(now, location);
  final dayEnd = tz.TZDateTime(location, local.year, local.month, local.day + 1);
  final chats = hideContent
      ? const <Map<String, Object?>>[]
      : [
          for (final c in conversations
              .where(
                (c) =>
                    c.hasUnread &&
                    !c.isSaved &&
                    !c.isMuted &&
                    !c.settings.archived,
              )
              .take(homeWidgetMaxChats))
            _chat(c, showPreview: showPreview, color: avatarColor(c.id)),
        ];
  // 24-hour clock like the calendar; no locale data needed (background use).
  final time = DateFormat('HH:mm');
  String hm(DateTime utc) => time.format(tz.TZDateTime.from(utc, location));
  final events = hideContent
      ? const <Map<String, Object?>>[]
      : [
          for (final o in (today.where(
            (o) =>
                !o.allDay &&
                !o.event.isCancelled &&
                o.end.isAfter(now) &&
                o.start.isBefore(dayEnd),
          ).toList()..sort((a, b) => a.start.compareTo(b.start))).take(
            homeWidgetMaxEvents,
          ))
            {
              'title': o.event.title.trim(),
              'time': '${hm(o.start)}–${hm(o.end)}',
              'start': o.start.millisecondsSinceEpoch,
              'end': o.end.millisecondsSinceEpoch,
            },
        ];
  return jsonEncode({
    'v': homeWidgetSnapshotVersion,
    'signedIn': true,
    'hidden': hideContent,
    'unread': unreadTotal,
    'headline': unreadTotal > 0
        ? l10n.homeWidgetUnread(unreadTotal)
        : l10n.homeWidgetNoUnread,
    'accent': colorHex(accent),
    'accentDark': colorHex(accentDark),
    'dayEnd': dayEnd.millisecondsSinceEpoch,
    'chats': chats,
    'events': events,
    'labels': {
      'signIn': l10n.homeWidgetSignIn,
      'noEvents': l10n.homeWidgetNoEvents,
    },
  });
}

/// What the widget keeps after sign-out: a localized «Войдите» only.
String signedOutHomeWidgetSnapshot(AppLocalizations l10n) => jsonEncode({
  'v': homeWidgetSnapshotVersion,
  'signedIn': false,
  'labels': {'signIn': l10n.homeWidgetSignIn},
});

Map<String, Object?> _chat(
  ChatConversation c, {
  required bool showPreview,
  required Color color,
}) {
  final title = c.title.trim().isNotEmpty
      ? c.title.trim()
      : (c.peer?.email ?? '').trim();
  final preview = showPreview ? messagePreview(c.lastMessage) : '';
  return {
    'id': c.id,
    'title': title,
    'initial': title.isEmpty ? '' : title.characters.first.toUpperCase(),
    if (preview.isNotEmpty) 'preview': preview,
    'unread': c.unread,
    'color': colorHex(color),
  };
}

/// First line of a text message, shortened; empty for deleted messages and
/// messages without text.
String messagePreview(ChatMessage? m) {
  if (m == null || m.isDeleted) return '';
  final line = m.body.trim().split('\n').first.trim();
  if (line.characters.length <= _previewMaxChars) return line;
  return '${line.characters.take(_previewMaxChars - 1)}…';
}

String colorHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
