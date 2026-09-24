import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../../chat/data/chat_translation.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../chat/presentation/messenger2_providers.dart';
import '../../chat/presentation/translation/translation_providers.dart';

/// «Перевести письмо»: the plain text of the body (sanitized HTML flattened
/// to text, paragraphs kept) translated through chat-service `POST
/// /translate`, piece by piece, shown instead of the original body. The Mail
/// API has no translator; the item is hidden when the user has no chat
/// access or chat-service reports `translation: false`.

/// Translations of opened letters in this session, by `messageId|target`
/// (reset on sign-out with the chat repository).
final mailTranslationsProvider = Provider<Map<String, ChatTranslationResult>>((
  ref,
) {
  ref.watch(chatRepositoryProvider);
  return <String, ChatTranslationResult>{};
});

class MailTranslationView extends ConsumerStatefulWidget {
  const MailTranslationView({
    super.key,
    required this.messageId,
    required this.text,
    required this.onShowOriginal,
  });
  final String messageId;
  final String text;
  final VoidCallback onShowOriginal;

  @override
  ConsumerState<MailTranslationView> createState() =>
      _MailTranslationViewState();
}

class _MailTranslationViewState extends ConsumerState<MailTranslationView> {
  ChatTranslationResult? _result;
  String _partial = '';
  int _done = 0;
  int _total = 0;
  Object? _error;
  String? _target;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final target = translateTarget(ref, context);
    if (target != _target) {
      _target = target;
      _start(target);
    }
  }

  Future<void> _start(String target) async {
    final key = '${widget.messageId}|$target';
    final memo = ref.read(mailTranslationsProvider);
    if (memo[key] != null) {
      setState(() => _result = memo[key]);
      return;
    }
    final max =
        ref.read(chatFeaturesProvider).value?.translationMaxChars ?? 5000;
    setState(() {
      _result = null;
      _error = null;
      _partial = '';
      _done = 0;
      _total = TranslateLanguages.chunks(
        widget.text,
        math.min(max, 4000),
      ).length;
    });
    try {
      final r = await ref
          .read(chatTranslateApiProvider)
          .translateLong(
            widget.text,
            target: target,
            maxChars: math.min(max, 4000),
            onProgress: (partial, done, total) {
              if (!mounted || _target != target) return;
              setState(() {
                _partial = partial;
                _done = done;
                _total = total;
              });
            },
          );
      memo[key] = r;
      if (mounted && _target == target) setState(() => _result = r);
    } on AppException catch (e) {
      if (mounted && _target == target) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final r = _result;
    final String label;
    if (r != null) {
      label = r.sameLanguage
          ? l10n.translateSameLanguage(translateLanguageName(l10n, r.target))
          : l10n.translateLabel(
              translateLanguageName(l10n, r.source),
              translateLanguageName(l10n, r.target),
            );
    } else if (_error != null) {
      label = translateErrorText(l10n, _error!);
    } else {
      label = _total > 1
          ? l10n.translateMailProgress(_done, _total)
          : l10n.translateInProgress;
    }
    final body = r?.text ?? _partial;
    return Column(
      key: const Key('mail_translation'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.xs,
            Space.xs,
            Space.xs,
          ),
          decoration: BoxDecoration(
            color: t.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(t.radiusMd),
          ),
          child: Row(
            children: [
              if (r == null && _error == null)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: t.primary,
                  ),
                )
              else
                ExcludeSemantics(
                  child: Icon(
                    _error != null
                        ? LucideIcons.circleAlert
                        : LucideIcons.languages,
                    size: 16,
                    color: _error != null ? t.danger : t.primary,
                  ),
                ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  label,
                  key: const Key('mail_translation_label'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: t.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_error != null)
                TextButton(
                  key: const Key('mail_translation_retry'),
                  onPressed: () => _start(_target!),
                  child: Text(l10n.translateRetry),
                ),
              TextButton(
                key: const Key('mail_translation_original'),
                onPressed: widget.onShowOriginal,
                child: Text(l10n.translateShowOriginal),
              ),
            ],
          ),
        ),
        if (body.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          SelectableText(
            body,
            key: const Key('mail_translation_text'),
            style: theme.textTheme.bodyLarge!.copyWith(height: 1.6),
          ),
        ],
      ],
    );
  }
}
