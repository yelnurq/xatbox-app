import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/platform/desktop.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/security/app_lock.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../../shared/utils/error_text.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/feedback_api.dart';
import 'shake_to_report.dart';
import '../../../shared/widgets/app_sheet.dart';

/// «Сообщить о проблеме»: category, description, optional screenshot and
/// diagnostics → `POST /feedback` of the Chat Service.
class ReportProblemScreen extends ConsumerStatefulWidget {
  const ReportProblemScreen({super.key, this.screenshot});

  /// Captured by shake-to-report before the form opened.
  final FeedbackScreenshot? screenshot;

  static const maxDescription = 4000;

  @override
  ConsumerState<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends ConsumerState<ReportProblemScreen> {
  final _description = TextEditingController();
  FeedbackCategory _category = FeedbackCategory.bug;
  FeedbackScreenshot? _screenshot;
  bool _diagnostics = true;
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _screenshot = widget.screenshot;
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  bool get _canSend => !_sending && _description.text.trim().isNotEmpty;

  Future<void> _pick() async {
    try {
      ref.read(appLockProvider.notifier).expectExternalActivity();
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final name = file.name.toLowerCase().endsWith('.png') ? 'screenshot.png' : 'screenshot.jpg';
      setState(() => _screenshot = FeedbackScreenshot(bytes, filename: name));
    } on Object catch (e) {
      DiagnosticLog.warn('feedback', 'image not picked', error: e);
    }
  }

  Future<void> _send() async {
    if (!_canSend) return;
    final l10n = context.l10n;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final diagnostics = _diagnostics ? await ref.read(feedbackDiagnosticsProvider.future) : null;
      await ref.read(feedbackApiProvider).send(
        category: _category,
        description: _description.text,
        diagnostics: diagnostics,
        screenshot: _screenshot,
      );
      if (mounted) setState(() => _sent = true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e is ApiException && e.statusCode == 429 ? l10n.reportRateLimited : ErrorText.describe(l10n, e),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showDiagnostics() async {
    final l10n = context.l10n;
    final d = await ref.read(feedbackDiagnosticsProvider.future);
    if (!mounted) return;
    final pretty = const JsonEncoder.withIndent('  ').convert(d.toPayload()..remove('diagnostics'));
    await showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
          children: [
            Text(l10n.reportDiagnosticsShow, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: Space.md),
            SelectableText(
              '$pretty\n\n${d.log}',
              style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11, color: ctx.tokens.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final enabled = ref.watch(chatEnabledProvider);

    if (_sent) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.reportTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              key: const Key('report_sent'),
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(color: t.successSoft, shape: BoxShape.circle),
                    child: Icon(LucideIcons.check, color: t.success, size: 44),
                  ),
                ),
                const SizedBox(height: Space.lg),
                Text(l10n.reportSentTitle, style: text.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: Space.sm),
                Text(l10n.reportSent, style: text.bodyMedium?.copyWith(color: t.textSecondary), textAlign: TextAlign.center),
                const SizedBox(height: Space.lg),
                FilledButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(l10n.reportDone)),
              ],
            ),
          ),
        ),
      );
    }

    final categories = [
      (FeedbackCategory.bug, LucideIcons.bug, l10n.reportCategoryBug),
      (FeedbackCategory.idea, LucideIcons.lightbulb, l10n.reportCategoryIdea),
      (FeedbackCategory.question, LucideIcons.circleHelp, l10n.reportCategoryQuestion),
      (FeedbackCategory.other, LucideIcons.messageSquare, l10n.reportCategoryOther),
    ];

    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(top: Space.lg, bottom: Space.sm),
      child: Text(s, style: text.titleSmall),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportTitle)),
      body: !enabled
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Text(l10n.reportUnavailable, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.xl),
              children: [
                label(l10n.reportCategory),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    for (final (value, icon, name) in categories)
                      ChoiceChip(
                        key: Key('report_category_${value.name}'),
                        avatar: Icon(icon, size: 16, color: _category == value ? t.primary : t.textSecondary),
                        showCheckmark: false,
                        label: Text(name),
                        selected: _category == value,
                        onSelected: (_) => setState(() => _category = value),
                      ),
                  ],
                ),
                label(l10n.reportDescription),
                TextField(
                  key: const Key('report_description'),
                  controller: _description,
                  minLines: 5,
                  maxLines: 12,
                  maxLength: ReportProblemScreen.maxDescription,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(hintText: l10n.reportDescriptionHint, alignLabelWithHint: true),
                ),
                label(l10n.reportScreenshot),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _screenshot == null
                      ? OutlinedButton.icon(
                          key: const Key('report_attach'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(64),
                            side: BorderSide(color: t.borderStrong, style: BorderStyle.solid),
                          ),
                          onPressed: _pick,
                          icon: const Icon(LucideIcons.imagePlus, size: 20),
                          label: Text(l10n.reportScreenshotAttach),
                        )
                      : _ScreenshotPreview(
                          key: const Key('report_screenshot'),
                          screenshot: _screenshot!,
                          onRemove: () => setState(() => _screenshot = null),
                          onReplace: _pick,
                        ),
                ),
                const SizedBox(height: Space.md),
                Material(
                  color: t.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.radiusLg),
                    side: BorderSide(color: t.border, width: t.borderWidth),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const Key('report_diagnostics'),
                        secondary: const Icon(LucideIcons.activity),
                        title: Text(l10n.reportDiagnostics),
                        subtitle: Text(l10n.reportDiagnosticsHint),
                        value: _diagnostics,
                        onChanged: (v) => setState(() => _diagnostics = v),
                      ),
                      if (_diagnostics)
                        ListTile(
                          dense: true,
                          leading: const SizedBox(width: 24),
                          title: Text(l10n.reportDiagnosticsShow, style: TextStyle(color: t.primary)),
                          trailing: Icon(LucideIcons.chevronRight, size: 16, color: t.primary),
                          onTap: _showDiagnostics,
                        ),
                      // Shaking is a phone gesture (no sensor on a computer).
                      if (!isDesktop) ...[
                        Divider(height: 1, color: t.divider),
                        SwitchListTile(
                          key: const Key('report_shake'),
                          secondary: const Icon(LucideIcons.vibrate),
                          title: Text(l10n.reportShake),
                          subtitle: Text(l10n.reportShakeHint),
                          value: ref.watch(shakeToReportProvider),
                          onChanged: (v) => ref.read(shakeToReportProvider.notifier).set(v),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: Space.md),
                  Text(_error!, key: const Key('report_error'), style: TextStyle(color: t.danger)),
                ],
                const SizedBox(height: Space.lg),
                SizedBox(
                  height: Space.controlLg + 8,
                  child: FilledButton.icon(
                    key: const Key('report_send'),
                    onPressed: _canSend ? _send : null,
                    icon: _sending
                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: t.textInverse))
                        : const Icon(LucideIcons.send, size: 18),
                    label: Text(l10n.reportSend),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ScreenshotPreview extends StatelessWidget {
  const _ScreenshotPreview({super.key, required this.screenshot, required this.onRemove, required this.onReplace});

  final FeedbackScreenshot screenshot;
  final VoidCallback onRemove;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(t.radiusMd),
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: t.border, width: t.borderWidth)),
            child: Image.memory(screenshot.bytes, height: 180, fit: BoxFit.contain, gaplessPlayback: true),
          ),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: onReplace,
                icon: const Icon(LucideIcons.imagePlus, size: 16),
                label: Text(l10n.reportScreenshotAttach),
              ),
              TextButton.icon(
                key: const Key('report_screenshot_remove'),
                style: TextButton.styleFrom(foregroundColor: t.danger),
                onPressed: onRemove,
                icon: const Icon(LucideIcons.trash2, size: 16),
                label: Text(l10n.reportScreenshotRemove),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
