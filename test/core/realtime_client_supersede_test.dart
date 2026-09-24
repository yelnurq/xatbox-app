import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/websocket/realtime_client.dart';

import '../helpers/fake_socket.dart';

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('a connect superseded by stop/start attaches one socket and every frame arrives once', () async {
    final sockets = <FakeSocketConnection>[];
    final token = Completer<String?>();
    final client = RealtimeClient(
      url: () => Uri.parse('ws://test/ws'),
      tokenProvider: () => token.future,
      connector: (_) {
        final s = FakeSocketConnection();
        sockets.add(s);
        return s;
      },
    );
    final frames = <Map<String, dynamic>>[];
    final sub = client.frames.listen(frames.add);

    client.start(); // attempt 1 waits for the token
    await client.stop(); // …and is superseded
    client.start(); // attempt 2 waits for the same token
    token.complete('t');
    await _settle();

    expect(sockets, hasLength(1));
    expect(client.isConnected, isTrue);

    sockets.single.serverSend({'type': 'call.incoming', 'call_id': 'c1'});
    await _settle();
    expect(frames.where((f) => f['type'] == 'call.incoming'), hasLength(1));

    await sub.cancel();
    await client.dispose();
  });
}
