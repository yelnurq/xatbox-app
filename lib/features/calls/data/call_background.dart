import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../../../core/api/app_env.dart';
import '../../../core/auth/token_storage.dart';
import '../../../shared/utils/diagnostic_log.dart';

/// `POST {callsBaseUrl}/calls/{id}/reject` without the app running (Android,
/// process killed, «Отклонить» in the full-screen notification), so the
/// caller stops hearing ringback at once instead of after the ring timeout.
///
/// Pure apart from [dio]: the token and base URL are injected. Returns true
/// when the server accepted the rejection. The token is never logged.
Future<bool> rejectCallInBackground({
  required String callId,
  required String callsBaseUrl,
  required Future<String?> Function() readToken,
  required Dio dio,
}) async {
  var base = callsBaseUrl.trim();
  if (callId.isEmpty || base.isEmpty) return false;
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  final String? token;
  try {
    token = await readToken();
  } on Object catch (e) {
    DiagnosticLog.warn('calls', 'background reject: token unavailable (${e.runtimeType})');
    return false;
  }
  if (token == null || token.isEmpty) return false; // signed out: nothing to do
  try {
    final res = await dio.post<dynamic>(
      '$base/calls/${Uri.encodeComponent(callId)}/reject',
      options: Options(
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
        validateStatus: (_) => true,
      ),
    );
    final status = res.statusCode ?? 0;
    if (status == 200) return true;
    // 409 CALL_NOT_RINGING / 404: the call is already over, nothing left to do.
    DiagnosticLog.warn('calls', 'background reject: HTTP $status');
    return false;
  } on DioException catch (e) {
    DiagnosticLog.warn('calls', 'background reject failed: ${e.type.name}');
    return false;
  }
}

/// Top-level handler run by flutter_callkit_incoming in a background isolate
/// when no UI listens to call events (the app process was killed).
@pragma('vm:entry-point')
Future<void> xatboxCallBackgroundEvent(CallEvent event) async {
  if (event is! CallEventActionCallDecline) return;
  DartPluginRegistrant.ensureInitialized();
  final AppEnv env;
  try {
    env = AppEnv.fromDefines();
  } on AppEnvError {
    return;
  }
  await rejectCallInBackground(
    callId: event.callKitParams.id,
    callsBaseUrl: env.callsBaseUrl,
    readToken: SecureTokenStorage().read,
    dio: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'User-Agent': 'XatBoxMobile/background (${Platform.operatingSystem})'},
      ),
    ),
  );
}

/// Registers the background call-event handler. Must be called from `main`
/// (Android only; on iOS CallKit actions reach the app itself).
Future<void> registerCallBackgroundHandlers() async {
  if (!Platform.isAndroid) return;
  try {
    await FlutterCallkitIncoming.onBackgroundMessage(xatboxCallBackgroundEvent);
  } on Object catch (e) {
    DiagnosticLog.warn('calls', 'background call handler registration failed', error: e);
  }
}
