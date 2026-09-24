import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../shared/utils/diagnostic_log.dart';
import 'mail_api.dart';
import 'mail_models.dart';

/// Downloads attachments **only on explicit user action** into the
/// app-private temporary directory (ТЗ п.24.5, п.24.16, п.24.24) and returns
/// the local path for opening with the system viewer.
class AttachmentDownloader {
  AttachmentDownloader(this._api);
  final MailApi _api;

  static const _subdir = 'xatbox_attachments';

  Future<Directory> _dir() async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory(p.join(tmp.path, _subdir));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _safeName(String name, {String fallback = 'attachment'}) {
    final base = p
        .basename(name)
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .trim();
    return base.isEmpty ? fallback : base;
  }

  /// Original bytes via `GET /mail/blob/{id}`.
  Future<File> download(
    MailAttachment attachment, {
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = await _dir();
    final file = File(
      p.join(dir.path, '${attachment.id}_${_safeName(attachment.filename)}'),
    );
    await _api.downloadBlob(
      attachment,
      savePath: file.path,
      onProgress: onProgress,
    );
    DiagnosticLog.info(
      'mail',
      'attachment downloaded (${attachment.sizeBytes} bytes)',
    );
    return file;
  }

  /// PDF rendering of an office document via `GET /mail/blob/{id}/pdf`.
  Future<File> downloadAsPdf(
    MailAttachment attachment, {
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = await _dir();
    final stem = p.basenameWithoutExtension(
      _safeName(attachment.filename, fallback: 'preview'),
    );
    final file = File(p.join(dir.path, '${attachment.id}_$stem.pdf'));
    await _api.downloadBlobAsPdf(
      attachment,
      savePath: file.path,
      onProgress: onProgress,
    );
    DiagnosticLog.info('mail', 'attachment previewed as pdf');
    return file;
  }

  /// Temporary files should not accumulate (ТЗ п.24.24).
  Future<void> clearTemporaryFiles() async {
    try {
      final dir = await _dir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException catch (e) {
      DiagnosticLog.warn('mail', 'temp cleanup failed', error: e);
    }
  }
}
