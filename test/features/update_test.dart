import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/auth/auth_session.dart';
import 'package:xatbox_mobile/core/localization/localization.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/theme/app_theme.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/update/data/apk_downloader.dart';
import 'package:xatbox_mobile/features/update/data/apk_installer.dart';
import 'package:xatbox_mobile/features/update/data/update_models.dart';
import 'package:xatbox_mobile/features/update/presentation/update_controller.dart';
import 'package:xatbox_mobile/features/update/presentation/update_gate.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

const _chatUrl = 'http://chat.local/api/v1';
final _apk = ascii.encode('XATBOX-APK-' * 40);
final _sha = sha256.convert(_apk).toString();

Map<String, dynamic> _latest({
  bool available = true,
  bool mandatory = false,
  int code = 7,
  int min = 0,
  String abi = 'arm64-v8a',
}) => {
  'available': available,
  'mandatory': mandatory,
  'version_name': '0.2.0',
  'version_code': code,
  'min_supported_version_code': min,
  'published_at': '2026-09-15T10:00:00Z',
  'notes': {'ru': 'Новые функции', 'en': 'New features', 'kk': ''},
  'abi': abi,
  'file': {'name': 'XatBox-0.2.0-$code-$abi.apk', 'size': _apk.length, 'sha256': _sha},
  'download_path': '/api/v1/app/android/download/$abi',
};

class FakeInstaller implements ApkInstaller {
  bool allowed = true;
  int settingsOpened = 0;
  final installs = <String>[];

  @override
  Future<bool> canRequestInstalls() async => allowed;

  @override
  Future<void> openInstallSettings() async => settingsOpened++;

  @override
  Future<InstallStart> install(String path) async {
    installs.add(path);
    return InstallStart.started;
  }
}

void main() {
  group('update models', () {
    test('ABI choice and split version codes', () {
      expect(ReleaseAbi.pick(['arm64-v8a', 'armeabi-v7a', 'armeabi']), 'arm64-v8a');
      expect(ReleaseAbi.pick(['x86_64', 'x86']), 'x86_64');
      expect(ReleaseAbi.pick(['mips']), 'universal');
      expect(VersionCodes.normalize(2005), 5);
      expect(VersionCodes.normalize(5), 5);
      expect(VersionCodes.isSplit(1005), isTrue);
      expect(VersionCodes.isSplit(5), isFalse);
    });

    test('release JSON, notes fallback and re-evaluation for the installed build', () {
      final r = AppRelease.fromJson(_latest(code: 7, min: 6));
      expect(r.downloadable, isTrue);
      expect(r.file!.size, _apk.length);
      expect(r.notesFor('en'), 'New features');
      expect(r.notesFor('kk'), 'Новые функции', reason: 'empty Kazakh notes fall back to Russian');
      expect(r.forInstalled(2005).mandatory, isTrue);
      expect(r.forInstalled(2007).available, isFalse);
      expect(r.forInstalled(2007).mandatory, isFalse);
      expect(AppRelease.fromJson({'available': false, 'mandatory': false}).hasRelease, isFalse);
      final roundTrip = AppRelease.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
      expect(roundTrip.file!.sha256, _sha);
      expect(roundTrip.downloadPath, r.downloadPath);
    });
  });

  test('Linux package installer: saved to Downloads under a readable name, then opened', () async {
    final dir = await Directory.systemTemp.createTemp('xatbox_linux');
    addTearDown(() => dir.delete(recursive: true));
    final deb = File('${dir.path}/xatbox-1106-x64-0123abcd.deb')..writeAsBytesSync(_apk);
    final opened = <String>[];
    final installer = LinuxPackageInstaller(
      downloads: () async => Directory('${dir.path}/Downloads'),
      open: (path) async {
        opened.add(path);
        return true;
      },
    );
    expect(await installer.install(deb.path), InstallStart.started);
    expect(opened.single, '${dir.path}/Downloads/XatBox-1106.deb');
    expect(File(opened.single).readAsBytesSync(), _apk);
    expect(linuxPackageName('/tmp/u/other.deb'), 'other.deb');

    final failing = LinuxPackageInstaller(downloads: () async => null, open: (_) async => false);
    expect(await failing.install(deb.path), InstallStart.failed);
    expect(failing.lastPath, deb.path);
  });

  group('UpdateController', () {
    late TestHarness h;
    late FakeInstaller installer;
    late Directory dir;
    var now = DateTime.utc(2026, 9, 15, 10);

    Future<void> create({
      int build = 2005,
      bool android = true,
      bool windows = false,
      bool linux = false,
      List<Override> extra = const [],
    }) async {
      dir = await Directory.systemTemp.createTemp('xatbox_update');
      installer = FakeInstaller();
      now = DateTime.utc(2026, 9, 15, 10);
      h = await TestHarness.create(
        storedToken: Fixtures.token,
        chatBaseUrl: _chatUrl,
        overrides: [
          installedAppProvider.overrideWith(
            (ref) async => InstalledApp(
              versionName: '0.1.0',
              buildNumber: build,
              supportedAbis: windows || linux ? const [] : const ['arm64-v8a', 'armeabi-v7a'],
              isAndroid: android && !windows && !linux,
              isWindows: windows,
              isLinux: linux,
            ),
          ),
          apkInstallerProvider.overrideWithValue(installer),
          apkDownloaderProvider.overrideWith(
            (ref) => ApkDownloader(
              client: ref.watch(chatApiClientProvider),
              directory: () async => Directory('${dir.path}/updates'),
            ),
          ),
          updateClockProvider.overrideWithValue(() => now),
          ...extra,
        ],
      );
    }

    tearDown(() async {
      await h.dispose();
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    void serveApk({List<int>? bytes}) {
      final body = bytes ?? _apk;
      h.chatAdapter.on('GET', '/app/android/download/arm64-v8a', (req) {
        final range = (req.headers['Range'] ?? req.headers['range']) as String?;
        final from = range == null ? 0 : int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
        return FakeResponse(
          range == null ? 200 : 206,
          text: ascii.decode(body.sublist(from)),
          contentType: 'application/vnd.android.package-archive',
        );
      });
    }

    UpdateController controller() => h.container.read(updateControllerProvider.notifier);
    UpdateState state() => h.container.read(updateControllerProvider);

    test('Windows: the installer channel (x64), build numbers as they are, installer started when asked', () async {
      // CI numbers desktop builds 100 + run: past 1000 they must not be read
      // as Android split codes.
      await create(build: 1105, windows: true);
      h.chatAdapter.onJson('GET', '/app/windows/latest', {
        ..._latest(code: 1106, abi: 'x64'),
        'download_path': '/api/v1/app/windows/download/x64',
      });
      h.chatAdapter.on('GET', '/app/windows/download/x64', (_) => FakeResponse(200, text: ascii.decode(_apk)));
      await controller().check();
      expect(h.chatAdapter.of('GET', '/app/windows/latest').single.query, {'abi': 'x64', 'version_code': '1105'});
      expect(h.chatAdapter.of('GET', '/app/android/latest'), isEmpty);
      expect(state().phase, UpdatePhase.available);
      await controller().download();
      // Installing restarts the app: the user picks «now» or «on quit».
      expect(installer.installs, isEmpty);
      expect(state().phase, UpdatePhase.ready);
      controller().installOnQuit();
      expect(state().installOnQuit, isTrue);
      await controller().install();
      expect(installer.installs, hasLength(1));
      expect(state().phase, UpdatePhase.installing);
      expect(AppRelease.fromJson(_latest(code: 1106)).forInstalled(1106, split: false).available, isFalse);
    });

    test('desktop beta channel: asked for when the setting is on, downloaded from beta; never on Android', () async {
      await create(build: 1105, windows: true, extra: [updateBetaChannelProvider.overrideWithValue(true)]);
      h.chatAdapter.onJson('GET', '/app/windows/latest', {
        ..._latest(code: 1107, abi: 'x64'),
        'download_path': '/api/v1/app/windows/download/x64?channel=beta',
        'channel': 'beta',
      });
      h.chatAdapter.on('GET', '/app/windows/download/x64', (_) => FakeResponse(200, text: ascii.decode(_apk)));
      await controller().check();
      expect(
        h.chatAdapter.of('GET', '/app/windows/latest').single.query,
        {'abi': 'x64', 'version_code': '1105', 'channel': 'beta'},
      );
      expect(state().phase, UpdatePhase.available);
      await controller().download();
      expect(state().phase, UpdatePhase.ready);
      expect(h.chatAdapter.of('GET', '/app/windows/download/x64').single.query, {'channel': 'beta'});
      await h.dispose();
      await dir.delete(recursive: true);

      await create(extra: [updateBetaChannelProvider.overrideWithValue(true)]);
      h.chatAdapter.onJson('GET', '/app/android/latest', _latest());
      await controller().check();
      expect(h.chatAdapter.of('GET', '/app/android/latest').single.query, {'abi': 'arm64-v8a', 'version_code': '5'});
    });

    test('desktop rollback: a newer (withdrawn) build takes the older one; no downgrade otherwise', () async {
      await create(build: 1107, windows: true);
      h.chatAdapter.onJson('GET', '/app/windows/latest', {
        ..._latest(code: 1105, abi: 'x64'),
        'download_path': '/api/v1/app/windows/download/x64',
        'rollback': true,
      });
      await controller().check();
      expect(state().phase, UpdatePhase.available);
      expect(state().release!.rollback, isTrue);
      // «Позже» on the withdrawn build 1107 does not hide the rollback.
      await h.container.read(updateStoreProvider).postpone(1107);
      expect(await controller().shouldPrompt(), isTrue);
      await controller().postpone();
      expect(await controller().shouldPrompt(), isFalse);

      // A server that answers «available» for a lower build without the
      // rollback flag is not followed.
      now = now.add(const Duration(hours: 7));
      h.chatAdapter.onJson('GET', '/app/windows/latest', {
        ..._latest(code: 1105, abi: 'x64'),
        'download_path': '/api/v1/app/windows/download/x64',
      });
      await controller().check();
      expect(state().phase, UpdatePhase.upToDate);

      final r = AppRelease.fromJson({..._latest(code: 1105), 'rollback': true});
      expect(r.forInstalled(1107, split: false).available, isTrue);
      expect(r.forInstalled(1105, split: false).available, isFalse);
      expect(r.forInstalled(1104, split: false).available, isTrue);
      final roundTrip = AppRelease.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
      expect(roundTrip.rollback, isTrue);
      expect(AppRelease.fromJson(_latest(code: 1105)).toJson().containsKey('rollback'), isFalse);
    });

    test('Linux: the .deb channel (x64), downloaded and opened in the package installer at once', () async {
      const app = InstalledApp(versionName: '0.2.0', buildNumber: 1105, isLinux: true);
      expect(app.updatable, isTrue);
      expect(app.platform, 'linux');
      expect(app.abi, 'x64');
      expect(app.versionCode, 1105);
      expect(app.isDesktopApp, isTrue);

      await create(build: 1105, linux: true);
      h.chatAdapter.onJson('GET', '/app/linux/latest', {
        ..._latest(code: 1106, abi: 'x64'),
        'download_path': '/api/v1/app/linux/download/x64',
      });
      h.chatAdapter.on('GET', '/app/linux/download/x64', (_) => FakeResponse(200, text: ascii.decode(_apk)));
      await controller().check();
      expect(h.chatAdapter.of('GET', '/app/linux/latest').single.query, {'abi': 'x64', 'version_code': '1105'});
      expect(state().phase, UpdatePhase.available);
      await controller().download();
      // No silent install: the system installer opens the package.
      expect(installer.installs, hasLength(1));
      expect(state().phase, UpdatePhase.installing);
    });

    test('Windows: a mandatory update installs right after the download', () async {
      await create(build: 1105, windows: true);
      h.chatAdapter.onJson('GET', '/app/windows/latest', {
        ..._latest(code: 1106, mandatory: true, abi: 'x64'),
        'download_path': '/api/v1/app/windows/download/x64',
      });
      h.chatAdapter.on('GET', '/app/windows/download/x64', (_) => FakeResponse(200, text: ascii.decode(_apk)));
      await controller().check();
      expect(state().mandatory, isTrue);
      await controller().download();
      expect(installer.installs, hasLength(1));
      expect(state().phase, UpdatePhase.installing);
    });

    test('Windows: an all-users install leaves updates to the administrator', () async {
      expect(
        const InstalledApp(versionName: '0.2.0', buildNumber: 1105, isWindows: true, managedByAdmin: true).updatable,
        isFalse,
      );
      const env = {'ProgramFiles': r'C:\Program Files', 'ProgramFiles(x86)': r'C:\Program Files (x86)'};
      expect(isMachineWideInstall(r'C:\Program Files\XatBox\XatBox.exe', env), isTrue);
      expect(isMachineWideInstall(r'c:/program files (x86)/XatBox/XatBox.exe', env), isTrue);
      expect(isMachineWideInstall(r'C:\Users\a\AppData\Local\Programs\XatBox\XatBox.exe', env), isFalse);
      expect(isMachineWideInstall(r'C:\Program Files Extra\XatBox.exe', env), isFalse);
      expect(isMachineWideInstall(r'D:\XatBox\XatBox.exe', const {}), isFalse);
    });

    test('Windows: the update installer is told it is a per-user install', () {
      // /CURRENTUSER keeps Inno Setup from restarting itself elevated, which
      // is what made Windows ask about the publisher of <installer>.tmp.
      final now = windowsSetupArgs(silent: false, launchAfter: true);
      expect(now, contains('/CURRENTUSER'));
      expect(now, contains('/SILENT'));
      expect(now, contains('/CLOSEAPPLICATIONS'));
      expect(now, isNot(contains('/NOLAUNCH')));

      final onQuit = windowsSetupArgs(silent: true, launchAfter: false);
      expect(onQuit, contains('/VERYSILENT'));
      expect(onQuit, contains('/NOLAUNCH'));
      expect(onQuit, contains('/CURRENTUSER'));

      expect(
        windowsSetupArgs(silent: true, launchAfter: false, perUser: false),
        isNot(contains('/CURRENTUSER')),
        reason: 'a machine-wide install must not be turned into a second per-user copy',
      );
    });

    test('launch check asks the server with the device ABI, then is throttled for 6 h', () async {
      await create();
      h.chatAdapter.onJson('GET', '/app/android/latest', _latest());
      expect(await controller().checkIfDue(), isTrue);
      expect(state().phase, UpdatePhase.available);
      expect(state().release!.versionName, '0.2.0');
      final calls = h.chatAdapter.of('GET', '/app/android/latest');
      expect(calls.single.query, {'abi': 'arm64-v8a', 'version_code': '5'});

      now = now.add(const Duration(hours: 1));
      expect(await controller().checkIfDue(), isFalse);
      expect(h.chatAdapter.of('GET', '/app/android/latest'), hasLength(1));

      now = now.add(const Duration(hours: 6));
      expect(await controller().checkIfDue(), isTrue);
      expect(h.chatAdapter.of('GET', '/app/android/latest'), hasLength(2));
    });

    test('download resumes with Range, verifies SHA-256 and opens the installer', () async {
      await create();
      h.chatAdapter.onJson('GET', '/app/android/latest', _latest());
      serveApk();
      await controller().check();
      final release = state().release!;
      final updates = await Directory('${dir.path}/updates').create(recursive: true);
      await File('${updates.path}/${ApkDownloader.baseName(release)}.apk.part').writeAsBytes(_apk.sublist(0, 100));

      await controller().download();
      final req = h.chatAdapter.of('GET', '/app/android/download/arm64-v8a').single;
      expect(req.headers['Range'] ?? req.headers['range'], 'bytes=100-');
      expect(state().phase, UpdatePhase.installing);
      expect(installer.installs, hasLength(1));
      final file = File(installer.installs.single);
      expect(file.path, endsWith('.apk'));
      expect(await file.readAsBytes(), _apk);

      // A later check finds the verified file and does not download again.
      now = now.add(const Duration(hours: 7));
      await controller().check();
      expect(state().phase, UpdatePhase.ready);
    });

    test('a corrupted download is rejected and removed', () async {
      await create();
      h.chatAdapter.onJson('GET', '/app/android/latest', _latest());
      serveApk(bytes: ascii.encode('X' * _apk.length));
      await controller().check();
      await controller().download();
      expect(state().phase, UpdatePhase.failed);
      expect(state().error, isA<ApkIntegrityException>());
      expect(installer.installs, isEmpty);
      final left = Directory('${dir.path}/updates').listSync();
      expect(left, isEmpty);
    });

    test('without the install permission: guide to settings, continue on resume', () async {
      await create();
      installer.allowed = false;
      h.chatAdapter.onJson('GET', '/app/android/latest', _latest());
      serveApk();
      await controller().check();
      await controller().download();
      expect(state().phase, UpdatePhase.needsPermission);
      expect(installer.installs, isEmpty);

      await controller().openInstallSettings();
      expect(installer.settingsOpened, 1);
      await controller().onResume();
      expect(state().phase, UpdatePhase.needsPermission, reason: 'still not allowed');

      installer.allowed = true;
      await controller().onResume();
      expect(state().phase, UpdatePhase.installing);
      expect(installer.installs, hasLength(1));

      // Installer dismissed: back to «Установить».
      await controller().onResume();
      expect(state().phase, UpdatePhase.ready);
    });

    test('mandatory release; a split install cannot take a universal-only APK', () async {
      await create(build: 2003);
      h.chatAdapter.onJson('GET', '/app/android/latest', _latest(mandatory: true, min: 5, abi: 'universal'));
      await controller().check();
      expect(state().mandatory, isTrue);
      expect(state().incompatible, isTrue);
      expect(await controller().shouldPrompt(), isFalse);
    });

    test('failed check keeps the last known release; unsupported off Android', () async {
      await create();
      h.chatAdapter.onJson('GET', '/app/android/latest', _latest(mandatory: true, min: 6));
      await controller().check();
      h.chatAdapter.onError('GET', '/app/android/latest', 503, 'UNAVAILABLE');
      now = now.add(const Duration(hours: 7));
      await controller().checkIfDue();
      expect(state().phase, UpdatePhase.failed);
      expect(state().mandatory, isTrue);
      await h.dispose();
      await dir.delete(recursive: true);

      await create(android: false);
      await controller().check();
      expect(state().phase, UpdatePhase.unsupported);
      expect(h.chatAdapter.requests, isEmpty);
    });
  });

  group('UpdateGate', () {
    late TestHarness h;
    late Directory dir;

    Future<void> launch(WidgetTester tester, Map<String, dynamic> latest) async {
      dir = await tester.runAsync(() => Directory.systemTemp.createTemp('xatbox_gate')) as Directory;
      h = await tester.runAsync(
        () => TestHarness.create(
          storedToken: Fixtures.token,
          chatBaseUrl: _chatUrl,
          overrides: [
            installedAppProvider.overrideWith(
              (ref) async => const InstalledApp(
                versionName: '0.1.0',
                buildNumber: 5,
                supportedAbis: ['arm64-v8a'],
                isAndroid: true,
              ),
            ),
            apkInstallerProvider.overrideWithValue(FakeInstaller()),
            apkDownloaderProvider.overrideWith(
              (ref) => ApkDownloader(
                client: ref.watch(chatApiClientProvider),
                directory: () async => Directory('${dir.path}/updates'),
              ),
            ),
          ],
        ),
      ) as TestHarness;
      h.stubSignedIn();
      h.adapter.onJson('POST', '/auth/logout', {});
      h.chatAdapter.onJson('GET', '/app/android/latest', latest);
      await tester.runAsync(() => h.session.restore());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalization.delegates,
            supportedLocales: AppLocalization.supportedLocales,
            locale: const Locale('ru'),
            builder: (context, child) => UpdateGate(child: child!),
            home: const Scaffold(body: Center(child: Text('home'))),
          ),
        ),
      );
      await settle(tester);
    }

    tearDown(() async {
      await h.dispose();
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    testWidgets('optional update: sheet on launch, «Позже» postpones the version', (tester) async {
      await launch(tester, _latest());
      expect(find.byKey(const Key('update_sheet')), findsOneWidget);
      expect(find.text('Доступно обновление'), findsOneWidget);
      expect(find.text('Новые функции'), findsOneWidget);
      expect(find.byKey(const Key('mandatory_update')), findsNothing);

      await tester.tap(find.byKey(const Key('update_later')));
      await settle(tester);
      expect(find.byKey(const Key('update_sheet')), findsNothing);
      final postponed = await tester.runAsync(() => h.container.read(updateStoreProvider).postponedCode());
      expect(postponed, 7);
      expect(await tester.runAsync(() => h.container.read(updateControllerProvider.notifier).shouldPrompt()), isFalse);
    });

    testWidgets('mandatory update blocks the app but allows sign-out', (tester) async {
      await launch(tester, _latest(mandatory: true, min: 6));
      expect(find.byKey(const Key('mandatory_update')), findsOneWidget);
      expect(find.text('Нужно обновить XatBox'), findsOneWidget);
      expect(find.byKey(const Key('update_sheet')), findsNothing);
      expect(find.byKey(const Key('update_download')), findsOneWidget);

      final signOut = find.byKey(const Key('mandatory_sign_out'));
      await tester.scrollUntilVisible(
        signOut,
        150,
        scrollable: find.descendant(of: find.byKey(const Key('mandatory_update')), matching: find.byType(Scrollable)).first,
      );
      await tester.tap(signOut);
      await settle(tester);
      expect(h.session.status, AuthStatus.unauthenticated);
      expect(find.byKey(const Key('mandatory_update')), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });
  });
}

/// Pumps frames with real async in between (sembast, files).
Future<void> settle(WidgetTester tester, [int steps = 8]) async {
  for (var i = 0; i < steps; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
