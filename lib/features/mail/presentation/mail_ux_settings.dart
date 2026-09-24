import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/diagnostic_log.dart';
import '../../../shared/utils/email_address.dart';
import '../data/mail_models.dart';
import 'mail_providers.dart';

/// What a full swipe of a message row does.
enum MailSwipeAction { none, trash, archive, read, bookmark }

/// Local (device) mail UX preferences: swipe actions and the undo-send delay.
class MailUxSettings {
  const MailUxSettings({
    this.swipeLeft = MailSwipeAction.trash,
    this.swipeRight = MailSwipeAction.read,
    this.undoSendSeconds = 5,
  });

  final MailSwipeAction swipeLeft;
  final MailSwipeAction swipeRight;

  /// 0 = send immediately.
  final int undoSendSeconds;

  static const undoSendChoices = [0, 5, 10, 20];

  MailUxSettings copyWith({
    MailSwipeAction? swipeLeft,
    MailSwipeAction? swipeRight,
    int? undoSendSeconds,
  }) => MailUxSettings(
    swipeLeft: swipeLeft ?? this.swipeLeft,
    swipeRight: swipeRight ?? this.swipeRight,
    undoSendSeconds: undoSendSeconds ?? this.undoSendSeconds,
  );

  Map<String, Object?> toJson() => {
    'swipe_left': swipeLeft.name,
    'swipe_right': swipeRight.name,
    'undo_send_seconds': undoSendSeconds,
  };

  factory MailUxSettings.fromJson(Map<String, Object?> json) {
    const d = MailUxSettings();
    MailSwipeAction action(Object? v, MailSwipeAction fallback) =>
        MailSwipeAction.values.where((a) => a.name == v).firstOrNull ??
        fallback;
    final seconds = json['undo_send_seconds'];
    return MailUxSettings(
      swipeLeft: action(json['swipe_left'], d.swipeLeft),
      swipeRight: action(json['swipe_right'], d.swipeRight),
      undoSendSeconds: seconds is int && undoSendChoices.contains(seconds)
          ? seconds
          : d.undoSendSeconds,
    );
  }
}

class MailUxSettingsNotifier extends Notifier<MailUxSettings> {
  bool _touched = false;

  @override
  MailUxSettings build() {
    Future.microtask(_load);
    return const MailUxSettings();
  }

  Future<void> _load() async {
    try {
      final json = await ref.read(mailPrefsStoreProvider).readUx();
      if (ref.mounted && !_touched) state = MailUxSettings.fromJson(json);
    } on Object catch (e) {
      DiagnosticLog.warn('mail', 'ux preferences unreadable', error: e);
    }
  }

  Future<void> update(MailUxSettings value) async {
    _touched = true;
    state = value;
    try {
      await ref.read(mailPrefsStoreProvider).writeUx(value.toJson());
    } on Object catch (e) {
      DiagnosticLog.warn('mail', 'ux preferences not saved', error: e);
    }
  }
}

final mailUxSettingsProvider =
    NotifierProvider<MailUxSettingsNotifier, MailUxSettings>(
      MailUxSettingsNotifier.new,
    );

/// The folder «В архив» moves to, when the mailbox has one (the current Mail
/// API lists none, so the option stays hidden until the server adds it).
final mailArchiveFolderProvider = Provider<String?>((ref) {
  final summary = ref.watch(mailSummaryProvider).summary;
  return mailArchiveFolderOf(summary);
});

String? mailArchiveFolderOf(MailSummary? summary) {
  if (summary == null) return null;
  for (final f in summary.folders) {
    if (f.type == 'archive') return f.type;
  }
  return null;
}

/// Recently used recipient addresses (most recent first, at most [max]).
class MailRecentRecipientsNotifier extends Notifier<List<String>> {
  static const max = 50;
  bool _touched = false;

  @override
  List<String> build() {
    Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    try {
      final list = await ref
          .read(mailPrefsStoreProvider)
          .readRecentRecipients();
      if (ref.mounted && !_touched) state = list;
    } on Object catch (e) {
      DiagnosticLog.warn('mail', 'recent recipients unreadable', error: e);
    }
  }

  static List<String> merge(List<String> current, Iterable<String> used) {
    final fresh = EmailAddress.dedupe(used).where(EmailAddress.isBare).toList();
    return EmailAddress.dedupe([...fresh, ...current]).take(max).toList();
  }

  Future<void> remember(Iterable<String> addresses) async {
    _touched = true;
    state = merge(state, addresses);
    try {
      await ref.read(mailPrefsStoreProvider).writeRecentRecipients(state);
    } on Object catch (e) {
      DiagnosticLog.warn('mail', 'recent recipients not saved', error: e);
    }
  }

  Future<void> clear() async {
    _touched = true;
    state = const [];
    await ref.read(mailPrefsStoreProvider).clearRecentRecipients();
  }
}

final mailRecentRecipientsProvider =
    NotifierProvider<MailRecentRecipientsNotifier, List<String>>(
      MailRecentRecipientsNotifier.new,
    );
