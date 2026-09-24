import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/utils/diagnostic_log.dart';

/// Radio-level network state (ТЗ п.24.17). It only says whether a network
/// interface is up, not that the server is reachable: requests still handle
/// their own errors.
enum NetworkKind {
  none,
  wifi,
  mobile,
  other;

  bool get online => this != none;
}

/// Platform connectivity behind an interface (fake in tests).
abstract class NetworkMonitor {
  Future<NetworkKind> current();
  Stream<NetworkKind> get changes;
}

class PluginNetworkMonitor implements NetworkMonitor {
  final _connectivity = Connectivity();

  static NetworkKind _map(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return NetworkKind.wifi;
    }
    if (results.contains(ConnectivityResult.mobile)) return NetworkKind.mobile;
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return NetworkKind.none;
    }
    return NetworkKind.other;
  }

  @override
  Future<NetworkKind> current() async {
    try {
      return _map(await _connectivity.checkConnectivity());
    } on Object catch (e) {
      // No plugin (tests, unsupported platform): assume online.
      DiagnosticLog.warn('network', 'connectivity check failed', error: e);
      return NetworkKind.other;
    }
  }

  @override
  Stream<NetworkKind> get changes => _connectivity.onConnectivityChanged
      .map(_map)
      .handleError(
        (Object e) =>
            DiagnosticLog.warn('network', 'connectivity stream failed', error: e),
      );
}

final networkMonitorProvider = Provider<NetworkMonitor>(
  (_) => PluginNetworkMonitor(),
);

/// Current network kind; starts with a check, then follows changes.
final networkStatusProvider = StreamProvider<NetworkKind>((ref) async* {
  final monitor = ref.watch(networkMonitorProvider);
  yield await monitor.current();
  yield* monitor.changes;
});

/// `true` unless the device reports no network at all.
final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(networkStatusProvider).value?.online ?? true,
);

/// Fake monitor for tests.
class FixedNetworkMonitor implements NetworkMonitor {
  FixedNetworkMonitor([this.kind = NetworkKind.wifi]);
  NetworkKind kind;
  final _controller = StreamController<NetworkKind>.broadcast();

  void set(NetworkKind k) {
    kind = k;
    _controller.add(k);
  }

  @override
  Future<NetworkKind> current() async => kind;

  @override
  Stream<NetworkKind> get changes => _controller.stream;
}
