import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/mail/data/attachment_downloader.dart';
import 'package:xatbox_mobile/features/mail/data/mail_models.dart';
import 'package:xatbox_mobile/features/mail/presentation/desktop_mail_body.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_providers.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Hands out a local file for every attachment, without the network.
class _LocalDownloader implements AttachmentDownloader {
  _LocalDownloader(this.file);
  final File file;
  final requested = <String>[];

  @override
  Future<File> download(MailAttachment attachment, {void Function(int received, int total)? onProgress}) async {
    requested.add(attachment.id);
    return file;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Phones show letters as they were sent: pictures from the internet and
/// the ones attached to the letter (`cid:`), no «Внешние изображения
/// заблокированы».
void main() {
  testWidgets('phone: a letter shows its web and attached pictures', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final dir = Directory.systemTemp.createTempSync('mail_pictures');
    addTearDown(() => dir.deleteSync(recursive: true));
    final logo = File('${dir.path}/logo.png')..writeAsBytesSync(const [0x89, 0x50, 0x4E, 0x47]);
    final downloader = _LocalDownloader(logo);
    final h = await TestHarness.create(
      storedToken: Fixtures.token,
      overrides: [attachmentDownloaderProvider.overrideWithValue(downloader)],
    );
    addTearDown(h.dispose);
    h.stubSignedIn();
    h.adapter.onJson(
      'GET',
      '/mail/messages/m1',
      Fixtures.detail(
        bodyHtml: '<p>Добрый день</p><img src="https://cdn.example/banner.png" alt="banner">'
            '<img src="cid:logo@x" alt="logo">',
        attachments: const [
          {'id': 'a1', 'filename': 'logo.png', 'content_type': 'image/png', 'size_bytes': 4, 'content_id': 'logo@x', 'inline': true},
        ],
      ),
    );
    await tester.pumpWidget(UncontrolledProviderScope(container: h.container, child: const XatBoxApp()));
    await tester.pump(const Duration(milliseconds: 500));
    unawaited(h.container.read(appRouterProvider).push(Routes.mailMessagePath('m1')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(DesktopMailBody), findsOneWidget);
    expect(find.text('Внешние изображения заблокированы'), findsNothing);
    expect(downloader.requested, ['a1']);
    final sources = tester.widgetList<Image>(find.byType(Image)).map((i) => i.image.toString()).join(' ');
    expect(sources, contains('https://cdn.example/banner.png'));
    expect(sources, contains('logo.png'));
    await tester.pump(const Duration(seconds: 5));
  });
}
