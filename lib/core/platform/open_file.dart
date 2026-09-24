import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/utils/diagnostic_log.dart';
import 'desktop.dart';

enum OpenFileOutcome { opened, noApp, failed }

/// Opens a downloaded file in the app the system associates with it:
/// open_filex on phones (MIME-typed intent / document interaction), the
/// shell's default handler on desktop (open_filex has no desktop
/// implementation). Never throws.
Future<OpenFileOutcome> openLocalFile(String path, {String? mimeType}) async {
  try {
    if (isDesktop) {
      return await launchUrl(Uri.file(path)) ? OpenFileOutcome.opened : OpenFileOutcome.noApp;
    }
    final res = await OpenFilex.open(path, type: mimeType == null || mimeType.isEmpty ? null : mimeType);
    return switch (res.type) {
      ResultType.done => OpenFileOutcome.opened,
      ResultType.noAppToOpen => OpenFileOutcome.noApp,
      _ => OpenFileOutcome.failed,
    };
  } on Object catch (e) {
    DiagnosticLog.warn('files', 'open file failed', error: e);
    return OpenFileOutcome.failed;
  }
}
