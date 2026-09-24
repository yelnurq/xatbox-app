import 'package:flutter/foundation.dart';

import '../../shared/models/auth_user.dart';
import '../../shared/utils/diagnostic_log.dart';
import '../api/api_exception.dart';
import '../storage/profile_cache.dart';
import 'auth_api.dart';
import 'token_storage.dart';

enum AuthStatus {
  /// Not restored yet (splash).
  unknown,

  /// A token exists but the server could not be reached to verify it and no
  /// cached profile is available. Splash offers a retry.
  unreachable,

  unauthenticated,
  authenticated,
}

/// Why the user is on the login screen (drives the banner there).
enum SignOutReason { none, userLogout, sessionExpired }

/// Single session for Mail / Chat / Calls (ТЗ п.13, п.24.4).
///
/// * Token is kept in memory only as a mirror of [TokenStorage] (secure).
/// * `expire()` is wired to the HTTP layer: any `401 UNAUTHENTICATED` drops the
///   session. There is no refresh; the user signs in again.
/// * Other modules register [addSignOutHook] to wipe their sensitive caches.
///
/// Extending with PIN/biometric lock later: add a `locked` flag on top of
/// [AuthStatus.authenticated]; nothing here needs to change.
class AuthSession extends ChangeNotifier {
  AuthSession({
    required TokenStorage tokenStorage,
    required ProfileCache profileCache,
    required AuthApi Function() apiFactory,
  }) : _tokenStorage = tokenStorage, // ignore: prefer_initializing_formals
       _profileCache = profileCache, // ignore: prefer_initializing_formals
       _apiFactory = apiFactory; // ignore: prefer_initializing_formals

  final TokenStorage _tokenStorage;
  final ProfileCache _profileCache;
  final AuthApi Function() _apiFactory;
  final List<Future<void> Function()> _signOutHooks = [];

  AuthStatus _status = AuthStatus.unknown;
  AuthUser? _user;
  String? _token;
  SignOutReason _signOutReason = SignOutReason.none;
  bool _offlineProfile = false;
  bool _expiring = false;

  AuthStatus get status => _status;
  AuthUser? get user => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  SignOutReason get signOutReason => _signOutReason;

  /// True when the profile came from the local cache because the server was
  /// unreachable at startup.
  bool get offlineProfile => _offlineProfile;

  /// Used by the HTTP client; never exposed to UI or logs.
  String? currentToken() => _token;

  bool hasPermission(String permission) =>
      _user?.hasPermission(permission) ?? false;

  void addSignOutHook(Future<void> Function() hook) => _signOutHooks.add(hook);

  /// Splash logic (ТЗ п.24.3): token in secure storage → `GET /me`.
  Future<void> restore() async {
    final token = await _tokenStorage.read();
    if (token == null) {
      _set(AuthStatus.unauthenticated);
      return;
    }
    _token = token;
    try {
      final me = await _apiFactory().me();
      _user = me;
      _offlineProfile = false;
      await _profileCache.write(me);
      _set(AuthStatus.authenticated);
      DiagnosticLog.info('auth', 'session restored');
    } on ApiException catch (e) {
      if (e.isUnauthenticated) {
        DiagnosticLog.info('auth', 'stored session rejected, signing out');
        await _clearLocal();
        _signOutReason = SignOutReason.sessionExpired;
        _set(AuthStatus.unauthenticated);
      } else {
        // 5xx etc.: keep the token, try the cached profile.
        await _fallbackToCachedProfile(e);
      }
    } on NetworkException catch (e) {
      await _fallbackToCachedProfile(e);
    } on AppException catch (e) {
      await _fallbackToCachedProfile(e);
    }
  }

  Future<void> _fallbackToCachedProfile(Object cause) async {
    final cached = await _profileCache.read();
    if (cached != null) {
      DiagnosticLog.warn(
        'auth',
        'server unreachable, using cached profile',
        error: cause,
      );
      _user = cached;
      _offlineProfile = true;
      _set(AuthStatus.authenticated);
    } else {
      DiagnosticLog.warn(
        'auth',
        'server unreachable, no cached profile',
        error: cause,
      );
      _set(AuthStatus.unreachable);
    }
  }

  /// `POST /auth/login`. Errors propagate as [AppException] for the UI to map.
  Future<void> login({required String email, required String password}) async {
    final result = await _apiFactory().login(
      email: email.trim(),
      password: password,
    );
    await _tokenStorage.write(result.token);
    _token = result.token;
    _user = result.user;
    _offlineProfile = false;
    _signOutReason = SignOutReason.none;
    await _profileCache.write(result.user);
    _set(AuthStatus.authenticated);
    DiagnosticLog.info('auth', 'signed in');
    // The login response omits department/avatar fields; refresh quietly.
    _refreshProfileQuietly();
  }

  /// Reloads `GET /me` (after a profile change such as a new photo).
  Future<void> refreshProfile() => _refreshProfileQuietly();

  Future<void> _refreshProfileQuietly() async {
    try {
      final me = await _apiFactory().me();
      if (!isAuthenticated) return;
      _user = me;
      await _profileCache.write(me);
      notifyListeners();
    } on AppException catch (e) {
      DiagnosticLog.warn('auth', 'profile refresh failed', error: e);
    }
  }

  /// Explicit sign-out: server first (best effort), then local wipe — always.
  Future<void> logout() async {
    if (_token != null) {
      try {
        await _apiFactory().logout();
      } on AppException catch (e) {
        DiagnosticLog.warn(
          'auth',
          'server logout failed, clearing locally anyway',
          error: e,
        );
      }
    }
    await _clearLocal();
    _signOutReason = SignOutReason.userLogout;
    _set(AuthStatus.unauthenticated);
    DiagnosticLog.info('auth', 'signed out');
  }

  /// Called by the HTTP layer on `401 UNAUTHENTICATED` from any endpoint.
  /// Idempotent: concurrent failing requests trigger a single sign-out.
  void expire() {
    if (_expiring || _status != AuthStatus.authenticated) return;
    _expiring = true;
    DiagnosticLog.info('auth', 'session expired (401), signing out');
    _clearLocal().whenComplete(() {
      _expiring = false;
      _signOutReason = SignOutReason.sessionExpired;
      _set(AuthStatus.unauthenticated);
    });
  }

  /// Splash retry when the server was unreachable.
  Future<void> retryRestore() async {
    _set(AuthStatus.unknown);
    await restore();
  }

  /// Splash "sign in again" when the server is unreachable: drop the stored
  /// token without a server call.
  Future<void> discardStoredSession() async {
    await _clearLocal();
    _signOutReason = SignOutReason.none;
    _set(AuthStatus.unauthenticated);
  }

  Future<void> _clearLocal() async {
    _token = null;
    _user = null;
    _offlineProfile = false;
    await _tokenStorage.clear();
    await _profileCache.clear();
    for (final hook in _signOutHooks) {
      try {
        await hook();
      } on Object catch (e) {
        DiagnosticLog.warn('auth', 'sign-out hook failed', error: e);
      }
    }
  }

  void _set(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
