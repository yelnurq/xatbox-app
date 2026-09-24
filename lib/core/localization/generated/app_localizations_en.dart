// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'XatBox';

  @override
  String get chatFilterChannels => 'Channels';

  @override
  String get channelsDiscoverTitle => 'Organization channels';

  @override
  String get channelsSearchHint => 'Search channels';

  @override
  String get channelsEmpty => 'Your organization has no public channels yet';

  @override
  String get channelsNothingFound => 'Nothing found';

  @override
  String get channelSubscribe => 'Subscribe';

  @override
  String get channelSubscribed => 'Subscribed';

  @override
  String get channelUnsubscribe => 'Unsubscribe';

  @override
  String channelUnsubscribeConfirm(String title) {
    return 'Unsubscribe from “$title”?';
  }

  @override
  String channelSubscribersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subscribers',
      one: '$count subscriber',
    );
    return '$_temp0';
  }

  @override
  String get channelCreate => 'Create channel';

  @override
  String get channelNameLabel => 'Channel name';

  @override
  String get channelDescriptionLabel => 'Description (optional)';

  @override
  String get channelPublic => 'Public channel';

  @override
  String get channelPublicHint =>
      'Anyone in the organization can find it in “Organization channels” and subscribe';

  @override
  String get channelPrivateHint => 'Channel admins add subscribers';

  @override
  String get channelReadOnly => 'Only channel admins can post';

  @override
  String get channelBadge => 'Channel';

  @override
  String get channelSubscribers => 'Subscribers';

  @override
  String get channelAdmins => 'Admins';

  @override
  String get channelAddSubscriber => 'Add subscriber';

  @override
  String channelViews(int count) {
    return 'Views: $count';
  }

  @override
  String get channelNoPermission => 'You are not allowed to create channels';

  @override
  String get pollAttach => 'Poll';

  @override
  String get pollNewTitle => 'New poll';

  @override
  String get pollQuestionLabel => 'Question';

  @override
  String get pollOptionsLabel => 'Options';

  @override
  String pollOptionHint(int n) {
    return 'Option $n';
  }

  @override
  String get pollAddOption => 'Add option';

  @override
  String get pollRemoveOption => 'Remove option';

  @override
  String get pollAnonymous => 'Anonymous voting';

  @override
  String get pollMultiple => 'Multiple answers';

  @override
  String get pollQuiz => 'Quiz mode';

  @override
  String get pollQuizHint => 'Mark the correct answer';

  @override
  String get pollCloseSection => 'Close automatically';

  @override
  String get pollCloseNever => 'Never';

  @override
  String get pollClose1h => 'In an hour';

  @override
  String get pollClose1d => 'In 24 hours';

  @override
  String get pollCloseWeek => 'In a week';

  @override
  String get pollCreate => 'Create';

  @override
  String get pollErrorQuestion => 'Enter a question';

  @override
  String get pollErrorOptions => 'Add 2 to 10 different options';

  @override
  String get pollKindAnonymous => 'Anonymous poll';

  @override
  String get pollKindPublic => 'Public poll';

  @override
  String get pollKindQuiz => 'Quiz';

  @override
  String get pollClosed => 'Poll closed';

  @override
  String get pollVote => 'Vote';

  @override
  String get pollRetract => 'Retract vote';

  @override
  String get pollCloseNow => 'Close poll';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '$count vote',
      zero: 'No votes',
    );
    return '$_temp0';
  }

  @override
  String pollEndsAt(String time) {
    return 'until $time';
  }

  @override
  String get pollVotersTitle => 'Voters';

  @override
  String get pollNoVoters => 'Nobody has chosen this option yet';

  @override
  String get pollCorrect => 'Correct answer';

  @override
  String get scheduleSendLater => 'Send later';

  @override
  String get scheduleIn1h => 'In 1 hour';

  @override
  String get scheduleTonight => 'This evening';

  @override
  String get scheduleTomorrowMorning => 'Tomorrow morning';

  @override
  String get schedulePick => 'Pick date and time';

  @override
  String get scheduleTooEarly => 'Pick a time in the future';

  @override
  String get scheduledTitle => 'Scheduled';

  @override
  String scheduledBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scheduled messages',
      one: '$count scheduled message',
    );
    return '$_temp0';
  }

  @override
  String get scheduledEmpty => 'No scheduled messages';

  @override
  String get scheduledSendNow => 'Send now';

  @override
  String get scheduledEditText => 'Edit text';

  @override
  String get scheduledEditTime => 'Change time';

  @override
  String get scheduledFailed => 'Not sent';

  @override
  String scheduledCreated(String when) {
    return 'The message will be sent $when';
  }

  @override
  String scheduledAttachments(int count) {
    return 'Attachments: $count';
  }

  @override
  String get remindAction => 'Remind me';

  @override
  String get remindSheetTitle => 'Remind me about this message';

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersEmpty => 'No reminders';

  @override
  String get remindersEmptyHint =>
      'Long-press a message and choose “Remind me”';

  @override
  String get remindersUpcoming => 'Upcoming';

  @override
  String get remindersDone => 'Past';

  @override
  String reminderSetDone(String when) {
    return 'I\'ll remind you $when';
  }

  @override
  String get reminderReschedule => 'Reschedule';

  @override
  String get reminderDelete => 'Delete reminder';

  @override
  String get reminderNotificationTitle => 'Reminder';

  @override
  String get notifPrefsChannels => 'Channels';

  @override
  String chatWhenToday(String time) {
    return 'today at $time';
  }

  @override
  String chatWhenTomorrow(String time) {
    return 'tomorrow at $time';
  }

  @override
  String chatWhenDate(String date, String time) {
    return '$date at $time';
  }

  @override
  String get tabMail => 'Mail';

  @override
  String get tabChat => 'Chat';

  @override
  String get tabCalls => 'Calls';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get chatComingSoonBody =>
      'The chat module arrives in a future update.';

  @override
  String get callsComingSoonBody =>
      'The calls module arrives in a future update.';

  @override
  String get splashChecking => 'Checking session…';

  @override
  String get splashUnreachableTitle => 'Server unreachable';

  @override
  String get splashUnreachableBody =>
      'Could not verify the session. Check your connection and try again.';

  @override
  String get splashSignInAgain => 'Sign in again';

  @override
  String get loginTitle => 'Sign in to XatBox';

  @override
  String get loginSubtitle => 'Use your corporate mail account';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginButton => 'Sign in';

  @override
  String get loginEmailRequired => 'Enter your email';

  @override
  String get loginPasswordRequired => 'Enter your password';

  @override
  String get loginEmailInvalid => 'Invalid email';

  @override
  String get sessionExpiredBanner =>
      'Your session has expired. Please sign in again.';

  @override
  String get errInvalidCredentialsFormat => 'Enter your email and password.';

  @override
  String get errInvalidCredentials => 'Wrong email or password.';

  @override
  String get errUserDisabled =>
      'This account is disabled. Contact your administrator.';

  @override
  String get errOrganizationSuspended =>
      'Your organization\'s subscription is suspended. Contact your administrator.';

  @override
  String get errDirectoryDisabled =>
      'Directory sign-in is disabled. Contact your administrator.';

  @override
  String get errTooManyAttempts =>
      'Too many sign-in attempts. Try again later.';

  @override
  String get errDirectoryUnavailable =>
      'The corporate directory is unavailable. Try again later.';

  @override
  String get errSubscriptionLimit =>
      'The organization\'s user limit has been reached. Contact your administrator.';

  @override
  String get errInternal => 'Server error. Try again later.';

  @override
  String get errNetwork =>
      'No connection to the server. Check your internet connection.';

  @override
  String get errTimeout => 'The server is taking too long. Try again.';

  @override
  String get errUnauthenticated =>
      'Your session has expired. Please sign in again.';

  @override
  String get errForbidden => 'You do not have permission for this action.';

  @override
  String get errNoMailbox => 'Your account has no active mailbox.';

  @override
  String get errMailServiceUnavailable =>
      'The mail service is temporarily unavailable.';

  @override
  String get errMessageNotFound => 'Message not found.';

  @override
  String get errFolderNotFound => 'Folder not found.';

  @override
  String errInvalidMessage(String detail) {
    return 'The message failed validation: $detail';
  }

  @override
  String get errInvalidBody => 'Invalid request. Please update the app.';

  @override
  String get errAttachmentTooLarge => 'The file is too large.';

  @override
  String get errStorageUnavailable =>
      'File storage is unavailable. Try again later.';

  @override
  String get errConverterUnavailable =>
      'Document preview is not available on the server.';

  @override
  String get errNotConvertible => 'This file cannot be shown as PDF.';

  @override
  String get errConvertTimeout => 'Preview timed out.';

  @override
  String get errConvertFailed => 'Could not prepare the preview.';

  @override
  String errUnknown(String code) {
    return 'Something went wrong ($code).';
  }

  @override
  String get errUnexpected => 'Unexpected server response.';

  @override
  String errRequestId(String id) {
    return 'Request id: $id';
  }

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get close => 'Close';

  @override
  String get delete => 'Delete';

  @override
  String get send => 'Send';

  @override
  String get save => 'Save';

  @override
  String get search => 'Search';

  @override
  String get loading => 'Loading…';

  @override
  String get offlineBanner => 'Offline — showing saved data';

  @override
  String get offlineProfileBanner => 'Server unreachable, working offline';

  @override
  String get folderInbox => 'Inbox';

  @override
  String get folderSent => 'Sent';

  @override
  String get folderDrafts => 'Drafts';

  @override
  String get folderSpam => 'Spam';

  @override
  String get folderTrash => 'Trash';

  @override
  String get folderBookmarks => 'Bookmarks';

  @override
  String get sectionSmartFolders => 'Smart folders';

  @override
  String get sectionBookmarkFolders => 'Bookmark folders';

  @override
  String get mailEmptyFolder => 'No messages in this folder';

  @override
  String get mailEmptySearch => 'Nothing found';

  @override
  String get mailSearchHint => 'Search in folder';

  @override
  String get filterUnread => 'Unread';

  @override
  String get filterStarred => 'Bookmarked';

  @override
  String get filterAttachments => 'With attachments';

  @override
  String get mailNoSubject => '(no subject)';

  @override
  String get mailLoadMoreError => 'Could not load more';

  @override
  String get mailMarkRead => 'Mark as read';

  @override
  String get mailMarkUnread => 'Mark as unread';

  @override
  String get mailStar => 'Bookmark';

  @override
  String get mailUnstar => 'Remove bookmark';

  @override
  String get mailMoveToTrash => 'Move to Trash';

  @override
  String get mailDeleteForever => 'Delete forever';

  @override
  String get mailDeleteForeverConfirm =>
      'The message will be deleted permanently. Continue?';

  @override
  String get mailReportSpam => 'Report spam';

  @override
  String get mailReportNotSpam => 'Not spam';

  @override
  String get mailMoveTo => 'Move to…';

  @override
  String get mailReply => 'Reply';

  @override
  String get mailReplyAll => 'Reply all';

  @override
  String get mailForward => 'Forward';

  @override
  String get mailCompose => 'Compose';

  @override
  String get mailNoPermission => 'You do not have access to mail.';

  @override
  String get mailAttachments => 'Attachments';

  @override
  String get attachmentOpen => 'Open';

  @override
  String get attachmentPreviewPdf => 'Preview (PDF)';

  @override
  String get attachmentDownloading => 'Downloading file…';

  @override
  String get attachmentNoApp => 'No app can open this file';

  @override
  String get mailFrom => 'From';

  @override
  String get mailTo => 'To';

  @override
  String get mailCc => 'Cc';

  @override
  String get mailBcc => 'Bcc';

  @override
  String get mailSubject => 'Subject';

  @override
  String get mailBody => 'Message';

  @override
  String mailThreadTitle(int count) {
    return 'Conversation ($count)';
  }

  @override
  String get mailShowHtml => 'Show formatting';

  @override
  String get mailShowText => 'Show as text';

  @override
  String get mailNoBody => '(empty message)';

  @override
  String get mailRemoteContentBlocked => 'Remote images are blocked';

  @override
  String get mailOpenLinkTitle => 'Open link?';

  @override
  String get mailOpen => 'Open';

  @override
  String mailUnreadCount(int count) {
    return '$count unread';
  }

  @override
  String get mailActionDone => 'Done';

  @override
  String get mailMovedToTrash => 'Message moved to Trash';

  @override
  String get mailDeleted => 'Message deleted';

  @override
  String get mailReportedSpam => 'Message reported as spam';

  @override
  String get mailReportedHam => 'Message moved back to Inbox';

  @override
  String get composeTitleNew => 'New message';

  @override
  String get composeTitleReply => 'Reply';

  @override
  String get composeTitleForward => 'Forward';

  @override
  String get composeTitleDraft => 'Draft';

  @override
  String get composeRecipientsRequired => 'Add at least one recipient';

  @override
  String composeInvalidAddress(String address) {
    return 'Invalid address: $address';
  }

  @override
  String get composeTooManyRecipients => 'Too many recipients (max 100)';

  @override
  String get composeSubjectTooLong => 'Subject is too long';

  @override
  String get composeTooManyAttachments => 'At most 20 attachments';

  @override
  String composeAttachmentTooLarge(String name, String limit) {
    return 'File \"$name\" exceeds the $limit limit';
  }

  @override
  String get composeAddAttachment => 'Attach file';

  @override
  String get composeSent => 'Message sent';

  @override
  String get composeSaveDraft => 'Save draft';

  @override
  String get composeDraftSaved => 'Draft saved';

  @override
  String get composeDiscard => 'Discard';

  @override
  String get composeDiscardTitle => 'Close message?';

  @override
  String get composeDiscardBody => 'Unsaved changes will be lost.';

  @override
  String get composeSending => 'Sending…';

  @override
  String get composeForwardedAttachments =>
      'Attachments from the original message';

  @override
  String get composeSignatureNote =>
      'The server adds your signature when sending.';

  @override
  String composeQuoteHeader(String date, String from) {
    return 'On $date, $from wrote:';
  }

  @override
  String get composeForwardHeader => '---------- Forwarded message ----------';

  @override
  String get composeRecipientHint => 'comma-separated addresses';

  @override
  String get composeNoSendPermission => 'You are not allowed to send mail.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileSessions => 'Active sessions';

  @override
  String get profileCurrentSession => 'Current';

  @override
  String get profileEndSession => 'End';

  @override
  String get profileEndOthers => 'End all other sessions';

  @override
  String get profileDepartment => 'Department';

  @override
  String profileSessionsEnded(int count) {
    return 'Sessions ended: $count';
  }

  @override
  String profileExpires(String date) {
    return 'Valid until $date';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLogout => 'Sign out';

  @override
  String get settingsLogoutConfirm => 'Sign out on this device?';

  @override
  String get settingsCacheSection => 'Storage & data';

  @override
  String get settingsCacheLimit => 'Keep opened messages offline';

  @override
  String get settingsCacheClear => 'Clear cache';

  @override
  String get settingsCacheCleared => 'Cache cleared';

  @override
  String settingsCacheStats(int messages, int lists) {
    return 'Cached: $messages messages, $lists lists';
  }

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsDiagnostics => 'Diagnostics';

  @override
  String get settingsDiagnosticsEmpty => 'No events yet';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationsHint =>
      'Which push notifications to get, quiet hours';

  @override
  String get settingsSendErrorReports => 'Send error reports';

  @override
  String get settingsSendErrorReportsHint =>
      'Technical crash data goes only to the XatBox server, without message texts or addresses';

  @override
  String get notifPrefsServerHint =>
      'Stored on the server: disabled notifications are not sent at all';

  @override
  String get notifPrefsTypesSection => 'Notify me about';

  @override
  String get notifPrefsDirect => 'Direct messages';

  @override
  String get notifPrefsGroups => 'Groups';

  @override
  String get notifPrefsMentionsOnly => 'Only mentions in groups';

  @override
  String get notifPrefsCalls => 'Calls';

  @override
  String get notifPrefsQuietSection => 'Quiet hours';

  @override
  String get notifPrefsQuietEnabled => 'Do not disturb during quiet hours';

  @override
  String notifPrefsQuietHint(String zone) {
    return 'Every day, device time ($zone)';
  }

  @override
  String get notifPrefsQuietStart => 'Starts';

  @override
  String get notifPrefsQuietEnd => 'Ends';

  @override
  String get notifPrefsQuietAllowCalls => 'Let calls ring during quiet hours';

  @override
  String get notifPrefsQuietAllowCallsHint => 'Incoming calls ring as usual';

  @override
  String get notifPrefsPending =>
      'Changes will be sent when you are back online';

  @override
  String get notifPrefsLoadFailed => 'Could not load notification settings';

  @override
  String get notifPrefsRetry => 'Retry';

  @override
  String get notifPrefsSystemSettings => 'System notification settings';

  @override
  String get notifPrefsSystemSettingsHint =>
      'Sound, vibration and Android channels';

  @override
  String get notifBackgroundSection => 'Connection';

  @override
  String get notifBackgroundTitle => 'Stay connected in background';

  @override
  String get notifBackgroundOneMinute => '1 minute';

  @override
  String get notifBackgroundFifteenMinutes => '15 minutes';

  @override
  String get notifBackgroundAlways => 'Always';

  @override
  String notifBackgroundAuto(String value) {
    return 'Default ($value)';
  }

  @override
  String get notifBackgroundHint =>
      'How long the app keeps its connection after you leave it. Once closed, new messages and calls arrive only through push notifications. The connection is never closed during a call.';

  @override
  String get notifBackgroundNoPush =>
      'Push notifications are not set up: while disconnected, messages and incoming calls do not arrive';

  @override
  String get notifBackgroundAlwaysWarning => 'Uses more battery';

  @override
  String get permOnboardNotifTitle => 'Turn on notifications?';

  @override
  String get permOnboardNotifBody =>
      'XatBox will tell you about new messages, incoming calls and calendar reminders. Android will ask for permission — tap “Allow”.';

  @override
  String get permOnboardFsiTitle => 'Full-screen calls';

  @override
  String get permOnboardFsiBody =>
      'To see incoming calls on the lock screen, allow XatBox to use full-screen notifications. Android settings will open: turn the switch on and come back to the app.';

  @override
  String get permAllow => 'Allow';

  @override
  String get permNotNow => 'Not now';

  @override
  String get permOpenSettings => 'Open settings';

  @override
  String get notifDeviceSection => 'This phone';

  @override
  String get notifDeviceNotifications => 'Notification permission';

  @override
  String get notifDeviceGranted => 'Allowed';

  @override
  String get notifDeviceNotificationsOff =>
      'Off: messages, calls and reminders are not shown';

  @override
  String get notifDeviceFullScreen => 'Full-screen calls';

  @override
  String get notifDeviceFullScreenOff =>
      'Off: an incoming call shows only as a small notification';

  @override
  String get notifDeviceBattery => 'No battery restrictions';

  @override
  String get notifDeviceBatteryOn =>
      'Android does not delay the app in the background';

  @override
  String get notifDeviceBatteryOff =>
      'Android may delay messages and reminders while the phone is idle';

  @override
  String get notifDeviceBatteryNoPush =>
      'While push notifications are not set up this matters most: without restrictions the app stays connected longer';

  @override
  String get notifDeviceHelp => 'Autostart and background work';

  @override
  String get notifDeviceHelpHint =>
      'Xiaomi, Huawei, Honor, Samsung, Oppo, Realme';

  @override
  String get bgHelpTitle => 'Background work';

  @override
  String get bgHelpIntro =>
      'Some manufacturers close background apps more aggressively than stock Android. If messages or calls arrive late, check the settings below. Item names may differ slightly between firmware versions.';

  @override
  String get bgHelpCommonTitle => 'All phones';

  @override
  String get bgHelpCommonSteps =>
      '1. Settings → Apps → XatBox → Notifications: turn on all categories.\n2. Same place → Battery: “Unrestricted” (“Don\'t optimise”).\n3. Don\'t swipe XatBox away from recent apps while you expect a call.';

  @override
  String get bgHelpXiaomiTitle => 'Xiaomi, Redmi, POCO (MIUI, HyperOS)';

  @override
  String get bgHelpXiaomiSteps =>
      '1. Settings → Apps → Manage apps → XatBox.\n2. Turn on “Autostart”.\n3. “Battery saver” → “No restrictions”.\n4. “Other permissions”: allow “Show on lock screen” and “Display pop-up windows while running in the background”.\n5. In recent apps, pull the XatBox card down and lock it.';

  @override
  String get bgHelpHuaweiTitle => 'Huawei, Honor (EMUI, MagicOS)';

  @override
  String get bgHelpHuaweiSteps =>
      '1. Settings → Battery → App launch.\n2. Find XatBox and turn off “Manage automatically”.\n3. In the dialog turn on “Auto-launch”, “Secondary launch” and “Run in background”.\n4. Settings → Notifications → XatBox: allow notifications on the lock screen.';

  @override
  String get bgHelpSamsungTitle => 'Samsung (One UI)';

  @override
  String get bgHelpSamsungSteps =>
      '1. Settings → Apps → XatBox → Battery: “Unrestricted”.\n2. Settings → Battery → Background usage limits: XatBox must not be in “Sleeping apps” or “Deep sleeping apps”.\n3. Add XatBox to “Never sleeping apps”.';

  @override
  String get bgHelpOppoTitle => 'Oppo, Realme, OnePlus, Vivo';

  @override
  String get bgHelpOppoSteps =>
      '1. Settings → Apps → XatBox → Battery usage: allow “Background activity” and “Auto launch”.\n2. Settings → Battery → Optimisation: set XatBox to “Don\'t optimise”.\n3. Lock XatBox in recent apps.';

  @override
  String get bgHelpCheck =>
      'To check: lock the phone for 15 minutes and ask a colleague to message or call you.';

  @override
  String get a11ySearchPrevious => 'Previous match';

  @override
  String get a11ySearchNext => 'Next match';

  @override
  String get a11yMuted => 'muted';

  @override
  String get a11yPinned => 'pinned';

  @override
  String a11yUnreadCount(int count) {
    return '$count unread';
  }

  @override
  String get a11yMarkedUnread => 'marked as unread';

  @override
  String get a11yMicOff => 'microphone off';

  @override
  String a11yHandsRaised(int count) {
    return 'raised hands: $count';
  }

  @override
  String get a11yVoiceSeek => 'Seek voice message';

  @override
  String a11yPinEntered(int filled, int length) {
    return '$filled of $length digits entered';
  }

  @override
  String get a11yDecrease => 'Decrease';

  @override
  String get a11yIncrease => 'Increase';

  @override
  String get a11yAdd => 'Add';

  @override
  String a11yReaction(String emoji, int count) {
    return 'Reaction $emoji: $count';
  }

  @override
  String a11yVoiceMessage(String duration) {
    return 'Voice message, $duration';
  }

  @override
  String get a11ySelected => 'selected';

  @override
  String get a11yFavourite => 'favourite';

  @override
  String get a11yGuest => 'guest';

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatDisabled => 'Chat is not configured in this build.';

  @override
  String get chatNoAccess => 'You do not have access to chat.';

  @override
  String get chatEmpty =>
      'No chats yet. Start a conversation with a colleague.';

  @override
  String get chatNew => 'New chat';

  @override
  String get chatNewGroup => 'New group';

  @override
  String get chatGroupTitle => 'Group name';

  @override
  String get chatCreateGroup => 'Create group';

  @override
  String get chatSearchUsers => 'Search by name or email';

  @override
  String get chatSearch => 'Search chats';

  @override
  String get chatSearchMessages => 'Messages';

  @override
  String get chatNoUsers => 'Nobody found';

  @override
  String chatSelectedMembers(int count) {
    return 'Selected: $count';
  }

  @override
  String get chatConnecting => 'Connecting…';

  @override
  String get chatSyncing => 'Updating…';

  @override
  String get chatOffline => 'No connection';

  @override
  String get chatOnline => 'online';

  @override
  String chatLastSeen(String when) {
    return 'last seen $when';
  }

  @override
  String chatMembersCount(int count) {
    return '$count members';
  }

  @override
  String chatTyping(String name) {
    return '$name is typing…';
  }

  @override
  String get chatTypingMany => 'typing…';

  @override
  String chatRecording(String name) {
    return '$name is recording…';
  }

  @override
  String get chatYou => 'You';

  @override
  String get chatMessageHint => 'Message';

  @override
  String get chatSend => 'Send';

  @override
  String get chatCameraTitle => 'Camera photo';

  @override
  String get chatCameraTake => 'Take a photo';

  @override
  String get chatCameraRetake => 'Retake';

  @override
  String get chatCameraDevice => 'Camera';

  @override
  String get chatCameraUnavailable =>
      'The camera is unavailable. Check that it is plugged in and not in use by another program.';

  @override
  String get chatAttach => 'Attach';

  @override
  String get chatVoiceHold => 'Hold to record';

  @override
  String get chatVoiceSlideCancel => '← Slide to cancel';

  @override
  String get chatVoiceLocked => 'Recording';

  @override
  String get chatVoiceCancel => 'Cancel';

  @override
  String get chatVoicePreview => 'Voice message';

  @override
  String get chatMicDenied =>
      'Microphone access denied. Allow it in system settings.';

  @override
  String get chatVoiceStartFailed =>
      'Could not start recording. Check the microphone.';

  @override
  String get chatVoiceSendFailed =>
      'Could not finish the recording. Try again.';

  @override
  String get chatOpenSettings => 'Open settings';

  @override
  String get chatReply => 'Reply';

  @override
  String get chatForward => 'Forward';

  @override
  String get chatCopy => 'Copy';

  @override
  String get chatEdit => 'Edit';

  @override
  String get chatDelete => 'Delete';

  @override
  String get chatReact => 'React';

  @override
  String get chatEdited => 'edited';

  @override
  String get chatDeleted => 'Message deleted';

  @override
  String get chatCopied => 'Copied';

  @override
  String get chatForwardTo => 'Forward to…';

  @override
  String get chatForwarded => 'Forwarded';

  @override
  String get chatReplyingTo => 'Replying to';

  @override
  String get chatEditing => 'Editing';

  @override
  String get chatPending => 'Sending…';

  @override
  String get chatFailed => 'Not sent';

  @override
  String get chatRetry => 'Retry';

  @override
  String get chatDiscard => 'Remove from queue';

  @override
  String get chatStatusSent => 'Sent';

  @override
  String get chatStatusDelivered => 'Delivered';

  @override
  String get chatStatusRead => 'Read';

  @override
  String get chatAttachmentImage => 'Photo';

  @override
  String get chatAttachmentVideo => 'Video';

  @override
  String get chatAttachmentVoice => 'Voice message';

  @override
  String get chatAttachmentAudio => 'Audio';

  @override
  String get chatAttachmentFile => 'File';

  @override
  String get chatFileOpen => 'Open';

  @override
  String get chatFileDownloading => 'Downloading…';

  @override
  String chatSystemMemberAdded(String actor, String user) {
    return '$actor added $user';
  }

  @override
  String chatSystemMemberRemoved(String actor, String user) {
    return '$actor removed $user';
  }

  @override
  String chatSystemMemberLeft(String user) {
    return '$user left the chat';
  }

  @override
  String chatSystemTitleChanged(String actor, String title) {
    return '$actor renamed the chat: $title';
  }

  @override
  String get chatSystemGeneric => 'System message';

  @override
  String get chatInfo => 'Info';

  @override
  String get chatMembers => 'Members';

  @override
  String get chatAddMember => 'Add member';

  @override
  String get chatRemoveMember => 'Remove from group';

  @override
  String get chatLeave => 'Leave group';

  @override
  String get chatLeaveConfirm =>
      'You will no longer receive messages from this group.';

  @override
  String get chatRename => 'Rename';

  @override
  String get chatRoleOwner => 'owner';

  @override
  String get chatRoleAdmin => 'admin';

  @override
  String get chatRoleMember => 'member';

  @override
  String get chatMakeAdmin => 'Make admin';

  @override
  String get chatMute => 'Mute';

  @override
  String get chatMuteHour => 'For 1 hour';

  @override
  String get chatMuteDay => 'For 24 hours';

  @override
  String get chatMuteForever => 'Forever';

  @override
  String get chatUnmute => 'Unmute';

  @override
  String get chatPin => 'Pin';

  @override
  String get chatUnpin => 'Unpin';

  @override
  String get chatArchive => 'Archive';

  @override
  String get chatUnarchive => 'Unarchive';

  @override
  String get chatArchived => 'Archive';

  @override
  String get chatPinnedMessage => 'Pinned message';

  @override
  String get chatPinMessage => 'Pin message';

  @override
  String get chatUnpinMessage => 'Unpin message';

  @override
  String get chatLoadOlder => 'Load earlier';

  @override
  String get chatNoMessages => 'No messages yet';

  @override
  String get chatToday => 'Today';

  @override
  String get chatYesterday => 'Yesterday';

  @override
  String get chatPrivacySection => 'Chat privacy';

  @override
  String get chatPrivacyLastSeen => 'Show last seen';

  @override
  String get chatPrivacyOnline => 'Show online status';

  @override
  String get chatPrivacyReadReceipts => 'Send read receipts';

  @override
  String get chatPrivacyPushPreview => 'Show message text in notifications';

  @override
  String chatCacheStats(int chats, int messages, int outbox) {
    return 'Chats: $chats, cached messages: $messages, queued: $outbox';
  }

  @override
  String get chatMentionHint => 'Mention';

  @override
  String get chatRateLimited => 'Too many messages. Please wait a moment.';

  @override
  String get chatFileTooLarge => 'The file is too large.';

  @override
  String get chatFileTypeForbidden => 'This file type cannot be sent.';

  @override
  String get chatFileInfected => 'The file was rejected by the antivirus.';

  @override
  String get chatAvUnavailable => 'Antivirus unavailable, try again later.';

  @override
  String get chatMessageTooLong => 'The message is too long.';

  @override
  String get chatConversationGone => 'This chat is no longer available.';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarViewMonth => 'Month';

  @override
  String get calendarViewWeek => 'Week';

  @override
  String get calendarViewDay => 'Day';

  @override
  String get calendarViewAgenda => 'Agenda';

  @override
  String get calendarNoEvents => 'No events';

  @override
  String get calendarNoEventsDay => 'Nothing planned for this day';

  @override
  String get calendarAllDay => 'All day';

  @override
  String get calendarOfflineCached => 'Offline — showing the saved calendar';

  @override
  String get calendarOfflineEmpty =>
      'Offline, and this period has not been loaded yet';

  @override
  String get calendarNoAccess => 'You don\'t have access to the calendar.';

  @override
  String get calendarNewEvent => 'New event';

  @override
  String get calendarEditEvent => 'Edit event';

  @override
  String get calendarSearch => 'Search events';

  @override
  String get calendarSearchHint => 'Title, place, organizer';

  @override
  String get calendarSearchEmpty => 'Nothing found';

  @override
  String get calendarSearchCachedOnly =>
      'Search covers the loaded months of the calendar.';

  @override
  String get calendarInvitations => 'Invitations';

  @override
  String get calendarInvitationsEmpty => 'No new invitations';

  @override
  String get calendarPendingSync => 'Waiting to sync';

  @override
  String get calendarSyncing => 'Updating…';

  @override
  String get calendarFieldTitle => 'Title';

  @override
  String get calendarFieldTitleRequired => 'Enter a title';

  @override
  String get calendarFieldTitleTooLong => 'The title is too long';

  @override
  String get calendarFieldStart => 'Starts';

  @override
  String get calendarFieldEnd => 'Ends';

  @override
  String get calendarFieldEndBeforeStart => 'The end must be after the start';

  @override
  String get calendarFieldTimezone => 'Time zone';

  @override
  String get calendarFieldLocation => 'Location';

  @override
  String get calendarFieldLink => 'Meeting link';

  @override
  String get calendarFieldLinkInvalid => 'Use an https://… link';

  @override
  String get calendarFieldDescription => 'Description';

  @override
  String get calendarFieldCategory => 'Category';

  @override
  String get calendarFieldPrivate => 'Private: only you see the description';

  @override
  String get calendarFieldRepeat => 'Repeat';

  @override
  String get calendarFieldReminders => 'Reminders';

  @override
  String get calendarFieldParticipants => 'Participants';

  @override
  String get calendarAddParticipant => 'Add participant';

  @override
  String get calendarAddReminder => 'Add';

  @override
  String get calendarExternalEmailHint => 'External participant email';

  @override
  String get calendarExternalEmailInvalid => 'Invalid email';

  @override
  String get calendarParticipantsUnavailable =>
      'The colleague directory is unavailable: the chat module is off.';

  @override
  String get calendarParticipantsOffline =>
      'Participants will load when the network is back.';

  @override
  String get calendarSearchColleagues => 'Search colleagues by name or email';

  @override
  String get calendarCategoryPersonal => 'Personal';

  @override
  String get calendarCategoryMeeting => 'Meeting';

  @override
  String get calendarCategoryDepartment => 'Department';

  @override
  String get calendarCategoryOrganization => 'Organization';

  @override
  String get calendarExternal => 'external participant';

  @override
  String get calendarRepeatNone => 'Does not repeat';

  @override
  String get calendarRepeatDaily => 'Daily';

  @override
  String get calendarRepeatWeekly => 'Weekly';

  @override
  String get calendarRepeatMonthly => 'Monthly';

  @override
  String get calendarRepeatYearly => 'Yearly';

  @override
  String calendarRepeatEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count days',
      one: 'Every day',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count weeks',
      one: 'Every week',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count months',
      one: 'Every month',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatEveryYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count years',
      one: 'Every year',
    );
    return '$_temp0';
  }

  @override
  String get calendarRepeatInterval => 'Interval';

  @override
  String get calendarRepeatEnds => 'Ends';

  @override
  String get calendarRepeatEndsNever => 'Never';

  @override
  String get calendarRepeatEndsOn => 'On date';

  @override
  String get calendarRepeatEndsAfter => 'After a number of times';

  @override
  String calendarRepeatUntil(String date) {
    return 'until $date';
  }

  @override
  String calendarRepeatTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      one: 'once',
    );
    return '$_temp0';
  }

  @override
  String get calendarRepeatCustom => 'Custom repeat rule';

  @override
  String get calendarRepeatServerNote =>
      'The server stores the end of the series, but webmail currently shows such series as endless.';

  @override
  String get calendarDone => 'Done';

  @override
  String get calendarReminderAtStart => 'At start';

  @override
  String calendarReminderMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes before',
      one: '1 minute before',
    );
    return '$_temp0';
  }

  @override
  String calendarReminderHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours before',
      one: '1 hour before',
    );
    return '$_temp0';
  }

  @override
  String calendarReminderDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days before',
      one: '1 day before',
    );
    return '$_temp0';
  }

  @override
  String get calendarReminderLocalNote =>
      'Participants also get the first reminder; the others fire on this device only.';

  @override
  String get calendarReminderChannel => 'Calendar reminders';

  @override
  String get calendarReminderChannelDescription =>
      'Notifications before events start';

  @override
  String calendarOrganizer(String name) {
    return 'Organizer: $name';
  }

  @override
  String get calendarYourAnswer => 'Your answer';

  @override
  String get calendarRsvpAccept => 'Yes';

  @override
  String get calendarRsvpTentative => 'Maybe';

  @override
  String get calendarRsvpDecline => 'No';

  @override
  String get calendarRsvpPending => 'No answer';

  @override
  String get calendarRsvpAccepted => 'Accepted';

  @override
  String get calendarRsvpTentativeStatus => 'Tentative';

  @override
  String get calendarRsvpDeclined => 'Declined';

  @override
  String calendarRsvpSummary(
    int accepted,
    int tentative,
    int declined,
    int pending,
  ) {
    return 'Yes: $accepted · Maybe: $tentative · No: $declined · No answer: $pending';
  }

  @override
  String get calendarMandatory => 'Mandatory event';

  @override
  String get calendarMandatoryCannotDecline =>
      'A mandatory event can\'t be declined.';

  @override
  String get calendarJoinCall => 'Join call';

  @override
  String get calendarJoinCallSoon =>
      'Joining a call from the calendar will come with the calls module.';

  @override
  String calendarEventTimeInZone(String time, String zone) {
    return '$time in $zone';
  }

  @override
  String get calendarDelete => 'Delete';

  @override
  String get calendarEdit => 'Edit';

  @override
  String get calendarSave => 'Save';

  @override
  String get calendarDeleteConfirm =>
      'Delete the event? Participants will be notified of the cancellation.';

  @override
  String get calendarScopeTitleEdit => 'Edit recurring event';

  @override
  String get calendarScopeTitleDelete => 'Delete recurring event';

  @override
  String get calendarScopeThis => 'This event';

  @override
  String get calendarScopeFollowing => 'This and following events';

  @override
  String get calendarScopeAll => 'All events';

  @override
  String get calendarRecreateWarning =>
      'This change can\'t be applied to the existing event: it will be cancelled and created again, and participants will get a new invitation.';

  @override
  String get calendarContinue => 'Continue';

  @override
  String get calendarEventNotFound => 'Event not found or not available.';

  @override
  String get calendarNotOrganizer =>
      'Only the organizer can change this event.';

  @override
  String get calendarCancelled => 'Cancelled';

  @override
  String calendarProblemsBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes not synced',
      one: '1 change not synced',
    );
    return '$_temp0';
  }

  @override
  String get calendarConflictTitle => 'The event was changed on another device';

  @override
  String get calendarConflictBody =>
      'Apply your changes over the newer version, or discard them?';

  @override
  String get calendarConflictOverwrite => 'Apply mine';

  @override
  String get calendarDiscard => 'Discard changes';

  @override
  String calendarProblemFailed(String reason) {
    return 'Change rejected: $reason';
  }

  @override
  String get calendarErrTitle =>
      'The title is empty or too long (300 bytes max).';

  @override
  String get calendarErrTime => 'Check the start and end time.';

  @override
  String get calendarErrLink => 'The meeting link must start with https://.';

  @override
  String get calendarErrTimezone => 'Unknown time zone.';

  @override
  String get calendarErrAudience =>
      'Some participants are not in your organization.';

  @override
  String get calendarErrRoom => 'The room is booked at that time.';

  @override
  String get calendarErrMeetingsDisabled =>
      'Meetings with participants are disabled in your organization.';

  @override
  String get calendarErrTooManyOccurrences =>
      'The series has too many occurrences: the server can\'t end a series, so \"this and following\" is unavailable. Delete the whole series or single events.';

  @override
  String get calendarErrOffline =>
      'Network needed: the series data has not been loaded yet.';

  @override
  String get calendarErrSending =>
      'The event is being sent — try again in a minute.';

  @override
  String get calendarErrScope =>
      'This change can\'t be applied to a single event of a series.';

  @override
  String get calendarErrOverride =>
      'The server did not return the moved event — refresh the calendar.';

  @override
  String get callsFilterAll => 'All';

  @override
  String get callsFilterMissed => 'Missed';

  @override
  String get callsEmpty => 'No calls yet';

  @override
  String get callsMissedEmpty => 'No missed calls';

  @override
  String get callsNew => 'New call';

  @override
  String get callsAudio => 'Audio call';

  @override
  String get callsVideo => 'Video call';

  @override
  String get callsDisabled =>
      'Calls are unavailable: the call service is not configured.';

  @override
  String get callsIncoming => 'Incoming call';

  @override
  String get callsIncomingVideo => 'Incoming video call';

  @override
  String get callsCalling => 'Calling…';

  @override
  String get callsConnecting => 'Connecting…';

  @override
  String get callsReconnecting => 'Reconnecting…';

  @override
  String get callsAccept => 'Accept';

  @override
  String get callsDecline => 'Decline';

  @override
  String get callsHangUp => 'End';

  @override
  String get callsEndForAll => 'End for everyone';

  @override
  String get callsLeave => 'Leave call';

  @override
  String get callsMic => 'Microphone';

  @override
  String get callsCamera => 'Camera';

  @override
  String get callsSwitchCamera => 'Switch camera';

  @override
  String get callsCameraUnavailable => 'Could not turn on the camera';

  @override
  String get callsSpeaker => 'Speaker';

  @override
  String get callsAudioOutput => 'Audio output';

  @override
  String get callsAudioSettings => 'Sound';

  @override
  String get callsAudioEarpiece => 'Phone earpiece';

  @override
  String get callsAudioWired => 'Wired headphones';

  @override
  String get callsAudioBluetooth => 'Bluetooth';

  @override
  String get callsScreenShare => 'Screen';

  @override
  String get callsScreenShareRefused => 'Screen sharing was not allowed.';

  @override
  String get callsScreenShareNotification => 'XatBox is sharing your screen';

  @override
  String get callsParticipants => 'Participants';

  @override
  String get callsModMute => 'Mute microphone';

  @override
  String get callsModRemove => 'Remove from call';

  @override
  String get callsMakeModerator => 'Make moderator';

  @override
  String get callsHost => 'host';

  @override
  String get callsModerator => 'moderator';

  @override
  String get callsYou => 'You';

  @override
  String get callsRedial => 'Call back';

  @override
  String get callsEndedHangup => 'Call ended';

  @override
  String get callsEndedDeclined => 'Call declined';

  @override
  String get callsEndedBusy => 'Busy';

  @override
  String get callsEndedMissed => 'No answer';

  @override
  String get callsEndedCancelled => 'Call cancelled';

  @override
  String get callsEndedFailed => 'Could not connect';

  @override
  String get callsEndedNetwork => 'No network — the call could not be made';

  @override
  String get callsEndedElsewhere => 'Answered on another device';

  @override
  String get callsEndedRemoved => 'A moderator removed you from the call';

  @override
  String get callsPermissionNeeded =>
      'A call needs microphone access (and the camera for video). Allow access to call.';

  @override
  String get callsQualityPoor => 'Poor connection';

  @override
  String get callsQualityLost => 'Connection lost';

  @override
  String get callsOutcomeMissed => 'Missed';

  @override
  String get callsOutcomeDeclined => 'Declined';

  @override
  String get callsOutcomeCancelled => 'Cancelled';

  @override
  String get callsOutcomeBusy => 'Busy';

  @override
  String get callsOutcomeFailed => 'Failed';

  @override
  String get callsOutgoing => 'Outgoing';

  @override
  String get callsIncomingShort => 'Incoming';

  @override
  String get callsActiveBanner => 'Call in progress — tap to return';

  @override
  String get callsIncomingChannel => 'Incoming calls';

  @override
  String get callsMissedChannel => 'Missed calls';

  @override
  String get callsSelectPeople =>
      'Pick one colleague, or several for a group call';

  @override
  String callsParticipantsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
    );
    return '$_temp0';
  }

  @override
  String get callsErrNotModerator => 'Only a moderator can do this.';

  @override
  String get callsErrAlreadyInCall => 'You are already in another call.';

  @override
  String get callsErrTooMany => 'Too many participants for a call.';

  @override
  String get callsErrInvalidParticipants =>
      'Some participants can\'t be called.';

  @override
  String get callsErrRateLimited =>
      'Too many calls in a row. Please wait a moment.';

  @override
  String get appOfflineBanner => 'No network connection';

  @override
  String appSizeBytes(String value) {
    return '$value B';
  }

  @override
  String appSizeKb(String value) {
    return '$value KB';
  }

  @override
  String appSizeMb(String value) {
    return '$value MB';
  }

  @override
  String appSizeGb(String value) {
    return '$value GB';
  }

  @override
  String get settingsAppearanceSection => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System default';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageRu => 'Русский';

  @override
  String get settingsLanguageKk => 'Қазақша';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get mailSortSender => 'Folder for sender';

  @override
  String mailSortSenderHint(String sender) {
    return 'Mail from $sender will be collected in the chosen folder.';
  }

  @override
  String get mailSortSenderIncludeExisting => 'Move mail already received';

  @override
  String mailSenderSorted(String name) {
    return 'Sender added to \"$name\"';
  }

  @override
  String get mailSortSenderNoFolders =>
      'Create a smart folder under Inbox first.';

  @override
  String get settingsSecurityChangePassword => 'Change password';

  @override
  String get settingsSecurityChangePasswordHint =>
      'At least 10 characters. Other sessions keep working after the change — end them below if needed.';

  @override
  String get settingsCurrentPassword => 'Current password';

  @override
  String get settingsNewPassword => 'New password (at least 10 characters)';

  @override
  String get settingsRepeatPassword => 'Repeat new password';

  @override
  String get settingsPasswordsMismatch => 'Passwords do not match';

  @override
  String get settingsPasswordChanged => 'Password changed';

  @override
  String get settingsPasswordTooShort => 'At least 10 characters';

  @override
  String get mailSettingsClients => 'Mail clients';

  @override
  String get mailSettingsClientsSubtitle =>
      'IMAP/SMTP for Outlook, Thunderbird and others';

  @override
  String get mailClientsHint =>
      'Connection settings for third-party mail apps.';

  @override
  String get mailClientsIncoming => 'Incoming · IMAP';

  @override
  String get mailClientsOutgoing => 'Outgoing · SMTP';

  @override
  String get mailClientsUsername => 'Username';

  @override
  String get mailClientsDisabled =>
      'IMAP/SMTP access is disabled by the administrator.';

  @override
  String get mailClientsEnabled => 'Enabled';

  @override
  String get mailClientsDisabledBadge => 'Disabled';

  @override
  String get profileChangePhoto => 'Change photo';

  @override
  String get profileRemovePhoto => 'Remove photo';

  @override
  String get profilePhotoUpdated => 'Photo updated';

  @override
  String get profilePhotoHint =>
      'Colleagues see the photo in mail, chat and the directory.';

  @override
  String get profileRole => 'Role';

  @override
  String get profileAdministrator => 'Administrator';

  @override
  String get profileMember => 'Member';

  @override
  String mailQuickReplyTo(String name) {
    return 'Reply to $name';
  }

  @override
  String mailQuickReplyAll(int count) {
    return 'Reply all · $count';
  }

  @override
  String get mailQuickReplyHint => 'Write a reply…';

  @override
  String get mailQuickReplySent => 'Reply sent';

  @override
  String get mailQuickReplyOpenComposer => 'Open in composer';

  @override
  String get mailQuickReplyAnother => 'Write another';

  @override
  String get mailQuickReplyViewSent => 'View in Sent';

  @override
  String get mailQuickReplySwitchAll => 'Everyone';

  @override
  String get mailQuickReplySwitchOne => 'Sender only';

  @override
  String get mailRemindMe => 'Remind me';

  @override
  String get mailRemindLaterToday => 'Later today';

  @override
  String get mailRemindTomorrow => 'Tomorrow morning';

  @override
  String get mailRemindNextWeek => 'Next week';

  @override
  String get mailReminderCreated => 'Reminder created';

  @override
  String get mailAddToTasks => 'Add to tasks';

  @override
  String get mailAddedToTasks => 'Task created';

  @override
  String get mailHideList => 'Hide list';

  @override
  String get mailShowList => 'Show list';

  @override
  String get mailMoveToInbox => 'Move to Inbox';

  @override
  String get mailExternalSender => 'External sender';

  @override
  String mailRecipientsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipients',
      one: '$count recipient',
    );
    return '$_temp0';
  }

  @override
  String get mailConversation => 'Conversation';

  @override
  String get mailConversationHistory => 'conversation history';

  @override
  String mailThreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '$count message',
    );
    return '$_temp0';
  }

  @override
  String get mailLookalikeWarning =>
      'The sender\'s domain looks like yours but is different. This may be a fake — check the address before replying.';

  @override
  String mailAttachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attachments',
      one: '$count attachment',
    );
    return '$_temp0';
  }

  @override
  String get mailOpenMessage => 'Open message';

  @override
  String get mailRoleStart => 'Start';

  @override
  String get mailRoleReply => 'Reply';

  @override
  String get mailRoleLatest => 'Latest';

  @override
  String get mailRoleCurrent => 'This message';

  @override
  String get mailEditSend => 'Edit & send';

  @override
  String get mailCopyAddress => 'Copy address';

  @override
  String get mailAddressCopied => 'Address copied';

  @override
  String get mailSaveToBookmarkFolder => 'Save to a bookmark folder';

  @override
  String get mailCreateBookmarkFolderFirst => 'Create a bookmark folder first';

  @override
  String mailSavedToFolder(String name) {
    return 'Saved to \"$name\"';
  }

  @override
  String get mailMoreActions => 'More';

  @override
  String get mailDownload => 'Download';

  @override
  String get mailPreview => 'Open';

  @override
  String get mailRefresh => 'Refresh mail';

  @override
  String get mailRefreshed => 'Mail refreshed';

  @override
  String get mailNewFolder => 'New folder';

  @override
  String get mailCreateFirstFolder => 'Create first folder';

  @override
  String get mailNewBookmarkFolder => 'New bookmark folder';

  @override
  String get mailCreateFirstBookmarkFolder => 'Create a bookmark folder';

  @override
  String get mailFolderName => 'Folder name';

  @override
  String get mailFolderNameHint => 'e.g. Accounting';

  @override
  String get mailFolderModalHint =>
      'A smart folder collects mail from the senders you choose.';

  @override
  String get mailBookmarkModalHint =>
      'A bookmark folder keeps the messages you saved.';

  @override
  String get mailFolderCreated => 'Folder created';

  @override
  String get mailBookmarkFolderCreated => 'Bookmark folder created';

  @override
  String get mailCreating => 'Creating…';

  @override
  String get sectionMail => 'Mail';

  @override
  String get sectionWorkspace => 'Workspace';

  @override
  String get mailSelectAll => 'Select all';

  @override
  String get mailSelectMessage => 'Select message';

  @override
  String mailSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '$count selected',
    );
    return '$_temp0';
  }

  @override
  String get mailUndo => 'Undo';

  @override
  String get mailThreadYou => 'You';

  @override
  String get mailReplyBadge => 'Reply';

  @override
  String mailMessagesTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '$count message',
    );
    return '$_temp0';
  }

  @override
  String mailSendersTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count senders',
      one: '$count sender',
    );
    return '$_temp0';
  }

  @override
  String get mailUnreadLabel => 'unread';

  @override
  String get mailBackToAccounts => 'Back to senders';

  @override
  String get mailSelectAccount => 'Select a sender';

  @override
  String get mailSelectAccountHint =>
      'The sender\'s messages will appear here.';

  @override
  String get mailExpandInbox => 'Expand inbox folders';

  @override
  String get mailCollapseInbox => 'Collapse inbox folders';

  @override
  String get mailCouldNotCreateFolder => 'Could not create the folder';

  @override
  String get mailDeleteSelected => 'Delete';

  @override
  String get mailBookmarkSelected => 'Bookmark';

  @override
  String get mailMarkReadSelected => 'Mark read';

  @override
  String get mailMarkUnreadSelected => 'Mark unread';

  @override
  String get mailSpamSelected => 'Spam';

  @override
  String get mailNotSpamSelected => 'Not spam';

  @override
  String mailDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages deleted',
      one: '$count message deleted',
    );
    return '$_temp0';
  }

  @override
  String mailMovedToSpamCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages moved to spam',
      one: '$count message moved to spam',
    );
    return '$_temp0';
  }

  @override
  String mailRestoredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages moved to Inbox',
      one: '$count message moved to Inbox',
    );
    return '$_temp0';
  }

  @override
  String mailMarkedReadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages marked read',
      one: '$count message marked read',
    );
    return '$_temp0';
  }

  @override
  String mailMarkedUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages marked unread',
      one: '$count message marked unread',
    );
    return '$_temp0';
  }

  @override
  String mailBookmarkedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages bookmarked',
      one: '$count message bookmarked',
    );
    return '$_temp0';
  }

  @override
  String get settingsStyle => 'Style';

  @override
  String get settingsStyleHint =>
      'Pick a look for the whole app. Text size and density apply on top of it.';

  @override
  String get settingsStyleApplied => 'Style applied';

  @override
  String get settingsTextSize => 'Text size';

  @override
  String get settingsTextSizeSmall => 'Small';

  @override
  String get settingsTextSizeMedium => 'Standard';

  @override
  String get settingsTextSizeLarge => 'Large';

  @override
  String get settingsListDensity => 'List density';

  @override
  String get settingsDensityCompact => 'Compact';

  @override
  String get settingsDensityNormal => 'Normal';

  @override
  String get settingsDensitySpacious => 'Spacious';

  @override
  String get settingsAppearanceHint =>
      'Set the text size and list density to whatever is comfortable for you. Saved on this device.';

  @override
  String get skinStandard => 'Standard';

  @override
  String get skinStandardHint => 'Calm classic, light or dark';

  @override
  String get skinSteppe => 'Steppe';

  @override
  String get skinSteppeHint => 'Warm sand and terracotta';

  @override
  String get skinPaper => 'Paper';

  @override
  String get skinPaperHint => 'Cream paper, ink and serif type';

  @override
  String get skinGraphite => 'Graphite';

  @override
  String get skinGraphiteHint => 'Dark, monospace, amber accent';

  @override
  String get skinKok => 'Kök';

  @override
  String get skinKokHint => 'Turquoise and gold, deep-teal menu';

  @override
  String get skinMidnight => 'Midnight';

  @override
  String get skinMidnightHint => 'Deep indigo, lilac accent';

  @override
  String get skinTerminal => 'Terminal';

  @override
  String get skinTerminalHint => 'Green phosphor, monospace throughout';

  @override
  String get skinLilac => 'Lilac';

  @override
  String get skinLilacHint => 'Lavender ground, plum, slab serif';

  @override
  String get skinContrast => 'High contrast';

  @override
  String get skinContrastHint => 'Black on white, 2px rules, for low vision';

  @override
  String get skinForest => 'Forest';

  @override
  String get skinForestHint => 'Pine dark, moss accent';

  @override
  String get settingsSecuritySection => 'Security';

  @override
  String get settingsLockPin => 'PIN lock';

  @override
  String get settingsLockPinHint => 'Ask for a PIN when the app opens';

  @override
  String get settingsLockChangePin => 'Change PIN';

  @override
  String get settingsLockBiometric => 'Unlock with biometrics';

  @override
  String get settingsLockTimeout => 'Lock';

  @override
  String get settingsLockOnClose => 'Ask for the PIN when the window is closed';

  @override
  String get settingsLockOnCloseHint =>
      'The X hides XatBox to the tray; the next time the window opens it asks for the PIN';

  @override
  String get settingsLockTimeoutImmediately =>
      'Immediately after leaving the app';

  @override
  String settingsLockTimeoutMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'After $minutes minutes',
      one: 'After $minutes minute',
    );
    return '$_temp0';
  }

  @override
  String get settingsHideContent => 'Hide content in the app switcher';

  @override
  String get settingsHideContentHint =>
      'On Android this also blocks screenshots';

  @override
  String settingsStorageUsed(String size) {
    return 'Used on this device: $size';
  }

  @override
  String get lockTitle => 'Enter your PIN';

  @override
  String lockWrong(int attempts) {
    String _temp0 = intl.Intl.pluralLogic(
      attempts,
      locale: localeName,
      other: 'Wrong PIN. $attempts attempts left',
      one: 'Wrong PIN. $attempts attempt left',
    );
    return '$_temp0';
  }

  @override
  String lockThrottled(int seconds) {
    return 'Too many attempts. Try again in $seconds s';
  }

  @override
  String get lockBiometric => 'Unlock with biometrics';

  @override
  String get lockBiometricReason => 'Unlock XatBox';

  @override
  String get lockForgot => 'Forgot PIN?';

  @override
  String get lockForgotConfirm =>
      'Sign out? Then sign in with your password and set a new PIN.';

  @override
  String get lockForgotSignOut => 'Sign out';

  @override
  String get lockDelete => 'Delete digit';

  @override
  String get lockSetupTitle => 'PIN';

  @override
  String get lockSetupEnter => 'Choose a 4–6 digit PIN';

  @override
  String get lockSetupRepeat => 'Repeat the PIN';

  @override
  String get lockSetupMismatch => 'The PINs do not match. Try again.';

  @override
  String get lockSetupNext => 'Next';

  @override
  String get loginShowPassword => 'Show password';

  @override
  String get loginHidePassword => 'Hide password';

  @override
  String get callsDetailsTitle => 'Call';

  @override
  String get callsDetailsType => 'Type';

  @override
  String get callsDetailsResult => 'Result';

  @override
  String get callsDetailsStarted => 'Started';

  @override
  String get callsDetailsDuration => 'Duration';

  @override
  String get callsDetailsNoConversation => 'No conversation';

  @override
  String get callsDetailsMessage => 'Message';

  @override
  String get callsModeDirect => 'Direct';

  @override
  String get callsModeGroup => 'Group';

  @override
  String get callsModeConference => 'Conference';

  @override
  String get callsOutcomeAnswered => 'Answered';

  @override
  String get callsRoleParticipant => 'participant';

  @override
  String get callsPStatusInvited => 'invited';

  @override
  String get callsPStatusRinging => 'ringing';

  @override
  String get callsPStatusAccepted => 'accepted';

  @override
  String get callsPStatusJoined => 'in the call';

  @override
  String get callsPStatusLeft => 'left';

  @override
  String get callsPStatusDeclined => 'declined';

  @override
  String get callsPStatusMissed => 'didn\'t answer';

  @override
  String get callsPStatusBusy => 'busy';

  @override
  String get callsPStatusRemoved => 'removed';

  @override
  String get callsErrNotFound => 'Call not found.';

  @override
  String get callsInvite => 'Add participants';

  @override
  String callsInviteSubmit(int count) {
    return 'Invite ($count)';
  }

  @override
  String get callsInviteSent => 'Invitations sent.';

  @override
  String get callsInviteNobody => 'Everyone found is already in the call';

  @override
  String get callsMinimize => 'Minimise';

  @override
  String get callsReturnToCall => 'Return to call';

  @override
  String get callsMore => 'More';

  @override
  String get callsRaiseHand => 'Raise hand';

  @override
  String get callsLowerHand => 'Lower hand';

  @override
  String get callsHandRaised => 'Hand raised';

  @override
  String get callsReactions => 'Reactions';

  @override
  String get callsChat => 'Chat';

  @override
  String get callsChatTitle => 'Call chat';

  @override
  String get callsChatHint => 'Message…';

  @override
  String get callsChatSend => 'Send';

  @override
  String get callsChatEmpty => 'Everyone in the call sees these messages';

  @override
  String get callsChatEmptyLinked =>
      'Everyone in the call sees these messages; they are saved to the chat';

  @override
  String get callsChatFailed => 'Not sent — tap to retry';

  @override
  String get callsChatEmoji => 'Emoji';

  @override
  String get callsChatClose => 'Close chat';

  @override
  String get callsRecord => 'Record';

  @override
  String get callsRecordStop => 'Stop recording';

  @override
  String get callsRecordConfirmTitle => 'Record this call?';

  @override
  String get callsRecordConfirmBody =>
      'Everyone in the call will see the recording indicator. Participants will find the recording in the call card.';

  @override
  String get callsRecordConfirmStart => 'Start recording';

  @override
  String get callsRecordingBanner => 'This call is being recorded';

  @override
  String callsRecordingBannerBy(String name) {
    return 'Recording started by $name';
  }

  @override
  String get callsRecordingStopped => 'Recording stopped';

  @override
  String get callsRecordings => 'Recordings';

  @override
  String get callsRecordingInProgress => 'Recording in progress';

  @override
  String get callsRecordingFailed => 'Recording failed';

  @override
  String get callsRecordingVideo => 'Video recording';

  @override
  String get callsRecordingAudio => 'Audio recording';

  @override
  String get callsRecordingDownload => 'Download';

  @override
  String get callsRecordingOpen => 'Open';

  @override
  String get callsRecordingNoApp => 'No app can open this file';

  @override
  String get callsRecordingDownloadFailed => 'Couldn\'t download the recording';

  @override
  String get callsErrRecordingUnavailable =>
      'Recording is unavailable right now. Try again later.';

  @override
  String get callsErrRecordingActive => 'The call is already being recorded';

  @override
  String get callsErrRecordingDisabled => 'Call recording is turned off';

  @override
  String get callsLayoutGrid => 'Grid';

  @override
  String get callsLayoutSpotlight => 'Speaker';

  @override
  String get callsDeclineWithMessage => 'Decline with a message';

  @override
  String get callsQuickReplyBusy => 'Can\'t talk now, I\'ll text you later.';

  @override
  String get callsQuickReplyLater => 'I\'ll call you back in a few minutes.';

  @override
  String get callsQuickReplyMeeting => 'I\'m in a meeting.';

  @override
  String get callsQuickReplySent => 'Message sent';

  @override
  String get callsMessage => 'Message';

  @override
  String get callsModMuteCamera => 'Turn off camera';

  @override
  String get callsModStopScreenShare => 'Stop screen sharing';

  @override
  String get callsMakeParticipant => 'Make participant';

  @override
  String get callsRingAgain => 'Ring again';

  @override
  String get callsRingAgainSent => 'Calling again';

  @override
  String get callsSectionInCall => 'In the call';

  @override
  String get callsSectionNotInCall => 'Not connected';

  @override
  String get callsClose => 'Close';

  @override
  String get callsTitleHint => 'Call title (optional)';

  @override
  String get meetingsSection => 'Meetings';

  @override
  String get meetingsToday => 'Today';

  @override
  String get meetingJoin => 'Join';

  @override
  String get meetingLive => 'Live';

  @override
  String get meetingOpenNow => 'Open to join';

  @override
  String meetingOpensAt(String time) {
    return 'Opens at $time';
  }

  @override
  String get meetingOpensSoonHint => 'You can join 10 minutes before the start';

  @override
  String get meetingPrejoinTitle => 'Video meeting';

  @override
  String get meetingDevices => 'Devices';

  @override
  String meetingDeviceMic(String name) {
    return 'Microphone: $name';
  }

  @override
  String meetingDeviceCamera(String name) {
    return 'Camera: $name';
  }

  @override
  String get meetingDeviceDefault => 'default';

  @override
  String get meetingDeviceOff => 'off';

  @override
  String get meetingCameraOff => 'Camera is off';

  @override
  String get meetingPreviewUnavailable => 'Camera preview is unavailable';

  @override
  String get meetingLobbyTitle => 'Waiting to be let in';

  @override
  String get meetingLobbyText =>
      'The organizer got your request and will let you in soon.';

  @override
  String get meetingLobbyDenied => 'The organizer did not let you in';

  @override
  String get meetingNotStarted => 'The meeting has not started yet';

  @override
  String get meetingEnded => 'The meeting has ended';

  @override
  String get meetingCancelled => 'The meeting was cancelled';

  @override
  String get meetingNotFound => 'Meeting not found';

  @override
  String get meetingGuestLinkTitle => 'This is a guest link';

  @override
  String get meetingGuestLinkText =>
      'Guest links open in a browser — they are for people without an account.';

  @override
  String get meetingOpenInBrowser => 'Open in browser';

  @override
  String get meetingPermissionDenied => 'No camera or microphone access';

  @override
  String get calendarXatBoxMeeting => 'Add a XatBox video meeting';

  @override
  String get calendarXatBoxMeetingHint => 'A join link is added to the event';

  @override
  String get calendarXatBoxMeetingAdded => 'XatBox video meeting added';

  @override
  String get calendarXatBoxMeetingAllDay => 'Not available for all-day events';

  @override
  String calendarXatBoxMeetingDescription(String url) {
    return 'XatBox video meeting: $url';
  }

  @override
  String get calendarXatBoxMeetingFailed =>
      'Could not create the video meeting';

  @override
  String get calendarMeetingReminderBody => 'In 5 minutes. Tap “Join”';

  @override
  String callsLobbyWaiting(int count) {
    return 'Waiting: $count';
  }

  @override
  String get callsLobbyAdmit => 'Admit';

  @override
  String get callsLobbyDeny => 'Deny';

  @override
  String get callsLobbyStaff => 'Colleague';

  @override
  String callsLobbyBanner(int count) {
    return 'Waiting to join: $count';
  }

  @override
  String get callsLobbyOpen => 'Open';

  @override
  String get callsGuest => 'Guest';

  @override
  String get callsGuestsSection => 'Guests';

  @override
  String get callsGuestInvite => 'Invite a guest';

  @override
  String get callsGuestLinkTitle => 'Guest link';

  @override
  String get callsGuestLinkHint =>
      'For people without a XatBox account: the link opens in a browser and you let the guest in.';

  @override
  String get callsGuestLinkExpires => 'Valid for';

  @override
  String get callsGuestLinkHour => '1 hour';

  @override
  String get callsGuestLinkDay => '1 day';

  @override
  String get callsGuestLinkWeek => '7 days';

  @override
  String get callsGuestLinkUses => 'People';

  @override
  String callsGuestLinkUsesValue(int count) {
    return 'up to $count people';
  }

  @override
  String get callsGuestLinkLobby => 'Admit manually';

  @override
  String get callsGuestLinkScreen => 'Allow screen sharing';

  @override
  String get callsGuestLinkCreate => 'Create link';

  @override
  String get callsGuestLinkCopy => 'Copy link';

  @override
  String get callsGuestLinkCopied => 'Link copied';

  @override
  String get callsQualitySettings => 'Quality';

  @override
  String get callsQualityAudio => 'Audio processing';

  @override
  String get callsQualityVideo => 'Video';

  @override
  String get callsNoiseSuppression => 'Noise suppression';

  @override
  String get callsEchoCancellation => 'Echo cancellation';

  @override
  String get callsAutoGain => 'Auto gain';

  @override
  String get callsMusicMode => 'Music mode';

  @override
  String get callsMusicModeHint => 'No voice filters, higher bitrate';

  @override
  String get callsDataSaver => 'Data usage';

  @override
  String get callsDataSaverOff => 'Normal';

  @override
  String get callsDataSaverLow => 'Saver';

  @override
  String get callsDataSaverAudio => 'Audio only';

  @override
  String get callsDataSaverHint =>
      '“Saver” receives low-quality video, “Audio only” neither receives nor sends video.';

  @override
  String get callsBackgroundBlur => 'Background blur';

  @override
  String get callsBackgroundBlurUnavailable =>
      'Not available in the mobile app yet';

  @override
  String get callsPoorNetworkTitle => 'Poor connection';

  @override
  String get callsPoorNetworkText =>
      'Turn on data saver so the audio does not break up?';

  @override
  String get callsPoorNetworkAccept => 'Save data';

  @override
  String get callsPoorNetworkDismiss => 'Not now';

  @override
  String get callsTranscript => 'Transcript';

  @override
  String get callsTranscriptPending => 'Transcript in progress';

  @override
  String get callsTranscriptFailed => 'Transcript failed';

  @override
  String get callsTranscriptRetry => 'Retry transcript';

  @override
  String get callsTranscriptSearch => 'Search the transcript';

  @override
  String callsTranscriptMatches(int count) {
    return 'Matches: $count';
  }

  @override
  String get callsTranscriptKeyPhrases => 'Key phrases';

  @override
  String get callsTranscriptAutomatic => 'automatic';

  @override
  String get callsTranscriptKeyPhrasesNote =>
      'Picked automatically by word frequency — this is not a summary of the conversation.';

  @override
  String get callsTranscriptCopy => 'Copy text';

  @override
  String get callsTranscriptCopied => 'Text copied';

  @override
  String get callsTranscriptEmpty =>
      'No speech was recognized in the recording';

  @override
  String get callsTranscriptNoSeek =>
      'Times are counted from the start of the recording.';

  @override
  String get callsErrNotOrganizer =>
      'Only the organizer can change the meeting';

  @override
  String get callsErrLobbyDecided => 'The request was already handled';

  @override
  String get callsErrGuests => 'Guest access is not available';

  @override
  String get callsErrTranscriptBusy =>
      'The transcription queue is busy — try later';

  @override
  String get callsGroupCall => 'Group call';

  @override
  String get callsSwapVideo => 'Swap views';

  @override
  String get callsVideoPaused => 'Video paused';

  @override
  String get chatAttachContact => 'Contact';

  @override
  String get chatContactPickTitle => 'Send a contact';

  @override
  String get chatContactWrite => 'Message';

  @override
  String get chatContactCall => 'Call';

  @override
  String get chatContactInvalid => 'This contact is not available.';

  @override
  String get chatVideoOpen => 'Open video';

  @override
  String get chatMediaLoadPreview => 'Load preview';

  @override
  String get chatAvatarChange => 'Change group photo';

  @override
  String get chatAvatarUpdated => 'Group photo updated';

  @override
  String get chatStorageSection => 'Chat data';

  @override
  String get chatAutoDownloadTitle => 'Media auto-download';

  @override
  String get chatAutoDownloadHint =>
      'Photo and video previews, voice messages. Original files download only when tapped.';

  @override
  String get chatAutoDownloadNever => 'Never';

  @override
  String get chatAutoDownloadWifi => 'Wi‑Fi only';

  @override
  String get chatAutoDownloadAlways => 'Always';

  @override
  String get chatMessagesKeptTitle => 'Messages kept per chat';

  @override
  String chatMediaSize(String size) {
    return 'Chat media: $size';
  }

  @override
  String get chatMediaClear => 'Clear media';

  @override
  String get chatMediaCleared => 'Chat media cleared';

  @override
  String get calendarBusyTitle => 'Availability';

  @override
  String get calendarBusyYou => 'You';

  @override
  String get calendarBusyFree => 'free';

  @override
  String get calendarBusyUnavailable => 'Couldn\'t load availability.';

  @override
  String get calendarFindTime => 'Find a time';

  @override
  String get calendarFindTimeHint =>
      'Organization working hours, 7 days from the chosen date.';

  @override
  String get calendarFindTimeEmpty => 'No free slots found.';

  @override
  String get calendarRoom => 'Room';

  @override
  String get calendarRoomNone => 'No room';

  @override
  String calendarRoomSeats(int count) {
    return 'Seats: $count';
  }

  @override
  String get calendarRoomsEmpty => 'No rooms available';

  @override
  String get calendarRoomBusy => 'Room bookings';

  @override
  String get calendarRoomBusyWarning =>
      'The room is booked at the chosen time.';

  @override
  String get contactsTab => 'Contacts';

  @override
  String get contactsTitle => 'Contacts';

  @override
  String get contactsSearchHint => 'Search by name or email';

  @override
  String get contactsLoadMore => 'Show more';

  @override
  String get contactsClearSearch => 'Clear search';

  @override
  String get contactsEmpty => 'The directory is empty';

  @override
  String get contactsNotFound => 'Nobody found';

  @override
  String get contactsChatDisabled =>
      'The staff directory works through the chat service, which is not configured in this build.';

  @override
  String get contactsCachedBanner =>
      'Couldn\'t refresh — showing the saved list';

  @override
  String contactsLimitHint(int count) {
    return 'Showing the first $count colleagues — refine the search';
  }

  @override
  String get contactsProfileTitle => 'Colleague';

  @override
  String get contactsProfileNotFound => 'Colleague not found in the directory';

  @override
  String get contactsWrite => 'Message';

  @override
  String get contactsAudioCall => 'Audio call';

  @override
  String get contactsVideoCall => 'Video call';

  @override
  String get contactsWriteEmail => 'Send email';

  @override
  String get contactsEmail => 'Email';

  @override
  String get contactsDepartment => 'Department';

  @override
  String get contactsPosition => 'Position';

  @override
  String get contactsFilterAll => 'All';

  @override
  String get contactsFilterOnline => 'Online';

  @override
  String get contactsFilterFavourites => 'Favourites';

  @override
  String get contactsFilterDepartment => 'Department';

  @override
  String get contactsDepartmentsTitle => 'Departments';

  @override
  String get contactsAllDepartments => 'All departments';

  @override
  String get contactsNoDepartment => 'No department';

  @override
  String get contactsDepartmentsEmpty => 'Departments are unavailable';

  @override
  String get contactsGroupByDepartment => 'Group by department';

  @override
  String get contactsGroupByName => 'Alphabetical';

  @override
  String get contactsFavourites => 'Favourites';

  @override
  String get contactsRecent => 'Recent';

  @override
  String get contactsAddFavourite => 'Add to favourites';

  @override
  String get contactsRemoveFavourite => 'Remove from favourites';

  @override
  String get contactsNotFoundHint =>
      'Check the spelling or pick another department';

  @override
  String get contactsNoOnline => 'Nobody is online right now';

  @override
  String get contactsNoFavourites => 'No favourite colleagues';

  @override
  String get contactsNoFavouritesHint =>
      'Open a profile and tap the star to pin a colleague here';

  @override
  String get contactsMailbox => 'Mailbox';

  @override
  String contactsCopied(String value) {
    return 'Copied: $value';
  }

  @override
  String get contactsCopy => 'Copy';

  @override
  String get contactsManager => 'Manager';

  @override
  String contactsEmployeeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count employees',
      one: '$count employee',
    );
    return '$_temp0';
  }

  @override
  String get contactsColleagues => 'Colleagues in the department';

  @override
  String get contactsSharedChats => 'Shared groups';

  @override
  String contactsChatMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
    );
    return '$_temp0';
  }

  @override
  String get contactsShare => 'Share contact';

  @override
  String get contactsShareToChat => 'Send to a chat';

  @override
  String get contactsCopyVCard => 'Copy contact card (vCard)';

  @override
  String get contactsVCardCopied => 'Contact card copied';

  @override
  String contactsShareSent(String chat) {
    return 'Contact sent to “$chat”';
  }

  @override
  String get contactsShareNoChats => 'No chats to send to';

  @override
  String get contactsActionAudio => 'Audio';

  @override
  String get contactsActionVideo => 'Video';

  @override
  String get contactsActionEmail => 'Email';

  @override
  String get contactsIndexHint => 'Jump to a letter';

  @override
  String get contactsSeenJustNow => 'last seen just now';

  @override
  String contactsSeenMinutes(int count) {
    return 'last seen $count min ago';
  }

  @override
  String contactsSeenHours(int count) {
    return 'last seen $count h ago';
  }

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsReadAll => 'Mark all read';

  @override
  String get notificationsEmpty => 'No notifications yet';

  @override
  String notificationsLimitNote(int count) {
    return 'Showing the latest $count notifications';
  }

  @override
  String get mailFormatToolbar => 'Formatting';

  @override
  String get mailFormatBold => 'Bold';

  @override
  String get mailFormatItalic => 'Italic';

  @override
  String get mailFormatUnderline => 'Underline';

  @override
  String get mailFormatBulletList => 'Bulleted list';

  @override
  String get mailFormatNumberedList => 'Numbered list';

  @override
  String get mailFormatQuote => 'Quote';

  @override
  String get mailFormatLink => 'Link';

  @override
  String get mailFormatTextColor => 'Text colour';

  @override
  String get mailFormatHighlight => 'Highlight colour';

  @override
  String get mailFormatColorNone => 'No colour';

  @override
  String get mailFormatTable => 'Table';

  @override
  String get mailFormatPreview => 'Preview';

  @override
  String get mailFormatEdit => 'Edit';

  @override
  String get mailFormatHelp =>
      '**bold**  _italic_  __underline__  - list  1. list  > quote  [text](https://…)';

  @override
  String get mailPreviewEmpty => 'The message is empty';

  @override
  String get mailLinkDialogTitle => 'Insert link';

  @override
  String get mailLinkUrl => 'Link address';

  @override
  String get mailLinkUrlHint => 'https://… or mailto:…';

  @override
  String get mailLinkText => 'Link text';

  @override
  String get mailLinkInvalid =>
      'Only https://, http:// and mailto: links are allowed';

  @override
  String get mailLinkInsert => 'Insert';

  @override
  String get mailSignaturePreviewTitle =>
      'The server will add this signature when sending:';

  @override
  String get mailSignaturePreviewNote =>
      'Preview only: organization rules for replies and external recipients may change it.';

  @override
  String get mailThreadsMode => 'Group into conversations';

  @override
  String get mailSettingsTitle => 'Mail settings';

  @override
  String get mailSettingsSignature => 'Signature';

  @override
  String get mailSettingsSignatureSubtitle => 'Personal signature in messages';

  @override
  String get mailSettingsVacation => 'Out-of-office reply';

  @override
  String get mailSettingsVacationSubtitle =>
      'Automatic reply while you are away';

  @override
  String get mailSettingsBlocked => 'Blocked senders';

  @override
  String get mailSettingsBlockedSubtitle => 'Their mail goes to Spam';

  @override
  String get mailSettingsBookmarkFolders => 'Bookmark folders';

  @override
  String get mailSettingsBookmarkFoldersSubtitle =>
      'Collections of bookmarked messages';

  @override
  String get mailSettingsSaved => 'Saved';

  @override
  String get mailSignatureLabel => 'Signature text';

  @override
  String get mailSignatureDefaultNote => 'The default signature is used now.';

  @override
  String get mailSignatureRestoreDefault => 'Restore the default signature';

  @override
  String get mailSignatureTooLong => 'The signature is longer than 2000 bytes.';

  @override
  String mailSignatureBytes(int used, int max) {
    return '$used / $max bytes';
  }

  @override
  String get mailSignatureNotApplied =>
      'Your organization does not add personal signatures right now.';

  @override
  String get mailVacationEnabled => 'Reply automatically';

  @override
  String get mailVacationSubject => 'Subject (optional)';

  @override
  String get mailVacationBody => 'Reply text';

  @override
  String get mailVacationStartsOn => 'Starts';

  @override
  String get mailVacationEndsOn => 'Ends';

  @override
  String get mailVacationNoDate => 'No date';

  @override
  String get mailVacationClearDate => 'Clear date';

  @override
  String get mailVacationTimeZone => 'Time zone';

  @override
  String get mailVacationActiveNow => 'The reply is being sent now';

  @override
  String get mailVacationPending => 'The reply starts on the start date';

  @override
  String get mailVacationInactive => 'The reply is not being sent';

  @override
  String get mailVacationNote =>
      'External senders get the reply, each at most once every 3 days.';

  @override
  String get mailVacationBodyRequired => 'Enter the reply text.';

  @override
  String get mailVacationSubjectTooLong =>
      'The subject is longer than 200 characters.';

  @override
  String get mailVacationBodyTooLong =>
      'The text is longer than 4000 characters.';

  @override
  String get mailVacationDatesInvalid =>
      'The end date can\'t be before the start date.';

  @override
  String get mailVacationTimeZoneInvalid => 'Unknown time zone.';

  @override
  String get mailSyncPending => 'Applying changes on the mail server…';

  @override
  String get mailSyncFailed =>
      'The mail server did not accept the changes. Save again.';

  @override
  String get mailBlockedEmpty => 'No blocked senders';

  @override
  String get mailBlockedAdd => 'Block';

  @override
  String get mailBlockedAddTitle => 'Block a sender';

  @override
  String get mailBlockedValue => 'Domain, address, IP or network';

  @override
  String get mailBlockedValueHint =>
      'example.com, 203.0.113.7, 198.51.100.0/24';

  @override
  String get mailBlockedNote => 'Note (optional)';

  @override
  String mailBlockedRemoveTitle(String pattern) {
    return 'Unblock $pattern?';
  }

  @override
  String get mailBlockedRemove => 'Unblock';

  @override
  String mailBlockedCount(int count, int limit) {
    return '$count of $limit';
  }

  @override
  String get mailBlockedKindDomain => 'Domain';

  @override
  String get mailBlockedKindIp => 'IP address';

  @override
  String get mailBlockedKindNetwork => 'Network';

  @override
  String get mailBookmarkFoldersEmpty => 'No bookmark folders yet';

  @override
  String get mailBookmarkFolderCreate => 'New folder';

  @override
  String get mailBookmarkFolderName => 'Folder name';

  @override
  String get mailBookmarkFolderNameInvalid =>
      'The name must be 1 to 80 characters.';

  @override
  String mailBookmarkFolderDeleteTitle(String name) {
    return 'Delete folder \"$name\"?';
  }

  @override
  String get mailBookmarkFolderDeleteBody =>
      'Messages stay in their folders and keep the bookmark.';

  @override
  String get mailErrFolderExists => 'A folder with this name already exists.';

  @override
  String get mailErrInvalidList => 'Senders can only be blocked.';

  @override
  String get mailErrEmptyPattern => 'Enter a domain, address, IP or network.';

  @override
  String get mailErrTopLevelDomain =>
      'A whole top-level domain can\'t be blocked.';

  @override
  String get mailErrNetworkTooWide => 'The network is too wide: /8 at most.';

  @override
  String get mailErrIpv6Network =>
      'IPv6 ranges are not supported; enter an exact address.';

  @override
  String get mailErrInvalidPattern =>
      'This is not a domain, address, IP or network.';

  @override
  String get mailErrNoteTooLong => 'The note is longer than 200 characters.';

  @override
  String get mailErrRuleLimit => 'The limit of 500 entries is reached.';

  @override
  String get mailErrRuleExists => 'This sender is already blocked.';

  @override
  String get mailErrRuleNotFound => 'The entry was already removed.';

  @override
  String get mailErrIcsNotFound => 'No invitation found in the message.';

  @override
  String get mailErrIcsTooLarge => 'The invitation file is too large.';

  @override
  String get mailErrInvalidIcs => 'The invitation could not be read.';

  @override
  String get mailErrInvalidRsvp => 'Invalid invitation response.';

  @override
  String get mailReportPhishing => 'Report phishing';

  @override
  String get mailReportPhishingTitle => 'Report phishing?';

  @override
  String get mailReportPhishingBody =>
      'The message will move to Spam and be sent for analysis. Don\'t follow its links or open its attachments.';

  @override
  String get mailReportPhishingConfirm => 'Report';

  @override
  String get mailReportedPhishing => 'Phishing reported';

  @override
  String get mailDeliveryStatus => 'Delivery status';

  @override
  String get mailDeliveryEmpty =>
      'No delivery data: the message was not sent through the platform.';

  @override
  String get mailDeliveryRecipients => 'Recipients';

  @override
  String get mailDeliveryHistory => 'History';

  @override
  String get mailDeliveryStateAccepted => 'Accepted';

  @override
  String get mailDeliveryStateProcessing => 'Processing';

  @override
  String get mailDeliveryStateDelivered => 'Delivered';

  @override
  String get mailDeliveryStatePartiallyDelivered => 'Partially delivered';

  @override
  String get mailDeliveryStateFailed => 'Failed';

  @override
  String get mailDeliveryStateQuarantined => 'Quarantined';

  @override
  String get mailDeliveryStatePending => 'Pending';

  @override
  String get mailDeliveryStateRelayed => 'Relayed';

  @override
  String get mailDeliveryStateDraft => 'Draft';

  @override
  String get mailDeliveryEventAccepted => 'Accepted for delivery';

  @override
  String get mailDeliveryEventScanned => 'Scanned';

  @override
  String get mailDeliveryEventDeliveredLocal => 'Delivered to mailbox';

  @override
  String get mailDeliveryEventRelayed => 'Relayed to external server';

  @override
  String get mailDeliveryEventFailed => 'Delivery failed';

  @override
  String get mailInviteTitle => 'Calendar invitation';

  @override
  String get mailInviteMethodRequest => 'Invitation';

  @override
  String get mailInviteMethodCancel => 'Event cancelled';

  @override
  String get mailInviteMethodReply => 'Attendee reply';

  @override
  String mailInviteOrganizer(String name) {
    return 'Organizer: $name';
  }

  @override
  String mailInviteYourStatus(String status) {
    return 'Your response: $status';
  }

  @override
  String get mailInviteStatusAccepted => 'accepted';

  @override
  String get mailInviteStatusTentative => 'maybe';

  @override
  String get mailInviteStatusDeclined => 'declined';

  @override
  String get mailInviteStatusPending => 'no response';

  @override
  String get mailInviteAccept => 'Accept';

  @override
  String get mailInviteMaybe => 'Maybe';

  @override
  String get mailInviteDecline => 'Decline';

  @override
  String get mailInviteCancelledNote => 'The organizer cancelled this event.';

  @override
  String get mailInviteApplyCancel => 'Apply the cancellation to the calendar';

  @override
  String mailInviteReplyFrom(String who, String status) {
    return '$who replied: $status';
  }

  @override
  String get mailInviteApplyReply => 'Update the response in the calendar';

  @override
  String get mailInviteOpenCalendar => 'Open in calendar';

  @override
  String get mailInviteSaved => 'Response saved to the calendar';

  @override
  String get mailInviteRecurring => 'Recurring event';

  @override
  String mailInviteInZone(String time, String zone) {
    return '$time ($zone)';
  }

  @override
  String get chatDraft => 'Draft';

  @override
  String get chatUnreadMessages => 'Unread messages';

  @override
  String get chatScrollToBottom => 'Scroll to bottom';

  @override
  String chatForwardedFrom(String name) {
    return 'Forwarded from $name';
  }

  @override
  String get chatSelect => 'Select';

  @override
  String chatDeleteSelected(int count) {
    return 'Delete $count messages?';
  }

  @override
  String get chatSearchInChat => 'Search in chat';

  @override
  String get chatSearchNoResults => 'Nothing found';

  @override
  String chatSearchPosition(int current, int total) {
    return '$current of $total';
  }

  @override
  String get chatMessageNotFound => 'Message is not available';

  @override
  String get chatAttachCamera => 'Camera';

  @override
  String get chatAttachGallery => 'Gallery';

  @override
  String get chatMoreReactions => 'More reactions';

  @override
  String get chatEmojiRecent => 'Recent';

  @override
  String get chatEmojiAll => 'All emoji';

  @override
  String get chatMessageInfo => 'Message info';

  @override
  String get chatReadBy => 'Read by';

  @override
  String get chatNoReceipts => 'Nobody has read it yet';

  @override
  String get chatFilterAll => 'All';

  @override
  String get chatFilterUnread => 'Unread';

  @override
  String get chatFilterGroups => 'Groups';

  @override
  String get chatEmptyFilter => 'Nothing here yet';

  @override
  String get chatArchivedEmpty => 'No archived chats';

  @override
  String get chatSelectConversation => 'Select a chat to start messaging';

  @override
  String get chatRemoveAdmin => 'Remove admin rights';

  @override
  String get chatOpenExternally => 'Open in another app';

  @override
  String get chatPlaybackSpeed => 'Playback speed';

  @override
  String get chatTypingShort => 'typing…';

  @override
  String get chatRecordingShort => 'recording a voice message…';

  @override
  String get chatEmptyHint => 'Send the first message';

  @override
  String get chatSaved => 'Saved Messages';

  @override
  String get chatSavedHint => 'Notes and files just for you';

  @override
  String get chatSaveToSaved => 'Save to Saved Messages';

  @override
  String get chatSavedDone => 'Saved to Saved Messages';

  @override
  String get chatDeleteForMe => 'Delete for me';

  @override
  String get chatDeleteForAll => 'Delete for everyone';

  @override
  String get chatMarkUnread => 'Mark as unread';

  @override
  String get chatMarkRead => 'Mark as read';

  @override
  String get chatUnreadShort => 'Unread';

  @override
  String get chatReadShort => 'Read';

  @override
  String get chatDescription => 'Description';

  @override
  String get chatDescriptionAdd => 'Add description';

  @override
  String get chatDescriptionEdit => 'Edit description';

  @override
  String get chatDescriptionTooLong => 'At most 500 characters';

  @override
  String chatSystemDescriptionChanged(String actor) {
    return '$actor changed the group description';
  }

  @override
  String get chatMediaFilesLinks => 'Media, files and links';

  @override
  String get chatMediaTabMedia => 'Media';

  @override
  String get chatMediaTabFiles => 'Files';

  @override
  String get chatMediaTabLinks => 'Links';

  @override
  String get chatMediaTabVoice => 'Voice';

  @override
  String get chatMediaEmpty => 'Nothing here yet';

  @override
  String get chatShowInChat => 'Show in chat';

  @override
  String get chatShareTitle => 'Send to chat';

  @override
  String get chatShareRecent => 'Recent chats';

  @override
  String get chatShareNothing => 'Nothing to send';

  @override
  String chatShareFiles(int count) {
    return 'Attachments: $count';
  }

  @override
  String get chatRemoveAttachment => 'Remove attachment';

  @override
  String get chatVideoPlay => 'Play';

  @override
  String get chatVideoPause => 'Pause';

  @override
  String get chatVideoMute => 'Mute';

  @override
  String get chatVideoUnmute => 'Unmute';

  @override
  String get chatVideoFailed => 'Could not play the video';

  @override
  String homeWidgetUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread',
      one: '$count unread',
    );
    return '$_temp0';
  }

  @override
  String get homeWidgetNoUnread => 'No unread chats';

  @override
  String get homeWidgetNoEvents => 'No more events today';

  @override
  String get homeWidgetSignIn => 'Sign in to XatBox';

  @override
  String get settingsWidgetSection => 'Widget and shortcuts';

  @override
  String get settingsWidgetPreview => 'Message text in the widget';

  @override
  String get settingsWidgetPreviewHint =>
      'Otherwise the widget shows chat names only. With a PIN lock or «Hide content» it shows just the unread count.';

  @override
  String get shortcutNewMessage => 'New message';

  @override
  String get shortcutCall => 'Call';

  @override
  String get shortcutSearch => 'Search';

  @override
  String get savedChatOpenFailed => 'Could not open Saved Messages';

  @override
  String get updateTitle => 'App update';

  @override
  String updateCurrentVersion(String version) {
    return 'Installed version $version';
  }

  @override
  String updateNewVersion(String version) {
    return 'Version $version';
  }

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String get updateMandatoryTitle => 'Please update XatBox';

  @override
  String get updateMandatoryBody =>
      'This version is no longer supported by the server. Updating takes a minute — your chats, mail and settings stay in place.';

  @override
  String get updateUpToDate => 'You\'re up to date';

  @override
  String updateCheckedAt(String time) {
    return 'Checked $time';
  }

  @override
  String get updateCheck => 'Check for updates';

  @override
  String get updateChecking => 'Checking for updates…';

  @override
  String get updateCheckFailed => 'Couldn\'t check for updates';

  @override
  String get updateWhatsNew => 'What\'s new';

  @override
  String get updateNoNotes => 'Bug fixes and stability improvements.';

  @override
  String get updateDownload => 'Download and install';

  @override
  String updateDownloading(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String updateDownloadedOf(String received, String total) {
    return '$received of $total';
  }

  @override
  String get updateCancel => 'Stop download';

  @override
  String get updateResume => 'Resume download';

  @override
  String get updateInstall => 'Install';

  @override
  String get updateInstalling => 'Android installer is open';

  @override
  String get updateInstallingHint =>
      'Confirm the installation. If the window closed, tap “Install” again.';

  @override
  String get updateLater => 'Later';

  @override
  String get updatePermissionTitle => 'Allow update installs';

  @override
  String get updatePermissionBody =>
      'Android asks once to let XatBox install apps. Open settings, turn on “Allow from this source” and come back — the installation continues on its own.';

  @override
  String get updatePermissionOpen => 'Open settings';

  @override
  String get updateFailed => 'Couldn\'t download the update';

  @override
  String get updateIntegrityFailed =>
      'The file was damaged while downloading. Please try again.';

  @override
  String get updateInstallFailed => 'Couldn\'t open the Android installer';

  @override
  String get updateRetry => 'Try again';

  @override
  String get updateIncompatible =>
      'There is no update file for this device. Please contact your administrator.';

  @override
  String get updateUnsupported =>
      'Updates come from the XatBox server and are available on Android only.';

  @override
  String get updateSignOut => 'Sign out';

  @override
  String updateSettingsAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String get updateBadgeNew => 'New';

  @override
  String get sessionsTitle => 'My devices and sessions';

  @override
  String get sessionsSettingsHint => 'Where your account is signed in';

  @override
  String get sessionsHint =>
      'These are all devices signed in to your account. If you don\'t recognise one, end its session and change your password.';

  @override
  String get sessionsThisDevice => 'This device';

  @override
  String get sessionsOthers => 'Other devices';

  @override
  String get sessionsNoOthers => 'No other active sessions';

  @override
  String get sessionsActiveNow => 'Active now';

  @override
  String sessionsLastActive(String time) {
    return 'Last active $time';
  }

  @override
  String sessionsSignedIn(String date) {
    return 'Signed in $date';
  }

  @override
  String sessionsIp(String ip) {
    return 'IP address $ip';
  }

  @override
  String get sessionsEnd => 'Sign out on this device';

  @override
  String get sessionsEndConfirmTitle => 'End session?';

  @override
  String sessionsEndConfirmBody(String device) {
    return '“$device” will have to sign in with the password again, and XatBox data on it is wiped the next time it connects.';
  }

  @override
  String get sessionsEndOthers => 'Sign out on all other devices';

  @override
  String get sessionsEndOthersConfirmBody =>
      'Every device except this one is signed out and wipes its local XatBox data.';

  @override
  String get sessionsEnded => 'Session ended';

  @override
  String get sessionsXatBoxApp => 'XatBox app';

  @override
  String get sessionsUnknownDevice => 'Unknown device';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutTagline => 'Mail, messenger and calls in one app';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version · build $build';
  }

  @override
  String get aboutAppSection => 'App';

  @override
  String get aboutServers => 'Servers';

  @override
  String get aboutServerMail => 'Mail';

  @override
  String get aboutServerChat => 'Messenger';

  @override
  String get aboutServerCalls => 'Calls';

  @override
  String get aboutServerNotConfigured => 'Not configured';

  @override
  String get aboutServerUnreachable => 'Unreachable';

  @override
  String get aboutServerDegraded => 'Having problems';

  @override
  String aboutServerLatency(int ms) {
    return '$ms ms';
  }

  @override
  String get aboutRecheck => 'Check again';

  @override
  String get aboutWhatsNew => 'What\'s new';

  @override
  String get aboutLicenses => 'Open-source licences';

  @override
  String get aboutPrivacy => 'Privacy';

  @override
  String get aboutPrivacyDataTitle => 'Where your data lives';

  @override
  String get aboutPrivacyDataBody =>
      'Mail, chats, files and call recordings are stored on your organisation\'s servers, not with third parties. The device keeps only an offline cache, wiped when you sign out.';

  @override
  String get aboutPrivacyPushTitle => 'Encrypted notifications';

  @override
  String get aboutPrivacyPushBody =>
      'Notification text is encrypted with a key created on this phone. Google and Apple only deliver the sealed packet and can\'t see who wrote what.';

  @override
  String get aboutPrivacyReportsTitle => 'Error reports';

  @override
  String get aboutPrivacyReportsBody =>
      'Crash reports go only to the XatBox server — without message texts, addresses or passwords. You can turn them off in settings.';

  @override
  String get aboutPrivacyLockTitle => 'App lock';

  @override
  String get aboutPrivacyLockBody =>
      'Your PIN is never stored as is: the device\'s secure storage keeps only a salted hash.';

  @override
  String get reportTitle => 'Report a problem';

  @override
  String get reportCategory => 'What happened?';

  @override
  String get reportCategoryBug => 'Bug';

  @override
  String get reportCategoryIdea => 'Idea';

  @override
  String get reportCategoryQuestion => 'Question';

  @override
  String get reportCategoryOther => 'Other';

  @override
  String get reportDescription => 'Description';

  @override
  String get reportDescriptionHint =>
      'What were you doing and what went wrong? The more detail, the faster we fix it.';

  @override
  String get reportScreenshot => 'Screenshot';

  @override
  String get reportScreenshotAttach => 'Attach an image';

  @override
  String get reportScreenshotRemove => 'Remove';

  @override
  String get reportDiagnostics => 'Attach diagnostics';

  @override
  String get reportDiagnosticsHint =>
      'Version, device model and a technical log without personal data';

  @override
  String get reportDiagnosticsShow => 'What will be sent';

  @override
  String get reportShake => 'Shake to report a problem';

  @override
  String get reportShakeHint =>
      'Shake the phone on any screen to open this form with a screenshot';

  @override
  String get reportSend => 'Send';

  @override
  String get reportSentTitle => 'Thank you!';

  @override
  String get reportSent =>
      'Your report has been sent. We\'ll look into it and get in touch if needed.';

  @override
  String get reportDone => 'Done';

  @override
  String get reportRateLimited =>
      'Too many reports in a row. Please try again in an hour.';

  @override
  String get reportUnavailable =>
      'Sending is unavailable: the messenger server is not configured.';

  @override
  String lockGreeting(String name) {
    return 'Hello, $name';
  }

  @override
  String get lockReturnToCall => 'Return to call';

  @override
  String get chatReport => 'Report';

  @override
  String get chatReportTitle => 'Report message';

  @override
  String get chatReportReasonSpam => 'Spam';

  @override
  String get chatReportReasonAbuse => 'Abuse';

  @override
  String get chatReportReasonConfidential => 'Confidential data';

  @override
  String get chatReportReasonOther => 'Other';

  @override
  String get chatReportComment => 'Comment (optional)';

  @override
  String get chatReportSend => 'Send report';

  @override
  String get chatReportSent => 'Report sent. Moderators will review it.';

  @override
  String get chatReportReviewed => 'Your report has been reviewed. Thank you!';

  @override
  String get chatReportPrivacyHint => 'The author will not know who reported.';

  @override
  String get chatForwardForbidden => 'Forwarding from this chat is disabled';

  @override
  String get chatMemberRestricted => 'You cannot write in this chat for now';

  @override
  String chatSystemProtectionChanged(String actor) {
    return '$actor changed the chat protection settings';
  }

  @override
  String get chatSystemModerationWarning =>
      'A moderator issued a warning for breaking the rules';

  @override
  String get chatSystemMemberRestricted => 'A member cannot write for a while';

  @override
  String get chatProtection => 'Chat protection';

  @override
  String get chatProtectionActive => 'Protection is on';

  @override
  String get chatProtectionNone => 'Protection is off';

  @override
  String get chatProtectionNoForward => 'Disable forwarding and copying';

  @override
  String get chatProtectionNoForwardHint =>
      'Messages cannot be forwarded, copied or saved';

  @override
  String get chatProtectionScreenshots => 'Screenshot protection';

  @override
  String get chatProtectionScreenshotsHint =>
      'Screenshots and screen recording are blocked on Android; on iPhone the chat is hidden in the app switcher';

  @override
  String get chatProtectionDisappearing => 'Disappearing messages';

  @override
  String get chatProtectionDisappearingHint =>
      'New messages are deleted for everyone after the timer';

  @override
  String get chatProtectionAdminsOnly =>
      'Only admins can change the protection';

  @override
  String get chatProtectionPeerNotified =>
      'The other person will see a notice about the change';

  @override
  String get chatProtectionMembersNotified =>
      'Members will see a notice about the change';

  @override
  String get chatDisappearingOff => 'Off';

  @override
  String get chatDisappearingDay => '1 day';

  @override
  String get chatDisappearingWeek => '1 week';

  @override
  String get chatDisappearingMonth => '1 month';

  @override
  String chatDisappearingCustom(int hours) {
    return '$hours h';
  }

  @override
  String get chatDisappearingMessage => 'Disappearing message';

  @override
  String get chatStickers => 'Emoji and stickers';

  @override
  String get chatEmoji => 'Emoji';

  @override
  String get chatStickersRecent => 'Recent';

  @override
  String get chatStickersEmpty => 'Stickers are not available yet';

  @override
  String get chatAttachmentSticker => 'Sticker';

  @override
  String get chatStickerUnavailable => 'Sticker unavailable';

  @override
  String get chatTranscribe => 'Transcribe';

  @override
  String get chatTranscribing => 'Transcribing…';

  @override
  String get chatTranscriptFailed => 'Could not transcribe';

  @override
  String get chatTranscriptRetry => 'Retry';

  @override
  String get chatTranscriptEmpty => 'No speech recognized';

  @override
  String get chatTranscriptShow => 'Show text';

  @override
  String get chatTranscriptHide => 'Text';

  @override
  String get chatTranscriptionBusy =>
      'The transcription queue is busy, try again later';

  @override
  String get chatAutoTranscribe => 'Transcribe voice messages automatically';

  @override
  String get chatAutoTranscribeHint =>
      'Transcription runs on the university server';

  @override
  String get moderationTitle => 'Moderation';

  @override
  String get moderationHint => 'Message reports';

  @override
  String get moderationTabOpen => 'Open';

  @override
  String get moderationTabResolved => 'Resolved';

  @override
  String get moderationTabDismissed => 'Dismissed';

  @override
  String get moderationEmpty => 'No reports';

  @override
  String get moderationEmptyHint => 'Reports from members will appear here';

  @override
  String get moderationGlobalScope => 'All chats of the organization';

  @override
  String get moderationGroupScope => 'Groups you administer';

  @override
  String get moderationReport => 'Report';

  @override
  String moderationReportFrom(String name) {
    return 'Reported by $name';
  }

  @override
  String moderationAuthor(String name) {
    return 'Author: $name';
  }

  @override
  String get moderationDirectChat => 'Direct chat';

  @override
  String get moderationMember => 'Member';

  @override
  String get moderationContext => 'Conversation context';

  @override
  String get moderationComment => 'Comment';

  @override
  String get moderationActions => 'Actions';

  @override
  String get moderationDeleteMessage => 'Delete message for everyone';

  @override
  String get moderationWarn => 'Warn the author';

  @override
  String get moderationRemove => 'Remove from the group';

  @override
  String get moderationMute => 'Mute in the group';

  @override
  String moderationMuteHours(int hours) {
    return 'For $hours h';
  }

  @override
  String get moderationDismiss => 'Dismiss the report';

  @override
  String get moderationNote => 'Note for the audit log (optional)';

  @override
  String get moderationConfirm => 'Apply';

  @override
  String get moderationDone => 'Done';

  @override
  String get moderationAlreadyHandled => 'The report is already handled';

  @override
  String moderationResolution(String action) {
    return 'Outcome: $action';
  }

  @override
  String moderationRestrictedUntil(String time) {
    return 'Cannot write until $time';
  }

  @override
  String get moderationNotMember => 'No longer a member';

  @override
  String get moderationDeletedContent => 'Message deleted';

  @override
  String get statusTitle => 'Status';

  @override
  String get statusSet => 'Set a status';

  @override
  String get statusNone => 'No status';

  @override
  String get statusPresetInClass => 'In class';

  @override
  String get statusPresetMeeting => 'In a meeting';

  @override
  String get statusPresetBusinessTrip => 'On a business trip';

  @override
  String get statusPresetVacation => 'On vacation';

  @override
  String get statusPresetSick => 'Out sick';

  @override
  String get statusPresetDnd => 'Do not disturb';

  @override
  String get statusPresetCustom => 'Custom';

  @override
  String get statusTextLabel => 'Status text';

  @override
  String get statusEmojiPick => 'Choose the status emoji';

  @override
  String get statusUntilLabel => 'Until';

  @override
  String get statusUntilNone => 'No end';

  @override
  String get statusUntilHour => '1 hour';

  @override
  String get statusUntilDay => 'End of day';

  @override
  String get statusUntilWeek => 'End of week';

  @override
  String get statusUntilPick => 'Pick date and time';

  @override
  String statusUntilShort(String time) {
    return 'until $time';
  }

  @override
  String get statusAutoReplyLabel => 'Auto-reply (optional)';

  @override
  String get statusAutoReplyHint =>
      'Sent in a direct chat to whoever writes to you, once a day per chat';

  @override
  String get statusDndHint =>
      'While this status is on, message push notifications are paused';

  @override
  String get statusClear => 'Clear status';

  @override
  String get statusSaved => 'Status set';

  @override
  String get statusCleared => 'Status cleared';

  @override
  String get statusInvalid =>
      'Check the status: text up to 70 characters, an end time in the future and within a year';

  @override
  String get statusCustomRequired => 'Enter text or choose an emoji';

  @override
  String chatAutoReplyText(String text) {
    return 'Auto-reply: $text';
  }

  @override
  String a11yStatus(String status) {
    return 'status: $status';
  }

  @override
  String get chatFoldersTitle => 'Chat folders';

  @override
  String get chatFoldersEdit => 'Edit folders';

  @override
  String get chatFoldersEmpty =>
      'Group work chats, groups or channels into a separate tab';

  @override
  String get chatFolderNew => 'New folder';

  @override
  String get chatFolderEditTitle => 'Edit folder';

  @override
  String get chatFolderName => 'Name';

  @override
  String get chatFolderEmoji => 'Choose the folder icon';

  @override
  String get chatFolderTypes => 'All chats of a type';

  @override
  String get chatFolderTypeDirect => 'Direct';

  @override
  String get chatFolderUnreadOnly => 'Unread only';

  @override
  String get chatFolderExcludeMuted => 'Hide muted chats';

  @override
  String get chatFolderChats => 'Chats in the folder';

  @override
  String chatFolderChatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats',
      one: '$count chat',
    );
    return '$_temp0';
  }

  @override
  String get chatFolderSearchChats => 'Search chats';

  @override
  String get chatFolderErrorName => 'Enter a name (up to 32 characters)';

  @override
  String get chatFolderErrorEmpty => 'Add chats or choose a chat type';

  @override
  String get chatFolderErrorChats => 'A folder can hold up to 200 chats';

  @override
  String get chatFolderLimit => 'You can create up to 10 folders';

  @override
  String get chatFolderDelete => 'Delete folder';

  @override
  String chatFolderDeleteConfirm(String name) {
    return 'Delete the folder “$name”? The chats stay in the list.';
  }

  @override
  String get chatFolderReorder => 'Drag to reorder';

  @override
  String chatFolderUnreadChats(int count) {
    return 'chats with unread messages: $count';
  }

  @override
  String get chatFoldersPending =>
      'Changes will be saved when you are back online';

  @override
  String get chatFoldersSaveFailed => 'Could not save the folders';

  @override
  String get chatAddToFolder => 'Add to folder';

  @override
  String get chatVoiceModeTitle => 'Recording voice messages';

  @override
  String get chatVoiceModeHold => 'Hold';

  @override
  String get chatVoiceModeTap => 'Tap to record';

  @override
  String get chatVoiceModeHint =>
      'With TalkBack on, recording always starts with a tap';

  @override
  String get chatVoiceTapToRecord => 'Record a voice message';

  @override
  String get channelComments => 'Comments';

  @override
  String get channelCommentsHint => 'Subscribers can discuss posts';

  @override
  String commentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '$count comment',
    );
    return '$_temp0';
  }

  @override
  String get commentsLeave => 'Comment';

  @override
  String get commentsEmpty => 'No comments yet — be the first';

  @override
  String get commentsDisabled => 'Comments are turned off';

  @override
  String get commentsInvalidThread =>
      'You can only reply to the post or its comments';

  @override
  String get commentsPostUnavailable =>
      'The post was deleted or is unavailable';

  @override
  String get scheduleWhenOnline => 'When they are online';

  @override
  String get scheduleWhenOnlineHint => 'Waits up to 7 days';

  @override
  String get scheduledWhenOnline => 'When online';

  @override
  String get scheduledWhenOnlineCreated =>
      'It will be sent when they come online';

  @override
  String get scheduledWhenOnlineTimeout => 'Not sent: they did not come online';

  @override
  String get scheduleWhenOnlineUnavailable => 'They hide when they are online';

  @override
  String get officialTitle => 'Official messages';

  @override
  String get officialEmpty => 'No official messages yet';

  @override
  String get officialNoAccess => 'You have no access to official messages';

  @override
  String get officialNotFound => 'Message not found';

  @override
  String get officialUnread => 'Unread';

  @override
  String get officialRequiresAck => 'Acknowledgement required';

  @override
  String get officialAcknowledged => 'Acknowledged';

  @override
  String get officialAcknowledgeButton => 'I have read it';

  @override
  String officialAcknowledgedAt(String date) {
    return 'You acknowledged it: $date';
  }

  @override
  String get officialAckHint =>
      'The sender asks you to confirm that you have read this message.';

  @override
  String officialLimitNote(int count) {
    return 'Showing the latest $count messages';
  }

  @override
  String get officialNew => 'New message';

  @override
  String get officialReceivedTab => 'Received';

  @override
  String get officialSentTab => 'Sent';

  @override
  String get officialSentEmpty =>
      'Messages sent from this device will appear here';

  @override
  String officialRecipientCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipients',
      one: '$count recipient',
    );
    return '$_temp0';
  }

  @override
  String officialSentToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sent to $count recipients',
      one: 'Sent to $count recipient',
    );
    return '$_temp0';
  }

  @override
  String get officialComposeTitle => 'Official message';

  @override
  String get officialFieldTitle => 'Title';

  @override
  String get officialFieldBody => 'Message text';

  @override
  String get officialTitleRequired => 'Enter a title';

  @override
  String get officialBodyRequired => 'Enter the message text';

  @override
  String get officialRequireAck => 'Require acknowledgement';

  @override
  String get officialRequireAckHint =>
      'Every recipient will have to confirm they have read it';

  @override
  String get officialRecipients => 'Recipients';

  @override
  String get officialRecipientsOrganization => 'Whole organization';

  @override
  String get officialRecipientsDepartments => 'Departments';

  @override
  String get officialRecipientsUsers => 'Employees';

  @override
  String get officialRecipientsRequired => 'Choose recipients';

  @override
  String get officialSearchUsers => 'Search employees';

  @override
  String get officialNoUsers => 'Nobody found';

  @override
  String get officialNoDepartments => 'No departments available';

  @override
  String officialSelectedDone(int count) {
    return 'Done ($count)';
  }

  @override
  String get officialSend => 'Send';

  @override
  String get officialStatsTitle => 'Statistics';

  @override
  String get officialStatsRecipients => 'Recipients';

  @override
  String get officialStatsRead => 'Read';

  @override
  String get officialStatsAcknowledged => 'Acknowledged';

  @override
  String get officialStatsNoData =>
      'No data. Statistics are available only to the sender.';

  @override
  String get officialStatsAggregateNote =>
      'The server reports totals only, without a list of recipients.';

  @override
  String get officialErrNotFound =>
      'Message not found or does not require acknowledgement';

  @override
  String get officialErrInvalid => 'Fill in the title and the message text';

  @override
  String get officialErrInvalidRecipients => 'Could not resolve the recipients';

  @override
  String get officialErrNoRecipients =>
      'None of the selected recipients is an active user';

  @override
  String get officialErrForbidden =>
      'You are not allowed to send official messages to these recipients';

  @override
  String get officialErrNotSent =>
      'The server did not accept the message. Please try again.';

  @override
  String mailUxUnbookmarkedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages removed from bookmarks',
      one: '$count message removed from bookmarks',
    );
    return '$_temp0';
  }

  @override
  String mailUxArchivedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages archived',
      one: '$count message archived',
    );
    return '$_temp0';
  }

  @override
  String get mailUxSwipeSection => 'List gestures';

  @override
  String get mailUxSwipeLeft => 'Swipe left';

  @override
  String get mailUxSwipeRight => 'Swipe right';

  @override
  String get mailUxSwipeNone => 'Nothing';

  @override
  String get mailUxSwipeTrash => 'Move to trash';

  @override
  String get mailUxSwipeArchive => 'Archive';

  @override
  String get mailUxSwipeRead => 'Read / unread';

  @override
  String get mailUxSwipeBookmark => 'Bookmark';

  @override
  String get mailUxSwipeHint =>
      'In Trash and Drafts, the trash swipe deletes forever after confirmation. Swipes are off while several messages are selected.';

  @override
  String get mailUxSendSection => 'Sending';

  @override
  String get mailUxUndoSend => 'Undo send';

  @override
  String get mailUxUndoSendOff => 'Off';

  @override
  String mailUxUndoSendSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get mailUxUndoSendHint =>
      'the message leaves after a pause and can be undone meanwhile';

  @override
  String get mailUxSending => 'Sending message…';

  @override
  String mailUxSendFailed(String error) {
    return 'Message not sent: $error';
  }

  @override
  String get mailUxEdit => 'Edit';

  @override
  String get mailUxAttachFile => 'File';

  @override
  String get mailUxAttachGallery => 'Photo or video from gallery';

  @override
  String get mailUxAttachCameraPhoto => 'Take a photo';

  @override
  String get mailUxAttachCameraVideo => 'Record a video';

  @override
  String get mailUxRecentRecipient => 'Recently used';

  @override
  String get mailUxForwardToChat => 'Forward to chat';

  @override
  String get mailUxForwardToChatAttachments =>
      'Which attachments to send to the chat?';

  @override
  String get mailUxNext => 'Next';

  @override
  String get mailUxDownloading => 'Downloading attachments…';

  @override
  String get mailUxChatDate => 'Date';

  @override
  String get mailUxChatSubject => 'Subject';

  @override
  String get mailUxChatFrom => 'From';

  @override
  String get mailUxSendByMail => 'Send by email';

  @override
  String get tasksTitle => 'Tasks';

  @override
  String get tasksScreenTitle => 'My tasks';

  @override
  String get tasksSectionMine => 'Assigned to me';

  @override
  String get tasksSectionAssigned => 'Assigned by me';

  @override
  String tasksSectionDone(int count) {
    return 'Completed · $count';
  }

  @override
  String get tasksEmpty => 'No tasks';

  @override
  String get tasksEmptyHint => 'Create a task or add an email to tasks';

  @override
  String get tasksUnavailable => 'Tasks are not available for your account';

  @override
  String get tasksNew => 'New task';

  @override
  String get tasksEdit => 'Edit task';

  @override
  String get tasksDetails => 'Task';

  @override
  String get tasksFieldTitle => 'Title';

  @override
  String get tasksFieldDescription => 'Description';

  @override
  String get tasksFieldDue => 'Due';

  @override
  String get tasksFieldReminder => 'Reminder';

  @override
  String get tasksFieldAssignee => 'Assignee';

  @override
  String get tasksFieldPriority => 'Priority';

  @override
  String get tasksNoDue => 'No due date';

  @override
  String get tasksNoReminder => 'No reminder';

  @override
  String get tasksAssigneeSelf => 'Me';

  @override
  String get tasksAssigneePick => 'Assign to';

  @override
  String get tasksAssigneeSearch => 'Search colleagues';

  @override
  String get tasksAssigneeEmpty => 'No colleagues in your departments';

  @override
  String get tasksPriorityLow => 'Low';

  @override
  String get tasksPriorityNormal => 'Normal';

  @override
  String get tasksPriorityHigh => 'High';

  @override
  String get tasksPriorityUrgent => 'Urgent';

  @override
  String get tasksOverdue => 'Overdue';

  @override
  String get tasksDueToday => 'Today';

  @override
  String tasksDueOn(String date) {
    return 'due $date';
  }

  @override
  String tasksAssignedTo(String name) {
    return 'Assignee: $name';
  }

  @override
  String tasksAssignedBy(String name) {
    return 'Assigned by: $name';
  }

  @override
  String get tasksAssignedToColleague => 'Assigned to a colleague';

  @override
  String get tasksReminderFixed =>
      'The reminder can only be set when the task is created';

  @override
  String get tasksReadOnly => 'Only the assignee can edit or delete this task';

  @override
  String get tasksTitleRequired => 'Enter a title';

  @override
  String get tasksClear => 'Clear';

  @override
  String get tasksCreate => 'Create';

  @override
  String get tasksDelete => 'Delete task';

  @override
  String tasksDeleteConfirm(String title) {
    return 'Delete the task “$title”? Its reminders are removed too.';
  }

  @override
  String get tasksDeleted => 'Task deleted';

  @override
  String get tasksCreated => 'Task created';

  @override
  String get tasksSaved => 'Task saved';

  @override
  String get tasksMarkDone => 'Mark as done';

  @override
  String get tasksMarkUndone => 'Mark as not done';

  @override
  String get tasksOpenMessage => 'Open email';

  @override
  String get tasksOpen => 'Open';

  @override
  String get tasksNotFound => 'Task not found';

  @override
  String get tasksErrInvalid => 'Check the task fields';

  @override
  String get tasksErrOwner => 'The colleague is not in your organization';

  @override
  String get tasksErrReminder => 'Could not save the reminder';

  @override
  String get tasksErrForbidden => 'You cannot assign a task to this colleague';

  @override
  String get taskBoardsTitle => 'Boards';

  @override
  String get taskBoardPersonal => 'My tasks';

  @override
  String get taskBoardNew => 'New board';

  @override
  String get taskBoardCreate => 'Create board';

  @override
  String get taskBoardRename => 'Rename board';

  @override
  String get taskBoardName => 'Board name';

  @override
  String get taskBoardNameHint => 'For example: Admissions campaign';

  @override
  String get taskBoardDescription => 'Description';

  @override
  String get taskBoardColor => 'Colour';

  @override
  String get taskBoardShare => 'Share';

  @override
  String get taskBoardDelete => 'Delete board';

  @override
  String taskBoardDeleteConfirm(String name) {
    return 'Delete the board «$name»? Its tasks go back to My tasks and colleagues lose access to them.';
  }

  @override
  String get taskBoardDeleted => 'Board deleted';

  @override
  String get taskBoardCreated => 'Board created';

  @override
  String get taskBoardSaved => 'Board saved';

  @override
  String get taskBoardShared => 'Access updated';

  @override
  String get taskBoardNameRequired => 'Enter a board name';

  @override
  String taskBoardOwnedBy(String name) {
    return '$name\'s board';
  }

  @override
  String get taskBoardRoleEditor => 'Can edit';

  @override
  String get taskBoardRoleViewer => 'View only';

  @override
  String get taskBoardReadOnly => 'This board is read-only for you';

  @override
  String taskBoardShareTitle(String name) {
    return 'Access to «$name»';
  }

  @override
  String get taskBoardShareHint =>
      'Members see the board\'s tasks. Editors can create and change them, viewers only read.';

  @override
  String get taskBoardShareSearch => 'Search colleagues';

  @override
  String get taskBoardShareEmpty => 'Nobody else has access yet';

  @override
  String taskBoardShareMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
      zero: 'No members',
    );
    return '$_temp0';
  }

  @override
  String get taskBoardRemoveMember => 'Remove access';

  @override
  String get taskBoardEmpty => 'No tasks on this board yet';

  @override
  String get taskBoardMoveHere => 'Move here';

  @override
  String taskBoardMoved(String name) {
    return 'Task moved to $name';
  }

  @override
  String taskBoardOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '$count task',
      zero: 'No tasks',
    );
    return '$_temp0';
  }

  @override
  String get taskBoardErrNotFound => 'Board not found';

  @override
  String get taskBoardErrForbidden => 'You cannot change this board';

  @override
  String get taskBoardErrName => 'The board name must be 1 to 120 characters';

  @override
  String get taskBoardErrMember => 'That colleague is not in your organization';

  @override
  String get taskBoardsRailHide => 'Hide the boards list';

  @override
  String get taskBoardsRailShow => 'Show the boards list';

  @override
  String get translateAction => 'Translate';

  @override
  String get translateMail => 'Translate message';

  @override
  String get translateInProgress => 'Translating…';

  @override
  String get translateFailed => 'Could not translate';

  @override
  String get translateRetry => 'Retry';

  @override
  String get translateShowOriginal => 'Show original';

  @override
  String translateLabel(String from, String to) {
    return 'Translation: $from → $to';
  }

  @override
  String translateSameLanguage(String language) {
    return 'Already in $language';
  }

  @override
  String get translateLangRu => 'Russian';

  @override
  String get translateLangKk => 'Kazakh';

  @override
  String get translateLangEn => 'English';

  @override
  String translateAutoInChat(String language) {
    return 'Translate automatically into $language';
  }

  @override
  String get translateAutoInChatHint =>
      'Incoming messages in other languages, on this device';

  @override
  String get translateTargetSetting => 'Translation language';

  @override
  String translateTargetAppLanguage(String language) {
    return 'Same as the app ($language)';
  }

  @override
  String get translateUnavailable =>
      'Translation is unavailable right now. Try again later.';

  @override
  String get translateTooLong => 'The text is too long to translate';

  @override
  String get translateRateLimited => 'Too many translations. Try again later.';

  @override
  String translateMailProgress(int done, int total) {
    return 'Translating: $done of $total';
  }

  @override
  String get searchEverywhere => 'Search everywhere';

  @override
  String get searchHint => 'People, chats, mail, events';

  @override
  String get searchIntro => 'Search people, chats, mail and calendar at once';

  @override
  String get searchRecent => 'Recent';

  @override
  String get searchRecentClear => 'Clear';

  @override
  String get searchRecentRemove => 'Remove from history';

  @override
  String get searchSectionPeople => 'People';

  @override
  String get searchSectionChats => 'Chats';

  @override
  String get searchSectionMail => 'Mail';

  @override
  String get searchSectionEvents => 'Events';

  @override
  String get searchShowAll => 'Show all';

  @override
  String get searchSectionError => 'Search failed';

  @override
  String get searchEmpty => 'Nothing found';

  @override
  String get searchNothingAvailable =>
      'Search is not available for your account';

  @override
  String get searchOfflineHint => 'Offline — saved data only';

  @override
  String get searchNoSubject => '(no subject)';

  @override
  String get todayTab => 'Today';

  @override
  String get todayStartScreen => 'Start screen';

  @override
  String get todayStartScreenHint =>
      'The tab opened on launch. «Today» adds a tab with a summary of the day.';

  @override
  String get todayGreetingMorning => 'Good morning';

  @override
  String get todayGreetingAfternoon => 'Good afternoon';

  @override
  String get todayGreetingEvening => 'Good evening';

  @override
  String get todayGreetingNight => 'Good night';

  @override
  String get todayMailTitle => 'Unread mail';

  @override
  String get todayMailEmpty => 'All mail read';

  @override
  String get todayChatsTitle => 'Unread chats';

  @override
  String get todayChatsEmpty => 'No new messages';

  @override
  String get todayEventsTitle => 'Today in calendar';

  @override
  String get todayEventsEmpty => 'No more events today';

  @override
  String get todayJoin => 'Join';

  @override
  String get todayMissedCallsTitle => 'Missed calls';

  @override
  String get todayMissedCallsEmpty => 'No missed calls today';

  @override
  String get todayNewMail => 'Mail';

  @override
  String get todayNewChat => 'Message';

  @override
  String get todayNewCall => 'Call';

  @override
  String get callsShareChoose => 'Choose what to share';

  @override
  String get callsShareEntireScreen => 'Entire screen';

  @override
  String get callsShareWindow => 'Window';

  @override
  String get callsShareStart => 'Share';

  @override
  String get desktopTrayOpen => 'Open XatBox';

  @override
  String get desktopTrayQuit => 'Quit XatBox';

  @override
  String get desktopSearch => 'Search';

  @override
  String get desktopMore => 'More';

  @override
  String get contactsSelect => 'Select a colleague to open their profile';

  @override
  String get callsSelect => 'Select a call to see its details';

  @override
  String get desktopRefresh => 'Refresh';

  @override
  String get desktopPrevious => 'Previous';

  @override
  String get desktopNext => 'Next';

  @override
  String get aboutPrivacyPushBodyDesktop =>
      'On the computer, notifications come straight from your organisation\'s server over a secure connection, without Google or Apple.';

  @override
  String get remindersEmptyHintDesktop =>
      'Right-click a message and choose «Remind me»';

  @override
  String get chatProtectionScreenshotsHintDesktop =>
      'On the computer the chat is hidden while the window is minimized';

  @override
  String get settingsLockWindowsHello => 'Unlock with Windows Hello';

  @override
  String get composeMinimize => 'Minimize';

  @override
  String get composeExpand => 'Expand';

  @override
  String get composeRestoreSize => 'Restore size';

  @override
  String get composeSaveAndClose => 'Save and close';

  @override
  String get composeAddCcBcc => 'Add Cc / Bcc';

  @override
  String get desktopCollapseSidebar => 'Collapse sidebar';

  @override
  String get desktopExpandSidebar => 'Expand sidebar';

  @override
  String get desktopZoom => 'Zoom';

  @override
  String get desktopZoomHint =>
      'Size of the whole interface. Shortcuts: Ctrl + plus, Ctrl + minus, Ctrl + 0.';

  @override
  String get desktopZoomReset => 'Reset';

  @override
  String get desktopNotifTest => 'Test notifications';

  @override
  String get desktopNotifTestHint => 'Show a sample system notification';

  @override
  String get desktopNotifTestBody => 'Notifications work';

  @override
  String get desktopNotifTestSent =>
      'Notification sent. If you do not see it, allow notifications for XatBox in the system settings and turn off Do not disturb.';

  @override
  String desktopNotifTestFailed(String error) {
    return 'The system did not show the notification: $error';
  }

  @override
  String get desktopSettingsIntro =>
      'Profile, appearance, notifications and security. Changes are saved right away.';

  @override
  String get updateInstallFailedDesktop =>
      'Could not start the update installer';

  @override
  String desktopCalendarMore(int count) {
    return '+$count more';
  }

  @override
  String get desktopCalendarSelectedDay => 'Selected day';

  @override
  String composeDraftSavedAt(String time) {
    return 'Draft saved $time';
  }

  @override
  String get desktopShortcutsTitle => 'Keyboard shortcuts';

  @override
  String get desktopShortcutsMail => 'Messages';

  @override
  String get desktopShortcutsEverywhere => 'Everywhere';

  @override
  String get desktopShortcutNext => 'Next message';

  @override
  String get desktopShortcutPrevious => 'Previous message';

  @override
  String get desktopShortcutOpen => 'Open message';

  @override
  String get desktopShortcutClose => 'Close message';

  @override
  String get desktopShortcutReadToggle => 'Mark read / unread';

  @override
  String get desktopShortcutSend => 'Send message';

  @override
  String get desktopShortcutModules =>
      'Mail · Chat · Calls · Calendar · Contacts';

  @override
  String get desktopShortcutZoom => 'Zoom: in · out · reset';

  @override
  String get desktopPrint => 'Print';

  @override
  String get desktopPrintFailed => 'Could not open the message for printing';

  @override
  String get desktopOpenInWindow => 'Open in a separate window';

  @override
  String get desktopDefaultMailApp => 'Default email app';

  @override
  String get desktopDefaultMailAppHint =>
      'Email links (mailto:) in the browser and documents will open a new message in XatBox. Windows settings open: choose XatBox for MAILTO.';

  @override
  String get desktopAppSection => 'Desktop app';

  @override
  String get updateRestartNow => 'Restart and update';

  @override
  String get updateOnQuit => 'Update when I quit';

  @override
  String get updateOnQuitScheduled =>
      'The update installs when you quit XatBox: tray icon → “Quit XatBox”.';

  @override
  String get updateManagedByAdmin =>
      'XatBox is installed for all users of this computer. New versions are installed by your administrator.';

  @override
  String get desktopPrintDate => 'Date';

  @override
  String get desktopPrintAttachments => 'Attachments';

  @override
  String get desktopDefaultMailAppHintMac =>
      'Email links (mailto:) in the browser and documents will open a new message in XatBox. macOS asks you to confirm.';

  @override
  String get desktopDefaultMailAppDone => 'XatBox now opens mailto: links';

  @override
  String desktopMailMore(int count) {
    return '$count more new messages';
  }

  @override
  String get desktopMailNotifications => 'Notify about new mail';

  @override
  String get desktopMailNotificationsHint =>
      'A notification with Reply, Mark as read and Delete while XatBox is in the background or on another page';

  @override
  String get desktopFileHint => 'Drag to a folder · Space for a quick look';

  @override
  String get desktopEmlUnreadable => 'Could not read the message file';

  @override
  String get desktopAwayStatus => 'Away';

  @override
  String get desktopMiniCallMute => 'Mute';

  @override
  String get desktopMiniCallUnmute => 'Unmute';

  @override
  String get desktopMiniCallEnd => 'End call';

  @override
  String get desktopMiniCallExpand => 'Expand';

  @override
  String get desktopLaunchAtLogin => 'Start when I sign in';

  @override
  String get desktopLaunchAtLoginHint =>
      'XatBox starts in the tray and gets mail and messages right away';

  @override
  String get desktopLaunchAtLoginManaged =>
      'Turned on by the administrator for all users of this computer';

  @override
  String get desktopGlobalHotkeys => 'Global shortcuts';

  @override
  String desktopGlobalHotkeysHint(String compose, String show) {
    return '$compose new message, $show show XatBox, from any program';
  }

  @override
  String get desktopAutoAway => '“Away” status automatically';

  @override
  String get desktopAutoAwayHint =>
      'While the computer is locked or idle for 10 minutes. Your own status is left alone';

  @override
  String get desktopMiniCall => 'Mini call window';

  @override
  String get desktopMiniCallHint =>
      'When you switch to another program the call stays in a small window on top';

  @override
  String get desktopNotificationSound => 'Notification sound';

  @override
  String get desktopNotificationSoundHint =>
      'New chat messages and new letters';

  @override
  String get desktopSoundXatbox => 'XatBox';

  @override
  String get desktopSoundSystem => 'System';

  @override
  String get desktopSoundNone => 'None';

  @override
  String get desktopRingtone => 'Ringtone';

  @override
  String get desktopRingtoneHint => 'Incoming call';

  @override
  String get desktopRingtoneClassic => 'Classic';

  @override
  String get desktopSoundPreview => 'Play';

  @override
  String get chatWritePersonally => 'Message privately';

  @override
  String get chatMemberActions => 'Member';

  @override
  String get desktopBetaUpdates => 'Get beta versions';

  @override
  String get desktopBetaUpdatesHint =>
      'New versions arrive right away, a day before everyone else. They may have bugs.';

  @override
  String get updateDownloadOnly => 'Download';

  @override
  String get updateLinuxOpen => 'Open the package';

  @override
  String get updateLinuxOpened => 'The package is open in the installer';

  @override
  String get updateLinuxOpenedHint =>
      'Install it (it needs an administrator password) and restart XatBox. The .deb file is in your Downloads folder.';

  @override
  String get desktopSpellCheck => 'Spelling in messages';

  @override
  String get desktopSpellCheckHint =>
      'Mistakes are underlined, suggestions on right click. System dictionaries: Russian, English, Kazakh (if installed)';

  @override
  String get desktopShortcutQuickLook =>
      'Quick look at the attachment under the pointer';

  @override
  String get desktopShortcutGlobalCompose => 'New message from any program';

  @override
  String get desktopShortcutGlobalShow => 'Show XatBox from any program';

  @override
  String get desktopCalendarOpen => 'Open';

  @override
  String get desktopCalendarGoToDate => 'Go to date';

  @override
  String get desktopCalendarNewHere => 'New event here';

  @override
  String desktopCalendarWeekNumber(int week) {
    return 'Week $week';
  }

  @override
  String get desktopSelectMessageToRead => 'Select a message to read';

  @override
  String get desktopSelectMessageToReadHint =>
      'Choose a message from the list. It opens here, so you never lose your place.';

  @override
  String get desktopProfileFullName => 'Full name';

  @override
  String get desktopRoleMember => 'Employee';

  @override
  String get desktopRoleUserManager => 'User manager';

  @override
  String get desktopRoleOrgAdmin => 'Organization administrator';

  @override
  String get desktopRoleDomainAdmin => 'Domain administrator';

  @override
  String get desktopRoleDeveloper => 'Developer';

  @override
  String get desktopRoleSecurityAnalyst => 'Security analyst';

  @override
  String get desktopRoleAuditor => 'Auditor';

  @override
  String get desktopRoleSupport => 'Support';

  @override
  String get desktopRoleTenantOwner => 'Tenant owner';

  @override
  String get desktopRoleSuperAdmin => 'Super administrator';

  @override
  String get desktopRolePlatformSuperAdmin => 'Platform super administrator';

  @override
  String get desktopContactMeeting => 'Meeting';

  @override
  String get desktopContactScheduleMeeting => 'Schedule a meeting';

  @override
  String get desktopContactCopyAddress => 'Copy address';

  @override
  String get desktopCalendarEmailParticipants => 'Email participants';

  @override
  String get desktopCalendarExternalGroup => 'External participants';

  @override
  String get desktopCalendarNoDepartment => 'No department';

  @override
  String get desktopPaletteHint => 'Command, section or search…';

  @override
  String desktopPaletteSearch(String query) {
    return 'Search everywhere for “$query”';
  }

  @override
  String get desktopPaletteToggleTheme => 'Switch light / dark theme';

  @override
  String get desktopPaletteGoTo => 'Go to';

  @override
  String get desktopPaletteCreate => 'Create';

  @override
  String get desktopPaletteNothing => 'Nothing found';

  @override
  String get desktopCallStart => 'Call';

  @override
  String get desktopCallWithVideo => 'With video';

  @override
  String get desktopCallShortcuts => 'Call';

  @override
  String get desktopMailSettingsShortcuts => 'Shortcuts';

  @override
  String get desktopMailSettingsShortcutsHint =>
      'Work without the mouse. Press ? anywhere to see this list.';

  @override
  String get desktopMailKeysCalendarPrevNext => 'Previous / next period';

  @override
  String get desktopMailKeysCalendarClosePanel => 'Close the event panel';

  @override
  String get desktopMailRestored => 'Restored';

  @override
  String get desktopCrashTitle => 'XatBox closed unexpectedly';

  @override
  String get desktopCrashBody =>
      'Last time the app ended with an error. Send the log of its last steps to the developers? It holds no message texts, passwords or addresses.';

  @override
  String get desktopCrashSend => 'Send';

  @override
  String get desktopCrashSkip => 'Don\'t send';

  @override
  String get desktopCrashSent => 'Thank you, the report was sent';

  @override
  String desktopCrashReport(String version, String time) {
    return 'Automatic report: XatBox $version closed unexpectedly (started $time)';
  }

  @override
  String desktopMailMovedTo(String folder) {
    return 'Moved to “$folder”';
  }

  @override
  String get desktopMailHideList => 'Hide message list';

  @override
  String get desktopMailShowList => 'Show message list';

  @override
  String get desktopMailLinkElsewhereTitle =>
      'This link opens a different site';

  @override
  String desktopMailLinkElsewhereBody(String shown, String real) {
    return 'The text shows one address, but the link opens another. Open it anyway?\n\nShown: $shown\nOpens: $real';
  }

  @override
  String get desktopMailLinkOpenAnyway => 'Open anyway';

  @override
  String desktopMailQuickReplyHint(String keys) {
    return 'Write a reply… ($keys to send)';
  }

  @override
  String get desktopMailQuickReplyAttach => 'Attach file';

  @override
  String get desktopMailQuickReplyUploading => 'Uploading…';

  @override
  String get desktopMailQuickReplyUploadFailed => 'Upload failed';

  @override
  String get desktopMailQuickReplyRemoveFile => 'Remove file';

  @override
  String desktopMailQuickReplySentTo(String recipients, String time) {
    return 'Sent to $recipients · $time';
  }

  @override
  String get desktopShortcutPalette => 'Command palette';

  @override
  String get desktopChatCreate => 'Create';

  @override
  String get desktopChatDetails => 'Details';

  @override
  String get mailOutboxQueued =>
      'No network — the letter is in the Outbox and will go out once you are back online';

  @override
  String mailOutboxTitle(int count) {
    return 'Outbox: $count';
  }

  @override
  String get mailOutboxHint =>
      'will be sent automatically once you are back online';

  @override
  String get mailOutboxWaiting => 'Waiting for network';

  @override
  String get mailOutboxSending => 'Sending…';

  @override
  String mailOutboxFailed(String error) {
    return 'Not sent: $error';
  }

  @override
  String get mailOutboxSendNow => 'Send now';

  @override
  String get mailOutboxDiscard => 'Remove from Outbox';

  @override
  String mailOutboxSent(int count) {
    return 'Letters sent from the Outbox: $count';
  }

  @override
  String get skinGlassForest => 'Forest glass';

  @override
  String get skinGlassForestHint => 'Clear panels over a misty morning forest';

  @override
  String get skinGlassSpace => 'Space';

  @override
  String get skinGlassSpaceHint => 'Clear panels over a starry sky';

  @override
  String get desktopEventTitleHint => 'Add a title';

  @override
  String desktopEventDurationMinutes(int count) {
    return '$count min';
  }

  @override
  String desktopEventDurationHours(int count) {
    return '$count h';
  }

  @override
  String desktopEventDurationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get desktopEventParticipantsHint =>
      'Invite people: a name or an email';

  @override
  String desktopEventInviteEmail(String email) {
    return 'Invite $email';
  }

  @override
  String get desktopEventLocationHint => 'Add a location';

  @override
  String get desktopEventDescriptionHint => 'Description or agenda';

  @override
  String get desktopEventMore => 'More: link, room, find a time';

  @override
  String get desktopEventLess => 'Hide extra options';

  @override
  String get desktopEventRepeatCustom => 'Custom…';

  @override
  String desktopEventSaveHint(String keys) {
    return '$keys to save';
  }

  @override
  String get desktopEventReminder => 'Reminder';

  @override
  String get desktopEventOtherTime => 'Other time…';

  @override
  String get desktopEventNoReminders => 'No reminders';

  @override
  String get tasksBoardByDue => 'By due date';

  @override
  String get tasksBoardByStatus => 'By status';

  @override
  String get tasksColumnTomorrow => 'Tomorrow';

  @override
  String get tasksColumnLater => 'Later';

  @override
  String get tasksColumnDone => 'Done';

  @override
  String get tasksColumnTodo => 'To do';

  @override
  String get tasksColumnInProgress => 'In progress';

  @override
  String get tasksQuickAdd => 'Add a task';

  @override
  String get tasksQuickAddHint => 'What needs doing? Enter to add';

  @override
  String get tasksDropHere => 'Drop a task here';

  @override
  String get tasksBoardHintDue =>
      'Drag cards between columns and the due date follows';

  @override
  String get tasksBoardHintStatus => 'Drag cards to change their status';

  @override
  String tasksStatToday(int count) {
    return 'Today: $count';
  }

  @override
  String tasksStatOverdue(int count) {
    return 'Overdue: $count';
  }

  @override
  String tasksStatDone(int count) {
    return 'Done: $count';
  }

  @override
  String tasksShowAll(int count) {
    return 'Show all · $count';
  }

  @override
  String get tasksShowLess => 'Show less';

  @override
  String get tasksPickDay => 'Move it to which day?';

  @override
  String get tasksSearchHint => 'Search tasks';

  @override
  String get tasksFromMail => 'From a letter';

  @override
  String get tasksMarkInProgress => 'Start working';

  @override
  String get tasksArchive => 'Archive';

  @override
  String get tasksArchived => 'Task archived';

  @override
  String get tasksRestore => 'Restore';

  @override
  String get tasksRestored => 'Task is back on the board';

  @override
  String get tasksArchiveTitle => 'Archive';

  @override
  String get tasksArchiveEmpty =>
      'The archive is empty. Done tasks can be put here from the card menu.';

  @override
  String get tasksArchiveAllBoards => 'All boards';

  @override
  String get tasksArchiveThisBoard => 'This board only';

  @override
  String get myContactsTitle => 'My contacts';

  @override
  String get myContactsAllStaff => 'All colleagues';

  @override
  String get myContactsDepartments => 'Departments';

  @override
  String get myContactsNew => 'New contact';

  @override
  String get myContactsPin => 'Add to my contacts';

  @override
  String get myContactsUnpin => 'Remove from my contacts';

  @override
  String myContactsPinned(String name) {
    return '$name is in your contacts';
  }

  @override
  String get myContactsEmptyTitle => 'Your contacts will live here';

  @override
  String get myContactsEmptyHint =>
      'Pin colleagues with the star in the staff list, or add someone from outside the university';

  @override
  String get myContactsBrowseStaff => 'Browse colleagues';

  @override
  String get myContactsSectionStaff => 'Colleagues';

  @override
  String get myContactsSectionPersonal => 'Personal contacts';

  @override
  String get myContactsPersonalTag => 'Personal';

  @override
  String get myContactsSelect => 'Pick a contact to see the details';

  @override
  String get myContactsNothingFound => 'Nobody found';

  @override
  String get personalContactName => 'Full name';

  @override
  String get personalContactNameRequired => 'Enter a name';

  @override
  String get personalContactEmail => 'Email';

  @override
  String get personalContactEmailInvalid => 'Check the email address';

  @override
  String get personalContactPhone => 'Phone';

  @override
  String get personalContactOrganization => 'Organization';

  @override
  String get personalContactPosition => 'Position';

  @override
  String get personalContactNote => 'Note';

  @override
  String get personalContactEdit => 'Edit contact';

  @override
  String get personalContactDelete => 'Delete contact';

  @override
  String personalContactDeleteConfirm(String name) {
    return 'Delete “$name” from your contacts?';
  }

  @override
  String get personalContactSaved => 'Contact saved';

  @override
  String get personalContactDeleted => 'Contact deleted';

  @override
  String get personalContactLocalNote =>
      'Personal contacts are kept on this computer';

  @override
  String get personalContactCall => 'Call';

  @override
  String get skinGlassAstana => 'Astana';

  @override
  String get skinGlassAstanaHint => 'Clear panels over a photograph of Astana';

  @override
  String get skinGlassSemey => 'Semey';

  @override
  String get skinGlassSemeyHint =>
      'Clear panels over the bridge across the Irtysh';

  @override
  String get skinGlassCustom => 'My picture';

  @override
  String get skinGlassCustomHint => 'Clear panels over a picture of your own';

  @override
  String get settingsBackdropOwn => 'Your picture';

  @override
  String get settingsBackdropOwnHint =>
      'Copied into the XatBox folder; the original can be deleted';

  @override
  String get settingsBackdropNone =>
      'No picture yet — a plain dark backdrop for now';

  @override
  String get settingsBackdropPick => 'Choose a picture';

  @override
  String get settingsBackdropReplace => 'Replace the picture';

  @override
  String get settingsBackdropRemove => 'Remove';

  @override
  String get settingsBackdropDim => 'Dim';

  @override
  String get settingsBackdropBlur => 'Blur';

  @override
  String get settingsBackdropFailed => 'That picture could not be read';

  @override
  String get settingsBackdropCredits => 'Backdrop photographs';

  @override
  String get settingsBackdropCreditAstana =>
      '«Astana» — photo by Dauren Nabijan, CC0, Wikimedia Commons';

  @override
  String get settingsBackdropCreditSemey =>
      '«Semey» — photo by Ivan Bykov, CC BY 3.0, cropped, Wikimedia Commons';

  @override
  String get mailSettingsImport => 'Import mail';

  @override
  String get mailSettingsImportSubtitle =>
      'Bring mail over from a previous mail system';

  @override
  String get mailImportHint =>
      'Bring mail from a previous mail system into this mailbox. Nothing here is replaced: what is already in your folders stays, and a message you already have is recognised and not doubled.';

  @override
  String get mailImportFile => 'Archive (.tgz)';

  @override
  String get mailImportFileHint =>
      'The file your previous mail system exported for your account. Zimbra: Preferences → Import/Export → Export. Up to 2 GB; the import runs in the background and you can close the app.';

  @override
  String get mailImportChoose => 'Choose an archive';

  @override
  String get mailImportStart => 'Upload and import';

  @override
  String mailImportUploading(int percent) {
    return 'Uploading $percent%';
  }

  @override
  String get mailImportCancelUpload => 'Stop the upload';

  @override
  String get mailImportPickFile => 'Choose an archive first';

  @override
  String mailImportWrongName(String mailbox) {
    return 'This archive is not named for your mailbox. Upload the file named $mailbox.tgz';
  }

  @override
  String get mailImportQueued => 'Uploaded: the import starts in a moment';

  @override
  String mailImportImported(int imported, int total) {
    return '$imported / $total imported';
  }

  @override
  String mailImportAlready(int count) {
    return '$count already here';
  }

  @override
  String mailImportFailedCount(int count) {
    return '$count could not be added';
  }

  @override
  String mailImportNotMail(int count) {
    return '$count not mail (contacts, calendar)';
  }

  @override
  String get mailImportDeleteTitle => 'Remove this import?';

  @override
  String get mailImportDeleteBody =>
      'The record and the uploaded file are removed. Mail already imported stays in your folders.';

  @override
  String get mailImportFailedGeneric => 'The import could not be started';

  @override
  String get mailImportStatusQueued => 'Queued';

  @override
  String get mailImportStatusRunning => 'Importing';

  @override
  String get mailImportStatusDone => 'Done';

  @override
  String get mailImportStatusFailed => 'Failed';

  @override
  String requestsNumber(int number) {
    return 'Request #$number';
  }

  @override
  String get requestsWhat => 'What happened';

  @override
  String get requestsWhatHint => 'Describe the problem';

  @override
  String get requestsRoom => 'Room';

  @override
  String get requestsRoomHint => 'For example, 305';

  @override
  String get requestsDate => 'Date';

  @override
  String get requestsSubmit => 'Send request';

  @override
  String get requestsFillAll => 'Fill in all three fields';

  @override
  String get requestsStatusNew => 'New';

  @override
  String get requestsStatusInProgress => 'In progress';

  @override
  String get requestsStatusDone => 'Done';

  @override
  String get requestsStatusRejected => 'Rejected';

  @override
  String get requestsEmptyTitle => 'Your requests will appear here';

  @override
  String get requestsEmptyHint =>
      'Fill in the form below: what happened, the room and the date. The answer comes to this chat.';

  @override
  String get requestsListHint => 'File a request';

  @override
  String get tabMore => 'More';

  @override
  String get contactsFilterMine => 'Mine';

  @override
  String get notifTestHintPhone => 'Show a test notification on this phone';
}
