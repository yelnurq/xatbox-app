import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/auth_user.dart';
import '../api/api_client.dart';
import '../api/app_env.dart';
import '../storage/app_database.dart';
import '../storage/cache_policy.dart';
import '../storage/profile_cache.dart';
import 'auth_api.dart';
import 'auth_session.dart';
import 'token_storage.dart';

/// Dependencies created at bootstrap (`main.dart`) and injected through
/// `ProviderScope(overrides: ...)`. Tests override the same providers.
final appEnvProvider = Provider<AppEnv>(
  (_) => throw UnimplementedError('override in main'),
);

final appDatabaseProvider = Provider<AppDatabase>(
  (_) => throw UnimplementedError('override in main'),
);

final tokenStorageProvider = Provider<TokenStorage>(
  (_) => SecureTokenStorage(),
);

final profileCacheProvider = Provider<ProfileCache>(
  (ref) => ProfileCache(ref.watch(appDatabaseProvider)),
);

final cacheSettingsStoreProvider = Provider<CacheSettingsStore>(
  (ref) => CacheSettingsStore(ref.watch(appDatabaseProvider)),
);

/// Descriptive User-Agent so the session shows up recognisably in
/// `GET /me/sessions`. Overridden in main with the real version.
final userAgentProvider = Provider<String>((_) => 'XatBoxMobile/dev');

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final env = ref.watch(appEnvProvider);
  // `ref.read` below is deliberate: the client must not be rebuilt when the
  // session changes (that would create a cycle).
  return ApiClient(
    baseUrl: env.apiBaseUrl,
    userAgent: ref.watch(userAgentProvider),
    tokenReader: () => ref.read(authSessionProvider).currentToken(),
    onUnauthenticated: () => ref.read(authSessionProvider).expire(),
  );
});

final Provider<AuthApi> authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

final Provider<AuthSession> authSessionProvider = Provider<AuthSession>((ref) {
  final session = AuthSession(
    tokenStorage: ref.watch(tokenStorageProvider),
    profileCache: ref.watch(profileCacheProvider),
    apiFactory: () => ref.read(authApiProvider),
  );
  ref.onDispose(session.dispose);
  return session;
});

/// Reactive view of the session for widgets.
class AuthState {
  const AuthState({
    required this.status,
    required this.user,
    required this.offlineProfile,
  });
  final AuthStatus status;
  final AuthUser? user;
  final bool offlineProfile;
}

final authStateProvider = Provider<AuthState>((ref) {
  final session = ref.watch(authSessionProvider);
  void listener() => ref.invalidateSelf();
  session.addListener(listener);
  ref.onDispose(() => session.removeListener(listener));
  return AuthState(
    status: session.status,
    user: session.user,
    offlineProfile: session.offlineProfile,
  );
});

final currentUserProvider = Provider<AuthUser?>(
  (ref) => ref.watch(authStateProvider).user,
);

/// `true` when the signed-in user holds [permission] (from `GET /me`).
final hasPermissionProvider = Provider.family<bool, String>(
  (ref, permission) =>
      ref.watch(currentUserProvider)?.hasPermission(permission) ?? false,
);
