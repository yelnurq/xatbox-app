import 'package:flutter/foundation.dart';

/// The fields of a `mailto:` link (RFC 6068).
@immutable
class MailtoLink {
  const MailtoLink({this.to = const [], this.cc = const [], this.bcc = const [], this.subject = '', this.body = ''});

  final List<String> to;
  final List<String> cc;
  final List<String> bcc;
  final String subject;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is MailtoLink &&
      listEquals(other.to, to) &&
      listEquals(other.cc, cc) &&
      listEquals(other.bcc, bcc) &&
      other.subject == subject &&
      other.body == body;

  @override
  int get hashCode => Object.hash(Object.hashAll(to), Object.hashAll(cc), Object.hashAll(bcc), subject, body);

  @override
  String toString() => 'MailtoLink(to: $to, cc: $cc, bcc: $bcc, subject: $subject)';
}

/// `mailto:a@x,b@y?cc=c@z&subject=…&body=…` → [MailtoLink]; null when
/// [link] is not a mailto link (pure, unit-tested).
///
/// Unlike form data, `+` stays a plus (RFC 6068 §5): addresses such as
/// `name+tag@host` survive. Line breaks come out as `\n`.
MailtoLink? parseMailto(String link) {
  final trimmed = link.trim();
  if (!trimmed.toLowerCase().startsWith('mailto:')) return null;
  final rest = trimmed.substring('mailto:'.length);
  final q = rest.indexOf('?');
  final to = <String>[..._addresses(q < 0 ? rest : rest.substring(0, q))];
  final cc = <String>[];
  final bcc = <String>[];
  var subject = '';
  var body = '';
  if (q >= 0) {
    for (final pair in rest.substring(q + 1).split('&')) {
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      final name = pair.substring(0, eq).toLowerCase();
      final value = pair.substring(eq + 1);
      switch (name) {
        case 'to':
          to.addAll(_addresses(value));
        case 'cc':
          cc.addAll(_addresses(value));
        case 'bcc':
          bcc.addAll(_addresses(value));
        case 'subject':
          subject = _decode(value).replaceAll(RegExp(r'[\r\n]+'), ' ');
        case 'body':
          body = _decode(value).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      }
    }
  }
  return MailtoLink(to: to, cc: cc, bcc: bcc, subject: subject, body: body);
}

String _decode(String value) {
  try {
    return Uri.decodeComponent(value);
  } on ArgumentError {
    return value;
  }
}

Iterable<String> _addresses(String value) =>
    _decode(value).split(RegExp('[,;]')).map((a) => a.trim()).where((a) => a.isNotEmpty);

/// What the desktop app is asked to do by a launch, the tray menu or the
/// jump list.
@immutable
sealed class DesktopCommand {
  const DesktopCommand();
}

/// A new message, prefilled from a `mailto:` link or with local [files]
/// (dropped on the window) attached.
final class DesktopCompose extends DesktopCommand {
  const DesktopCompose({this.mailto, this.files = const []});
  final MailtoLink? mailto;
  final List<String> files;

  @override
  bool operator ==(Object other) => other is DesktopCompose && other.mailto == mailto && listEquals(other.files, files);

  @override
  int get hashCode => Object.hash(mailto, Object.hashAll(files));
}

/// One of the modules of the rail.
enum DesktopModuleTarget { mail, chat, calls, calendar, contacts }

final class DesktopOpen extends DesktopCommand {
  const DesktopOpen(this.module);
  final DesktopModuleTarget module;

  @override
  bool operator ==(Object other) => other is DesktopOpen && other.module == module;

  @override
  int get hashCode => module.hashCode;
}

/// One message in the reading pane (a new-mail toast was clicked).
final class DesktopOpenMessage extends DesktopCommand {
  const DesktopOpenMessage(this.messageId);
  final String messageId;

  @override
  bool operator ==(Object other) => other is DesktopOpenMessage && other.messageId == messageId;

  @override
  int get hashCode => messageId.hashCode;
}

/// «Ответить» on a new-mail toast: the composer with the reply.
final class DesktopReply extends DesktopCommand {
  const DesktopReply(this.messageId);
  final String messageId;

  @override
  bool operator ==(Object other) => other is DesktopReply && other.messageId == messageId;

  @override
  int get hashCode => messageId.hashCode;
}

/// The window in front (global hotkey).
final class DesktopShow extends DesktopCommand {
  const DesktopShow();

  @override
  bool operator ==(Object other) => other is DesktopShow;

  @override
  int get hashCode => 0;
}

/// A saved message (.eml) opened with XatBox.
final class DesktopOpenEml extends DesktopCommand {
  const DesktopOpenEml(this.path);
  final String path;

  @override
  bool operator ==(Object other) => other is DesktopOpenEml && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// A calendar invitation (.ics) opened with XatBox: into the calendar.
final class DesktopOpenIcs extends DesktopCommand {
  const DesktopOpenIcs(this.path);
  final String path;

  @override
  bool operator ==(Object other) => other is DesktopOpenIcs && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// Command line switches of `XatBox.exe` (jump list tasks, the Run value,
/// Send To, the global hotkeys use them).
abstract final class DesktopArguments {
  static const compose = '--compose';
  static const show = '--show';

  /// Started at sign-in: the window stays in the tray.
  static const hidden = '--hidden';

  /// Send To / Services: the files after it are attached to a new message.
  static const attach = '--attach';
  static String open(DesktopModuleTarget module) => '--open=${module.name}';
}

/// The commands in a command line (without the program name); unknown
/// switches are ignored. Files: `--attach` ones and any file dropped on the
/// program icon go into one new message; `.eml` opens, `.ics` goes to the
/// calendar (pure, unit-tested).
List<DesktopCommand> parseDesktopArguments(List<String> arguments) {
  final commands = <DesktopCommand>[];
  final attach = <String>[];
  for (final a in arguments) {
    final mailto = parseMailto(a);
    if (mailto != null) {
      commands.add(DesktopCompose(mailto: mailto));
    } else if (a == DesktopArguments.compose) {
      commands.add(const DesktopCompose());
    } else if (a == DesktopArguments.show) {
      commands.add(const DesktopShow());
    } else if (a.startsWith('--open=')) {
      final name = a.substring('--open='.length);
      final module = DesktopModuleTarget.values.where((m) => m.name == name).firstOrNull;
      if (module != null) commands.add(DesktopOpen(module));
    } else if (a.startsWith('--') || a.trim().isEmpty) {
      continue; // --attach, --hidden, unknown switches
    } else {
      final lower = a.toLowerCase();
      if (lower.endsWith('.eml') && !arguments.contains(DesktopArguments.attach)) {
        commands.add(DesktopOpenEml(a));
      } else if (lower.endsWith('.ics') && !arguments.contains(DesktopArguments.attach)) {
        commands.add(DesktopOpenIcs(a));
      } else {
        attach.add(a);
      }
    }
  }
  if (attach.isNotEmpty) commands.add(DesktopCompose(files: attach));
  return commands;
}
