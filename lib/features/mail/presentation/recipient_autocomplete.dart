import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/localization/localization.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../../shared/utils/email_address.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../contacts/data/contact_models.dart';
import '../../contacts/presentation/contacts_providers.dart';
import 'mail_ux_settings.dart';

/// One row of the To / Cc / Bcc suggestion list.
@immutable
class RecipientSuggestion {
  const RecipientSuggestion({
    required this.email,
    this.name = '',
    this.position = '',
    this.department = '',
    this.recent = false,
  });

  final String email;
  final String name;
  final String position;
  final String department;
  final bool recent;

  String get label => name.trim().isNotEmpty ? name.trim() : email;

  /// «Должность · Отдел» (either may be missing).
  String get details =>
      [position, department].where((s) => s.trim().isNotEmpty).join(' · ');

  @override
  bool operator ==(Object other) =>
      other is RecipientSuggestion && other.email == email;

  @override
  int get hashCode => email.hashCode;
}

/// Token handling and ranking for recipient fields (pure, unit-tested).
abstract final class RecipientSuggest {
  static final _separator = RegExp(r'[,;]');

  /// The address being typed: text after the last `,` / `;`.
  static String currentToken(String text) {
    final i = text.lastIndexOf(_separator);
    return (i < 0 ? text : text.substring(i + 1)).trim();
  }

  /// Addresses already complete before the current token.
  static List<String> previousAddresses(String text) {
    final i = text.lastIndexOf(_separator);
    return i < 0 ? const [] : EmailAddress.split(text.substring(0, i));
  }

  /// [text] with the current token replaced by [email] and a separator, so
  /// the next address can be typed right away.
  static String replaceCurrent(String text, String email) {
    final i = text.lastIndexOf(_separator);
    final prefix = i < 0 ? '' : '${text.substring(0, i + 1).trimRight()} ';
    return '$prefix$email, ';
  }

  /// Directory colleagues and recently used addresses matching [query]:
  /// prefix matches of the address / name words first, recently used ahead
  /// of the rest, addresses already entered skipped.
  static List<RecipientSuggestion> rank({
    required String query,
    required List<Contact> directory,
    required List<String> recent,
    Iterable<String> exclude = const [],
    int limit = 8,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final skip = exclude.map((e) => e.toLowerCase()).toSet();
    final recentSet = recent.map((e) => e.toLowerCase()).toList();
    final scored = <String, (int, RecipientSuggestion)>{};

    int score(String email, String name, {required bool recentHit}) {
      final e = email.toLowerCase();
      final n = name.toLowerCase();
      int base;
      if (e.startsWith(q) || n.startsWith(q)) {
        base = 0;
      } else if (n.split(RegExp(r'\s+')).any((w) => w.startsWith(q)) ||
          e.split(RegExp(r'[._@-]')).any((w) => w.startsWith(q))) {
        base = 1;
      } else {
        base = 2;
      }
      return base * 2 + (recentHit ? 0 : 1);
    }

    for (final c in directory) {
      final email = c.mailAddress.trim().toLowerCase();
      if (email.isEmpty || skip.contains(email)) continue;
      final matches = c.matches(q) || email.contains(q);
      if (!matches) continue;
      final isRecent = recentSet.contains(email);
      final s = RecipientSuggestion(
        email: email,
        name: c.displayName,
        position: c.position,
        department: c.department,
        recent: isRecent,
      );
      final value = score(email, c.displayName, recentHit: isRecent);
      final prev = scored[email];
      if (prev == null || value < prev.$1) scored[email] = (value, s);
    }
    for (final r in recentSet) {
      if (skip.contains(r) || scored.containsKey(r) || !r.contains(q)) continue;
      scored[r] = (
        score(r, '', recentHit: true),
        RecipientSuggestion(email: r, recent: true),
      );
    }
    final list = scored.values.toList()
      ..sort((a, b) {
        final byScore = a.$1.compareTo(b.$1);
        if (byScore != 0) return byScore;
        final ra = recentSet.indexOf(a.$2.email);
        final rb = recentSet.indexOf(b.$2.email);
        if (ra != rb) {
          if (ra < 0) return 1;
          if (rb < 0) return -1;
          return ra.compareTo(rb);
        }
        return a.$2.label.toLowerCase().compareTo(b.$2.label.toLowerCase());
      });
    return list.take(limit).map((e) => e.$2).toList();
  }
}

/// The directory known locally (cached `GET /users`), loaded once when there
/// is no cache yet and the Chat Service is configured. `complete` is false
/// when the organization is larger than one page (then queries also search
/// the service).
typedef MailRecipientDirectory = ({List<Contact> contacts, bool complete});

final mailRecipientDirectoryProvider =
    FutureProvider.autoDispose<MailRecipientDirectory>((ref) async {
      final repo = ref.watch(contactsRepositoryProvider);
      final chat = ref.watch(chatEnabledProvider);
      try {
        final cached = await repo.cached();
        if (cached != null && cached.contacts.isNotEmpty) {
          return (contacts: cached.contacts, complete: false);
        }
        if (!chat) return (contacts: const <Contact>[], complete: true);
        final result = await repo.load('');
        return (contacts: result.contacts, complete: !result.hasMore);
      } on Object catch (e) {
        DiagnosticLog.warn('mail', 'recipient directory unavailable', error: e);
        return (contacts: const <Contact>[], complete: !chat);
      }
    });

/// A To / Cc / Bcc field with suggestions from the corporate directory and
/// recently used addresses. Several comma-separated addresses; typing a full
/// address still works. Arrow keys move through suggestions, Enter picks.
class RecipientField extends ConsumerStatefulWidget {
  const RecipientField({
    super.key,
    required this.controller,
    required this.label,
    required this.enabled,
    this.hint,
    this.trailing,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool enabled;
  final Widget? trailing;
  final Key? fieldKey;

  @override
  ConsumerState<RecipientField> createState() => _RecipientFieldState();
}

class _RecipientFieldState extends ConsumerState<RecipientField> {
  final _focus = FocusNode();
  final Map<String, List<Contact>> _remote = {};

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<List<RecipientSuggestion>> _options(TextEditingValue value) async {
    final token = RecipientSuggest.currentToken(value.text);
    if (token.isEmpty || !widget.enabled) return const [];
    MailRecipientDirectory directory;
    try {
      directory = await ref.read(mailRecipientDirectoryProvider.future);
    } on Object {
      directory = (contacts: const <Contact>[], complete: true);
    }
    var contacts = directory.contacts;
    if (!directory.complete &&
        token.length >= 2 &&
        ref.read(chatEnabledProvider)) {
      final key = token.toLowerCase();
      var found = _remote[key];
      if (found == null) {
        try {
          final result = await ref
              .read(contactsRepositoryProvider)
              .load(token)
              .timeout(const Duration(seconds: 3));
          found = result.contacts;
          _remote[key] = found;
        } on Object catch (e) {
          DiagnosticLog.warn('mail', 'recipient search failed', error: e);
        }
      }
      if (found != null) contacts = [...found, ...contacts];
    }
    if (!mounted) return const [];
    return RecipientSuggest.rank(
      query: token,
      directory: contacts,
      recent: ref.read(mailRecentRecipientsProvider),
      exclude: RecipientSuggest.previousAddresses(value.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep the directory warm while the composer is open.
    ref.watch(mailRecipientDirectoryProvider);
    ref.watch(mailRecentRecipientsProvider);
    final l10n = context.l10n;
    final t = context.tokens;
    return RawAutocomplete<RecipientSuggestion>(
      textEditingController: widget.controller,
      focusNode: _focus,
      displayStringForOption: (o) =>
          RecipientSuggest.replaceCurrent(widget.controller.text, o.email),
      optionsBuilder: _options,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
          TextField(
            key: widget.fieldKey,
            controller: controller,
            focusNode: focusNode,
            enabled: widget.enabled,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => onSubmitted(),
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              suffixIcon: widget.trailing,
            ),
          ),
      optionsViewBuilder: (context, onSelected, options) {
        final highlighted = AutocompleteHighlightedOption.of(context);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            color: t.surface,
            borderRadius: BorderRadius.circular(t.radiusMd),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 520),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final o = options.elementAt(i);
                  final details = [
                    if (o.details.isNotEmpty) o.details,
                    if (o.label != o.email) o.email,
                  ].join('\n');
                  return ListTile(
                    key: ValueKey('recipient_suggestion_${o.email}'),
                    selected: i == highlighted,
                    selectedTileColor: t.surfaceSelected,
                    leading: UserAvatar(
                      email: o.email,
                      label: o.label,
                      radius: 16,
                      excludeFromSemantics: true,
                    ),
                    title: Text(
                      o.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: details.isEmpty && !o.recent
                        ? null
                        : Text(
                            details.isEmpty
                                ? l10n.mailUxRecentRecipient
                                : details,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: t.textTertiary),
                          ),
                    onTap: () => onSelected(o),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Desktop composer: recipients as chips, like the web's recipient
/// selector. [controller] keeps holding "a@x, b@y, …" (what is sent and
/// saved does not change); the field under the chips edits only the address
/// being typed. A comma, semicolon, space, Enter or leaving the field turns
/// it into a chip; Backspace in the empty field takes the last one back.
class RecipientChipsField extends ConsumerStatefulWidget {
  const RecipientChipsField({
    super.key,
    required this.controller,
    required this.enabled,
    this.hint,
    this.fieldKey,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? hint;
  final Key? fieldKey;

  @override
  ConsumerState<RecipientChipsField> createState() => _RecipientChipsFieldState();
}

class _RecipientChipsFieldState extends ConsumerState<RecipientChipsField> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final Map<String, List<Contact>> _remote = {};
  late List<String> _chips = EmailAddress.split(widget.controller.text);

  static final _separator = RegExp(r'[,;\s]');

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _sync() {
    final typing = _input.text.trim();
    final next = [..._chips, if (typing.isNotEmpty) typing].join(', ');
    if (widget.controller.text != next) widget.controller.text = next;
  }

  void _add(String address) {
    final a = address.trim();
    if (a.isEmpty) return;
    if (!_chips.any((c) => c.toLowerCase() == a.toLowerCase())) _chips = [..._chips, a];
  }

  void _commit() {
    if (_input.text.trim().isEmpty) return;
    setState(() {
      _add(_input.text);
      _input.clear();
    });
    _sync();
  }

  void _onChanged(String value) {
    if (_separator.hasMatch(value)) {
      // Typed or pasted separators: every complete address becomes a chip.
      final parts = value.split(_separator);
      final last = parts.removeLast();
      setState(() {
        for (final p in parts) {
          _add(p);
        }
        _input.value = TextEditingValue(text: last, selection: TextSelection.collapsed(offset: last.length));
      });
    }
    _sync();
  }

  void _remove(String address) {
    setState(() => _chips = _chips.where((c) => c != address).toList());
    _sync();
  }

  Future<List<RecipientSuggestion>> _options(TextEditingValue value) async {
    final token = value.text.trim();
    if (token.isEmpty || !widget.enabled) return const [];
    MailRecipientDirectory directory;
    try {
      directory = await ref.read(mailRecipientDirectoryProvider.future);
    } on Object {
      directory = (contacts: const <Contact>[], complete: true);
    }
    var contacts = directory.contacts;
    if (!directory.complete && token.length >= 2 && ref.read(chatEnabledProvider)) {
      final key = token.toLowerCase();
      var found = _remote[key];
      if (found == null) {
        try {
          final result = await ref.read(contactsRepositoryProvider).load(token).timeout(const Duration(seconds: 3));
          found = result.contacts;
          _remote[key] = found;
        } on Object catch (e) {
          DiagnosticLog.warn('mail', 'recipient search failed', error: e);
        }
      }
      if (found != null) contacts = [...found, ...contacts];
    }
    if (!mounted) return const [];
    return RecipientSuggest.rank(
      query: token,
      directory: contacts,
      recent: ref.read(mailRecentRecipientsProvider),
      exclude: _chips,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(mailRecipientDirectoryProvider);
    ref.watch(mailRecentRecipientsProvider);
    final t = context.tokens;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final c in _chips)
            _RecipientChip(
              key: ValueKey('recipient_chip_$c'),
              address: c,
              valid: EmailAddress.isBare(c),
              enabled: widget.enabled,
              onRemove: () => _remove(c),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120, maxWidth: 520),
            child: IntrinsicWidth(
              child: RawAutocomplete<RecipientSuggestion>(
                textEditingController: _input,
                focusNode: _focus,
                displayStringForOption: (_) => '',
                optionsBuilder: _options,
                onSelected: (o) {
                  setState(() {
                    _add(o.email);
                    _input.clear();
                  });
                  _sync();
                  _focus.requestFocus();
                },
                fieldViewBuilder: (context, controller, focusNode, onSubmitted) => Focus(
                  // Backspace in the empty field edits the last chip.
                  onKeyEvent: (_, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.backspace &&
                        controller.text.isEmpty &&
                        _chips.isNotEmpty) {
                      final last = _chips.last;
                      setState(() => _chips = _chips.sublist(0, _chips.length - 1));
                      controller.value = TextEditingValue(text: last, selection: TextSelection.collapsed(offset: last.length));
                      _sync();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    key: widget.fieldKey,
                    controller: controller,
                    focusNode: focusNode,
                    enabled: widget.enabled,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    onChanged: _onChanged,
                    onSubmitted: (_) {
                      onSubmitted();
                      _commit();
                      focusNode.requestFocus();
                    },
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      hintText: _chips.isEmpty ? widget.hint : null,
                    ),
                  ),
                ),
                optionsViewBuilder: (context, onSelected, options) {
                  final highlighted = AutocompleteHighlightedOption.of(context);
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      color: t.surface,
                      borderRadius: BorderRadius.circular(t.radiusMd),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280, maxWidth: 420),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, i) {
                            final o = options.elementAt(i);
                            return ListTile(
                              key: ValueKey('recipient_suggestion_${o.email}'),
                              dense: true,
                              selected: i == highlighted,
                              selectedTileColor: t.surfaceSelected,
                              leading: UserAvatar(email: o.email, label: o.label, radius: 14, excludeFromSemantics: true),
                              title: Text(o.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                o.label != o.email ? o.email : (o.recent ? l10n.mailUxRecentRecipient : o.details),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: t.textTertiary),
                              ),
                              onTap: () => onSelected(o),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `rounded-full border px-2.5 py-1 text-[13px]`; a bad address in red.
class _RecipientChip extends StatelessWidget {
  const _RecipientChip({super.key, required this.address, required this.valid, required this.enabled, required this.onRemove});
  final String address;
  final bool valid;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: valid ? t.surfaceSubtle : t.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(XatBoxTokens.radiusPill),
        border: Border.all(color: valid ? t.border : t.danger, width: t.borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(address, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: valid ? t.textPrimary : t.danger)),
          const SizedBox(width: 2),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onRemove : null,
            child: Padding(padding: const EdgeInsets.all(3), child: Icon(LucideIcons.x, size: 12, color: t.textTertiary)),
          ),
        ],
      ),
    );
  }
}
