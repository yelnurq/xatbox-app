import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:xatbox_mobile/core/api/api_client.dart';
import 'package:xatbox_mobile/core/api/app_env.dart';
import 'package:xatbox_mobile/core/auth/auth_providers.dart';
import 'package:xatbox_mobile/core/auth/auth_session.dart';
import 'package:xatbox_mobile/core/auth/token_storage.dart';
import 'package:xatbox_mobile/core/localization/localization.dart';
import 'package:xatbox_mobile/core/network/network_status.dart';
import 'package:xatbox_mobile/core/routing/link_router.dart';
import 'package:xatbox_mobile/core/security/app_lock.dart';
import 'package:xatbox_mobile/core/security/pin_hasher.dart';
import 'package:xatbox_mobile/core/storage/app_database.dart';
import 'package:xatbox_mobile/core/storage/storage_usage.dart';
import 'package:xatbox_mobile/core/theme/app_theme.dart';
import 'package:xatbox_mobile/core/websocket/realtime_client.dart';
import 'package:xatbox_mobile/features/calls/presentation/calls_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';

import 'fake_http.dart';
import 'fake_socket.dart';
import 'fixtures.dart';

/// Everything a test needs: fake HTTP (mail + chat hosts), fake WebSocket,
/// in-memory DB and token storage, and a [ProviderContainer] wired exactly
/// like `main.dart`.
class TestHarness {
  TestHarness._(
    this.adapter,
    this.chatAdapter,
    this.socketFactory,
    this.db,
    this.tokens,
    this.container,
  );

  final FakeHttpAdapter adapter;
  final FakeHttpAdapter chatAdapter;
  final FakeSocketFactory socketFactory;
  final AppDatabase db;
  final InMemoryTokenStorage tokens;
  final ProviderContainer container;

  AuthSession get session => container.read(authSessionProvider);

  /// [chatBaseUrl] empty = chat disabled (the default for mail-only tests).
  static Future<TestHarness> create({
    String? storedToken,
    String chatBaseUrl = '',
    String callsBaseUrl = '',
    List<Override> overrides = const [],
    FixedNetworkMonitor? network,
  }) async {
    final adapter = FakeHttpAdapter();
    final chatAdapter = FakeHttpAdapter();
    final callsAdapter = FakeHttpAdapter();
    final sockets = FakeSocketFactory();
    final db = await AppDatabase.inMemory();
    final tokens = InMemoryTokenStorage(storedToken);
    // Pass [network] instead of overriding networkMonitorProvider again.
    final monitor = network ?? FixedNetworkMonitor();
    final links = FakeDeepLinkSource();
    final secrets = InMemorySecretStore();
    final biometrics = FakeBiometricAuth();
    // `stage`: no dev fallbacks, so chat is enabled only when a test asks for it.
    final env = AppEnv.fromValues(
      flavorName: 'stage',
      apiBaseUrl: 'http://test.local/api/v1',
      chatBaseUrl: chatBaseUrl,
      callsBaseUrl: callsBaseUrl,
    );
    late final ProviderContainer container;
    container = ProviderContainer(
      overrides: [
        appEnvProvider.overrideWithValue(env),
        appDatabaseProvider.overrideWithValue(db),
        tokenStorageProvider.overrideWithValue(tokens),
        apiClientProvider.overrideWith(
          (ref) => ApiClient(
            baseUrl: env.apiBaseUrl,
            userAgent: 'XatBoxMobile/test',
            adapter: adapter,
            tokenReader: () => ref.read(authSessionProvider).currentToken(),
            onUnauthenticated: () => ref.read(authSessionProvider).expire(),
          ),
        ),
        chatApiClientProvider.overrideWith(
          (ref) => ApiClient(
            baseUrl: env.chatBaseUrl,
            userAgent: 'XatBoxMobile/test',
            adapter: chatAdapter,
            tokenReader: () => ref.read(authSessionProvider).currentToken(),
            onUnauthenticated: () => ref.read(authSessionProvider).expire(),
          ),
        ),
        callsApiClientProvider.overrideWith(
          (ref) => ApiClient(
            baseUrl: env.callsBaseUrl,
            userAgent: 'XatBoxMobile/test',
            adapter: callsAdapter,
            tokenReader: () => ref.read(authSessionProvider).currentToken(),
            onUnauthenticated: () => ref.read(authSessionProvider).expire(),
          ),
        ),
        chatSocketProvider.overrideWith((ref) {
          final client = RealtimeClient(
            url: () => Uri.parse('ws://chat.local/api/v1/ws'),
            tokenProvider: () async =>
                ref.read(authSessionProvider).currentToken(),
            connector: sockets.connect,
            maxBackoff: const Duration(milliseconds: 50),
          );
          ref.onDispose(client.dispose);
          return client;
        }),
        // Platform plugins are absent in tests.
        networkMonitorProvider.overrideWithValue(monitor),
        deepLinkSourceProvider.overrideWithValue(links),
        secretStoreProvider.overrideWithValue(secrets),
        pinVaultProvider.overrideWith(
          (ref) => PinVault(
            ref.watch(secretStoreProvider),
            iterations: 2,
            derive: (pin, salt, iterations) async =>
                PinHasher.derive(pin, salt, iterations),
          ),
        ),
        biometricAuthProvider.overrideWithValue(biometrics),
        storageInspectorProvider.overrideWithValue(FakeStorageInspector()),
        ...overrides,
      ],
    );
    return TestHarness._(adapter, chatAdapter, sockets, db, tokens, container)
      ..callsAdapter = callsAdapter
      ..network = monitor
      ..links = links
      ..secrets = secrets
      ..biometrics = biometrics;
  }

  /// Fake Call Service host.
  late final FakeHttpAdapter callsAdapter;

  /// Connectivity, OS links, secure storage and biometrics fakes.
  late final FixedNetworkMonitor network;
  late final FakeDeepLinkSource links;
  late final InMemorySecretStore secrets;
  late final FakeBiometricAuth biometrics;

  /// Registers the standard happy-path routes for a signed-in user.
  void stubSignedIn({List<Map<String, dynamic>>? messages, int? total}) {
    adapter.onJson('GET', '/me', Fixtures.me());
    adapter.onJson('GET', '/mail/summary', Fixtures.summary());
    adapter.onJson(
      'GET',
      '/mail/messages',
      Fixtures.page(messages ?? Fixtures.messages(2), total: total ?? 2),
    );
  }

  Future<void> dispose() async {
    container.dispose();
    await db.close();
  }
}

class FakeDeepLinkSource implements DeepLinkSource {
  Uri? initialLink;
  final _controller = StreamController<Uri>.broadcast();

  void emit(Uri uri) => _controller.add(uri);

  @override
  Future<Uri?> initial() async => initialLink;

  @override
  Stream<Uri> get links => _controller.stream;
}

class FakeBiometricAuth implements BiometricAuth {
  bool isAvailable = true;
  bool succeed = true;
  int prompts = 0;

  @override
  Future<bool> available() async => isAvailable;

  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return succeed;
  }
}

class FakeStorageInspector extends StorageInspector {
  StorageUsage usage = const StorageUsage(
    databaseBytes: 1024 * 1024,
    filesBytes: 512 * 1024,
  );

  @override
  Future<StorageUsage> measure() async => usage;

  @override
  Future<int> sweepTemporary(Duration maxAge, {DateTime? now}) async => 0;
}

/// Wraps a widget with the app's theme and localizations.
Widget wrapWidget(Widget child, {ProviderContainer? container}) {
  final app = MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalization.delegates,
    supportedLocales: AppLocalization.supportedLocales,
    locale: const Locale('ru'),
    home: child,
  );
  if (container == null) return ProviderScope(child: app);
  return UncontrolledProviderScope(container: container, child: app);
}
