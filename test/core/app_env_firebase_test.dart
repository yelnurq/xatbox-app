import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/api/app_env.dart';

void main() {
  FirebasePushOptions? options({String appId = '', String iosAppId = '', required bool ios}) =>
      FirebasePushOptions.fromValues(
        apiKey: 'key',
        appId: appId,
        iosAppId: iosAppId,
        messagingSenderId: '123',
        projectId: 'xatbox',
        ios: ios,
      );

  test('a Firebase app id per platform: iOS takes XATBOX_FIREBASE_IOS_APP_ID', () {
    const android = '1:123:android:abc';
    const apple = '1:123:ios:def';
    expect(options(appId: android, iosAppId: apple, ios: false)!.appId, android);
    expect(options(appId: android, iosAppId: apple, ios: true)!.appId, apple);
    // Older env files without the iOS id keep working as before.
    expect(options(appId: android, ios: true)!.appId, android);
    // An iOS-only build needs no Android id.
    expect(options(iosAppId: apple, ios: true)!.appId, apple);
    expect(options(iosAppId: apple, ios: false), isNull);
    expect(options(ios: true), isNull);
  });
}
