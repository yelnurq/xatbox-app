import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:xatbox_mobile/core/auth/auth_session.dart';
import 'package:xatbox_mobile/core/preferences/app_preferences.dart';
import 'package:xatbox_mobile/core/routing/link_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/core/security/app_lock.dart';
import 'package:xatbox_mobile/core/security/pin_hasher.dart';
import 'package:xatbox_mobile/core/storage/app_database.dart';
import 'package:xatbox_mobile/core/storage/storage_usage.dart';

import '../helpers/test_app.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

PinVault _vault(SecretStore store) => PinVault(
  store,
  iterations: 2,
  derive: (pin, salt, it) async => PinHasher.derive(pin, salt, it),
);

void main() {
  group('AppPreferences', () {
    test('json round trip and defaults for bad values', () {
      const prefs = AppPreferences(
        theme: AppThemePreference.dark,
        languageCode: 'kk',
        lockEnabled: true,
        biometricEnabled: true,
        lockTimeout: Duration(minutes: 5),
        hideInSwitcher: true,
      );
      final back = AppPreferences.fromJson(prefs.toJson());
      expect(back.theme, AppThemePreference.dark);
      expect(back.locale, const Locale('kk'));
      expect(back.lockEnabled, isTrue);
      expect(back.biometricEnabled, isTrue);
      expect(back.lockTimeout, const Duration(minutes: 5));
      expect(back.hideInSwitcher, isTrue);

      final junk = AppPreferences.fromJson({
        'theme': 'neon',
        'language': 'de',
        'lock_timeout_sec': -1,
      });
      expect(junk.theme, AppThemePreference.system);
      expect(junk.languageCode, isNull);
      expect(junk.lockTimeout, const Duration(minutes: 1));
      expect(
        prefs.copyWith(clearLanguage: true).languageCode,
        isNull,
      );
    });

    test('store persists in the local database', () async {
      final db = await AppDatabase.inMemory();
      addTearDown(db.close);
      final store = AppPreferencesStore(db);
      expect((await store.read()).theme, AppThemePreference.system);
      await store.write(const AppPreferences(theme: AppThemePreference.light));
      expect((await store.read()).theme, AppThemePreference.light);
    });
  });

  group('PinHasher', () {
    test('PBKDF2-HMAC-SHA256 test vectors', () {
      final salt = utf8.encode('salt');
      expect(
        _hex(PinHasher.derive('password', salt, 1)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
      expect(
        _hex(PinHasher.derive('password', salt, 2)),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });

    test('constant-time comparison', () {
      expect(PinHasher.constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
      expect(PinHasher.constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
      expect(PinHasher.constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
    });
  });

  group('PinVault', () {
    final t0 = DateTime.utc(2026, 9, 15, 10);

    test('stores only salt and hash, never the PIN', () async {
      final store = InMemorySecretStore();
      await _vault(store).setPin('482913');
      final raw = store.values[PinVault.storageKey]!;
      expect(raw, isNot(contains('482913')));
      expect(await _vault(store).pinLength(), 6);
    });

    test('throttle schedule', () {
      expect(PinVault.throttleFor(4), Duration.zero);
      expect(PinVault.throttleFor(5), const Duration(seconds: 30));
      expect(PinVault.throttleFor(6), const Duration(seconds: 60));
      expect(PinVault.throttleFor(8), const Duration(seconds: 240));
      expect(PinVault.throttleFor(9), const Duration(seconds: 300));
    });

    test('wrong attempts, throttling, reset on success, wipe at the limit', () async {
      final store = InMemorySecretStore();
      final vault = _vault(store);
      await vault.setPin('1234');

      expect((await vault.verify('1234', t0)).result, PinCheckResult.ok);
      for (var i = 1; i <= 4; i++) {
        final c = await vault.verify('0000', t0);
        expect(c.result, PinCheckResult.wrong);
        expect(c.attemptsLeft, PinVault.maxAttempts - i);
      }
      final fifth = await vault.verify('0000', t0);
      expect(fifth.result, PinCheckResult.throttled);
      expect(fifth.retryAt, t0.add(const Duration(seconds: 30)));
      // Even the right PIN waits, and the counter survives a new instance.
      expect(
        (await _vault(store).verify('1234', t0.add(const Duration(seconds: 10))))
            .result,
        PinCheckResult.throttled,
      );
      final later = t0.add(const Duration(seconds: 31));
      expect((await vault.verify('1234', later)).result, PinCheckResult.ok);

      var now = later;
      PinCheck last = const PinCheck(PinCheckResult.ok);
      for (var i = 0; i < PinVault.maxAttempts; i++) {
        now = now.add(const Duration(minutes: 10));
        last = await vault.verify('9999', now);
      }
      expect(last.result, PinCheckResult.exhausted);
      expect(await vault.hasPin(), isFalse);
    });
  });

  group('AppLockController', () {
    late TestHarness h;
    var now = DateTime.utc(2026, 9, 15, 10);
    tearDown(() => h.dispose());

    Future<void> create({bool lockEnabled = true}) async {
      h = await TestHarness.create(
        overrides: [
          initialAppPreferencesProvider.overrideWithValue(
            AppPreferences(lockEnabled: lockEnabled),
          ),
          lockClockProvider.overrideWithValue(() => now),
        ],
      );
      await h.container.read(pinVaultProvider).setPin('1234');
    }

    test('cold start locked; PIN unlocks; background timeout relocks', () async {
      await create();
      final lock = h.container.read(appLockProvider.notifier);
      expect(h.container.read(appLockProvider).locked, isTrue);
      expect((await lock.submit('1111')).result, PinCheckResult.wrong);
      expect(h.container.read(appLockProvider).locked, isTrue);
      await lock.submit('1234');
      expect(h.container.read(appLockProvider).locked, isFalse);

      lock.onBackground();
      now = now.add(const Duration(seconds: 30));
      lock.onForeground();
      expect(h.container.read(appLockProvider).locked, isFalse);

      lock.onBackground();
      now = now.add(const Duration(minutes: 2));
      lock.onForeground();
      expect(h.container.read(appLockProvider).locked, isTrue);
    });

    test('biometrics unlock only when enabled', () async {
      await create();
      final lock = h.container.read(appLockProvider.notifier);
      expect(await lock.unlockWithBiometrics('r'), isFalse);
      expect(h.biometrics.prompts, 0);
      await h.container
          .read(appPreferencesProvider.notifier)
          .update((p) => p.copyWith(biometricEnabled: true));
      expect(await lock.unlockWithBiometrics('r'), isTrue);
      expect(h.container.read(appLockProvider).locked, isFalse);
    });

    test('disable and sign-out reset clear the PIN and settings', () async {
      await create();
      await h.container.read(appLockProvider.notifier).reset();
      expect(h.container.read(appLockProvider).locked, isFalse);
      expect(h.container.read(appPreferencesProvider).lockEnabled, isFalse);
      expect(await h.container.read(pinVaultProvider).hasPin(), isFalse);
      expect(
        (await h.container.read(appPreferencesStoreProvider).read()).lockEnabled,
        isFalse,
      );
    });

    test('running out of attempts signs out', () async {
      await create();
      final lock = h.container.read(appLockProvider.notifier);
      for (var i = 0; i < PinVault.maxAttempts; i++) {
        now = now.add(const Duration(minutes: 10));
        await lock.submit('0000');
      }
      expect(h.session.status, AuthStatus.unauthenticated);
    });
  });

  group('pushTapLocation', () {
    test('maps push payloads to screens', () {
      expect(
        pushTapLocation({'type': 'calendar.invite', 'event_id': 'e1'}),
        Routes.calendarEventPath('e1'),
      );
      expect(
        pushTapLocation({'event_id': 'e2', 'kind': 'updated'}),
        Routes.calendarEventPath('e2'),
      );
      expect(
        pushTapLocation({'type': 'chat.message', 'conversation_id': 'c1'}),
        Routes.chatConversationPath('c1'),
      );
      expect(
        pushTapLocation({'type': 'mail.new', 'message_id': 'm1'}),
        Routes.mailMessagePath('m1'),
      );
      expect(
        pushTapLocation({'type': 'call.incoming', 'call_id': 'x'}),
        Routes.calls,
      );
      expect(
        pushTapLocation({'link': 'xatbox://mail/m2'}),
        Routes.mailMessagePath('m2'),
      );
      expect(pushTapLocation({'link': 'https://evil.example/mail/1'}), isNull);
      expect(pushTapLocation({'type': 'chat.message'}), isNull);
      // A chat message id alone is not a mail message.
      expect(pushTapLocation({'message_id': 'm3'}), isNull);
    });
  });

  group('storage', () {
    test('splitBytes picks the unit', () {
      expect(splitBytes(0), (0.0, SizeUnit.b));
      expect(splitBytes(1536), (1.5, SizeUnit.kb));
      expect(splitBytes(5 * 1024 * 1024), (5.0, SizeUnit.mb));
    });

    test('measures database and files, sweeps stale temp files', () async {
      final root = await Directory.systemTemp.createTemp('xatbox_storage');
      addTearDown(() => root.delete(recursive: true));
      final support = await Directory(p.join(root.path, 'support')).create();
      final temp = await Directory(p.join(root.path, 'tmp')).create();
      await File(
        p.join(support.path, StorageInspector.databaseFile),
      ).writeAsBytes(List.filled(100, 1));
      await Directory(p.join(support.path, 'chat_media')).create();
      await File(
        p.join(support.path, 'chat_media', 'a.jpg'),
      ).writeAsBytes(List.filled(50, 1));
      final old = File(p.join(temp.path, 'old.pdf'))
        ..writeAsBytesSync(List.filled(30, 1));
      old.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 20)));
      File(p.join(temp.path, 'fresh.m4a')).writeAsBytesSync(List.filled(20, 1));

      final inspector = StorageInspector(
        supportDir: () async => support,
        tempDir: () async => temp,
      );
      final usage = await inspector.measure();
      expect(usage.databaseBytes, 100);
      expect(usage.filesBytes, 100);
      expect(usage.totalBytes, 200);

      expect(await inspector.sweepTemporary(const Duration(days: 14)), 1);
      expect(old.existsSync(), isFalse);
      expect((await inspector.measure()).filesBytes, 70);
    });
  });
}
