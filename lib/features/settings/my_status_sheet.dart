import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_exception.dart';
import '../../core/localization/localization.dart';
import '../../core/theme/tokens.dart';
import '../chat/data/chat_status.dart';
import '../chat/presentation/broadcast/broadcast_format.dart';
import '../chat/presentation/chat_emoji_picker.dart';
import '../chat/presentation/chat_formatters.dart';
import '../chat/presentation/chat_providers.dart';
import '../chat/presentation/status/chat_status_providers.dart';
import '../../shared/widgets/app_sheet.dart';

/// «Статус»: preset or own text with emoji, «До», optional auto-reply,
/// «Сбросить статус». Opened from Settings and the chat list menu.
Future<void> showMyStatusSheet(BuildContext context) =>
    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const MyStatusSheet(),
    );

class MyStatusSheet extends ConsumerStatefulWidget {
  const MyStatusSheet({super.key, this.now});

  /// Clock (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<MyStatusSheet> createState() => _MyStatusSheetState();
}

class _MyStatusSheetState extends ConsumerState<MyStatusSheet> {
  final _text = TextEditingController();
  final _autoReply = TextEditingController();
  ChatStatusPreset? _preset;
  String _emoji = '';
  ChatStatusUntil _until = ChatStatusUntil.none;
  DateTime? _picked;
  bool _prefilled = false;
  bool _busy = false;
  String? _error;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final current = ref.read(myChatStatusProvider);
    if (current.hasValue) _prefill(current.value);
  }

  @override
  void dispose() {
    _text.dispose();
    _autoReply.dispose();
    super.dispose();
  }

  void _prefill(ChatUserStatus? s) {
    if (_prefilled) return;
    _prefilled = true;
    if (s == null) return;
    _preset = s.preset;
    _emoji = s.emoji == s.preset.emoji ? '' : s.emoji;
    _text.text = s.text;
    _autoReply.text = s.autoReply;
    if (s.until != null) {
      _until = ChatStatusUntil.custom;
      _picked = s.until!.toLocal();
    }
  }

  Future<void> _pickEmoji() async {
    final emoji = await ChatEmojiPickerSheet.show(context);
    if (emoji != null && mounted) setState(() => _emoji = emoji);
  }

  Future<void> _pickUntil() async {
    final start = _now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(start.year, start.month, start.day),
      lastDate: start.add(const Duration(days: 365)),
      initialDate: _picked ?? start,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _picked ?? start.add(const Duration(hours: 1)),
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _until = ChatStatusUntil.custom;
      _picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _error = null;
    });
  }

  ChatUserStatus? _draft() {
    final preset = _preset;
    if (preset == null) return null;
    final now = _now();
    return ChatUserStatus(
      preset: preset,
      emoji: _emoji.isNotEmpty
          ? _emoji
          : (preset == ChatStatusPreset.custom ? '' : preset.emoji),
      text: _text.text.trim(),
      until: ChatStatusDurations.resolve(_until, now, picked: _picked),
      autoReply: _autoReply.text.trim(),
    );
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final draft = _draft();
    if (draft == null || _busy) return;
    final invalid = draft.validate(_now());
    if (invalid != null) {
      setState(
        () => _error =
            invalid == 'text' && draft.preset == ChatStatusPreset.custom
            ? l10n.statusCustomRequired
            : l10n.statusInvalid,
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(myChatStatusProvider.notifier).save(draft);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.statusSaved)));
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is ApiException && e.code == 'INVALID_STATUS'
            ? l10n.statusInvalid
            : ChatFormat.error(l10n, e);
      });
    }
  }

  Future<void> _clear() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(myChatStatusProvider.notifier).clear();
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.statusCleared)));
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ChatFormat.error(l10n, e);
      });
    }
  }

  String _untilLabel(ChatStatusUntil u) {
    final l10n = context.l10n;
    return switch (u) {
      ChatStatusUntil.none => l10n.statusUntilNone,
      ChatStatusUntil.hour => l10n.statusUntilHour,
      ChatStatusUntil.endOfDay => l10n.statusUntilDay,
      ChatStatusUntil.endOfWeek => l10n.statusUntilWeek,
      ChatStatusUntil.custom =>
        _picked == null
            ? l10n.statusUntilPick
            : formatWhen(context, _picked!, now: _now()),
    };
  }

  Widget _chip({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final t = context.tokens;
    return ChoiceChip(
      key: key,
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      labelStyle: TextStyle(
        color: selected ? t.textPrimary : t.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: t.primarySoft,
      backgroundColor: t.surface,
      side: BorderSide(
        color: selected ? t.primary : t.border,
        width: t.borderWidth,
      ),
      shape: const StadiumBorder(),
      onSelected: (_) => onTap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    ref.listen<AsyncValue<ChatUserStatus?>>(myChatStatusProvider, (_, next) {
      if (next.hasValue && !_prefilled) setState(() => _prefill(next.value));
    });
    final current = ref.watch(myChatStatusProvider).value;
    final preset = _preset;
    final emoji = _emoji.isNotEmpty ? _emoji : (preset?.emoji ?? '🙂');
    Widget section(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(0, Space.md, 0, Space.xs),
      child: Text(
        t.sectionLabel(text),
        style: theme.textTheme.labelMedium?.copyWith(
          color: t.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        key: const Key('my_status_sheet'),
        padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.statusTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              children: [
                for (final p in ChatStatusPreset.values)
                  _chip(
                    key: Key('status_preset_${p.apiName}'),
                    label: '${p.emoji} ${ChatStatusFormat.presetLabel(l10n, p)}',
                    selected: preset == p,
                    onTap: () => setState(() {
                      _preset = p;
                      _error = null;
                    }),
                  ),
              ],
            ),
            if (preset == ChatStatusPreset.dnd)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(
                  l10n.statusDndHint,
                  key: const Key('status_dnd_hint'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: t.textSecondary,
                  ),
                ),
              ),
            if (preset != null) ...[
              const SizedBox(height: Space.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    button: true,
                    label: l10n.statusEmojiPick,
                    excludeSemantics: true,
                    child: InkWell(
                      key: const Key('status_emoji'),
                      customBorder: const CircleBorder(),
                      onTap: _busy ? null : _pickEmoji,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: t.surfaceMuted,
                          shape: BoxShape.circle,
                          border: Border.all(color: t.border, width: t.borderWidth),
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: TextField(
                      key: const Key('status_text'),
                      controller: _text,
                      maxLength: ChatUserStatus.maxText,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() => _error = null),
                      decoration: InputDecoration(
                        labelText: l10n.statusTextLabel,
                        hintText: preset == ChatStatusPreset.custom
                            ? null
                            : ChatStatusFormat.presetLabel(l10n, preset),
                      ),
                    ),
                  ),
                ],
              ),
              section(l10n.statusUntilLabel),
              Wrap(
                spacing: Space.sm,
                children: [
                  for (final u in ChatStatusUntil.values)
                    _chip(
                      key: Key('status_until_${u.name}'),
                      label: _untilLabel(u),
                      selected: _until == u,
                      onTap: u == ChatStatusUntil.custom
                          ? _pickUntil
                          : () => setState(() {
                              _until = u;
                              _error = null;
                            }),
                    ),
                ],
              ),
              const SizedBox(height: Space.md),
              TextField(
                key: const Key('status_auto_reply'),
                controller: _autoReply,
                minLines: 1,
                maxLines: 4,
                maxLength: ChatUserStatus.maxAutoReply,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.statusAutoReplyLabel,
                  helperText: l10n.statusAutoReplyHint,
                  helperMaxLines: 3,
                ),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: Space.sm),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    key: const Key('status_error'),
                    style: theme.textTheme.bodySmall?.copyWith(color: t.danger),
                  ),
                ),
              ),
            const SizedBox(height: Space.md),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                if (current != null)
                  TextButton.icon(
                    key: const Key('status_clear'),
                    style: TextButton.styleFrom(
                      foregroundColor: t.danger,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(LucideIcons.eraser, size: 18),
                    label: Text(l10n.statusClear),
                    onPressed: _busy ? null : _clear,
                  ),
                FilledButton(
                  key: const Key('status_save'),
                  style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
                  onPressed: _busy || preset == null ? null : _save,
                  child: Text(l10n.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings row: the current status or «Установить статус».
class MyStatusSettingsTile extends ConsumerWidget {
  const MyStatusSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(chatEnabledProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final t = context.tokens;
    final status = ref.watch(myChatStatusProvider).value;
    final active = status != null && status.isActiveAt(DateTime.now());
    return ListTile(
      key: const Key('settings_status'),
      leading: const Icon(LucideIcons.smilePlus),
      title: Text(l10n.statusTitle),
      subtitle: Text(
        active ? ChatStatusFormat.line(context, status) : l10n.statusSet,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: t.textMuted),
      ),
      trailing: const Icon(LucideIcons.chevronRight),
      onTap: () => unawaited(showMyStatusSheet(context)),
    );
  }
}
