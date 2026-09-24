import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../shared/utils/diagnostic_log.dart';
import '../auth/auth_providers.dart';
import '../preferences/app_preferences.dart';
import 'pin_hasher.dart';

/// Small key-value secret storage (Keystore / Keychain on devices).
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureSecretStore implements SecretStore {
  const SecureSecretStore();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    // macOS: the login keychain. The data protection keychain needs a
    // keychain-access-groups entitlement, i.e. a build signed with a team id.
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class InMemorySecretStore implements SecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Biometric prompt behind an interface (fake in tests).
abstract class BiometricAuth {
  Future<bool> available();
  Future<bool> authenticate(String reason);
}

class LocalBiometricAuth implements BiometricAuth {
  final _auth = LocalAuthentication();

  @override
  Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } on Object catch (e) {
      DiagnosticLog.warn('lock', 'biometrics unavailable', error: e);
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // Windows Hello refuses biometricOnly (UnsupportedError); it offers
        // the face / fingerprint / Hello PIN the user has set up.
        biometricOnly: !Platform.isWindows,
        persistAcrossBackgrounding: true,
      );
    } on Object catch (e) {
      DiagnosticLog.warn('lock', 'biometric prompt failed', error: e);
      return false;
    }
  }
}

enum PinCheckResult { ok, wrong, throttled, exhausted }

@immutable
class PinCheck {
  const PinCheck(this.result, {this.attemptsLeft = 0, this.retryAt});
  final PinCheckResult result;
  final int attemptsLeft;
  final DateTime? retryAt;
}

typedef PinDerive =
    Future<Uint8List> Function(String pin, List<int> salt, int iterations);

Future<Uint8List> _deriveInIsolate(String pin, List<int> salt, int iterations) =>
    Isolate.run(() => PinHasher.derive(pin, salt, iterations));

/// PIN record in secure storage: salt, derived key, length and the failed
/// attempt counter (persisted, so restarting the app does not reset it).
class PinVault {
  PinVault(
    this._store, {
    this.iterations = PinHasher.defaultIterations,
    PinDerive? derive,
    Random? random,
  }) : _derive = derive ?? _deriveInIsolate,
       _random = random; // ignore: prefer_initializing_formals

  static const storageKey = 'xatbox.app_lock_pin';

  /// Attempts before throttling starts, and the total before sign-out.
  static const freeAttempts = 5;
  static const maxAttempts = 10;

  final SecretStore _store;
  final int iterations;
  final PinDerive _derive;
  final Random? _random;

  Future<Map<String, Object?>?> _record() async {
    final raw = await _store.read(storageKey);
    if (raw == null) return null;
    try {
      return Map<String, Object?>.from(jsonDecode(raw) as Map);
    } on Object {
      return null;
    }
  }

  Future<void> _save(Map<String, Object?> record) =>
      _store.write(storageKey, jsonEncode(record));

  Future<bool> hasPin() async => (await _record()) != null;

  Future<int?> pinLength() async => (await _record())?['length'] as int?;

  Future<void> setPin(String pin) async {
    final salt = PinHasher.newSalt(_random);
    final key = await _derive(pin, salt, iterations);
    await _save({
      'salt': base64Encode(salt),
      'hash': base64Encode(key),
      'iterations': iterations,
      'length': pin.length,
      'failed': 0,
      'retry_at': null,
    });
  }

  static Duration throttleFor(int failed) {
    if (failed < freeAttempts) return Duration.zero;
    final seconds = 30 * pow(2, failed - freeAttempts);
    return Duration(seconds: min(seconds.toInt(), 300));
  }

  Future<DateTime?> retryAt() async {
    final ms = (await _record())?['retry_at'];
    return ms is int ? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true) : null;
  }

  Future<PinCheck> verify(String pin, DateTime now) async {
    final record = await _record();
    if (record == null) return const PinCheck(PinCheckResult.exhausted);
    final retry = record['retry_at'];
    if (retry is int && now.millisecondsSinceEpoch < retry) {
      return PinCheck(
        PinCheckResult.throttled,
        retryAt: DateTime.fromMillisecondsSinceEpoch(retry, isUtc: true),
      );
    }
    final salt = base64Decode(record['salt']! as String);
    final expected = base64Decode(record['hash']! as String);
    final key = await _derive(pin, salt, record['iterations']! as int);
    if (PinHasher.constantTimeEquals(key, expected)) {
      await _save({...record, 'failed': 0, 'retry_at': null});
      return const PinCheck(PinCheckResult.ok);
    }
    final failed = ((record['failed'] as int?) ?? 0) + 1;
    if (failed >= maxAttempts) {
      await clear();
      return const PinCheck(PinCheckResult.exhausted);
    }
    final wait = throttleFor(failed);
    final retryAt = wait == Duration.zero ? null : now.add(wait);
    await _save({
      ...record,
      'failed': failed,
      'retry_at': retryAt?.millisecondsSinceEpoch,
    });
    return PinCheck(
      retryAt == null ? PinCheckResult.wrong : PinCheckResult.throttled,
      attemptsLeft: maxAttempts - failed,
      retryAt: retryAt,
    );
  }

  Future<void> clear() => _store.delete(storageKey);
}

@immutable
class AppLockState {
  const AppLockState({this.locked = false});
  final bool locked;
}

final secretStoreProvider = Provider<SecretStore>(
  (_) => const SecureSecretStore(),
);
final pinVaultProvider = Provider<PinVault>(
  (ref) => PinVault(ref.watch(secretStoreProvider)),
);
final biometricAuthProvider = Provider<BiometricAuth>(
  (_) => LocalBiometricAuth(),
);
final lockClockProvider = Provider<DateTime Function()>(
  (_) => () => DateTime.now().toUtc(),
);
final biometricAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricAuthProvider).available(),
);

/// Local PIN / biometric lock on top of an authenticated session. It never
/// touches the server token: the lock only hides the UI, and running out of
/// attempts signs the user out.
class AppLockController extends Notifier<AppLockState> {
  DateTime? _backgroundAt;

  @override
  AppLockState build() =>
      AppLockState(locked: ref.read(appPreferencesProvider).lockEnabled);

  AppPreferences get _prefs => ref.read(appPreferencesProvider);
  DateTime _now() => ref.read(lockClockProvider)();

  void onBackground() => _backgroundAt ??= _now();

  DateTime? _externalUntil;

  /// The app is about to open a system screen of its own (photo picker,
  /// package installer): coming back from it within [window] does not lock.
  void expectExternalActivity({Duration window = const Duration(minutes: 3)}) =>
      _externalUntil = _now().add(window);

  void onForeground() {
    final at = _backgroundAt;
    _backgroundAt = null;
    final external = _externalUntil;
    _externalUntil = null;
    if (external != null && _now().isBefore(external)) return;
    if (at == null || state.locked || !_prefs.lockEnabled) return;
    if (_now().difference(at) >= _prefs.lockTimeout) {
      state = const AppLockState(locked: true);
    }
  }

  void lockNow() {
    if (_prefs.lockEnabled) state = const AppLockState(locked: true);
  }

  Future<PinCheck> submit(String pin) async {
    final check = await ref.read(pinVaultProvider).verify(pin, _now());
    if (!ref.mounted) return check;
    switch (check.result) {
      case PinCheckResult.ok:
        state = const AppLockState();
      case PinCheckResult.exhausted:
        DiagnosticLog.warn('lock', 'too many wrong PIN attempts, signing out');
        await ref.read(authSessionProvider).logout();
      case PinCheckResult.wrong:
      case PinCheckResult.throttled:
        break;
    }
    return check;
  }

  Future<bool> unlockWithBiometrics(String reason) async {
    if (!_prefs.biometricEnabled) return false;
    final ok = await ref.read(biometricAuthProvider).authenticate(reason);
    if (ok && ref.mounted) state = const AppLockState();
    return ok;
  }

  Future<void> enable(String pin) async {
    await ref.read(pinVaultProvider).setPin(pin);
    // The flag applies at once; persisting it must not hold up the UI.
    unawaited(
      ref
          .read(appPreferencesProvider.notifier)
          .update((p) => p.copyWith(lockEnabled: true)),
    );
  }

  Future<void> disable() async {
    await ref.read(pinVaultProvider).clear();
    await ref
        .read(appPreferencesProvider.notifier)
        .update((p) => p.copyWith(lockEnabled: false, biometricEnabled: false));
    if (ref.mounted) state = const AppLockState();
  }

  /// "Forgot PIN": the only way out is a new sign-in with the password.
  Future<void> forgotPin() => ref.read(authSessionProvider).logout();

  /// Sign-out hook: the PIN belongs to the signed-in user.
  Future<void> reset() async {
    _backgroundAt = null;
    await disable();
  }
}

final appLockProvider = NotifierProvider<AppLockController, AppLockState>(
  AppLockController.new,
);

/// Android `FLAG_SECURE` through the `xatbox/window` channel in MainActivity
/// (no-op elsewhere).
abstract final class WindowSecurity {
  static const _channel = MethodChannel('xatbox/window');

  static Future<void> setSecure(bool secure) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } on Object catch (e) {
      DiagnosticLog.warn('lock', 'FLAG_SECURE not applied', error: e);
    }
  }
}
