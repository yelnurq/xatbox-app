import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../data/chat_models.dart';
import '../../data/chat_translation.dart';
import 'translation_providers.dart';

/// Under the text of a message: its translation with a language label and
/// «Показать оригинал», a progress row while translating, or a quiet error
/// with «Повторить». Nothing when translation is off or not requested.
///
/// In chats with «Переводить автоматически» an incoming message that does
/// not look like the target language is translated when this widget is
/// first built — the list builds only visible rows, so translation is lazy.
class MessageTranslationView extends ConsumerStatefulWidget {
  const MessageTranslationView({
    super.key,
    required this.message,
    required this.isOwn,
  });
  final ChatMessage message;
  final bool isOwn;

  @override
  ConsumerState<MessageTranslationView> createState() =>
      _MessageTranslationViewState();
}

class _MessageTranslationViewState
    extends ConsumerState<MessageTranslationView> {
  ChatMessage get _m => widget.message;

  void _maybeAuto(String target, MessageTranslationState? s) {
    if (s != null || widget.isOwn || !chatMessageTranslatable(_m)) return;
    if (!ref.watch(chatAutoTranslateProvider).contains(_m.conversationId)) {
      return;
    }
    if (ref.read(chatTranslationsProvider).hidden.contains(_m.id)) return;
    if (TranslateLanguages.detect(_m.body) == target) return;
    Future.microtask(() {
      if (!mounted) return;
      unawaited(
        ref
            .read(chatTranslationsProvider.notifier)
            .request(_m, target, auto: true),
      );
    });
  }

  Future<void> _retry(String target) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    try {
      await ref.read(chatTranslationsProvider.notifier).request(_m, target);
    } on AppException catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text(translateErrorText(l10n, e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(translationAvailableProvider) || _m.isDeleted) {
      return const SizedBox.shrink();
    }
    final target = translateTarget(ref, context);
    final key = ChatTranslationStore.key(_m, target);
    final all = ref.watch(chatTranslationsProvider);
    final s = all.items[key];
    _maybeAuto(target, s);
    if (s == null || all.hidden.contains(_m.id)) return const SizedBox.shrink();
    final child = switch (s.status) {
      MessageTranslationStatus.loading => _progress(context),
      MessageTranslationStatus.failed =>
        s.auto ? const SizedBox.shrink() : _failed(context, s, target),
      MessageTranslationStatus.done =>
        s.result!.sameLanguage && s.auto
            ? const SizedBox.shrink()
            : _result(context, s.result!),
    };
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnimatedSize(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topLeft,
      child: child,
    );
  }

  TextStyle? _labelStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: context.tokens.textTertiary);

  Widget _progress(BuildContext context) {
    final t = context.tokens;
    return Padding(
      key: ValueKey('message_translating_${_m.id}'),
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: t.primary,
            ),
          ),
          const SizedBox(width: Space.sm),
          Flexible(
            child: Text(
              context.l10n.translateInProgress,
              style: _labelStyle(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _failed(
    BuildContext context,
    MessageTranslationState s,
    String target,
  ) {
    final t = context.tokens;
    return Row(
      key: ValueKey('message_translation_failed_${_m.id}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(LucideIcons.circleAlert, size: 14, color: t.danger),
        ),
        const SizedBox(width: Space.xs),
        Flexible(
          child: Text(
            translateErrorText(context.l10n, s.error ?? ''),
            style: _labelStyle(context),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          onPressed: () => _retry(target),
          child: Text(context.l10n.translateRetry),
        ),
      ],
    );
  }

  Widget _result(BuildContext context, ChatTranslationResult r) {
    final t = context.tokens;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final label = r.sameLanguage
        ? l10n.translateSameLanguage(translateLanguageName(l10n, r.target))
        : l10n.translateLabel(
            translateLanguageName(l10n, r.source),
            translateLanguageName(l10n, r.target),
          );
    return Container(
      key: ValueKey('message_translation_${_m.id}'),
      margin: const EdgeInsets.only(top: Space.xs),
      padding: const EdgeInsets.fromLTRB(Space.sm, Space.xs, 0, 0),
      decoration: BoxDecoration(
        color: t.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(t.radiusSm),
        border: Border(left: BorderSide(color: t.primary, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(LucideIcons.languages, size: 14, color: t.primary),
              ),
              const SizedBox(width: Space.xs),
              Flexible(
                child: Text(
                  label,
                  key: ValueKey('message_translation_label_${_m.id}'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: t.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (!r.sameLanguage)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: Space.sm),
              child: Text(r.text.trim(), style: theme.textTheme.bodyMedium),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: ValueKey('message_translation_original_${_m.id}'),
              style: TextButton.styleFrom(
                foregroundColor: t.primary,
                visualDensity: VisualDensity.standard,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: () =>
                  ref.read(chatTranslationsProvider.notifier).hide(_m.id),
              child: Text(l10n.translateShowOriginal),
            ),
          ),
        ],
      ),
    );
  }
}
