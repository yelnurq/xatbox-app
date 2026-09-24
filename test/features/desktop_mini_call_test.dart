import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:xatbox_mobile/core/localization/localization.dart';
import 'package:xatbox_mobile/core/platform/desktop.dart';
import 'package:xatbox_mobile/features/calls/presentation/desktop_mini_call.dart';

import '../helpers/test_app.dart';

class _Small extends DesktopMiniCall {
  @override
  bool build() => true;
}

/// The small call window sits above the app's navigator (in the app
/// builder): its buttons must work there — their tooltips used to find no
/// Overlay, which broke the window (grey in release builds).
void main() {
  testWidgets('the small call: hovering and pressing its buttons works', (tester) async {
    debugDesktopOverride = true;
    addTearDown(() => debugDesktopOverride = null);
    final h = await TestHarness.create(overrides: [desktopMiniCallProvider.overrideWith(_Small.new)]);
    addTearDown(h.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(
          localizationsDelegates: AppLocalization.delegates,
          supportedLocales: AppLocalization.supportedLocales,
          builder: (context, child) => DesktopMiniCallHost(child: child!),
          home: const Scaffold(body: Text('app')),
        ),
      ),
    );
    await tester.pump();
    final mic = find.byIcon(LucideIcons.mic).evaluate().isEmpty ? find.byIcon(LucideIcons.micOff) : find.byIcon(LucideIcons.mic);
    expect(mic, findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(mic));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.byType(Tooltip), findsWidgets);
    expect(find.byKey(const Key('mini_call_video')), findsOneWidget);
  });
}
