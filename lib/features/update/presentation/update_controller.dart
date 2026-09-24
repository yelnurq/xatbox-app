import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/security/app_lock.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/apk_downloader.dart';
import '../data/apk_installer.dart';
import '../data/update_api.dart';
import '../data/update_models.dart';
import '../data/update_store.dart';
import '../../../core/platform/desktop.dart';
import '../../../core/platform/desktop_settings.dart';

enum UpdatePhase {
  /// Not checked in this run yet.
  idle,

  /// Updates come only through the Chat Service on Android.
  unsupported,
  checking,
  upToDate,
  available,
  downloading,

  /// Verified APK on disk, waiting for the installer.
  ready,

  /// The system installer is (or was) on screen.
  installing,

  /// «Install unknown apps» must be allowed for XatBox first.
  needsPermission,
  failed,
}

@immutable
class UpdateState {
  const UpdateState({
    this.phase = UpdatePhase.idle,
    this.release,
    this.installed,
    this.received = 0,
    this.total = 0,
    this.error,
    this.checkedAt,
    this.apkPath,
    this.installOnQuit = false,
  });

  final UpdatePhase phase;
  final AppRelease? release;
  final InstalledApp? installed;
  final int received;
  final int total;
  final Object? error;
  final DateTime? checkedAt;
  final String? apkPath;

  /// Windows: the downloaded update installs when the user quits XatBox
  /// («Обновить при выходе»).
  final bool installOnQuit;

  double? get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : null;
  bool get mandatory => release?.mandatory == true;
  bool get hasUpdate => release?.available == true;
  bool get busy =>
      phase == UpdatePhase.checking || phase == UpdatePhase.downloading;

  /// The installed build cannot take the offered file (split install vs a
  /// universal-only release: Android would call it a downgrade).
  bool get incompatible {
    final i = installed;
    final r = release;
    if (i == null || r == null || !r.available) return false;
    if (!r.downloadable) return true;
    return VersionCodes.isSplit(i.buildNumber) && r.abi == ReleaseAbi.universal;
  }

  UpdateState copyWith({
    UpdatePhase? phase,
    AppRelease? release,
    InstalledApp? installed,
    int? received,
    int? total,
    Object? error,
    bool clearError = false,
    DateTime? checkedAt,
    String? apkPath,
    bool clearApk = false,
    bool? installOnQuit,
  }) => UpdateState(
    phase: phase ?? this.phase,
    release: release ?? this.release,
    installed: installed ?? this.installed,
    received: received ?? this.received,
    total: total ?? this.total,
    error: clearError ? null : (error ?? this.error),
    checkedAt: checkedAt ?? this.checkedAt,
    apkPath: clearApk ? null : (apkPath ?? this.apkPath),
    installOnQuit: installOnQuit ?? this.installOnQuit,
  );
}

/// Whether «Обновление приложения» is offered: APKs on Android and the
/// installer on Windows (iOS updates come through TestFlight / the App Store).
final appUpdatesSupportedProvider = Provider<bool>(
  (ref) =>
      ref.watch(installedAppProvider).value?.updatable ??
      (defaultTargetPlatform == TargetPlatform.android ||
          isDesktop && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)),
);

/// Desktop «Получать бета-версии»: the update check asks for the beta
/// channel (never on phones).
final updateBetaChannelProvider = Provider<bool>(
  (ref) => isDesktop && ref.watch(desktopSettingsProvider.select((s) => s.betaUpdates)),
);

/// The running build; tests override it.
final installedAppProvider = FutureProvider<InstalledApp>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final android = !kIsWeb && Platform.isAndroid;
  final windows = isDesktop && Platform.isWindows;
  var abis = const <String>[];
  if (android) {
    try {
      abis = (await DeviceInfoPlugin().androidInfo.timeout(
        const Duration(seconds: 3),
      )).supportedAbis;
    } on Object catch (e) {
      DiagnosticLog.warn('update', 'device ABIs unknown', error: e);
    }
  }
  return InstalledApp(
    versionName: info.version,
    buildNumber: int.tryParse(info.buildNumber) ?? 0,
    supportedAbis: abis,
    isAndroid: android,
    isWindows: windows,
    isMacOS: isDesktop && Platform.isMacOS,
    isLinux: isDesktop && Platform.isLinux,
    managedByAdmin: windows && isMachineWideInstall(Platform.resolvedExecutable, Platform.environment),
  );
});

final updateApiProvider = Provider<UpdateApi>(
  (ref) => UpdateApi(ref.watch(chatApiClientProvider)),
);

final updateStoreProvider = Provider<UpdateStore>(
  (ref) => UpdateStore(ref.watch(appDatabaseProvider)),
);

final apkDownloaderProvider = Provider<ApkDownloader>(
  (ref) => ApkDownloader(
    client: ref.watch(chatApiClientProvider),
    directory: () async =>
        Directory('${(await getTemporaryDirectory()).path}/updates'),
    extension: isDesktop && Platform.isWindows
        ? 'exe'
        : (isDesktop && Platform.isMacOS ? 'zip' : (isDesktop && Platform.isLinux ? 'deb' : 'apk')),
  ),
);

final apkInstallerProvider = Provider<ApkInstaller>(
  (_) => isDesktop && Platform.isWindows
      ? WindowsSetupInstaller(quit: DesktopTray.instance.quit)
      : isDesktop && Platform.isMacOS
      ? MacAppInstaller(quit: DesktopTray.instance.quit)
      : isDesktop && Platform.isLinux
      ? LinuxPackageInstaller(downloads: getDownloadsDirectory)
      : const ChannelApkInstaller(),
);

final updateClockProvider = Provider<DateTime Function()>(
  (_) => () => DateTime.now().toUtc(),
);

/// In-app updates without Google Play: `GET /app/android/latest` on launch
/// (at most every [checkInterval]) and from Settings, download with resume
/// and SHA-256 check, then the Android package installer.
class UpdateController extends Notifier<UpdateState> {
  static const checkInterval = Duration(hours: 6);

  CancelToken? _cancel;
  Future<void>? _checking;

  @override
  UpdateState build() {
    ref.onDispose(() => _cancel?.cancel());
    return const UpdateState();
  }

  DateTime _now() => ref.read(updateClockProvider)();
  UpdateStore get _store => ref.read(updateStoreProvider);

  Future<InstalledApp?> _installed() async {
    try {
      final app = await ref.read(installedAppProvider.future);
      if (!ref.mounted) return null;
      if (!app.updatable || !ref.read(chatEnabledProvider)) {
        state = state.copyWith(phase: UpdatePhase.unsupported, installed: app);
        return null;
      }
      return app;
    } on Object catch (e) {
      DiagnosticLog.warn('update', 'installed version unknown', error: e);
      if (ref.mounted) state = state.copyWith(phase: UpdatePhase.unsupported);
      return null;
    }
  }

  /// Launch / resume check: the cached answer when checked less than
  /// [checkInterval] ago, a server round trip otherwise. Returns true when
  /// the answer is fresh from the server.
  Future<bool> checkIfDue() async {
    final app = await _installed();
    if (app == null || !ref.mounted) return false;
    final last = await _store.checkedAt();
    if (!ref.mounted) return false;
    if (last != null && _now().difference(last) < checkInterval) {
      if (state.phase == UpdatePhase.idle) {
        final cached = (await _store.release())?.forInstalled(app.buildNumber, split: !app.isDesktopApp);
        if (!ref.mounted) return false;
        state = state.copyWith(
          phase: cached?.available == true ? UpdatePhase.available : UpdatePhase.upToDate,
          release: cached,
          installed: app,
          checkedAt: last,
        );
      }
      return false;
    }
    await check();
    return ref.mounted && state.phase != UpdatePhase.failed;
  }

  /// Asks the server now (Settings «Проверить обновления»).
  Future<void> check() => _checking ??= _check().whenComplete(() => _checking = null);

  Future<void> _check() async {
    final app = await _installed();
    if (app == null || !ref.mounted) return;
    if (state.phase == UpdatePhase.downloading) return;
    state = state.copyWith(phase: UpdatePhase.checking, installed: app, clearError: true);
    try {
      final answer = await ref.read(updateApiProvider).latest(
        abi: app.abi,
        versionCode: app.versionCode,
        platform: app.platform,
        beta: app.isDesktopApp && ref.read(updateBetaChannelProvider),
      );
      // Desktop: never a lower build unless the server rolled back. Only
      // «available» is decided here; «mandatory» stays the server's word.
      final release = app.isDesktopApp ? _desktopAnswer(answer, app.buildNumber) : answer;
      final now = _now();
      await _store.saveCheck(release, now);
      if (!ref.mounted) return;
      final ready = release.available
          ? await ref.read(apkDownloaderProvider).existing(release)
          : null;
      if (!release.available) {
        unawaited(ref.read(apkDownloaderProvider).clear().catchError((Object _) {}));
      }
      if (!ref.mounted) return;
      state = UpdateState(
        phase: !release.available
            ? UpdatePhase.upToDate
            : (ready != null ? UpdatePhase.ready : UpdatePhase.available),
        release: release,
        installed: app,
        checkedAt: now,
        apkPath: ready?.path,
        received: ready != null ? release.file!.size : 0,
        total: release.file?.size ?? 0,
      );
      DiagnosticLog.info(
        'update',
        'checked: installed=${app.versionCode} latest=${release.versionCode} '
            'mandatory=${release.mandatory}',
      );
    } on Object catch (e) {
      DiagnosticLog.warn('update', 'update check failed', error: e);
      if (!ref.mounted) return;
      // A failed check keeps the last known release (mandatory gate).
      final cached = state.release ??
          (await _store.release())?.forInstalled(app.buildNumber, split: !app.isDesktopApp);
      if (!ref.mounted) return;
      state = state.copyWith(phase: UpdatePhase.failed, error: e, release: cached);
    }
  }

  Future<void> download() async {
    final release = state.release;
    if (release == null || !release.downloadable || state.phase == UpdatePhase.downloading) {
      return;
    }
    final cancel = _cancel = CancelToken();
    state = state.copyWith(
      phase: UpdatePhase.downloading,
      received: 0,
      total: release.file!.size,
      clearError: true,
      clearApk: true,
    );
    var lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      final file = await ref.read(apkDownloaderProvider).download(
        release,
        cancelToken: cancel,
        onProgress: (received, total) {
          final now = DateTime.now();
          if (!ref.mounted || now.difference(lastEmit).inMilliseconds < 100 && received < total) {
            return;
          }
          lastEmit = now;
          state = state.copyWith(received: received, total: total);
        },
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: UpdatePhase.ready,
        apkPath: file.path,
        received: release.file!.size,
      );
      DiagnosticLog.info('update', 'APK ${release.versionCode} downloaded and verified');
      // Windows: installing restarts the app, so the user picks the moment
      // («Перезапустить и обновить» / «Обновить при выходе»); a mandatory
      // update cannot wait. Linux: the package opens in the system
      // installer right away (the app keeps running).
      final installed = state.installed;
      if (installed?.isDesktopApp == true && installed?.isLinux != true && !release.mandatory) return;
      await install();
    } on Object catch (e) {
      if (!ref.mounted) return;
      if (cancel.isCancelled) {
        state = state.copyWith(phase: UpdatePhase.available, clearError: true);
        return;
      }
      DiagnosticLog.warn('update', 'download failed', error: e);
      state = state.copyWith(phase: UpdatePhase.failed, error: e);
    } finally {
      if (identical(_cancel, cancel)) _cancel = null;
    }
  }

  /// Stops the download; the part file stays for a resume.
  void cancelDownload() => _cancel?.cancel();

  /// The installer was started in this run (now or on quit).
  bool _installerStarted = false;
  bool _quitHook = false;

  Future<void> install() async {
    final path = state.apkPath;
    if (path == null) return;
    final installer = ref.read(apkInstallerProvider);
    if (!await installer.canRequestInstalls()) {
      if (ref.mounted) state = state.copyWith(phase: UpdatePhase.needsPermission);
      return;
    }
    _installerStarted = true;
    // The installer (and, after the update, the new build) must not be
    // followed by the PIN screen for a cancelled installation.
    ref.read(appLockProvider.notifier).expectExternalActivity();
    final result = await installer.install(path);
    if (!ref.mounted) return;
    state = state.copyWith(
      phase: switch (result) {
        InstallStart.started => UpdatePhase.installing,
        InstallStart.needsPermission => UpdatePhase.needsPermission,
        InstallStart.failed => UpdatePhase.failed,
      },
      error: result == InstallStart.failed ? const InstallFailedException() : null,
    );
  }

  /// Windows «Обновить при выходе»: the tray's «Выйти» runs the installer
  /// silently, without starting XatBox again.
  void installOnQuit() {
    if (state.phase != UpdatePhase.ready || state.apkPath == null) return;
    state = state.copyWith(installOnQuit: true);
    if (_quitHook) return;
    _quitHook = true;
    DesktopTray.instance.addBeforeQuit(() async {
      final path = state.apkPath;
      if (!ref.mounted || _installerStarted || !state.installOnQuit || path == null) return;
      _installerStarted = true;
      final installer = ref.read(apkInstallerProvider);
      if (installer is QuitInstaller) await (installer as QuitInstaller).installAfterQuit(path);
    });
  }

  Future<void> openInstallSettings() {
    ref.read(appLockProvider.notifier).expectExternalActivity();
    return ref.read(apkInstallerProvider).openInstallSettings();
  }

  /// Back from the system settings or a dismissed installer.
  Future<void> onResume() async {
    switch (state.phase) {
      case UpdatePhase.needsPermission:
        if (await ref.read(apkInstallerProvider).canRequestInstalls()) {
          await install();
        }
      case UpdatePhase.installing:
        // Still running this build: the installer was cancelled.
        if (ref.mounted) state = state.copyWith(phase: UpdatePhase.ready);
      default:
        break;
    }
  }

  /// «Позже» on the launch sheet: not offered again for this version.
  Future<void> postpone() async {
    final code = state.release?.versionCode;
    if (code != null) await _store.postpone(code);
  }

  /// Whether the launch sheet should appear for the current answer.
  static AppRelease _desktopAnswer(AppRelease answer, int installed) {
    final available = answer.forInstalled(installed, split: false).available;
    return AppRelease.fromJson({
      ...answer.toJson(),
      'available': available,
      'mandatory': answer.mandatory && available,
    });
  }

  Future<bool> shouldPrompt() async {
    final r = state.release;
    if (r == null || !r.available || r.mandatory || state.incompatible) return false;
    final postponed = await _store.postponedCode();
    // A rollback is below the postponed (withdrawn) build.
    return r.rollback ? postponed != r.versionCode : postponed < r.versionCode;
  }
}

class InstallFailedException implements Exception {
  const InstallFailedException();
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);
