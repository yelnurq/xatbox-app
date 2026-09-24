import 'package:flutter/foundation.dart';

/// ABI keys of the release manifest (`/releases/android/manifest.json`).
abstract final class ReleaseAbi {
  static const arm64 = 'arm64-v8a';
  static const arm32 = 'armeabi-v7a';
  static const x64 = 'x86_64';
  static const universal = 'universal';

  static const known = {arm64, arm32, x64};

  /// The first device ABI (most preferred first, as Android reports them)
  /// that has a split APK; [universal] when none matches.
  static String pick(List<String> supportedAbis) {
    for (final abi in supportedAbis) {
      if (known.contains(abi)) return abi;
    }
    return universal;
  }
}

/// Flutter's `--split-per-abi` adds `1000 × ABI` to the version code
/// (armeabi-v7a 1, arm64-v8a 2, x86_64 4). The manifest carries the plain
/// pubspec build number, so the installed code is reduced to it.
abstract final class VersionCodes {
  static const abiFactor = 1000;

  static int normalize(int installed) =>
      installed >= abiFactor ? installed % abiFactor : installed;

  /// True for a split-per-ABI install: Android refuses to replace it with the
  /// universal APK (its version code is lower).
  static bool isSplit(int installed) => installed >= abiFactor;
}

/// The APK of one ABI in a release.
@immutable
class ReleaseFile {
  const ReleaseFile({
    required this.name,
    required this.size,
    required this.sha256,
  });

  final String name;
  final int size;
  final String sha256;

  static ReleaseFile? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final sha = raw['sha256'];
    final size = raw['size'];
    if (sha is! String || sha.length != 64 || size is! num) return null;
    final name = raw['name'];
    return ReleaseFile(
      name: name is String && name.isNotEmpty ? name : 'xatbox.apk',
      size: size.toInt(),
      sha256: sha.toLowerCase(),
    );
  }
}

/// `GET /app/android/latest` of the Chat Service.
@immutable
class AppRelease {
  const AppRelease({
    required this.available,
    required this.mandatory,
    this.versionName = '',
    this.versionCode = 0,
    this.minSupportedVersionCode = 0,
    this.publishedAt,
    this.notes = const {},
    this.abi,
    this.file,
    this.downloadPath,
    this.rollback = false,
  });

  /// Nothing published on the server.
  static const none = AppRelease(available: false, mandatory: false);

  final bool available;
  final bool mandatory;
  final String versionName;
  final int versionCode;
  final int minSupportedVersionCode;
  final DateTime? publishedAt;

  /// «Что нового» by language code (ru / en / kk).
  final Map<String, String> notes;
  final String? abi;
  final ReleaseFile? file;
  final String? downloadPath;

  /// Desktop: an earlier build restored on the server after a bad one
  /// (backend/deploy/rollback-desktop.sh). Apps running a newer build
  /// install it; otherwise an app never goes back to a lower version.
  final bool rollback;

  bool get hasRelease => versionCode > 0;
  bool get downloadable => file != null && downloadPath != null;

  /// Notes in [languageCode], falling back to Russian, then any language.
  String notesFor(String languageCode) {
    String? pick(String code) {
      final v = notes[code]?.trim();
      return v == null || v.isEmpty ? null : v;
    }

    return pick(languageCode) ??
        pick('ru') ??
        notes.values.map((v) => v.trim()).where((v) => v.isNotEmpty).firstOrNull ??
        '';
  }

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final notes = <String, String>{};
    final rawNotes = json['notes'];
    if (rawNotes is Map) {
      rawNotes.forEach((k, v) {
        if (k is String && v is String) notes[k] = v;
      });
    }
    int integer(Object? v) => v is num ? v.toInt() : 0;
    final published = json['published_at'];
    final path = json['download_path'];
    return AppRelease(
      available: json['available'] == true,
      mandatory: json['mandatory'] == true,
      versionName: (json['version_name'] as String?) ?? '',
      versionCode: integer(json['version_code']),
      minSupportedVersionCode: integer(json['min_supported_version_code']),
      publishedAt: published is String ? DateTime.tryParse(published) : null,
      notes: notes,
      abi: json['abi'] as String?,
      file: ReleaseFile.fromJson(json['file']),
      downloadPath: path is String && path.isNotEmpty ? path : null,
      rollback: json['rollback'] == true,
    );
  }

  Map<String, Object?> toJson() => {
    'available': available,
    'mandatory': mandatory,
    'version_name': versionName,
    'version_code': versionCode,
    'min_supported_version_code': minSupportedVersionCode,
    'published_at': publishedAt?.toUtc().toIso8601String(),
    'notes': notes,
    'abi': abi,
    if (file != null)
      'file': {'name': file!.name, 'size': file!.size, 'sha256': file!.sha256},
    'download_path': downloadPath,
    if (rollback) 'rollback': true,
  };

  /// Re-evaluates [available] / [mandatory] for the installed build (the
  /// cached answer may be older than an update installed since).
  /// [split]: Android build numbers carry 1000*ABI (Windows numbers do not).
  /// A lower build is available only as a [rollback].
  AppRelease forInstalled(int installedCode, {bool split = true}) {
    final code = split ? VersionCodes.normalize(installedCode) : installedCode;
    return AppRelease(
      available: versionCode > code || (rollback && code > versionCode),
      mandatory: code > 0 && code < minSupportedVersionCode,
      versionName: versionName,
      versionCode: versionCode,
      minSupportedVersionCode: minSupportedVersionCode,
      publishedAt: publishedAt,
      notes: notes,
      abi: abi,
      file: file,
      downloadPath: downloadPath,
      rollback: rollback,
    );
  }
}

/// The running build, as the update check sees it.
@immutable
class InstalledApp {
  const InstalledApp({
    required this.versionName,
    required this.buildNumber,
    this.supportedAbis = const [],
    this.isAndroid = false,
    this.isWindows = false,
    this.isMacOS = false,
    this.isLinux = false,
    this.managedByAdmin = false,
  });

  final String versionName;

  /// Raw Android version code (includes the split-APK ABI offset).
  final int buildNumber;
  final List<String> supportedAbis;
  final bool isAndroid;

  /// The Windows desktop app: updated by its Inno Setup installer.
  final bool isWindows;

  /// The macOS desktop app: its XatBox.app is replaced from a zip.
  final bool isMacOS;

  /// The Linux desktop app: the user installs the downloaded .deb with the
  /// system's package installer (no silent install).
  final bool isLinux;

  /// A desktop build: plain build numbers, the user picks when to restart.
  bool get isDesktopApp => isWindows || isMacOS || isLinux;

  /// Windows: installed for all users of the computer (Program Files, by an
  /// administrator or Intune/GPO). The IT department rolls out new versions;
  /// a per-user update would only put a second copy next to it.
  final bool managedByAdmin;

  /// Builds that update themselves from the Chat Service.
  bool get updatable => isAndroid || (isWindows && !managedByAdmin) || isMacOS || isLinux;

  /// `/app/<platform>/…` of the Chat Service.
  String get platform => isWindows ? 'windows' : (isMacOS ? 'macos' : (isLinux ? 'linux' : 'android'));

  int get versionCode => isDesktopApp ? buildNumber : VersionCodes.normalize(buildNumber);
  String get abi => isWindows || isLinux ? 'x64' : (isMacOS ? 'universal' : ReleaseAbi.pick(supportedAbis));
  String get label => '$versionName ($versionCode)';
}

/// Windows: [exe] lies in Program Files, where only an all-users install
/// puts XatBox (pure, unit-tested). [environment] as Platform.environment.
bool isMachineWideInstall(String exe, Map<String, String> environment) {
  String norm(String path) => path.replaceAll('/', r'\').toLowerCase();
  final path = norm(exe);
  for (final key in const ['ProgramFiles', 'ProgramFiles(x86)', 'ProgramW6432']) {
    final dir = environment[key] ?? environment[key.toUpperCase()];
    if (dir == null || dir.trim().isEmpty) continue;
    final root = norm(dir.trim());
    if (path.startsWith(root.endsWith(r'\') ? root : '$root\\')) return true;
  }
  return false;
}
