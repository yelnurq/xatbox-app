import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/errors/error_reporting_providers.dart';
import '../../../core/errors/error_scrubber.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../chat/presentation/chat_providers.dart';

enum FeedbackCategory { bug, idea, question, other }

/// Diagnostics attached to a problem report: build and device facts, ids of
/// the latest queued crash reports and the tail of the (already redacted)
/// diagnostics log. No message texts, tokens or e-mails.
@immutable
class FeedbackDiagnostics {
  const FeedbackDiagnostics({
    required this.device,
    this.route = '',
    this.errorReportIds = const [],
    this.log = '',
  });

  final DeviceSnapshot device;
  final String route;
  final List<String> errorReportIds;
  final String log;

  static const maxLogBytes = 8000;
  static const maxReports = 20;

  Map<String, Object?> toPayload() => {
    'app_version': device.appVersion,
    'app_build': device.appBuild,
    'platform': device.platform,
    'os_version': device.osVersion,
    'device_model': device.deviceModel,
    'locale': device.locale,
    'route': route,
    'error_report_ids': errorReportIds,
    'diagnostics': log,
  };

  /// The newest log lines that fit into [maxLogBytes].
  static String tail(List<DiagnosticRecord> records) {
    final lines = <String>[];
    var bytes = 0;
    for (final r in records.reversed) {
      final line = ErrorScrubber.scrub(
        '${r.time.toUtc().toIso8601String()} ${r.level.name} ${r.area}: '
        '${r.message}${r.error == null ? '' : ' (${r.error})'}',
      );
      bytes += utf8.encode(line).length + 1;
      if (bytes > maxLogBytes) break;
      lines.add(line);
    }
    return lines.reversed.join('\n');
  }
}

@immutable
class FeedbackScreenshot {
  const FeedbackScreenshot(this.bytes, {this.filename = 'screenshot.png'});
  final Uint8List bytes;
  final String filename;
}

/// `POST /feedback` of the Chat Service (multipart: `payload` JSON +
/// optional `screenshot`).
class FeedbackApi {
  FeedbackApi(this._client);
  final ApiClient _client;

  Future<String> send({
    required FeedbackCategory category,
    required String description,
    FeedbackDiagnostics? diagnostics,
    FeedbackScreenshot? screenshot,
  }) async {
    final payload = {
      'category': category.name,
      'description': description.trim(),
      ...?diagnostics?.toPayload(),
    };
    final form = FormData();
    form.fields.add(MapEntry('payload', jsonEncode(payload)));
    if (screenshot != null) {
      final png = screenshot.filename.toLowerCase().endsWith('.png');
      form.files.add(
        MapEntry(
          'screenshot',
          MultipartFile.fromBytes(
            screenshot.bytes,
            filename: screenshot.filename,
            contentType: DioMediaType('image', png ? 'png' : 'jpeg'),
          ),
        ),
      );
    }
    final res = await _client.send(
      () => _client.dio.post<dynamic>('/feedback', data: form),
      expectedStatuses: const {200, 201},
    );
    final json = ApiClient.asJsonObject(res.data, '/feedback', allowEmpty: true);
    return (json['id'] as String?) ?? '';
  }
}

final feedbackApiProvider = Provider<FeedbackApi>(
  (ref) => FeedbackApi(ref.watch(chatApiClientProvider)),
);

/// Collects [FeedbackDiagnostics] for the current moment.
final feedbackDiagnosticsProvider = FutureProvider.autoDispose<FeedbackDiagnostics>((ref) async {
  final reporter = ref.watch(errorReporterProvider);
  var ids = const <String>[];
  try {
    final queued = await ref
        .watch(errorReportQueueProvider)
        .peek(FeedbackDiagnostics.maxReports);
    ids = [for (final r in queued) r.fingerprint.isEmpty ? r.id : '${r.id}:${r.fingerprint.substring(0, r.fingerprint.length.clamp(0, 12))}'];
  } on Object catch (e) {
    DiagnosticLog.warn('feedback', 'error reports unavailable', error: e);
  }
  String route = '';
  try {
    route = ErrorScrubber.scrub(reporter.routeName?.call() ?? '');
  } on Object {
    route = '';
  }
  return FeedbackDiagnostics(
    device: reporter.device,
    route: route,
    errorReportIds: ids,
    log: FeedbackDiagnostics.tail(DiagnosticLog.recent),
  );
});
