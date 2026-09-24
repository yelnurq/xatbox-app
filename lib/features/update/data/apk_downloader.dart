import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/utils/diagnostic_log.dart';
import 'update_api.dart';
import 'update_models.dart';

/// The downloaded file does not match the manifest checksum.
class ApkIntegrityException implements Exception {
  const ApkIntegrityException();
  @override
  String toString() => 'ApkIntegrityException';
}

typedef DownloadProgress = void Function(int received, int total);

/// Downloads a release APK into [directory] with resume (`Range`) and
/// verifies its SHA-256 before handing it to the installer.
///
/// Files: `xatbox-<code>-<abi>-<sha8>.apk.part` while loading, renamed to
/// `.apk` once verified. Other versions' files are removed.
class ApkDownloader {
  ApkDownloader({required this.client, required this.directory, this.extension = 'apk'});

  final ApiClient client;
  final Future<Directory> Function() directory;

  /// `apk`, or `exe` for the Windows installer (it must run as a program).
  final String extension;

  static String baseName(AppRelease r) =>
      'xatbox-${r.versionCode}-${r.abi ?? ReleaseAbi.universal}-'
      '${r.file!.sha256.substring(0, 8)}';

  /// A verified APK of [release] that is already on disk, if any.
  Future<File?> existing(AppRelease release) async {
    if (!release.downloadable) return null;
    final file = File('${(await directory()).path}/${baseName(release)}.$extension');
    if (!await file.exists() || await file.length() != release.file!.size) return null;
    return file;
  }

  Future<File> download(
    AppRelease release, {
    DownloadProgress? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (!release.downloadable) {
      throw const UnexpectedApiException('release without a downloadable file');
    }
    final dir = await directory();
    await dir.create(recursive: true);
    final name = baseName(release);
    final done = File('${dir.path}/$name.$extension');
    final part = File('${dir.path}/$name.$extension.part');
    await _removeOthers(dir, name);

    if (await done.exists()) {
      if (await _matches(done, release)) return done;
      await done.delete();
    }
    final expected = release.file!;
    var have = await part.exists() ? await part.length() : 0;
    if (have > expected.size) {
      await part.delete();
      have = 0;
    }
    if (have < expected.size) {
      have = await _fetch(release, part, have, onProgress, cancelToken);
    }
    onProgress?.call(have, expected.size);
    if (!await _matches(part, release)) {
      await part.delete();
      throw const ApkIntegrityException();
    }
    return part.rename(done.path);
  }

  Future<int> _fetch(
    AppRelease release,
    File part,
    int offset,
    DownloadProgress? onProgress,
    CancelToken? cancelToken,
  ) async {
    final total = release.file!.size;
    final path = UpdateApi.relativeDownloadPath(release.downloadPath!);
    final res = await client.send<ResponseBody>(
      () => client.dio.get<ResponseBody>(
        path,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(minutes: 2),
          headers: {
            'Accept': 'application/vnd.android.package-archive',
            if (offset > 0) 'Range': 'bytes=$offset-',
            if (offset > 0) 'If-Range': '"${release.file!.sha256}"',
          },
        ),
      ),
      expectedStatuses: const {200, 206, 416},
    );
    final status = res.statusCode ?? 0;
    if (status == 416) {
      // Nothing left to send: the part file is complete (or stale).
      await res.data?.stream.drain<void>();
      return offset;
    }
    final resumed = status == 206;
    if (!resumed) offset = 0;
    DiagnosticLog.info('update', resumed ? 'download resumed at $offset' : 'download started');
    final sink = part.openWrite(mode: resumed ? FileMode.append : FileMode.write);
    var received = offset;
    try {
      await for (final chunk in res.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
    } on DioException catch (e) {
      throw ApiClient.mapDioException(e);
    } finally {
      await sink.flush();
      await sink.close();
    }
    return received;
  }

  static Future<bool> _matches(File file, AppRelease release) async {
    if (await file.length() != release.file!.size) return false;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == release.file!.sha256;
  }

  static Future<void> _removeOthers(Directory dir, String keep) async {
    try {
      await for (final e in dir.list()) {
        final n = e.uri.pathSegments.last;
        if (e is File && n.startsWith('xatbox-') && !n.startsWith(keep)) {
          await e.delete();
        }
      }
    } on FileSystemException catch (e) {
      DiagnosticLog.warn('update', 'old APKs not removed', error: e);
    }
  }

  /// Removes every downloaded APK (after a successful update or sign-out).
  Future<void> clear() async {
    final dir = await directory();
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
