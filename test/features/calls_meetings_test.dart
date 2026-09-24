import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/deep_links.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_models.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_reminders.dart';
import 'package:xatbox_mobile/features/calendar/domain/calendar_time.dart';
import 'package:xatbox_mobile/features/calendar/presentation/calendar_providers.dart';
import 'package:xatbox_mobile/features/calendar/presentation/event_edit_screen.dart';
import 'package:xatbox_mobile/features/calls/data/call_chat.dart';
import 'package:xatbox_mobile/features/calls/data/call_media.dart';
import 'package:xatbox_mobile/features/calls/data/calls_config.dart';
import 'package:xatbox_mobile/features/calls/data/meetings.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_controller.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_screen.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_transcript_screen.dart';
import 'package:xatbox_mobile/features/calls/presentation/calls_providers.dart';
import 'package:xatbox_mobile/features/calls/presentation/meeting_prejoin_screen.dart';
import 'package:xatbox_mobile/features/calls/presentation/widgets/call_recording.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';

import '../helpers/calendar_fake_server.dart';
import '../helpers/call_fakes.dart';
import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Meetings from the calendar, pre-join, lobby and guests, audio quality and
/// traffic saving, recording transcripts (docs/CALLS-API.md §12–§14).
void main() {
  group('links, models, reminders', () {
    test('deep links: xatbox://meet and the https meeting link open the pre-join screen', () {
      expect(DeepLinks.toRoute(Uri.parse('xatbox://meet/abc-defg-hjk')), '/meet/abc-defg-hjk');
      expect(DeepLinks.toRoute(Uri.parse('https://mail.kaztbu.edu.kz/xatbox/calls/api/v1/meet/abc-defg-hjk')), '/meet/abc-defg-hjk');
      final guest = 'g${'k' * 32}';
      expect(DeepLinks.toRoute(Uri.parse('https://mail.kaztbu.edu.kz/xatbox/calls/api/v1/meet/$guest')), '/meet/$guest');
      expect(DeepLinks.toRoute(Uri.parse('https://mail.kaztbu.edu.kz/xatbox/calls/api/v1/calls')), isNull);
      expect(DeepLinks.toRoute(Uri.parse('https://evil.example/meet/abc-defg-hjk')), isNull);
      expect(DeepLinks.toRoute(Uri.parse('xatbox://meet/not-a-code')), Routes.calls);
    });

    test('meeting links in event text, guest tokens, join window, API models', () {
      const url = 'https://mail.kaztbu.edu.kz/xatbox/calls/api/v1/meet/abc-defg-hjk';
      expect(XatBoxMeetingLinks.meetingCodeIn('Повестка\n\nВидеовстреча XatBox: $url'), 'abc-defg-hjk');
      expect(XatBoxMeetingLinks.meetingCodeIn('xatbox://meet/bcd-efgh-jkm'), 'bcd-efgh-jkm');
      expect(XatBoxMeetingLinks.meetingCodeIn('https://zoom.us/j/123'), isNull);
      expect(XatBoxMeetingLinks.isGuestToken('g${'a' * 32}'), isTrue);
      expect(XatBoxMeetingLinks.isMeetingCode('g${'a' * 32}'), isFalse);

      final cfg = CallsConfig.fromJson(const {'transcription_enabled': true, 'guests_enabled': true, 'meeting_join_early_sec': 300});
      expect([cfg.transcriptionEnabled, cfg.guestsEnabled, cfg.meetingJoinEarlySec], [true, true, 300]);
      expect([const CallsConfig().guestsEnabled, const CallsConfig().meetingJoinEarlySec], [false, 600], reason: 'older servers');
      expect(CallRecordingItem.fromJson(const {'id': 'r', 'transcript_status': 'processing'}).transcriptStatus, 'processing');
      expect(CallRecordingItem.fromJson(const {'id': 'r'}).transcriptStatus, 'none');

      final start = DateTime.utc(2026, 9, 16, 10);
      final join = MeetingJoinResult.fromJson({
        'meeting': FakeCallServer.meetingJson(code: 'abc-defg-hjk', startsAt: start),
        'lobby': {'id': 'l1', 'status': 'waiting'},
      });
      expect([join.joined, join.lobby!.id, join.meeting.opensAt], [false, 'l1', DateTime.utc(2026, 9, 16, 9, 50)]);
      final scheduled = Meeting.fromJson(FakeCallServer.meetingJson(code: 'abc-defg-hjk', startsAt: start, status: 'scheduled'));
      expect(meetingJoinableAt(scheduled, DateTime.utc(2026, 9, 16, 9, 49)), isFalse);
      expect(meetingJoinableAt(scheduled, DateTime.utc(2026, 9, 16, 9, 50)), isTrue);
      expect(meetingJoinableAt(scheduled, DateTime.utc(2026, 9, 16, 12)), isFalse, reason: 'an hour after the end');
      final live = Meeting.fromJson(FakeCallServer.meetingJson(code: 'abc-defg-hjk', startsAt: start, status: 'live'));
      expect(meetingJoinableAt(live, DateTime.utc(2026, 9, 16, 15)), isTrue);

      final t = CallTranscript.fromJson(FakeCallServer.transcriptJson('rec-1', 'c1'));
      expect([t.ready, t.segments.length, t.keyPhrases.single.startSec, t.plainText.contains('\n\n')], [true, 2, 0, true]);
      final spans = highlightMatches('Бюджет и бюджет', 'бюджет', const TextStyle(), Colors.yellow);
      expect(spans.where((s) => s.style?.backgroundColor == Colors.yellow), hasLength(2));

      final audio = CallAudioSettings.fromJson(const CallAudioSettings(noiseSuppression: false, musicMode: true).toJson());
      expect([audio.noiseSuppression, audio.echoCancellation, audio.musicMode], [false, true, true]);
    });

    test('a XatBox meeting gets one reminder 5 minutes before with «Подключиться»', () {
      CalendarZones.ensureInitialized();
      final start = DateTime.utc(2026, 9, 16, 5);
      CalendarOccurrence occ(String id, {String link = ''}) => CalendarOccurrence(
        event: CalendarEvent.fromJson({
          'id': id,
          'title': 'Совет',
          'starts_at': start.toIso8601String(),
          'ends_at': start.add(const Duration(hours: 1)).toIso8601String(),
          'meeting_link': link,
          'reminder_minutes': 15,
        }),
        start: start,
        end: start.add(const Duration(hours: 1)),
      );
      final plan = ReminderPlanner.plan(
        occurrences: [occ('e1', link: 'https://mail.kaztbu.edu.kz/xatbox/calls/api/v1/meet/abc-defg-hjk'), occ('e2')],
        localReminders: const {'e1': [5, 15], 'e2': [5]},
        now: DateTime.utc(2026, 9, 15, 12),
        device: CalendarZones.location('Asia/Almaty'),
        describe: (_) => 'body',
        meetingCodeOf: (e) => XatBoxMeetingLinks.meetingCodeIn('${e.meetingLink}\n${e.description}'),
        meetingBody: 'Через 5 минут',
        joinLabel: 'Подключиться',
      );
      final meeting = plan.where((r) => r.payload.startsWith(ReminderPlanner.meetingPayloadPrefix)).toList();
      expect(meeting, hasLength(1));
      expect([meeting.single.payload, meeting.single.actionLabel, meeting.single.body], ['meet:abc-defg-hjk', 'Подключиться', 'Через 5 минут']);
      expect(meeting.single.fireAt.isAtSameMomentAs(start.subtract(const Duration(minutes: 5))), isTrue);
      expect(
        plan.where((r) => r.payload.startsWith('e1|')).map((r) => r.fireAt),
        [start.subtract(const Duration(minutes: 15))],
        reason: 'no second 5-minute reminder for a meeting',
      );
      expect(plan.where((r) => r.payload.startsWith('e2|')), hasLength(1));
    });
  });

  group('calls widgets', () {
    late TestHarness h;
    late FakeCallServer server;
    late List<FakeCallMedia> medias;
    late FakeCameraPreview preview;
    String? clipboard;

    tearDown(() => h.dispose());

    Future<void> settle(WidgetTester tester, [int steps = 12]) async {
      for (var i = 0; i < steps; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> launch(WidgetTester tester, {void Function()? before}) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      medias = [];
      preview = FakeCameraPreview();
      clipboard = null;
      h = await TestHarness.create(
        storedToken: Fixtures.token,
        chatBaseUrl: 'http://chat.local/api/v1',
        callsBaseUrl: 'http://calls.local/api/v1',
        overrides: [
          callNativeProvider.overrideWithValue(FakeCallNative()),
          callSoundsProvider.overrideWithValue(FakeCallSounds()),
          callPipProvider.overrideWithValue(FakeCallPip()),
          callMediaFactoryProvider.overrideWithValue(() {
            final m = FakeCallMedia();
            medias.add(m);
            return m;
          }),
          callCameraPreviewFactoryProvider.overrideWithValue(() => preview),
          reminderSchedulerProvider.overrideWithValue(_RecordingScheduler()),
          callRecordingsDirProvider.overrideWithValue(() async => Directory.systemTemp),
        ],
      );
      h.stubSignedIn();
      h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats(const []));
      h.chatAdapter.onPattern('POST', r'^/push/devices$', (_) => const FakeResponse(204));
      server = FakeCallServer(h.callsAdapter, selfId: ChatFixtures.me, selfName: 'Тест Пользователь');
      server.config = {
        'max_video_tiles': 9,
        'ring_timeout_sec': 45,
        'max_group': 50,
        'max_conference': 150,
        'recording_enabled': true,
        'transcription_enabled': true,
        'guests_enabled': true,
        'meeting_join_early_sec': 600,
      };
      before?.call();
      tester.platformDispatcher.localeTestValue = const Locale('ru');
      tester.platformDispatcher.localesTestValue = const [Locale('ru')];
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.runAsync(() => h.session.restore());
      await tester.pumpWidget(UncontrolledProviderScope(container: h.container, child: const XatBoxApp()));
      await settle(tester);
    }

    Future<void> finish(WidgetTester tester) async {
      if (h.container.read(callControllerProvider).inCall) {
        unawaited(h.container.read(callControllerProvider.notifier).hangUp());
        await tester.pump(const Duration(seconds: 1));
      }
      unawaited(h.container.read(chatRepositoryProvider).stop());
      await tester.pump(const Duration(seconds: 10));
    }

    testWidgets('360 px pre-join: preview, device names, mic/camera toggles, lobby wait, then the meeting opens with the chosen devices', (tester) async {
      const code = 'abc-defg-hjk';
      await launch(
        tester,
        before: () {
          server.meetings[code] = FakeCallServer.meetingJson(code: code, startsAt: DateTime.now().toUtc().add(const Duration(minutes: 5)));
          server.meetingLobbyPolls = 1;
        },
      );
      unawaited(h.container.read(appRouterProvider).push(Routes.meetPath(code)));
      await settle(tester, 20);

      expect(find.byType(MeetingPrejoinScreen), findsOneWidget);
      expect(find.text('Учёный совет'), findsOneWidget);
      expect(find.byKey(const ValueKey('fake_camera_preview')), findsOneWidget);
      expect(find.textContaining('Встроенный микрофон'), findsOneWidget);
      expect(find.textContaining('Фронтальная камера'), findsOneWidget);

      await tester.tap(find.byKey(const Key('meet_mic_toggle')));
      await tester.tap(find.byKey(const Key('meet_cam_toggle')));
      await settle(tester);
      expect(find.byKey(const ValueKey('fake_camera_preview')), findsNothing);
      expect(find.text('Камера выключена'), findsOneWidget);
      expect(find.textContaining('Микрофон: выключен(а)'), findsOneWidget);
      expect(preview.running, isFalse, reason: 'camera released: ${preview.events}');

      await tester.ensureVisible(find.byKey(const Key('meet_join')));
      await tester.tap(find.byKey(const Key('meet_join')));
      await settle(tester);
      expect(find.byKey(const Key('meet_lobby_waiting')), findsOneWidget);
      final joins = h.callsAdapter.of('POST', '/meetings/$code/join');
      expect(joins, hasLength(1));
      expect(joins.single.json['device_id'], isNotEmpty);

      await tester.pump(const Duration(seconds: 3));
      await settle(tester, 20);
      expect(h.callsAdapter.of('POST', '/meetings/$code/join'), hasLength(2), reason: 'polls while waiting');
      expect(find.byType(CallScreen), findsOneWidget);
      final st = h.container.read(callControllerProvider);
      expect(st.call?.meetingId, 'm-$code');
      expect(st.phase, CallPhase.active, reason: 'a meeting is on even alone');
      expect(medias.single.connectedVideo, isFalse);
      expect(medias.single.micOn, isFalse);
      await finish(tester);
    });

    testWidgets('pre-join: a meeting that is not open yet disables «Подключиться»; a guest link explains itself', (tester) async {
      const code = 'bcd-efgh-jkm';
      await launch(
        tester,
        before: () => server.meetings[code] = FakeCallServer.meetingJson(
          code: code,
          startsAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
          status: 'scheduled',
          canJoin: false,
        ),
      );
      unawaited(h.container.read(appRouterProvider).push(Routes.meetPath(code)));
      await settle(tester, 20);
      await tester.ensureVisible(find.byKey(const Key('meet_join')));
      expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('meet_join'))).onPressed, isNull);
      expect(find.byKey(const Key('meet_join_hint')), findsOneWidget);

      h.container.read(appRouterProvider).pop();
      await settle(tester);
      unawaited(h.container.read(appRouterProvider).push(Routes.meetPath('g${'k' * 32}')));
      await settle(tester);
      expect(find.text('Это гостевая ссылка'), findsOneWidget);
      expect(h.callsAdapter.requests.where((r) => r.path.startsWith('/meetings/g')), isEmpty);
      await finish(tester);
    });

    testWidgets('«Встречи» on the calls tab: an open meeting offers «Подключиться», a later one shows its time', (tester) async {
      await launch(
        tester,
        before: () {
          server.meetings['abc-defg-hjk'] = FakeCallServer.meetingJson(code: 'abc-defg-hjk', startsAt: DateTime.now().toUtc().add(const Duration(minutes: 5)));
          server.meetings['cde-fghj-kmn'] = FakeCallServer.meetingJson(
            code: 'cde-fghj-kmn',
            title: 'Планёрка кафедры',
            startsAt: DateTime.now().toUtc().add(const Duration(days: 1)),
            status: 'scheduled',
            canJoin: false,
          );
        },
      );
      // Звонки live under «Ещё» of the glass bar.
      await tester.tap(find.byKey(const Key('tab_more')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('more_calls')));
      await settle(tester, 20);
      expect(find.byKey(const Key('calls_meetings')), findsOneWidget);
      expect(find.byKey(const ValueKey('meeting_join_abc-defg-hjk')), findsOneWidget);
      expect(find.byKey(const ValueKey('meeting_join_cde-fghj-kmn')), findsNothing);
      expect(find.text('Планёрка кафедры'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('meeting_join_abc-defg-hjk')));
      await settle(tester, 20);
      expect(find.byType(MeetingPrejoinScreen), findsOneWidget);
      await finish(tester);
    });

    testWidgets('360 px group call: knock banner, «Ожидают: 1» with admit, the guest with «Гость», a guest link with copy', (tester) async {
      await launch(tester);
      unawaited(h.container.read(callControllerProvider.notifier).startCall(calleeIds: ['u-bob', 'u-carol'], video: false, mode: 'group'));
      unawaited(h.container.read(appRouterProvider).push(Routes.call));
      await settle(tester, 20);
      medias.single.join('u-bob');
      await settle(tester);
      final id = h.container.read(callControllerProvider).callId!;

      server.lobbies[id] = {
        'waiting': [
          {'id': 'g1', 'name': 'Айдана Гость', 'kind': 'guest', 'status': 'waiting', 'identity': 'guest_g1#web', 'created_at': '2026-09-15T10:00:00Z'},
        ],
        'guests': <Object>[],
      };
      medias.single.receive('', {'type': 'lobby', 'call_id': id, 'count': 1});
      await settle(tester);
      expect(find.byKey(const Key('call_lobby_banner')), findsOneWidget);
      expect(find.text('Ожидают входа: 1'), findsOneWidget);
      medias.single.receive('u-bob#d1', {'type': 'lobby', 'call_id': id, 'count': 5});
      await settle(tester);
      expect(h.callsAdapter.of('GET', '/calls/$id/lobby').length, lessThanOrEqualTo(2), reason: 'only the Call Service announces the lobby');

      await tester.tap(find.byKey(const Key('call_lobby_banner_open')));
      await settle(tester);
      expect(find.byKey(const Key('call_lobby_section')), findsOneWidget);
      expect(find.text('ОЖИДАЮТ: 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lobby_admit_g1')));
      await settle(tester);
      expect(server.lobbyDecisions, ['admit:g1']);
      expect(find.byKey(const Key('call_lobby_section')), findsNothing);

      medias.single.join('guest_g1');
      await settle(tester);
      expect(find.byKey(const ValueKey('guest_badge_g1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('call_guest_link')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('guest_link_expiry_1440')));
      await tester.tap(find.byKey(const Key('guest_link_uses_plus')));
      await settle(tester, 2);
      await tester.ensureVisible(find.byKey(const Key('guest_link_create')));
      await tester.tap(find.byKey(const Key('guest_link_create')));
      await settle(tester);
      expect(server.guestLinkBodies.single, {'expires_in_minutes': 1440, 'max_uses': 6, 'require_lobby': true, 'allow_screen_share': false});
      expect(find.byKey(const Key('guest_link_url')), findsOneWidget);
      await tester.tap(find.byKey(const Key('guest_link_copy')));
      await settle(tester);
      expect(clipboard, startsWith('https://mail.test/xatbox/calls/api/v1/meet/g'));

      Navigator.of(tester.element(find.byKey(const Key('guest_link_copy')))).pop();
      await settle(tester);
      Navigator.of(tester.element(find.byKey(const Key('call_guests_section')))).pop();
      await settle(tester);
      await finish(tester);
    });

    testWidgets('360 px: poor network offers traffic saving once; «Качество» toggles processing, music mode and «Только звук», remembered', (tester) async {
      await launch(tester);
      unawaited(h.container.read(callControllerProvider.notifier).startCall(calleeIds: ['u-bob'], video: true));
      unawaited(h.container.read(appRouterProvider).push(Routes.call));
      await settle(tester, 20);
      medias.single.join('u-bob', cameraOn: true);
      await settle(tester);

      await tester.tap(find.byKey(const Key('call_more')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('call_quality_more')));
      await settle(tester);
      expect(find.byKey(const Key('call_quality_sheet')), findsOneWidget);
      expect(find.byKey(const Key('call_blur_unavailable')), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('call_audio_noise'))).value, isTrue, reason: 'on by default');

      await tester.tap(find.byKey(const Key('call_audio_noise')));
      await settle(tester);
      expect(medias.single.audioSettings.noiseSuppression, isFalse);
      await tester.tap(find.byKey(const Key('call_audio_music')));
      await settle(tester);
      expect(medias.single.audioSettings.musicMode, isTrue);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('call_audio_echo'))).onChanged, isNull, reason: 'music mode turns voice filters off');

      await tester.ensureVisible(find.byKey(const ValueKey('call_data_saver_audioOnly')));
      await tester.tap(find.byKey(const ValueKey('call_data_saver_audioOnly')));
      await settle(tester);
      expect(medias.single.dataSaver, CallDataSaver.audioOnly);
      expect(medias.single.cameraOn, isFalse);
      final saved = await tester.runAsync(() => h.container.read(callsCacheProvider).audioSettings());
      expect(saved?.dataSaver, CallDataSaver.audioOnly);
      expect(saved?.audio.musicMode, isTrue);
      await tester.tap(find.byKey(const ValueKey('call_data_saver_off')));
      await settle(tester);
      expect(medias.single.dataSaver, CallDataSaver.off);
      Navigator.of(tester.element(find.byKey(const Key('call_quality_sheet')))).pop();
      await settle(tester);

      // The link stays poor: saving is offered once (the banner is visible with hidden controls too).
      medias.single.setQuality(LinkQuality.poor);
      await tester.pump(const Duration(seconds: 9));
      await settle(tester);
      expect(find.byKey(const Key('call_quality_prompt')), findsOneWidget);
      await tester.tap(find.byKey(const Key('call_quality_prompt_accept')));
      await settle(tester);
      expect(medias.single.dataSaver, CallDataSaver.lowVideo);
      expect(find.byKey(const Key('call_quality_prompt')), findsNothing);
      medias.single.setQuality(LinkQuality.good);
      medias.single.setQuality(LinkQuality.lost);
      await tester.pump(const Duration(seconds: 9));
      await settle(tester);
      expect(find.byKey(const Key('call_quality_prompt')), findsNothing, reason: 'once per call, saving is on');
      await finish(tester);
    });

    testWidgets('360 px call card: «Расшифровка» opens the transcript with automatic key phrases, search and copy', (tester) async {
      await launch(
        tester,
        before: () {
          server.calls['old'] = server.callJson(
            id: 'old',
            callerId: 'u-bob',
            others: [('u-bob', 'Болат')],
            status: 'ended',
            direction: 'incoming',
            outcome: 'answered',
          )..['duration_sec'] = 912;
          server.recordings['old'] = [
            FakeCallServer.recordingItem('rec-1', 'old')..['transcript_status'] = 'complete',
            FakeCallServer.recordingItem('rec-2', 'old')..['transcript_status'] = 'processing',
          ];
          server.transcripts['rec-1'] = FakeCallServer.transcriptJson('rec-1', 'old');
        },
      );
      // Звонки live under «Ещё» of the glass bar.
      await tester.tap(find.byKey(const Key('tab_more')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('more_calls')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('call_old')));
      await settle(tester);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await settle(tester);

      final list = find.descendant(of: find.byKey(const Key('call_details')), matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(find.byKey(const ValueKey('call_transcript_pending_rec-2')), 200, scrollable: list);
      expect(find.byKey(const ValueKey('call_transcript_pending_rec-2')), findsOneWidget);
      final open = find.byKey(const ValueKey('call_transcript_open_rec-1'));
      await tester.scrollUntilVisible(open, -100, scrollable: list);
      await tester.ensureVisible(open);
      await settle(tester, 4);
      await tester.tap(open);
      await settle(tester, 20);

      expect(find.byType(CallTranscriptScreen), findsOneWidget);
      expect(find.byKey(const Key('transcript_key_phrases')), findsOneWidget);
      expect(find.text('автоматически'), findsOneWidget);
      expect(find.byKey(const ValueKey('transcript_segment_0')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('transcript_search')), 'протокол');
      await settle(tester);
      expect(find.text('Найдено: 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('transcript_segment_0')), findsNothing);
      expect(find.byKey(const ValueKey('transcript_segment_1')), findsOneWidget);
      expect(find.byKey(const Key('transcript_key_phrases')), findsNothing);

      await tester.tap(find.byKey(const Key('transcript_copy')));
      await settle(tester);
      expect(clipboard, contains('бюджет кафедры'));
      expect(clipboard, contains('Протокол будет вечером.'));
      expect(find.text('Текст скопирован'), findsOneWidget);
      await finish(tester);
    });
  });

  group('calendar meetings', () {
    setUpAll(CalendarZones.ensureInitialized);

    late TestHarness h;
    late FakeCalendarServer calendar;
    late FakeCallServer calls;
    late _RecordingScheduler scheduler;
    final clock = DateTime.utc(2026, 9, 14, 6); // Monday 11:00 in Almaty
    const me = FakeCalendarUser(
      id: '11111111-1111-4111-8111-111111111111',
      token: Fixtures.token,
      name: 'Тест Пользователь',
      org: '33333333-3333-4333-8333-333333333333',
    );
    const bob = FakeCalendarUser(
      id: 'bbbbbbbb-0000-4000-8000-000000000002',
      token: 'tok-bob',
      name: 'Болат Сейтов',
      org: '33333333-3333-4333-8333-333333333333',
    );
    DateTime at(int d, int hour) => EventTime.atWall(CalendarDate(2026, 9, d), hour, 0, CalendarZones.location('Asia/Almaty'));

    tearDown(() => h.dispose());

    Future<void> settle(WidgetTester tester, [int steps = 12]) async {
      for (var i = 0; i < steps; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> launch(WidgetTester tester, {void Function()? before}) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      scheduler = _RecordingScheduler();
      h = await TestHarness.create(
        storedToken: Fixtures.token,
        chatBaseUrl: 'http://chat.local/api/v1',
        callsBaseUrl: 'http://calls.local/api/v1',
        overrides: [
          initialDeviceZoneProvider.overrideWithValue('Asia/Almaty'),
          calendarClockProvider.overrideWithValue(() => clock),
          callClockProvider.overrideWithValue(() => clock),
          reminderSchedulerProvider.overrideWithValue(scheduler),
          callNativeProvider.overrideWithValue(FakeCallNative()),
          callSoundsProvider.overrideWithValue(FakeCallSounds()),
          callPipProvider.overrideWithValue(FakeCallPip()),
          callMediaFactoryProvider.overrideWithValue(FakeCallMedia.new),
          callCameraPreviewFactoryProvider.overrideWithValue(FakeCameraPreview.new),
        ],
      );
      h.stubSignedIn();
      h.adapter.onJson(
        'GET',
        '/me',
        Fixtures.me(
          permissions: const [
            'mail.read',
            'mail.send',
            'messages.send',
            'messages.group.create',
            'calendar.events.read',
            'calendar.events.create',
            'calendar.events.manage_own',
          ],
        ),
      );
      h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats(const []));
      h.chatAdapter.onPattern('POST', r'^/push/devices$', (_) => const FakeResponse(204));
      h.chatAdapter.onPattern('POST', r'^/calendar/events/.+$', (_) => const FakeResponse(204));
      calendar = FakeCalendarServer(h.adapter, const [me, bob]);
      calls = FakeCallServer(h.callsAdapter, selfId: ChatFixtures.me, selfName: 'Тест Пользователь');
      calls.config = {'max_video_tiles': 9, 'ring_timeout_sec': 45, 'max_group': 50, 'max_conference': 150, 'guests_enabled': true};
      before?.call();
      tester.platformDispatcher.localeTestValue = const Locale('ru');
      tester.platformDispatcher.localesTestValue = const [Locale('ru')];
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.runAsync(() => h.session.restore());
      await tester.pumpWidget(UncontrolledProviderScope(container: h.container, child: const XatBoxApp()));
      await settle(tester);
    }

    Future<void> finish(WidgetTester tester) async {
      unawaited(h.container.read(chatRepositoryProvider).stop());
      await tester.pump(const Duration(seconds: 10));
    }

    testWidgets('360 px editor: «Добавить видеовстречу XatBox» creates the meeting and writes its link into the event', (tester) async {
      await launch(tester);
      unawaited(
        h.container.read(appRouterProvider).push(
          Routes.calendarNew,
          extra: const EventEditArgs.create(date: CalendarDate(2026, 9, 17), hour: 10),
        ),
      );
      await settle(tester, 20);
      await tester.enterText(find.byKey(const Key('event_title')), 'Защита проекта');
      await tester.scrollUntilVisible(find.byKey(const Key('event_xatbox_meeting')), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Добавить видеовстречу XatBox'), findsOneWidget);
      await tester.tap(find.byKey(const Key('event_xatbox_meeting')));
      await settle(tester, 2);
      expect(tester.widget<Switch>(find.descendant(of: find.byKey(const Key('event_xatbox_meeting')), matching: find.byType(Switch))).value, isTrue);

      await tester.tap(find.byKey(const Key('event_save')));
      await settle(tester, 30);
      final body = h.callsAdapter.of('POST', '/meetings').single.json;
      expect(body['title'], 'Защита проекта');
      expect(DateTime.parse(body['starts_at'] as String).isAtSameMomentAs(at(17, 10)), isTrue);
      expect(DateTime.parse(body['ends_at'] as String).isAtSameMomentAs(at(17, 11)), isTrue);
      expect([body['lobby_enabled'], body['invitee_ids']], [true, <Object>[]]);
      expect(body['client_meeting_id'], isNotEmpty);

      const url = 'https://mail.test/xatbox/calls/api/v1/meet/bcd-efgh-jkm';
      final event = calendar.events.values.firstWhere((e) => e['title'] == 'Защита проекта');
      expect(event['meeting_link'], url);
      expect(event['description'], 'Видеовстреча XatBox: $url');
      expect(find.byType(EventEditScreen), findsNothing);
      await finish(tester);
    });

    testWidgets('event with a XatBox meeting: «Подключиться» from 10 minutes before opens the pre-join; a reminder 5 minutes before with the action', (tester) async {
      const link = 'https://mail.test/xatbox/calls/api/v1/meet/abc-defg-hjk';
      late String nowId;
      late String laterId;
      await launch(
        tester,
        before: () {
          nowId = calendar.seedEvent(organizer: me, title: 'Совет сейчас', start: at(14, 11), end: at(14, 12), guests: const [bob]);
          calendar.events[nowId]!['meeting_link'] = link;
          laterId = calendar.seedEvent(organizer: me, title: 'Совет позже', start: at(14, 15), end: at(14, 16), guests: const [bob]);
          calendar.events[laterId]!['meeting_link'] = link.replaceFirst('abc-defg-hjk', 'cde-fghj-kmn');
          calls.meetings['abc-defg-hjk'] = FakeCallServer.meetingJson(code: 'abc-defg-hjk', startsAt: at(14, 11));
        },
      );
      final router = h.container.read(appRouterProvider);

      unawaited(router.push(Routes.calendarEventPath(laterId)));
      await settle(tester, 20);
      expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('event_meeting_join'))).onPressed, isNull);
      expect(find.byKey(const Key('event_meeting_hint')), findsOneWidget);
      expect(find.byKey(const Key('event_join_call')), findsNothing);
      router.pop();
      await settle(tester);

      unawaited(router.push(Routes.calendarEventPath(nowId)));
      await settle(tester, 20);
      await tester.tap(find.byKey(const Key('event_meeting_join')));
      await settle(tester, 20);
      expect(find.byType(MeetingPrejoinScreen), findsOneWidget);

      await tester.pump(const Duration(seconds: 5)); // reminders are planned after a short debounce
      await settle(tester);
      final meeting = scheduler.active.values.where((r) => r.payload.startsWith('meet:')).toList();
      expect(meeting.map((r) => r.payload), ['meet:cde-fghj-kmn'], reason: 'the meeting starting now is past its reminder');
      // The scheduler texts follow the device locale, not the app one.
      expect(meeting.single.actionLabel, anyOf('Подключиться', 'Join', 'Қосылу'));
      expect(meeting.single.fireAt.isAtSameMomentAs(at(14, 15).subtract(const Duration(minutes: 5))), isTrue);
      await finish(tester);
    });
  });
}

class _RecordingScheduler implements ReminderScheduler {
  final Map<int, ReminderRequest> active = {};

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule(ReminderRequest request) async => active[request.id] = request;

  @override
  Future<void> cancel(int id) async => active.remove(id);
}
