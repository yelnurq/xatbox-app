import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/io.dart';

import '../../shared/utils/diagnostic_log.dart';

/// Minimal socket transport so the client can be driven by a fake in tests.
abstract class SocketConnection {
  Future<void> get ready;
  Stream<dynamic> get stream;
  void add(String data);
  Future<void> close();
  int? get closeCode;
}

/// Production transport over `web_socket_channel` (dart:io).
class WebSocketConnection implements SocketConnection {
  WebSocketConnection._(this._channel);
  final IOWebSocketChannel _channel;

  static SocketConnection connect(Uri uri) => WebSocketConnection._(
    IOWebSocketChannel.connect(
      uri,
      connectTimeout: const Duration(seconds: 10),
    ),
  );

  @override
  Future<void> get ready => _channel.ready;
  @override
  Stream<dynamic> get stream => _channel.stream;
  @override
  void add(String data) => _channel.sink.add(data);
  @override
  Future<void> close() => _channel.sink.close();
  @override
  int? get closeCode => _channel.closeCode;
}

/// Connection state of a [RealtimeClient].
enum RealtimeStatus { disconnected, connecting, authenticating, connected }

/// Reconnecting JSON WebSocket with exponential backoff (ТЗ п.13):
/// 1s → 2s → 4s … capped at [maxBackoff] with jitter, never a reconnect
/// flood. The token is sent as the first frame (never in the URL), and the
/// [handshake] callback decides whether the server accepted it.
///
/// Used by the Chat module now; Calls can reuse it for signalling later.
class RealtimeClient {
  RealtimeClient({
    required Uri Function() url,
    required Future<String?> Function() tokenProvider,
    required SocketConnection Function(Uri) connector,
    this.pingInterval = const Duration(seconds: 25),
    this.maxBackoff = const Duration(seconds: 30),
    this.authTimeout = const Duration(seconds: 10),
    Random? random,
  }) : _url = url, // ignore: prefer_initializing_formals
       _tokenProvider = tokenProvider, // ignore: prefer_initializing_formals
       _connector = connector, // ignore: prefer_initializing_formals
       _random = random ?? Random();

  final Uri Function() _url;
  final Future<String?> Function() _tokenProvider;
  final SocketConnection Function(Uri) _connector;
  final Duration pingInterval;
  final Duration maxBackoff;
  final Duration authTimeout;
  final Random _random;

  final _status = StreamController<RealtimeStatus>.broadcast();
  final _frames = StreamController<Map<String, dynamic>>.broadcast();
  final _closes = StreamController<int?>.broadcast();

  SocketConnection? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  Timer? _authTimer;
  int _attempt = 0;
  bool _enabled = false;
  bool _networkAvailable = true;
  RealtimeStatus _current = RealtimeStatus.disconnected;

  /// Close codes after which we must NOT reconnect automatically (the
  /// session is gone; the app has to sign in again).
  static const fatalCloseCodes = {4401, 4408};

  Stream<RealtimeStatus> get status => _status.stream;
  Stream<Map<String, dynamic>> get frames => _frames.stream;

  /// Emits the close code of every dropped connection (null when unknown).
  Stream<int?> get closes => _closes.stream;
  RealtimeStatus get current => _current;
  bool get isConnected => _current == RealtimeStatus.connected;

  /// Starts (and keeps) the connection until [stop].
  void start() {
    if (_enabled) return;
    _enabled = true;
    _attempt = 0;
    _connect();
  }

  /// Stops and closes; no reconnects until [start] again.
  Future<void> stop() async {
    _enabled = false;
    _reconnectTimer?.cancel();
    await _teardown(notify: true);
  }

  /// Forces an immediate reconnect attempt (e.g. network came back).
  void kick() {
    if (!_enabled ||
        _current == RealtimeStatus.connected ||
        _current == RealtimeStatus.connecting ||
        _current == RealtimeStatus.authenticating) {
      return;
    }
    _reconnectTimer?.cancel();
    _attempt = 0;
    _connect();
  }

  /// Connectivity hint from the platform. While `false` no reconnect attempt
  /// is scheduled (no radio wake-up every few seconds with no network at
  /// all); `true` again reconnects at once.
  void setNetworkAvailable(bool available) {
    if (available == _networkAvailable) return;
    _networkAvailable = available;
    if (!available) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      return;
    }
    kick();
  }

  /// True while a reconnect is scheduled (tests).
  bool get reconnectPending => _reconnectTimer?.isActive ?? false;

  /// The last connectivity hint this client was given (tests). Whether the
  /// device is offline and whether this client has been *told* so are two
  /// different moments, and a test that waits for the wrong one is racing
  /// the listener that carries the news.
  bool get networkAvailable => _networkAvailable;

  void send(Map<String, dynamic> frame) {
    final ch = _channel;
    if (ch == null || _current == RealtimeStatus.disconnected) return;
    try {
      ch.add(jsonEncode(frame));
    } on Object catch (e) {
      DiagnosticLog.warn('ws', 'send failed', error: e);
    }
  }

  /// Bumped by every connect attempt and teardown. An attempt that finds a
  /// newer generation after an await was superseded (stop/start, reconnect)
  /// and must not attach its socket: otherwise two sockets feed [frames] and
  /// every event is delivered twice.
  int _generation = 0;

  Future<void> _connect() async {
    if (!_enabled) return;
    // Never two sockets: drop whatever is still attached (its late events are
    // ignored by generation), then start a new generation.
    if (_channel != null || _sub != null) unawaited(_teardown(notify: false));
    final gen = ++_generation;
    _set(RealtimeStatus.connecting);
    final token = await _tokenProvider();
    if (gen != _generation || !_enabled) return;
    if (token == null || token.isEmpty) {
      _set(RealtimeStatus.disconnected);
      return;
    }
    try {
      final ch = _connector(_url());
      await ch.ready;
      if (gen != _generation || !_enabled) {
        unawaited(ch.close().catchError((Object _) {}));
        return;
      }
      _channel = ch;
      _set(RealtimeStatus.authenticating);
      _sub = ch.stream.listen(
        (dynamic data) {
          if (gen == _generation) _onData(data);
        },
        onError: (Object e) {
          if (gen == _generation) _onDone(error: e);
        },
        onDone: () {
          if (gen == _generation) _onDone();
        },
      );
      ch.add(jsonEncode({'type': 'auth', 'token': token}));
      _authTimer?.cancel();
      _authTimer = Timer(authTimeout, () {
        if (_current == RealtimeStatus.authenticating) {
          DiagnosticLog.warn('ws', 'auth timeout');
          _onDone();
        }
      });
    } on Object catch (e) {
      DiagnosticLog.warn('ws', 'connect failed', error: e);
      // A superseded attempt must not schedule a second reconnect loop.
      if (gen == _generation) {
        // Not "connecting" any more: kick() must be able to retry at once.
        _set(RealtimeStatus.disconnected);
        _scheduleReconnect();
      }
    }
  }

  void _onData(dynamic data) {
    if (data is! String) return;
    Map<String, dynamic> frame;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map) return;
      frame = decoded.cast<String, dynamic>();
    } on FormatException {
      return;
    }
    switch (frame['type']) {
      case 'auth.ok':
        _authTimer?.cancel();
        _attempt = 0;
        _set(RealtimeStatus.connected);
        _startPing(frame);
        DiagnosticLog.info('ws', 'connected');
      case 'auth.error':
        _authTimer?.cancel();
        DiagnosticLog.warn('ws', 'auth rejected: ${frame['code']}');
      case 'pong':
        break;
    }
    _frames.add(frame);
  }

  void _startPing(Map<String, dynamic> authOk) {
    _pingTimer?.cancel();
    var interval = pingInterval;
    final serverMs = authOk['ping_interval_ms'];
    if (serverMs is num && serverMs > 1000) {
      interval = Duration(milliseconds: serverMs.toInt());
    }
    _pingTimer = Timer.periodic(interval, (_) => send({'type': 'ping'}));
  }

  void _onDone({Object? error}) {
    final code = _channel?.closeCode;
    if (error != null) DiagnosticLog.warn('ws', 'socket error', error: error);
    _teardown(notify: true);
    _closes.add(code);
    if (code != null && fatalCloseCodes.contains(code)) {
      DiagnosticLog.info(
        'ws',
        'closed with fatal code $code, not reconnecting',
      );
      _enabled = false;
      return;
    }
    _scheduleReconnect();
  }

  Future<void> _teardown({required bool notify}) async {
    _generation++;
    _pingTimer?.cancel();
    _authTimer?.cancel();
    // Detach synchronously: a reconnect that starts while this teardown is
    // still awaiting must never have its new socket closed here.
    final sub = _sub;
    final ch = _channel;
    _sub = null;
    _channel = null;
    if (notify) _set(RealtimeStatus.disconnected);
    await sub?.cancel();
    if (ch != null) {
      try {
        await ch.close();
      } on Object {
        // already closed
      }
    }
  }

  void _scheduleReconnect() {
    if (!_enabled) return;
    _reconnectTimer?.cancel();
    if (!_networkAvailable) {
      _reconnectTimer = null;
      DiagnosticLog.info('ws', 'no network: waiting for connectivity');
      return;
    }
    final delay = backoffFor(_attempt, maxBackoff, _random);
    _attempt++;
    DiagnosticLog.info(
      'ws',
      'reconnect in ${delay.inMilliseconds}ms (attempt $_attempt)',
    );
    _reconnectTimer = Timer(delay, _connect);
  }

  /// Exponential backoff with full jitter: base 1s, doubled per attempt,
  /// capped at [max]. Pure, unit-tested.
  static Duration backoffFor(int attempt, Duration cap, Random random) {
    final capped = min(cap.inMilliseconds, 1000 * (1 << min(attempt, 10)));
    final jitter = random.nextInt(max(1, capped ~/ 2));
    return Duration(milliseconds: capped ~/ 2 + jitter);
  }

  void _set(RealtimeStatus s) {
    if (_current == s) return;
    _current = s;
    _status.add(s);
  }

  Future<void> dispose() async {
    await stop();
    await _status.close();
    await _frames.close();
    await _closes.close();
  }
}
