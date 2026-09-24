import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/utils/diagnostic_log.dart';

/// Bytes the app keeps on the device (ТЗ п.24.16).
class StorageUsage {
  const StorageUsage({required this.databaseBytes, required this.filesBytes});

  /// Local cache DB (mail lists, chat history, calendar windows…).
  final int databaseBytes;

  /// Downloaded attachments, chat media, voice recordings, temp files.
  final int filesBytes;

  int get totalBytes => databaseBytes + filesBytes;
}

class StorageInspector {
  StorageInspector({
    Future<Directory> Function()? supportDir,
    Future<Directory> Function()? tempDir,
  }) : _supportDir = supportDir ?? getApplicationSupportDirectory,
       _tempDir = tempDir ?? getTemporaryDirectory;

  final Future<Directory> Function() _supportDir;
  final Future<Directory> Function() _tempDir;

  static const databaseFile = 'xatbox_cache.db';

  static Future<int> directorySize(Directory dir) async {
    var total = 0;
    if (!await dir.exists()) return 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } on FileSystemException {
            // Removed while listing.
          }
        }
      }
    } on FileSystemException catch (e) {
      DiagnosticLog.warn('storage', 'size scan failed', error: e);
    }
    return total;
  }

  Future<StorageUsage> measure() async {
    final support = await _supportDir();
    final db = File(p.join(support.path, databaseFile));
    final dbBytes = await db.exists() ? await db.length() : 0;
    final supportBytes = await directorySize(support);
    final tempBytes = await directorySize(await _tempDir());
    return StorageUsage(
      databaseBytes: dbBytes,
      filesBytes: supportBytes - dbBytes + tempBytes,
    );
  }

  /// Deletes temporary files (opened attachments, recordings, picker copies)
  /// not modified for [maxAge]. Returns how many were removed.
  Future<int> sweepTemporary(Duration maxAge, {DateTime? now}) async {
    final dir = await _tempDir();
    if (!await dir.exists()) return 0;
    final cutoff = (now ?? DateTime.now()).subtract(maxAge);
    var removed = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        try {
          if ((await entity.lastModified()).isBefore(cutoff)) {
            await entity.delete();
            removed++;
          }
        } on FileSystemException {
          // In use or already gone.
        }
      }
    } on FileSystemException catch (e) {
      DiagnosticLog.warn('storage', 'temp sweep failed', error: e);
    }
    if (removed > 0) {
      DiagnosticLog.info('storage', 'removed $removed stale temp files');
    }
    return removed;
  }
}

final storageInspectorProvider = Provider<StorageInspector>(
  (_) => StorageInspector(),
);

final storageUsageProvider = FutureProvider.autoDispose<StorageUsage>(
  (ref) => ref.watch(storageInspectorProvider).measure(),
);

/// Sizes with 1024 steps; units are localized by the caller.
enum SizeUnit { b, kb, mb, gb }

(double, SizeUnit) splitBytes(int bytes) {
  var value = bytes.toDouble();
  var unit = SizeUnit.b;
  while (value >= 1024 && unit != SizeUnit.gb) {
    value /= 1024;
    unit = SizeUnit.values[unit.index + 1];
  }
  return (value, unit);
}
