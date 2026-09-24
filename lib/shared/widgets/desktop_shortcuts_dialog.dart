import 'package:flutter/material.dart';

import '../../core/localization/localization.dart';
import '../../core/theme/tokens.dart';
import '../../core/platform/desktop_keys.dart';

/// The web's `ShortcutsDialog` (`?`): the keys of the desktop app —
/// messages, everywhere, calls (and the modules in settings «Клавиши»).
Future<void> showDesktopShortcuts(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _ShortcutsDialog(),
);

/// Rows of a group: a label and its key combinations (`['Ctrl', 'P']`).
typedef DesktopShortcutRows = List<(String, List<List<String>>)>;

/// The groups the dialog shows (messages, everywhere); [modules] adds the
/// calendar's and the messenger's keys (settings «Клавиши»).
List<(String, DesktopShortcutRows)> desktopShortcutGroups(AppLocalizations l10n, {bool modules = false}) => [
  (l10n.desktopShortcutsMail, [
    (l10n.desktopShortcutNext, [['J'], ['↓']]),
    (l10n.desktopShortcutPrevious, [['K'], ['↑']]),
    (l10n.desktopShortcutOpen, [['Enter'], ['O']]),
    (l10n.desktopShortcutClose, [['Esc']]),
    (l10n.mailReply, [['R']]),
    (l10n.mailReplyAll, [['A']]),
    (l10n.mailForward, [['F']]),
    (l10n.desktopShortcutReadToggle, [['U']]),
    (l10n.mailStar, [['S']]),
    (l10n.delete, [['Delete'], ['#']]),
    (l10n.desktopPrint, [[commandKeyLabel, 'P']]),
    (l10n.desktopShortcutQuickLook, [['Space']]),
  ]),
  if (modules) ...[
    (l10n.calendarTitle, [
      (l10n.calendarToday, [['T']]),
      (l10n.desktopMailKeysCalendarPrevNext, [['←'], ['→'], ['J'], ['K']]),
      (l10n.calendarViewMonth, [['M']]),
      (l10n.calendarViewWeek, [['W']]),
      (l10n.calendarViewDay, [['D']]),
      (l10n.calendarViewAgenda, [['A']]),
      (l10n.calendarNewEvent, [['N'], ['C'], [commandKeyLabel, 'N']]),
      (l10n.desktopMailKeysCalendarClosePanel, [['Esc']]),
    ]),
    (l10n.chatTitle, [
      (l10n.chatNew, [['C'], [commandKeyLabel, 'N']]),
    ]),
  ],
  (l10n.desktopShortcutsEverywhere, [
    (l10n.search, [['/']]),
    (l10n.desktopShortcutPalette, [[commandKeyLabel, 'K']]),
    (l10n.composeTitleNew, [['C'], [commandKeyLabel, 'N']]),
    (l10n.desktopShortcutSend, [[commandKeyLabel, 'Enter']]),
    (l10n.desktopShortcutModules, [[commandKeyLabel, '1…5']]),
    (l10n.settingsTitle, [[commandKeyLabel, ',']]),
    (l10n.desktopShortcutZoom, [[commandKeyLabel, '+'], [commandKeyLabel, '−'], [commandKeyLabel, '0']]),
    (l10n.desktopShortcutsTitle, [['?']]),
    (l10n.desktopShortcutGlobalCompose, [if (usesCommandKey) ['⌃', '⌥', 'M'] else ['Ctrl', 'Alt', 'M']]),
    (l10n.desktopShortcutGlobalShow, [if (usesCommandKey) ['⌃', '⌥', 'X'] else ['Ctrl', 'Alt', 'X']]),
  ]),
  (l10n.desktopCallShortcuts, [
    (l10n.callsMic, [['M'], [commandKeyLabel, 'D']]),
    (l10n.callsCamera, [['V'], [commandKeyLabel, 'E']]),
    (l10n.callsChat, [[commandKeyLabel, 'Shift', 'C']]),
    (l10n.callsParticipants, [[commandKeyLabel, 'Shift', 'P']]),
    (l10n.callsHangUp, [[commandKeyLabel, 'Shift', 'H']]),
    (l10n.callsAccept, [['Enter']]),
    (l10n.callsDecline, [['Esc']]),
  ]),
];

class _ShortcutsDialog extends StatelessWidget {
  const _ShortcutsDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return Dialog(
      key: const Key('desktop_shortcuts'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(Space.lg),
          children: [
            Text(
              l10n.desktopShortcutsTitle,
              style: TextStyle(fontFamily: t.fontDisplay, fontSize: 18, fontWeight: FontWeight.w600, color: t.textPrimary),
            ),
            DesktopShortcutsGroups(groups: desktopShortcutGroups(l10n)),
            const SizedBox(height: Space.md),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The groups as the dialog draws them: a small caps title, then a row per
/// action with its keys on the right.
class DesktopShortcutsGroups extends StatelessWidget {
  const DesktopShortcutsGroups({super.key, required this.groups});

  final List<(String, DesktopShortcutRows)> groups;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (title, rows) in groups) ...[
          const SizedBox(height: Space.md),
          Text(
            title.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.1, color: t.textTertiary),
          ),
          const SizedBox(height: Space.xs),
          for (final (label, combos) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: t.textPrimary))),
                  const SizedBox(width: Space.md),
                  for (var i = 0; i < combos.length; i++) ...[
                    if (i > 0) Text('  /  ', style: TextStyle(fontSize: 12, color: t.textTertiary)),
                    for (var k = 0; k < combos[i].length; k++) ...[
                      if (k > 0) const SizedBox(width: 3),
                      _Key(combos[i][k]),
                    ],
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: t.surfaceSubtle,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: t.border, width: t.borderWidth),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11, fontWeight: FontWeight.w600, color: t.textSecondary),
      ),
    );
  }
}
