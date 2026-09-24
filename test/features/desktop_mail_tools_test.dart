import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/notifications/local_notification_hub.dart';
import 'package:xatbox_mobile/core/platform/desktop_commands.dart';
import 'package:xatbox_mobile/core/platform/desktop_settings.dart';
import 'package:xatbox_mobile/core/platform/desktop_shell.dart';
import 'package:xatbox_mobile/features/calendar/domain/ics_invite.dart';
import 'package:xatbox_mobile/features/calls/presentation/desktop_mini_call.dart';
import 'package:xatbox_mobile/features/chat/presentation/status/desktop_auto_away.dart';
import 'package:xatbox_mobile/features/mail/data/mail_models.dart';
import 'package:xatbox_mobile/features/mail/domain/eml.dart';
import 'package:xatbox_mobile/features/mail/presentation/compose_spell_check.dart';
import 'package:xatbox_mobile/features/mail/presentation/desktop_mail_notifier.dart';
import 'package:xatbox_mobile/features/mail/presentation/markup_editing_controller.dart';

import '../helpers/fixtures.dart';

void main() {
  group('command line', () {
    test('Send To files, a file on the icon, .eml, .ics, hotkeys', () {
      expect(parseDesktopArguments([DesktopArguments.attach, r'C:\a.pdf', r'C:\b.docx']), [
        const DesktopCompose(files: [r'C:\a.pdf', r'C:\b.docx']),
      ]);
      expect(parseDesktopArguments([DesktopArguments.attach, r'C:\saved.eml']), [
        const DesktopCompose(files: [r'C:\saved.eml']),
      ], reason: 'Send To attaches even a message file');
      expect(parseDesktopArguments(['/Users/a/Письмо.EML']), [const DesktopOpenEml('/Users/a/Письмо.EML')]);
      expect(parseDesktopArguments(['/tmp/invite.ics']), [const DesktopOpenIcs('/tmp/invite.ics')]);
      expect(parseDesktopArguments(['/tmp/photo.jpg']), [const DesktopCompose(files: ['/tmp/photo.jpg'])]);
      expect(parseDesktopArguments([DesktopArguments.show]), [const DesktopShow()]);
      expect(parseDesktopArguments([DesktopArguments.hidden]), isEmpty);
    });
  });

  group('saved message (.eml)', () {
    Uint8List bytes(String s) => Uint8List.fromList(latin1.encode(s));

    test('headers, HTML in windows-1251 quoted-printable, a base64 file, an inline picture', () {
      final subject = base64.encode(utf8.encode('Отчёт за сентябрь'));
      final pdf = base64.encode(utf8.encode('%PDF-1.4 test'));
      // «Привет» in windows-1251, quoted-printable.
      const privet = '=CF=F0=E8=E2=E5=F2';
      final eml =
          'From: =?utf-8?B?${base64.encode(utf8.encode('Иван Петров'))}?= <ivan@kaztbu.edu.kz>\r\n'
          'To: a@kaztbu.edu.kz, b@kaztbu.edu.kz\r\n'
          'Subject: =?utf-8?B?$subject?=\r\n'
          'Date: Thu, 18 Sep 2026 14:03:05 +0500\r\n'
          'Content-Type: multipart/mixed; boundary="b1"\r\n\r\n'
          '--b1\r\n'
          'Content-Type: multipart/alternative; boundary=b2\r\n\r\n'
          '--b2\r\nContent-Type: text/plain; charset=utf-8\r\n\r\nplain\r\n'
          '--b2\r\nContent-Type: text/html; charset=windows-1251\r\n'
          'Content-Transfer-Encoding: quoted-printable\r\n\r\n<p>$privet</p><img src="cid:logo">\r\n'
          '--b2--\r\n'
          '--b1\r\nContent-Type: image/png\r\nContent-ID: <logo>\r\nContent-Transfer-Encoding: base64\r\n\r\niVBORw0KGgo=\r\n'
          '--b1\r\nContent-Type: application/pdf\r\n'
          "Content-Disposition: attachment; filename*=utf-8''%D0%9E%D1%82%D1%87%D1%91%D1%82.pdf\r\n"
          'Content-Transfer-Encoding: base64\r\n\r\n$pdf\r\n'
          '--b1--\r\n';
      final m = EmlMessage.parse(bytes(eml));
      expect(m.from, 'Иван Петров <ivan@kaztbu.edu.kz>');
      expect(m.subject, 'Отчёт за сентябрь');
      expect(m.to, 'a@kaztbu.edu.kz, b@kaztbu.edu.kz');
      expect(m.date, DateTime.utc(2026, 9, 18, 9, 3, 5));
      expect(m.text, 'plain');
      expect(m.html, contains('<p>Привет</p>'));
      expect(m.parts.map((p) => p.filename), ['file', 'Отчёт.pdf']);
      expect(m.parts.first.contentId, 'logo');
      expect(utf8.decode(m.parts.last.bytes), '%PDF-1.4 test');
    });

    test('KOI8-R text, raw UTF-8 subject, Q-encoded words', () {
      final koi = [0xF0, 0xD2, 0xC9, 0xD7, 0xC5, 0xD4]; // «Привет» in KOI8-R
      final eml = [
        ...utf8.encode('Subject: Тема =?utf-8?Q?=D0=B8_=D0=B5=D1=89=D1=91?=\nContent-Type: text/plain; charset=koi8-r\n\n'),
        ...koi,
      ];
      final m = EmlMessage.parse(Uint8List.fromList(eml));
      expect(m.subject, 'Тема и ещё');
      expect(m.text, 'Привет');
    });
  });

  group('calendar invitation (.ics)', () {
    test('title, place, text, zone and times; folded lines', () {
      const ics =
          'BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nSUMMARY:Учёный совет\\, заседание\r\n'
          'LOCATION:Ауд. 301\r\nDESCRIPTION:Повестка:\\n1. Отчёт\r\n  кафедры\r\n'
          'DTSTART;TZID=Asia/Almaty:20260925T100000\r\nDTEND;TZID=Asia/Almaty:20260925T113000\r\nEND:VEVENT\r\nEND:VCALENDAR';
      final e = IcsInvite.parse(ics)!;
      expect(e.title, 'Учёный совет, заседание');
      expect(e.location, 'Ауд. 301');
      expect(e.description, 'Повестка:\n1. Отчёт кафедры');
      expect(e.zone, 'Asia/Almaty');
      expect(e.start, DateTime(2026, 9, 25, 10));
      expect(e.end, DateTime(2026, 9, 25, 11, 30));
      expect(e.allDay, isFalse);
    });

    test('all-day, UTC with a duration, nothing to import', () {
      final day = IcsInvite.parse('BEGIN:VEVENT\nSUMMARY:Выходной\nDTSTART;VALUE=DATE:20261216\nEND:VEVENT')!;
      expect(day.allDay, isTrue);
      expect(day.end, DateTime(2026, 12, 17));
      final utc = IcsInvite.parse('BEGIN:VEVENT\nDTSTART:20260925T040000Z\nDURATION:PT45M\nEND:VEVENT')!;
      expect(utc.zone, 'UTC');
      expect(utc.end, DateTime(2026, 9, 25, 4, 45));
      expect(IcsInvite.parse('BEGIN:VCALENDAR\nEND:VCALENDAR'), isNull);
    });
  });

  group('spelling', () {
    test('link targets, URLs and addresses are not checked', () {
      const text = 'Првиет, [сайт](https://kaztbu.edu.kz) и ivan@kaztbu.edu.kz www.exmple.kz';
      final issues = [
        const SpellingIssue(0, 6, ['Привет']),
        SpellingIssue(text.indexOf('kaztbu'), 6, const []),
        SpellingIssue(text.indexOf('ivan'), 4, const []),
        SpellingIssue(text.indexOf('exmple'), 6, const []),
      ];
      expect(filterSpelling(text, issues).map((i) => i.start), [0]);
    });

    testWidgets('underline keeps the formatting and the markers hidden', (tester) async {
      final c = MailMarkupEditingController(text: '**Првиет** мир')..spelling = const [SpellingIssue(2, 6, [])];
      late TextSpan span;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              span = c.buildTextSpan(context: context, style: const TextStyle(), withComposing: false);
              return const SizedBox();
            },
          ),
        ),
      );
      final word = span.children!.whereType<TextSpan>().firstWhere((s) => s.text == 'Првиет');
      expect(word.style!.fontWeight, FontWeight.w700);
      expect(word.style!.decorationStyle, TextDecorationStyle.wavy);
      expect(span.toPlainText(), '**Првиет** мир', reason: 'every character keeps its place');
    });
  });

  group('desktop behaviour', () {
    test('away when locked or idle 10 minutes', () {
      expect(isAwayNow(locked: true, idleSeconds: 0), isTrue);
      expect(isAwayNow(locked: false, idleSeconds: 599), isFalse);
      expect(isAwayNow(locked: false, idleSeconds: 600), isTrue);
    });

    test('mini call window in the bottom right of the work area', () {
      final r = miniCallBounds(const Rect.fromLTWH(0, 0, 1920, 1040));
      expect(r, const Rect.fromLTWH(1920 - 360 - 16, 1040 - 220 - 16, 360, 220));
    });

    test('desktop settings: defaults, round trip, broken values', () {
      const d = DesktopSettings();
      expect((d.mailNotifications, d.globalHotkeys, d.autoAway, d.miniCallWindow, d.spellCheck), (true, true, true, true, true));
      final off = d.copyWith(autoAway: false, spellCheck: false);
      final back = DesktopSettings.fromJson(off.toJson());
      expect((back.autoAway, back.spellCheck, back.mailNotifications), (false, false, true));
      expect(DesktopSettings.fromJson({'auto_away': 'no'}).autoAway, isTrue);
      expect(DesktopSettings.fromJson(null).globalHotkeys, isTrue);
      // Beta updates: off unless chosen.
      expect(d.betaUpdates, isFalse);
      expect(DesktopSettings.fromJson(d.copyWith(betaUpdates: true).toJson()).betaUpdates, isTrue);
    });

    test('new mail: unread and not seen before', () {
      final items = [
        MailListItem.fromJson(Fixtures.message(1)),
        MailListItem.fromJson(Fixtures.message(2, read: true)),
        MailListItem.fromJson(Fixtures.message(3)),
      ];
      expect(newMailToNotify(items, {'m3'}).map((m) => m.id), ['m1']);
    });

    test('mail toast buttons come back with the message', () {
      final r = LocalNotificationHub.normalizeWindowsResponse(
        NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotification,
          payload: LocalNotificationHub.windowsActionArguments(LocalNotificationHub.mailDeleteActionId, '${mailToastPrefix}m9'),
        ),
      );
      expect(r.actionId, LocalNotificationHub.mailDeleteActionId);
      expect(r.payload, 'mail:m9');
    });
  });
}
