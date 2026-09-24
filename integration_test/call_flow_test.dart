import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_controller.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_screen.dart';
import 'package:xatbox_mobile/features/calls/presentation/calls_providers.dart';

import '../test/helpers/fixtures.dart';
import 'support/e2e_app.dart';

/// E2E: an incoming call over the chat socket → accept → minimise into the
/// floating mini bar → return → hang up. LiveKit and the system call UI are fakes.
void main() {
  ensureE2EBinding();

  testWidgets('incoming call: accept, minimise, return, hang up', (tester) async {
    useRussian(tester);
    final e2e = await E2E.create(storedToken: Fixtures.token);
    addTearDown(e2e.h.dispose);
    final h = e2e.h;
    final server = e2e.calls!;
    h.stubSignedIn();
    await tester.runAsync(() => h.session.restore());
    await pumpE2EApp(tester, e2e);

    // The chat socket announces a call.
    final id = server.addIncoming(callerId: 'u-bob', callerName: 'Болат Сейтов');
    h.socketFactory.last.serverSend({'type': 'call.incoming', 'call_id': id, 'call': server.calls[id]});
    await settle(tester, 20);
    expect(find.byType(CallScreen), findsOneWidget);
    expect(find.text('Входящий звонок'), findsOneWidget);
    expect(e2e.native.shownIncoming, [id]);

    // Accept; the peer joins the media room.
    await tester.tap(find.byKey(const Key('call_accept')));
    await settle(tester, 20);
    expect(h.callsAdapter.of('POST', '/calls/$id/accept'), hasLength(1));
    e2e.medias.single.join('u-bob');
    await settle(tester);
    final controller = h.container.read(callControllerProvider);
    expect(controller.phase, CallPhase.active);
    expect(e2e.medias.single.connectedWith?.token, 'lk-jwt-$id');

    // Minimise: the call keeps going in the mini bar over the app.
    await tester.tap(find.byKey(const Key('call_minimize')).first);
    await settle(tester);
    expect(find.byType(CallScreen), findsNothing);
    expect(h.container.read(callControllerProvider).inCall, isTrue);
    expect(find.byKey(const Key('call_mini_bar')), findsOneWidget);

    // Return to the full call screen.
    await tester.tap(find.byKey(const Key('call_mini_bar')));
    await settle(tester);
    expect(find.byType(CallScreen), findsOneWidget);
    expect(find.byKey(const Key('call_mini_bar')), findsNothing);

    // Hang up.
    await tester.tap(find.byKey(const Key('call_hangup')));
    await settle(tester);
    expect(h.callsAdapter.of('POST', '/calls/$id/end'), hasLength(1));
    expect(find.text('Звонок завершён'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await settle(tester);
    expect(find.byType(CallScreen), findsNothing);
    expect(h.container.read(appRouterProvider).routeInformationProvider.value.uri.path, isNot('/call'));
    expect(e2e.medias.single.disconnected, isTrue);
    expect(tester.takeException(), isNull);

    await finishE2E(tester, e2e);
  });
}
