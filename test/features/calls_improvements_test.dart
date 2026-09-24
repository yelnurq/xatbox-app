import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/api/api_client.dart';
import 'package:xatbox_mobile/core/api/api_exception.dart';
import 'package:xatbox_mobile/core/localization/localization.dart';
import 'package:xatbox_mobile/features/calls/data/call_background.dart';
import 'package:xatbox_mobile/features/calls/data/call_models.dart';
import 'package:xatbox_mobile/features/calls/data/call_sounds.dart';
import 'package:xatbox_mobile/features/calls/data/calls_api.dart';
import 'package:xatbox_mobile/features/calls/data/calls_config.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_controller.dart';
import 'package:xatbox_mobile/features/calls/presentation/calls_format.dart';
import 'package:xatbox_mobile/features/calls/presentation/calls_providers.dart';

import '../helpers/call_fakes.dart';
import '../helpers/fake_http.dart';
import '../helpers/test_app.dart';

/// Calls iteration 5: tones driven by call phases, `/calls/config` parsing
/// and caching, offline history, invite errors, background decline request.
void main() {
  Future<void> flush() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('controller', () {
    late FakeHttpAdapter http;
    late FakeCallServer server;
    late FakeCallNative native;
    late FakeCallSounds sounds;
    late List<FakeCallMedia> medias;
    late ProviderContainer container;
    late NotifierProvider<CallController, CallSessionState> provider;
    var ringsInApp = true;
    const self = 'u-self';

    setUp(() {
      http = FakeHttpAdapter();
      server = FakeCallServer(http, selfId: self, selfName: 'Я');
      native = FakeCallNative();
      sounds = FakeCallSounds();
      medias = [];
      ringsInApp = true;
      final api = CallsApi(
        ApiClient(
          baseUrl: 'http://calls.local/api/v1',
          userAgent: 'test',
          adapter: http,
          tokenReader: () => 'tok',
          onUnauthenticated: () {},
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
            socketConnected: () => true,
            sounds: sounds,
            ringInApp: () => ringsInApp,
          ),
        ),
      );
      container = ProviderContainer();
    });
    tearDown(() => container.dispose());

    CallController ctl() => container.read(provider.notifier);
    CallSessionState st() => container.read(provider);

    test('ringback while the outgoing call rings, silence once someone joins', () async {
      await ctl().startCall(calleeIds: ['u-bob'], video: false);
      await flush();
      expect(st().phase, CallPhase.outgoing);
      expect(sounds.playing, CallTone.ringback);
      expect(sounds.events.where((e) => e == 'play:ringback'), hasLength(1), reason: 'not restarted on every state change');

      medias.single.join('u-bob');
      await flush();
      expect(st().phase, CallPhase.active);
      expect(sounds.playing, isNull);
      expect(sounds.events.last, 'stop');
    });

    test('hanging up an outgoing call stops the ringback before any request', () async {
      await ctl().startCall(calleeIds: ['u-bob'], video: false);
      await flush();
      final done = ctl().hangUp();
      expect(sounds.playing, isNull, reason: 'stopped synchronously on tap');
      await done;
      expect(st().endReason, CallEndReasons.cancelled);
      expect(sounds.events.where((e) => e.startsWith('play')), hasLength(1));
    });

    test('incoming rings in the app (Android foreground); accept and decline stop it at once', () async {
      final id = server.addIncoming(callerId: 'u-bob', callerName: 'Болат');
      await ctl().onIncoming(CallInfo.fromJson(server.calls[id]!));
      expect(sounds.playing, CallTone.ringtone);

      final accepting = ctl().accept();
      expect(sounds.playing, isNull, reason: 'stopped before the permission prompt and the request');
      await accepting;
      await flush();
      expect(st().phase, CallPhase.connecting);
      expect(sounds.events.where((e) => e == 'play:ringtone'), hasLength(1));

      await ctl().hangUp();
      ctl().dismiss();
      final second = server.addIncoming(callerId: 'u-bob', callerName: 'Болат');
      await ctl().onIncoming(CallInfo.fromJson(server.calls[second]!));
      expect(sounds.playing, CallTone.ringtone);
      final declining = ctl().decline();
      expect(sounds.playing, isNull);
      await declining;
      expect(st().endReason, CallEndReasons.declined);
    });

    test('incoming with the system UI ringing (iOS / background): no in-app ringtone; background stops it', () async {
      ringsInApp = false;
      final id = server.addIncoming(callerId: 'u-bob', callerName: 'Болат');
      await ctl().onIncoming(CallInfo.fromJson(server.calls[id]!));
      expect(st().phase, CallPhase.incoming);
      expect(sounds.events, isEmpty);

      ringsInApp = true;
      await ctl().onForeground();
      expect(sounds.playing, CallTone.ringtone);
      ringsInApp = false;
      await ctl().onBackground();
      expect(sounds.playing, isNull);
    });

    test('invite: success updates participants; NOT_MODERATOR and TOO_MANY_PARTICIPANTS are mapped', () async {
      final l10n = lookupAppLocalizations(const Locale('ru'));
      await ctl().startCall(calleeIds: ['u-a', 'u-b'], video: false, mode: 'group');
      await flush();
      final id = st().callId!;

      await ctl().invite(['u-c']);
      expect(http.of('POST', '/calls/$id/invite').single.json, {
        'user_ids': ['u-c'],
      });
      expect(st().call!.participant('u-c')?.status, ParticipantStatus.invited);

      server.inviteError = 'NOT_MODERATOR';
      Object? error;
      try {
        await ctl().invite(['u-d']);
      } on ApiException catch (e) {
        error = e;
      }
      expect(error, isA<ApiException>().having((e) => e.code, 'code', 'NOT_MODERATOR'));
      expect(CallsFormat.error(l10n, error!), l10n.callsErrNotModerator);

      server
        ..inviteError = 'TOO_MANY_PARTICIPANTS'
        ..inviteErrorStatus = 400;
      await expectLater(
        ctl().invite(['u-d']),
        throwsA(
          isA<ApiException>().having((e) => CallsFormat.error(l10n, e), 'text', l10n.callsErrTooMany),
        ),
      );
      expect(st().call!.participant('u-d'), isNull);
    });
  });

  group('tones', () {
    test('synthesized WAV: valid PCM header and exact length of the pattern', () {
      final wav = synthesizeWav(ringbackPattern);
      final bytes = ByteData.sublistView(wav);
      String ascii(int at) => String.fromCharCodes(wav.sublist(at, at + 4));
      expect(ascii(0), 'RIFF');
      expect(ascii(8), 'WAVE');
      expect(ascii(36), 'data');
      expect(bytes.getUint16(20, Endian.little), 1, reason: 'PCM');
      expect(bytes.getUint32(24, Endian.little), 16000);
      // 1 s tone + 4 s silence at 16 kHz, 16-bit mono.
      expect(bytes.getUint32(40, Endian.little), 5 * 16000 * 2);
      expect(wav.length, 44 + 5 * 16000 * 2);
      // Tone first, silence after.
      final toneEnergy = List.generate(1000, (i) => bytes.getInt16(44 + 2 * (4000 + i), Endian.little).abs()).reduce((a, b) => a + b);
      final silence = List.generate(1000, (i) => bytes.getInt16(44 + 2 * (32000 + i), Endian.little).abs()).reduce((a, b) => a + b);
      expect(toneEnergy, greaterThan(0));
      expect(silence, 0);
      expect(synthesizeWav(ringtonePattern).length, 44 + 3 * 16000 * 2);
    });
  });

  group('config', () {
    test('parses the contract and falls back on bad values', () {
      final c = CallsConfig.fromJson({'max_video_tiles': 4, 'ring_timeout_sec': 30, 'max_group': 20, 'max_conference': 100});
      expect([c.maxVideoTiles, c.ringTimeoutSec, c.maxGroup, c.maxConference], [4, 30, 20, 100]);
      expect(CallsConfig.fromJson({'max_video_tiles': 16}).maxVideoTiles, 16);
      expect(CallsConfig.fromJson({'max_video_tiles': 3}).maxVideoTiles, 9, reason: 'below 4');
      expect(CallsConfig.fromJson({'max_video_tiles': 17}).maxVideoTiles, 9, reason: 'above 16');
      expect(CallsConfig.fromJson({'max_video_tiles': '6'}).maxVideoTiles, 9, reason: 'mistyped');
      expect(CallsConfig.fromJson({'max_video_tiles': 6.5}).maxVideoTiles, 9, reason: 'not an integer');
      final empty = CallsConfig.fromJson(const {});
      expect([empty.maxVideoTiles, empty.ringTimeoutSec, empty.maxGroup, empty.maxConference], [9, 45, 50, 150]);
      expect(c.limitFor('conference'), 100);
      expect(c.limitFor('group'), 20);
    });

    test('server value is used and cached; the cached value survives a failing server', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final h = await TestHarness.create(chatBaseUrl: 'http://chat.local/api/v1', callsBaseUrl: 'http://calls.local/api/v1');
      addTearDown(h.dispose);
      final server = FakeCallServer(h.callsAdapter, selfId: 'me', selfName: 'Я');

      // Older server without the endpoint: defaults.
      var sub = h.container.listen(callsConfigProvider, (_, _) {});
      await flush();
      expect(sub.read().maxVideoTiles, CallsConfig.defaultMaxVideoTiles);
      sub.close();

      server.config = {'max_video_tiles': 12, 'ring_timeout_sec': 45, 'max_group': 50, 'max_conference': 150};
      await h.container.read(callsConfigProvider.notifier).refresh();
      expect(h.container.read(callsConfigProvider).maxVideoTiles, 12);

      server.config = null; // endpoint fails from now on
      h.container.invalidate(callsConfigProvider);
      sub = h.container.listen(callsConfigProvider, (_, _) {});
      await flush();
      expect(sub.read().maxVideoTiles, 12, reason: 'last value from the cache');
      sub.close();
    });
  });

  group('history cache', () {
    test('offline: cached first page with the error; back online: refreshed from the server', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final h = await TestHarness.create(chatBaseUrl: 'http://chat.local/api/v1', callsBaseUrl: 'http://calls.local/api/v1');
      addTearDown(h.dispose);
      final server = FakeCallServer(h.callsAdapter, selfId: 'me', selfName: 'Я');
      server.calls['c1'] = server.callJson(id: 'c1', callerId: 'u-bob', others: [('u-bob', 'Болат')], status: 'missed', direction: 'incoming', outcome: 'missed');

      var sub = h.container.listen(callsHistoryProvider(false), (_, _) {});
      await flush();
      expect(sub.read().calls.map((c) => c.id), ['c1']);
      expect(sub.read().fromCache, isFalse);
      sub.close();
      await flush();

      h.callsAdapter.onOffline('GET', '/calls');
      sub = h.container.listen(callsHistoryProvider(false), (_, _) {});
      await flush();
      final offline = sub.read();
      expect(offline.calls.map((c) => c.id), ['c1'], reason: 'served from sembast');
      expect(offline.calls.single.outcome, CallOutcome.missed);
      expect(offline.fromCache, isTrue);
      expect(offline.error, isA<NetworkException>());

      // The missed filter has its own page: nothing cached yet.
      final missed = h.container.listen(callsHistoryProvider(true), (_, _) {});
      await flush();
      expect(missed.read().calls, isEmpty);
      expect(missed.read().error, isA<NetworkException>());
      missed.close();

      // Network back (the chat socket reconnects): reloaded without user action.
      server.calls['c2'] = server.callJson(id: 'c2', callerId: 'me', others: [('u-ann', 'Анна')], status: 'ended', direction: 'outgoing', outcome: 'answered');
      h.callsAdapter.on('GET', '/calls', (_) => FakeResponse(200, json: {'calls': server.calls.values.toList(), 'next_cursor': ''}));
      h.container.read(callsReconnectTickProvider.notifier).bump();
      await flush();
      expect(sub.read().calls.map((c) => c.id), ['c1', 'c2']);
      expect(sub.read().fromCache, isFalse);
      expect(sub.read().error, isNull);
      sub.close();

      await h.container.read(callsCacheProvider).clear();
      expect(await h.container.read(callsCacheProvider).history(missedOnly: false), isNull, reason: 'sign-out wipe');
    });
  });

  group('background decline', () {
    late FakeHttpAdapter http;
    late Dio dio;

    setUp(() {
      http = FakeHttpAdapter();
      dio = Dio()..httpClientAdapter = http;
    });

    test('POST /calls/{id}/reject with the bearer token and no body', () async {
      http.on('POST', '/calls/call-9/reject', (_) => const FakeResponse(200, json: {'call': <String, dynamic>{}}));
      final ok = await rejectCallInBackground(
        callId: 'call-9',
        callsBaseUrl: 'https://api.xatbox.kz/calls/api/v1/',
        readToken: () async => 'secret-token',
        dio: dio,
      );
      expect(ok, isTrue);
      final r = http.requests.single;
      expect(r.method, 'POST');
      expect(r.path, '/calls/call-9/reject');
      expect(r.headers['Authorization'], 'Bearer secret-token');
      expect(r.body, isEmpty);
    });

    test('no token (signed out) or no calls URL: nothing is sent', () async {
      expect(
        await rejectCallInBackground(callId: 'call-9', callsBaseUrl: 'http://calls.local/api/v1', readToken: () async => null, dio: dio),
        isFalse,
      );
      expect(
        await rejectCallInBackground(callId: 'call-9', callsBaseUrl: 'http://calls.local/api/v1', readToken: () async => '', dio: dio),
        isFalse,
      );
      expect(
        await rejectCallInBackground(callId: 'call-9', callsBaseUrl: '', readToken: () async => 'tok', dio: dio),
        isFalse,
      );
      expect(
        await rejectCallInBackground(
          callId: 'call-9',
          callsBaseUrl: 'http://calls.local/api/v1',
          readToken: () async => throw StateError('keystore locked'),
          dio: dio,
        ),
        isFalse,
      );
      expect(http.requests, isEmpty);
    });

    test('call already over (409) or offline: false, no throw', () async {
      http.onError('POST', '/calls/call-9/reject', 409, 'CALL_NOT_RINGING');
      expect(
        await rejectCallInBackground(callId: 'call-9', callsBaseUrl: 'http://calls.local/api/v1', readToken: () async => 'tok', dio: dio),
        isFalse,
      );
      http.onOffline('POST', '/calls/call-9/reject');
      expect(
        await rejectCallInBackground(callId: 'call-9', callsBaseUrl: 'http://calls.local/api/v1', readToken: () async => 'tok', dio: dio),
        isFalse,
      );
      unawaited(Future<void>.value());
    });
  });
}
