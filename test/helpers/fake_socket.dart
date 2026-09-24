import 'dart:async';
import 'dart:convert';

import 'package:xatbox_mobile/core/websocket/realtime_client.dart';

/// In-memory socket transport for tests: the test plays the server.
class FakeSocketConnection implements SocketConnection {
  FakeSocketConnection({this.acceptAuth = true});

  final bool acceptAuth;
  final _incoming = StreamController<dynamic>();
  final List<Map<String, dynamic>> sent = [];
  int? _closeCode;
  bool closed = false;

  @override
  Future<void> get ready async {}

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  int? get closeCode => _closeCode;

  @override
  void add(String data) {
    final frame = (jsonDecode(data) as Map).cast<String, dynamic>();
    sent.add(frame);
    if (frame['type'] == 'auth') {
      if (acceptAuth) {
        serverSend({
          'type': 'auth.ok',
          'user_id': 'me',
          'session_id': 's1',
          'ping_interval_ms': 60000,
        });
      } else {
        serverSend({'type': 'auth.error', 'code': 'UNAUTHENTICATED'});
        serverClose(4401);
      }
    }
  }

  /// Server → client frame.
  void serverSend(Map<String, dynamic> frame) {
    if (!closed) _incoming.add(jsonEncode(frame));
  }

  /// Server closes with a code.
  void serverClose(int code) {
    if (closed) return;
    closed = true;
    _closeCode = code;
    _incoming.close();
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    // Not awaited: a controller without a listener never completes close().
    unawaited(_incoming.close());
  }
}

/// Connector that hands out fake connections and remembers them.
class FakeSocketFactory {
  FakeSocketFactory({this.acceptAuth = true});
  bool acceptAuth;
  final List<FakeSocketConnection> connections = [];

  SocketConnection connect(Uri uri) {
    final c = FakeSocketConnection(acceptAuth: acceptAuth);
    connections.add(c);
    return c;
  }

  FakeSocketConnection get last => connections.last;
}
