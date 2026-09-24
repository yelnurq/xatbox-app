import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/lifecycle/app_visibility.dart';
import 'package:xatbox_mobile/core/lifecycle/background_connection.dart';
import 'package:xatbox_mobile/core/network/network_status.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Grace period under the test's control. `null` = «always stay connected».
class _TestGrace extends Notifier<Duration?> {
  @override
  Duration? build() => null;
  void set(Duration? v) => state = v;
}

final _testGraceProvider = NotifierProvider<_TestGrace, Duration?>(_TestGrace.new);

/// The real chat socket wired to the background policy (fake visibility):
/// disconnect once the grace period is over, no reconnects while hidden,
/// immediate reconnect on return, no reconnect loop without network.
///
/// No assertion depends on wall-clock timing: "still connected while hidden"
/// is checked with an unlimited grace, and expiry is triggered by switching
/// the grace to zero (the same reevaluate path a settings change takes).
/// Waits are condition-based with a generous cap, so CPU load in the full
/// suite cannot make them flaky. Grace defaults are covered in
/// test/core/background_battery_test.dart.
void main() {
  late TestHarness h;
  late FakeAppVisibility visibility;
  var signedIn = false;

  Future<void> until(bool Function() cond) async {
    for (var i = 0; i < 1500 && !cond(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(cond(), isTrue);
  }

  /// Lets queued timers and microtasks run (no timing assumption: used only
  /// before asserting that something did NOT happen, after the triggering
  /// state is already observable).
  Future<void> drain() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> signIn() async {
    signedIn = true;
    visibility = FakeAppVisibility();
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
      overrides: [
        appVisibilityProvider.overrideWithValue(visibility),
        backgroundGraceProvider.overrideWith((ref) => ref.watch(_testGraceProvider)),
      ],
    );
    h.adapter.onJson('GET', '/me', Fixtures.me());
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats(const []));
    await h.session.restore();
    // Like XatBoxApp's ref.watch: a provider without listeners is paused in
    // Riverpod 3, and so would be its network listener.
    final lifecycle = h.container.listen(chatLifecycleProvider, (_, _) {});
    addTearDown(lifecycle.close);
    await until(() => h.container.read(chatSocketProvider).isConnected);
  }

  void setGrace(Duration? grace) => h.container.read(_testGraceProvider.notifier).set(grace);

  tearDown(() async {
    if (!signedIn) return;
    signedIn = false;
    await h.container.read(chatRepositoryProvider).stop();
    await h.dispose();
  });

  test('hidden past the grace period: socket closes, stays closed, reconnects on return', () async {
    await signIn();
    final socket = h.container.read(chatSocketProvider);
    final policy = h.container.read(chatBackgroundPolicyProvider);
    expect(h.socketFactory.connections, hasLength(1));

    visibility.set(foreground: false);
    await drain();
    expect(socket.isConnected, isTrue, reason: 'unlimited grace: still connected');
    expect(policy.suspended, isFalse);

    setGrace(Duration.zero); // grace over
    await until(() => policy.suspended && !socket.isConnected);
    expect(h.socketFactory.last.closed, isTrue);

    await drain();
    expect(h.socketFactory.connections, hasLength(1), reason: 'no reconnects while hidden');
    expect(socket.reconnectPending, isFalse);

    visibility.set(foreground: true);
    await until(() => socket.isConnected);
    expect(policy.suspended, isFalse);
    expect(h.socketFactory.connections, hasLength(2));
  });

  test('a short trip to the background keeps the same socket', () async {
    await signIn();
    setGrace(const Duration(hours: 1));
    final socket = h.container.read(chatSocketProvider);
    final policy = h.container.read(chatBackgroundPolicyProvider);

    visibility.set(foreground: false);
    await drain();
    expect(policy.graceRunning, isTrue);
    visibility.set(foreground: true);
    await drain();

    expect(policy.graceRunning, isFalse, reason: 'return cancels the grace timer');
    expect(policy.suspended, isFalse);
    expect(socket.isConnected, isTrue);
    expect(h.socketFactory.connections, hasLength(1));
  });

  test('no network: a dropped socket waits instead of retrying; network back = reconnect', () async {
    await signIn();
    final socket = h.container.read(chatSocketProvider);

    h.network.set(NetworkKind.none);
    // Not `isOnlineProvider`: that only says the provider knows. The socket
    // is told by a listener a turn later, and closing the connection in
    // between is a race the full suite does lose under load.
    await until(() => !socket.networkAvailable);
    h.socketFactory.last.serverClose(1006);
    await until(() => !socket.isConnected);
    await drain();
    // Offline: no reconnect is even scheduled (with network the 50 ms harness
    // backoff would be pending right now).
    expect(socket.reconnectPending, isFalse);
    expect(h.socketFactory.connections, hasLength(1));

    h.network.set(NetworkKind.wifi);
    await until(() => socket.isConnected);
    expect(h.socketFactory.connections, hasLength(2));
  });

  test('push registration drives the default grace', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(backgroundGraceProvider), const Duration(minutes: 15));
    c.read(pushRegisteredProvider.notifier).set(true);
    expect(c.read(backgroundGraceProvider), const Duration(minutes: 1));
  });
}
