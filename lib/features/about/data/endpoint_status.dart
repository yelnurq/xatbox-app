import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/app_env.dart';
import '../../../core/auth/auth_providers.dart';

enum ServiceKind { mail, chat, calls }

@immutable
class EndpointStatus {
  const EndpointStatus({
    required this.kind,
    required this.host,
    required this.configured,
    this.reachable = false,
    this.latency,
    this.statusCode,
  });

  final ServiceKind kind;
  final String host;
  final bool configured;
  final bool reachable;
  final Duration? latency;
  final int? statusCode;

  /// Answered, but not healthy (5xx from a health probe).
  bool get degraded => reachable && (statusCode ?? 0) >= 500;
}

/// Reachability + latency of the three servers. No token is sent: the mail
/// probe expects `401` from `GET /me`, the chat and call services answer
/// `/health` next to their `/api/v1`.
class EndpointProber {
  EndpointProber({HttpClientAdapter? adapter, this.timeout = const Duration(seconds: 6)})
    : _adapter = adapter; // ignore: prefer_initializing_formals

  final HttpClientAdapter? _adapter;
  final Duration timeout;

  /// `https://host/prefix/api/v1` → `https://host/prefix/health`.
  static String healthUrl(String apiBaseUrl) {
    final trimmed = apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final root = trimmed.endsWith('/api/v1')
        ? trimmed.substring(0, trimmed.length - '/api/v1'.length)
        : trimmed;
    return '$root/health';
  }

  static String hostOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }

  Future<EndpointStatus> probe(ServiceKind kind, String apiBaseUrl) async {
    if (apiBaseUrl.isEmpty) {
      return EndpointStatus(kind: kind, host: '', configured: false);
    }
    final url = kind == ServiceKind.mail
        ? '${apiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}/me'
        : healthUrl(apiBaseUrl);
    final dio = Dio(
      BaseOptions(
        connectTimeout: timeout,
        receiveTimeout: timeout,
        validateStatus: (_) => true,
        responseType: ResponseType.plain,
      ),
    );
    if (_adapter != null) dio.httpClientAdapter = _adapter;
    final watch = Stopwatch()..start();
    try {
      final res = await dio.get<String>(url);
      watch.stop();
      return EndpointStatus(
        kind: kind,
        host: hostOf(apiBaseUrl),
        configured: true,
        reachable: true,
        latency: watch.elapsed,
        statusCode: res.statusCode,
      );
    } on Object {
      return EndpointStatus(kind: kind, host: hostOf(apiBaseUrl), configured: true);
    } finally {
      dio.close();
    }
  }

  Future<List<EndpointStatus>> probeAll(AppEnv env) => Future.wait([
    probe(ServiceKind.mail, env.apiBaseUrl),
    probe(ServiceKind.chat, env.chatBaseUrl),
    probe(ServiceKind.calls, env.callsBaseUrl),
  ]);
}

final endpointProberProvider = Provider<EndpointProber>((_) => EndpointProber());

final endpointStatusProvider = FutureProvider.autoDispose<List<EndpointStatus>>(
  (ref) => ref.watch(endpointProberProvider).probeAll(ref.watch(appEnvProvider)),
);
