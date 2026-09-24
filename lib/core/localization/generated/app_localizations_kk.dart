// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kazakh (`kk`).
class AppLocalizationsKk extends AppLocalizations {
  AppLocalizationsKk([String locale = 'kk']) : super(locale);

  @override
  String get appTitle => 'XatBox';

  @override
  String get chatFilterChannels => 'Арналар';

  @override
  String get channelsDiscoverTitle => 'Ұйым арналары';

  @override
  String get channelsSearchHint => 'Арналарды іздеу';

  @override
  String get channelsEmpty => 'Ұйымда әзірге ашық арна жоқ';

  @override
  String get channelsNothingFound => 'Ештеңе табылмады';

  @override
  String get channelSubscribe => 'Жазылу';

  @override
  String get channelSubscribed => 'Жазылдыңыз';

  @override
  String get channelUnsubscribe => 'Жазылымнан шығу';

  @override
  String channelUnsubscribeConfirm(String title) {
    return '«$title» арнасынан жазылымды тоқтату керек пе?';
  }

  @override
  String channelSubscribersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count жазылушы',
    );
    return '$_temp0';
  }

  @override
  String get channelCreate => 'Арна құру';

  @override
  String get channelNameLabel => 'Арна атауы';

  @override
  String get channelDescriptionLabel => 'Сипаттама (міндетті емес)';

  @override
  String get channelPublic => 'Ашық арна';

  @override
  String get channelPublicHint =>
      'Ұйымның кез келген қызметкері арнаны «Ұйым арналарынан» тауып, жазыла алады';

  @override
  String get channelPrivateHint => 'Жазылушыларды арна әкімшілері қосады';

  @override
  String get channelReadOnly => 'Тек арна әкімшілері жариялай алады';

  @override
  String get channelBadge => 'Арна';

  @override
  String get channelSubscribers => 'Жазылушылар';

  @override
  String get channelAdmins => 'Әкімшілер';

  @override
  String get channelAddSubscriber => 'Жазылушы қосу';

  @override
  String channelViews(int count) {
    return 'Қаралым: $count';
  }

  @override
  String get channelNoPermission => 'Арна құруға рұқсатыңыз жоқ';

  @override
  String get pollAttach => 'Сауалнама';

  @override
  String get pollNewTitle => 'Жаңа сауалнама';

  @override
  String get pollQuestionLabel => 'Сұрақ';

  @override
  String get pollOptionsLabel => 'Жауап нұсқалары';

  @override
  String pollOptionHint(int n) {
    return '$n-нұсқа';
  }

  @override
  String get pollAddOption => 'Нұсқа қосу';

  @override
  String get pollRemoveOption => 'Нұсқаны өшіру';

  @override
  String get pollAnonymous => 'Жасырын дауыс беру';

  @override
  String get pollMultiple => 'Бірнеше жауап';

  @override
  String get pollQuiz => 'Викторина режимі';

  @override
  String get pollQuizHint => 'Дұрыс жауапты белгілеңіз';

  @override
  String get pollCloseSection => 'Автоматты түрде аяқтау';

  @override
  String get pollCloseNever => 'Жоқ';

  @override
  String get pollClose1h => 'Бір сағаттан кейін';

  @override
  String get pollClose1d => 'Бір тәуліктен кейін';

  @override
  String get pollCloseWeek => 'Бір аптадан кейін';

  @override
  String get pollCreate => 'Құру';

  @override
  String get pollErrorQuestion => 'Сұрақты енгізіңіз';

  @override
  String get pollErrorOptions => '2-ден 10-ға дейін әртүрлі нұсқа қажет';

  @override
  String get pollKindAnonymous => 'Жасырын сауалнама';

  @override
  String get pollKindPublic => 'Ашық сауалнама';

  @override
  String get pollKindQuiz => 'Викторина';

  @override
  String get pollClosed => 'Сауалнама аяқталды';

  @override
  String get pollVote => 'Дауыс беру';

  @override
  String get pollRetract => 'Дауысты қайтару';

  @override
  String get pollCloseNow => 'Сауалнаманы аяқтау';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дауыс',
      zero: 'Дауыс жоқ',
    );
    return '$_temp0';
  }

  @override
  String pollEndsAt(String time) {
    return '$time дейін';
  }

  @override
  String get pollVotersTitle => 'Дауыс бергендер';

  @override
  String get pollNoVoters => 'Бұл нұсқаны әзірге ешкім таңдамады';

  @override
  String get pollCorrect => 'Дұрыс жауап';

  @override
  String get scheduleSendLater => 'Кейінірек жіберу';

  @override
  String get scheduleIn1h => '1 сағаттан кейін';

  @override
  String get scheduleTonight => 'Бүгін кешке';

  @override
  String get scheduleTomorrowMorning => 'Ертең таңертең';

  @override
  String get schedulePick => 'Күн мен уақытты таңдау';

  @override
  String get scheduleTooEarly => 'Болашақтағы уақытты таңдаңыз';

  @override
  String get scheduledTitle => 'Жоспарланғандар';

  @override
  String scheduledBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count жоспарланған хабарлама',
    );
    return '$_temp0';
  }

  @override
  String get scheduledEmpty => 'Жоспарланған хабарлама жоқ';

  @override
  String get scheduledSendNow => 'Қазір жіберу';

  @override
  String get scheduledEditText => 'Мәтінді өзгерту';

  @override
  String get scheduledEditTime => 'Уақытты өзгерту';

  @override
  String get scheduledFailed => 'Жіберілмеді';

  @override
  String scheduledCreated(String when) {
    return 'Хабарлама $when жіберіледі';
  }

  @override
  String scheduledAttachments(int count) {
    return 'Тіркемелер: $count';
  }

  @override
  String get remindAction => 'Еске салу';

  @override
  String get remindSheetTitle => 'Хабарлама туралы еске салу';

  @override
  String get remindersTitle => 'Еске салғыштар';

  @override
  String get remindersEmpty => 'Еске салғыш жоқ';

  @override
  String get remindersEmptyHint =>
      'Хабарламаны басып тұрып, «Еске салу» таңдаңыз';

  @override
  String get remindersUpcoming => 'Алдағы';

  @override
  String get remindersDone => 'Орындалған';

  @override
  String reminderSetDone(String when) {
    return '$when еске саламын';
  }

  @override
  String get reminderReschedule => 'Ауыстыру';

  @override
  String get reminderDelete => 'Еске салғышты өшіру';

  @override
  String get reminderNotificationTitle => 'Еске салу';

  @override
  String get notifPrefsChannels => 'Арналар';

  @override
  String chatWhenToday(String time) {
    return 'бүгін $time';
  }

  @override
  String chatWhenTomorrow(String time) {
    return 'ертең $time';
  }

  @override
  String chatWhenDate(String date, String time) {
    return '$date, $time';
  }

  @override
  String get tabMail => 'Пошта';

  @override
  String get tabChat => 'Чат';

  @override
  String get tabCalls => 'Қоңыраулар';

  @override
  String get comingSoon => 'Жақында';

  @override
  String get chatComingSoonBody => 'Чат модулі келесі жаңартуда қосылады.';

  @override
  String get callsComingSoonBody =>
      'Қоңыраулар модулі келесі жаңартуда қосылады.';

  @override
  String get splashChecking => 'Сессия тексерілуде…';

  @override
  String get splashUnreachableTitle => 'Сервер қолжетімсіз';

  @override
  String get splashUnreachableBody =>
      'Сессияны тексеру мүмкін болмады. Қосылымды тексеріп, қайталап көріңіз.';

  @override
  String get splashSignInAgain => 'Қайта кіру';

  @override
  String get loginTitle => 'XatBox-қа кіру';

  @override
  String get loginSubtitle => 'Корпоративтік пошта тіркелгісін пайдаланыңыз';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginPassword => 'Құпиясөз';

  @override
  String get loginButton => 'Кіру';

  @override
  String get loginEmailRequired => 'Email енгізіңіз';

  @override
  String get loginPasswordRequired => 'Құпиясөзді енгізіңіз';

  @override
  String get loginEmailInvalid => 'Email дұрыс емес';

  @override
  String get sessionExpiredBanner => 'Сессия мерзімі өтті. Қайта кіріңіз.';

  @override
  String get errInvalidCredentialsFormat => 'Email мен құпиясөзді енгізіңіз.';

  @override
  String get errInvalidCredentials => 'Email немесе құпиясөз қате.';

  @override
  String get errUserDisabled => 'Тіркелгі өшірілген. Әкімшіге хабарласыңыз.';

  @override
  String get errOrganizationSuspended =>
      'Ұйымның жазылымы тоқтатылған. Әкімшіге хабарласыңыз.';

  @override
  String get errDirectoryDisabled =>
      'Корпоративтік каталог арқылы кіру өшірілген. Әкімшіге хабарласыңыз.';

  @override
  String get errTooManyAttempts =>
      'Кіру әрекеттері тым көп. Кейінірек қайталап көріңіз.';

  @override
  String get errDirectoryUnavailable =>
      'Корпоративтік каталог қолжетімсіз. Кейінірек қайталап көріңіз.';

  @override
  String get errSubscriptionLimit =>
      'Ұйымның пайдаланушылар шегіне жетті. Әкімшіге хабарласыңыз.';

  @override
  String get errInternal => 'Сервер қатесі. Кейінірек қайталап көріңіз.';

  @override
  String get errNetwork =>
      'Сервермен байланыс жоқ. Интернетке қосылымды тексеріңіз.';

  @override
  String get errTimeout =>
      'Сервер ұзақ жауап бермей тұр. Тағы да қайталап көріңіз.';

  @override
  String get errUnauthenticated => 'Сессия мерзімі өтті. Қайта кіріңіз.';

  @override
  String get errForbidden => 'Бұл әрекетке құқығыңыз жоқ.';

  @override
  String get errNoMailbox => 'Тіркелгіңізде белсенді пошта жәшігі жоқ.';

  @override
  String get errMailServiceUnavailable => 'Пошта қызметі уақытша қолжетімсіз.';

  @override
  String get errMessageNotFound => 'Хат табылмады.';

  @override
  String get errFolderNotFound => 'Қалта табылмады.';

  @override
  String errInvalidMessage(String detail) {
    return 'Хат тексеруден өтпеді: $detail';
  }

  @override
  String get errInvalidBody => 'Сұрау дұрыс емес. Қолданбаны жаңартыңыз.';

  @override
  String get errAttachmentTooLarge => 'Файл тым үлкен.';

  @override
  String get errStorageUnavailable =>
      'Файл қоймасы қолжетімсіз. Кейінірек қайталап көріңіз.';

  @override
  String get errConverterUnavailable =>
      'Серверде құжаттарды алдын ала қарау қолжетімсіз.';

  @override
  String get errNotConvertible => 'Бұл файлды PDF ретінде көрсету мүмкін емес.';

  @override
  String get errConvertTimeout =>
      'Алдын ала қарауды дайындау мүмкін болмады: күту уақыты асып кетті.';

  @override
  String get errConvertFailed => 'Алдын ала қарауды дайындау мүмкін болмады.';

  @override
  String errUnknown(String code) {
    return 'Бірдеңе дұрыс болмады ($code).';
  }

  @override
  String get errUnexpected => 'Сервердің күтпеген жауабы.';

  @override
  String errRequestId(String id) {
    return 'Сұрау коды: $id';
  }

  @override
  String get retry => 'Қайталау';

  @override
  String get cancel => 'Болдырмау';

  @override
  String get ok => 'Жарайды';

  @override
  String get close => 'Жабу';

  @override
  String get delete => 'Жою';

  @override
  String get send => 'Жіберу';

  @override
  String get save => 'Сақтау';

  @override
  String get search => 'Іздеу';

  @override
  String get loading => 'Жүктелуде…';

  @override
  String get offlineBanner => 'Желі жоқ — сақталған деректер көрсетілген';

  @override
  String get offlineProfileBanner =>
      'Сервер қолжетімсіз, офлайн режимде жұмыс істеп тұр';

  @override
  String get folderInbox => 'Кіріс';

  @override
  String get folderSent => 'Жіберілген';

  @override
  String get folderDrafts => 'Жобалар';

  @override
  String get folderSpam => 'Спам';

  @override
  String get folderTrash => 'Себет';

  @override
  String get folderBookmarks => 'Бетбелгілер';

  @override
  String get sectionSmartFolders => 'Ақылды қалталар';

  @override
  String get sectionBookmarkFolders => 'Бетбелгі қалталары';

  @override
  String get mailEmptyFolder => 'Бұл қалтада хат жоқ';

  @override
  String get mailEmptySearch => 'Ештеңе табылмады';

  @override
  String get mailSearchHint => 'Қалтадан іздеу';

  @override
  String get filterUnread => 'Оқылмағандар';

  @override
  String get filterStarred => 'Бетбелгілер';

  @override
  String get filterAttachments => 'Тіркемелері бар';

  @override
  String get mailNoSubject => '(тақырыпсыз)';

  @override
  String get mailLoadMoreError => 'Қосымша жүктеу мүмкін болмады';

  @override
  String get mailMarkRead => 'Оқылды';

  @override
  String get mailMarkUnread => 'Оқылмады';

  @override
  String get mailStar => 'Бетбелгіге қосу';

  @override
  String get mailUnstar => 'Бетбелгіден алып тастау';

  @override
  String get mailMoveToTrash => 'Себетке';

  @override
  String get mailDeleteForever => 'Біржола жою';

  @override
  String get mailDeleteForeverConfirm =>
      'Хат қайтарылмайтындай болып жойылады. Жалғастыру керек пе?';

  @override
  String get mailReportSpam => 'Спамға';

  @override
  String get mailReportNotSpam => 'Спам емес';

  @override
  String get mailMoveTo => 'Қалтаға жылжыту…';

  @override
  String get mailReply => 'Жауап беру';

  @override
  String get mailReplyAll => 'Барлығына жауап беру';

  @override
  String get mailForward => 'Қайта жіберу';

  @override
  String get mailCompose => 'Жазу';

  @override
  String get mailNoPermission => 'Поштаға қолжетімділігіңіз жоқ.';

  @override
  String get mailAttachments => 'Тіркемелер';

  @override
  String get attachmentOpen => 'Ашу';

  @override
  String get attachmentPreviewPdf => 'Алдын ала қарау (PDF)';

  @override
  String get attachmentDownloading => 'Файл жүктелуде…';

  @override
  String get attachmentNoApp => 'Бұл файлды ашатын қолданба жоқ';

  @override
  String get mailFrom => 'Кімнен';

  @override
  String get mailTo => 'Кімге';

  @override
  String get mailCc => 'Көшірме';

  @override
  String get mailBcc => 'Жасырын көшірме';

  @override
  String get mailSubject => 'Тақырып';

  @override
  String get mailBody => 'Хат мәтіні';

  @override
  String mailThreadTitle(int count) {
    return 'Хат алмасу ($count)';
  }

  @override
  String get mailShowHtml => 'Безендіруді көрсету';

  @override
  String get mailShowText => 'Мәтін ретінде көрсету';

  @override
  String get mailNoBody => '(бос хат)';

  @override
  String get mailRemoteContentBlocked => 'Сыртқы суреттер бұғатталған';

  @override
  String get mailOpenLinkTitle => 'Сілтемені ашу керек пе?';

  @override
  String get mailOpen => 'Ашу';

  @override
  String mailUnreadCount(int count) {
    return '$count оқылмаған';
  }

  @override
  String get mailActionDone => 'Дайын';

  @override
  String get mailMovedToTrash => 'Хат себетке жылжытылды';

  @override
  String get mailDeleted => 'Хат жойылды';

  @override
  String get mailReportedSpam => 'Хат спам ретінде белгіленді';

  @override
  String get mailReportedHam => 'Хат «Кіріс» қалтасына қайтарылды';

  @override
  String get composeTitleNew => 'Жаңа хат';

  @override
  String get composeTitleReply => 'Жауап';

  @override
  String get composeTitleForward => 'Қайта жіберу';

  @override
  String get composeTitleDraft => 'Жоба';

  @override
  String get composeRecipientsRequired => 'Кемінде бір алушыны көрсетіңіз';

  @override
  String composeInvalidAddress(String address) {
    return 'Мекенжай дұрыс емес: $address';
  }

  @override
  String get composeTooManyRecipients => 'Алушылар тым көп (ең көбі 100)';

  @override
  String get composeSubjectTooLong => 'Тақырып тым ұзын';

  @override
  String get composeTooManyAttachments => '20 тіркемеден аспауы керек';

  @override
  String composeAttachmentTooLarge(String name, String limit) {
    return '«$name» файлы $limit шегінен асады';
  }

  @override
  String get composeAddAttachment => 'Файл тіркеу';

  @override
  String get composeSent => 'Хат жіберілді';

  @override
  String get composeSaveDraft => 'Жобаны сақтау';

  @override
  String get composeDraftSaved => 'Жоба сақталды';

  @override
  String get composeDiscard => 'Сақтамау';

  @override
  String get composeDiscardTitle => 'Хатты жабу керек пе?';

  @override
  String get composeDiscardBody => 'Сақталмаған өзгерістер жоғалады.';

  @override
  String get composeSending => 'Жіберілуде…';

  @override
  String get composeForwardedAttachments => 'Бастапқы хаттың тіркемелері';

  @override
  String get composeSignatureNote => 'Қолтаңбаны жіберу кезінде сервер қосады.';

  @override
  String composeQuoteHeader(String date, String from) {
    return '$date, $from жазды:';
  }

  @override
  String get composeForwardHeader =>
      '---------- Қайта жіберілген хат ----------';

  @override
  String get composeRecipientHint => 'мекенжайларды үтір арқылы жазыңыз';

  @override
  String get composeNoSendPermission => 'Хат жіберуге құқығыңыз жоқ.';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileSessions => 'Белсенді сессиялар';

  @override
  String get profileCurrentSession => 'Ағымдағы';

  @override
  String get profileEndSession => 'Аяқтау';

  @override
  String get profileEndOthers => 'Басқа сессияларды аяқтау';

  @override
  String get profileDepartment => 'Бөлімше';

  @override
  String profileSessionsEnded(int count) {
    return 'Аяқталған сессиялар: $count';
  }

  @override
  String profileExpires(String date) {
    return '$date дейін жарамды';
  }

  @override
  String get settingsTitle => 'Баптаулар';

  @override
  String get settingsLogout => 'Шығу';

  @override
  String get settingsLogoutConfirm =>
      'Осы құрылғыда тіркелгіден шығу керек пе?';

  @override
  String get settingsCacheSection => 'Жад және деректер';

  @override
  String get settingsCacheLimit => 'Ашылған хаттарды офлайн сақтау';

  @override
  String get settingsCacheClear => 'Кэшті тазалау';

  @override
  String get settingsCacheCleared => 'Кэш тазаланды';

  @override
  String settingsCacheStats(int messages, int lists) {
    return 'Кэште: $messages хат, $lists тізім';
  }

  @override
  String settingsVersion(String version) {
    return 'Нұсқа $version';
  }

  @override
  String get settingsDiagnostics => 'Диагностика';

  @override
  String get settingsDiagnosticsEmpty => 'Әзірге оқиғалар жоқ';

  @override
  String get settingsNotifications => 'Хабарландырулар';

  @override
  String get settingsNotificationsHint =>
      'Қандай push-хабарландырулар алу, тыныш сағаттар';

  @override
  String get settingsSendErrorReports => 'Қате туралы есептерді жіберу';

  @override
  String get settingsSendErrorReportsHint =>
      'Ақаулар туралы техникалық деректер тек XatBox серверіне жіберіледі, хабар мәтіндері мен мекенжайларсыз';

  @override
  String get notifPrefsServerHint =>
      'Баптаулар серверде сақталады: өшірілген хабарландырулар мүлде жіберілмейді';

  @override
  String get notifPrefsTypesSection => 'Нені жіберу';

  @override
  String get notifPrefsDirect => 'Жеке хабарлар';

  @override
  String get notifPrefsGroups => 'Топтар';

  @override
  String get notifPrefsMentionsOnly => 'Топтарда тек аталулар';

  @override
  String get notifPrefsCalls => 'Қоңыраулар';

  @override
  String get notifPrefsQuietSection => 'Тыныш сағаттар';

  @override
  String get notifPrefsQuietEnabled => 'Тыныш сағаттарда мазаламау';

  @override
  String notifPrefsQuietHint(String zone) {
    return 'Күн сайын, құрылғы уақытымен ($zone)';
  }

  @override
  String get notifPrefsQuietStart => 'Басталуы';

  @override
  String get notifPrefsQuietEnd => 'Аяқталуы';

  @override
  String get notifPrefsQuietAllowCalls =>
      'Тыныш сағаттарда қоңырауларды өткізу';

  @override
  String get notifPrefsQuietAllowCallsHint =>
      'Кіріс қоңыраулар әдеттегідей шырылдайды';

  @override
  String get notifPrefsPending => 'Өзгерістер байланыс болғанда жіберіледі';

  @override
  String get notifPrefsLoadFailed =>
      'Хабарландыру баптауларын жүктеу мүмкін болмады';

  @override
  String get notifPrefsRetry => 'Қайталау';

  @override
  String get notifPrefsSystemSettings => 'Жүйелік хабарландыру баптаулары';

  @override
  String get notifPrefsSystemSettingsHint =>
      'Дыбыс, діріл және Android арналары';

  @override
  String get notifBackgroundSection => 'Байланыс';

  @override
  String get notifBackgroundTitle => 'Фонда байланыста болу';

  @override
  String get notifBackgroundOneMinute => '1 минут';

  @override
  String get notifBackgroundFifteenMinutes => '15 минут';

  @override
  String get notifBackgroundAlways => 'Әрқашан';

  @override
  String notifBackgroundAuto(String value) {
    return 'Әдепкі ($value)';
  }

  @override
  String get notifBackgroundHint =>
      'Қолданба жабылғаннан кейін байланысты қанша уақыт ұстайды. Байланыс жабық кезде жаңа хабарлар мен қоңыраулар тек push-хабарландыру арқылы келеді. Қоңырау кезінде байланыс жабылмайды.';

  @override
  String get notifBackgroundNoPush =>
      'Push-хабарландырулар бапталмаған: байланыс жабық кезде хабарлар мен кіріс қоңыраулар келмейді';

  @override
  String get notifBackgroundAlwaysWarning => 'Батарея зарядын тезірек жұмсайды';

  @override
  String get permOnboardNotifTitle => 'Хабарландыруларды қосу керек пе?';

  @override
  String get permOnboardNotifBody =>
      'XatBox жаңа хабарлар, кіріс қоңыраулар және күнтізбе еске салғыштары туралы хабарлайды. Android рұқсат сұрайды — «Рұқсат ету» түймесін басыңыз.';

  @override
  String get permOnboardFsiTitle => 'Толық экрандағы қоңыраулар';

  @override
  String get permOnboardFsiBody =>
      'Кіріс қоңырау құлыптаулы экранда көрінуі үшін XatBox-қа толық экранды хабарландыруларға рұқсат беріңіз. Android баптаулары ашылады: қосқышты қосып, қолданбаға оралыңыз.';

  @override
  String get permAllow => 'Рұқсат ету';

  @override
  String get permNotNow => 'Қазір емес';

  @override
  String get permOpenSettings => 'Баптауларды ашу';

  @override
  String get notifDeviceSection => 'Осы телефон';

  @override
  String get notifDeviceNotifications => 'Хабарландыруларға рұқсат';

  @override
  String get notifDeviceGranted => 'Рұқсат етілген';

  @override
  String get notifDeviceNotificationsOff =>
      'Өшірулі: хабарлар, қоңыраулар мен еске салғыштар көрсетілмейді';

  @override
  String get notifDeviceFullScreen => 'Толық экрандағы қоңыраулар';

  @override
  String get notifDeviceFullScreenOff =>
      'Өшірулі: кіріс қоңырау тек шағын хабарландыру болып келеді';

  @override
  String get notifDeviceBattery => 'Батарея шектеуінсіз';

  @override
  String get notifDeviceBatteryOn =>
      'Android қолданбаның фондағы жұмысын кейінге қалдырмайды';

  @override
  String get notifDeviceBatteryOff =>
      'Телефон қолданылмай тұрғанда Android хабарлар мен еске салғыштарды кешіктіруі мүмкін';

  @override
  String get notifDeviceBatteryNoPush =>
      'Push-хабарландырулар бапталмаған кезде бұл әсіресе маңызды: шектеусіз қолданба байланыста ұзағырақ болады';

  @override
  String get notifDeviceHelp => 'Автоіске қосу және фондағы жұмыс';

  @override
  String get notifDeviceHelpHint =>
      'Xiaomi, Huawei, Honor, Samsung, Oppo, Realme';

  @override
  String get bgHelpTitle => 'Фондағы жұмыс';

  @override
  String get bgHelpIntro =>
      'Кейбір өндірушілер фондағы қолданбаларды қарапайым Android-қа қарағанда қаттырақ жабады. Хабарлар немесе қоңыраулар кешігіп келсе, төмендегі баптауларды тексеріңіз. Пункт атаулары микробағдарлама нұсқасына қарай сәл өзгеше болуы мүмкін.';

  @override
  String get bgHelpCommonTitle => 'Барлық телефондар үшін';

  @override
  String get bgHelpCommonSteps =>
      '1. Баптаулар → Қолданбалар → XatBox → Хабарландырулар: барлық санаттарды қосыңыз.\n2. Сол жерде → Батарея: «Шектеусіз» («Оңтайландырмау»).\n3. Қоңырау күтіп тұрсаңыз, XatBox-ты соңғы қолданбалардан сырғытып жаппаңыз.';

  @override
  String get bgHelpXiaomiTitle => 'Xiaomi, Redmi, POCO (MIUI, HyperOS)';

  @override
  String get bgHelpXiaomiSteps =>
      '1. Баптаулар → Қолданбалар → Барлық қолданбалар → XatBox.\n2. «Автоіске қосу» қосқышын қосыңыз.\n3. «Қуат үнемдеу» → «Шектеусіз».\n4. «Басқа рұқсаттар»: «Құлып экраны» және «Фонда қалқымалы терезелер» рұқсат етіңіз.\n5. Соңғы қолданбаларда XatBox картасын төмен тартып, құлыппен бекітіңіз.';

  @override
  String get bgHelpHuaweiTitle => 'Huawei, Honor (EMUI, MagicOS)';

  @override
  String get bgHelpHuaweiSteps =>
      '1. Баптаулар → Батарея → Қолданбаларды іске қосу.\n2. XatBox-ты тауып, «Автоматты басқаруды» өшіріңіз.\n3. Терезеде «Автоіске қосу», «Жанама іске қосу» және «Фонда жұмыс» қосыңыз.\n4. Баптаулар → Хабарландырулар → XatBox: құлып экранындағы хабарландыруларға рұқсат етіңіз.';

  @override
  String get bgHelpSamsungTitle => 'Samsung (One UI)';

  @override
  String get bgHelpSamsungSteps =>
      '1. Баптаулар → Қолданбалар → XatBox → Батарея: «Шектеусіз».\n2. Баптаулар → Батарея → Фондағы пайдалану шектеулері: XatBox «Ұйықтап жатқан» және «Терең ұйқыдағы» тізімдерінде болмауы керек.\n3. XatBox-ты «Ешқашан ұйықтамайтын қолданбаларға» қосыңыз.';

  @override
  String get bgHelpOppoTitle => 'Oppo, Realme, OnePlus, Vivo';

  @override
  String get bgHelpOppoSteps =>
      '1. Баптаулар → Қолданбалар → XatBox → Батареяны пайдалану: «Фондағы белсенділік» пен «Автоіске қосуға» рұқсат етіңіз.\n2. Баптаулар → Батарея → Оңтайландыру: XatBox үшін «Оңтайландырмау».\n3. XatBox-ты соңғы қолданбаларда бекітіңіз.';

  @override
  String get bgHelpCheck =>
      'Тексеру: телефонды 15 минутқа құлыптап, әріптесіңізден хабар жазуды не қоңырау шалуды сұраңыз.';

  @override
  String get a11ySearchPrevious => 'Алдыңғы сәйкестік';

  @override
  String get a11ySearchNext => 'Келесі сәйкестік';

  @override
  String get a11yMuted => 'дыбысы өшірілген';

  @override
  String get a11yPinned => 'бекітілген';

  @override
  String a11yUnreadCount(int count) {
    return 'оқылмаған: $count';
  }

  @override
  String get a11yMarkedUnread => 'оқылмаған деп белгіленген';

  @override
  String get a11yMicOff => 'микрофон өшірулі';

  @override
  String a11yHandsRaised(int count) {
    return 'қол көтергендер: $count';
  }

  @override
  String get a11yVoiceSeek => 'Дауыстық хабарды айналдыру';

  @override
  String a11yPinEntered(int filled, int length) {
    return '$length цифрдың $filled енгізілді';
  }

  @override
  String get a11yDecrease => 'Азайту';

  @override
  String get a11yIncrease => 'Көбейту';

  @override
  String get a11yAdd => 'Қосу';

  @override
  String a11yReaction(String emoji, int count) {
    return 'Реакция $emoji: $count';
  }

  @override
  String a11yVoiceMessage(String duration) {
    return 'Дауыстық хабар, $duration';
  }

  @override
  String get a11ySelected => 'таңдалған';

  @override
  String get a11yFavourite => 'таңдаулыларда';

  @override
  String get a11yGuest => 'қонақ';

  @override
  String get chatTitle => 'Чат';

  @override
  String get chatDisabled => 'Бұл жинақта чат бапталмаған.';

  @override
  String get chatNoAccess => 'Чатқа қолжетімділігіңіз жоқ.';

  @override
  String get chatEmpty =>
      'Әзірге чаттар жоқ. Әріптесіңізбен хат алмасуды бастаңыз.';

  @override
  String get chatNew => 'Жаңа чат';

  @override
  String get chatNewGroup => 'Жаңа топ';

  @override
  String get chatGroupTitle => 'Топ атауы';

  @override
  String get chatCreateGroup => 'Топ құру';

  @override
  String get chatSearchUsers => 'Аты немесе email бойынша іздеу';

  @override
  String get chatSearch => 'Чаттардан іздеу';

  @override
  String get chatSearchMessages => 'Хабарламалар';

  @override
  String get chatNoUsers => 'Ешкім табылмады';

  @override
  String chatSelectedMembers(int count) {
    return 'Таңдалды: $count';
  }

  @override
  String get chatConnecting => 'Қосылуда…';

  @override
  String get chatSyncing => 'Жаңартылуда…';

  @override
  String get chatOffline => 'Байланыс жоқ';

  @override
  String get chatOnline => 'желіде';

  @override
  String chatLastSeen(String when) {
    return '$when желіде болды';
  }

  @override
  String chatMembersCount(int count) {
    return '$count қатысушы';
  }

  @override
  String chatTyping(String name) {
    return '$name жазып жатыр…';
  }

  @override
  String get chatTypingMany => 'жазып жатыр…';

  @override
  String chatRecording(String name) {
    return '$name дауыстық хабарлама жазып жатыр…';
  }

  @override
  String get chatYou => 'Сіз';

  @override
  String get chatMessageHint => 'Хабарлама';

  @override
  String get chatSend => 'Жіберу';

  @override
  String get chatCameraTitle => 'Камерадан түсірілім';

  @override
  String get chatCameraTake => 'Түсіру';

  @override
  String get chatCameraRetake => 'Қайта түсіру';

  @override
  String get chatCameraDevice => 'Камера';

  @override
  String get chatCameraUnavailable =>
      'Камера қолжетімсіз. Қосылғанын және басқа бағдарлама пайдаланбай тұрғанын тексеріңіз.';

  @override
  String get chatAttach => 'Тіркеу';

  @override
  String get chatVoiceHold => 'Жазу үшін басып тұрыңыз';

  @override
  String get chatVoiceSlideCancel => '← Болдырмау үшін сырғытыңыз';

  @override
  String get chatVoiceLocked => 'Жазылуда';

  @override
  String get chatVoiceCancel => 'Болдырмау';

  @override
  String get chatVoicePreview => 'Дауыстық хабарлама';

  @override
  String get chatMicDenied =>
      'Микрофонға рұқсат жоқ. Оған баптауларда рұқсат беріңіз.';

  @override
  String get chatVoiceStartFailed =>
      'Жазуды бастау мүмкін болмады. Микрофонды тексеріңіз.';

  @override
  String get chatVoiceSendFailed =>
      'Жазбаны аяқтау мүмкін болмады. Қайталап көріңіз.';

  @override
  String get chatOpenSettings => 'Баптауларды ашу';

  @override
  String get chatReply => 'Жауап беру';

  @override
  String get chatForward => 'Қайта жіберу';

  @override
  String get chatCopy => 'Көшіру';

  @override
  String get chatEdit => 'Өзгерту';

  @override
  String get chatDelete => 'Жою';

  @override
  String get chatReact => 'Реакция';

  @override
  String get chatEdited => 'өзгертілді';

  @override
  String get chatDeleted => 'Хабарлама жойылды';

  @override
  String get chatCopied => 'Көшірілді';

  @override
  String get chatForwardTo => 'Қайта жіберу…';

  @override
  String get chatForwarded => 'Қайта жіберілген';

  @override
  String get chatReplyingTo => 'Хабарламаға жауап';

  @override
  String get chatEditing => 'Өңдеу';

  @override
  String get chatPending => 'Жіберілуде…';

  @override
  String get chatFailed => 'Жіберілмеді';

  @override
  String get chatRetry => 'Қайталау';

  @override
  String get chatDiscard => 'Кезектен алып тастау';

  @override
  String get chatStatusSent => 'Жіберілді';

  @override
  String get chatStatusDelivered => 'Жеткізілді';

  @override
  String get chatStatusRead => 'Оқылды';

  @override
  String get chatAttachmentImage => 'Фото';

  @override
  String get chatAttachmentVideo => 'Бейне';

  @override
  String get chatAttachmentVoice => 'Дауыстық хабарлама';

  @override
  String get chatAttachmentAudio => 'Аудио';

  @override
  String get chatAttachmentFile => 'Файл';

  @override
  String get chatFileOpen => 'Ашу';

  @override
  String get chatFileDownloading => 'Жүктелуде…';

  @override
  String chatSystemMemberAdded(String actor, String user) {
    return '$actor қатысушы қосты: $user';
  }

  @override
  String chatSystemMemberRemoved(String actor, String user) {
    return '$actor қатысушыны шығарды: $user';
  }

  @override
  String chatSystemMemberLeft(String user) {
    return '$user чаттан шықты';
  }

  @override
  String chatSystemTitleChanged(String actor, String title) {
    return '$actor чат атауын өзгертті: $title';
  }

  @override
  String get chatSystemGeneric => 'Қызметтік хабарлама';

  @override
  String get chatInfo => 'Ақпарат';

  @override
  String get chatMembers => 'Қатысушылар';

  @override
  String get chatAddMember => 'Қатысушы қосу';

  @override
  String get chatRemoveMember => 'Топтан шығару';

  @override
  String get chatLeave => 'Топтан шығу';

  @override
  String get chatLeaveConfirm =>
      'Бұдан былай бұл топтың хабарламаларын алмайсыз.';

  @override
  String get chatRename => 'Атауын өзгерту';

  @override
  String get chatRoleOwner => 'иесі';

  @override
  String get chatRoleAdmin => 'әкімші';

  @override
  String get chatRoleMember => 'қатысушы';

  @override
  String get chatMakeAdmin => 'Әкімші ету';

  @override
  String get chatMute => 'Дыбыссыз';

  @override
  String get chatMuteHour => '1 сағатқа';

  @override
  String get chatMuteDay => '24 сағатқа';

  @override
  String get chatMuteForever => 'Біржола';

  @override
  String get chatUnmute => 'Дыбысты қосу';

  @override
  String get chatPin => 'Бекіту';

  @override
  String get chatUnpin => 'Бекітуден алу';

  @override
  String get chatArchive => 'Мұрағатқа';

  @override
  String get chatUnarchive => 'Мұрағаттан шығару';

  @override
  String get chatArchived => 'Мұрағат';

  @override
  String get chatPinnedMessage => 'Бекітілген хабарлама';

  @override
  String get chatPinMessage => 'Хабарламаны бекіту';

  @override
  String get chatUnpinMessage => 'Хабарламаны бекітуден алу';

  @override
  String get chatLoadOlder => 'Ертеректерін жүктеу';

  @override
  String get chatNoMessages => 'Әзірге хабарламалар жоқ';

  @override
  String get chatToday => 'Бүгін';

  @override
  String get chatYesterday => 'Кеше';

  @override
  String get chatPrivacySection => 'Чат құпиялылығы';

  @override
  String get chatPrivacyLastSeen => '«Соңғы рет желіде болған» уақытты көрсету';

  @override
  String get chatPrivacyOnline => '«Желіде» күйін көрсету';

  @override
  String get chatPrivacyReadReceipts => 'Оқылғаны туралы белгілерді жіберу';

  @override
  String get chatPrivacyPushPreview => 'Хабарландыруларда мәтінді көрсету';

  @override
  String chatCacheStats(int chats, int messages, int outbox) {
    return 'Чаттар: $chats, кэштегі хабарламалар: $messages, кезекте: $outbox';
  }

  @override
  String get chatMentionHint => 'Атап өту';

  @override
  String get chatRateLimited => 'Хабарламалар тым көп. Біраз күте тұрыңыз.';

  @override
  String get chatFileTooLarge => 'Файл тым үлкен.';

  @override
  String get chatFileTypeForbidden => 'Мұндай файл түрін жіберуге болмайды.';

  @override
  String get chatFileInfected => 'Файлды антивирус қабылдамады.';

  @override
  String get chatAvUnavailable =>
      'Антивирус қолжетімсіз, кейінірек қайталап көріңіз.';

  @override
  String get chatMessageTooLong => 'Хабарлама тым ұзын.';

  @override
  String get chatConversationGone => 'Чат қолжетімсіз.';

  @override
  String get calendarTitle => 'Күнтізбе';

  @override
  String get calendarToday => 'Бүгін';

  @override
  String get calendarViewMonth => 'Ай';

  @override
  String get calendarViewWeek => 'Апта';

  @override
  String get calendarViewDay => 'Күн';

  @override
  String get calendarViewAgenda => 'Тізім';

  @override
  String get calendarNoEvents => 'Оқиғалар жоқ';

  @override
  String get calendarNoEventsDay => 'Бұл күні оқиғалар жоқ';

  @override
  String get calendarAllDay => 'Күні бойы';

  @override
  String get calendarOfflineCached =>
      'Желі жоқ — сақталған күнтізбе көрсетілген';

  @override
  String get calendarOfflineEmpty => 'Желі жоқ, ал бұл кезең әлі жүктелмеген';

  @override
  String get calendarNoAccess => 'Күнтізбеге қолжетімділігіңіз жоқ.';

  @override
  String get calendarNewEvent => 'Жаңа оқиға';

  @override
  String get calendarEditEvent => 'Оқиғаны өзгерту';

  @override
  String get calendarSearch => 'Оқиғалардан іздеу';

  @override
  String get calendarSearchHint => 'Атауы, орны, ұйымдастырушы';

  @override
  String get calendarSearchEmpty => 'Ештеңе табылмады';

  @override
  String get calendarSearchCachedOnly =>
      'Іздеу күнтізбенің жүктелген айлары бойынша жүргізіледі.';

  @override
  String get calendarInvitations => 'Шақырулар';

  @override
  String get calendarInvitationsEmpty => 'Жаңа шақырулар жоқ';

  @override
  String get calendarPendingSync => 'Жіберуді күтуде';

  @override
  String get calendarSyncing => 'Жаңартылуда…';

  @override
  String get calendarFieldTitle => 'Атауы';

  @override
  String get calendarFieldTitleRequired => 'Атауын енгізіңіз';

  @override
  String get calendarFieldTitleTooLong => 'Атауы тым ұзын';

  @override
  String get calendarFieldStart => 'Басталуы';

  @override
  String get calendarFieldEnd => 'Аяқталуы';

  @override
  String get calendarFieldEndBeforeStart =>
      'Аяқталуы басталуынан кейін болуы керек';

  @override
  String get calendarFieldTimezone => 'Уақыт белдеуі';

  @override
  String get calendarFieldLocation => 'Орны';

  @override
  String get calendarFieldLink => 'Кездесу сілтемесі';

  @override
  String get calendarFieldLinkInvalid => 'https://… түріндегі сілтеме қажет';

  @override
  String get calendarFieldDescription => 'Сипаттама';

  @override
  String get calendarFieldCategory => 'Санат';

  @override
  String get calendarFieldPrivate => 'Жеке: сипаттаманы тек сіз көресіз';

  @override
  String get calendarFieldRepeat => 'Қайталану';

  @override
  String get calendarFieldReminders => 'Еске салғыштар';

  @override
  String get calendarFieldParticipants => 'Қатысушылар';

  @override
  String get calendarAddParticipant => 'Қатысушы қосу';

  @override
  String get calendarAddReminder => 'Қосу';

  @override
  String get calendarExternalEmailHint => 'Сыртқы қатысушының email-і';

  @override
  String get calendarExternalEmailInvalid => 'Email дұрыс емес';

  @override
  String get calendarParticipantsUnavailable =>
      'Әріптестер анықтамалығы қолжетімсіз: чат модулі өшірулі.';

  @override
  String get calendarParticipantsOffline =>
      'Қатысушылар желі пайда болғанда жүктеледі.';

  @override
  String get calendarSearchColleagues =>
      'Әріптестерді аты немесе email бойынша іздеу';

  @override
  String get calendarCategoryPersonal => 'Жеке';

  @override
  String get calendarCategoryMeeting => 'Кездесу';

  @override
  String get calendarCategoryDepartment => 'Бөлім';

  @override
  String get calendarCategoryOrganization => 'Ұйым';

  @override
  String get calendarExternal => 'сыртқы қатысушы';

  @override
  String get calendarRepeatNone => 'Қайталамау';

  @override
  String get calendarRepeatDaily => 'Күн сайын';

  @override
  String get calendarRepeatWeekly => 'Апта сайын';

  @override
  String get calendarRepeatMonthly => 'Ай сайын';

  @override
  String get calendarRepeatYearly => 'Жыл сайын';

  @override
  String calendarRepeatEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Әр $count күн сайын',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Әр $count апта сайын',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Әр $count ай сайын',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatEveryYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Әр $count жыл сайын',
    );
    return '$_temp0';
  }

  @override
  String get calendarRepeatInterval => 'Аралық';

  @override
  String get calendarRepeatEnds => 'Қайталанудың аяқталуы';

  @override
  String get calendarRepeatEndsNever => 'Ешқашан';

  @override
  String get calendarRepeatEndsOn => 'Белгілі күнге дейін';

  @override
  String get calendarRepeatEndsAfter => 'Бірнеше қайталанудан кейін';

  @override
  String calendarRepeatUntil(String date) {
    return '$date дейін';
  }

  @override
  String calendarRepeatTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count рет',
    );
    return '$_temp0';
  }

  @override
  String get calendarRepeatCustom => 'Ерекше қайталану ережесі';

  @override
  String get calendarRepeatServerNote =>
      'Сервер серияның аяқталуын сақтайды, бірақ веб-пошта әзірге мұндай серияларды шексіз етіп көрсетеді.';

  @override
  String get calendarDone => 'Дайын';

  @override
  String get calendarReminderAtStart => 'Басталған сәтте';

  @override
  String calendarReminderMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count минут бұрын',
    );
    return '$_temp0';
  }

  @override
  String calendarReminderHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сағат бұрын',
    );
    return '$_temp0';
  }

  @override
  String calendarReminderDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count күн бұрын',
    );
    return '$_temp0';
  }

  @override
  String get calendarReminderLocalNote =>
      'Бірінші еске салғышты қатысушылар да алады; қалғандары тек осы құрылғыда іске қосылады.';

  @override
  String get calendarReminderChannel => 'Күнтізбе еске салғыштары';

  @override
  String get calendarReminderChannelDescription =>
      'Оқиғалар басталар алдындағы хабарландырулар';

  @override
  String calendarOrganizer(String name) {
    return 'Ұйымдастырушы: $name';
  }

  @override
  String get calendarYourAnswer => 'Сіздің жауабыңыз';

  @override
  String get calendarRsvpAccept => 'Барамын';

  @override
  String get calendarRsvpTentative => 'Мүмкін';

  @override
  String get calendarRsvpDecline => 'Бармаймын';

  @override
  String get calendarRsvpPending => 'Жауап бермеді';

  @override
  String get calendarRsvpAccepted => 'Қабылдады';

  @override
  String get calendarRsvpTentativeStatus => 'Нақты емес';

  @override
  String get calendarRsvpDeclined => 'Бас тартты';

  @override
  String calendarRsvpSummary(
    int accepted,
    int tentative,
    int declined,
    int pending,
  ) {
    return 'Барады: $accepted · Нақты емес: $tentative · Бас тартты: $declined · Жауап бермеді: $pending';
  }

  @override
  String get calendarMandatory => 'Міндетті оқиға';

  @override
  String get calendarMandatoryCannotDecline =>
      'Міндетті оқиғадан бас тартуға болмайды.';

  @override
  String get calendarJoinCall => 'Қоңырауға қосылу';

  @override
  String get calendarJoinCallSoon =>
      'Күнтізбеден қоңырауға қосылу мүмкіндігі қоңыраулар модулімен бірге қосылады.';

  @override
  String calendarEventTimeInZone(String time, String zone) {
    return '$zone уақытымен $time';
  }

  @override
  String get calendarDelete => 'Жою';

  @override
  String get calendarEdit => 'Өзгерту';

  @override
  String get calendarSave => 'Сақтау';

  @override
  String get calendarDeleteConfirm =>
      'Оқиғаны жою керек пе? Қатысушыларға оның тоқтатылғаны туралы хабарланады.';

  @override
  String get calendarScopeTitleEdit => 'Қайталанатын оқиғаны өзгерту';

  @override
  String get calendarScopeTitleDelete => 'Қайталанатын оқиғаны жою';

  @override
  String get calendarScopeThis => 'Тек осы оқиға';

  @override
  String get calendarScopeFollowing => 'Осы және келесі оқиғалар';

  @override
  String get calendarScopeAll => 'Серияның барлық оқиғалары';

  @override
  String get calendarRecreateWarning =>
      'Бұл өзгерісті бар оқиғаға енгізу мүмкін емес: ол тоқтатылып, қайта құрылады, ал қатысушылар жаңа шақыру алады.';

  @override
  String get calendarContinue => 'Жалғастыру';

  @override
  String get calendarEventNotFound => 'Оқиға табылмады немесе қолжетімсіз.';

  @override
  String get calendarNotOrganizer => 'Оқиғаны тек ұйымдастырушы өзгерте алады.';

  @override
  String get calendarCancelled => 'Тоқтатылды';

  @override
  String calendarProblemsBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count өзгеріс жіберілмеді',
    );
    return '$_temp0';
  }

  @override
  String get calendarConflictTitle => 'Оқиға басқа құрылғыда өзгертілді';

  @override
  String get calendarConflictBody =>
      'Өзгерістеріңізді жаңа нұсқаның үстінен қолдану керек пе, әлде олардан бас тарту керек пе?';

  @override
  String get calendarConflictOverwrite => 'Менікін қолдану';

  @override
  String get calendarDiscard => 'Өзгерістерден бас тарту';

  @override
  String calendarProblemFailed(String reason) {
    return 'Өзгеріс қабылданбады: $reason';
  }

  @override
  String get calendarErrTitle =>
      'Атауы бос немесе тым ұзын (ең көбі 300 байт).';

  @override
  String get calendarErrTime => 'Басталу және аяқталу уақытын тексеріңіз.';

  @override
  String get calendarErrLink =>
      'Кездесу сілтемесі https:// деп басталуы керек.';

  @override
  String get calendarErrTimezone => 'Белгісіз уақыт белдеуі.';

  @override
  String get calendarErrAudience =>
      'Кейбір қатысушылар сіздің ұйымыңыздан емес.';

  @override
  String get calendarErrRoom => 'Бұл уақытта мәжіліс бөлмесі бос емес.';

  @override
  String get calendarErrMeetingsDisabled =>
      'Ұйымда қатысушылармен кездесу құру өшірілген.';

  @override
  String get calendarErrTooManyOccurrences =>
      'Серияда қайталанулар тым көп: сервер серияны аяқтай алмайды, сондықтан «осы және келесі оқиғалар» қолжетімсіз. Серияны толығымен немесе жекелеген оқиғаларды жойыңыз.';

  @override
  String get calendarErrOffline =>
      'Желі қажет: серия деректері әлі жүктелмеген.';

  @override
  String get calendarErrSending =>
      'Оқиға жіберілуде — бір минуттан кейін қайталап көріңіз.';

  @override
  String get calendarErrScope =>
      'Бұл өзгерісті серияның жалғыз оқиғасына қолдану мүмкін емес.';

  @override
  String get calendarErrOverride =>
      'Сервер ауыстырылған оқиғаны қайтармады — күнтізбені жаңартыңыз.';

  @override
  String get callsFilterAll => 'Барлығы';

  @override
  String get callsFilterMissed => 'Қабылданбаған';

  @override
  String get callsEmpty => 'Әзірге қоңыраулар жоқ';

  @override
  String get callsMissedEmpty => 'Қабылданбаған қоңыраулар жоқ';

  @override
  String get callsNew => 'Жаңа қоңырау';

  @override
  String get callsAudio => 'Аудиоқоңырау';

  @override
  String get callsVideo => 'Бейнеқоңырау';

  @override
  String get callsDisabled =>
      'Қоңыраулар қолжетімсіз: қоңырау қызметі бапталмаған.';

  @override
  String get callsIncoming => 'Кіріс қоңырау';

  @override
  String get callsIncomingVideo => 'Кіріс бейнеқоңырау';

  @override
  String get callsCalling => 'Қоңырау шалынуда…';

  @override
  String get callsConnecting => 'Қосылуда…';

  @override
  String get callsReconnecting => 'Байланыс қалпына келтірілуде…';

  @override
  String get callsAccept => 'Жауап беру';

  @override
  String get callsDecline => 'Қабылдамау';

  @override
  String get callsHangUp => 'Аяқтау';

  @override
  String get callsEndForAll => 'Барлығы үшін аяқтау';

  @override
  String get callsLeave => 'Қоңыраудан шығу';

  @override
  String get callsMic => 'Микрофон';

  @override
  String get callsCamera => 'Камера';

  @override
  String get callsSwitchCamera => 'Камераны ауыстыру';

  @override
  String get callsCameraUnavailable => 'Камераны қосу мүмкін болмады';

  @override
  String get callsSpeaker => 'Динамик';

  @override
  String get callsAudioOutput => 'Аудио шығысы';

  @override
  String get callsAudioSettings => 'Дыбыс';

  @override
  String get callsAudioEarpiece => 'Телефон (құлаққа)';

  @override
  String get callsAudioWired => 'Сымды құлаққап';

  @override
  String get callsAudioBluetooth => 'Bluetooth';

  @override
  String get callsScreenShare => 'Экран';

  @override
  String get callsScreenShareRefused => 'Экранды көрсетуге рұқсат берілмеді.';

  @override
  String get callsScreenShareNotification => 'XatBox экранды көрсетіп жатыр';

  @override
  String get callsParticipants => 'Қатысушылар';

  @override
  String get callsModMute => 'Микрофонды өшіру';

  @override
  String get callsModRemove => 'Қоңыраудан шығару';

  @override
  String get callsMakeModerator => 'Модератор ету';

  @override
  String get callsHost => 'ұйымдастырушы';

  @override
  String get callsModerator => 'модератор';

  @override
  String get callsYou => 'Сіз';

  @override
  String get callsRedial => 'Қайта қоңырау шалу';

  @override
  String get callsEndedHangup => 'Қоңырау аяқталды';

  @override
  String get callsEndedDeclined => 'Қоңыраудан бас тартылды';

  @override
  String get callsEndedBusy => 'Абонент бос емес';

  @override
  String get callsEndedMissed => 'Жауап жоқ';

  @override
  String get callsEndedCancelled => 'Қоңырау болдырылмады';

  @override
  String get callsEndedFailed => 'Қосылу мүмкін болмады';

  @override
  String get callsEndedNetwork => 'Желі жоқ — қоңырау шалу мүмкін емес';

  @override
  String get callsEndedElsewhere => 'Басқа құрылғыда жауап берілді';

  @override
  String get callsEndedRemoved => 'Модератор сізді қоңыраудан шығарды';

  @override
  String get callsPermissionNeeded =>
      'Микрофонға рұқсатсыз қоңырау шалу мүмкін емес (бейнеқоңырауға камера да қажет). Қоңырау шалу үшін рұқсат беріңіз.';

  @override
  String get callsQualityPoor => 'Байланыс әлсіз';

  @override
  String get callsQualityLost => 'Байланыс үзілді';

  @override
  String get callsOutcomeMissed => 'Қабылданбаған';

  @override
  String get callsOutcomeDeclined => 'Бас тартылған';

  @override
  String get callsOutcomeCancelled => 'Болдырылмаған';

  @override
  String get callsOutcomeBusy => 'Бос емес';

  @override
  String get callsOutcomeFailed => 'Сәтсіз';

  @override
  String get callsOutgoing => 'Шығыс';

  @override
  String get callsIncomingShort => 'Кіріс';

  @override
  String get callsActiveBanner => 'Қоңырау жүріп жатыр — оралу үшін түртіңіз';

  @override
  String get callsIncomingChannel => 'Кіріс қоңыраулар';

  @override
  String get callsMissedChannel => 'Қабылданбаған қоңыраулар';

  @override
  String get callsSelectPeople =>
      'Бір әріптесті немесе топтық қоңырау үшін бірнешеуін таңдаңыз';

  @override
  String callsParticipantsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count қатысушы',
    );
    return '$_temp0';
  }

  @override
  String get callsErrNotModerator => 'Бұл әрекет тек модераторға қолжетімді.';

  @override
  String get callsErrAlreadyInCall => 'Сіз басқа қоңырауға қатысып жатырсыз.';

  @override
  String get callsErrTooMany => 'Қоңырау үшін қатысушылар тым көп.';

  @override
  String get callsErrInvalidParticipants =>
      'Кейбір қатысушыларға қоңырау шалу мүмкін емес.';

  @override
  String get callsErrRateLimited =>
      'Қатарынан тым көп қоңырау шалынды. Біраз күте тұрыңыз.';

  @override
  String get appOfflineBanner => 'Желіге қосылым жоқ';

  @override
  String appSizeBytes(String value) {
    return '$value Б';
  }

  @override
  String appSizeKb(String value) {
    return '$value КБ';
  }

  @override
  String appSizeMb(String value) {
    return '$value МБ';
  }

  @override
  String appSizeGb(String value) {
    return '$value ГБ';
  }

  @override
  String get settingsAppearanceSection => 'Сыртқы түрі';

  @override
  String get settingsTheme => 'Тақырып';

  @override
  String get settingsThemeSystem => 'Жүйедегідей';

  @override
  String get settingsThemeLight => 'Ашық';

  @override
  String get settingsThemeDark => 'Қараңғы';

  @override
  String get settingsLanguage => 'Тіл';

  @override
  String get settingsLanguageSystem => 'Жүйедегідей';

  @override
  String get settingsLanguageRu => 'Русский';

  @override
  String get settingsLanguageKk => 'Қазақша';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get mailSortSender => 'Жіберушіге қалта';

  @override
  String mailSortSenderHint(String sender) {
    return '$sender хаттары таңдалған қалтаға жиналады.';
  }

  @override
  String get mailSortSenderIncludeExisting => 'Бұрын келген хаттарды да көшіру';

  @override
  String mailSenderSorted(String name) {
    return 'Жіберуші «$name» қалтасына қосылды';
  }

  @override
  String get mailSortSenderNoFolders =>
      'Алдымен «Кіріс» ішінде ақылды қалта құрыңыз.';

  @override
  String get settingsSecurityChangePassword => 'Құпиясөзді өзгерту';

  @override
  String get settingsSecurityChangePasswordHint =>
      'Кемінде 10 таңба. Өзгерткеннен кейін басқа сессиялар жұмыс істей береді — қажет болса, төменде аяқтаңыз.';

  @override
  String get settingsCurrentPassword => 'Ағымдағы құпиясөз';

  @override
  String get settingsNewPassword => 'Жаңа құпиясөз (кемінде 10 таңба)';

  @override
  String get settingsRepeatPassword => 'Жаңа құпиясөзді қайталаңыз';

  @override
  String get settingsPasswordsMismatch => 'Құпиясөздер сәйкес емес';

  @override
  String get settingsPasswordChanged => 'Құпиясөз өзгертілді';

  @override
  String get settingsPasswordTooShort => 'Кемінде 10 таңба';

  @override
  String get mailSettingsClients => 'Пошта клиенттері';

  @override
  String get mailSettingsClientsSubtitle =>
      'Outlook, Thunderbird және басқалар үшін IMAP/SMTP';

  @override
  String get mailClientsHint =>
      'Үшінші тарап пошта бағдарламалары үшін қосылу параметрлері.';

  @override
  String get mailClientsIncoming => 'Кіріс · IMAP';

  @override
  String get mailClientsOutgoing => 'Шығыс · SMTP';

  @override
  String get mailClientsUsername => 'Пайдаланушы аты';

  @override
  String get mailClientsDisabled => 'IMAP/SMTP қолжетімділігін әкімші өшірген.';

  @override
  String get mailClientsEnabled => 'Қосулы';

  @override
  String get mailClientsDisabledBadge => 'Өшірулі';

  @override
  String get profileChangePhoto => 'Фотоны өзгерту';

  @override
  String get profileRemovePhoto => 'Фотоны жою';

  @override
  String get profilePhotoUpdated => 'Фото жаңартылды';

  @override
  String get profilePhotoHint =>
      'Фотоны әріптестер поштада, чатта және каталогта көреді.';

  @override
  String get profileRole => 'Рөл';

  @override
  String get profileAdministrator => 'Әкімші';

  @override
  String get profileMember => 'Қызметкер';

  @override
  String mailQuickReplyTo(String name) {
    return 'Жауап: $name';
  }

  @override
  String mailQuickReplyAll(int count) {
    return 'Барлығына жауап · $count';
  }

  @override
  String get mailQuickReplyHint => 'Жауап жазыңыз…';

  @override
  String get mailQuickReplySent => 'Жауап жіберілді';

  @override
  String get mailQuickReplyOpenComposer => 'Редакторда ашу';

  @override
  String get mailQuickReplyAnother => 'Тағы жазу';

  @override
  String get mailQuickReplyViewSent => 'Жіберілгендерге';

  @override
  String get mailQuickReplySwitchAll => 'Барлығына';

  @override
  String get mailQuickReplySwitchOne => 'Тек жіберушіге';

  @override
  String get mailRemindMe => 'Еске салу';

  @override
  String get mailRemindLaterToday => 'Бүгін кейінірек';

  @override
  String get mailRemindTomorrow => 'Ертең таңертең';

  @override
  String get mailRemindNextWeek => 'Келесі аптада';

  @override
  String get mailReminderCreated => 'Еске салғыш құрылды';

  @override
  String get mailAddToTasks => 'Тапсырмаларға';

  @override
  String get mailAddedToTasks => 'Тапсырма құрылды';

  @override
  String get mailHideList => 'Тізімді жасыру';

  @override
  String get mailShowList => 'Тізімді көрсету';

  @override
  String get mailMoveToInbox => 'Кіріске жылжыту';

  @override
  String get mailExternalSender => 'Сыртқы жіберуші';

  @override
  String mailRecipientsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count алушы',
      one: '$count алушы',
    );
    return '$_temp0';
  }

  @override
  String get mailConversation => 'Хат алмасу';

  @override
  String get mailConversationHistory => 'хат алмасу тарихы';

  @override
  String mailThreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count хабарлама',
      one: '$count хабарлама',
    );
    return '$_temp0';
  }

  @override
  String get mailLookalikeWarning =>
      'Жіберушінің домені сіздікіне ұқсас, бірақ басқа. Бұл жалған болуы мүмкін — жауап бермес бұрын мекенжайды тексеріңіз.';

  @override
  String mailAttachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count тіркеме',
      one: '$count тіркеме',
    );
    return '$_temp0';
  }

  @override
  String get mailOpenMessage => 'Хатты ашу';

  @override
  String get mailRoleStart => 'Басы';

  @override
  String get mailRoleReply => 'Жауап';

  @override
  String get mailRoleLatest => 'Соңғысы';

  @override
  String get mailRoleCurrent => 'Осы хат';

  @override
  String get mailEditSend => 'Өңдеу және жіберу';

  @override
  String get mailCopyAddress => 'Мекенжайды көшіру';

  @override
  String get mailAddressCopied => 'Мекенжай көшірілді';

  @override
  String get mailSaveToBookmarkFolder => 'Бетбелгі қалтасына сақтау';

  @override
  String get mailCreateBookmarkFolderFirst =>
      'Алдымен бетбелгі қалтасын құрыңыз';

  @override
  String mailSavedToFolder(String name) {
    return '«$name» қалтасына сақталды';
  }

  @override
  String get mailMoreActions => 'Тағы';

  @override
  String get mailDownload => 'Жүктеу';

  @override
  String get mailPreview => 'Ашу';

  @override
  String get mailRefresh => 'Поштаны жаңарту';

  @override
  String get mailRefreshed => 'Пошта жаңартылды';

  @override
  String get mailNewFolder => 'Жаңа қалта';

  @override
  String get mailCreateFirstFolder => 'Алғашқы қалтаны құру';

  @override
  String get mailNewBookmarkFolder => 'Жаңа бетбелгі қалтасы';

  @override
  String get mailCreateFirstBookmarkFolder => 'Бетбелгі қалтасын құру';

  @override
  String get mailFolderName => 'Қалта атауы';

  @override
  String get mailFolderNameHint => 'Мысалы: Бухгалтерия';

  @override
  String get mailFolderModalHint =>
      'Ақылды қалта таңдалған жіберушілердің хаттарын жинайды.';

  @override
  String get mailBookmarkModalHint =>
      'Бетбелгі қалтасы сіз белгілеген хаттарды сақтайды.';

  @override
  String get mailFolderCreated => 'Қалта құрылды';

  @override
  String get mailBookmarkFolderCreated => 'Бетбелгі қалтасы құрылды';

  @override
  String get mailCreating => 'Құрылуда…';

  @override
  String get sectionMail => 'Пошта';

  @override
  String get sectionWorkspace => 'Жұмыс орны';

  @override
  String get mailSelectAll => 'Барлығын таңдау';

  @override
  String get mailSelectMessage => 'Хатты таңдау';

  @override
  String mailSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count хат таңдалды',
      one: '$count хат таңдалды',
    );
    return '$_temp0';
  }

  @override
  String get mailUndo => 'Болдырмау';

  @override
  String get mailThreadYou => 'Сіз';

  @override
  String get mailReplyBadge => 'Жауап';

  @override
  String mailMessagesTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count хат',
      one: '$count хат',
    );
    return '$_temp0';
  }

  @override
  String mailSendersTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count жіберуші',
      one: '$count жіберуші',
    );
    return '$_temp0';
  }

  @override
  String get mailUnreadLabel => 'оқылмаған';

  @override
  String get mailBackToAccounts => 'Жіберушілерге';

  @override
  String get mailSelectAccount => 'Жіберушіні таңдаңыз';

  @override
  String get mailSelectAccountHint => 'Жіберушінің хаттары осында көрсетіледі.';

  @override
  String get mailExpandInbox => 'Кіріс қалталарын жаю';

  @override
  String get mailCollapseInbox => 'Кіріс қалталарын жию';

  @override
  String get mailCouldNotCreateFolder => 'Қалтаны құру мүмкін болмады';

  @override
  String get mailDeleteSelected => 'Жою';

  @override
  String get mailBookmarkSelected => 'Бетбелгіге';

  @override
  String get mailMarkReadSelected => 'Оқылды';

  @override
  String get mailMarkUnreadSelected => 'Оқылмады';

  @override
  String get mailSpamSelected => 'Спамға';

  @override
  String get mailNotSpamSelected => 'Спам емес';

  @override
  String mailDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count хат жойылды',
      one: '$count хат жойылды',
    );
    return '$_temp0';
  }

  @override
  String mailMovedToSpamCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count хат спамға жіберілді',
      one: '$count хат спамға жіберілді',
    );
    return '$_temp0';
  }

  @override
  String mailRestoredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count хат «Кіріс» қалтасына қайтарылды',
      one: '$count хат «Кіріс» қалтасына қайтарылды',
    );
    return '$_temp0';
  }

  @override
  String mailMarkedReadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count хат оқылды деп белгіленді',
      one: '$count хат оқылды деп белгіленді',
    );
    return '$_temp0';
  }

  @override
  String mailMarkedUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count хат оқылмады деп белгіленді',
      one: '$count хат оқылмады деп белгіленді',
    );
    return '$_temp0';
  }

  @override
  String mailBookmarkedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count хат бетбелгіге қосылды',
      one: '$count хат бетбелгіге қосылды',
    );
    return '$_temp0';
  }

  @override
  String get settingsStyle => 'Стиль';

  @override
  String get settingsStyleHint =>
      'Бүкіл қосымшаның көрінісін таңдаңыз. Мәтін өлшемі мен тығыздық оның үстінен қолданылады.';

  @override
  String get settingsStyleApplied => 'Стиль қолданылды';

  @override
  String get settingsTextSize => 'Мәтін өлшемі';

  @override
  String get settingsTextSizeSmall => 'Кіші';

  @override
  String get settingsTextSizeMedium => 'Қалыпты';

  @override
  String get settingsTextSizeLarge => 'Үлкен';

  @override
  String get settingsListDensity => 'Тізім тығыздығы';

  @override
  String get settingsDensityCompact => 'Тығыз';

  @override
  String get settingsDensityNormal => 'Қалыпты';

  @override
  String get settingsDensitySpacious => 'Кең';

  @override
  String get settingsAppearanceHint =>
      'Өзіңізге ыңғайлы мәтін өлшемі мен тізім тығыздығын таңдаңыз. Баптау осы құрылғыда сақталады.';

  @override
  String get skinStandard => 'Стандарт';

  @override
  String get skinStandardHint => 'Байсалды классика, ақ немесе қараңғы';

  @override
  String get skinSteppe => 'Дала';

  @override
  String get skinSteppeHint => 'Жылы құм мен терракота';

  @override
  String get skinPaper => 'Қағаз';

  @override
  String get skinPaperHint => 'Крем қағаз, сия және антиква';

  @override
  String get skinGraphite => 'Графит';

  @override
  String get skinGraphiteHint => 'Қараңғы, моноширинді, кәріптас екпін';

  @override
  String get skinKok => 'Көк';

  @override
  String get skinKokHint => 'Көгілдір мен алтын, қараңғы мәзір';

  @override
  String get skinMidnight => 'Түн ортасы';

  @override
  String get skinMidnightHint => 'Терең индиго, сирень екпін';

  @override
  String get skinTerminal => 'Терминал';

  @override
  String get skinTerminalHint => 'Жасыл фосфор, барлық мәтін моноширинді';

  @override
  String get skinLilac => 'Сирень';

  @override
  String get skinLilacHint => 'Лаванда фон, қара өрік, брусок қаріп';

  @override
  String get skinContrast => 'Контраст';

  @override
  String get skinContrastHint => 'Аққа қара, 2px жиек — нашар көретіндерге';

  @override
  String get skinForest => 'Орман';

  @override
  String get skinForestHint => 'Қарағай қараңғысы, мүк екпін';

  @override
  String get settingsSecuritySection => 'Қауіпсіздік';

  @override
  String get settingsLockPin => 'PIN-код арқылы кіру';

  @override
  String get settingsLockPinHint => 'Қолданбаны ашқанда PIN-кодты сұрау';

  @override
  String get settingsLockChangePin => 'PIN-кодты өзгерту';

  @override
  String get settingsLockBiometric => 'Биометрия арқылы құлыпты ашу';

  @override
  String get settingsLockTimeout => 'Құлыптау';

  @override
  String get settingsLockOnClose => 'Терезені жапқанда PIN сұрау';

  @override
  String get settingsLockOnCloseHint =>
      'Крестик XatBox-ты трейге жасырады; терезе қайта ашылғанда PIN-код сұралады';

  @override
  String get settingsLockTimeoutImmediately =>
      'Қолданбаны жиғаннан кейін бірден';

  @override
  String settingsLockTimeoutMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes минуттан кейін',
    );
    return '$_temp0';
  }

  @override
  String get settingsHideContent => 'Қолданбалар тізімінде мазмұнды жасыру';

  @override
  String get settingsHideContentHint =>
      'Android-те скриншот түсіруге де тыйым салады';

  @override
  String settingsStorageUsed(String size) {
    return 'Құрылғыда пайдаланылған: $size';
  }

  @override
  String get lockTitle => 'PIN-кодты енгізіңіз';

  @override
  String lockWrong(int attempts) {
    String _temp0 = intl.Intl.pluralLogic(
      attempts,
      locale: localeName,
      other: 'PIN-код қате. $attempts әрекет қалды',
    );
    return '$_temp0';
  }

  @override
  String lockThrottled(int seconds) {
    return 'Әрекеттер тым көп. $seconds с кейін қайталаңыз';
  }

  @override
  String get lockBiometric => 'Биометрия арқылы ашу';

  @override
  String get lockBiometricReason => 'XatBox құлпын ашыңыз';

  @override
  String get lockForgot => 'PIN-кодты ұмыттыңыз ба?';

  @override
  String get lockForgotConfirm =>
      'Тіркелгіден шығу керек пе? Содан кейін құпиясөзбен кіріп, жаңа PIN-код орнатыңыз.';

  @override
  String get lockForgotSignOut => 'Шығу';

  @override
  String get lockDelete => 'Цифрды өшіру';

  @override
  String get lockSetupTitle => 'PIN-код';

  @override
  String get lockSetupEnter => '4–6 цифрдан тұратын PIN-код ойлап табыңыз';

  @override
  String get lockSetupRepeat => 'PIN-кодты қайталаңыз';

  @override
  String get lockSetupMismatch =>
      'PIN-кодтар сәйкес келмейді. Қайталап көріңіз.';

  @override
  String get lockSetupNext => 'Келесі';

  @override
  String get loginShowPassword => 'Құпиясөзді көрсету';

  @override
  String get loginHidePassword => 'Құпиясөзді жасыру';

  @override
  String get callsDetailsTitle => 'Қоңырау';

  @override
  String get callsDetailsType => 'Түрі';

  @override
  String get callsDetailsResult => 'Нәтижесі';

  @override
  String get callsDetailsStarted => 'Басталуы';

  @override
  String get callsDetailsDuration => 'Ұзақтығы';

  @override
  String get callsDetailsNoConversation => 'Сөйлесу болмады';

  @override
  String get callsDetailsMessage => 'Жазу';

  @override
  String get callsModeDirect => 'Жеке';

  @override
  String get callsModeGroup => 'Топтық';

  @override
  String get callsModeConference => 'Конференция';

  @override
  String get callsOutcomeAnswered => 'Жауап берілген';

  @override
  String get callsRoleParticipant => 'қатысушы';

  @override
  String get callsPStatusInvited => 'шақырылды';

  @override
  String get callsPStatusRinging => 'қоңырау түсуде';

  @override
  String get callsPStatusAccepted => 'қабылдады';

  @override
  String get callsPStatusJoined => 'қоңырауда';

  @override
  String get callsPStatusLeft => 'шықты';

  @override
  String get callsPStatusDeclined => 'бас тартты';

  @override
  String get callsPStatusMissed => 'жауап бермеді';

  @override
  String get callsPStatusBusy => 'бос емес';

  @override
  String get callsPStatusRemoved => 'шығарылды';

  @override
  String get callsErrNotFound => 'Қоңырау табылмады.';

  @override
  String get callsInvite => 'Қатысушыларды қосу';

  @override
  String callsInviteSubmit(int count) {
    return 'Шақыру ($count)';
  }

  @override
  String get callsInviteSent => 'Шақырулар жіберілді.';

  @override
  String get callsInviteNobody => 'Табылған әріптестердің барлығы қоңырауда';

  @override
  String get callsMinimize => 'Жию';

  @override
  String get callsReturnToCall => 'Қоңырауға оралу';

  @override
  String get callsMore => 'Тағы';

  @override
  String get callsRaiseHand => 'Қол көтеру';

  @override
  String get callsLowerHand => 'Қолды түсіру';

  @override
  String get callsHandRaised => 'Қол көтерілді';

  @override
  String get callsReactions => 'Реакциялар';

  @override
  String get callsChat => 'Чат';

  @override
  String get callsChatTitle => 'Қоңырау чаты';

  @override
  String get callsChatHint => 'Хабарлама…';

  @override
  String get callsChatSend => 'Жіберу';

  @override
  String get callsChatEmpty =>
      'Хабарламаларды қоңыраудың барлық қатысушылары көреді';

  @override
  String get callsChatEmptyLinked =>
      'Хабарламаларды қоңырау қатысушылары көреді, олар чатта сақталады';

  @override
  String get callsChatFailed => 'Жіберілмеді — қайталау үшін басыңыз';

  @override
  String get callsChatEmoji => 'Эмодзи';

  @override
  String get callsChatClose => 'Чатты жабу';

  @override
  String get callsRecord => 'Жазу';

  @override
  String get callsRecordStop => 'Жазуды тоқтату';

  @override
  String get callsRecordConfirmTitle => 'Қоңырауды жазу керек пе?';

  @override
  String get callsRecordConfirmBody =>
      'Барлық қатысушылар жазу белгісін көреді. Жазба қоңырау карточкасында қатысушыларға қолжетімді болады.';

  @override
  String get callsRecordConfirmStart => 'Жазуды бастау';

  @override
  String get callsRecordingBanner => 'Қоңырау жазылып жатыр';

  @override
  String callsRecordingBannerBy(String name) {
    return 'Жазуды $name қосты';
  }

  @override
  String get callsRecordingStopped => 'Жазу тоқтатылды';

  @override
  String get callsRecordings => 'Жазбалар';

  @override
  String get callsRecordingInProgress => 'Жазу жүріп жатыр';

  @override
  String get callsRecordingFailed => 'Жазу сәтсіз аяқталды';

  @override
  String get callsRecordingVideo => 'Бейнежазба';

  @override
  String get callsRecordingAudio => 'Аудиожазба';

  @override
  String get callsRecordingDownload => 'Жүктеп алу';

  @override
  String get callsRecordingOpen => 'Ашу';

  @override
  String get callsRecordingNoApp => 'Файлды ашатын қолданба жоқ';

  @override
  String get callsRecordingDownloadFailed =>
      'Жазбаны жүктеп алу мүмкін болмады';

  @override
  String get callsErrRecordingUnavailable =>
      'Жазу қазір қолжетімсіз. Кейінірек көріңіз.';

  @override
  String get callsErrRecordingActive => 'Қоңырау жазылып жатыр';

  @override
  String get callsErrRecordingDisabled => 'Қоңырауларды жазу өшірулі';

  @override
  String get callsLayoutGrid => 'Тор';

  @override
  String get callsLayoutSpotlight => 'Спикер';

  @override
  String get callsDeclineWithMessage => 'Хабарламамен қабылдамау';

  @override
  String get callsQuickReplyBusy => 'Қазір сөйлесе алмаймын, кейін жазамын.';

  @override
  String get callsQuickReplyLater =>
      'Бірнеше минуттан кейін қайта қоңырау шаламын.';

  @override
  String get callsQuickReplyMeeting => 'Мен кездесудемін.';

  @override
  String get callsQuickReplySent => 'Хабарлама жіберілді';

  @override
  String get callsMessage => 'Хабарлама';

  @override
  String get callsModMuteCamera => 'Камераны өшіру';

  @override
  String get callsModStopScreenShare => 'Экран көрсетуді тоқтату';

  @override
  String get callsMakeParticipant => 'Қатысушы ету';

  @override
  String get callsRingAgain => 'Қайта шақыру';

  @override
  String get callsRingAgainSent => 'Шақыру жіберілді';

  @override
  String get callsSectionInCall => 'Қоңырауда';

  @override
  String get callsSectionNotInCall => 'Қосылмаған';

  @override
  String get callsClose => 'Жабу';

  @override
  String get callsTitleHint => 'Қоңырау атауы (міндетті емес)';

  @override
  String get meetingsSection => 'Кездесулер';

  @override
  String get meetingsToday => 'Бүгін';

  @override
  String get meetingJoin => 'Қосылу';

  @override
  String get meetingLive => 'Жүріп жатыр';

  @override
  String get meetingOpenNow => 'Қосылуға болады';

  @override
  String meetingOpensAt(String time) {
    return '$time ашылады';
  }

  @override
  String get meetingOpensSoonHint =>
      'Басталуына 10 минут қалғанда қосылуға болады';

  @override
  String get meetingPrejoinTitle => 'Бейнекездесу';

  @override
  String get meetingDevices => 'Құрылғылар';

  @override
  String meetingDeviceMic(String name) {
    return 'Микрофон: $name';
  }

  @override
  String meetingDeviceCamera(String name) {
    return 'Камера: $name';
  }

  @override
  String get meetingDeviceDefault => 'әдепкі';

  @override
  String get meetingDeviceOff => 'өшірулі';

  @override
  String get meetingCameraOff => 'Камера өшірулі';

  @override
  String get meetingPreviewUnavailable => 'Камераны алдын ала көру қолжетімсіз';

  @override
  String get meetingLobbyTitle => 'Растауды күтіңіз';

  @override
  String get meetingLobbyText =>
      'Ұйымдастырушы сұрауыңызды алды, жақында кіргізеді.';

  @override
  String get meetingLobbyDenied => 'Ұйымдастырушы сізді кездесуге кіргізбеді';

  @override
  String get meetingNotStarted => 'Кездесу әлі басталған жоқ';

  @override
  String get meetingEnded => 'Кездесу аяқталды';

  @override
  String get meetingCancelled => 'Кездесу болдырылмады';

  @override
  String get meetingNotFound => 'Кездесу табылмады';

  @override
  String get meetingGuestLinkTitle => 'Бұл қонақ сілтемесі';

  @override
  String get meetingGuestLinkText =>
      'Қонақ сілтемелері браузерде ашылады — тіркелгісі жоқ адамдарға арналған.';

  @override
  String get meetingOpenInBrowser => 'Браузерде ашу';

  @override
  String get meetingPermissionDenied => 'Камераға немесе микрофонға рұқсат жоқ';

  @override
  String get calendarXatBoxMeeting => 'XatBox бейнекездесуін қосу';

  @override
  String get calendarXatBoxMeetingHint => 'Қосылу сілтемесі оқиғаға қосылады';

  @override
  String get calendarXatBoxMeetingAdded => 'XatBox бейнекездесуі қосылды';

  @override
  String get calendarXatBoxMeetingAllDay => 'Күні бойғы оқиғаларға қолжетімсіз';

  @override
  String calendarXatBoxMeetingDescription(String url) {
    return 'XatBox бейнекездесуі: $url';
  }

  @override
  String get calendarXatBoxMeetingFailed => 'Бейнекездесу құру мүмкін болмады';

  @override
  String get calendarMeetingReminderBody =>
      '5 минуттан кейін. «Қосылу» түймесін басыңыз';

  @override
  String callsLobbyWaiting(int count) {
    return 'Күтуде: $count';
  }

  @override
  String get callsLobbyAdmit => 'Кіргізу';

  @override
  String get callsLobbyDeny => 'Қабылдамау';

  @override
  String get callsLobbyStaff => 'Қызметкер';

  @override
  String callsLobbyBanner(int count) {
    return 'Кіруді күтуде: $count';
  }

  @override
  String get callsLobbyOpen => 'Ашу';

  @override
  String get callsGuest => 'Қонақ';

  @override
  String get callsGuestsSection => 'Қонақтар';

  @override
  String get callsGuestInvite => 'Қонақ шақыру';

  @override
  String get callsGuestLinkTitle => 'Қонақ сілтемесі';

  @override
  String get callsGuestLinkHint =>
      'XatBox тіркелгісі жоқ адамдарға: сілтеме браузерде ашылады, қонақты өзіңіз кіргізесіз.';

  @override
  String get callsGuestLinkExpires => 'Жарамдылығы';

  @override
  String get callsGuestLinkHour => '1 сағат';

  @override
  String get callsGuestLinkDay => '1 күн';

  @override
  String get callsGuestLinkWeek => '7 күн';

  @override
  String get callsGuestLinkUses => 'Адам саны';

  @override
  String callsGuestLinkUsesValue(int count) {
    return '$count адамға дейін';
  }

  @override
  String get callsGuestLinkLobby => 'Қолмен кіргізу';

  @override
  String get callsGuestLinkScreen => 'Экранды көрсетуге рұқсат беру';

  @override
  String get callsGuestLinkCreate => 'Сілтеме жасау';

  @override
  String get callsGuestLinkCopy => 'Сілтемені көшіру';

  @override
  String get callsGuestLinkCopied => 'Сілтеме көшірілді';

  @override
  String get callsQualitySettings => 'Сапа';

  @override
  String get callsQualityAudio => 'Дыбысты өңдеу';

  @override
  String get callsQualityVideo => 'Бейне';

  @override
  String get callsNoiseSuppression => 'Шуды басу';

  @override
  String get callsEchoCancellation => 'Жаңғырықты басу';

  @override
  String get callsAutoGain => 'Автокүшейту';

  @override
  String get callsMusicMode => 'Музыка режимі';

  @override
  String get callsMusicModeHint => 'Дауыс сүзгілерінсіз, биттрейт жоғары';

  @override
  String get callsDataSaver => 'Трафик';

  @override
  String get callsDataSaverOff => 'Қалыпты';

  @override
  String get callsDataSaverLow => 'Үнемдеу';

  @override
  String get callsDataSaverAudio => 'Тек дыбыс';

  @override
  String get callsDataSaverHint =>
      '«Үнемдеу» бейнені төмен сапада қабылдайды, «Тек дыбыс» бейнені қабылдамайды және жібермейді.';

  @override
  String get callsBackgroundBlur => 'Фонды бұлыңғырлау';

  @override
  String get callsBackgroundBlurUnavailable =>
      'Мобильді қолданбада әзірге қолжетімсіз';

  @override
  String get callsPoorNetworkTitle => 'Желі әлсіз';

  @override
  String get callsPoorNetworkText =>
      'Дыбыс үзілмеуі үшін трафикті үнемдеуді қосу керек пе?';

  @override
  String get callsPoorNetworkAccept => 'Үнемдеу';

  @override
  String get callsPoorNetworkDismiss => 'Қазір емес';

  @override
  String get callsTranscript => 'Мәтіндік жазба';

  @override
  String get callsTranscriptPending => 'Мәтіндік жазба дайындалуда';

  @override
  String get callsTranscriptFailed => 'Мәтіндік жазба сәтсіз аяқталды';

  @override
  String get callsTranscriptRetry => 'Қайта өңдеу';

  @override
  String get callsTranscriptSearch => 'Мәтіннен іздеу';

  @override
  String callsTranscriptMatches(int count) {
    return 'Табылды: $count';
  }

  @override
  String get callsTranscriptKeyPhrases => 'Негізгі сөйлемдер';

  @override
  String get callsTranscriptAutomatic => 'автоматты';

  @override
  String get callsTranscriptKeyPhrasesNote =>
      'Сөз жиілігі бойынша автоматты таңдалды — бұл әңгіменің мазмұндамасы емес.';

  @override
  String get callsTranscriptCopy => 'Мәтінді көшіру';

  @override
  String get callsTranscriptCopied => 'Мәтін көшірілді';

  @override
  String get callsTranscriptEmpty => 'Жазбада сөз танылмады';

  @override
  String get callsTranscriptNoSeek => 'Уақыт жазба басынан бастап есептеледі.';

  @override
  String get callsErrNotOrganizer =>
      'Кездесуді тек ұйымдастырушы өзгерте алады';

  @override
  String get callsErrLobbyDecided => 'Сұрау өңделіп қойған';

  @override
  String get callsErrGuests => 'Қонақ қолжетімділігі жоқ';

  @override
  String get callsErrTranscriptBusy =>
      'Мәтіндік жазба кезегі бос емес — кейінірек көріңіз';

  @override
  String get callsGroupCall => 'Топтық қоңырау';

  @override
  String get callsSwapVideo => 'Орындарын ауыстыру';

  @override
  String get callsVideoPaused => 'Бейне кідіртілді';

  @override
  String get chatAttachContact => 'Контакт';

  @override
  String get chatContactPickTitle => 'Контакт жіберу';

  @override
  String get chatContactWrite => 'Жазу';

  @override
  String get chatContactCall => 'Қоңырау шалу';

  @override
  String get chatContactInvalid => 'Бұл контакт қолжетімсіз.';

  @override
  String get chatVideoOpen => 'Бейнені ашу';

  @override
  String get chatMediaLoadPreview => 'Алдын ала көріністі жүктеу';

  @override
  String get chatAvatarChange => 'Топ фотосын өзгерту';

  @override
  String get chatAvatarUpdated => 'Топ фотосы жаңартылды';

  @override
  String get chatStorageSection => 'Чат деректері';

  @override
  String get chatAutoDownloadTitle => 'Медианы автожүктеу';

  @override
  String get chatAutoDownloadHint =>
      'Фото мен бейненің алдын ала көріністері, дауыстық хабарламалар. Файлдардың түпнұсқалары тек басқанда жүктеледі.';

  @override
  String get chatAutoDownloadNever => 'Ешқашан';

  @override
  String get chatAutoDownloadWifi => 'Тек Wi‑Fi';

  @override
  String get chatAutoDownloadAlways => 'Әрқашан';

  @override
  String get chatMessagesKeptTitle => 'Әр чатта сақталатын хабарламалар';

  @override
  String chatMediaSize(String size) {
    return 'Чат медиафайлдары: $size';
  }

  @override
  String get chatMediaClear => 'Медиафайлдарды тазалау';

  @override
  String get chatMediaCleared => 'Чат медиафайлдары жойылды';

  @override
  String get calendarBusyTitle => 'Бос емес уақыт';

  @override
  String get calendarBusyYou => 'Сіз';

  @override
  String get calendarBusyFree => 'бос';

  @override
  String get calendarBusyUnavailable =>
      'Бос емес уақыт туралы деректерді жүктеу мүмкін болмады.';

  @override
  String get calendarFindTime => 'Уақыт іріктеу';

  @override
  String get calendarFindTimeHint =>
      'Ұйымның жұмыс уақыты, таңдалған күннен бастап алдағы 7 күн.';

  @override
  String get calendarFindTimeEmpty => 'Бос уақыт табылмады.';

  @override
  String get calendarRoom => 'Мәжіліс бөлмесі';

  @override
  String get calendarRoomNone => 'Мәжіліс бөлмесінсіз';

  @override
  String calendarRoomSeats(int count) {
    return 'Орын саны: $count';
  }

  @override
  String get calendarRoomsEmpty => 'Қолжетімді мәжіліс бөлмелері жоқ';

  @override
  String get calendarRoomBusy => 'Мәжіліс бөлмесінің броньдары';

  @override
  String get calendarRoomBusyWarning =>
      'Таңдалған уақытта мәжіліс бөлмесі бос емес.';

  @override
  String get contactsTab => 'Контактілер';

  @override
  String get contactsTitle => 'Контактілер';

  @override
  String get contactsSearchHint => 'Аты немесе пошта бойынша іздеу';

  @override
  String get contactsLoadMore => 'Тағы көрсету';

  @override
  String get contactsClearSearch => 'Іздеуді тазалау';

  @override
  String get contactsEmpty => 'Анықтамалықта әзірге ешкім жоқ';

  @override
  String get contactsNotFound => 'Ешкім табылмады';

  @override
  String get contactsChatDisabled =>
      'Қызметкерлер анықтамалығы чат қызметі арқылы жұмыс істейді, ал ол бұл жинақта бапталмаған.';

  @override
  String get contactsCachedBanner =>
      'Жаңарту мүмкін болмады — сақталған тізім көрсетілген';

  @override
  String contactsLimitHint(int count) {
    return 'Алғашқы $count қызметкер көрсетілген — іздеуді нақтылаңыз';
  }

  @override
  String get contactsProfileTitle => 'Қызметкер';

  @override
  String get contactsProfileNotFound => 'Қызметкер анықтамалықтан табылмады';

  @override
  String get contactsWrite => 'Жазу';

  @override
  String get contactsAudioCall => 'Аудиоқоңырау';

  @override
  String get contactsVideoCall => 'Бейнеқоңырау';

  @override
  String get contactsWriteEmail => 'Хат жазу';

  @override
  String get contactsEmail => 'Пошта';

  @override
  String get contactsDepartment => 'Бөлім';

  @override
  String get contactsPosition => 'Лауазымы';

  @override
  String get contactsFilterAll => 'Барлығы';

  @override
  String get contactsFilterOnline => 'Желіде';

  @override
  String get contactsFilterFavourites => 'Таңдаулылар';

  @override
  String get contactsFilterDepartment => 'Бөлім';

  @override
  String get contactsDepartmentsTitle => 'Бөлімдер';

  @override
  String get contactsAllDepartments => 'Барлық бөлімдер';

  @override
  String get contactsNoDepartment => 'Бөлімсіз';

  @override
  String get contactsDepartmentsEmpty => 'Бөлімдер тізімі қолжетімсіз';

  @override
  String get contactsGroupByDepartment => 'Бөлімдер бойынша топтау';

  @override
  String get contactsGroupByName => 'Әліпби бойынша';

  @override
  String get contactsFavourites => 'Таңдаулылар';

  @override
  String get contactsRecent => 'Соңғылар';

  @override
  String get contactsAddFavourite => 'Таңдаулыларға қосу';

  @override
  String get contactsRemoveFavourite => 'Таңдаулылардан алып тастау';

  @override
  String get contactsNotFoundHint =>
      'Жазылуын тексеріңіз немесе басқа бөлімді таңдаңыз';

  @override
  String get contactsNoOnline => 'Қазір ешкім желіде емес';

  @override
  String get contactsNoFavourites => 'Таңдаулы әріптестер жоқ';

  @override
  String get contactsNoFavouritesHint =>
      'Профильді ашып, жұлдызшаны басыңыз — әріптес осында шығады';

  @override
  String get contactsMailbox => 'Пошта жәшігі';

  @override
  String contactsCopied(String value) {
    return 'Көшірілді: $value';
  }

  @override
  String get contactsCopy => 'Көшіру';

  @override
  String get contactsManager => 'Басшы';

  @override
  String contactsEmployeeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count қызметкер',
    );
    return '$_temp0';
  }

  @override
  String get contactsColleagues => 'Бөлімдегі әріптестер';

  @override
  String get contactsSharedChats => 'Ортақ топтар';

  @override
  String contactsChatMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count қатысушы',
    );
    return '$_temp0';
  }

  @override
  String get contactsShare => 'Контактіні бөлісу';

  @override
  String get contactsShareToChat => 'Чатқа жіберу';

  @override
  String get contactsCopyVCard => 'Визитканы көшіру (vCard)';

  @override
  String get contactsVCardCopied => 'Визитка көшірілді';

  @override
  String contactsShareSent(String chat) {
    return 'Контакт «$chat» чатына жіберілді';
  }

  @override
  String get contactsShareNoChats => 'Жіберетін чат жоқ';

  @override
  String get contactsActionAudio => 'Аудио';

  @override
  String get contactsActionVideo => 'Бейне';

  @override
  String get contactsActionEmail => 'Хат';

  @override
  String get contactsIndexHint => 'Әріп бойынша жылдам өту';

  @override
  String get contactsSeenJustNow => 'жаңа ғана желіде болды';

  @override
  String contactsSeenMinutes(int count) {
    return '$count мин бұрын желіде болды';
  }

  @override
  String contactsSeenHours(int count) {
    return '$count сағ бұрын желіде болды';
  }

  @override
  String get notificationsTitle => 'Хабарландырулар';

  @override
  String get notificationsReadAll => 'Барлығын оқылды деп белгілеу';

  @override
  String get notificationsEmpty => 'Әзірге хабарландырулар жоқ';

  @override
  String notificationsLimitNote(int count) {
    return 'Соңғы $count хабарландыру көрсетілген';
  }

  @override
  String get mailFormatToolbar => 'Пішімдеу';

  @override
  String get mailFormatBold => 'Қалың';

  @override
  String get mailFormatItalic => 'Курсив';

  @override
  String get mailFormatUnderline => 'Асты сызылған';

  @override
  String get mailFormatBulletList => 'Маркерлі тізім';

  @override
  String get mailFormatNumberedList => 'Нөмірленген тізім';

  @override
  String get mailFormatQuote => 'Дәйексөз';

  @override
  String get mailFormatLink => 'Сілтеме';

  @override
  String get mailFormatTextColor => 'Мәтін түсі';

  @override
  String get mailFormatHighlight => 'Бөлектеу түсі';

  @override
  String get mailFormatColorNone => 'Түссіз';

  @override
  String get mailFormatTable => 'Кесте';

  @override
  String get mailFormatPreview => 'Алдын ала қарау';

  @override
  String get mailFormatEdit => 'Өңдеу';

  @override
  String get mailFormatHelp =>
      '**қалың**  _курсив_  __асты сызылған__  - тізім  1. тізім  > дәйексөз  [мәтін](https://…)';

  @override
  String get mailPreviewEmpty => 'Хат әзірге бос';

  @override
  String get mailLinkDialogTitle => 'Сілтеме қою';

  @override
  String get mailLinkUrl => 'Сілтеме мекенжайы';

  @override
  String get mailLinkUrlHint => 'https://… немесе mailto:…';

  @override
  String get mailLinkText => 'Сілтеме мәтіні';

  @override
  String get mailLinkInvalid =>
      'Тек https://, http:// және mailto: сілтемелеріне рұқсат етіледі';

  @override
  String get mailLinkInsert => 'Қою';

  @override
  String get mailSignaturePreviewTitle =>
      'Жіберу кезінде сервер мына қолтаңбаны қосады:';

  @override
  String get mailSignaturePreviewNote =>
      'Алдын ала көрініс: жауаптар мен сыртқы алушылар үшін ұйым ережелері өзгеше болуы мүмкін.';

  @override
  String get mailThreadsMode => 'Хат тізбектері';

  @override
  String get mailSettingsTitle => 'Пошта баптаулары';

  @override
  String get mailSettingsSignature => 'Қолтаңба';

  @override
  String get mailSettingsSignatureSubtitle => 'Хаттардағы жеке қолтаңба';

  @override
  String get mailSettingsVacation => 'Автожауап';

  @override
  String get mailSettingsVacationSubtitle => 'Сіз жоқ кезде жіберілетін жауап';

  @override
  String get mailSettingsBlocked => 'Бұғатталған жіберушілер';

  @override
  String get mailSettingsBlockedSubtitle =>
      'Олардың хаттары «Спам» қалтасына түседі';

  @override
  String get mailSettingsBookmarkFolders => 'Бетбелгі қалталары';

  @override
  String get mailSettingsBookmarkFoldersSubtitle =>
      'Белгіленген хаттар жинақтары';

  @override
  String get mailSettingsSaved => 'Сақталды';

  @override
  String get mailSignatureLabel => 'Қолтаңба мәтіні';

  @override
  String get mailSignatureDefaultNote => 'Қазір әдепкі қолтаңба қолданылуда.';

  @override
  String get mailSignatureRestoreDefault => 'Әдепкі қолтаңбаны қайтару';

  @override
  String get mailSignatureTooLong => 'Қолтаңба 2000 байттан ұзын.';

  @override
  String mailSignatureBytes(int used, int max) {
    return '$used / $max байт';
  }

  @override
  String get mailSignatureNotApplied =>
      'Ұйым қазір хаттарға жеке қолтаңба қоспайды.';

  @override
  String get mailVacationEnabled => 'Автожауап қосулы';

  @override
  String get mailVacationSubject => 'Тақырып (міндетті емес)';

  @override
  String get mailVacationBody => 'Автожауап мәтіні';

  @override
  String get mailVacationStartsOn => 'Басталуы';

  @override
  String get mailVacationEndsOn => 'Аяқталуы';

  @override
  String get mailVacationNoDate => 'Күні жоқ';

  @override
  String get mailVacationClearDate => 'Күнді алып тастау';

  @override
  String get mailVacationTimeZone => 'Уақыт белдеуі';

  @override
  String get mailVacationActiveNow => 'Автожауап қазір жіберілуде';

  @override
  String get mailVacationPending =>
      'Автожауап басталу күнінен бастап жіберіледі';

  @override
  String get mailVacationInactive => 'Автожауап жіберілмейді';

  @override
  String get mailVacationNote =>
      'Жауапты сыртқы жіберушілер алады, әрқайсысы 3 күнде бір реттен жиі емес.';

  @override
  String get mailVacationBodyRequired => 'Автожауап мәтінін енгізіңіз.';

  @override
  String get mailVacationSubjectTooLong => 'Тақырып 200 таңбадан ұзын.';

  @override
  String get mailVacationBodyTooLong => 'Мәтін 4000 таңбадан ұзын.';

  @override
  String get mailVacationDatesInvalid =>
      'Аяқталу күні басталу күнінен ерте болмауы керек.';

  @override
  String get mailVacationTimeZoneInvalid => 'Белгісіз уақыт белдеуі.';

  @override
  String get mailSyncPending => 'Өзгерістер пошта серверінде қолданылуда…';

  @override
  String get mailSyncFailed =>
      'Пошта сервері өзгерістерді қабылдамады. Қайта сақтаңыз.';

  @override
  String get mailBlockedEmpty => 'Бұғатталған жіберушілер жоқ';

  @override
  String get mailBlockedAdd => 'Бұғаттау';

  @override
  String get mailBlockedAddTitle => 'Жіберушіні бұғаттау';

  @override
  String get mailBlockedValue => 'Домен, мекенжай, IP немесе желі';

  @override
  String get mailBlockedValueHint =>
      'example.com, 203.0.113.7, 198.51.100.0/24';

  @override
  String get mailBlockedNote => 'Ескертпе (міндетті емес)';

  @override
  String mailBlockedRemoveTitle(String pattern) {
    return '$pattern бұғаттан шығару керек пе?';
  }

  @override
  String get mailBlockedRemove => 'Бұғаттан шығару';

  @override
  String mailBlockedCount(int count, int limit) {
    return '$count / $limit';
  }

  @override
  String get mailBlockedKindDomain => 'Домен';

  @override
  String get mailBlockedKindIp => 'IP-мекенжай';

  @override
  String get mailBlockedKindNetwork => 'Желі';

  @override
  String get mailBookmarkFoldersEmpty => 'Әзірге бетбелгі қалталары жоқ';

  @override
  String get mailBookmarkFolderCreate => 'Қалта құру';

  @override
  String get mailBookmarkFolderName => 'Қалта атауы';

  @override
  String get mailBookmarkFolderNameInvalid =>
      'Атауы 1-ден 80 таңбаға дейін болуы керек.';

  @override
  String mailBookmarkFolderDeleteTitle(String name) {
    return '«$name» қалтасын жою керек пе?';
  }

  @override
  String get mailBookmarkFolderDeleteBody =>
      'Хаттар өз қалталарында қалады және бетбелгісін сақтайды.';

  @override
  String get mailErrFolderExists => 'Мұндай атаулы қалта бар.';

  @override
  String get mailErrInvalidList => 'Тек жіберушілерді бұғаттауға болады.';

  @override
  String get mailErrEmptyPattern =>
      'Доменді, мекенжайды, IP-ді немесе желіні көрсетіңіз.';

  @override
  String get mailErrTopLevelDomain =>
      'Бүкіл домен аймағын бұғаттауға болмайды.';

  @override
  String get mailErrNetworkTooWide => 'Желі тым кең: /8-ден кең болмауы керек.';

  @override
  String get mailErrIpv6Network =>
      'IPv6 ауқымдарына қолдау көрсетілмейді — нақты мекенжайды көрсетіңіз.';

  @override
  String get mailErrInvalidPattern =>
      'Бұл домен, мекенжай, IP немесе желі емес.';

  @override
  String get mailErrNoteTooLong => 'Ескертпе 200 таңбадан ұзын.';

  @override
  String get mailErrRuleLimit => '500 жазба шегіне жетті.';

  @override
  String get mailErrRuleExists => 'Бұл жіберуші бұғатталып қойған.';

  @override
  String get mailErrRuleNotFound => 'Жазба жойылып қойған.';

  @override
  String get mailErrIcsNotFound => 'Хаттан шақыру табылмады.';

  @override
  String get mailErrIcsTooLarge => 'Шақыру файлы тым үлкен.';

  @override
  String get mailErrInvalidIcs => 'Шақыруды оқу мүмкін болмады.';

  @override
  String get mailErrInvalidRsvp => 'Шақыруға жарамсыз жауап.';

  @override
  String get mailReportPhishing => 'Фишинг туралы хабарлау';

  @override
  String get mailReportPhishingTitle => 'Фишинг туралы хабарлау керек пе?';

  @override
  String get mailReportPhishingBody =>
      'Хат «Спам» қалтасына жылжытылып, тексеруге жіберіледі. Ондағы сілтемелерге өтпеңіз және тіркемелерді ашпаңыз.';

  @override
  String get mailReportPhishingConfirm => 'Хабарлау';

  @override
  String get mailReportedPhishing => 'Фишинг туралы хабар жіберілді';

  @override
  String get mailDeliveryStatus => 'Жеткізу күйі';

  @override
  String get mailDeliveryEmpty =>
      'Жеткізу деректері жоқ: хат платформа арқылы жіберілмеген.';

  @override
  String get mailDeliveryRecipients => 'Алушылар';

  @override
  String get mailDeliveryHistory => 'Тарих';

  @override
  String get mailDeliveryStateAccepted => 'Қабылданды';

  @override
  String get mailDeliveryStateProcessing => 'Өңделуде';

  @override
  String get mailDeliveryStateDelivered => 'Жеткізілді';

  @override
  String get mailDeliveryStatePartiallyDelivered => 'Ішінара жеткізілді';

  @override
  String get mailDeliveryStateFailed => 'Жеткізілмеді';

  @override
  String get mailDeliveryStateQuarantined => 'Карантинде';

  @override
  String get mailDeliveryStatePending => 'Күтуде';

  @override
  String get mailDeliveryStateRelayed => 'Сыртқы серверге берілді';

  @override
  String get mailDeliveryStateDraft => 'Жоба';

  @override
  String get mailDeliveryEventAccepted => 'Жіберуге қабылданды';

  @override
  String get mailDeliveryEventScanned => 'Тексерілді';

  @override
  String get mailDeliveryEventDeliveredLocal => 'Пошта жәшігіне жеткізілді';

  @override
  String get mailDeliveryEventRelayed => 'Сыртқы серверге берілді';

  @override
  String get mailDeliveryEventFailed => 'Жеткізу қатесі';

  @override
  String get mailInviteTitle => 'Күнтізбеге шақыру';

  @override
  String get mailInviteMethodRequest => 'Шақыру';

  @override
  String get mailInviteMethodCancel => 'Оқиға тоқтатылды';

  @override
  String get mailInviteMethodReply => 'Қатысушының жауабы';

  @override
  String mailInviteOrganizer(String name) {
    return 'Ұйымдастырушы: $name';
  }

  @override
  String mailInviteYourStatus(String status) {
    return 'Сіздің жауабыңыз: $status';
  }

  @override
  String get mailInviteStatusAccepted => 'қабылданды';

  @override
  String get mailInviteStatusTentative => 'мүмкін';

  @override
  String get mailInviteStatusDeclined => 'бас тартылды';

  @override
  String get mailInviteStatusPending => 'жауап жоқ';

  @override
  String get mailInviteAccept => 'Қабылдаймын';

  @override
  String get mailInviteMaybe => 'Мүмкін';

  @override
  String get mailInviteDecline => 'Бас тартамын';

  @override
  String get mailInviteCancelledNote => 'Ұйымдастырушы оқиғаны тоқтатты.';

  @override
  String get mailInviteApplyCancel => 'Күнтізбеде тоқтатылғанын белгілеу';

  @override
  String mailInviteReplyFrom(String who, String status) {
    return '$who жауап берді: $status';
  }

  @override
  String get mailInviteApplyReply => 'Күнтізбедегі жауапты жаңарту';

  @override
  String get mailInviteOpenCalendar => 'Күнтізбеде ашу';

  @override
  String get mailInviteSaved => 'Жауап күнтізбеге сақталды';

  @override
  String get mailInviteRecurring => 'Қайталанатын оқиға';

  @override
  String mailInviteInZone(String time, String zone) {
    return '$time ($zone)';
  }

  @override
  String get chatDraft => 'Жоба';

  @override
  String get chatUnreadMessages => 'Оқылмаған хабарлар';

  @override
  String get chatScrollToBottom => 'Төменге';

  @override
  String chatForwardedFrom(String name) {
    return 'Қайта жіберілді: $name';
  }

  @override
  String get chatSelect => 'Таңдау';

  @override
  String chatDeleteSelected(int count) {
    return '$count хабарды жою керек пе?';
  }

  @override
  String get chatSearchInChat => 'Чаттан іздеу';

  @override
  String get chatSearchNoResults => 'Ештеңе табылмады';

  @override
  String chatSearchPosition(int current, int total) {
    return '$current / $total';
  }

  @override
  String get chatMessageNotFound => 'Хабар қолжетімсіз';

  @override
  String get chatAttachCamera => 'Камера';

  @override
  String get chatAttachGallery => 'Галерея';

  @override
  String get chatMoreReactions => 'Басқа реакциялар';

  @override
  String get chatEmojiRecent => 'Соңғы';

  @override
  String get chatEmojiAll => 'Барлық эмодзи';

  @override
  String get chatMessageInfo => 'Хабар туралы ақпарат';

  @override
  String get chatReadBy => 'Оқығандар';

  @override
  String get chatNoReceipts => 'Әзірге ешкім оқымаған';

  @override
  String get chatFilterAll => 'Барлығы';

  @override
  String get chatFilterUnread => 'Оқылмаған';

  @override
  String get chatFilterGroups => 'Топтар';

  @override
  String get chatEmptyFilter => 'Әзірге бос';

  @override
  String get chatArchivedEmpty => 'Мұрағатта чат жоқ';

  @override
  String get chatSelectConversation =>
      'Хат алмасуды бастау үшін чатты таңдаңыз';

  @override
  String get chatRemoveAdmin => 'Әкімші құқығын алып тастау';

  @override
  String get chatOpenExternally => 'Басқа қолданбада ашу';

  @override
  String get chatPlaybackSpeed => 'Ойнату жылдамдығы';

  @override
  String get chatTypingShort => 'жазып жатыр…';

  @override
  String get chatRecordingShort => 'дауыстық хабар жазып жатыр…';

  @override
  String get chatEmptyHint => 'Алғашқы хабарды жіберіңіз';

  @override
  String get chatSaved => 'Таңдаулылар';

  @override
  String get chatSavedHint => 'Тек сізге арналған жазбалар мен файлдар';

  @override
  String get chatSaveToSaved => 'Таңдаулыларға сақтау';

  @override
  String get chatSavedDone => 'Таңдаулыларға сақталды';

  @override
  String get chatDeleteForMe => 'Менде жою';

  @override
  String get chatDeleteForAll => 'Барлығында жою';

  @override
  String get chatMarkUnread => 'Оқылмаған деп белгілеу';

  @override
  String get chatMarkRead => 'Оқылған деп белгілеу';

  @override
  String get chatUnreadShort => 'Оқылмаған';

  @override
  String get chatReadShort => 'Оқылды';

  @override
  String get chatDescription => 'Сипаттама';

  @override
  String get chatDescriptionAdd => 'Сипаттама қосу';

  @override
  String get chatDescriptionEdit => 'Сипаттаманы өзгерту';

  @override
  String get chatDescriptionTooLong => '500 таңбадан аспауы керек';

  @override
  String chatSystemDescriptionChanged(String actor) {
    return '$actor топ сипаттамасын өзгертті';
  }

  @override
  String get chatMediaFilesLinks => 'Медиа, файлдар және сілтемелер';

  @override
  String get chatMediaTabMedia => 'Медиа';

  @override
  String get chatMediaTabFiles => 'Файлдар';

  @override
  String get chatMediaTabLinks => 'Сілтемелер';

  @override
  String get chatMediaTabVoice => 'Дауыстық';

  @override
  String get chatMediaEmpty => 'Әзірге ештеңе жоқ';

  @override
  String get chatShowInChat => 'Чатта көрсету';

  @override
  String get chatShareTitle => 'Чатқа жіберу';

  @override
  String get chatShareRecent => 'Соңғы чаттар';

  @override
  String get chatShareNothing => 'Жіберетін ештеңе жоқ';

  @override
  String chatShareFiles(int count) {
    return 'Тіркемелер: $count';
  }

  @override
  String get chatRemoveAttachment => 'Тіркемені алып тастау';

  @override
  String get chatVideoPlay => 'Ойнату';

  @override
  String get chatVideoPause => 'Кідірту';

  @override
  String get chatVideoMute => 'Дыбысты өшіру';

  @override
  String get chatVideoUnmute => 'Дыбысты қосу';

  @override
  String get chatVideoFailed => 'Бейнені ойнату мүмкін болмады';

  @override
  String homeWidgetUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count оқылмаған',
    );
    return '$_temp0';
  }

  @override
  String get homeWidgetNoUnread => 'Оқылмаған чат жоқ';

  @override
  String get homeWidgetNoEvents => 'Бүгін басқа оқиға жоқ';

  @override
  String get homeWidgetSignIn => 'XatBox-қа кіріңіз';

  @override
  String get settingsWidgetSection => 'Виджет және жарлықтар';

  @override
  String get settingsWidgetPreview => 'Виджетте хабарлама мәтіні';

  @override
  String get settingsWidgetPreviewHint =>
      'Әйтпесе виджет тек чат атауларын көрсетеді. PIN-құлып немесе «Мазмұнды жасыру» қосулы болса — тек оқылмағандар саны.';

  @override
  String get shortcutNewMessage => 'Жаңа хабарлама';

  @override
  String get shortcutCall => 'Қоңырау шалу';

  @override
  String get shortcutSearch => 'Іздеу';

  @override
  String get savedChatOpenFailed => 'Таңдаулыларды ашу мүмкін болмады';

  @override
  String get updateTitle => 'Қолданбаны жаңарту';

  @override
  String updateCurrentVersion(String version) {
    return 'Орнатылған нұсқа $version';
  }

  @override
  String updateNewVersion(String version) {
    return 'Нұсқа $version';
  }

  @override
  String get updateAvailableTitle => 'Жаңарту қолжетімді';

  @override
  String get updateMandatoryTitle => 'XatBox-ты жаңарту қажет';

  @override
  String get updateMandatoryBody =>
      'Бұл нұсқаны сервер енді қолдамайды. Жаңарту бір минут алады — чаттар, пошта және баптаулар сақталады.';

  @override
  String get updateUpToDate => 'Сізде соңғы нұсқа';

  @override
  String updateCheckedAt(String time) {
    return 'Тексерілді: $time';
  }

  @override
  String get updateCheck => 'Жаңартуларды тексеру';

  @override
  String get updateChecking => 'Жаңартулар тексерілуде…';

  @override
  String get updateCheckFailed => 'Жаңартуларды тексеру мүмкін болмады';

  @override
  String get updateWhatsNew => 'Не жаңалық';

  @override
  String get updateNoNotes => 'Қателерді түзету және тұрақтылықты жақсарту.';

  @override
  String get updateDownload => 'Жүктеп алу және орнату';

  @override
  String updateDownloading(int percent) {
    return 'Жүктелуде… $percent%';
  }

  @override
  String updateDownloadedOf(String received, String total) {
    return '$received / $total';
  }

  @override
  String get updateCancel => 'Жүктеуді тоқтату';

  @override
  String get updateResume => 'Жүктеуді жалғастыру';

  @override
  String get updateInstall => 'Орнату';

  @override
  String get updateInstalling => 'Android орнатушысы ашылды';

  @override
  String get updateInstallingHint =>
      'Орнатуды растаңыз. Терезе жабылса, «Орнату» түймесін қайта басыңыз.';

  @override
  String get updateLater => 'Кейінірек';

  @override
  String get updatePermissionTitle => 'Жаңартуларды орнатуға рұқсат беріңіз';

  @override
  String get updatePermissionBody =>
      'Android XatBox-қа қолданба орнатуға бір рет рұқсат сұрайды. Баптауларды ашып, «Осы көзден рұқсат ету» опциясын қосыңыз да, қайта оралыңыз — орнату өздігінен жалғасады.';

  @override
  String get updatePermissionOpen => 'Баптауларды ашу';

  @override
  String get updateFailed => 'Жаңартуды жүктеу мүмкін болмады';

  @override
  String get updateIntegrityFailed =>
      'Файл жүктеу кезінде бүлінді. Қайталап көріңіз.';

  @override
  String get updateInstallFailed => 'Android орнатушысын ашу мүмкін болмады';

  @override
  String get updateRetry => 'Қайталау';

  @override
  String get updateIncompatible =>
      'Бұл құрылғыға сәйкес жаңарту файлы жоқ. Әкімшіге хабарласыңыз.';

  @override
  String get updateUnsupported =>
      'Жаңартулар XatBox серверінен келеді және тек Android-та қолжетімді.';

  @override
  String get updateSignOut => 'Аккаунттан шығу';

  @override
  String updateSettingsAvailable(String version) {
    return '$version нұсқасы қолжетімді';
  }

  @override
  String get updateBadgeNew => 'Жаңа';

  @override
  String get sessionsTitle => 'Құрылғыларым мен сеанстарым';

  @override
  String get sessionsSettingsHint => 'Аккаунтқа қай жерден кірілген';

  @override
  String get sessionsHint =>
      'Мұнда аккаунтыңызға кірген барлық құрылғылар. Құрылғыны танымасаңыз, сеансты аяқтап, құпиясөзді өзгертіңіз.';

  @override
  String get sessionsThisDevice => 'Осы құрылғы';

  @override
  String get sessionsOthers => 'Басқа құрылғылар';

  @override
  String get sessionsNoOthers => 'Басқа белсенді сеанс жоқ';

  @override
  String get sessionsActiveNow => 'Қазір белсенді';

  @override
  String sessionsLastActive(String time) {
    return 'Соңғы белсенділік: $time';
  }

  @override
  String sessionsSignedIn(String date) {
    return 'Кірген уақыты: $date';
  }

  @override
  String sessionsIp(String ip) {
    return 'IP мекенжайы $ip';
  }

  @override
  String get sessionsEnd => 'Осы құрылғыда шығу';

  @override
  String get sessionsEndConfirmTitle => 'Сеансты аяқтау керек пе?';

  @override
  String sessionsEndConfirmBody(String device) {
    return '«$device» құрылғысында құпиясөзбен қайта кіру керек болады, ал ондағы XatBox деректері келесі қосылғанда өшіріледі.';
  }

  @override
  String get sessionsEndOthers => 'Барлық басқа құрылғыларда шығу';

  @override
  String get sessionsEndOthersConfirmBody =>
      'Осы құрылғыдан басқа барлық құрылғылар аккаунттан шығарылып, жергілікті XatBox деректерін өшіреді.';

  @override
  String get sessionsEnded => 'Сеанс аяқталды';

  @override
  String get sessionsXatBoxApp => 'XatBox қолданбасы';

  @override
  String get sessionsUnknownDevice => 'Белгісіз құрылғы';

  @override
  String get aboutTitle => 'Қолданба туралы';

  @override
  String get aboutTagline => 'Пошта, мессенджер және қоңыраулар бір қолданбада';

  @override
  String aboutVersion(String version, String build) {
    return 'Нұсқа $version · жинақ $build';
  }

  @override
  String get aboutAppSection => 'Қолданба';

  @override
  String get aboutServers => 'Серверлер';

  @override
  String get aboutServerMail => 'Пошта';

  @override
  String get aboutServerChat => 'Мессенджер';

  @override
  String get aboutServerCalls => 'Қоңыраулар';

  @override
  String get aboutServerNotConfigured => 'Бапталмаған';

  @override
  String get aboutServerUnreachable => 'Қолжетімсіз';

  @override
  String get aboutServerDegraded => 'Қателермен жұмыс істейді';

  @override
  String aboutServerLatency(int ms) {
    return '$ms мс';
  }

  @override
  String get aboutRecheck => 'Қайта тексеру';

  @override
  String get aboutWhatsNew => 'Не жаңалық';

  @override
  String get aboutLicenses => 'Ашық бағдарламалық жасақтама лицензиялары';

  @override
  String get aboutPrivacy => 'Құпиялық';

  @override
  String get aboutPrivacyDataTitle => 'Деректер қайда сақталады';

  @override
  String get aboutPrivacyDataBody =>
      'Хаттар, чаттар, файлдар және қоңырау жазбалары бөгде сервистерде емес, ұйымның серверлерінде сақталады. Құрылғыда тек желісіз жұмысқа арналған кэш қалады — ол аккаунттан шыққанда өшіріледі.';

  @override
  String get aboutPrivacyPushTitle => 'Шифрланған хабарландырулар';

  @override
  String get aboutPrivacyPushBody =>
      'Хабарландыру мәтіні осы телефонда жасалған кілтпен шифрланады. Google мен Apple тек шифрланған пакетті жеткізеді және кім не жазғанын көрмейді.';

  @override
  String get aboutPrivacyReportsTitle => 'Қате туралы есептер';

  @override
  String get aboutPrivacyReportsBody =>
      'Ақаулар туралы есептер тек XatBox серверіне жіберіледі — хабар мәтіндерісіз, мекенжайларсыз және құпиясөздерсіз. Оларды баптауларда өшіруге болады.';

  @override
  String get aboutPrivacyLockTitle => 'Қолданбаны құлыптау';

  @override
  String get aboutPrivacyLockBody =>
      'PIN-код ашық түрде сақталмайды: құрылғының қорғалған қоймасында тек тұзды хеші сақталады.';

  @override
  String get reportTitle => 'Мәселе туралы хабарлау';

  @override
  String get reportCategory => 'Не болды?';

  @override
  String get reportCategoryBug => 'Қате';

  @override
  String get reportCategoryIdea => 'Ұсыныс';

  @override
  String get reportCategoryQuestion => 'Сұрақ';

  @override
  String get reportCategoryOther => 'Басқа';

  @override
  String get reportDescription => 'Сипаттама';

  @override
  String get reportDescriptionHint =>
      'Не істедіңіз және не дұрыс болмады? Неғұрлым толық жазсаңыз, соғұрлым тез түзетеміз.';

  @override
  String get reportScreenshot => 'Скриншот';

  @override
  String get reportScreenshotAttach => 'Сурет тіркеу';

  @override
  String get reportScreenshotRemove => 'Алып тастау';

  @override
  String get reportDiagnostics => 'Диагностиканы тіркеу';

  @override
  String get reportDiagnosticsHint =>
      'Нұсқа, құрылғы моделі және жеке деректерсіз техникалық журнал';

  @override
  String get reportDiagnosticsShow => 'Не жіберіледі';

  @override
  String get reportShake => 'Мәселе туралы хабарлау үшін сілку';

  @override
  String get reportShakeHint =>
      'Кез келген экранда телефонды сілкіңіз — скриншоты бар осы пішін ашылады';

  @override
  String get reportSend => 'Жіберу';

  @override
  String get reportSentTitle => 'Рақмет!';

  @override
  String get reportSent =>
      'Хабарлама жіберілді. Біз оны қарастырып, қажет болса, сізбен байланысамыз.';

  @override
  String get reportDone => 'Дайын';

  @override
  String get reportRateLimited =>
      'Қатарынан тым көп хабарлама. Бір сағаттан кейін қайталаңыз.';

  @override
  String get reportUnavailable =>
      'Жіберу қолжетімсіз: мессенджер сервері бапталмаған.';

  @override
  String lockGreeting(String name) {
    return 'Сәлеметсіз бе, $name';
  }

  @override
  String get lockReturnToCall => 'Қоңырауға оралу';

  @override
  String get chatReport => 'Шағымдану';

  @override
  String get chatReportTitle => 'Хабарламаға шағымдану';

  @override
  String get chatReportReasonSpam => 'Спам';

  @override
  String get chatReportReasonAbuse => 'Қорлау';

  @override
  String get chatReportReasonConfidential => 'Құпия деректер';

  @override
  String get chatReportReasonOther => 'Басқа';

  @override
  String get chatReportComment => 'Түсініктеме (міндетті емес)';

  @override
  String get chatReportSend => 'Шағым жіберу';

  @override
  String get chatReportSent => 'Шағым жіберілді. Модераторлар оны қарайды.';

  @override
  String get chatReportReviewed => 'Шағымыңыз қаралды. Рақмет!';

  @override
  String get chatReportPrivacyHint => 'Автор кім шағымданғанын білмейді.';

  @override
  String get chatForwardForbidden => 'Бұл чаттан қайта жіберуге тыйым салынған';

  @override
  String get chatMemberRestricted =>
      'Сізге бұл чатқа уақытша жазуға тыйым салынған';

  @override
  String chatSystemProtectionChanged(String actor) {
    return '$actor чатты қорғау баптауларын өзгертті';
  }

  @override
  String get chatSystemModerationWarning =>
      'Модератор ережені бұзғаны үшін ескерту жасады';

  @override
  String get chatSystemMemberRestricted =>
      'Қатысушыға уақытша жазуға тыйым салынды';

  @override
  String get chatProtection => 'Чатты қорғау';

  @override
  String get chatProtectionActive => 'Қорғау қосулы';

  @override
  String get chatProtectionNone => 'Қорғау өшірулі';

  @override
  String get chatProtectionNoForward =>
      'Қайта жіберуге және көшіруге тыйым салу';

  @override
  String get chatProtectionNoForwardHint =>
      'Хабарламаларды қайта жіберу, көшіру немесе сақтау мүмкін емес';

  @override
  String get chatProtectionScreenshots => 'Скриншоттан қорғау';

  @override
  String get chatProtectionScreenshotsHint =>
      'Android-та скриншот пен экран жазбасы бұғатталады, iPhone-да чат жасырылады';

  @override
  String get chatProtectionDisappearing => 'Жоғалатын хабарламалар';

  @override
  String get chatProtectionDisappearingHint =>
      'Жаңа хабарламалар таймер бойынша барлығынан жойылады';

  @override
  String get chatProtectionAdminsOnly => 'Қорғауды тек әкімшілер өзгерте алады';

  @override
  String get chatProtectionPeerNotified =>
      'Әңгімелесуші өзгеріс туралы хабарды көреді';

  @override
  String get chatProtectionMembersNotified =>
      'Қатысушылар өзгеріс туралы хабарды көреді';

  @override
  String get chatDisappearingOff => 'Өшірулі';

  @override
  String get chatDisappearingDay => '1 күн';

  @override
  String get chatDisappearingWeek => '1 апта';

  @override
  String get chatDisappearingMonth => '1 ай';

  @override
  String chatDisappearingCustom(int hours) {
    return '$hours сағ';
  }

  @override
  String get chatDisappearingMessage => 'Жоғалатын хабарлама';

  @override
  String get chatStickers => 'Эмодзи мен стикерлер';

  @override
  String get chatEmoji => 'Эмодзи';

  @override
  String get chatStickersRecent => 'Соңғылар';

  @override
  String get chatStickersEmpty => 'Стикерлер әзірге қолжетімсіз';

  @override
  String get chatAttachmentSticker => 'Стикер';

  @override
  String get chatStickerUnavailable => 'Стикер қолжетімсіз';

  @override
  String get chatTranscribe => 'Мәтінге айналдыру';

  @override
  String get chatTranscribing => 'Мәтінге айналдырылуда…';

  @override
  String get chatTranscriptFailed => 'Мәтінге айналдыру мүмкін болмады';

  @override
  String get chatTranscriptRetry => 'Қайталау';

  @override
  String get chatTranscriptEmpty => 'Сөз танылмады';

  @override
  String get chatTranscriptShow => 'Мәтінді көрсету';

  @override
  String get chatTranscriptHide => 'Мәтін';

  @override
  String get chatTranscriptionBusy =>
      'Мәтінге айналдыру кезегі бос емес, кейінірек көріңіз';

  @override
  String get chatAutoTranscribe =>
      'Дауыстық хабарларды автоматты түрде мәтінге айналдыру';

  @override
  String get chatAutoTranscribeHint =>
      'Мәтінге айналдыру университет серверінде орындалады';

  @override
  String get moderationTitle => 'Модерация';

  @override
  String get moderationHint => 'Хабарламаларға шағымдар';

  @override
  String get moderationTabOpen => 'Ашық';

  @override
  String get moderationTabResolved => 'Шешілген';

  @override
  String get moderationTabDismissed => 'Қабылданбаған';

  @override
  String get moderationEmpty => 'Шағым жоқ';

  @override
  String get moderationEmptyHint => 'Қатысушылардың шағымдары осында көрінеді';

  @override
  String get moderationGlobalScope => 'Ұйымның барлық чаттары';

  @override
  String get moderationGroupScope => 'Сіз әкімші болған топтар';

  @override
  String get moderationReport => 'Шағым';

  @override
  String moderationReportFrom(String name) {
    return 'Шағымданған: $name';
  }

  @override
  String moderationAuthor(String name) {
    return 'Автор: $name';
  }

  @override
  String get moderationDirectChat => 'Жеке чат';

  @override
  String get moderationMember => 'Қатысушы';

  @override
  String get moderationContext => 'Хат алмасу контексі';

  @override
  String get moderationComment => 'Түсініктеме';

  @override
  String get moderationActions => 'Әрекеттер';

  @override
  String get moderationDeleteMessage => 'Хабарламаны барлығынан жою';

  @override
  String get moderationWarn => 'Авторға ескерту';

  @override
  String get moderationRemove => 'Топтан шығару';

  @override
  String get moderationMute => 'Жазуға тыйым салу';

  @override
  String moderationMuteHours(int hours) {
    return '$hours сағатқа';
  }

  @override
  String get moderationDismiss => 'Шағымды қабылдамау';

  @override
  String get moderationNote => 'Журналға жазба (міндетті емес)';

  @override
  String get moderationConfirm => 'Қолдану';

  @override
  String get moderationDone => 'Дайын';

  @override
  String get moderationAlreadyHandled => 'Шағым қаралып қойған';

  @override
  String moderationResolution(String action) {
    return 'Шешім: $action';
  }

  @override
  String moderationRestrictedUntil(String time) {
    return '$time дейін жаза алмайды';
  }

  @override
  String get moderationNotMember => 'Енді чат қатысушысы емес';

  @override
  String get moderationDeletedContent => 'Хабарлама жойылды';

  @override
  String get statusTitle => 'Мәртебе';

  @override
  String get statusSet => 'Мәртебе орнату';

  @override
  String get statusNone => 'Мәртебе орнатылмаған';

  @override
  String get statusPresetInClass => 'Сабақта';

  @override
  String get statusPresetMeeting => 'Жиналыста';

  @override
  String get statusPresetBusinessTrip => 'Іссапарда';

  @override
  String get statusPresetVacation => 'Демалыста';

  @override
  String get statusPresetSick => 'Ауырып жүрмін';

  @override
  String get statusPresetDnd => 'Мазаламаңыз';

  @override
  String get statusPresetCustom => 'Өз мәртебем';

  @override
  String get statusTextLabel => 'Мәртебе мәтіні';

  @override
  String get statusEmojiPick => 'Мәртебе эмодзиін таңдау';

  @override
  String get statusUntilLabel => 'Дейін';

  @override
  String get statusUntilNone => 'Мерзімсіз';

  @override
  String get statusUntilHour => '1 сағат';

  @override
  String get statusUntilDay => 'Күн соңына дейін';

  @override
  String get statusUntilWeek => 'Апта соңына дейін';

  @override
  String get statusUntilPick => 'Күн мен уақытты таңдау';

  @override
  String statusUntilShort(String time) {
    return '$time дейін';
  }

  @override
  String get statusAutoReplyLabel => 'Автожауап (міндетті емес)';

  @override
  String get statusAutoReplyHint =>
      'Сізге жазған адамға жеке чатта келеді — әр чатқа күніне бір рет';

  @override
  String get statusDndHint =>
      'Мәртебе белсенді кезде хабарлама туралы push-хабарландырулар келмейді';

  @override
  String get statusClear => 'Мәртебені тазалау';

  @override
  String get statusSaved => 'Мәртебе орнатылды';

  @override
  String get statusCleared => 'Мәртебе тазаланды';

  @override
  String get statusInvalid =>
      'Мәртебені тексеріңіз: мәтін 70 таңбаға дейін, мерзім болашақта және бір жылдан аспауы керек';

  @override
  String get statusCustomRequired => 'Мәтін енгізіңіз немесе эмодзи таңдаңыз';

  @override
  String chatAutoReplyText(String text) {
    return 'Автожауап: $text';
  }

  @override
  String a11yStatus(String status) {
    return 'мәртебе: $status';
  }

  @override
  String get chatFoldersTitle => 'Чат қалталары';

  @override
  String get chatFoldersEdit => 'Қалталарды баптау';

  @override
  String get chatFoldersEmpty =>
      'Жұмыс чаттарын, топтарды немесе арналарды бөлек қойындыға жинаңыз';

  @override
  String get chatFolderNew => 'Жаңа қалта';

  @override
  String get chatFolderEditTitle => 'Қалтаны өзгерту';

  @override
  String get chatFolderName => 'Атауы';

  @override
  String get chatFolderEmoji => 'Қалта белгішесін таңдау';

  @override
  String get chatFolderTypes => 'Осы түрдегі барлық чаттар';

  @override
  String get chatFolderTypeDirect => 'Жеке';

  @override
  String get chatFolderUnreadOnly => 'Тек оқылмағандар';

  @override
  String get chatFolderExcludeMuted => 'Дыбысы өшірілген чаттарды жасыру';

  @override
  String get chatFolderChats => 'Қалтадағы чаттар';

  @override
  String chatFolderChatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count чат',
    );
    return '$_temp0';
  }

  @override
  String get chatFolderSearchChats => 'Чаттарды іздеу';

  @override
  String get chatFolderErrorName => 'Атауын енгізіңіз (32 таңбаға дейін)';

  @override
  String get chatFolderErrorEmpty =>
      'Чаттарды қосыңыз немесе чат түрін таңдаңыз';

  @override
  String get chatFolderErrorChats => 'Қалтада 200-ден аспайтын чат болады';

  @override
  String get chatFolderLimit => '10-нан аспайтын қалта жасауға болады';

  @override
  String get chatFolderDelete => 'Қалтаны жою';

  @override
  String chatFolderDeleteConfirm(String name) {
    return '«$name» қалтасын жою керек пе? Чаттар тізімде қалады.';
  }

  @override
  String get chatFolderReorder => 'Ретін өзгерту үшін сүйреңіз';

  @override
  String chatFolderUnreadChats(int count) {
    return 'оқылмаған чаттар: $count';
  }

  @override
  String get chatFoldersPending => 'Өзгерістер желі пайда болғанда сақталады';

  @override
  String get chatFoldersSaveFailed => 'Қалталарды сақтау мүмкін болмады';

  @override
  String get chatAddToFolder => 'Қалтаға қосу';

  @override
  String get chatVoiceModeTitle => 'Дауыстық хабар жазу';

  @override
  String get chatVoiceModeHold => 'Басып тұру';

  @override
  String get chatVoiceModeTap => 'Жазу үшін басу';

  @override
  String get chatVoiceModeHint =>
      'TalkBack қосулы болса, жазу әрдайым басу арқылы басталады';

  @override
  String get chatVoiceTapToRecord => 'Дауыстық хабар жазу';

  @override
  String get channelComments => 'Пікірлер';

  @override
  String get channelCommentsHint => 'Жазылушылар жазбаларды талқылай алады';

  @override
  String commentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count пікір',
    );
    return '$_temp0';
  }

  @override
  String get commentsLeave => 'Пікір қалдыру';

  @override
  String get commentsEmpty => 'Әзірге пікір жоқ — бірінші болып жазыңыз';

  @override
  String get commentsDisabled => 'Жазбаларға пікір өшірілген';

  @override
  String get commentsInvalidThread =>
      'Тек жазбаға немесе оның пікіріне жауап беруге болады';

  @override
  String get commentsPostUnavailable => 'Жазба жойылған немесе қолжетімсіз';

  @override
  String get scheduleWhenOnline => 'Желіге кіргенде';

  @override
  String get scheduleWhenOnlineHint => '7 күнге дейін күтеміз';

  @override
  String get scheduledWhenOnline => 'Желіге кіргенде';

  @override
  String get scheduledWhenOnlineCreated =>
      'Әңгімелесуші желіге кіргенде жіберіледі';

  @override
  String get scheduledWhenOnlineTimeout =>
      'Жіберілмеді: әңгімелесуші желіге кірмеді';

  @override
  String get scheduleWhenOnlineUnavailable =>
      'Әңгімелесуші желіде болғанын жасырады';

  @override
  String get officialTitle => 'Ресми хабарламалар';

  @override
  String get officialEmpty => 'Әзірге ресми хабарламалар жоқ';

  @override
  String get officialNoAccess => 'Ресми хабарламаларға рұқсат жоқ';

  @override
  String get officialNotFound => 'Хабарлама табылмады';

  @override
  String get officialUnread => 'Оқылмаған';

  @override
  String get officialRequiresAck => 'Танысуды талап етеді';

  @override
  String get officialAcknowledged => 'Таныстым';

  @override
  String get officialAcknowledgeButton => 'Таныстым';

  @override
  String officialAcknowledgedAt(String date) {
    return 'Сіз таныстыңыз: $date';
  }

  @override
  String get officialAckHint =>
      'Жіберуші хабарламамен танысқаныңызды растауды сұрайды.';

  @override
  String officialLimitNote(int count) {
    return 'Соңғы $count хабарлама көрсетілген';
  }

  @override
  String get officialNew => 'Жаңа хабарлама';

  @override
  String get officialReceivedTab => 'Кіріс';

  @override
  String get officialSentTab => 'Жіберілген';

  @override
  String get officialSentEmpty =>
      'Осы құрылғыдан жіберілген хабарламалар осында көрсетіледі';

  @override
  String officialRecipientCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count алушы',
    );
    return '$_temp0';
  }

  @override
  String officialSentToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Жіберілді, алушылар: $count',
    );
    return '$_temp0';
  }

  @override
  String get officialComposeTitle => 'Ресми хабарлама';

  @override
  String get officialFieldTitle => 'Тақырып';

  @override
  String get officialFieldBody => 'Хабарлама мәтіні';

  @override
  String get officialTitleRequired => 'Тақырыпты енгізіңіз';

  @override
  String get officialBodyRequired => 'Хабарлама мәтінін енгізіңіз';

  @override
  String get officialRequireAck => 'Танысуды талап ету';

  @override
  String get officialRequireAckHint =>
      'Әр алушы «Таныстым» батырмасын басуы керек';

  @override
  String get officialRecipients => 'Алушылар';

  @override
  String get officialRecipientsOrganization => 'Бүкіл ұйым';

  @override
  String get officialRecipientsDepartments => 'Бөлімдер';

  @override
  String get officialRecipientsUsers => 'Қызметкерлер';

  @override
  String get officialRecipientsRequired => 'Алушыларды таңдаңыз';

  @override
  String get officialSearchUsers => 'Қызметкерлерді іздеу';

  @override
  String get officialNoUsers => 'Ешкім табылмады';

  @override
  String get officialNoDepartments => 'Қолжетімді бөлімдер жоқ';

  @override
  String officialSelectedDone(int count) {
    return 'Дайын ($count)';
  }

  @override
  String get officialSend => 'Жіберу';

  @override
  String get officialStatsTitle => 'Статистика';

  @override
  String get officialStatsRecipients => 'Алушылар';

  @override
  String get officialStatsRead => 'Оқығандар';

  @override
  String get officialStatsAcknowledged => 'Танысқандар';

  @override
  String get officialStatsNoData =>
      'Деректер жоқ. Статистика тек хабарламаны жіберушіге қолжетімді.';

  @override
  String get officialStatsAggregateNote =>
      'Сервер алушылар тізімінсіз тек жалпы сандарды береді.';

  @override
  String get officialErrNotFound =>
      'Хабарлама табылмады немесе танысуды талап етпейді';

  @override
  String get officialErrInvalid => 'Тақырып пен хабарлама мәтінін толтырыңыз';

  @override
  String get officialErrInvalidRecipients =>
      'Алушыларды анықтау мүмкін болмады';

  @override
  String get officialErrNoRecipients =>
      'Таңдалғандар арасында белсенді пайдаланушылар жоқ';

  @override
  String get officialErrForbidden =>
      'Бұл алушыларға ресми хабарлама жіберуге құқық жеткіліксіз';

  @override
  String get officialErrNotSent =>
      'Сервер хабарламаны қабылдамады. Қайталап көріңіз.';

  @override
  String mailUxUnbookmarkedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count хат бетбелгіден алынды',
      one: '$count хат бетбелгіден алынды',
    );
    return '$_temp0';
  }

  @override
  String mailUxArchivedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count хат мұрағатқа жіберілді',
      one: '$count хат мұрағатқа жіберілді',
    );
    return '$_temp0';
  }

  @override
  String get mailUxSwipeSection => 'Хаттар тізіміндегі қимылдар';

  @override
  String get mailUxSwipeLeft => 'Солға сырғыту';

  @override
  String get mailUxSwipeRight => 'Оңға сырғыту';

  @override
  String get mailUxSwipeNone => 'Ештеңе';

  @override
  String get mailUxSwipeTrash => 'Себетке';

  @override
  String get mailUxSwipeArchive => 'Мұрағатқа';

  @override
  String get mailUxSwipeRead => 'Оқылды / оқылмады';

  @override
  String get mailUxSwipeBookmark => 'Бетбелгі';

  @override
  String get mailUxSwipeHint =>
      'Себет пен жобаларда «Себетке» сырғыту хатты растаудан кейін біржола жояды. Бірнеше хат таңдалғанда сырғыту өшіріледі.';

  @override
  String get mailUxSendSection => 'Жіберу';

  @override
  String get mailUxUndoSend => 'Жіберуден бас тарту';

  @override
  String get mailUxUndoSendOff => 'Өшірулі';

  @override
  String mailUxUndoSendSeconds(int seconds) {
    return '$seconds с';
  }

  @override
  String get mailUxUndoSendHint =>
      'хат кідірістен кейін жіберіледі, осы уақытта одан бас тартуға болады';

  @override
  String get mailUxSending => 'Хат жіберілуде…';

  @override
  String mailUxSendFailed(String error) {
    return 'Хат жіберілмеді: $error';
  }

  @override
  String get mailUxEdit => 'Өзгерту';

  @override
  String get mailUxAttachFile => 'Файл';

  @override
  String get mailUxAttachGallery => 'Галереядан фото не бейне';

  @override
  String get mailUxAttachCameraPhoto => 'Суретке түсіру';

  @override
  String get mailUxAttachCameraVideo => 'Бейне түсіру';

  @override
  String get mailUxRecentRecipient => 'Соңғы мекенжай';

  @override
  String get mailUxForwardToChat => 'Чатқа жіберу';

  @override
  String get mailUxForwardToChatAttachments =>
      'Чатқа қандай тіркемелер жіберу керек?';

  @override
  String get mailUxNext => 'Әрі қарай';

  @override
  String get mailUxDownloading => 'Тіркемелер жүктелуде…';

  @override
  String get mailUxChatDate => 'Күні';

  @override
  String get mailUxChatSubject => 'Тақырып';

  @override
  String get mailUxChatFrom => 'Кімнен';

  @override
  String get mailUxSendByMail => 'Поштамен жіберу';

  @override
  String get tasksTitle => 'Тапсырмалар';

  @override
  String get tasksScreenTitle => 'Менің тапсырмаларым';

  @override
  String get tasksSectionMine => 'Маған';

  @override
  String get tasksSectionAssigned => 'Мен тапсырдым';

  @override
  String tasksSectionDone(int count) {
    return 'Орындалғандар · $count';
  }

  @override
  String get tasksEmpty => 'Тапсырмалар жоқ';

  @override
  String get tasksEmptyHint =>
      'Тапсырма жасаңыз немесе хатты тапсырмаларға қосыңыз';

  @override
  String get tasksUnavailable =>
      'Тапсырмалар сіздің тіркелгіңіз үшін қолжетімсіз';

  @override
  String get tasksNew => 'Жаңа тапсырма';

  @override
  String get tasksEdit => 'Тапсырманы өзгерту';

  @override
  String get tasksDetails => 'Тапсырма';

  @override
  String get tasksFieldTitle => 'Атауы';

  @override
  String get tasksFieldDescription => 'Сипаттама';

  @override
  String get tasksFieldDue => 'Мерзімі';

  @override
  String get tasksFieldReminder => 'Еске салу';

  @override
  String get tasksFieldAssignee => 'Орындаушы';

  @override
  String get tasksFieldPriority => 'Басымдық';

  @override
  String get tasksNoDue => 'Мерзімсіз';

  @override
  String get tasksNoReminder => 'Еске салусыз';

  @override
  String get tasksAssigneeSelf => 'Мен';

  @override
  String get tasksAssigneePick => 'Кімге тапсыру';

  @override
  String get tasksAssigneeSearch => 'Қызметкерді іздеу';

  @override
  String get tasksAssigneeEmpty => 'Сіздің бөлімдеріңізде қызметкерлер жоқ';

  @override
  String get tasksPriorityLow => 'Төмен';

  @override
  String get tasksPriorityNormal => 'Қалыпты';

  @override
  String get tasksPriorityHigh => 'Жоғары';

  @override
  String get tasksPriorityUrgent => 'Шұғыл';

  @override
  String get tasksOverdue => 'Мерзімі өтті';

  @override
  String get tasksDueToday => 'Бүгін';

  @override
  String tasksDueOn(String date) {
    return '$date дейін';
  }

  @override
  String tasksAssignedTo(String name) {
    return 'Орындаушы: $name';
  }

  @override
  String tasksAssignedBy(String name) {
    return 'Тапсырған: $name';
  }

  @override
  String get tasksAssignedToColleague => 'Қызметкерге тапсырылды';

  @override
  String get tasksReminderFixed =>
      'Еске салу тек тапсырма жасалғанда орнатылады';

  @override
  String get tasksReadOnly => 'Тапсырманы тек орындаушы өзгерте және жоя алады';

  @override
  String get tasksTitleRequired => 'Атауын енгізіңіз';

  @override
  String get tasksClear => 'Алып тастау';

  @override
  String get tasksCreate => 'Жасау';

  @override
  String get tasksDelete => 'Тапсырманы жою';

  @override
  String tasksDeleteConfirm(String title) {
    return '«$title» тапсырмасын жою керек пе? Оның еске салулары да жойылады.';
  }

  @override
  String get tasksDeleted => 'Тапсырма жойылды';

  @override
  String get tasksCreated => 'Тапсырма жасалды';

  @override
  String get tasksSaved => 'Тапсырма сақталды';

  @override
  String get tasksMarkDone => 'Орындалды деп белгілеу';

  @override
  String get tasksMarkUndone => 'Жұмысқа қайтару';

  @override
  String get tasksOpenMessage => 'Хатты ашу';

  @override
  String get tasksOpen => 'Ашу';

  @override
  String get tasksNotFound => 'Тапсырма табылмады';

  @override
  String get tasksErrInvalid => 'Тапсырма өрістерін тексеріңіз';

  @override
  String get tasksErrOwner => 'Қызметкер сіздің ұйымыңызда жоқ';

  @override
  String get tasksErrReminder => 'Еске салуды сақтау мүмкін болмады';

  @override
  String get tasksErrForbidden => 'Бұл қызметкерге тапсырма беруге құқық жоқ';

  @override
  String get taskBoardsTitle => 'Тақталар';

  @override
  String get taskBoardPersonal => 'Менің тапсырмаларым';

  @override
  String get taskBoardNew => 'Жаңа тақта';

  @override
  String get taskBoardCreate => 'Тақта құру';

  @override
  String get taskBoardRename => 'Тақта атын өзгерту';

  @override
  String get taskBoardName => 'Тақта атауы';

  @override
  String get taskBoardNameHint => 'Мысалы: Қабылдау науқаны';

  @override
  String get taskBoardDescription => 'Сипаттама';

  @override
  String get taskBoardColor => 'Түс';

  @override
  String get taskBoardShare => 'Ортақ қолжетімділік';

  @override
  String get taskBoardDelete => 'Тақтаны жою';

  @override
  String taskBoardDeleteConfirm(String name) {
    return '«$name» тақтасы жойылсын ба? Тапсырмалары «Менің тапсырмаларыма» оралады, әріптестер оларға қолжетімділігін жоғалтады.';
  }

  @override
  String get taskBoardDeleted => 'Тақта жойылды';

  @override
  String get taskBoardCreated => 'Тақта құрылды';

  @override
  String get taskBoardSaved => 'Тақта сақталды';

  @override
  String get taskBoardShared => 'Қолжетімділік жаңартылды';

  @override
  String get taskBoardNameRequired => 'Тақта атауын енгізіңіз';

  @override
  String taskBoardOwnedBy(String name) {
    return '$name тақтасы';
  }

  @override
  String get taskBoardRoleEditor => 'Өзгерте алады';

  @override
  String get taskBoardRoleViewer => 'Тек қарау';

  @override
  String get taskBoardReadOnly => 'Бұл тақта сізге тек қарауға ашық';

  @override
  String taskBoardShareTitle(String name) {
    return '«$name» тақтасына қолжетімділік';
  }

  @override
  String get taskBoardShareHint =>
      'Қатысушылар тақта тапсырмаларын көреді. Редакторлар оларды құрып, өзгерте алады, бақылаушылар тек оқиды.';

  @override
  String get taskBoardShareSearch => 'Қызметкерді іздеу';

  @override
  String get taskBoardShareEmpty => 'Тақта әзірге ешкімге ашылмаған';

  @override
  String taskBoardShareMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count қатысушы',
      zero: 'Қатысушы жоқ',
    );
    return '$_temp0';
  }

  @override
  String get taskBoardRemoveMember => 'Қолжетімділікті алу';

  @override
  String get taskBoardEmpty => 'Бұл тақтада әзірге тапсырма жоқ';

  @override
  String get taskBoardMoveHere => 'Осында көшіру';

  @override
  String taskBoardMoved(String name) {
    return 'Тапсырма көшірілді: $name';
  }

  @override
  String taskBoardOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count тапсырма',
      zero: 'Тапсырма жоқ',
    );
    return '$_temp0';
  }

  @override
  String get taskBoardErrNotFound => 'Тақта табылмады';

  @override
  String get taskBoardErrForbidden => 'Бұл тақтаны өзгертуге құқық жоқ';

  @override
  String get taskBoardErrName =>
      'Тақта атауы 1-ден 120 таңбаға дейін болуы керек';

  @override
  String get taskBoardErrMember => 'Қызметкер сіздің ұйымыңызда жоқ';

  @override
  String get taskBoardsRailHide => 'Тақталар тізімін жасыру';

  @override
  String get taskBoardsRailShow => 'Тақталар тізімін көрсету';

  @override
  String get translateAction => 'Аудару';

  @override
  String get translateMail => 'Хатты аудару';

  @override
  String get translateInProgress => 'Аударылуда…';

  @override
  String get translateFailed => 'Аудару мүмкін болмады';

  @override
  String get translateRetry => 'Қайталау';

  @override
  String get translateShowOriginal => 'Түпнұсқаны көрсету';

  @override
  String translateLabel(String from, String to) {
    return 'Аударма: $from → $to';
  }

  @override
  String translateSameLanguage(String language) {
    return 'Мәтін осы тілде: $language';
  }

  @override
  String get translateLangRu => 'орыс тілі';

  @override
  String get translateLangKk => 'қазақ тілі';

  @override
  String get translateLangEn => 'ағылшын тілі';

  @override
  String translateAutoInChat(String language) {
    return 'Автоматты түрде аудару: $language';
  }

  @override
  String get translateAutoInChatHint =>
      'Басқа тілдегі кіріс хабарламалар, осы құрылғыда';

  @override
  String get translateTargetSetting => 'Аударма тілі';

  @override
  String translateTargetAppLanguage(String language) {
    return 'Қолданбадағыдай ($language)';
  }

  @override
  String get translateUnavailable =>
      'Аудару қазір қолжетімсіз. Кейінірек қайталаңыз.';

  @override
  String get translateTooLong => 'Мәтін аудару үшін тым ұзын';

  @override
  String get translateRateLimited =>
      'Аудармалар тым көп. Кейінірек қайталаңыз.';

  @override
  String translateMailProgress(int done, int total) {
    return 'Аударма: $done / $total';
  }

  @override
  String get searchEverywhere => 'Барлық жерден іздеу';

  @override
  String get searchHint => 'Адамдар, чаттар, пошта, оқиғалар';

  @override
  String get searchIntro =>
      'Адамдар, чаттар, пошта және күнтізбе бойынша бірден іздеңіз';

  @override
  String get searchRecent => 'Соңғылар';

  @override
  String get searchRecentClear => 'Тазалау';

  @override
  String get searchRecentRemove => 'Тарихтан жою';

  @override
  String get searchSectionPeople => 'Адамдар';

  @override
  String get searchSectionChats => 'Чаттар';

  @override
  String get searchSectionMail => 'Пошта';

  @override
  String get searchSectionEvents => 'Оқиғалар';

  @override
  String get searchShowAll => 'Барлығын көрсету';

  @override
  String get searchSectionError => 'Іздеу орындалмады';

  @override
  String get searchEmpty => 'Ештеңе табылмады';

  @override
  String get searchNothingAvailable =>
      'Іздеу сіздің тіркелгіңіз үшін қолжетімсіз';

  @override
  String get searchOfflineHint => 'Желіден тыс — тек сақталғандар';

  @override
  String get searchNoSubject => '(тақырыпсыз)';

  @override
  String get todayTab => 'Бүгін';

  @override
  String get todayStartScreen => 'Бастапқы экран';

  @override
  String get todayStartScreenHint =>
      'Іске қосқанда ашылатын қойынды. «Бүгін» күн шолуы бар қойынды қосады.';

  @override
  String get todayGreetingMorning => 'Қайырлы таң';

  @override
  String get todayGreetingAfternoon => 'Қайырлы күн';

  @override
  String get todayGreetingEvening => 'Қайырлы кеш';

  @override
  String get todayGreetingNight => 'Қайырлы түн';

  @override
  String get todayMailTitle => 'Оқылмаған пошта';

  @override
  String get todayMailEmpty => 'Барлық хаттар оқылды';

  @override
  String get todayChatsTitle => 'Оқылмаған чаттар';

  @override
  String get todayChatsEmpty => 'Жаңа хабарлар жоқ';

  @override
  String get todayEventsTitle => 'Бүгін күнтізбеде';

  @override
  String get todayEventsEmpty => 'Бүгін басқа оқиғалар жоқ';

  @override
  String get todayJoin => 'Қосылу';

  @override
  String get todayMissedCallsTitle => 'Қабылданбаған қоңыраулар';

  @override
  String get todayMissedCallsEmpty => 'Бүгін өткізіп алынғандар жоқ';

  @override
  String get todayNewMail => 'Хат';

  @override
  String get todayNewChat => 'Хабар';

  @override
  String get todayNewCall => 'Қоңырау';

  @override
  String get callsShareChoose => 'Нені көрсету керек';

  @override
  String get callsShareEntireScreen => 'Бүкіл экран';

  @override
  String get callsShareWindow => 'Терезе';

  @override
  String get callsShareStart => 'Көрсету';

  @override
  String get desktopTrayOpen => 'XatBox-ты ашу';

  @override
  String get desktopTrayQuit => 'XatBox-тан шығу';

  @override
  String get desktopSearch => 'Іздеу';

  @override
  String get desktopMore => 'Тағы';

  @override
  String get contactsSelect => 'Профильді ашу үшін қызметкерді таңдаңыз';

  @override
  String get callsSelect => 'Карточканы ашу үшін қоңырауды таңдаңыз';

  @override
  String get desktopRefresh => 'Жаңарту';

  @override
  String get desktopPrevious => 'Артқа';

  @override
  String get desktopNext => 'Алға';

  @override
  String get aboutPrivacyPushBodyDesktop =>
      'Компьютерде хабарландырулар Google мен Apple-сыз, ұйым серверінен қорғалған байланыс арқылы тікелей келеді.';

  @override
  String get remindersEmptyHintDesktop =>
      'Хабарламаны тінтуірдің оң жақ батырмасымен басып, «Еске салу» таңдаңыз';

  @override
  String get chatProtectionScreenshotsHintDesktop =>
      'Компьютерде терезе жиналғанда чат жасырылады';

  @override
  String get settingsLockWindowsHello => 'Windows Hello арқылы ашу';

  @override
  String get composeMinimize => 'Жию';

  @override
  String get composeExpand => 'Кеңейту';

  @override
  String get composeRestoreSize => 'Өлшемін қалпына келтіру';

  @override
  String get composeSaveAndClose => 'Сақтап жабу';

  @override
  String get composeAddCcBcc => 'Көшірме / Жасырын көшірме';

  @override
  String get desktopCollapseSidebar => 'Мәзірді жию';

  @override
  String get desktopExpandSidebar => 'Мәзірді ашу';

  @override
  String get desktopZoom => 'Масштаб';

  @override
  String get desktopZoomHint =>
      'Бүкіл интерфейстің өлшемі. Пернелер: Ctrl + плюс, Ctrl + минус, Ctrl + 0.';

  @override
  String get desktopZoomReset => 'Қалпына келтіру';

  @override
  String get desktopNotifTest => 'Хабарландыруды тексеру';

  @override
  String get desktopNotifTestHint => 'Жүйелік сынақ хабарландыруын көрсету';

  @override
  String get desktopNotifTestBody => 'Хабарландырулар жұмыс істейді';

  @override
  String get desktopNotifTestSent =>
      'Хабарландыру жіберілді. Көрінбесе, жүйе баптауларында XatBox хабарландыруларын қосып, «Мазаламау» режимін өшіріңіз.';

  @override
  String desktopNotifTestFailed(String error) {
    return 'Жүйе хабарландыруды көрсетпеді: $error';
  }

  @override
  String get desktopSettingsIntro =>
      'Профиль, көрініс, хабарландырулар және қауіпсіздік. Өзгерістер бірден сақталады.';

  @override
  String get updateInstallFailedDesktop =>
      'Жаңарту орнатқышын іске қосу мүмкін болмады';

  @override
  String desktopCalendarMore(int count) {
    return '+$count тағы';
  }

  @override
  String get desktopCalendarSelectedDay => 'Таңдалған күн';

  @override
  String composeDraftSavedAt(String time) {
    return 'Жоба сақталды $time';
  }

  @override
  String get desktopShortcutsTitle => 'Пернетақта тіркесімдері';

  @override
  String get desktopShortcutsMail => 'Хаттар';

  @override
  String get desktopShortcutsEverywhere => 'Барлық жерде';

  @override
  String get desktopShortcutNext => 'Келесі хат';

  @override
  String get desktopShortcutPrevious => 'Алдыңғы хат';

  @override
  String get desktopShortcutOpen => 'Хатты ашу';

  @override
  String get desktopShortcutClose => 'Хатты жабу';

  @override
  String get desktopShortcutReadToggle => 'Оқылды / оқылмады';

  @override
  String get desktopShortcutSend => 'Хатты жіберу';

  @override
  String get desktopShortcutModules =>
      'Пошта · Чат · Қоңыраулар · Күнтізбе · Контактілер';

  @override
  String get desktopShortcutZoom => 'Масштаб: үлкейту · кішірейту · бастапқы';

  @override
  String get desktopPrint => 'Басып шығару';

  @override
  String get desktopPrintFailed => 'Хатты басып шығаруға ашу мүмкін болмады';

  @override
  String get desktopOpenInWindow => 'Бөлек терезеде ашу';

  @override
  String get desktopDefaultMailApp => 'Әдепкі пошта бағдарламасы';

  @override
  String get desktopDefaultMailAppHint =>
      'Браузер мен құжаттардағы пошта сілтемелері (mailto:) XatBox-та жаңа хат ашады. Windows параметрлері ашылады: MAILTO үшін XatBox-ты таңдаңыз.';

  @override
  String get desktopAppSection => 'Компьютерге арналған қолданба';

  @override
  String get updateRestartNow => 'Қайта іске қосып, жаңарту';

  @override
  String get updateOnQuit => 'Шыққанда жаңарту';

  @override
  String get updateOnQuitScheduled =>
      'Жаңарту XatBox-тан шыққанда орнатылады: трейдегі белгіше → «XatBox-тан шығу».';

  @override
  String get updateManagedByAdmin =>
      'XatBox компьютердің барлық пайдаланушылары үшін орнатылған. Жаңа нұсқаларды әкімші орнатады.';

  @override
  String get desktopPrintDate => 'Күні';

  @override
  String get desktopPrintAttachments => 'Тіркемелер';

  @override
  String get desktopDefaultMailAppHintMac =>
      'Браузер мен құжаттардағы пошта сілтемелері (mailto:) XatBox-та жаңа хат ашады. macOS растауды сұрайды.';

  @override
  String get desktopDefaultMailAppDone =>
      'Енді mailto: сілтемелерін XatBox ашады';

  @override
  String desktopMailMore(int count) {
    return 'Тағы жаңа хаттар: $count';
  }

  @override
  String get desktopMailNotifications => 'Жаңа хаттар туралы хабарлау';

  @override
  String get desktopMailNotificationsHint =>
      'XatBox жабық немесе басқа бөлімде болғанда «Жауап беру», «Оқылды», «Жою» түймелері бар хабарландыру';

  @override
  String get desktopFileHint => 'Қалтаға сүйреңіз · Бос орын — жылдам қарау';

  @override
  String get desktopEmlUnreadable => 'Хат файлын оқу мүмкін болмады';

  @override
  String get desktopAwayStatus => 'Орнымда жоқпын';

  @override
  String get desktopMiniCallMute => 'Микрофонды өшіру';

  @override
  String get desktopMiniCallUnmute => 'Микрофонды қосу';

  @override
  String get desktopMiniCallEnd => 'Аяқтау';

  @override
  String get desktopMiniCallExpand => 'Жаю';

  @override
  String get desktopLaunchAtLogin => 'Жүйеге кіргенде іске қосу';

  @override
  String get desktopLaunchAtLoginHint =>
      'XatBox трейге жиналған күйде іске қосылып, хаттар мен хабарламаларды бірден алады';

  @override
  String get desktopLaunchAtLoginManaged =>
      'Компьютердің барлық пайдаланушылары үшін әкімші қосқан';

  @override
  String get desktopGlobalHotkeys => 'Жаһандық пернелер тіркесімі';

  @override
  String desktopGlobalHotkeysHint(String compose, String show) {
    return '$compose — жаңа хат, $show — XatBox-ты көрсету, кез келген бағдарламадан';
  }

  @override
  String get desktopAutoAway => '«Орнымда жоқпын» мәртебесі автоматты түрде';

  @override
  String get desktopAutoAwayHint =>
      'Компьютер құлыпталғанда немесе 10 минут әрекетсіз тұрғанда. Өзіңіз қойған мәртебе өзгермейді';

  @override
  String get desktopMiniCall => 'Қоңыраудың шағын терезесі';

  @override
  String get desktopMiniCallHint =>
      'Басқа бағдарламаға ауысқанда қоңырау барлық терезелердің үстінде шағын терезеде қалады';

  @override
  String get desktopNotificationSound => 'Хабарландыру дыбысы';

  @override
  String get desktopNotificationSoundHint =>
      'Чаттағы жаңа хабарламалар мен жаңа хаттар';

  @override
  String get desktopSoundXatbox => 'XatBox';

  @override
  String get desktopSoundSystem => 'Жүйелік';

  @override
  String get desktopSoundNone => 'Дыбыссыз';

  @override
  String get desktopRingtone => 'Қоңырау әуені';

  @override
  String get desktopRingtoneHint => 'Кіріс қоңырау';

  @override
  String get desktopRingtoneClassic => 'Классикалық';

  @override
  String get desktopSoundPreview => 'Тыңдау';

  @override
  String get chatWritePersonally => 'Жеке жазу';

  @override
  String get chatMemberActions => 'Қатысушы';

  @override
  String get desktopBetaUpdates => 'Бета нұсқаларды алу';

  @override
  String get desktopBetaUpdatesHint =>
      'Жаңа нұсқалар бірден, басқалардан бір күн бұрын келеді. Оларда қателер болуы мүмкін.';

  @override
  String get updateDownloadOnly => 'Жүктеп алу';

  @override
  String get updateLinuxOpen => 'Пакетті ашу';

  @override
  String get updateLinuxOpened => 'Пакет орнатушыда ашылды';

  @override
  String get updateLinuxOpenedHint =>
      'Оны орнатыңыз (әкімші құпиясөзі қажет) және XatBox-ты қайта іске қосыңыз. .deb файлы «Жүктелгендер» қалтасында сақталды.';

  @override
  String get desktopSpellCheck => 'Хаттардағы емле тексеру';

  @override
  String get desktopSpellCheckHint =>
      'Қателердің асты сызылады, нұсқалар — оң жақ түймемен. Жүйе сөздіктері: орыс, ағылшын, қазақ (орнатылса)';

  @override
  String get desktopShortcutQuickLook => 'Меңзердегі тіркемені жылдам қарау';

  @override
  String get desktopShortcutGlobalCompose =>
      'Кез келген бағдарламадан жаңа хат';

  @override
  String get desktopShortcutGlobalShow =>
      'Кез келген бағдарламадан XatBox-ты көрсету';

  @override
  String get desktopCalendarOpen => 'Ашу';

  @override
  String get desktopCalendarGoToDate => 'Күнге өту';

  @override
  String get desktopCalendarNewHere => 'Осы жерде оқиға құру';

  @override
  String desktopCalendarWeekNumber(int week) {
    return '$week-апта';
  }

  @override
  String get desktopSelectMessageToRead => 'Оқу үшін хатты таңдаңыз';

  @override
  String get desktopSelectMessageToReadHint =>
      'Тізімнен хатты таңдаңыз. Ол осы жерде ашылады.';

  @override
  String get desktopProfileFullName => 'Толық аты';

  @override
  String get desktopRoleMember => 'Қызметкер';

  @override
  String get desktopRoleUserManager => 'Пайдаланушылар менеджері';

  @override
  String get desktopRoleOrgAdmin => 'Ұйым әкімшісі';

  @override
  String get desktopRoleDomainAdmin => 'Домен әкімшісі';

  @override
  String get desktopRoleDeveloper => 'Әзірлеуші';

  @override
  String get desktopRoleSecurityAnalyst => 'Қауіпсіздік талдаушысы';

  @override
  String get desktopRoleAuditor => 'Аудитор';

  @override
  String get desktopRoleSupport => 'Қолдау';

  @override
  String get desktopRoleTenantOwner => 'Тенант иесі';

  @override
  String get desktopRoleSuperAdmin => 'Суперәкімші';

  @override
  String get desktopRolePlatformSuperAdmin => 'Платформа суперәкімшісі';

  @override
  String get desktopContactMeeting => 'Кездесу';

  @override
  String get desktopContactScheduleMeeting => 'Кездесу тағайындау';

  @override
  String get desktopContactCopyAddress => 'Мекенжайды көшіру';

  @override
  String get desktopCalendarEmailParticipants => 'Қатысушыларға жазу';

  @override
  String get desktopCalendarExternalGroup => 'Сыртқы қатысушылар';

  @override
  String get desktopCalendarNoDepartment => 'Бөлімсіз';

  @override
  String get desktopPaletteHint => 'Команда, бөлім немесе іздеу…';

  @override
  String desktopPaletteSearch(String query) {
    return '«$query» барлық жерден іздеу';
  }

  @override
  String get desktopPaletteToggleTheme => 'Ашық / қараңғы тақырыпты ауыстыру';

  @override
  String get desktopPaletteGoTo => 'Өту';

  @override
  String get desktopPaletteCreate => 'Құру';

  @override
  String get desktopPaletteNothing => 'Ештеңе табылмады';

  @override
  String get desktopCallStart => 'Қоңырау шалу';

  @override
  String get desktopCallWithVideo => 'Бейнемен';

  @override
  String get desktopCallShortcuts => 'Қоңырау';

  @override
  String get desktopMailSettingsShortcuts => 'Пернелер';

  @override
  String get desktopMailSettingsShortcutsHint =>
      'Тінтуірсіз жұмыс істеңіз. Осы тізімді ашу үшін кез келген жерде ? басыңыз.';

  @override
  String get desktopMailKeysCalendarPrevNext => 'Алдыңғы / келесі кезең';

  @override
  String get desktopMailKeysCalendarClosePanel => 'Оқиға панелін жабу';

  @override
  String get desktopMailRestored => 'Қайтарылды';

  @override
  String get desktopCrashTitle => 'XatBox күтпеген жерден жабылды';

  @override
  String get desktopCrashBody =>
      'Өткен жолы бағдарлама қатемен аяқталды. Оның соңғы әрекеттерінің журналын әзірлеушілерге жіберу керек пе? Онда хаттар мен хабарламалардың мәтіні, құпиясөздер мен мекенжайлар жоқ.';

  @override
  String get desktopCrashSend => 'Жіберу';

  @override
  String get desktopCrashSkip => 'Жібермеу';

  @override
  String get desktopCrashSent => 'Рахмет, есеп жіберілді';

  @override
  String desktopCrashReport(String version, String time) {
    return 'Автоесеп: XatBox $version күтпеген жерден жабылды (іске қосылған уақыты $time)';
  }

  @override
  String desktopMailMovedTo(String folder) {
    return '«$folder» қалтасына жылжытылды';
  }

  @override
  String get desktopMailHideList => 'Хаттар тізімін жасыру';

  @override
  String get desktopMailShowList => 'Хаттар тізімін көрсету';

  @override
  String get desktopMailLinkElsewhereTitle => 'Сілтеме басқа сайтқа апарады';

  @override
  String desktopMailLinkElsewhereBody(String shown, String real) {
    return 'Мәтінде бір мекенжай көрсетілген, ал басқасы ашылады. Бәрібір ашу керек пе?\n\nКөрсетілген: $shown\nАшылады: $real';
  }

  @override
  String get desktopMailLinkOpenAnyway => 'Бәрібір ашу';

  @override
  String desktopMailQuickReplyHint(String keys) {
    return 'Жауап жазыңыз… (жіберу үшін $keys)';
  }

  @override
  String get desktopMailQuickReplyAttach => 'Файл тіркеу';

  @override
  String get desktopMailQuickReplyUploading => 'Жүктелуде…';

  @override
  String get desktopMailQuickReplyUploadFailed => 'Жүктеу сәтсіз';

  @override
  String get desktopMailQuickReplyRemoveFile => 'Файлды алып тастау';

  @override
  String desktopMailQuickReplySentTo(String recipients, String time) {
    return 'Жіберілді: $recipients · $time';
  }

  @override
  String get desktopShortcutPalette => 'Командалар палитрасы';

  @override
  String get desktopChatCreate => 'Құру';

  @override
  String get desktopChatDetails => 'Мәліметтер';

  @override
  String get mailOutboxQueued =>
      'Желі жоқ — хат «Шығыс» қалтасында, байланыс болғанда жіберіледі';

  @override
  String mailOutboxTitle(int count) {
    return 'Шығыс: $count';
  }

  @override
  String get mailOutboxHint => 'байланыс болғанда автоматты түрде жіберіледі';

  @override
  String get mailOutboxWaiting => 'Желіні күтуде';

  @override
  String get mailOutboxSending => 'Жіберілуде…';

  @override
  String mailOutboxFailed(String error) {
    return 'Жіберілмеді: $error';
  }

  @override
  String get mailOutboxSendNow => 'Қазір жіберу';

  @override
  String get mailOutboxDiscard => '«Шығыс» қалтасынан жою';

  @override
  String mailOutboxSent(int count) {
    return '«Шығыс» хаттары жіберілді: $count';
  }

  @override
  String get skinGlassForest => 'Орман әйнегі';

  @override
  String get skinGlassForestHint => 'Таңғы орман үстіндегі мөлдір панельдер';

  @override
  String get skinGlassSpace => 'Ғарыш';

  @override
  String get skinGlassSpaceHint => 'Жұлдызды аспан үстіндегі мөлдір панельдер';

  @override
  String get desktopEventTitleHint => 'Атауын жазыңыз';

  @override
  String desktopEventDurationMinutes(int count) {
    return '$count мин';
  }

  @override
  String desktopEventDurationHours(int count) {
    return '$count сағ';
  }

  @override
  String desktopEventDurationHoursMinutes(int hours, int minutes) {
    return '$hours сағ $minutes мин';
  }

  @override
  String get desktopEventParticipantsHint =>
      'Әріптестерді шақырыңыз: аты немесе email';

  @override
  String desktopEventInviteEmail(String email) {
    return '$email шақыру';
  }

  @override
  String get desktopEventLocationHint => 'Орнын қосу';

  @override
  String get desktopEventDescriptionHint => 'Сипаттама немесе күн тәртібі';

  @override
  String get desktopEventMore => 'Тағы: сілтеме, мәжіліс бөлмесі, уақыт таңдау';

  @override
  String get desktopEventLess => 'Қосымша баптауларды жасыру';

  @override
  String get desktopEventRepeatCustom => 'Баптау…';

  @override
  String desktopEventSaveHint(String keys) {
    return '$keys — сақтау';
  }

  @override
  String get desktopEventReminder => 'Еске салу';

  @override
  String get desktopEventOtherTime => 'Басқа уақыт…';

  @override
  String get desktopEventNoReminders => 'Еске салусыз';

  @override
  String get tasksBoardByDue => 'Мерзімі бойынша';

  @override
  String get tasksBoardByStatus => 'Күйі бойынша';

  @override
  String get tasksColumnTomorrow => 'Ертең';

  @override
  String get tasksColumnLater => 'Кейінірек';

  @override
  String get tasksColumnDone => 'Дайын';

  @override
  String get tasksColumnTodo => 'Орындалуы тиіс';

  @override
  String get tasksColumnInProgress => 'Жұмыста';

  @override
  String get tasksQuickAdd => 'Тапсырма қосу';

  @override
  String get tasksQuickAddHint => 'Не істеу керек? Enter — қосу';

  @override
  String get tasksDropHere => 'Тапсырманы осында сүйреңіз';

  @override
  String get tasksBoardHintDue =>
      'Карточкаларды бағандар арасында сүйреңіз — мерзімі өзі өзгереді';

  @override
  String get tasksBoardHintStatus =>
      'Күйін өзгерту үшін карточкаларды сүйреңіз';

  @override
  String tasksStatToday(int count) {
    return 'Бүгінге: $count';
  }

  @override
  String tasksStatOverdue(int count) {
    return 'Мерзімі өткен: $count';
  }

  @override
  String tasksStatDone(int count) {
    return 'Орындалды: $count';
  }

  @override
  String tasksShowAll(int count) {
    return 'Барлығын көрсету · $count';
  }

  @override
  String get tasksShowLess => 'Жию';

  @override
  String get tasksPickDay => 'Қай күнге ауыстыру керек?';

  @override
  String get tasksSearchHint => 'Тапсырмалардан іздеу';

  @override
  String get tasksFromMail => 'Хаттан';

  @override
  String get tasksMarkInProgress => 'Жұмысқа алу';

  @override
  String get tasksArchive => 'Мұрағатқа';

  @override
  String get tasksArchived => 'Тапсырма мұрағатқа жіберілді';

  @override
  String get tasksRestore => 'Қайтару';

  @override
  String get tasksRestored => 'Тапсырма тақтаға қайтарылды';

  @override
  String get tasksArchiveTitle => 'Мұрағат';

  @override
  String get tasksArchiveEmpty =>
      'Мұрағат әзірге бос. Дайын тапсырмаларды карточка мәзірінен осында жіберуге болады.';

  @override
  String get tasksArchiveAllBoards => 'Барлық тақталар';

  @override
  String get tasksArchiveThisBoard => 'Тек осы тақта';

  @override
  String get myContactsTitle => 'Менің контактілерім';

  @override
  String get myContactsAllStaff => 'Барлық қызметкерлер';

  @override
  String get myContactsDepartments => 'Бөлімдер';

  @override
  String get myContactsNew => 'Жаңа контакт';

  @override
  String get myContactsPin => 'Менің контактілеріме қосу';

  @override
  String get myContactsUnpin => 'Менің контактілерімнен алып тастау';

  @override
  String myContactsPinned(String name) {
    return '$name — сіздің контактілеріңізде';
  }

  @override
  String get myContactsEmptyTitle => 'Мұнда сіздің контактілеріңіз болады';

  @override
  String get myContactsEmptyHint =>
      'Қызметкерлер тізімінде әріптестерді жұлдызшамен бекітіңіз немесе университеттен тыс адамды қосыңыз';

  @override
  String get myContactsBrowseStaff => 'Қызметкерлерді ашу';

  @override
  String get myContactsSectionStaff => 'Қызметкерлер';

  @override
  String get myContactsSectionPersonal => 'Жеке контактілер';

  @override
  String get myContactsPersonalTag => 'Жеке';

  @override
  String get myContactsSelect => 'Толығырақ көру үшін контактіні таңдаңыз';

  @override
  String get myContactsNothingFound => 'Ешкім табылмады';

  @override
  String get personalContactName => 'Аты-жөні';

  @override
  String get personalContactNameRequired => 'Атын енгізіңіз';

  @override
  String get personalContactEmail => 'Email';

  @override
  String get personalContactEmailInvalid => 'Пошта мекенжайын тексеріңіз';

  @override
  String get personalContactPhone => 'Телефон';

  @override
  String get personalContactOrganization => 'Ұйым';

  @override
  String get personalContactPosition => 'Лауазымы';

  @override
  String get personalContactNote => 'Жазба';

  @override
  String get personalContactEdit => 'Контактіні өзгерту';

  @override
  String get personalContactDelete => 'Контактіні жою';

  @override
  String personalContactDeleteConfirm(String name) {
    return '«$name» контактілеріңізден жойылсын ба?';
  }

  @override
  String get personalContactSaved => 'Контакт сақталды';

  @override
  String get personalContactDeleted => 'Контакт жойылды';

  @override
  String get personalContactLocalNote =>
      'Жеке контактілер осы компьютерде сақталады';

  @override
  String get personalContactCall => 'Қоңырау шалу';

  @override
  String get skinGlassAstana => 'Астана';

  @override
  String get skinGlassAstanaHint =>
      'Астана фотосуреті үстіндегі мөлдір панельдер';

  @override
  String get skinGlassSemey => 'Семей';

  @override
  String get skinGlassSemeyHint =>
      'Ертіс үстіндегі көпір фотосуретінің үстінде мөлдір панельдер';

  @override
  String get skinGlassCustom => 'Өз фоным';

  @override
  String get skinGlassCustomHint => 'Өз суретіңіздің үстінде мөлдір панельдер';

  @override
  String get settingsBackdropOwn => 'Өз суретіңіз';

  @override
  String get settingsBackdropOwnHint =>
      'Сурет XatBox қалтасына көшірілді, түпнұсқаны жоюға болады';

  @override
  String get settingsBackdropNone => 'Сурет таңдалмаған — әзірге қара фон';

  @override
  String get settingsBackdropPick => 'Сурет таңдау';

  @override
  String get settingsBackdropReplace => 'Суретті ауыстыру';

  @override
  String get settingsBackdropRemove => 'Алып тастау';

  @override
  String get settingsBackdropDim => 'Күңгірттеу';

  @override
  String get settingsBackdropBlur => 'Бұлдырлату';

  @override
  String get settingsBackdropFailed => 'Суретті оқу мүмкін болмады';

  @override
  String get settingsBackdropCredits => 'Фон суреттері';

  @override
  String get settingsBackdropCreditAstana =>
      '«Астана» — Dauren Nabijan суреті, CC0, Wikimedia Commons';

  @override
  String get settingsBackdropCreditSemey =>
      '«Семей» — Иван Быков суреті, CC BY 3.0, қиылған, Wikimedia Commons';

  @override
  String get mailSettingsImport => 'Поштаны импорттау';

  @override
  String get mailSettingsImportSubtitle =>
      'Бұрынғы пошта жүйесіндегі хаттарды көшіру';

  @override
  String get mailImportHint =>
      'Бұрынғы пошта жүйесіндегі хаттарды осы жәшікке көшіріңіз. Ештеңе ауыстырылмайды: қалталарыңыздағы хаттар орнында қалады, ал бұрыннан бар хат танылып, қосарланбайды.';

  @override
  String get mailImportFile => 'Мұрағат (.tgz)';

  @override
  String get mailImportFileHint =>
      'Бұрынғы пошта жүйесі сіздің тіркелгіңіз үшін экспорттаған файл. Zimbra: Параметрлер → Импорт/Экспорт → Экспорт. 2 ГБ дейін; импорт фонда жүреді, қолданбаны жабуға болады.';

  @override
  String get mailImportChoose => 'Мұрағатты таңдау';

  @override
  String get mailImportStart => 'Жүктеп импорттау';

  @override
  String mailImportUploading(int percent) {
    return 'Жүктелуде $percent%';
  }

  @override
  String get mailImportCancelUpload => 'Жүктеуді тоқтату';

  @override
  String get mailImportPickFile => 'Алдымен мұрағатты таңдаңыз';

  @override
  String mailImportWrongName(String mailbox) {
    return 'Мұрағат атауы сіздің жәшігіңізге сәйкес емес. $mailbox.tgz атты файлды жүктеңіз';
  }

  @override
  String get mailImportQueued =>
      'Файл жүктелді: импорт бірнеше секундтан кейін басталады';

  @override
  String mailImportImported(int imported, int total) {
    return '$total ішінен $imported импортталды';
  }

  @override
  String mailImportAlready(int count) {
    return '$count бұрыннан бар';
  }

  @override
  String mailImportFailedCount(int count) {
    return '$count қосу мүмкін болмады';
  }

  @override
  String mailImportNotMail(int count) {
    return '$count пошта емес (контактілер, күнтізбе)';
  }

  @override
  String get mailImportDeleteTitle =>
      'Бұл импорт жазбасын алып тастау керек пе?';

  @override
  String get mailImportDeleteBody =>
      'Жазба мен жүктелген файл жойылады. Импортталған хаттар қалталарыңызда қалады.';

  @override
  String get mailImportFailedGeneric => 'Импортты бастау мүмкін болмады';

  @override
  String get mailImportStatusQueued => 'Кезекте';

  @override
  String get mailImportStatusRunning => 'Импорт жүріп жатыр';

  @override
  String get mailImportStatusDone => 'Дайын';

  @override
  String get mailImportStatusFailed => 'Қате';

  @override
  String requestsNumber(int number) {
    return '№$number өтінім';
  }

  @override
  String get requestsWhat => 'Не болды';

  @override
  String get requestsWhatHint => 'Мәселені сипаттаңыз';

  @override
  String get requestsRoom => 'Кабинет';

  @override
  String get requestsRoomHint => 'Мысалы, 305';

  @override
  String get requestsDate => 'Күні';

  @override
  String get requestsSubmit => 'Өтінім жіберу';

  @override
  String get requestsFillAll => 'Үш өрісті де толтырыңыз';

  @override
  String get requestsStatusNew => 'Жаңа';

  @override
  String get requestsStatusInProgress => 'Жұмыста';

  @override
  String get requestsStatusDone => 'Орындалды';

  @override
  String get requestsStatusRejected => 'Қабылданбады';

  @override
  String get requestsEmptyTitle => 'Мұнда сіздің өтінімдеріңіз болады';

  @override
  String get requestsEmptyHint =>
      'Төмендегі форманы толтырыңыз: не болды, кабинет және күні. Жауап осы чатқа келеді.';

  @override
  String get requestsListHint => 'Өтінім беру';

  @override
  String get tabMore => 'Тағы';

  @override
  String get contactsFilterMine => 'Менікі';

  @override
  String get notifTestHintPhone => 'Осы телефонда сынақ хабарландыруын көрсету';
}
