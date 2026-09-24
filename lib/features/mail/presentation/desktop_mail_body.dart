import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../../shared/utils/diagnostic_log.dart';
import '../data/mail_models.dart';
import 'mail_html.dart';
import 'mail_providers.dart';

/// The message body, as the web shows it (desktop and phones): the sender's
/// layout (stylesheet inlined, inline styles kept), remote pictures, `cid:`
/// pictures from the attachments, HTML that came as text or as a raw MIME
/// part (MailHtml).
class DesktopMailBody extends ConsumerStatefulWidget {
  const DesktopMailBody({
    super.key,
    required this.detail,
    required this.html,
    required this.textStyle,
    required this.onOpenLink,
    this.customStylesBuilder,
  });

  final MailMessageDetail detail;

  /// MailHtml.htmlOf of the message (not null).
  final String html;
  final TextStyle textStyle;
  final ValueChanged<String> onOpenLink;

  /// Dark skins: the sender's colours lifted to the theme's.
  final CustomStylesBuilder? customStylesBuilder;

  @override
  ConsumerState<DesktopMailBody> createState() => _DesktopMailBodyState();
}

class _DesktopMailBodyState extends ConsumerState<DesktopMailBody> {
  final _cidFiles = <String, String>{};
  String? _prepared;

  @override
  void initState() {
    super.initState();
    _prepare();
    unawaited(_downloadInlinePictures());
  }

  @override
  void didUpdateWidget(DesktopMailBody old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html) {
      _prepare();
      unawaited(_downloadInlinePictures());
    }
  }

  void _prepare() => _prepared = MailHtml.prepare(widget.html, cidFiles: _cidFiles);

  /// The pictures the text draws with `cid:`, fetched with the session like
  /// any attachment; the body redraws once they are on disk.
  Future<void> _downloadInlinePictures() async {
    final wanted = MailHtml.referencedCids(widget.html);
    if (wanted.isEmpty) return;
    final downloader = ref.read(attachmentDownloaderProvider);
    for (final a in widget.detail.attachments) {
      final cid = a.contentId.toLowerCase();
      if (cid.isEmpty || !wanted.contains(cid) || _cidFiles.containsKey(cid)) continue;
      try {
        final file = await downloader.download(a);
        if (!mounted) return;
        setState(() {
          _cidFiles[cid] = file.path;
          _prepare();
        });
      } on Object catch (e) {
        DiagnosticLog.warn('mail', 'inline picture not loaded', error: e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => HtmlWidget(
    _prepared ?? '',
    key: ValueKey('desktop_mail_body_${widget.detail.id}_${_cidFiles.length}'),
    textStyle: widget.textStyle,
    customStylesBuilder: widget.customStylesBuilder,
    onTapUrl: (url) {
      widget.onOpenLink(url);
      return true;
    },
  );
}
