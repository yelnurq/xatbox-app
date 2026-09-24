import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../broadcast/broadcast_format.dart';
import '../broadcast/broadcast_providers.dart';
import '../../../../shared/widgets/app_sheet.dart';

enum PollDraftError { question, options, quiz }

enum PollCloseAfter {
  never(null),
  hour(Duration(hours: 1)),
  day(Duration(days: 1)),
  week(Duration(days: 7));

  const PollCloseAfter(this.duration);
  final Duration? duration;
}

/// What the creation sheet produced (validated before it is returned).
class PollDraft {
  const PollDraft({
    required this.question,
    required this.options,
    this.anonymous = true,
    this.multiple = false,
    this.quiz = false,
    this.correctOption,
    this.closeAfter = PollCloseAfter.never,
  });

  final String question;

  /// As typed, empty fields included (their positions match the inputs).
  final List<String> options;
  final bool anonymous;
  final bool multiple;
  final bool quiz;

  /// Index among [options] (inputs).
  final int? correctOption;
  final PollCloseAfter closeAfter;

  static const maxOptions = 10;

  List<String> get cleanOptions => [
    for (final o in options)
      if (o.trim().isNotEmpty) o.trim(),
  ];

  /// [correctOption] as an index of [cleanOptions].
  int? get cleanCorrectOption {
    final c = correctOption;
    if (!quiz || c == null || c >= options.length || options[c].trim().isEmpty) {
      return null;
    }
    var index = -1;
    for (var i = 0; i <= c; i++) {
      if (options[i].trim().isNotEmpty) index++;
    }
    return index;
  }

  PollDraftError? validate() {
    if (question.trim().isEmpty) return PollDraftError.question;
    final opts = cleanOptions;
    final unique = {for (final o in opts) o.toLowerCase()};
    if (opts.length < 2 || opts.length > maxOptions || unique.length != opts.length) {
      return PollDraftError.options;
    }
    if (quiz && cleanCorrectOption == null) return PollDraftError.quiz;
    return null;
  }
}

/// «Опрос» from the attach grid: sheet → `POST /chats/{id}/polls`.
Future<void> createPollFlow(BuildContext context, WidgetRef ref, String conversationId) async {
  final draft = await PollCreateSheet.show(context);
  if (draft == null || !context.mounted) return;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final after = draft.closeAfter.duration;
  try {
    await ref
        .read(chatBroadcastApiProvider)
        .createPoll(
          conversationId,
          clientMessageId: const Uuid().v4(),
          question: draft.question.trim(),
          options: draft.cleanOptions,
          anonymous: draft.anonymous,
          multiple: draft.multiple && !draft.quiz,
          quiz: draft.quiz,
          correctOption: draft.cleanCorrectOption,
          closeAt: after == null ? null : DateTime.now().add(after),
        );
  } on AppException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(broadcastErrorText(l10n, e))));
  }
}

class PollCreateSheet extends StatefulWidget {
  const PollCreateSheet({super.key});

  static Future<PollDraft?> show(BuildContext context) => showAppSheet<PollDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const PollCreateSheet(),
  );

  @override
  State<PollCreateSheet> createState() => _PollCreateSheetState();
}

class _PollCreateSheetState extends State<PollCreateSheet> {
  final _question = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];
  bool _anonymous = true;
  bool _multiple = false;
  bool _quiz = false;
  int? _correct;
  PollCloseAfter _closeAfter = PollCloseAfter.never;
  PollDraftError? _error;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  PollDraft get _draft => PollDraft(
    question: _question.text,
    options: [for (final c in _options) c.text],
    anonymous: _anonymous,
    multiple: _multiple,
    quiz: _quiz,
    correctOption: _correct,
    closeAfter: _closeAfter,
  );

  void _submit() {
    final draft = _draft;
    final error = draft.validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, draft);
  }

  void _addOption() {
    if (_options.length >= PollDraft.maxOptions) return;
    setState(() => _options.add(TextEditingController()));
  }

  void _removeOption(int i) {
    if (_options.length <= 2) return;
    setState(() {
      _options.removeAt(i).dispose();
      if (_correct == i) {
        _correct = null;
      } else if (_correct != null && _correct! > i) {
        _correct = _correct! - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final errorText = switch (_error) {
      PollDraftError.question => l10n.pollErrorQuestion,
      PollDraftError.options => l10n.pollErrorOptions,
      PollDraftError.quiz => l10n.pollQuizHint,
      null => null,
    };
    String closeLabel(PollCloseAfter c) => switch (c) {
      PollCloseAfter.never => l10n.pollCloseNever,
      PollCloseAfter.hour => l10n.pollClose1h,
      PollCloseAfter.day => l10n.pollClose1d,
      PollCloseAfter.week => l10n.pollCloseWeek,
    };
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xs, 0, Space.md, Space.xs),
            child: Row(
              children: [
                IconButton(
                  key: const Key('poll_cancel'),
                  tooltip: l10n.cancel,
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    l10n.pollNewTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                FilledButton(
                  key: const Key('poll_create'),
                  onPressed: _submit,
                  child: Text(l10n.pollCreate),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('poll_question'),
                    controller: _question,
                    autofocus: true,
                    maxLength: 300,
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: l10n.pollQuestionLabel, counterText: ''),
                  ),
                  const SizedBox(height: Space.md),
                  Text(
                    l10n.pollOptionsLabel,
                    style: theme.textTheme.labelLarge?.copyWith(color: t.primary, fontWeight: FontWeight.w600),
                  ),
                  if (_quiz)
                    Text(l10n.pollQuizHint, style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary)),
                  for (var i = 0; i < _options.length; i++)
                    Row(
                      children: [
                        if (_quiz)
                          IconButton(
                            key: ValueKey('poll_correct_$i'),
                            tooltip: l10n.pollCorrect,
                            icon: Icon(
                              _correct == i ? LucideIcons.circleCheck : LucideIcons.circle,
                              color: _correct == i ? t.success : t.textTertiary,
                            ),
                            onPressed: () => setState(() {
                              _correct = i;
                              if (_error == PollDraftError.quiz) _error = null;
                            }),
                          ),
                        Expanded(
                          child: TextField(
                            key: ValueKey('poll_option_$i'),
                            controller: _options[i],
                            maxLength: 100,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(hintText: l10n.pollOptionHint(i + 1), counterText: ''),
                          ),
                        ),
                        if (_options.length > 2)
                          IconButton(
                            key: ValueKey('poll_remove_$i'),
                            tooltip: l10n.pollRemoveOption,
                            icon: Icon(LucideIcons.x, size: 18, color: t.textTertiary),
                            onPressed: () => _removeOption(i),
                          ),
                      ],
                    ),
                  if (_options.length < PollDraft.maxOptions)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const Key('poll_add_option'),
                        icon: const Icon(LucideIcons.plus, size: 18),
                        label: Text(l10n.pollAddOption),
                        onPressed: _addOption,
                      ),
                    ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.xs),
                      child: Text(
                        errorText,
                        key: const Key('poll_error'),
                        style: theme.textTheme.bodySmall?.copyWith(color: t.danger),
                      ),
                    ),
                  const Divider(height: Space.lg),
                  SwitchListTile(
                    key: const Key('poll_anonymous'),
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(LucideIcons.eyeOff),
                    title: Text(l10n.pollAnonymous),
                    value: _anonymous,
                    onChanged: (v) => setState(() => _anonymous = v),
                  ),
                  SwitchListTile(
                    key: const Key('poll_multiple'),
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(LucideIcons.listChecks),
                    title: Text(l10n.pollMultiple),
                    value: _multiple && !_quiz,
                    onChanged: _quiz ? null : (v) => setState(() => _multiple = v),
                  ),
                  SwitchListTile(
                    key: const Key('poll_quiz'),
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(LucideIcons.graduationCap),
                    title: Text(l10n.pollQuiz),
                    value: _quiz,
                    onChanged: (v) => setState(() {
                      _quiz = v;
                      if (v) _multiple = false;
                    }),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(l10n.pollCloseSection, style: theme.textTheme.labelLarge?.copyWith(color: t.textSecondary)),
                  const SizedBox(height: Space.xs),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.xs,
                    children: [
                      for (final c in PollCloseAfter.values)
                        ChoiceChip(
                          key: ValueKey('poll_close_${c.name}'),
                          label: Text(closeLabel(c)),
                          selected: _closeAfter == c,
                          showCheckmark: false,
                          selectedColor: t.primarySoft,
                          labelStyle: TextStyle(
                            color: _closeAfter == c ? t.primary : t.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => setState(() => _closeAfter = c),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
