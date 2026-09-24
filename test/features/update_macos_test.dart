import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/platform/mac_sandbox_migration.dart';
import 'package:xatbox_mobile/features/update/data/apk_installer.dart';
import 'package:xatbox_mobile/features/update/data/update_models.dart';

/// macOS in-app updates: the release asked for, the running bundle, and the
/// script that swaps XatBox.app once the app has quit.
void main() {
  test('the Mac app asks for its own releases with plain build numbers', () {
    const app = InstalledApp(versionName: '0.2.0', buildNumber: 3, isMacOS: true);
    expect(app.updatable, isTrue);
    expect(app.platform, 'macos');
    expect(app.abi, 'universal');
    expect(app.versionCode, 3);
    expect(app.isDesktopApp, isTrue);
  });

  test('the bundle of the running executable', () {
    expect(macAppBundle('/Applications/XatBox.app/Contents/MacOS/XatBox'), '/Applications/XatBox.app');
    expect(macAppBundle('/Users/sbs/My Apps/XatBox.app/Contents/MacOS/XatBox'), '/Users/sbs/My Apps/XatBox.app');
    expect(macAppBundle('/usr/local/bin/xatbox'), isNull);
  });

  test('the swap script waits, keeps the old bundle until the new is in, relaunches', () {
    final s = macSwapScript(pid: 42, bundle: "/Users/o'neil/XatBox.app", fresh: '/tmp/x/XatBox.app', relaunch: true);
    expect(s, contains('while kill -0 42'));
    expect(s, contains("mv '/Users/o'\\''neil/XatBox.app' \"\$OLD\""));
    expect(s, contains(r"""mv '/tmp/x/XatBox.app' '/Users/o'\''neil/XatBox.app'"""));
    expect(s, contains(r"""mv "$OLD" '/Users/o'\''neil/XatBox.app'"""));
    expect(s, contains('xattr -dr com.apple.quarantine'));
    expect(s, contains("/usr/bin/open '/Users/o'\\''neil/XatBox.app'"));
    expect(macSwapScript(pid: 1, bundle: '/A.app', fresh: '/B.app', relaunch: false), isNot(contains('/usr/bin/open')));
  });

  test('sandbox data moves from the container to Application Support', () {
    final (from, to) = macSandboxMove('/Users/sbs');
    expect(from, '/Users/sbs/Library/Containers/kz.xatbox.xatboxMobile/Data/Library/Application Support/kz.xatbox.xatboxMobile');
    expect(to, '/Users/sbs/Library/Application Support/kz.xatbox.xatboxMobile');
  });
}
