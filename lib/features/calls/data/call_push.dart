import 'dart:io';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../../../core/localization/localization.dart';
import '../../chat/data/chat_push.dart';
import '../../chat/data/push_crypto.dart';
import '../../chat/data/push_notifications.dart';
import 'call_native.dart';

/// Localized texts without a BuildContext (background isolate, providers).
NativeCallTexts systemCallTexts() {
  final code = Platform.localeName.split(RegExp('[_-]')).first;
  final supported = AppLocalization.supportedLocales.map((l) => l.languageCode);
  final l10n = lookupAppLocalizations(Locale(supported.contains(code) ? code : 'ru'));
  return NativeCallTexts(
    appName: l10n.appTitle,
    accept: l10n.callsAccept,
    decline: l10n.callsDecline,
    incomingChannel: l10n.callsIncomingChannel,
    missedChannel: l10n.callsMissedChannel,
  );
}

/// Push data of a call signal (docs/CALLS-API.md §4): FCM `data` on
/// Android; on iOS the VoIP payload is handled natively in AppDelegate.
bool isCallPush(Map<String, dynamic> data) =>
    (data['type'] as String?)?.startsWith('call.') ?? false;

/// FCM background handler (app in background or killed). Android wakes the
/// app for high-priority data messages; the incoming call is shown with the
/// system UI straight away, the actual state is loaded after the app opens.
///
/// Encrypted pushes (`v=1`) are decrypted with this install's key first;
/// their chat / calendar / missed-call notifications are rendered locally,
/// because the message carries no `notification` block.
@pragma('vm:entry-point')
Future<void> xatboxBackgroundPush(RemoteMessage message) async {
  await ensureFirebaseInitialized(firebaseOptionsFromDefines());
  final encrypted = isEncryptedPush(message.data);
  final data = await resolvePushData(message.data);
  if (data == null) return;
  await handleCallPushData(data);
  // Unencrypted alerts are shown by the system itself.
  if (encrypted) await showPushNotification(data);
}

/// Shows / ends the system call UI for a (decrypted) call push.
Future<void> handleCallPushData(Map<String, dynamic> data) async {
  if (!isCallPush(data)) return;
  final callId = data['call_id'] as String?;
  if (callId == null || callId.isEmpty) return;
  switch (data['type']) {
    case 'call.incoming':
      final deadline = DateTime.tryParse((data['ring_deadline'] as String?) ?? '');
      final ringFor = deadline == null
          ? const Duration(seconds: 45)
          : deadline.difference(DateTime.now().toUtc());
      if (ringFor <= Duration.zero) return; // expired: never open a dead call
      await FlutterCallkitIncoming.showCallkitIncoming(
        incomingCallParams(
          callId: callId,
          callerName: (data['caller_name'] as String?) ?? '',
          video: data['call_type'] == 'video',
          ringFor: ringFor,
          texts: systemCallTexts(),
        ),
      );
    case 'call.cancelled':
    case 'call.missed':
      await FlutterCallkitIncoming.endCall(callId);
  }
}
