import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_screen.dart';
import 'package:xatbox_mobile/features/contacts/presentation/contact_profile_screen.dart';
import 'package:xatbox_mobile/features/contacts/presentation/contacts_screen.dart';

import '../test/helpers/chat_fixtures.dart';
import '../test/helpers/fake_http.dart';
import '../test/helpers/fixtures.dart';
import 'support/e2e_app.dart';

/// E2E: contacts tab → search → profile → start an audio call.
void main() {
  ensureE2EBinding();

  testWidgets('contacts: search, open profile, start a call', (tester) async {
    useRussian(tester);
    final e2e = await E2E.create(storedToken: Fixtures.token);
    addTearDown(e2e.h.dispose);
    final h = e2e.h;
    h.stubSignedIn();
    final directory = [
      ChatFixtures.user(name: 'Болат Сейтов', online: true),
      ChatFixtures.user(id: 'u-alia', name: 'Алия Нурланова'),
      ChatFixtures.user(id: selfId, name: selfName),
    ];
    h.chatAdapter.on('GET', '/users', (r) {
      final q = ((r.query['q'] as String?) ?? '').toLowerCase();
      return FakeResponse(200, json: {
        'users': directory.where((u) => (u['display_name'] as String).toLowerCase().contains(q)).toList(),
      });
    });
    await tester.runAsync(() => h.session.restore());
    await pumpE2EApp(tester, e2e);

    await openTab(tester, 'Контакты');
    expect(find.byType(ContactsScreen), findsOneWidget);
    expect(find.text('Алия Нурланова'), findsOneWidget);

    // Search (debounced) narrows the directory.
    await tester.enterText(find.byKey(const Key('contacts_search')), 'бол');
    await settle(tester);
    expect(h.chatAdapter.of('GET', '/users').last.query['q'], 'бол');
    expect(find.text('Алия Нурланова'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('contact_${ChatFixtures.peer}')));
    await settle(tester);
    expect(find.byType(ContactProfileScreen), findsOneWidget);
    expect(find.byKey(const Key('contact_profile_name')), findsOneWidget);

    await tester.tap(find.byKey(const Key('contact_audio_call')));
    await settle(tester, 20);
    final create = h.callsAdapter.of('POST', '/calls').single.json;
    expect(create['callee_ids'], [ChatFixtures.peer]);
    expect(create['type'], 'audio');
    expect(create['client_call_id'], isNotEmpty);
    expect(find.byType(CallScreen), findsOneWidget);
    expect(find.text('Вызов…'), findsWidgets);
    expect(tester.takeException(), isNull);

    await finishE2E(tester, e2e);
  });
}
