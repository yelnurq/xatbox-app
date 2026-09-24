import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/api/api_client.dart';
import 'package:xatbox_mobile/features/calls/data/call_media.dart';
import 'package:xatbox_mobile/features/calls/data/call_models.dart';
import 'package:xatbox_mobile/features/calls/data/call_native.dart';
import 'package:xatbox_mobile/features/calls/data/calls_api.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_controller.dart';

import '../helpers/call_fakes.dart';
import '../helpers/fake_http.dart';

/// Call controller against a fake Call Service, fake media session and fake
/// system call UI: idempotent start, WS/push de-duplication, accept/decline,
/// server-driven endings, answered elsewhere, reconnects, 401.
void main() {
  late FakeHttpAdapter http;
  late FakeCallServer server;
  late FakeCallNative native;
  late List<FakeCallMedia> medias;
  late ProviderContainer container;
  late NotifierProvider<CallController, CallSessionState> provider;
  late int unauthenticated;
  var socketUp = true;
  const self = 'u-self';

  setUp(() {
    http = FakeHttpAdapter();
    server = FakeCallServer(http, selfId: self, selfName: 'Я');
    native = FakeCallNative();
    medias = [];
    unauthenticated = 0;
    socketUp = true;
    var ids = 0;
    final api = CallsApi(
      ApiClient(
        baseUrl: 'http://calls.local/api/v1',
        userAgent: 'test',
        adapter: http,
        tokenReader: () => 'tok',
        onUnauthenticated: () => unauthenticated++,
      ),
    );
    provider = NotifierProvider<CallController, CallSessionState>(
      () => CallController(
        (_) => CallDeps(
          api: api,
          native: native,
          mediaFactory: () {
            final m = FakeCallMedia();
            medias.add(m);
            return m;
          },
          deviceId: () async => 'device-A',
          selfId: () => self,
          socketConnected: () => socketUp,
          newId: () => 'client-${ids++}',
        ),
      ),
    );
    container = ProviderContainer();
  });
  tearDown(() => container.dispose());

  CallController ctl() => container.read(provider.notifier);
  CallSessionState st() => container.read(provider);

  Future<void> flush() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('double tap "call" creates one call and pre-joins the room once', () async {
    final a = ctl().startCall(calleeIds: ['u-bob'], video: true);
    final b = ctl().startCall(calleeIds: ['u-bob'], video: true);
    await Future.wait([a, b]);
    await flush();
    expect(server.createPosts, 1);
    expect(http.of('POST', '/calls'), hasLength(1));
    expect(st().phase, CallPhase.outgoing);
    expect(native.outgoing, hasLength(1));
    expect(medias.single.connectedWith?.room, startsWith('org:'));
    expect(medias.single.connectedVideo, isTrue);
    expect(native.screenOn, isTrue);
  });

  test('a camera that fails to start leaves the call running with the camera off', () async {
    await ctl().startCall(calleeIds: ['u-bob'], video: false);
    await flush();
    medias.single.cameraError = Exception('TrackCreateException');
    expect(await ctl().setCamera(true), isFalse);
    expect(st().cameraOn, isFalse);
    expect(st().phase, CallPhase.outgoing);
    medias.single.cameraError = null;
    expect(await ctl().setCamera(true), isTrue);
    expect(st().cameraOn, isTrue);
  });

  test('a lost create response is retried with the same client_call_id', () async {
    server.offlineCreates = 1;
    await ctl().startCall(calleeIds: ['u-bob'], video: false);
    final posts = http.of('POST', '/calls');
    expect(posts, hasLength(2));
    expect(posts[0].json['client_call_id'], posts[1].json['client_call_id']);
    expect(st().phase, CallPhase.outgoing);
  });

  test('no network: the call ends with a clear reason, nothing keeps ringing', () async {
    server.offlineCreates = 5;
    await ctl().startCall(calleeIds: ['u-bob'], video: false);
    expect(st().phase, CallPhase.ended);
    expect(st().endReason, CallEndReasons.network);
    expect(st().inCall, isFalse);
    expect(native.outgoing, isEmpty);
  });

  test('microphone denied: explained, no call created', () async {
    native.permission = MediaPermission.permanentlyDenied;
    await ctl().startCall(calleeIds: ['u-bob'], video: false);
    expect(server.createPosts, 0);
    expect(st().endReason, CallEndReasons.permission);
    expect(st().permissionPermanentlyDenied, isTrue);
  });

  test('incoming from the socket and then from a push is shown once and acked with this device', () async {
    final id = server.addIncoming(callerId: 'u-bob', callerName: 'Болат');
    final signal = CallSignal.fromFrame({'type': 'call.incoming', 'call_id': id, 'call': server.calls[id]})!;
    await ctl().onSignal(signal);
    await ctl().onSignal(signal);
    await ctl().onPushSignal({'type': 'call.incoming', 'call_id': id});
    await flush();
    expect(native.shownIncoming, [id]);
    expect(server.ringingDevices, ['device-A']);
    expect(st().phase, CallPhase.incoming);
  });

  test('accept → token → media; the call becomes active when the caller is in the room', () async {
    final id = server.addIncoming(callerId: 'u-bob', callerName: 'Болат', type: 'video');
    await ctl().onIncoming(CallInfo.fromJson(server.calls[id]!));
    await ctl().accept();
    expect(http.of('POST', '/calls/$id/accept').single.json, {'device_id': 'device-A'});
    expect(native.hiddenIncoming, [id], reason: 'answered in the app: the system incoming UI stops ringing');
    expect(native.connectedIds, [id]);
    expect(st().phase, CallPhase.connecting);
    medias.single.join('u-bob', speaking: true);
    await flush();
    expect(st().phase, CallPhase.active);
    expect(st().connectedAt, isNotNull);
    expect(st().participants.where((p) => p.speaking), hasLength(1));

    // Network switch: LiveKit reconnects on its own; the UI follows.
    medias.single.setConnection(MediaConnection.reconnecting);
    await flush();
    expect(st().phase, CallPhase.reconnecting);
    medias.single.setConnection(MediaConnection.connected);
    await flush();
    expect(st().phase, CallPhase.active);

    await ctl().setMic(false);
    expect(medias.single.micOn, isFalse);
    await ctl().hangUp();
    expect(http.of('POST', '/calls/$id/end'), hasLength(1));
    expect(medias.single.disconnected, isTrue);
    expect(st().phase, CallPhase.ended);
  });

  test('declined by the callee: the caller\'s screen ends at once, media released', () async {
    await ctl().startCall(calleeIds: ['u-bob'], video: false);
    await flush();
    final id = st().callId!;
    server.setStatus(id, 'declined');
    await ctl().onSignal(CallSignal.fromFrame({'type': 'call.status_changed', 'call_id': id, 'call': server.calls[id]})!);
    expect(st().phase, CallPhase.ended);
    expect(st().endReason, CallEndReasons.declined);
    expect(native.ended, contains(id));
    expect(medias.single.disconnected, isTrue);
  });

  test('answered on my other device: this device stops ringing without rejecting', () async {
    final id = server.addIncoming(callerId: 'u-bob', callerName: 'Болат');
    await ctl().onIncoming(CallInfo.fromJson(server.calls[id]!));
    await ctl().onSignal(
      CallSignal.fromFrame({
        'type': 'call.status_changed',
        'call_id': id,
        'call': server.calls[id],
        'participant': {'user_id': self, 'status': 'accepted', 'device_id': 'device-B'},
      })!,
    );
    expect(st().endReason, CallEndReasons.answeredElsewhere);
    expect(native.ended, [id]);
    expect(http.of('POST', '/calls/$id/reject'), isEmpty);
  });

  test('ringing with the socket down: the watchdog notices a cancelled call', () async {
    final id = server.addIncoming(callerId: 'u-bob', callerName: 'Болат');
    socketUp = false;
    await ctl().onIncoming(CallInfo.fromJson(server.calls[id]!));
    server.setStatus(id, 'cancelled');
    await ctl().refresh();
    expect(st().endReason, CallEndReasons.cancelled);
    expect(native.ended, contains(id));
  });

  test('cancel while ringing uses /cancel; system-UI decline uses /reject', () async {
    await ctl().startCall(calleeIds: ['u-bob'], video: false);
    await flush();
    final out = st().callId!;
    await ctl().hangUp();
    expect(http.of('POST', '/calls/$out/cancel'), hasLength(1));
    expect(st().endReason, CallEndReasons.cancelled);

    ctl().dismiss();
    final inc = server.addIncoming(callerId: 'u-bob', callerName: 'Болат');
    await ctl().onIncoming(CallInfo.fromJson(server.calls[inc]!));
    native.actionsController.add(NativeCallAction(NativeActionType.decline, inc));
    await ctl().onNativeAction(NativeCallAction(NativeActionType.decline, inc));
    expect(http.of('POST', '/calls/$inc/reject'), isNotEmpty);
    expect(st().endReason, CallEndReasons.declined);
  });

  test('accepted in the system UI while the app was closed: recovered at start', () async {
    final id = server.addIncoming(callerId: 'u-bob', callerName: 'Болат');
    native.accepted.add(id);
    await ctl().recover();
    expect(http.of('POST', '/calls/$id/accept'), hasLength(1));
    expect(medias, hasLength(1));
  });

  test('401 from the Call Service triggers the global sign-out', () async {
    http.onError('POST', '/calls', 401, 'UNAUTHENTICATED');
    await ctl().startCall(calleeIds: ['u-bob'], video: false);
    expect(unauthenticated, 1);
    expect(st().inCall, isFalse);
  });

  test('frames parse; tokens never appear in toString', () {
    final s = CallSignal.fromFrame({'type': 'call.status_changed', 'call_id': 'x', 'participant': {'user_id': 'u', 'status': 'joined'}});
    expect(s!.participantStatus, ParticipantStatus.joined);
    expect(CallSignal.fromFrame({'type': 'message.created'}), isNull);
    expect(LiveKitAccess.fromJson(FakeCallServer.livekit('c')).toString(), isNot(contains('lk-jwt')));
    expect(CallStatus.parse('missed').isTerminal, isTrue);
    unawaited(Future<void>.value());
  });
}
