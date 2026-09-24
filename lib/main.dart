import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app.dart';
import 'core/api/app_env.dart';
import 'core/auth/auth_providers.dart';
import 'core/errors/error_reporter.dart';
import 'core/errors/error_reporting_providers.dart';
import 'core/platform/desktop.dart';
import 'core/platform/ios_native_config.dart';
import 'core/preferences/app_preferences.dart';
import 'core/routing/app_router.dart';
import 'core/storage/app_database.dart';
import 'core/storage/cache_policy.dart';
import 'core/storage/storage_usage.dart';
import 'features/calendar/presentation/calendar_providers.dart';
import 'features/calls/data/call_background.dart';
import 'features/chat/data/chat_push.dart';
import 'features/chat/data/push_notifications.dart';
import 'features/mail/presentation/mail_providers.dart';
import 'features/sessions/sign_out_wipe.dart';
import 'shared/utils/diagnostic_log.dart';

/// Uncaught errors of the root zone go to the diagnostics log and to our
/// own crash reporting (lib/core/errors), never to a third party.
void main() {
  runZonedGuarded(_main, (error, stack) {
    DiagnosticLog.error('zone', error.toString(), stackTrace: stack);
    reportError(error, stack, context: 'zone');
  });
}

/// Shown when local data cannot be opened: without it the native splash
/// would stay on screen forever.
const _startupFailedMessage =
    'Не удалось запустить XatBox. Закройте приложение и откройте его снова.\n\n'
    'XatBox could not start. Close the app and open it again.';

Future<void> _main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Handlers first: nothing below may fail unseen.
  _installErrorHandlers();
  // Desktop: media backends and the window (no-op on phones).
  await initDesktop();

  final AppEnv env;
  try {
    env = AppEnv.current;
  } on AppEnvError catch (e) {
    runApp(ConfigErrorApp(message: e.message));
    return;
  }

  try {
    await _start(env);
  } on Object catch (e, st) {
    DiagnosticLog.error('app', 'startup failed: $e', stackTrace: st);
    reportError(e, st, context: 'startup');
    runApp(const ConfigErrorApp(message: _startupFailedMessage));
  }
}

void _installErrorHandlers() {
  // Framework errors go to the redacted diagnostics log, never raw.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    DiagnosticLog.error(
      'flutter',
      details.exceptionAsString(),
      stackTrace: details.stack,
    );
    if (!details.silent) {
      reportError(
        details.exception,
        details.stack,
        context: details.context?.toDescription(),
      );
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    DiagnosticLog.error('platform', error.toString(), stackTrace: stack);
    reportError(error, stack, context: 'platform');
    return true;
  };
  // Errors of the root isolate outside any zone (e.g. from native callbacks).
  Isolate.current.addErrorListener(
    RawReceivePort((Object? pair) {
      if (pair is! List || pair.length < 2) return;
      final trace = pair[1]?.toString() ?? '';
      reportError(
        RemoteError(pair[0]?.toString() ?? 'isolate error', trace),
        StackTrace.fromString(trace),
        context: 'isolate',
      );
    }).sendPort,
  );
}

Future<T> _orElse<T>(String what, Future<T> future, T fallback) async {
  try {
    return await future;
  } on Object catch (e) {
    DiagnosticLog.warn('app', '$what failed at start', error: e);
    return fallback;
  }
}

/// Local work only before the first frame (no network): the database and
/// what the first frame renders with (theme, language, time zone).
Future<void> _start(AppEnv env) async {
  // Push: Android notification channels (idempotent). Never fatal.
  unawaited(ensurePushChannels());

  // Independent platform calls in parallel. The database is the only
  // required one (its failure shows the startup error screen).
  final dbFuture = AppDatabase.open();
  final infoFuture = _orElse(
    'package info',
    PackageInfo.fromPlatform(),
    PackageInfo(appName: 'XatBox', packageName: '', version: '0.0.0', buildNumber: '0'),
  );
  // IANA zone before the first frame, so calendar times never flash in UTC.
  final zoneFuture = readDeviceZone();
  final db = await dbFuture;
  // Theme, language and lock settings before the first frame.
  final preferences = await _orElse(
    'preferences',
    AppPreferencesStore(db).read(),
    const AppPreferences(),
  );
  final info = await infoFuture;
  final deviceZone = await zoneFuture;
  ErrorReporter.instance
    ..enabled = preferences.sendErrorReports
    ..device = await _deviceSnapshot(info, env, preferences);
  // The Mail API lists sessions by User-Agent («Мои устройства и сеансы»):
  // "Android … Mobile" / an "iPhone…" model make it show a phone.
  final device = ErrorReporter.instance.device;
  final userAgent = Platform.isAndroid || Platform.isIOS
      ? 'XatBoxMobile/${info.version}+${info.buildNumber} '
            '(${device.osVersion}; Mobile; ${device.deviceModel}; ${env.flavor.name})'
      : 'XatBoxDesktop/${info.version}+${info.buildNumber} '
            '(${desktopUserAgentOs()}; ${env.flavor.name})';

  final container = ProviderContainer(
    overrides: [
      appEnvProvider.overrideWithValue(env),
      appDatabaseProvider.overrideWithValue(db),
      userAgentProvider.overrideWithValue(userAgent),
      initialDeviceZoneProvider.overrideWithValue(deviceZone),
      initialAppPreferencesProvider.overrideWithValue(preferences),
    ],
  );

  // Crash reports: offline queue, sent to the Chat Service when signed in.
  ErrorReporter.instance.routeName = () =>
      container.read(appRouterProvider).routeInformationProvider.value.uri.path;
  container.read(errorReportingProvider);

  // Cache limits chosen by the user (local read, needed before mail loads).
  try {
    container.read(mailCacheProvider).policy = await container
        .read(cacheSettingsStoreProvider)
        .read();
  } on Object catch (e) {
    DiagnosticLog.warn('app', 'cache settings unreadable, defaults used', error: e);
  }

  // Sign-out wipes module caches and temp files (ТЗ п.24.4); also after a
  // session ended remotely («Мои устройства и сеансы»). Add new hooks there.
  registerSignOutWipes(container);

  DiagnosticLog.info(
    'app',
    'start flavor=${env.flavor.name} version=${info.version}',
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const XatBoxApp()),
  );

  // After the first frame is scheduled: nothing here is needed to draw it.
  // The default FirebaseApp (google-services.json or dart-defines) is local
  // but can take seconds on a cold Play Services; chat push init awaits it
  // again after sign-in, so it no longer holds the splash.
  if (isMobileOs) {
    unawaited(
      _quietly(
        'firebase init',
        ensureFirebaseInitialized(env.firebase).timeout(const Duration(seconds: 10)),
      ),
    );
  }
  if (Platform.isIOS) {
    unawaited(_quietly('ios native config', writeIosNativeConfig(env)));
  }
  // Stale temporary files (opened attachments, recordings) do not pile up.
  unawaited(
    _quietly(
      'temp sweep',
      container.read(storageInspectorProvider).sweepTemporary(const CachePolicy().maxAge),
    ),
  );
  // Android: «Отклонить» while the process is killed still rejects the call.
  if (env.callsEnabled) {
    unawaited(_quietly('call background handlers', registerCallBackgroundHandlers()));
  }
}

/// The OS part of the desktop User-Agent, in the words the Mail API's
/// session list recognises («Мои устройства и сеансы»): Windows, macOS
/// (`Macintosh`) or Linux (`X11; Linux`).
String desktopUserAgentOs() {
  final version = Platform.operatingSystemVersion.replaceAll(RegExp(r'[();"]'), '').trim();
  if (Platform.isWindows) return 'Windows; $version';
  if (Platform.isMacOS) return 'Macintosh; Mac OS X $version';
  return 'X11; Linux $version';
}

Future<void> _quietly(String what, Future<void> future) async {
  try {
    await future;
  } on Object catch (e) {
    DiagnosticLog.warn('app', '$what failed at start', error: e);
  }
}

/// Build and device facts for crash reports (no identifiers of the user).
Future<DeviceSnapshot> _deviceSnapshot(
  PackageInfo info,
  AppEnv env,
  AppPreferences preferences,
) async {
  var model = '';
  var os = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  try {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final a = await plugin.androidInfo.timeout(const Duration(seconds: 2));
      model = '${a.manufacturer} ${a.model}';
      os = 'Android ${a.version.release} (SDK ${a.version.sdkInt})';
    } else if (Platform.isIOS) {
      final i = await plugin.iosInfo.timeout(const Duration(seconds: 2));
      model = i.utsname.machine;
      os = '${i.systemName} ${i.systemVersion}';
    }
  } on Object catch (e) {
    DiagnosticLog.warn('app', 'device info unavailable', error: e);
  }
  return DeviceSnapshot(
    appVersion: info.version,
    appBuild: info.buildNumber,
    flavor: env.flavor.name,
    platform: Platform.operatingSystem,
    osVersion: os,
    deviceModel: model,
    locale:
        preferences.languageCode ??
        PlatformDispatcher.instance.locale.toLanguageTag(),
  );
}
