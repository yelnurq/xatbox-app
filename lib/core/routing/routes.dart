/// Route paths. Keep in one place so deep links and navigation agree.
abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';

  // Bottom-navigation branches.
  static const mail = '/mail';
  static const chat = '/chat';
  static const calls = '/calls';
  static const contacts = '/contacts';
  // «Сегодня»: a fifth branch, shown in the bar only when it is the start
  // screen (Настройки → Оформление → «Начальный экран»).
  static const today = '/today';

  // «Единый поиск» over the bottom bar (app bars, `xatbox://search`,
  // launcher shortcut «Поиск»).
  static const search = '/search';

  // Contacts: profile over the bottom bar.
  static const contactProfile = '/contacts/u/:id';
  static String contactProfilePath(String id) =>
      '/contacts/u/${Uri.encodeComponent(id)}';

  // In-app notifications (entered from the app bar).
  static const notifications = '/notifications';

  // Official messages (entered from the mail drawer «Рабочее пространство»).
  static const official = '/official';
  static const officialNew = '/official/new';
  static const officialMessage = '/official/m/:id';
  static String officialMessagePath(String id) =>
      '/official/m/${Uri.encodeComponent(id)}';
  static const officialStats = '/official/m/:id/stats';
  static String officialStatsPath(String id) =>
      '/official/m/${Uri.encodeComponent(id)}/stats';

  // Mail sub-screens (full-screen over the bottom bar).
  static const mailMessage = '/mail/message/:id';
  static String mailMessagePath(String id) =>
      '/mail/message/${Uri.encodeComponent(id)}';
  static const mailCompose = '/mail/compose';

  // Chat sub-screens.
  static const chatNew = '/chat/new';
  static const chatConversation = '/chat/c/:id';
  static String chatConversationPath(String id) =>
      '/chat/c/${Uri.encodeComponent(id)}';
  static const chatInfo = '/chat/c/:id/info';
  static String chatInfoPath(String id) =>
      '/chat/c/${Uri.encodeComponent(id)}/info';
  static const chatAddMembers = '/chat/c/:id/add';
  static String chatAddMembersPath(String id) =>
      '/chat/c/${Uri.encodeComponent(id)}/add';
  // «Медиа, файлы, ссылки, голосовые» (pops with a message id to jump to).
  static const chatMedia = '/chat/c/:id/media';
  static String chatMediaPath(String id) =>
      '/chat/c/${Uri.encodeComponent(id)}/media';
  // Comments of a channel post (thread screen; `chat.comment` push taps).
  static const chatComments = '/chat/c/:id/comments/:postId';
  static String chatCommentsPath(String id, String postId) =>
      '/chat/c/${Uri.encodeComponent(id)}/comments/${Uri.encodeComponent(postId)}';
  // Chat picker for content shared from other apps.
  static const chatShare = '/chat/share';
  // Moderation queue (Settings → «Модерация») and one report.
  static const chatModeration = '/chat/moderation';
  static const chatModerationReport = '/chat/moderation/:id';
  static String chatModerationReportPath(String id) =>
      '/chat/moderation/${Uri.encodeComponent(id)}';
  // Launcher shortcuts: «Избранное» (resolved to its conversation) and the
  // chat list with the search field open.
  static const chatSaved = '/chat/saved';
  static const chatSearch = '/chat/search';

  // Calls: the call screen and the new-call picker over the bottom bar.
  static const call = '/call';
  static const callsNew = '/calls/new';
  static const callDetails = '/calls/c/:id';
  static String callDetailsPath(String id) =>
      '/calls/c/${Uri.encodeComponent(id)}';
  // Scheduled meeting pre-join (xatbox://meet/<code>, meeting links).
  static const meet = '/meet/:code';
  static String meetPath(String code) => '/meet/${Uri.encodeComponent(code)}';

  // Calendar (full-screen over the bottom bar; entered from the tab roots).
  static const calendar = '/calendar';
  static const calendarNew = '/calendar/new';
  static const calendarEdit = '/calendar/edit';
  static const calendarSearch = '/calendar/search';
  static String calendarSearchPath(String query) => query.isEmpty
      ? calendarSearch
      : '$calendarSearch?q=${Uri.encodeQueryComponent(query)}';
  static const calendarInvitations = '/calendar/invitations';
  static const calendarEvent = '/calendar/event/:id';
  static String calendarEventPath(String id, [String? occurrenceStart]) =>
      '/calendar/event/${Uri.encodeComponent(id)}'
      '${occurrenceStart == null ? '' : '?occ=${Uri.encodeQueryComponent(occurrenceStart)}'}';

  // Tasks («Мои задачи»; entered from the mail sidebar, notifications and
  // xatbox://tasks[/id]). The id variant opens that task over the list.
  static const tasks = '/tasks';
  static const task = '/tasks/:id';
  static String taskPath(String id) => '/tasks/${Uri.encodeComponent(id)}';

  static const profile = '/profile';
  static const settings = '/settings';
  static const settingsAppearance = '/settings/appearance';
  static const settingsSecurity = '/settings/security';
  static const settingsNotifications = '/settings/notifications';

  // Mail settings (entered from Settings and the mail account menu).
  static const settingsMail = '/settings/mail';
  static const settingsMailSignature = '/settings/mail/signature';
  static const settingsMailVacation = '/settings/mail/vacation';
  static const settingsMailBlockedSenders = '/settings/mail/blocked-senders';
  static const settingsMailBookmarkFolders = '/settings/mail/bookmark-folders';
  static const settingsMailClients = '/settings/mail/clients';
  static const settingsMailImport = '/settings/mail/import';

  // App: in-app update, devices & sessions, about, problem report.
  static const settingsUpdate = '/settings/update';
  static const settingsSessions = '/settings/sessions';
  static const settingsShortcuts = '/settings/shortcuts';
  static const settingsAbout = '/settings/about';
  static const reportProblem = '/settings/report';
}
