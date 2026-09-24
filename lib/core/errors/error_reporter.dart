import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sembast/sembast.dart';

import '../storage/app_database.dart';
import 'error_scrubber.dart';

/// Device and build facts attached to every report (no user data).
@immutable
class DeviceSnapshot {
  const DeviceSnapshot({
    this.appVersion = '',
    this.appBuild = '',
    this.flavor = '',
    this.platform = '',
    this.osVersion = '',
    this.deviceModel = '',
    this.locale = '',
  });

  final String appVersion;
  final String appBuild;
  final String flavor;
  final String platform;
  final String osVersion;
  final String deviceModel;
  final String locale;
}

/// One captured error; identical errors within the dedupe window share a
/// report with a [count].
class ErrorReport {
  ErrorReport({
    required this.id,
    required this.fingerprint,
    required this.errorType,
    required this.message,
    required this.stack,
    required this.firstSeen,
    required this.lastSeen,
    this.context = '',
    this.route = '',
    this.count = 1,
    this.device = const DeviceSnapshot(),
  });

  final String id;
  final String fingerprint;
  final String errorType;
  final String message;
  final String stack;
  final String context;
  final String route;
  final DateTime firstSeen;
  DateTime lastSeen;
  int count;
  DeviceSnapshot device;

  /// Body item of `POST /client-errors`.
  Map<String, Object?> toPayload() => {
    'platform': device.platform,
    'os_version': device.osVersion,
    'device_model': device.deviceModel,
    'app_version': device.appVersion,
    'app_build': device.appBuild,
    'flavor': device.flavor,
    'locale': device.locale,
    'route': route,
    'error_type': errorType,
    'message': message,
    'stack': stack,
    'context': context,
    'timestamp': lastSeen.toUtc().toIso8601String(),
    'count': count,
  };

  Map<String, Object?> toJson() => {
    'id': id,
    'fingerprint': fingerprint,
    'error_type': errorType,
    'message': message,
    'stack': stack,
    'context': context,
    'route': route,
    'first_seen': firstSeen.toUtc().toIso8601String(),
    'last_seen': lastSeen.toUtc().toIso8601String(),
    'count': count,
    'device': {
      'app_version': device.appVersion,
      'app_build': device.appBuild,
      'flavor': device.flavor,
      'platform': device.platform,
      'os_version': device.osVersion,
      'device_model': device.deviceModel,
      'locale': device.locale,
    },
  };

  static ErrorReport? fromJson(Object? raw) {
    if (raw is! Map) return null;
    String s(Object? v) => v is String ? v : '';
    final d = raw['device'] is Map ? raw['device'] as Map : const {};
    final first = DateTime.tryParse(s(raw['first_seen']));
    final last = DateTime.tryParse(s(raw['last_seen']));
    if (s(raw['id']).isEmpty || first == null || last == null) return null;
    return ErrorReport(
      id: s(raw['id']),
      fingerprint: s(raw['fingerprint']),
      errorType: s(raw['error_type']),
      message: s(raw['message']),
      stack: s(raw['stack']),
      context: s(raw['context']),
      route: s(raw['route']),
      firstSeen: first,
      lastSeen: last,
      count: raw['count'] is int ? raw['count'] as int : 1,
      device: DeviceSnapshot(
        appVersion: s(d['app_version']),
        appBuild: s(d['app_build']),
        flavor: s(d['flavor']),
        platform: s(d['platform']),
        osVersion: s(d['os_version']),
        deviceModel: s(d['device_model']),
        locale: s(d['locale']),
      ),
    );
  }
}

/// Bounded offline queue of reports in the local database: at most
/// [maxReports] (oldest dropped), identical fingerprints within
/// [dedupeWindow] only bump the count. Operations are serialised.
class ErrorReportQueue {
  ErrorReportQueue(
    this._db, {
    this.maxReports = 50,
    this.dedupeWindow = const Duration(minutes: 10),
  });

  final AppDatabase _db;
  final int maxReports;
  final Duration dedupeWindow;

  static final _store = stringMapStoreFactory.store('error_reports');
  static const _key = 'queue';
  Future<void> _tail = Future.value();

  Future<T> _locked<T>(Future<T> Function() op) {
    final result = _tail.then((_) => op());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<List<ErrorReport>> _read() async {
    final raw = await _store.record(_key).get(_db.db);
    final items = raw?['items'];
    if (items is! List) return [];
    return [for (final i in items) ?ErrorReport.fromJson(i)];
  }

  Future<void> _write(List<ErrorReport> items) => _store
      .record(_key)
      .put(_db.db, {
        'items': [for (final r in items) r.toJson()],
      });

  Future<void> add(ErrorReport report) => _locked(() async {
    final items = await _read();
    final same = items.where(
      (r) =>
          r.fingerprint == report.fingerprint &&
          report.lastSeen.difference(r.lastSeen).abs() <= dedupeWindow,
    );
    if (same.isNotEmpty) {
      final r = same.last;
      r
        ..count += report.count
        ..lastSeen = report.lastSeen
        ..device = report.device;
    } else {
      items.add(report);
    }
    while (items.length > maxReports) {
      items.removeAt(0);
    }
    await _write(items);
  });

  Future<List<ErrorReport>> peek(int limit) =>
      _locked(() async => (await _read()).take(limit).toList());

  Future<int> length() => _locked(() async => (await _read()).length);

  /// Removes what was sent. A report whose count grew while sending keeps
  /// the difference.
  Future<void> acknowledge(Map<String, int> sentCounts) => _locked(() async {
    final items = await _read();
    final kept = <ErrorReport>[];
    for (final r in items) {
      final sent = sentCounts[r.id];
      if (sent == null) {
        kept.add(r);
      } else if (r.count > sent) {
        kept.add(r..count -= sent);
      }
    }
    await _write(kept);
  });

  Future<void> clear() => _locked(() => _store.record(_key).delete(_db.db));
}

typedef ErrorBatchSender =
    Future<void> Function(List<Map<String, Object?>> reports);

/// Crash/error reporting to our own Chat Service (`POST /client-errors`).
///
/// Captures come from the global handlers in `main.dart` and from
/// [reportError]. Reports are scrubbed at capture, queued offline and sent
/// in batches of up to 50 when [canSend] (signed in and online).
class ErrorReporter {
  ErrorReporter({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// The process-wide reporter used by [reportError].
  static final instance = ErrorReporter();

  static const batchSize = 50;
  static const _earlyLimit = 20;

  final DateTime Function() _clock;
  ErrorReportQueue? _queue;
  final List<ErrorReport> _early = [];
  bool _capturing = false;
  bool _flushing = false;
  int _seq = 0;

  DeviceSnapshot device = const DeviceSnapshot();

  /// Current route path (ids are removed before it is stored).
  String? Function()? routeName;

  /// The «Отправлять отчёты об ошибках» setting; off = nothing is captured.
  bool enabled = true;

  /// Null = no server to send to (chat module disabled).
  ErrorBatchSender? sender;
  bool Function() canSend = _never;
  static bool _never() => false;

  ErrorReportQueue? get queue => _queue;

  void attach(ErrorReportQueue queue) {
    _queue = queue;
    final early = List.of(_early);
    _early.clear();
    for (final r in early) {
      unawaited(queue.add(r).catchError((Object _) {}));
    }
  }

  /// Captures an error. Never throws; errors inside reporting are dropped.
  void record(Object error, StackTrace? stack, {String? context}) {
    if (!enabled || _capturing || isIgnoredError(error)) return;
    _capturing = true;
    try {
      final now = _clock();
      final type = error.runtimeType.toString();
      final trace = ErrorScrubber.stack(stack);
      String route = '';
      try {
        route = ErrorScrubber.route(routeName?.call());
      } on Object {
        route = '';
      }
      final report = ErrorReport(
        id: '${now.microsecondsSinceEpoch}-${_seq++}',
        fingerprint: ErrorScrubber.fingerprint(type, trace),
        errorType: type,
        message: ErrorScrubber.message(error),
        stack: trace,
        context: ErrorScrubber.context(context),
        route: route,
        firstSeen: now,
        lastSeen: now,
        device: device,
      );
      final queue = _queue;
      if (queue == null) {
        if (_early.length < _earlyLimit) _early.add(report);
      } else {
        unawaited(queue.add(report).catchError((Object _) {}));
      }
    } on Object {
      // Reporting must never become the crash.
    } finally {
      _capturing = false;
    }
  }

  /// Sends queued reports while possible. Returns how many were sent.
  Future<int> flush() async {
    final queue = _queue;
    final send = sender;
    if (queue == null || send == null || !enabled || _flushing) return 0;
    _flushing = true;
    var sent = 0;
    try {
      while (canSend()) {
        final batch = await queue.peek(batchSize);
        if (batch.isEmpty) break;
        await send([for (final r in batch) r.toPayload()]);
        await queue.acknowledge({for (final r in batch) r.id: r.count});
        sent += batch.length;
        if (batch.length < batchSize) break;
      }
    } on Object {
      // Offline, rate limited or server error: keep the queue, retry later.
    } finally {
      _flushing = false;
    }
    return sent;
  }
}

/// Reports a handled-but-unexpected error to our server (scrubbed, queued).
void reportError(Object error, StackTrace? stack, {String? context}) =>
    ErrorReporter.instance.record(error, stack, context: context);

/// Platform camera calls that livekit_client fires without awaiting (tap to
/// focus / expose / pinch zoom on the local preview). Devices whose capturer
/// does not support them answer with a PlatformException; nothing is broken
/// for the user, so these are not crash reports.
const _ignoredPlatformCodes = {
  'setFocusMode',
  'setFocusPoint',
  'setExposureMode',
  'setExposurePoint',
  'setZoom',
};

bool isIgnoredError(Object error) =>
    error is PlatformException && _ignoredPlatformCodes.contains(error.code);
