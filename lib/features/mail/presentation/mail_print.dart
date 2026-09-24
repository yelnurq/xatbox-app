import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/utils/diagnostic_log.dart';
import '../data/mail_models.dart';
import 'mail_html.dart';

/// Labels of the printed header, in the app's language.
class MailPrintLabels {
  const MailPrintLabels({
    required this.from,
    required this.to,
    required this.cc,
    required this.date,
    required this.attachments,
    required this.noSubject,
  });
  final String from;
  final String to;
  final String cc;
  final String date;
  final String attachments;
  final String noSubject;
}

/// The message as a standalone page that opens the print dialog on load
/// (pure, unit-tested). The body is prepared like on screen (MailHtml: the
/// sender's layout, pictures), and the page's Content-Security-Policy allows
/// nothing but styles, pictures and the one print script, so nothing in the
/// message can run.
String mailPrintHtml(
  MailMessageDetail d, {
  required MailPrintLabels labels,
  required String date,
  required String language,
  required String nonce,
  Map<String, String> cidFiles = const {},
}) {
  const e = HtmlEscape();
  final subject = d.subject.trim().isEmpty ? labels.noSubject : d.subject;
  final sender = d.fromDisplay.isNotEmpty && d.fromDisplay != d.from ? '${d.fromDisplay} <${d.from}>' : d.from;
  String row(String label, String value) => value.isEmpty ? '' : '<tr><td>${e.convert(label)}</td><td>${e.convert(value)}</td></tr>';
  final html = MailHtml.htmlOf(bodyHtml: d.bodyHtml, bodyText: d.bodyText);
  final body = html != null ? MailHtml.prepare(html, cidFiles: cidFiles) : '<pre>${e.convert(d.bodyText)}</pre>';
  final attachments = d.attachments.isEmpty
      ? ''
      : '<hr><p class="files">${e.convert(labels.attachments)}: '
            '${d.attachments.map((a) => e.convert(a.filename)).join(', ')}</p>';
  return '''<!doctype html>
<html lang="${e.convert(language)}">
<head>
<meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data: https: http: file:; style-src 'unsafe-inline'; script-src 'nonce-$nonce'">
<title>${e.convert(subject)}</title>
<style>
body{font:14px/1.5 "Segoe UI",Arial,sans-serif;color:#111;margin:24px}
h1{font-size:20px;line-height:1.3;margin:0 0 12px}
table.head{border-collapse:collapse;margin-bottom:8px}
table.head td{padding:2px 16px 2px 0;vertical-align:top}
table.head td:first-child{color:#555;white-space:nowrap}
hr{border:0;border-top:1px solid #ccc;margin:12px 0}
.body{overflow-wrap:anywhere}
.body img{max-width:100%;height:auto}
pre{white-space:pre-wrap;font:inherit;margin:0}
.files{color:#555}
@media print{body{margin:0}}
</style>
</head>
<body>
<h1>${e.convert(subject)}</h1>
<table class="head">
${row(labels.from, sender)}
${row(labels.to, d.to.join(', '))}
${row(labels.cc, d.cc.join(', '))}
${row(labels.date, date)}
</table>
<hr>
<div class="body">$body</div>
$attachments
<script nonce="$nonce">addEventListener('load',function(){setTimeout(function(){print()},300)});</script>
</body>
</html>
''';
}

/// Desktop «Печать» (Ctrl+P): writes the page to the temp folder and opens
/// it in the default browser, whose print dialog also saves a PDF. Returns
/// false when the page could not be opened.
Future<bool> printMailMessage(
  MailMessageDetail d, {
  required MailPrintLabels labels,
  required String date,
  required String language,
}) async {
  try {
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'print'));
    // One page at a time: earlier ones were printed already.
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final random = Random.secure();
    final nonce = base64Url.encode(List<int>.generate(18, (_) => random.nextInt(256)));
    final file = File(p.join(dir.path, 'xatbox-message-${DateTime.now().millisecondsSinceEpoch}.html'));
    await file.writeAsString(mailPrintHtml(d, labels: labels, date: date, language: language, nonce: nonce));
    return await launchUrl(Uri.file(file.path), mode: LaunchMode.externalApplication);
  } on Object catch (e) {
    DiagnosticLog.warn('mail', 'print failed', error: e);
    return false;
  }
}
