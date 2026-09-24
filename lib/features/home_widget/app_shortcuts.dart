import 'package:quick_actions/quick_actions.dart';

import '../../core/routing/deep_links.dart';

/// App icon shortcuts (long-press the launcher icon).
///
/// * Android: «Написать», «Позвонить», «Избранное», «Поиск» are static
///   (android/app/src/main/res/xml/shortcuts.xml, `xatbox://` links, usable
///   before the app ever ran). The three most recent chats are published at
///   runtime as dynamic shortcuts through quick_actions. Launchers show a
///   limited number (often 4–5, static first); every shortcut can also be
///   dragged to the home screen.
/// * iOS: the four fixed actions as Quick Actions (iOS shows at most four).
///
/// Every action becomes an `xatbox://` link and goes through the pending
/// navigation of link_router.dart, i.e. after sign-in and the app lock.
abstract final class ShortcutTypes {
  static const newMessage = 'new_message';
  static const newCall = 'new_call';
  static const saved = 'saved';
  static const search = 'search';
  static const chatPrefix = 'chat:';

  static String chat(String conversationId) => '$chatPrefix$conversationId';
}

/// Most recent chats published as dynamic shortcuts (Android).
const maxRecentChatShortcuts = 3;

/// Android drawable of a recent-chat shortcut.
const chatShortcutIcon = 'ic_shortcut_chat';

class LauncherShortcut {
  const LauncherShortcut({required this.type, required this.title, this.icon});

  final String type;
  final String title;

  /// Android drawable / iOS image asset name; null = none.
  final String? icon;

  @override
  bool operator ==(Object other) =>
      other is LauncherShortcut &&
      other.type == type &&
      other.title == title &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(type, title, icon);
}

typedef ShortcutLabels = ({
  String newMessage,
  String call,
  String saved,
  String search,
});

/// The `xatbox://` link a shortcut type opens (null = unknown type).
Uri? shortcutLink(String type) {
  switch (type) {
    case ShortcutTypes.newMessage:
      return Uri.parse('${DeepLinks.scheme}://new/chat');
    case ShortcutTypes.newCall:
      return Uri.parse('${DeepLinks.scheme}://new/call');
    case ShortcutTypes.saved:
      return Uri.parse('${DeepLinks.scheme}://chat/saved');
    case ShortcutTypes.search:
      return Uri.parse('${DeepLinks.scheme}://search');
  }
  if (type.startsWith(ShortcutTypes.chatPrefix) &&
      type.length > ShortcutTypes.chatPrefix.length) {
    return Uri(
      scheme: DeepLinks.scheme,
      host: 'chat',
      pathSegments: [type.substring(ShortcutTypes.chatPrefix.length)],
    );
  }
  return null;
}

/// Shortcuts to publish at runtime (see the class comment above).
/// [recentChats] are in list order; their titles are only used when the app
/// does not hide content (the caller passes an empty list then).
List<LauncherShortcut> runtimeShortcuts({
  required bool ios,
  required ShortcutLabels labels,
  List<({String id, String title})> recentChats = const [],
}) {
  if (ios) {
    return [
      LauncherShortcut(type: ShortcutTypes.newMessage, title: labels.newMessage),
      LauncherShortcut(type: ShortcutTypes.newCall, title: labels.call),
      LauncherShortcut(type: ShortcutTypes.saved, title: labels.saved),
      LauncherShortcut(type: ShortcutTypes.search, title: labels.search),
    ];
  }
  return [
    for (final c in recentChats.where((c) => c.title.trim().isNotEmpty).take(
      maxRecentChatShortcuts,
    ))
      LauncherShortcut(
        type: ShortcutTypes.chat(c.id),
        title: c.title.trim(),
        icon: chatShortcutIcon,
      ),
  ];
}

/// Platform side of the shortcuts (fake in tests).
abstract class LauncherShortcutsBridge {
  /// [onAction] receives the type of a tapped shortcut (also the one the app
  /// was launched with).
  Future<void> initialize(void Function(String type) onAction);

  /// Replaces the runtime shortcuts; an empty list removes them.
  Future<void> publish(List<LauncherShortcut> items);
}

class QuickActionsBridge implements LauncherShortcutsBridge {
  const QuickActionsBridge();

  static const _plugin = QuickActions();

  @override
  Future<void> initialize(void Function(String type) onAction) =>
      _plugin.initialize(onAction);

  @override
  Future<void> publish(List<LauncherShortcut> items) => items.isEmpty
      ? _plugin.clearShortcutItems()
      : _plugin.setShortcutItems([
          for (final i in items)
            ShortcutItem(type: i.type, localizedTitle: i.title, icon: i.icon),
        ]);
}
