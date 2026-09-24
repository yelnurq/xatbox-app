// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'XatBox';

  @override
  String get chatFilterChannels => 'Каналы';

  @override
  String get channelsDiscoverTitle => 'Каналы организации';

  @override
  String get channelsSearchHint => 'Поиск каналов';

  @override
  String get channelsEmpty => 'В организации пока нет публичных каналов';

  @override
  String get channelsNothingFound => 'Ничего не найдено';

  @override
  String get channelSubscribe => 'Подписаться';

  @override
  String get channelSubscribed => 'Вы подписаны';

  @override
  String get channelUnsubscribe => 'Отписаться';

  @override
  String channelUnsubscribeConfirm(String title) {
    return 'Отписаться от канала «$title»?';
  }

  @override
  String channelSubscribersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count подписчика',
      many: '$count подписчиков',
      few: '$count подписчика',
      one: '$count подписчик',
    );
    return '$_temp0';
  }

  @override
  String get channelCreate => 'Создать канал';

  @override
  String get channelNameLabel => 'Название канала';

  @override
  String get channelDescriptionLabel => 'Описание (необязательно)';

  @override
  String get channelPublic => 'Публичный канал';

  @override
  String get channelPublicHint =>
      'Любой сотрудник найдёт канал в «Каналах организации» и подпишется';

  @override
  String get channelPrivateHint =>
      'Подписчиков добавляют администраторы канала';

  @override
  String get channelReadOnly => 'Публикуют только администраторы канала';

  @override
  String get channelBadge => 'Канал';

  @override
  String get channelSubscribers => 'Подписчики';

  @override
  String get channelAdmins => 'Администраторы';

  @override
  String get channelAddSubscriber => 'Добавить подписчика';

  @override
  String channelViews(int count) {
    return 'Просмотры: $count';
  }

  @override
  String get channelNoPermission => 'У вас нет права создавать каналы';

  @override
  String get pollAttach => 'Опрос';

  @override
  String get pollNewTitle => 'Новый опрос';

  @override
  String get pollQuestionLabel => 'Вопрос';

  @override
  String get pollOptionsLabel => 'Варианты ответа';

  @override
  String pollOptionHint(int n) {
    return 'Вариант $n';
  }

  @override
  String get pollAddOption => 'Добавить вариант';

  @override
  String get pollRemoveOption => 'Удалить вариант';

  @override
  String get pollAnonymous => 'Анонимное голосование';

  @override
  String get pollMultiple => 'Несколько вариантов ответа';

  @override
  String get pollQuiz => 'Режим викторины';

  @override
  String get pollQuizHint => 'Отметьте правильный ответ';

  @override
  String get pollCloseSection => 'Завершить автоматически';

  @override
  String get pollCloseNever => 'Нет';

  @override
  String get pollClose1h => 'Через час';

  @override
  String get pollClose1d => 'Через сутки';

  @override
  String get pollCloseWeek => 'Через неделю';

  @override
  String get pollCreate => 'Создать';

  @override
  String get pollErrorQuestion => 'Введите вопрос';

  @override
  String get pollErrorOptions => 'Нужно от 2 до 10 разных вариантов';

  @override
  String get pollKindAnonymous => 'Анонимный опрос';

  @override
  String get pollKindPublic => 'Открытый опрос';

  @override
  String get pollKindQuiz => 'Викторина';

  @override
  String get pollClosed => 'Опрос завершён';

  @override
  String get pollVote => 'Голосовать';

  @override
  String get pollRetract => 'Отменить голос';

  @override
  String get pollCloseNow => 'Завершить опрос';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count голоса',
      many: '$count голосов',
      few: '$count голоса',
      one: '$count голос',
      zero: 'Нет голосов',
    );
    return '$_temp0';
  }

  @override
  String pollEndsAt(String time) {
    return 'до $time';
  }

  @override
  String get pollVotersTitle => 'Проголосовали';

  @override
  String get pollNoVoters => 'Этот вариант пока никто не выбрал';

  @override
  String get pollCorrect => 'Правильный ответ';

  @override
  String get scheduleSendLater => 'Отправить позже';

  @override
  String get scheduleIn1h => 'Через 1 час';

  @override
  String get scheduleTonight => 'Сегодня вечером';

  @override
  String get scheduleTomorrowMorning => 'Завтра утром';

  @override
  String get schedulePick => 'Выбрать дату и время';

  @override
  String get scheduleTooEarly => 'Выберите время в будущем';

  @override
  String get scheduledTitle => 'Запланированные';

  @override
  String scheduledBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count запланированного сообщения',
      many: '$count запланированных сообщений',
      few: '$count запланированных сообщения',
      one: '$count запланированное сообщение',
    );
    return '$_temp0';
  }

  @override
  String get scheduledEmpty => 'Нет запланированных сообщений';

  @override
  String get scheduledSendNow => 'Отправить сейчас';

  @override
  String get scheduledEditText => 'Изменить текст';

  @override
  String get scheduledEditTime => 'Изменить время';

  @override
  String get scheduledFailed => 'Не отправлено';

  @override
  String scheduledCreated(String when) {
    return 'Сообщение будет отправлено $when';
  }

  @override
  String scheduledAttachments(int count) {
    return 'Вложений: $count';
  }

  @override
  String get remindAction => 'Напомнить';

  @override
  String get remindSheetTitle => 'Напомнить о сообщении';

  @override
  String get remindersTitle => 'Напоминания';

  @override
  String get remindersEmpty => 'Напоминаний нет';

  @override
  String get remindersEmptyHint =>
      'Удерживайте сообщение и выберите «Напомнить»';

  @override
  String get remindersUpcoming => 'Предстоящие';

  @override
  String get remindersDone => 'Сработавшие';

  @override
  String reminderSetDone(String when) {
    return 'Напомню $when';
  }

  @override
  String get reminderReschedule => 'Перенести';

  @override
  String get reminderDelete => 'Удалить напоминание';

  @override
  String get reminderNotificationTitle => 'Напоминание';

  @override
  String get notifPrefsChannels => 'Каналы';

  @override
  String chatWhenToday(String time) {
    return 'сегодня в $time';
  }

  @override
  String chatWhenTomorrow(String time) {
    return 'завтра в $time';
  }

  @override
  String chatWhenDate(String date, String time) {
    return '$date в $time';
  }

  @override
  String get tabMail => 'Почта';

  @override
  String get tabChat => 'Чат';

  @override
  String get tabCalls => 'Звонки';

  @override
  String get comingSoon => 'Скоро';

  @override
  String get chatComingSoonBody =>
      'Модуль чата появится в следующем обновлении.';

  @override
  String get callsComingSoonBody =>
      'Модуль звонков появится в следующем обновлении.';

  @override
  String get splashChecking => 'Проверяем сессию…';

  @override
  String get splashUnreachableTitle => 'Сервер недоступен';

  @override
  String get splashUnreachableBody =>
      'Не удалось проверить сессию. Проверьте подключение и повторите.';

  @override
  String get splashSignInAgain => 'Войти заново';

  @override
  String get loginTitle => 'Вход в XatBox';

  @override
  String get loginSubtitle => 'Используйте учётную запись корпоративной почты';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginPassword => 'Пароль';

  @override
  String get loginButton => 'Войти';

  @override
  String get loginEmailRequired => 'Введите email';

  @override
  String get loginPasswordRequired => 'Введите пароль';

  @override
  String get loginEmailInvalid => 'Некорректный email';

  @override
  String get sessionExpiredBanner => 'Сессия истекла. Войдите снова.';

  @override
  String get errInvalidCredentialsFormat => 'Введите email и пароль.';

  @override
  String get errInvalidCredentials => 'Неверный email или пароль.';

  @override
  String get errUserDisabled =>
      'Учётная запись отключена. Обратитесь к администратору.';

  @override
  String get errOrganizationSuspended =>
      'Подписка организации приостановлена. Обратитесь к администратору.';

  @override
  String get errDirectoryDisabled =>
      'Вход через корпоративный каталог отключён. Обратитесь к администратору.';

  @override
  String get errTooManyAttempts =>
      'Слишком много попыток входа. Попробуйте позже.';

  @override
  String get errDirectoryUnavailable =>
      'Корпоративный каталог недоступен. Попробуйте позже.';

  @override
  String get errSubscriptionLimit =>
      'Достигнут лимит пользователей организации. Обратитесь к администратору.';

  @override
  String get errInternal => 'Ошибка сервера. Попробуйте позже.';

  @override
  String get errNetwork =>
      'Нет соединения с сервером. Проверьте подключение к интернету.';

  @override
  String get errTimeout => 'Сервер долго не отвечает. Попробуйте ещё раз.';

  @override
  String get errUnauthenticated => 'Сессия истекла. Войдите снова.';

  @override
  String get errForbidden => 'У вас нет прав для этого действия.';

  @override
  String get errNoMailbox =>
      'У вашей учётной записи нет активного почтового ящика.';

  @override
  String get errMailServiceUnavailable =>
      'Почтовый сервис временно недоступен.';

  @override
  String get errMessageNotFound => 'Письмо не найдено.';

  @override
  String get errFolderNotFound => 'Папка не найдена.';

  @override
  String errInvalidMessage(String detail) {
    return 'Письмо не прошло проверку: $detail';
  }

  @override
  String get errInvalidBody => 'Некорректный запрос. Обновите приложение.';

  @override
  String get errAttachmentTooLarge => 'Файл слишком большой.';

  @override
  String get errStorageUnavailable =>
      'Хранилище файлов недоступно. Попробуйте позже.';

  @override
  String get errConverterUnavailable =>
      'Предпросмотр документов недоступен на сервере.';

  @override
  String get errNotConvertible => 'Этот файл нельзя показать как PDF.';

  @override
  String get errConvertTimeout =>
      'Не удалось подготовить предпросмотр: превышено время ожидания.';

  @override
  String get errConvertFailed => 'Не удалось подготовить предпросмотр.';

  @override
  String errUnknown(String code) {
    return 'Что-то пошло не так ($code).';
  }

  @override
  String get errUnexpected => 'Неожиданный ответ сервера.';

  @override
  String errRequestId(String id) {
    return 'Код запроса: $id';
  }

  @override
  String get retry => 'Повторить';

  @override
  String get cancel => 'Отмена';

  @override
  String get ok => 'ОК';

  @override
  String get close => 'Закрыть';

  @override
  String get delete => 'Удалить';

  @override
  String get send => 'Отправить';

  @override
  String get save => 'Сохранить';

  @override
  String get search => 'Поиск';

  @override
  String get loading => 'Загрузка…';

  @override
  String get offlineBanner => 'Нет сети — показаны сохранённые данные';

  @override
  String get offlineProfileBanner =>
      'Сервер недоступен, работа в офлайн-режиме';

  @override
  String get folderInbox => 'Входящие';

  @override
  String get folderSent => 'Отправленные';

  @override
  String get folderDrafts => 'Черновики';

  @override
  String get folderSpam => 'Спам';

  @override
  String get folderTrash => 'Корзина';

  @override
  String get folderBookmarks => 'Закладки';

  @override
  String get sectionSmartFolders => 'Умные папки';

  @override
  String get sectionBookmarkFolders => 'Папки закладок';

  @override
  String get mailEmptyFolder => 'В этой папке нет писем';

  @override
  String get mailEmptySearch => 'Ничего не найдено';

  @override
  String get mailSearchHint => 'Поиск в папке';

  @override
  String get filterUnread => 'Непрочитанные';

  @override
  String get filterStarred => 'Закладки';

  @override
  String get filterAttachments => 'С вложениями';

  @override
  String get mailNoSubject => '(без темы)';

  @override
  String get mailLoadMoreError => 'Не удалось загрузить ещё';

  @override
  String get mailMarkRead => 'Прочитано';

  @override
  String get mailMarkUnread => 'Не прочитано';

  @override
  String get mailStar => 'В закладки';

  @override
  String get mailUnstar => 'Убрать из закладок';

  @override
  String get mailMoveToTrash => 'В корзину';

  @override
  String get mailDeleteForever => 'Удалить навсегда';

  @override
  String get mailDeleteForeverConfirm =>
      'Письмо будет удалено безвозвратно. Продолжить?';

  @override
  String get mailReportSpam => 'В спам';

  @override
  String get mailReportNotSpam => 'Не спам';

  @override
  String get mailMoveTo => 'Переместить в…';

  @override
  String get mailReply => 'Ответить';

  @override
  String get mailReplyAll => 'Ответить всем';

  @override
  String get mailForward => 'Переслать';

  @override
  String get mailCompose => 'Написать';

  @override
  String get mailNoPermission => 'У вас нет доступа к почте.';

  @override
  String get mailAttachments => 'Вложения';

  @override
  String get attachmentOpen => 'Открыть';

  @override
  String get attachmentPreviewPdf => 'Предпросмотр (PDF)';

  @override
  String get attachmentDownloading => 'Загрузка файла…';

  @override
  String get attachmentNoApp => 'Нет приложения для открытия этого файла';

  @override
  String get mailFrom => 'От';

  @override
  String get mailTo => 'Кому';

  @override
  String get mailCc => 'Копия';

  @override
  String get mailBcc => 'Скрытая копия';

  @override
  String get mailSubject => 'Тема';

  @override
  String get mailBody => 'Текст письма';

  @override
  String mailThreadTitle(int count) {
    return 'Переписка ($count)';
  }

  @override
  String get mailShowHtml => 'Показать оформление';

  @override
  String get mailShowText => 'Показать как текст';

  @override
  String get mailNoBody => '(пустое письмо)';

  @override
  String get mailRemoteContentBlocked => 'Внешние изображения заблокированы';

  @override
  String get mailOpenLinkTitle => 'Открыть ссылку?';

  @override
  String get mailOpen => 'Открыть';

  @override
  String mailUnreadCount(int count) {
    return '$count непрочитанных';
  }

  @override
  String get mailActionDone => 'Готово';

  @override
  String get mailMovedToTrash => 'Письмо перемещено в корзину';

  @override
  String get mailDeleted => 'Письмо удалено';

  @override
  String get mailReportedSpam => 'Письмо отмечено как спам';

  @override
  String get mailReportedHam => 'Письмо возвращено во входящие';

  @override
  String get composeTitleNew => 'Новое письмо';

  @override
  String get composeTitleReply => 'Ответ';

  @override
  String get composeTitleForward => 'Пересылка';

  @override
  String get composeTitleDraft => 'Черновик';

  @override
  String get composeRecipientsRequired => 'Укажите хотя бы одного получателя';

  @override
  String composeInvalidAddress(String address) {
    return 'Некорректный адрес: $address';
  }

  @override
  String get composeTooManyRecipients =>
      'Слишком много получателей (максимум 100)';

  @override
  String get composeSubjectTooLong => 'Слишком длинная тема';

  @override
  String get composeTooManyAttachments => 'Не более 20 вложений';

  @override
  String composeAttachmentTooLarge(String name, String limit) {
    return 'Файл «$name» больше лимита $limit';
  }

  @override
  String get composeAddAttachment => 'Прикрепить файл';

  @override
  String get composeSent => 'Письмо отправлено';

  @override
  String get composeSaveDraft => 'Сохранить черновик';

  @override
  String get composeDraftSaved => 'Черновик сохранён';

  @override
  String get composeDiscard => 'Не сохранять';

  @override
  String get composeDiscardTitle => 'Закрыть письмо?';

  @override
  String get composeDiscardBody => 'Несохранённые изменения будут потеряны.';

  @override
  String get composeSending => 'Отправка…';

  @override
  String get composeForwardedAttachments => 'Вложения из исходного письма';

  @override
  String get composeSignatureNote => 'Подпись добавит сервер при отправке.';

  @override
  String composeQuoteHeader(String date, String from) {
    return '$date, $from написал(а):';
  }

  @override
  String get composeForwardHeader =>
      '---------- Пересланное сообщение ----------';

  @override
  String get composeRecipientHint => 'адреса через запятую';

  @override
  String get composeNoSendPermission => 'У вас нет права отправлять письма.';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileSessions => 'Активные сессии';

  @override
  String get profileCurrentSession => 'Текущая';

  @override
  String get profileEndSession => 'Завершить';

  @override
  String get profileEndOthers => 'Завершить остальные сессии';

  @override
  String get profileDepartment => 'Подразделение';

  @override
  String profileSessionsEnded(int count) {
    return 'Завершено сессий: $count';
  }

  @override
  String profileExpires(String date) {
    return 'Действует до $date';
  }

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsLogout => 'Выйти';

  @override
  String get settingsLogoutConfirm =>
      'Выйти из учётной записи на этом устройстве?';

  @override
  String get settingsCacheSection => 'Память и данные';

  @override
  String get settingsCacheLimit => 'Хранить открытых писем офлайн';

  @override
  String get settingsCacheClear => 'Очистить кэш';

  @override
  String get settingsCacheCleared => 'Кэш очищен';

  @override
  String settingsCacheStats(int messages, int lists) {
    return 'В кэше: $messages писем, $lists списков';
  }

  @override
  String settingsVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get settingsDiagnostics => 'Диагностика';

  @override
  String get settingsDiagnosticsEmpty => 'Событий пока нет';

  @override
  String get settingsNotifications => 'Уведомления';

  @override
  String get settingsNotificationsHint =>
      'Какие push-уведомления присылать, тихие часы';

  @override
  String get settingsSendErrorReports => 'Отправлять отчёты об ошибках';

  @override
  String get settingsSendErrorReportsHint =>
      'Технические данные о сбоях уходят только на сервер XatBox — без текстов сообщений и адресов';

  @override
  String get notifPrefsServerHint =>
      'Настройки хранятся на сервере: отключённые уведомления не отправляются вовсе';

  @override
  String get notifPrefsTypesSection => 'Что присылать';

  @override
  String get notifPrefsDirect => 'Личные сообщения';

  @override
  String get notifPrefsGroups => 'Группы';

  @override
  String get notifPrefsMentionsOnly => 'Только упоминания в группах';

  @override
  String get notifPrefsCalls => 'Звонки';

  @override
  String get notifPrefsQuietSection => 'Тихие часы';

  @override
  String get notifPrefsQuietEnabled => 'Не беспокоить в тихие часы';

  @override
  String notifPrefsQuietHint(String zone) {
    return 'Каждый день, по времени устройства ($zone)';
  }

  @override
  String get notifPrefsQuietStart => 'Начало';

  @override
  String get notifPrefsQuietEnd => 'Конец';

  @override
  String get notifPrefsQuietAllowCalls => 'Пропускать звонки в тихие часы';

  @override
  String get notifPrefsQuietAllowCallsHint =>
      'Входящие звонки звонят как обычно';

  @override
  String get notifPrefsPending => 'Изменения отправятся, когда появится связь';

  @override
  String get notifPrefsLoadFailed =>
      'Не удалось загрузить настройки уведомлений';

  @override
  String get notifPrefsRetry => 'Повторить';

  @override
  String get notifPrefsSystemSettings => 'Системные настройки уведомлений';

  @override
  String get notifPrefsSystemSettingsHint => 'Звук, вибрация и каналы Android';

  @override
  String get notifBackgroundSection => 'Соединение';

  @override
  String get notifBackgroundTitle => 'Оставаться на связи в фоне';

  @override
  String get notifBackgroundOneMinute => '1 минута';

  @override
  String get notifBackgroundFifteenMinutes => '15 минут';

  @override
  String get notifBackgroundAlways => 'Всегда';

  @override
  String notifBackgroundAuto(String value) {
    return 'По умолчанию ($value)';
  }

  @override
  String get notifBackgroundHint =>
      'Сколько приложение держит соединение после сворачивания. Когда оно закрыто, новые сообщения и звонки приходят только через push-уведомления. Во время звонка соединение не закрывается.';

  @override
  String get notifBackgroundNoPush =>
      'Push-уведомления не настроены: пока соединение закрыто, сообщения и входящие звонки не приходят';

  @override
  String get notifBackgroundAlwaysWarning => 'Быстрее расходует заряд батареи';

  @override
  String get permOnboardNotifTitle => 'Включить уведомления?';

  @override
  String get permOnboardNotifBody =>
      'XatBox сообщит о новых сообщениях, входящих звонках и напоминаниях календаря. Android спросит разрешение — нажмите «Разрешить».';

  @override
  String get permOnboardFsiTitle => 'Звонки на весь экран';

  @override
  String get permOnboardFsiBody =>
      'Чтобы входящий звонок был виден на заблокированном экране, разрешите XatBox полноэкранные уведомления. Откроются настройки Android: включите переключатель и вернитесь в приложение.';

  @override
  String get permAllow => 'Разрешить';

  @override
  String get permNotNow => 'Не сейчас';

  @override
  String get permOpenSettings => 'Открыть настройки';

  @override
  String get notifDeviceSection => 'Этот телефон';

  @override
  String get notifDeviceNotifications => 'Разрешение на уведомления';

  @override
  String get notifDeviceGranted => 'Разрешено';

  @override
  String get notifDeviceNotificationsOff =>
      'Выключено: сообщения, звонки и напоминания не показываются';

  @override
  String get notifDeviceFullScreen => 'Звонки на весь экран';

  @override
  String get notifDeviceFullScreenOff =>
      'Выключено: входящий звонок будет только маленьким уведомлением';

  @override
  String get notifDeviceBattery => 'Без ограничений батареи';

  @override
  String get notifDeviceBatteryOn =>
      'Android не откладывает работу приложения в фоне';

  @override
  String get notifDeviceBatteryOff =>
      'Android может откладывать сообщения и напоминания, пока телефоном не пользуются';

  @override
  String get notifDeviceBatteryNoPush =>
      'Пока push-уведомления не настроены, это особенно важно: без ограничений приложение дольше остаётся на связи';

  @override
  String get notifDeviceHelp => 'Автозапуск и фоновая работа';

  @override
  String get notifDeviceHelpHint =>
      'Xiaomi, Huawei, Honor, Samsung, Oppo, Realme';

  @override
  String get bgHelpTitle => 'Работа в фоне';

  @override
  String get bgHelpIntro =>
      'Некоторые производители закрывают приложения в фоне сильнее, чем обычный Android. Если сообщения или звонки приходят с опозданием, проверьте настройки ниже. Названия пунктов могут немного отличаться в разных версиях прошивки.';

  @override
  String get bgHelpCommonTitle => 'Для всех телефонов';

  @override
  String get bgHelpCommonSteps =>
      '1. Настройки → Приложения → XatBox → Уведомления: включите все категории.\n2. Там же → Батарея: «Без ограничений» («Не оптимизировать»).\n3. Не смахивайте XatBox из недавних приложений, если ждёте звонка.';

  @override
  String get bgHelpXiaomiTitle => 'Xiaomi, Redmi, POCO (MIUI, HyperOS)';

  @override
  String get bgHelpXiaomiSteps =>
      '1. Настройки → Приложения → Все приложения → XatBox.\n2. Включите «Автозапуск».\n3. «Контроль активности» (Экономия энергии) → «Нет ограничений».\n4. «Другие разрешения»: разрешите «Экран блокировки» и «Всплывающие окна в фоне».\n5. В недавних приложениях потяните карточку XatBox вниз и закрепите замком.';

  @override
  String get bgHelpHuaweiTitle => 'Huawei, Honor (EMUI, MagicOS)';

  @override
  String get bgHelpHuaweiSteps =>
      '1. Настройки → Батарея → Запуск приложений.\n2. Найдите XatBox и выключите «Автоматическое управление».\n3. В окне включите «Автозапуск», «Косвенный запуск» и «Работа в фоне».\n4. Настройки → Уведомления → XatBox: разрешите уведомления на экране блокировки.';

  @override
  String get bgHelpSamsungTitle => 'Samsung (One UI)';

  @override
  String get bgHelpSamsungSteps =>
      '1. Настройки → Приложения → XatBox → Батарея: «Не ограничено».\n2. Настройки → Батарея → Ограничения фоновых приложений: XatBox не должен быть в «Спящих» и «Глубоко спящих».\n3. Добавьте XatBox в «Никогда не спящие приложения».';

  @override
  String get bgHelpOppoTitle => 'Oppo, Realme, OnePlus, Vivo';

  @override
  String get bgHelpOppoSteps =>
      '1. Настройки → Приложения → XatBox → Использование батареи: разрешите «Работу в фоне» и «Автозапуск».\n2. Настройки → Батарея → Оптимизация: для XatBox — «Не оптимизировать».\n3. Закрепите XatBox в недавних приложениях.';

  @override
  String get bgHelpCheck =>
      'Проверка: заблокируйте телефон на 15 минут и попросите коллегу написать или позвонить.';

  @override
  String get a11ySearchPrevious => 'Предыдущее совпадение';

  @override
  String get a11ySearchNext => 'Следующее совпадение';

  @override
  String get a11yMuted => 'без звука';

  @override
  String get a11yPinned => 'закреплён';

  @override
  String a11yUnreadCount(int count) {
    return 'непрочитанных: $count';
  }

  @override
  String get a11yMarkedUnread => 'отмечен как непрочитанный';

  @override
  String get a11yMicOff => 'микрофон выключен';

  @override
  String a11yHandsRaised(int count) {
    return 'подняли руку: $count';
  }

  @override
  String get a11yVoiceSeek => 'Перемотка голосового сообщения';

  @override
  String a11yPinEntered(int filled, int length) {
    return 'Введено цифр: $filled из $length';
  }

  @override
  String get a11yDecrease => 'Уменьшить';

  @override
  String get a11yIncrease => 'Увеличить';

  @override
  String get a11yAdd => 'Добавить';

  @override
  String a11yReaction(String emoji, int count) {
    return 'Реакция $emoji: $count';
  }

  @override
  String a11yVoiceMessage(String duration) {
    return 'Голосовое сообщение, $duration';
  }

  @override
  String get a11ySelected => 'выбрано';

  @override
  String get a11yFavourite => 'в избранном';

  @override
  String get a11yGuest => 'гость';

  @override
  String get chatTitle => 'Чат';

  @override
  String get chatDisabled => 'Чат не настроен в этой сборке.';

  @override
  String get chatNoAccess => 'У вас нет доступа к чату.';

  @override
  String get chatEmpty => 'Пока нет чатов. Начните переписку с коллегой.';

  @override
  String get chatNew => 'Новый чат';

  @override
  String get chatNewGroup => 'Новая группа';

  @override
  String get chatGroupTitle => 'Название группы';

  @override
  String get chatCreateGroup => 'Создать группу';

  @override
  String get chatSearchUsers => 'Поиск по имени или email';

  @override
  String get chatSearch => 'Поиск по чатам';

  @override
  String get chatSearchMessages => 'Сообщения';

  @override
  String get chatNoUsers => 'Никого не найдено';

  @override
  String chatSelectedMembers(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get chatConnecting => 'Подключение…';

  @override
  String get chatSyncing => 'Обновление…';

  @override
  String get chatOffline => 'Нет соединения';

  @override
  String get chatOnline => 'в сети';

  @override
  String chatLastSeen(String when) {
    return 'был(а) $when';
  }

  @override
  String chatMembersCount(int count) {
    return '$count участников';
  }

  @override
  String chatTyping(String name) {
    return '$name печатает…';
  }

  @override
  String get chatTypingMany => 'печатают…';

  @override
  String chatRecording(String name) {
    return '$name записывает голосовое…';
  }

  @override
  String get chatYou => 'Вы';

  @override
  String get chatMessageHint => 'Сообщение';

  @override
  String get chatSend => 'Отправить';

  @override
  String get chatCameraTitle => 'Снимок с камеры';

  @override
  String get chatCameraTake => 'Снять';

  @override
  String get chatCameraRetake => 'Переснять';

  @override
  String get chatCameraDevice => 'Камера';

  @override
  String get chatCameraUnavailable =>
      'Камера недоступна. Проверьте, что она подключена и не занята другой программой.';

  @override
  String get chatAttach => 'Прикрепить';

  @override
  String get chatVoiceHold => 'Удерживайте для записи';

  @override
  String get chatVoiceSlideCancel => '← Смахните, чтобы отменить';

  @override
  String get chatVoiceLocked => 'Запись';

  @override
  String get chatVoiceCancel => 'Отменить';

  @override
  String get chatVoicePreview => 'Голосовое сообщение';

  @override
  String get chatMicDenied =>
      'Нет доступа к микрофону. Разрешите его в настройках.';

  @override
  String get chatVoiceStartFailed =>
      'Не удалось начать запись. Проверьте микрофон.';

  @override
  String get chatVoiceSendFailed =>
      'Не удалось завершить запись. Попробуйте ещё раз.';

  @override
  String get chatOpenSettings => 'Открыть настройки';

  @override
  String get chatReply => 'Ответить';

  @override
  String get chatForward => 'Переслать';

  @override
  String get chatCopy => 'Копировать';

  @override
  String get chatEdit => 'Изменить';

  @override
  String get chatDelete => 'Удалить';

  @override
  String get chatReact => 'Реакция';

  @override
  String get chatEdited => 'изменено';

  @override
  String get chatDeleted => 'Сообщение удалено';

  @override
  String get chatCopied => 'Скопировано';

  @override
  String get chatForwardTo => 'Переслать в…';

  @override
  String get chatForwarded => 'Переслано';

  @override
  String get chatReplyingTo => 'Ответ на сообщение';

  @override
  String get chatEditing => 'Редактирование';

  @override
  String get chatPending => 'Отправляется…';

  @override
  String get chatFailed => 'Не отправлено';

  @override
  String get chatRetry => 'Повторить';

  @override
  String get chatDiscard => 'Удалить из очереди';

  @override
  String get chatStatusSent => 'Отправлено';

  @override
  String get chatStatusDelivered => 'Доставлено';

  @override
  String get chatStatusRead => 'Прочитано';

  @override
  String get chatAttachmentImage => 'Фото';

  @override
  String get chatAttachmentVideo => 'Видео';

  @override
  String get chatAttachmentVoice => 'Голосовое сообщение';

  @override
  String get chatAttachmentAudio => 'Аудио';

  @override
  String get chatAttachmentFile => 'Файл';

  @override
  String get chatFileOpen => 'Открыть';

  @override
  String get chatFileDownloading => 'Загрузка…';

  @override
  String chatSystemMemberAdded(String actor, String user) {
    return '$actor добавил(а) $user';
  }

  @override
  String chatSystemMemberRemoved(String actor, String user) {
    return '$actor удалил(а) $user';
  }

  @override
  String chatSystemMemberLeft(String user) {
    return '$user покинул(а) чат';
  }

  @override
  String chatSystemTitleChanged(String actor, String title) {
    return '$actor переименовал(а) чат: $title';
  }

  @override
  String get chatSystemGeneric => 'Служебное сообщение';

  @override
  String get chatInfo => 'Информация';

  @override
  String get chatMembers => 'Участники';

  @override
  String get chatAddMember => 'Добавить участника';

  @override
  String get chatRemoveMember => 'Удалить из группы';

  @override
  String get chatLeave => 'Покинуть группу';

  @override
  String get chatLeaveConfirm =>
      'Вы больше не будете получать сообщения этой группы.';

  @override
  String get chatRename => 'Переименовать';

  @override
  String get chatRoleOwner => 'владелец';

  @override
  String get chatRoleAdmin => 'админ';

  @override
  String get chatRoleMember => 'участник';

  @override
  String get chatMakeAdmin => 'Сделать админом';

  @override
  String get chatMute => 'Без звука';

  @override
  String get chatMuteHour => 'На 1 час';

  @override
  String get chatMuteDay => 'На 24 часа';

  @override
  String get chatMuteForever => 'Навсегда';

  @override
  String get chatUnmute => 'Включить звук';

  @override
  String get chatPin => 'Закрепить';

  @override
  String get chatUnpin => 'Открепить';

  @override
  String get chatArchive => 'В архив';

  @override
  String get chatUnarchive => 'Из архива';

  @override
  String get chatArchived => 'Архив';

  @override
  String get chatPinnedMessage => 'Закреплённое сообщение';

  @override
  String get chatPinMessage => 'Закрепить сообщение';

  @override
  String get chatUnpinMessage => 'Открепить сообщение';

  @override
  String get chatLoadOlder => 'Загрузить раньше';

  @override
  String get chatNoMessages => 'Сообщений пока нет';

  @override
  String get chatToday => 'Сегодня';

  @override
  String get chatYesterday => 'Вчера';

  @override
  String get chatPrivacySection => 'Приватность чата';

  @override
  String get chatPrivacyLastSeen => 'Показывать «был(а) в сети»';

  @override
  String get chatPrivacyOnline => 'Показывать статус «в сети»';

  @override
  String get chatPrivacyReadReceipts => 'Отправлять отметки о прочтении';

  @override
  String get chatPrivacyPushPreview => 'Показывать текст в уведомлениях';

  @override
  String chatCacheStats(int chats, int messages, int outbox) {
    return 'Чаты: $chats, сообщений в кэше: $messages, в очереди: $outbox';
  }

  @override
  String get chatMentionHint => 'Упомянуть';

  @override
  String get chatRateLimited => 'Слишком много сообщений. Подождите немного.';

  @override
  String get chatFileTooLarge => 'Файл слишком большой.';

  @override
  String get chatFileTypeForbidden => 'Такой тип файла нельзя отправить.';

  @override
  String get chatFileInfected => 'Файл отклонён антивирусом.';

  @override
  String get chatAvUnavailable => 'Антивирус недоступен, попробуйте позже.';

  @override
  String get chatMessageTooLong => 'Сообщение слишком длинное.';

  @override
  String get chatConversationGone => 'Чат недоступен.';

  @override
  String get calendarTitle => 'Календарь';

  @override
  String get calendarToday => 'Сегодня';

  @override
  String get calendarViewMonth => 'Месяц';

  @override
  String get calendarViewWeek => 'Неделя';

  @override
  String get calendarViewDay => 'День';

  @override
  String get calendarViewAgenda => 'Список';

  @override
  String get calendarNoEvents => 'Нет событий';

  @override
  String get calendarNoEventsDay => 'В этот день событий нет';

  @override
  String get calendarAllDay => 'Весь день';

  @override
  String get calendarOfflineCached =>
      'Нет сети — показан сохранённый календарь';

  @override
  String get calendarOfflineEmpty => 'Нет сети, а этот период ещё не загружен';

  @override
  String get calendarNoAccess => 'У вас нет доступа к календарю.';

  @override
  String get calendarNewEvent => 'Новое событие';

  @override
  String get calendarEditEvent => 'Изменить событие';

  @override
  String get calendarSearch => 'Поиск по событиям';

  @override
  String get calendarSearchHint => 'Название, место, организатор';

  @override
  String get calendarSearchEmpty => 'Ничего не найдено';

  @override
  String get calendarSearchCachedOnly =>
      'Поиск идёт по загруженным месяцам календаря.';

  @override
  String get calendarInvitations => 'Приглашения';

  @override
  String get calendarInvitationsEmpty => 'Нет новых приглашений';

  @override
  String get calendarPendingSync => 'Ожидает отправки';

  @override
  String get calendarSyncing => 'Обновление…';

  @override
  String get calendarFieldTitle => 'Название';

  @override
  String get calendarFieldTitleRequired => 'Введите название';

  @override
  String get calendarFieldTitleTooLong => 'Слишком длинное название';

  @override
  String get calendarFieldStart => 'Начало';

  @override
  String get calendarFieldEnd => 'Окончание';

  @override
  String get calendarFieldEndBeforeStart =>
      'Окончание должно быть позже начала';

  @override
  String get calendarFieldTimezone => 'Часовой пояс';

  @override
  String get calendarFieldLocation => 'Место';

  @override
  String get calendarFieldLink => 'Ссылка на встречу';

  @override
  String get calendarFieldLinkInvalid => 'Нужна ссылка вида https://…';

  @override
  String get calendarFieldDescription => 'Описание';

  @override
  String get calendarFieldCategory => 'Категория';

  @override
  String get calendarFieldPrivate => 'Личное: описание видно только вам';

  @override
  String get calendarFieldRepeat => 'Повтор';

  @override
  String get calendarFieldReminders => 'Напоминания';

  @override
  String get calendarFieldParticipants => 'Участники';

  @override
  String get calendarAddParticipant => 'Добавить участника';

  @override
  String get calendarAddReminder => 'Добавить';

  @override
  String get calendarExternalEmailHint => 'Email внешнего участника';

  @override
  String get calendarExternalEmailInvalid => 'Некорректный email';

  @override
  String get calendarParticipantsUnavailable =>
      'Справочник коллег недоступен: модуль чата выключен.';

  @override
  String get calendarParticipantsOffline =>
      'Участники загрузятся, когда появится сеть.';

  @override
  String get calendarSearchColleagues => 'Поиск коллег по имени или email';

  @override
  String get calendarCategoryPersonal => 'Личное';

  @override
  String get calendarCategoryMeeting => 'Встреча';

  @override
  String get calendarCategoryDepartment => 'Отдел';

  @override
  String get calendarCategoryOrganization => 'Организация';

  @override
  String get calendarExternal => 'внешний участник';

  @override
  String get calendarRepeatNone => 'Не повторять';

  @override
  String get calendarRepeatDaily => 'Каждый день';

  @override
  String get calendarRepeatWeekly => 'Каждую неделю';

  @override
  String get calendarRepeatMonthly => 'Каждый месяц';

  @override
  String get calendarRepeatYearly => 'Каждый год';

  @override
  String calendarRepeatEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Каждые $count дня',
      many: 'Каждые $count дней',
      few: 'Каждые $count дня',
      one: 'Каждый $count день',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Каждые $count недели',
      many: 'Каждые $count недель',
      few: 'Каждые $count недели',
      one: 'Каждую $count неделю',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Каждые $count месяца',
      many: 'Каждые $count месяцев',
      few: 'Каждые $count месяца',
      one: 'Каждый $count месяц',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatEveryYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Каждые $count года',
      many: 'Каждые $count лет',
      few: 'Каждые $count года',
      one: 'Каждый $count год',
    );
    return '$_temp0';
  }

  @override
  String get calendarRepeatInterval => 'Интервал';

  @override
  String get calendarRepeatEnds => 'Окончание повтора';

  @override
  String get calendarRepeatEndsNever => 'Никогда';

  @override
  String get calendarRepeatEndsOn => 'До даты';

  @override
  String get calendarRepeatEndsAfter => 'После нескольких повторов';

  @override
  String calendarRepeatUntil(String date) {
    return 'до $date';
  }

  @override
  String calendarRepeatTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count раза',
      many: '$count раз',
      few: '$count раза',
      one: '$count раз',
    );
    return '$_temp0';
  }

  @override
  String get calendarRepeatCustom => 'Особое правило повтора';

  @override
  String get calendarRepeatServerNote =>
      'Сервер хранит окончание серии, но веб-почта пока показывает такие серии бесконечными.';

  @override
  String get calendarDone => 'Готово';

  @override
  String get calendarReminderAtStart => 'В момент начала';

  @override
  String calendarReminderMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'За $count минуты',
      many: 'За $count минут',
      few: 'За $count минуты',
      one: 'За $count минуту',
    );
    return '$_temp0';
  }

  @override
  String calendarReminderHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'За $count часа',
      many: 'За $count часов',
      few: 'За $count часа',
      one: 'За $count час',
    );
    return '$_temp0';
  }

  @override
  String calendarReminderDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'За $count дня',
      many: 'За $count дней',
      few: 'За $count дня',
      one: 'За $count день',
    );
    return '$_temp0';
  }

  @override
  String get calendarReminderLocalNote =>
      'Первое напоминание получат и участники; остальные сработают только на этом устройстве.';

  @override
  String get calendarReminderChannel => 'Напоминания календаря';

  @override
  String get calendarReminderChannelDescription =>
      'Уведомления перед началом событий';

  @override
  String calendarOrganizer(String name) {
    return 'Организатор: $name';
  }

  @override
  String get calendarYourAnswer => 'Ваш ответ';

  @override
  String get calendarRsvpAccept => 'Приду';

  @override
  String get calendarRsvpTentative => 'Возможно';

  @override
  String get calendarRsvpDecline => 'Не приду';

  @override
  String get calendarRsvpPending => 'Не ответил';

  @override
  String get calendarRsvpAccepted => 'Принял';

  @override
  String get calendarRsvpTentativeStatus => 'Под вопросом';

  @override
  String get calendarRsvpDeclined => 'Отклонил';

  @override
  String calendarRsvpSummary(
    int accepted,
    int tentative,
    int declined,
    int pending,
  ) {
    return 'Придут: $accepted · Под вопросом: $tentative · Отказались: $declined · Не ответили: $pending';
  }

  @override
  String get calendarMandatory => 'Обязательное событие';

  @override
  String get calendarMandatoryCannotDecline =>
      'От обязательного события нельзя отказаться.';

  @override
  String get calendarJoinCall => 'Присоединиться к звонку';

  @override
  String get calendarJoinCallSoon =>
      'Подключение к звонку из календаря появится в модуле звонков.';

  @override
  String calendarEventTimeInZone(String time, String zone) {
    return '$time по времени $zone';
  }

  @override
  String get calendarDelete => 'Удалить';

  @override
  String get calendarEdit => 'Изменить';

  @override
  String get calendarSave => 'Сохранить';

  @override
  String get calendarDeleteConfirm =>
      'Удалить событие? Участники получат уведомление об отмене.';

  @override
  String get calendarScopeTitleEdit => 'Изменить повторяющееся событие';

  @override
  String get calendarScopeTitleDelete => 'Удалить повторяющееся событие';

  @override
  String get calendarScopeThis => 'Только это событие';

  @override
  String get calendarScopeFollowing => 'Это и последующие';

  @override
  String get calendarScopeAll => 'Все события серии';

  @override
  String get calendarRecreateWarning =>
      'Это изменение нельзя внести в существующее событие: оно будет отменено и создано заново, участники получат новое приглашение.';

  @override
  String get calendarContinue => 'Продолжить';

  @override
  String get calendarEventNotFound => 'Событие не найдено или недоступно.';

  @override
  String get calendarNotOrganizer =>
      'Изменять событие может только организатор.';

  @override
  String get calendarCancelled => 'Отменено';

  @override
  String calendarProblemsBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count изменения не отправлены',
      many: '$count изменений не отправлено',
      few: '$count изменения не отправлены',
      one: '$count изменение не отправлено',
    );
    return '$_temp0';
  }

  @override
  String get calendarConflictTitle => 'Событие изменено на другом устройстве';

  @override
  String get calendarConflictBody =>
      'Применить ваши изменения поверх новой версии или отменить их?';

  @override
  String get calendarConflictOverwrite => 'Применить мои';

  @override
  String get calendarDiscard => 'Отменить изменения';

  @override
  String calendarProblemFailed(String reason) {
    return 'Изменение отклонено: $reason';
  }

  @override
  String get calendarErrTitle =>
      'Название пустое или слишком длинное (не более 300 байт).';

  @override
  String get calendarErrTime => 'Проверьте время начала и окончания.';

  @override
  String get calendarErrLink =>
      'Ссылка на встречу должна начинаться с https://.';

  @override
  String get calendarErrTimezone => 'Неизвестный часовой пояс.';

  @override
  String get calendarErrAudience =>
      'Некоторые участники не из вашей организации.';

  @override
  String get calendarErrRoom => 'Переговорная занята в это время.';

  @override
  String get calendarErrMeetingsDisabled =>
      'В организации отключено создание встреч с участниками.';

  @override
  String get calendarErrTooManyOccurrences =>
      'У серии слишком много повторов: сервер не умеет завершать серию, поэтому «это и последующие» недоступно. Удалите серию целиком или отдельные события.';

  @override
  String get calendarErrOffline => 'Нужна сеть: данные серии ещё не загружены.';

  @override
  String get calendarErrSending =>
      'Событие отправляется — попробуйте через минуту.';

  @override
  String get calendarErrScope =>
      'Это изменение нельзя применить к одному событию серии.';

  @override
  String get calendarErrOverride =>
      'Сервер не вернул перенесённое событие — обновите календарь.';

  @override
  String get callsFilterAll => 'Все';

  @override
  String get callsFilterMissed => 'Пропущенные';

  @override
  String get callsEmpty => 'Звонков пока нет';

  @override
  String get callsMissedEmpty => 'Пропущенных звонков нет';

  @override
  String get callsNew => 'Новый звонок';

  @override
  String get callsAudio => 'Аудиозвонок';

  @override
  String get callsVideo => 'Видеозвонок';

  @override
  String get callsDisabled => 'Звонки недоступны: сервис звонков не настроен.';

  @override
  String get callsIncoming => 'Входящий звонок';

  @override
  String get callsIncomingVideo => 'Входящий видеозвонок';

  @override
  String get callsCalling => 'Вызов…';

  @override
  String get callsConnecting => 'Соединение…';

  @override
  String get callsReconnecting => 'Восстанавливаем связь…';

  @override
  String get callsAccept => 'Ответить';

  @override
  String get callsDecline => 'Отклонить';

  @override
  String get callsHangUp => 'Завершить';

  @override
  String get callsEndForAll => 'Завершить для всех';

  @override
  String get callsLeave => 'Выйти из звонка';

  @override
  String get callsMic => 'Микрофон';

  @override
  String get callsCamera => 'Камера';

  @override
  String get callsSwitchCamera => 'Сменить камеру';

  @override
  String get callsCameraUnavailable => 'Не удалось включить камеру';

  @override
  String get callsSpeaker => 'Динамик';

  @override
  String get callsAudioOutput => 'Аудиовыход';

  @override
  String get callsAudioSettings => 'Звук';

  @override
  String get callsAudioEarpiece => 'Телефон (у уха)';

  @override
  String get callsAudioWired => 'Проводные наушники';

  @override
  String get callsAudioBluetooth => 'Bluetooth';

  @override
  String get callsScreenShare => 'Экран';

  @override
  String get callsScreenShareRefused => 'Демонстрация экрана не разрешена.';

  @override
  String get callsScreenShareNotification =>
      'Идёт демонстрация экрана в XatBox';

  @override
  String get callsParticipants => 'Участники';

  @override
  String get callsModMute => 'Выключить микрофон';

  @override
  String get callsModRemove => 'Удалить из звонка';

  @override
  String get callsMakeModerator => 'Сделать модератором';

  @override
  String get callsHost => 'организатор';

  @override
  String get callsModerator => 'модератор';

  @override
  String get callsYou => 'Вы';

  @override
  String get callsRedial => 'Перезвонить';

  @override
  String get callsEndedHangup => 'Звонок завершён';

  @override
  String get callsEndedDeclined => 'Звонок отклонён';

  @override
  String get callsEndedBusy => 'Абонент занят';

  @override
  String get callsEndedMissed => 'Нет ответа';

  @override
  String get callsEndedCancelled => 'Звонок отменён';

  @override
  String get callsEndedFailed => 'Не удалось соединиться';

  @override
  String get callsEndedNetwork => 'Нет сети — звонок невозможен';

  @override
  String get callsEndedElsewhere => 'Отвечено на другом устройстве';

  @override
  String get callsEndedRemoved => 'Модератор удалил вас из звонка';

  @override
  String get callsPermissionNeeded =>
      'Без доступа к микрофону звонок невозможен (для видео нужна и камера). Разрешите доступ, чтобы позвонить.';

  @override
  String get callsQualityPoor => 'Слабая связь';

  @override
  String get callsQualityLost => 'Связь потеряна';

  @override
  String get callsOutcomeMissed => 'Пропущенный';

  @override
  String get callsOutcomeDeclined => 'Отклонён';

  @override
  String get callsOutcomeCancelled => 'Отменён';

  @override
  String get callsOutcomeBusy => 'Занято';

  @override
  String get callsOutcomeFailed => 'Не состоялся';

  @override
  String get callsOutgoing => 'Исходящий';

  @override
  String get callsIncomingShort => 'Входящий';

  @override
  String get callsActiveBanner => 'Идёт звонок — нажмите, чтобы вернуться';

  @override
  String get callsIncomingChannel => 'Входящие звонки';

  @override
  String get callsMissedChannel => 'Пропущенные звонки';

  @override
  String get callsSelectPeople =>
      'Выберите одного коллегу или нескольких для группового звонка';

  @override
  String callsParticipantsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '$count участник',
    );
    return '$_temp0';
  }

  @override
  String get callsErrNotModerator => 'Это действие доступно только модератору.';

  @override
  String get callsErrAlreadyInCall => 'Вы уже участвуете в другом звонке.';

  @override
  String get callsErrTooMany => 'Слишком много участников для звонка.';

  @override
  String get callsErrInvalidParticipants =>
      'Некоторые участники недоступны для звонка.';

  @override
  String get callsErrRateLimited =>
      'Слишком много звонков подряд. Подождите немного.';

  @override
  String get appOfflineBanner => 'Нет подключения к сети';

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
  String get settingsAppearanceSection => 'Оформление';

  @override
  String get settingsTheme => 'Тема';

  @override
  String get settingsThemeSystem => 'Как в системе';

  @override
  String get settingsThemeLight => 'Светлая';

  @override
  String get settingsThemeDark => 'Тёмная';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get settingsLanguageSystem => 'Как в системе';

  @override
  String get settingsLanguageRu => 'Русский';

  @override
  String get settingsLanguageKk => 'Қазақша';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get mailSortSender => 'Папка для отправителя';

  @override
  String mailSortSenderHint(String sender) {
    return 'Письма от $sender будут собираться в выбранную папку.';
  }

  @override
  String get mailSortSenderIncludeExisting => 'Перенести уже полученные письма';

  @override
  String mailSenderSorted(String name) {
    return 'Отправитель добавлен в «$name»';
  }

  @override
  String get mailSortSenderNoFolders =>
      'Сначала создайте умную папку во «Входящих».';

  @override
  String get settingsSecurityChangePassword => 'Сменить пароль';

  @override
  String get settingsSecurityChangePasswordHint =>
      'Не короче 10 символов. После смены другие сессии продолжают работать — завершите их ниже, если нужно.';

  @override
  String get settingsCurrentPassword => 'Текущий пароль';

  @override
  String get settingsNewPassword => 'Новый пароль (не короче 10 символов)';

  @override
  String get settingsRepeatPassword => 'Повторите новый пароль';

  @override
  String get settingsPasswordsMismatch => 'Пароли не совпадают';

  @override
  String get settingsPasswordChanged => 'Пароль изменён';

  @override
  String get settingsPasswordTooShort => 'Не короче 10 символов';

  @override
  String get mailSettingsClients => 'Почтовые клиенты';

  @override
  String get mailSettingsClientsSubtitle =>
      'IMAP/SMTP для Outlook, Thunderbird и других';

  @override
  String get mailClientsHint =>
      'Параметры подключения для сторонних почтовых программ.';

  @override
  String get mailClientsIncoming => 'Входящая · IMAP';

  @override
  String get mailClientsOutgoing => 'Исходящая · SMTP';

  @override
  String get mailClientsUsername => 'Имя пользователя';

  @override
  String get mailClientsDisabled =>
      'Доступ по IMAP/SMTP отключён администратором.';

  @override
  String get mailClientsEnabled => 'Включено';

  @override
  String get mailClientsDisabledBadge => 'Отключено';

  @override
  String get profileChangePhoto => 'Сменить фото';

  @override
  String get profileRemovePhoto => 'Удалить фото';

  @override
  String get profilePhotoUpdated => 'Фото обновлено';

  @override
  String get profilePhotoHint => 'Фото видят коллеги в почте, чате и каталоге.';

  @override
  String get profileRole => 'Роль';

  @override
  String get profileAdministrator => 'Администратор';

  @override
  String get profileMember => 'Сотрудник';

  @override
  String mailQuickReplyTo(String name) {
    return 'Ответить: $name';
  }

  @override
  String mailQuickReplyAll(int count) {
    return 'Ответить всем · $count';
  }

  @override
  String get mailQuickReplyHint => 'Напишите ответ…';

  @override
  String get mailQuickReplySent => 'Ответ отправлен';

  @override
  String get mailQuickReplyOpenComposer => 'Открыть в редакторе';

  @override
  String get mailQuickReplyAnother => 'Написать ещё';

  @override
  String get mailQuickReplyViewSent => 'В отправленные';

  @override
  String get mailQuickReplySwitchAll => 'Всем';

  @override
  String get mailQuickReplySwitchOne => 'Только отправителю';

  @override
  String get mailRemindMe => 'Напомнить';

  @override
  String get mailRemindLaterToday => 'Сегодня позже';

  @override
  String get mailRemindTomorrow => 'Завтра утром';

  @override
  String get mailRemindNextWeek => 'На следующей неделе';

  @override
  String get mailReminderCreated => 'Напоминание создано';

  @override
  String get mailAddToTasks => 'В задачи';

  @override
  String get mailAddedToTasks => 'Задача создана';

  @override
  String get mailHideList => 'Скрыть список';

  @override
  String get mailShowList => 'Показать список';

  @override
  String get mailMoveToInbox => 'Во входящие';

  @override
  String get mailExternalSender => 'Внешний отправитель';

  @override
  String mailRecipientsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count получателей',
      few: '$count получателя',
      one: '$count получатель',
    );
    return '$_temp0';
  }

  @override
  String get mailConversation => 'Переписка';

  @override
  String get mailConversationHistory => 'история переписки';

  @override
  String mailThreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сообщений',
      few: '$count сообщения',
      one: '$count сообщение',
    );
    return '$_temp0';
  }

  @override
  String get mailLookalikeWarning =>
      'Домен отправителя похож на ваш, но отличается. Возможно, это подделка — проверьте адрес перед ответом.';

  @override
  String mailAttachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вложений',
      few: '$count вложения',
      one: '$count вложение',
    );
    return '$_temp0';
  }

  @override
  String get mailOpenMessage => 'Открыть письмо';

  @override
  String get mailRoleStart => 'Начало';

  @override
  String get mailRoleReply => 'Ответ';

  @override
  String get mailRoleLatest => 'Последнее';

  @override
  String get mailRoleCurrent => 'Это письмо';

  @override
  String get mailEditSend => 'Редактировать и отправить';

  @override
  String get mailCopyAddress => 'Скопировать адрес';

  @override
  String get mailAddressCopied => 'Адрес скопирован';

  @override
  String get mailSaveToBookmarkFolder => 'Сохранить в папку закладок';

  @override
  String get mailCreateBookmarkFolderFirst => 'Сначала создайте папку закладок';

  @override
  String mailSavedToFolder(String name) {
    return 'Сохранено в «$name»';
  }

  @override
  String get mailMoreActions => 'Ещё';

  @override
  String get mailDownload => 'Скачать';

  @override
  String get mailPreview => 'Открыть';

  @override
  String get mailRefresh => 'Обновить почту';

  @override
  String get mailRefreshed => 'Почта обновлена';

  @override
  String get mailNewFolder => 'Новая папка';

  @override
  String get mailCreateFirstFolder => 'Создать первую папку';

  @override
  String get mailNewBookmarkFolder => 'Новая папка закладок';

  @override
  String get mailCreateFirstBookmarkFolder => 'Создать папку закладок';

  @override
  String get mailFolderName => 'Название папки';

  @override
  String get mailFolderNameHint => 'Например: Бухгалтерия';

  @override
  String get mailFolderModalHint =>
      'Умная папка собирает письма выбранных отправителей.';

  @override
  String get mailBookmarkModalHint =>
      'Папка закладок хранит письма, которые вы отметили.';

  @override
  String get mailFolderCreated => 'Папка создана';

  @override
  String get mailBookmarkFolderCreated => 'Папка закладок создана';

  @override
  String get mailCreating => 'Создание…';

  @override
  String get sectionMail => 'Почта';

  @override
  String get sectionWorkspace => 'Рабочее место';

  @override
  String get mailSelectAll => 'Выбрать все';

  @override
  String get mailSelectMessage => 'Выбрать письмо';

  @override
  String mailSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Выбрано $count писем',
      few: 'Выбрано $count письма',
      one: 'Выбрано $count письмо',
    );
    return '$_temp0';
  }

  @override
  String get mailUndo => 'Отменить';

  @override
  String get mailThreadYou => 'Вы';

  @override
  String get mailReplyBadge => 'Ответ';

  @override
  String mailMessagesTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count писем',
      few: '$count письма',
      one: '$count письмо',
    );
    return '$_temp0';
  }

  @override
  String mailSendersTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count отправителей',
      few: '$count отправителя',
      one: '$count отправитель',
    );
    return '$_temp0';
  }

  @override
  String get mailUnreadLabel => 'непрочитано';

  @override
  String get mailBackToAccounts => 'К отправителям';

  @override
  String get mailSelectAccount => 'Выберите отправителя';

  @override
  String get mailSelectAccountHint => 'Письма отправителя появятся здесь.';

  @override
  String get mailExpandInbox => 'Развернуть папки входящих';

  @override
  String get mailCollapseInbox => 'Свернуть папки входящих';

  @override
  String get mailCouldNotCreateFolder => 'Не удалось создать папку';

  @override
  String get mailDeleteSelected => 'Удалить';

  @override
  String get mailBookmarkSelected => 'В закладки';

  @override
  String get mailMarkReadSelected => 'Прочитано';

  @override
  String get mailMarkUnreadSelected => 'Не прочитано';

  @override
  String get mailSpamSelected => 'В спам';

  @override
  String get mailNotSpamSelected => 'Не спам';

  @override
  String mailDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалено $count писем',
      few: 'Удалено $count письма',
      one: 'Удалено $count письмо',
    );
    return '$_temp0';
  }

  @override
  String mailMovedToSpamCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count писем отправлено в спам',
      few: '$count письма отправлено в спам',
      one: '$count письмо отправлено в спам',
    );
    return '$_temp0';
  }

  @override
  String mailRestoredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count писем возвращено во входящие',
      few: '$count письма возвращено во входящие',
      one: '$count письмо возвращено во входящие',
    );
    return '$_temp0';
  }

  @override
  String mailMarkedReadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count писем отмечено прочитанными',
      few: '$count письма отмечено прочитанными',
      one: '$count письмо отмечено прочитанным',
    );
    return '$_temp0';
  }

  @override
  String mailMarkedUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count писем отмечено непрочитанными',
      few: '$count письма отмечено непрочитанными',
      one: '$count письмо отмечено непрочитанным',
    );
    return '$_temp0';
  }

  @override
  String mailBookmarkedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count писем добавлено в закладки',
      few: '$count письма добавлено в закладки',
      one: '$count письмо добавлено в закладки',
    );
    return '$_temp0';
  }

  @override
  String get settingsStyle => 'Стиль';

  @override
  String get settingsStyleHint =>
      'Выберите облик всего приложения. Размер текста и плотность работают поверх него.';

  @override
  String get settingsStyleApplied => 'Стиль применён';

  @override
  String get settingsTextSize => 'Размер текста';

  @override
  String get settingsTextSizeSmall => 'Мелкий';

  @override
  String get settingsTextSizeMedium => 'Обычный';

  @override
  String get settingsTextSizeLarge => 'Крупный';

  @override
  String get settingsListDensity => 'Плотность списка';

  @override
  String get settingsDensityCompact => 'Плотно';

  @override
  String get settingsDensityNormal => 'Обычно';

  @override
  String get settingsDensitySpacious => 'Просторно';

  @override
  String get settingsAppearanceHint =>
      'Выберите размер текста и плотность списка, удобные лично вам. Настройка сохраняется на этом устройстве.';

  @override
  String get skinStandard => 'Стандарт';

  @override
  String get skinStandardHint => 'Спокойная классика, светлая или тёмная';

  @override
  String get skinSteppe => 'Степь';

  @override
  String get skinSteppeHint => 'Тёплый песок и терракота';

  @override
  String get skinPaper => 'Бумага';

  @override
  String get skinPaperHint => 'Кремовая бумага, чернила и антиква';

  @override
  String get skinGraphite => 'Графит';

  @override
  String get skinGraphiteHint => 'Тёмный, моноширинный, янтарный акцент';

  @override
  String get skinKok => 'Көк';

  @override
  String get skinKokHint => 'Бирюза и золото, тёмное меню';

  @override
  String get skinMidnight => 'Полночь';

  @override
  String get skinMidnightHint => 'Глубокий индиго, сиреневый акцент';

  @override
  String get skinTerminal => 'Терминал';

  @override
  String get skinTerminalHint => 'Зелёный фосфор, весь текст моноширинный';

  @override
  String get skinLilac => 'Сирень';

  @override
  String get skinLilacHint => 'Лавандовый фон, слива, брусковый шрифт';

  @override
  String get skinContrast => 'Контраст';

  @override
  String get skinContrastHint =>
      'Чёрное на белом, рамки 2px — для слабого зрения';

  @override
  String get skinForest => 'Лес';

  @override
  String get skinForestHint => 'Сосновая тьма, мшистый акцент';

  @override
  String get settingsSecuritySection => 'Безопасность';

  @override
  String get settingsLockPin => 'Вход по PIN-коду';

  @override
  String get settingsLockPinHint => 'Запрашивать PIN при открытии приложения';

  @override
  String get settingsLockChangePin => 'Сменить PIN-код';

  @override
  String get settingsLockBiometric => 'Разблокировка биометрией';

  @override
  String get settingsLockTimeout => 'Блокировать';

  @override
  String get settingsLockOnClose => 'Запрашивать PIN при закрытии окна';

  @override
  String get settingsLockOnCloseHint =>
      'Крестик прячет XatBox в трей; при следующем открытии окна — PIN-код';

  @override
  String get settingsLockTimeoutImmediately => 'Сразу после сворачивания';

  @override
  String settingsLockTimeoutMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Через $minutes минуты',
      many: 'Через $minutes минут',
      few: 'Через $minutes минуты',
      one: 'Через $minutes минуту',
    );
    return '$_temp0';
  }

  @override
  String get settingsHideContent => 'Скрывать содержимое в списке приложений';

  @override
  String get settingsHideContentHint =>
      'На Android также запрещает снимки экрана';

  @override
  String settingsStorageUsed(String size) {
    return 'Занято на устройстве: $size';
  }

  @override
  String get lockTitle => 'Введите PIN-код';

  @override
  String lockWrong(int attempts) {
    String _temp0 = intl.Intl.pluralLogic(
      attempts,
      locale: localeName,
      other: 'Неверный PIN-код. Осталось $attempts попытки',
      many: 'Неверный PIN-код. Осталось $attempts попыток',
      few: 'Неверный PIN-код. Осталось $attempts попытки',
      one: 'Неверный PIN-код. Осталась $attempts попытка',
    );
    return '$_temp0';
  }

  @override
  String lockThrottled(int seconds) {
    return 'Слишком много попыток. Повторите через $seconds с';
  }

  @override
  String get lockBiometric => 'Разблокировать биометрией';

  @override
  String get lockBiometricReason => 'Разблокируйте XatBox';

  @override
  String get lockForgot => 'Забыли PIN-код?';

  @override
  String get lockForgotConfirm =>
      'Выйти из учётной записи? Затем войдите по паролю и задайте новый PIN-код.';

  @override
  String get lockForgotSignOut => 'Выйти';

  @override
  String get lockDelete => 'Удалить цифру';

  @override
  String get lockSetupTitle => 'PIN-код';

  @override
  String get lockSetupEnter => 'Придумайте PIN-код из 4–6 цифр';

  @override
  String get lockSetupRepeat => 'Повторите PIN-код';

  @override
  String get lockSetupMismatch => 'PIN-коды не совпадают. Попробуйте ещё раз.';

  @override
  String get lockSetupNext => 'Далее';

  @override
  String get loginShowPassword => 'Показать пароль';

  @override
  String get loginHidePassword => 'Скрыть пароль';

  @override
  String get callsDetailsTitle => 'Звонок';

  @override
  String get callsDetailsType => 'Тип';

  @override
  String get callsDetailsResult => 'Итог';

  @override
  String get callsDetailsStarted => 'Начало';

  @override
  String get callsDetailsDuration => 'Длительность';

  @override
  String get callsDetailsNoConversation => 'Разговора не было';

  @override
  String get callsDetailsMessage => 'Написать';

  @override
  String get callsModeDirect => 'Личный';

  @override
  String get callsModeGroup => 'Групповой';

  @override
  String get callsModeConference => 'Конференция';

  @override
  String get callsOutcomeAnswered => 'Состоялся';

  @override
  String get callsRoleParticipant => 'участник';

  @override
  String get callsPStatusInvited => 'приглашён';

  @override
  String get callsPStatusRinging => 'звонит';

  @override
  String get callsPStatusAccepted => 'принял';

  @override
  String get callsPStatusJoined => 'в звонке';

  @override
  String get callsPStatusLeft => 'вышел';

  @override
  String get callsPStatusDeclined => 'отклонил';

  @override
  String get callsPStatusMissed => 'не ответил';

  @override
  String get callsPStatusBusy => 'занят';

  @override
  String get callsPStatusRemoved => 'удалён';

  @override
  String get callsErrNotFound => 'Звонок не найден.';

  @override
  String get callsInvite => 'Добавить участников';

  @override
  String callsInviteSubmit(int count) {
    return 'Пригласить ($count)';
  }

  @override
  String get callsInviteSent => 'Приглашения отправлены.';

  @override
  String get callsInviteNobody => 'Все найденные коллеги уже в звонке';

  @override
  String get callsMinimize => 'Свернуть';

  @override
  String get callsReturnToCall => 'Вернуться к звонку';

  @override
  String get callsMore => 'Ещё';

  @override
  String get callsRaiseHand => 'Поднять руку';

  @override
  String get callsLowerHand => 'Опустить руку';

  @override
  String get callsHandRaised => 'Поднята рука';

  @override
  String get callsReactions => 'Реакции';

  @override
  String get callsChat => 'Чат';

  @override
  String get callsChatTitle => 'Чат звонка';

  @override
  String get callsChatHint => 'Сообщение…';

  @override
  String get callsChatSend => 'Отправить';

  @override
  String get callsChatEmpty => 'Сообщения увидят все участники звонка';

  @override
  String get callsChatEmptyLinked =>
      'Сообщения увидят участники звонка, они сохранятся в чате';

  @override
  String get callsChatFailed => 'Не отправлено — нажмите, чтобы повторить';

  @override
  String get callsChatEmoji => 'Эмодзи';

  @override
  String get callsChatClose => 'Закрыть чат';

  @override
  String get callsRecord => 'Записать';

  @override
  String get callsRecordStop => 'Остановить запись';

  @override
  String get callsRecordConfirmTitle => 'Записать звонок?';

  @override
  String get callsRecordConfirmBody =>
      'Все участники увидят индикатор записи. Запись будет доступна участникам в карточке звонка.';

  @override
  String get callsRecordConfirmStart => 'Начать запись';

  @override
  String get callsRecordingBanner => 'Звонок записывается';

  @override
  String callsRecordingBannerBy(String name) {
    return 'Запись включил(а) $name';
  }

  @override
  String get callsRecordingStopped => 'Запись остановлена';

  @override
  String get callsRecordings => 'Записи';

  @override
  String get callsRecordingInProgress => 'Идёт запись';

  @override
  String get callsRecordingFailed => 'Запись не удалась';

  @override
  String get callsRecordingVideo => 'Видеозапись';

  @override
  String get callsRecordingAudio => 'Аудиозапись';

  @override
  String get callsRecordingDownload => 'Скачать';

  @override
  String get callsRecordingOpen => 'Открыть';

  @override
  String get callsRecordingNoApp => 'Нет приложения, чтобы открыть файл';

  @override
  String get callsRecordingDownloadFailed => 'Не удалось скачать запись';

  @override
  String get callsErrRecordingUnavailable =>
      'Запись сейчас недоступна. Попробуйте позже.';

  @override
  String get callsErrRecordingActive => 'Звонок уже записывается';

  @override
  String get callsErrRecordingDisabled => 'Запись звонков отключена';

  @override
  String get callsLayoutGrid => 'Сетка';

  @override
  String get callsLayoutSpotlight => 'Спикер';

  @override
  String get callsDeclineWithMessage => 'Отклонить с сообщением';

  @override
  String get callsQuickReplyBusy => 'Не могу говорить, напишу позже.';

  @override
  String get callsQuickReplyLater => 'Перезвоню через несколько минут.';

  @override
  String get callsQuickReplyMeeting => 'Я на встрече.';

  @override
  String get callsQuickReplySent => 'Сообщение отправлено';

  @override
  String get callsMessage => 'Сообщение';

  @override
  String get callsModMuteCamera => 'Выключить камеру';

  @override
  String get callsModStopScreenShare => 'Остановить показ экрана';

  @override
  String get callsMakeParticipant => 'Сделать участником';

  @override
  String get callsRingAgain => 'Позвонить ещё раз';

  @override
  String get callsRingAgainSent => 'Вызов отправлен';

  @override
  String get callsSectionInCall => 'В звонке';

  @override
  String get callsSectionNotInCall => 'Не подключены';

  @override
  String get callsClose => 'Закрыть';

  @override
  String get callsTitleHint => 'Название звонка (необязательно)';

  @override
  String get meetingsSection => 'Встречи';

  @override
  String get meetingsToday => 'Сегодня';

  @override
  String get meetingJoin => 'Подключиться';

  @override
  String get meetingLive => 'Идёт';

  @override
  String get meetingOpenNow => 'Можно подключаться';

  @override
  String meetingOpensAt(String time) {
    return 'Откроется в $time';
  }

  @override
  String get meetingOpensSoonHint => 'Подключиться можно за 10 минут до начала';

  @override
  String get meetingPrejoinTitle => 'Видеовстреча';

  @override
  String get meetingDevices => 'Устройства';

  @override
  String meetingDeviceMic(String name) {
    return 'Микрофон: $name';
  }

  @override
  String meetingDeviceCamera(String name) {
    return 'Камера: $name';
  }

  @override
  String get meetingDeviceDefault => 'по умолчанию';

  @override
  String get meetingDeviceOff => 'выключен(а)';

  @override
  String get meetingCameraOff => 'Камера выключена';

  @override
  String get meetingPreviewUnavailable => 'Предпросмотр камеры недоступен';

  @override
  String get meetingLobbyTitle => 'Ожидайте подтверждения';

  @override
  String get meetingLobbyText =>
      'Организатор получил запрос и скоро впустит вас.';

  @override
  String get meetingLobbyDenied => 'Организатор не впустил вас во встречу';

  @override
  String get meetingNotStarted => 'Встреча ещё не началась';

  @override
  String get meetingEnded => 'Встреча завершена';

  @override
  String get meetingCancelled => 'Встреча отменена';

  @override
  String get meetingNotFound => 'Встреча не найдена';

  @override
  String get meetingGuestLinkTitle => 'Это гостевая ссылка';

  @override
  String get meetingGuestLinkText =>
      'Гостевые ссылки открываются в браузере — для людей без учётной записи.';

  @override
  String get meetingOpenInBrowser => 'Открыть в браузере';

  @override
  String get meetingPermissionDenied => 'Нет доступа к камере или микрофону';

  @override
  String get calendarXatBoxMeeting => 'Добавить видеовстречу XatBox';

  @override
  String get calendarXatBoxMeetingHint =>
      'Ссылка для подключения появится в событии';

  @override
  String get calendarXatBoxMeetingAdded => 'Видеовстреча XatBox добавлена';

  @override
  String get calendarXatBoxMeetingAllDay =>
      'Недоступно для событий на весь день';

  @override
  String calendarXatBoxMeetingDescription(String url) {
    return 'Видеовстреча XatBox: $url';
  }

  @override
  String get calendarXatBoxMeetingFailed => 'Не удалось создать видеовстречу';

  @override
  String get calendarMeetingReminderBody =>
      'Через 5 минут. Нажмите «Подключиться»';

  @override
  String callsLobbyWaiting(int count) {
    return 'Ожидают: $count';
  }

  @override
  String get callsLobbyAdmit => 'Впустить';

  @override
  String get callsLobbyDeny => 'Отклонить';

  @override
  String get callsLobbyStaff => 'Сотрудник';

  @override
  String callsLobbyBanner(int count) {
    return 'Ожидают входа: $count';
  }

  @override
  String get callsLobbyOpen => 'Открыть';

  @override
  String get callsGuest => 'Гость';

  @override
  String get callsGuestsSection => 'Гости';

  @override
  String get callsGuestInvite => 'Пригласить гостя';

  @override
  String get callsGuestLinkTitle => 'Гостевая ссылка';

  @override
  String get callsGuestLinkHint =>
      'Для людей без учётной записи XatBox: ссылка откроется в браузере, вы впустите гостя сами.';

  @override
  String get callsGuestLinkExpires => 'Действует';

  @override
  String get callsGuestLinkHour => '1 час';

  @override
  String get callsGuestLinkDay => '1 день';

  @override
  String get callsGuestLinkWeek => '7 дней';

  @override
  String get callsGuestLinkUses => 'Сколько человек';

  @override
  String callsGuestLinkUsesValue(int count) {
    return 'до $count чел.';
  }

  @override
  String get callsGuestLinkLobby => 'Впускать вручную';

  @override
  String get callsGuestLinkScreen => 'Разрешить демонстрацию экрана';

  @override
  String get callsGuestLinkCreate => 'Создать ссылку';

  @override
  String get callsGuestLinkCopy => 'Копировать ссылку';

  @override
  String get callsGuestLinkCopied => 'Ссылка скопирована';

  @override
  String get callsQualitySettings => 'Качество';

  @override
  String get callsQualityAudio => 'Обработка звука';

  @override
  String get callsQualityVideo => 'Видео';

  @override
  String get callsNoiseSuppression => 'Шумоподавление';

  @override
  String get callsEchoCancellation => 'Эхоподавление';

  @override
  String get callsAutoGain => 'Автоусиление';

  @override
  String get callsMusicMode => 'Режим музыки';

  @override
  String get callsMusicModeHint => 'Без фильтров голоса и с высоким битрейтом';

  @override
  String get callsDataSaver => 'Трафик';

  @override
  String get callsDataSaverOff => 'Обычный';

  @override
  String get callsDataSaverLow => 'Экономия';

  @override
  String get callsDataSaverAudio => 'Только звук';

  @override
  String get callsDataSaverHint =>
      '«Экономия» принимает видео в низком качестве, «Только звук» не принимает и не отправляет видео.';

  @override
  String get callsBackgroundBlur => 'Размытие фона';

  @override
  String get callsBackgroundBlurUnavailable =>
      'Пока недоступно в мобильном приложении';

  @override
  String get callsPoorNetworkTitle => 'Слабая сеть';

  @override
  String get callsPoorNetworkText =>
      'Включить экономию трафика, чтобы звук не прерывался?';

  @override
  String get callsPoorNetworkAccept => 'Экономить';

  @override
  String get callsPoorNetworkDismiss => 'Не сейчас';

  @override
  String get callsTranscript => 'Расшифровка';

  @override
  String get callsTranscriptPending => 'Расшифровка готовится';

  @override
  String get callsTranscriptFailed => 'Расшифровка не удалась';

  @override
  String get callsTranscriptRetry => 'Повторить расшифровку';

  @override
  String get callsTranscriptSearch => 'Поиск в расшифровке';

  @override
  String callsTranscriptMatches(int count) {
    return 'Найдено: $count';
  }

  @override
  String get callsTranscriptKeyPhrases => 'Ключевые фразы';

  @override
  String get callsTranscriptAutomatic => 'автоматически';

  @override
  String get callsTranscriptKeyPhrasesNote =>
      'Выбраны автоматически по частоте слов — это не пересказ разговора.';

  @override
  String get callsTranscriptCopy => 'Копировать текст';

  @override
  String get callsTranscriptCopied => 'Текст скопирован';

  @override
  String get callsTranscriptEmpty => 'В записи не распознана речь';

  @override
  String get callsTranscriptNoSeek => 'Время указано от начала записи.';

  @override
  String get callsErrNotOrganizer =>
      'Изменить встречу может только организатор';

  @override
  String get callsErrLobbyDecided => 'Запрос уже обработан';

  @override
  String get callsErrGuests => 'Гостевой доступ недоступен';

  @override
  String get callsErrTranscriptBusy =>
      'Очередь расшифровки занята — попробуйте позже';

  @override
  String get callsGroupCall => 'Групповой звонок';

  @override
  String get callsSwapVideo => 'Поменять местами';

  @override
  String get callsVideoPaused => 'Видео приостановлено';

  @override
  String get chatAttachContact => 'Контакт';

  @override
  String get chatContactPickTitle => 'Отправить контакт';

  @override
  String get chatContactWrite => 'Написать';

  @override
  String get chatContactCall => 'Позвонить';

  @override
  String get chatContactInvalid => 'Этот контакт недоступен.';

  @override
  String get chatVideoOpen => 'Открыть видео';

  @override
  String get chatMediaLoadPreview => 'Загрузить превью';

  @override
  String get chatAvatarChange => 'Сменить фото группы';

  @override
  String get chatAvatarUpdated => 'Фото группы обновлено';

  @override
  String get chatStorageSection => 'Данные чата';

  @override
  String get chatAutoDownloadTitle => 'Автозагрузка медиа';

  @override
  String get chatAutoDownloadHint =>
      'Превью фото и видео, голосовые сообщения. Оригиналы файлов загружаются только по нажатию.';

  @override
  String get chatAutoDownloadNever => 'Никогда';

  @override
  String get chatAutoDownloadWifi => 'Только Wi‑Fi';

  @override
  String get chatAutoDownloadAlways => 'Всегда';

  @override
  String get chatMessagesKeptTitle => 'Хранить сообщений в каждом чате';

  @override
  String chatMediaSize(String size) {
    return 'Медиафайлы чата: $size';
  }

  @override
  String get chatMediaClear => 'Очистить медиафайлы';

  @override
  String get chatMediaCleared => 'Медиафайлы чата удалены';

  @override
  String get calendarBusyTitle => 'Занятость';

  @override
  String get calendarBusyYou => 'Вы';

  @override
  String get calendarBusyFree => 'свободен';

  @override
  String get calendarBusyUnavailable => 'Не удалось загрузить занятость.';

  @override
  String get calendarFindTime => 'Подобрать время';

  @override
  String get calendarFindTimeHint =>
      'Рабочие часы организации, ближайшие 7 дней от выбранной даты.';

  @override
  String get calendarFindTimeEmpty => 'Свободных слотов не найдено.';

  @override
  String get calendarRoom => 'Переговорная';

  @override
  String get calendarRoomNone => 'Без переговорной';

  @override
  String calendarRoomSeats(int count) {
    return 'Мест: $count';
  }

  @override
  String get calendarRoomsEmpty => 'Нет доступных переговорных';

  @override
  String get calendarRoomBusy => 'Бронь переговорной';

  @override
  String get calendarRoomBusyWarning =>
      'Переговорная занята в выбранное время.';

  @override
  String get contactsTab => 'Контакты';

  @override
  String get contactsTitle => 'Контакты';

  @override
  String get contactsSearchHint => 'Поиск по имени или почте';

  @override
  String get contactsLoadMore => 'Показать ещё';

  @override
  String get contactsClearSearch => 'Очистить поиск';

  @override
  String get contactsEmpty => 'В справочнике пока никого нет';

  @override
  String get contactsNotFound => 'Никого не нашлось';

  @override
  String get contactsChatDisabled =>
      'Справочник сотрудников работает через сервис чата, а он не настроен в этой сборке.';

  @override
  String get contactsCachedBanner =>
      'Не удалось обновить — показан сохранённый список';

  @override
  String contactsLimitHint(int count) {
    return 'Показаны первые $count сотрудников — уточните поиск';
  }

  @override
  String get contactsProfileTitle => 'Сотрудник';

  @override
  String get contactsProfileNotFound => 'Сотрудник не найден в справочнике';

  @override
  String get contactsWrite => 'Написать';

  @override
  String get contactsAudioCall => 'Аудиозвонок';

  @override
  String get contactsVideoCall => 'Видеозвонок';

  @override
  String get contactsWriteEmail => 'Написать письмо';

  @override
  String get contactsEmail => 'Почта';

  @override
  String get contactsDepartment => 'Отдел';

  @override
  String get contactsPosition => 'Должность';

  @override
  String get contactsFilterAll => 'Все';

  @override
  String get contactsFilterOnline => 'В сети';

  @override
  String get contactsFilterFavourites => 'Избранные';

  @override
  String get contactsFilterDepartment => 'Отдел';

  @override
  String get contactsDepartmentsTitle => 'Отделы';

  @override
  String get contactsAllDepartments => 'Все отделы';

  @override
  String get contactsNoDepartment => 'Без отдела';

  @override
  String get contactsDepartmentsEmpty => 'Список отделов недоступен';

  @override
  String get contactsGroupByDepartment => 'Группировать по отделам';

  @override
  String get contactsGroupByName => 'По алфавиту';

  @override
  String get contactsFavourites => 'Избранные';

  @override
  String get contactsRecent => 'Недавние';

  @override
  String get contactsAddFavourite => 'Добавить в избранное';

  @override
  String get contactsRemoveFavourite => 'Убрать из избранного';

  @override
  String get contactsNotFoundHint =>
      'Проверьте написание или выберите другой отдел';

  @override
  String get contactsNoOnline => 'Сейчас никого нет в сети';

  @override
  String get contactsNoFavourites => 'Нет избранных коллег';

  @override
  String get contactsNoFavouritesHint =>
      'Откройте профиль и нажмите звёздочку — коллега появится здесь';

  @override
  String get contactsMailbox => 'Почтовый ящик';

  @override
  String contactsCopied(String value) {
    return 'Скопировано: $value';
  }

  @override
  String get contactsCopy => 'Скопировать';

  @override
  String get contactsManager => 'Руководитель';

  @override
  String contactsEmployeeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сотрудника',
      many: '$count сотрудников',
      few: '$count сотрудника',
      one: '$count сотрудник',
    );
    return '$_temp0';
  }

  @override
  String get contactsColleagues => 'Коллеги из отдела';

  @override
  String get contactsSharedChats => 'Общие группы';

  @override
  String contactsChatMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '$count участник',
    );
    return '$_temp0';
  }

  @override
  String get contactsShare => 'Поделиться контактом';

  @override
  String get contactsShareToChat => 'Отправить в чат';

  @override
  String get contactsCopyVCard => 'Скопировать визитку (vCard)';

  @override
  String get contactsVCardCopied => 'Визитка скопирована';

  @override
  String contactsShareSent(String chat) {
    return 'Контакт отправлен в «$chat»';
  }

  @override
  String get contactsShareNoChats => 'Нет чатов для отправки';

  @override
  String get contactsActionAudio => 'Аудио';

  @override
  String get contactsActionVideo => 'Видео';

  @override
  String get contactsActionEmail => 'Письмо';

  @override
  String get contactsIndexHint => 'Быстрый переход по алфавиту';

  @override
  String get contactsSeenJustNow => 'был(а) только что';

  @override
  String contactsSeenMinutes(int count) {
    return 'был(а) $count мин назад';
  }

  @override
  String contactsSeenHours(int count) {
    return 'был(а) $count ч назад';
  }

  @override
  String get notificationsTitle => 'Уведомления';

  @override
  String get notificationsReadAll => 'Прочитать все';

  @override
  String get notificationsEmpty => 'Уведомлений пока нет';

  @override
  String notificationsLimitNote(int count) {
    return 'Показаны последние $count уведомлений';
  }

  @override
  String get mailFormatToolbar => 'Форматирование';

  @override
  String get mailFormatBold => 'Жирный';

  @override
  String get mailFormatItalic => 'Курсив';

  @override
  String get mailFormatUnderline => 'Подчёркнутый';

  @override
  String get mailFormatBulletList => 'Маркированный список';

  @override
  String get mailFormatNumberedList => 'Нумерованный список';

  @override
  String get mailFormatQuote => 'Цитата';

  @override
  String get mailFormatLink => 'Ссылка';

  @override
  String get mailFormatTextColor => 'Цвет текста';

  @override
  String get mailFormatHighlight => 'Цвет выделения';

  @override
  String get mailFormatColorNone => 'Без цвета';

  @override
  String get mailFormatTable => 'Таблица';

  @override
  String get mailFormatPreview => 'Предпросмотр';

  @override
  String get mailFormatEdit => 'Редактировать';

  @override
  String get mailFormatHelp =>
      '**жирный**  _курсив_  __подчёркнутый__  - список  1. список  > цитата  [текст](https://…)';

  @override
  String get mailPreviewEmpty => 'Письмо пока пустое';

  @override
  String get mailLinkDialogTitle => 'Вставить ссылку';

  @override
  String get mailLinkUrl => 'Адрес ссылки';

  @override
  String get mailLinkUrlHint => 'https://… или mailto:…';

  @override
  String get mailLinkText => 'Текст ссылки';

  @override
  String get mailLinkInvalid =>
      'Допустимы только ссылки https://, http:// и mailto:';

  @override
  String get mailLinkInsert => 'Вставить';

  @override
  String get mailSignaturePreviewTitle =>
      'При отправке сервер добавит подпись:';

  @override
  String get mailSignaturePreviewNote =>
      'Предварительный вид: для ответов и внешних адресатов правила организации могут отличаться.';

  @override
  String get mailThreadsMode => 'Цепочки писем';

  @override
  String get mailSettingsTitle => 'Настройки почты';

  @override
  String get mailSettingsSignature => 'Подпись';

  @override
  String get mailSettingsSignatureSubtitle => 'Личная подпись в письмах';

  @override
  String get mailSettingsVacation => 'Автоответ';

  @override
  String get mailSettingsVacationSubtitle => 'Ответ, пока вас нет на месте';

  @override
  String get mailSettingsBlocked => 'Заблокированные отправители';

  @override
  String get mailSettingsBlockedSubtitle => 'Их письма попадают в «Спам»';

  @override
  String get mailSettingsBookmarkFolders => 'Папки закладок';

  @override
  String get mailSettingsBookmarkFoldersSubtitle => 'Подборки помеченных писем';

  @override
  String get mailSettingsSaved => 'Сохранено';

  @override
  String get mailSignatureLabel => 'Текст подписи';

  @override
  String get mailSignatureDefaultNote =>
      'Сейчас используется подпись по умолчанию.';

  @override
  String get mailSignatureRestoreDefault => 'Вернуть подпись по умолчанию';

  @override
  String get mailSignatureTooLong => 'Подпись длиннее 2000 байт.';

  @override
  String mailSignatureBytes(int used, int max) {
    return '$used / $max байт';
  }

  @override
  String get mailSignatureNotApplied =>
      'Организация сейчас не добавляет личную подпись к письмам.';

  @override
  String get mailVacationEnabled => 'Автоответ включён';

  @override
  String get mailVacationSubject => 'Тема (необязательно)';

  @override
  String get mailVacationBody => 'Текст автоответа';

  @override
  String get mailVacationStartsOn => 'Начало';

  @override
  String get mailVacationEndsOn => 'Окончание';

  @override
  String get mailVacationNoDate => 'Без даты';

  @override
  String get mailVacationClearDate => 'Убрать дату';

  @override
  String get mailVacationTimeZone => 'Часовой пояс';

  @override
  String get mailVacationActiveNow => 'Автоответ отправляется сейчас';

  @override
  String get mailVacationPending =>
      'Автоответ начнёт отправляться с даты начала';

  @override
  String get mailVacationInactive => 'Автоответ не отправляется';

  @override
  String get mailVacationNote =>
      'Ответ получают внешние отправители, каждый не чаще раза в 3 дня.';

  @override
  String get mailVacationBodyRequired => 'Введите текст автоответа.';

  @override
  String get mailVacationSubjectTooLong => 'Тема длиннее 200 символов.';

  @override
  String get mailVacationBodyTooLong => 'Текст длиннее 4000 символов.';

  @override
  String get mailVacationDatesInvalid =>
      'Окончание не может быть раньше начала.';

  @override
  String get mailVacationTimeZoneInvalid => 'Неизвестный часовой пояс.';

  @override
  String get mailSyncPending => 'Изменения применяются на почтовом сервере…';

  @override
  String get mailSyncFailed =>
      'Почтовый сервер не принял изменения. Сохраните ещё раз.';

  @override
  String get mailBlockedEmpty => 'Заблокированных отправителей нет';

  @override
  String get mailBlockedAdd => 'Заблокировать';

  @override
  String get mailBlockedAddTitle => 'Заблокировать отправителя';

  @override
  String get mailBlockedValue => 'Домен, адрес, IP или сеть';

  @override
  String get mailBlockedValueHint =>
      'example.com, 203.0.113.7, 198.51.100.0/24';

  @override
  String get mailBlockedNote => 'Заметка (необязательно)';

  @override
  String mailBlockedRemoveTitle(String pattern) {
    return 'Разблокировать $pattern?';
  }

  @override
  String get mailBlockedRemove => 'Разблокировать';

  @override
  String mailBlockedCount(int count, int limit) {
    return '$count из $limit';
  }

  @override
  String get mailBlockedKindDomain => 'Домен';

  @override
  String get mailBlockedKindIp => 'IP-адрес';

  @override
  String get mailBlockedKindNetwork => 'Сеть';

  @override
  String get mailBookmarkFoldersEmpty => 'Папок закладок пока нет';

  @override
  String get mailBookmarkFolderCreate => 'Создать папку';

  @override
  String get mailBookmarkFolderName => 'Название папки';

  @override
  String get mailBookmarkFolderNameInvalid => 'Название — от 1 до 80 символов.';

  @override
  String mailBookmarkFolderDeleteTitle(String name) {
    return 'Удалить папку «$name»?';
  }

  @override
  String get mailBookmarkFolderDeleteBody =>
      'Письма останутся в своих папках и сохранят закладку.';

  @override
  String get mailErrFolderExists => 'Папка с таким названием уже есть.';

  @override
  String get mailErrInvalidList => 'Можно только блокировать отправителей.';

  @override
  String get mailErrEmptyPattern => 'Укажите домен, адрес, IP или сеть.';

  @override
  String get mailErrTopLevelDomain => 'Нельзя заблокировать всю доменную зону.';

  @override
  String get mailErrNetworkTooWide =>
      'Сеть слишком широкая: допускается не шире /8.';

  @override
  String get mailErrIpv6Network =>
      'Диапазоны IPv6 не поддерживаются — укажите точный адрес.';

  @override
  String get mailErrInvalidPattern => 'Это не домен, адрес, IP или сеть.';

  @override
  String get mailErrNoteTooLong => 'Заметка длиннее 200 символов.';

  @override
  String get mailErrRuleLimit => 'Достигнут лимит в 500 записей.';

  @override
  String get mailErrRuleExists => 'Этот отправитель уже заблокирован.';

  @override
  String get mailErrRuleNotFound => 'Запись уже удалена.';

  @override
  String get mailErrIcsNotFound => 'В письме не найдено приглашение.';

  @override
  String get mailErrIcsTooLarge => 'Файл приглашения слишком большой.';

  @override
  String get mailErrInvalidIcs => 'Не удалось прочитать приглашение.';

  @override
  String get mailErrInvalidRsvp => 'Недопустимый ответ на приглашение.';

  @override
  String get mailReportPhishing => 'Сообщить о фишинге';

  @override
  String get mailReportPhishingTitle => 'Сообщить о фишинге?';

  @override
  String get mailReportPhishingBody =>
      'Письмо переместится в «Спам» и будет отправлено на проверку. Не переходите по ссылкам из него и не открывайте вложения.';

  @override
  String get mailReportPhishingConfirm => 'Сообщить';

  @override
  String get mailReportedPhishing => 'Сообщение о фишинге отправлено';

  @override
  String get mailDeliveryStatus => 'Статус доставки';

  @override
  String get mailDeliveryEmpty =>
      'Нет данных о доставке: письмо отправлено не через платформу.';

  @override
  String get mailDeliveryRecipients => 'Получатели';

  @override
  String get mailDeliveryHistory => 'История';

  @override
  String get mailDeliveryStateAccepted => 'Принято';

  @override
  String get mailDeliveryStateProcessing => 'Обрабатывается';

  @override
  String get mailDeliveryStateDelivered => 'Доставлено';

  @override
  String get mailDeliveryStatePartiallyDelivered => 'Доставлено частично';

  @override
  String get mailDeliveryStateFailed => 'Не доставлено';

  @override
  String get mailDeliveryStateQuarantined => 'В карантине';

  @override
  String get mailDeliveryStatePending => 'Ожидает';

  @override
  String get mailDeliveryStateRelayed => 'Передано внешнему серверу';

  @override
  String get mailDeliveryStateDraft => 'Черновик';

  @override
  String get mailDeliveryEventAccepted => 'Принято к отправке';

  @override
  String get mailDeliveryEventScanned => 'Проверено';

  @override
  String get mailDeliveryEventDeliveredLocal => 'Доставлено в ящик';

  @override
  String get mailDeliveryEventRelayed => 'Передано внешнему серверу';

  @override
  String get mailDeliveryEventFailed => 'Ошибка доставки';

  @override
  String get mailInviteTitle => 'Приглашение в календарь';

  @override
  String get mailInviteMethodRequest => 'Приглашение';

  @override
  String get mailInviteMethodCancel => 'Отмена события';

  @override
  String get mailInviteMethodReply => 'Ответ участника';

  @override
  String mailInviteOrganizer(String name) {
    return 'Организатор: $name';
  }

  @override
  String mailInviteYourStatus(String status) {
    return 'Ваш ответ: $status';
  }

  @override
  String get mailInviteStatusAccepted => 'принято';

  @override
  String get mailInviteStatusTentative => 'возможно';

  @override
  String get mailInviteStatusDeclined => 'отклонено';

  @override
  String get mailInviteStatusPending => 'нет ответа';

  @override
  String get mailInviteAccept => 'Приму';

  @override
  String get mailInviteMaybe => 'Возможно';

  @override
  String get mailInviteDecline => 'Отклоню';

  @override
  String get mailInviteCancelledNote => 'Организатор отменил событие.';

  @override
  String get mailInviteApplyCancel => 'Отметить отмену в календаре';

  @override
  String mailInviteReplyFrom(String who, String status) {
    return '$who ответил(а): $status';
  }

  @override
  String get mailInviteApplyReply => 'Обновить ответ в календаре';

  @override
  String get mailInviteOpenCalendar => 'Открыть в календаре';

  @override
  String get mailInviteSaved => 'Ответ сохранён в календаре';

  @override
  String get mailInviteRecurring => 'Повторяющееся событие';

  @override
  String mailInviteInZone(String time, String zone) {
    return '$time ($zone)';
  }

  @override
  String get chatDraft => 'Черновик';

  @override
  String get chatUnreadMessages => 'Непрочитанные сообщения';

  @override
  String get chatScrollToBottom => 'Вниз';

  @override
  String chatForwardedFrom(String name) {
    return 'Переслано от $name';
  }

  @override
  String get chatSelect => 'Выбрать';

  @override
  String chatDeleteSelected(int count) {
    return 'Удалить сообщения: $count?';
  }

  @override
  String get chatSearchInChat => 'Поиск в чате';

  @override
  String get chatSearchNoResults => 'Ничего не найдено';

  @override
  String chatSearchPosition(int current, int total) {
    return '$current из $total';
  }

  @override
  String get chatMessageNotFound => 'Сообщение недоступно';

  @override
  String get chatAttachCamera => 'Камера';

  @override
  String get chatAttachGallery => 'Галерея';

  @override
  String get chatMoreReactions => 'Другие реакции';

  @override
  String get chatEmojiRecent => 'Недавние';

  @override
  String get chatEmojiAll => 'Все эмодзи';

  @override
  String get chatMessageInfo => 'Информация о сообщении';

  @override
  String get chatReadBy => 'Прочитали';

  @override
  String get chatNoReceipts => 'Пока никто не прочитал';

  @override
  String get chatFilterAll => 'Все';

  @override
  String get chatFilterUnread => 'Непрочитанные';

  @override
  String get chatFilterGroups => 'Группы';

  @override
  String get chatEmptyFilter => 'Здесь пока пусто';

  @override
  String get chatArchivedEmpty => 'В архиве нет чатов';

  @override
  String get chatSelectConversation => 'Выберите чат, чтобы начать переписку';

  @override
  String get chatRemoveAdmin => 'Снять права админа';

  @override
  String get chatOpenExternally => 'Открыть в другом приложении';

  @override
  String get chatPlaybackSpeed => 'Скорость воспроизведения';

  @override
  String get chatTypingShort => 'печатает…';

  @override
  String get chatRecordingShort => 'записывает голосовое…';

  @override
  String get chatEmptyHint => 'Напишите первое сообщение';

  @override
  String get chatSaved => 'Избранное';

  @override
  String get chatSavedHint => 'Заметки и файлы только для вас';

  @override
  String get chatSaveToSaved => 'Сохранить в Избранное';

  @override
  String get chatSavedDone => 'Сохранено в Избранное';

  @override
  String get chatDeleteForMe => 'Удалить у меня';

  @override
  String get chatDeleteForAll => 'Удалить у всех';

  @override
  String get chatMarkUnread => 'Пометить как непрочитанное';

  @override
  String get chatMarkRead => 'Пометить как прочитанное';

  @override
  String get chatUnreadShort => 'Непрочит.';

  @override
  String get chatReadShort => 'Прочитано';

  @override
  String get chatDescription => 'Описание';

  @override
  String get chatDescriptionAdd => 'Добавить описание';

  @override
  String get chatDescriptionEdit => 'Изменить описание';

  @override
  String get chatDescriptionTooLong => 'Не больше 500 символов';

  @override
  String chatSystemDescriptionChanged(String actor) {
    return '$actor изменил(а) описание группы';
  }

  @override
  String get chatMediaFilesLinks => 'Медиа, файлы и ссылки';

  @override
  String get chatMediaTabMedia => 'Медиа';

  @override
  String get chatMediaTabFiles => 'Файлы';

  @override
  String get chatMediaTabLinks => 'Ссылки';

  @override
  String get chatMediaTabVoice => 'Голосовые';

  @override
  String get chatMediaEmpty => 'Здесь пока ничего нет';

  @override
  String get chatShowInChat => 'Показать в чате';

  @override
  String get chatShareTitle => 'Отправить в чат';

  @override
  String get chatShareRecent => 'Недавние чаты';

  @override
  String get chatShareNothing => 'Нечего отправить';

  @override
  String chatShareFiles(int count) {
    return 'Вложений: $count';
  }

  @override
  String get chatRemoveAttachment => 'Убрать вложение';

  @override
  String get chatVideoPlay => 'Воспроизвести';

  @override
  String get chatVideoPause => 'Пауза';

  @override
  String get chatVideoMute => 'Выключить звук';

  @override
  String get chatVideoUnmute => 'Включить звук';

  @override
  String get chatVideoFailed => 'Не удалось воспроизвести видео';

  @override
  String homeWidgetUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count непрочитанных',
      many: '$count непрочитанных',
      few: '$count непрочитанных',
      one: '$count непрочитанный',
    );
    return '$_temp0';
  }

  @override
  String get homeWidgetNoUnread => 'Нет непрочитанных';

  @override
  String get homeWidgetNoEvents => 'Сегодня событий больше нет';

  @override
  String get homeWidgetSignIn => 'Войдите в XatBox';

  @override
  String get settingsWidgetSection => 'Виджет и ярлыки';

  @override
  String get settingsWidgetPreview => 'Текст сообщений в виджете';

  @override
  String get settingsWidgetPreviewHint =>
      'Без этого виджет показывает только названия чатов. С блокировкой PIN-кодом или «Скрывать содержимое» — только число непрочитанных.';

  @override
  String get shortcutNewMessage => 'Новое сообщение';

  @override
  String get shortcutCall => 'Позвонить';

  @override
  String get shortcutSearch => 'Поиск';

  @override
  String get savedChatOpenFailed => 'Не удалось открыть Избранное';

  @override
  String get updateTitle => 'Обновление приложения';

  @override
  String updateCurrentVersion(String version) {
    return 'Установлена версия $version';
  }

  @override
  String updateNewVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get updateAvailableTitle => 'Доступно обновление';

  @override
  String get updateMandatoryTitle => 'Нужно обновить XatBox';

  @override
  String get updateMandatoryBody =>
      'Эта версия больше не поддерживается сервером. Обновление займёт минуту — чаты, почта и настройки сохранятся.';

  @override
  String get updateUpToDate => 'У вас последняя версия';

  @override
  String updateCheckedAt(String time) {
    return 'Проверено $time';
  }

  @override
  String get updateCheck => 'Проверить обновления';

  @override
  String get updateChecking => 'Проверяем обновления…';

  @override
  String get updateCheckFailed => 'Не удалось проверить обновления';

  @override
  String get updateWhatsNew => 'Что нового';

  @override
  String get updateNoNotes => 'Исправления ошибок и улучшения стабильности.';

  @override
  String get updateDownload => 'Скачать и установить';

  @override
  String updateDownloading(int percent) {
    return 'Загрузка… $percent%';
  }

  @override
  String updateDownloadedOf(String received, String total) {
    return '$received из $total';
  }

  @override
  String get updateCancel => 'Остановить загрузку';

  @override
  String get updateResume => 'Продолжить загрузку';

  @override
  String get updateInstall => 'Установить';

  @override
  String get updateInstalling => 'Открыт установщик Android';

  @override
  String get updateInstallingHint =>
      'Подтвердите установку. Если окно закрылось, нажмите «Установить» ещё раз.';

  @override
  String get updateLater => 'Позже';

  @override
  String get updatePermissionTitle => 'Разрешите установку обновлений';

  @override
  String get updatePermissionBody =>
      'Android один раз просит разрешить XatBox устанавливать приложения. Откройте настройки, включите «Разрешить установку из этого источника» и вернитесь — установка продолжится сама.';

  @override
  String get updatePermissionOpen => 'Открыть настройки';

  @override
  String get updateFailed => 'Не удалось загрузить обновление';

  @override
  String get updateIntegrityFailed =>
      'Файл повредился при загрузке. Попробуйте ещё раз.';

  @override
  String get updateInstallFailed => 'Не удалось открыть установщик Android';

  @override
  String get updateRetry => 'Повторить';

  @override
  String get updateIncompatible =>
      'Для этого устройства нет подходящего файла обновления. Обратитесь к администратору.';

  @override
  String get updateUnsupported =>
      'Обновления приходят через сервер XatBox и доступны только на Android.';

  @override
  String get updateSignOut => 'Выйти из аккаунта';

  @override
  String updateSettingsAvailable(String version) {
    return 'Доступна версия $version';
  }

  @override
  String get updateBadgeNew => 'Новое';

  @override
  String get sessionsTitle => 'Мои устройства и сеансы';

  @override
  String get sessionsSettingsHint => 'Где выполнен вход в учётную запись';

  @override
  String get sessionsHint =>
      'Здесь все устройства, где выполнен вход в вашу учётную запись. Если не узнаёте устройство, завершите сеанс и смените пароль.';

  @override
  String get sessionsThisDevice => 'Это устройство';

  @override
  String get sessionsOthers => 'Другие устройства';

  @override
  String get sessionsNoOthers => 'Других активных сеансов нет';

  @override
  String get sessionsActiveNow => 'Активно сейчас';

  @override
  String sessionsLastActive(String time) {
    return 'Активность: $time';
  }

  @override
  String sessionsSignedIn(String date) {
    return 'Вход: $date';
  }

  @override
  String sessionsIp(String ip) {
    return 'IP-адрес $ip';
  }

  @override
  String get sessionsEnd => 'Выйти на этом устройстве';

  @override
  String get sessionsEndConfirmTitle => 'Завершить сеанс?';

  @override
  String sessionsEndConfirmBody(String device) {
    return 'На устройстве «$device» нужно будет снова войти по паролю, а данные XatBox на нём удалятся при следующем подключении.';
  }

  @override
  String get sessionsEndOthers => 'Выйти на всех других устройствах';

  @override
  String get sessionsEndOthersConfirmBody =>
      'Все устройства, кроме этого, будут отключены от учётной записи и удалят локальные данные XatBox.';

  @override
  String get sessionsEnded => 'Сеанс завершён';

  @override
  String get sessionsXatBoxApp => 'Приложение XatBox';

  @override
  String get sessionsUnknownDevice => 'Неизвестное устройство';

  @override
  String get aboutTitle => 'О приложении';

  @override
  String get aboutTagline => 'Почта, мессенджер и звонки в одном приложении';

  @override
  String aboutVersion(String version, String build) {
    return 'Версия $version · сборка $build';
  }

  @override
  String get aboutAppSection => 'Приложение';

  @override
  String get aboutServers => 'Серверы';

  @override
  String get aboutServerMail => 'Почта';

  @override
  String get aboutServerChat => 'Мессенджер';

  @override
  String get aboutServerCalls => 'Звонки';

  @override
  String get aboutServerNotConfigured => 'Не настроен';

  @override
  String get aboutServerUnreachable => 'Недоступен';

  @override
  String get aboutServerDegraded => 'Работает с ошибками';

  @override
  String aboutServerLatency(int ms) {
    return '$ms мс';
  }

  @override
  String get aboutRecheck => 'Проверить снова';

  @override
  String get aboutWhatsNew => 'Что нового';

  @override
  String get aboutLicenses => 'Лицензии открытого ПО';

  @override
  String get aboutPrivacy => 'Конфиденциальность';

  @override
  String get aboutPrivacyDataTitle => 'Где хранятся данные';

  @override
  String get aboutPrivacyDataBody =>
      'Письма, чаты, файлы и записи звонков хранятся на серверах организации, а не у сторонних сервисов. На устройстве остаётся только кэш для работы без сети — он удаляется при выходе из аккаунта.';

  @override
  String get aboutPrivacyPushTitle => 'Зашифрованные уведомления';

  @override
  String get aboutPrivacyPushBody =>
      'Текст уведомлений шифруется ключом, созданным на этом телефоне. Google и Apple доставляют только зашифрованный пакет и не видят, кто и что вам написал.';

  @override
  String get aboutPrivacyReportsTitle => 'Отчёты об ошибках';

  @override
  String get aboutPrivacyReportsBody =>
      'Отчёты о сбоях уходят только на сервер XatBox — без текстов сообщений, адресов и паролей. Их можно отключить в настройках.';

  @override
  String get aboutPrivacyLockTitle => 'Блокировка приложения';

  @override
  String get aboutPrivacyLockBody =>
      'PIN-код не хранится в открытом виде: в защищённом хранилище устройства лежит только его хеш с солью.';

  @override
  String get reportTitle => 'Сообщить о проблеме';

  @override
  String get reportCategory => 'Что случилось?';

  @override
  String get reportCategoryBug => 'Ошибка';

  @override
  String get reportCategoryIdea => 'Предложение';

  @override
  String get reportCategoryQuestion => 'Вопрос';

  @override
  String get reportCategoryOther => 'Другое';

  @override
  String get reportDescription => 'Описание';

  @override
  String get reportDescriptionHint =>
      'Что вы делали и что пошло не так? Чем подробнее, тем быстрее исправим.';

  @override
  String get reportScreenshot => 'Снимок экрана';

  @override
  String get reportScreenshotAttach => 'Прикрепить изображение';

  @override
  String get reportScreenshotRemove => 'Убрать снимок';

  @override
  String get reportDiagnostics => 'Приложить диагностику';

  @override
  String get reportDiagnosticsHint =>
      'Версия, модель устройства и технический журнал без личных данных';

  @override
  String get reportDiagnosticsShow => 'Что будет отправлено';

  @override
  String get reportShake => 'Встряхнуть, чтобы сообщить о проблеме';

  @override
  String get reportShakeHint =>
      'Встряхните телефон на любом экране — откроется эта форма со снимком экрана';

  @override
  String get reportSend => 'Отправить';

  @override
  String get reportSentTitle => 'Спасибо!';

  @override
  String get reportSent =>
      'Сообщение отправлено. Мы разберёмся и, если нужно, свяжемся с вами.';

  @override
  String get reportDone => 'Готово';

  @override
  String get reportRateLimited =>
      'Слишком много сообщений подряд. Попробуйте через час.';

  @override
  String get reportUnavailable =>
      'Отправка недоступна: сервер мессенджера не настроен.';

  @override
  String lockGreeting(String name) {
    return 'Здравствуйте, $name';
  }

  @override
  String get lockReturnToCall => 'Вернуться к звонку';

  @override
  String get chatReport => 'Пожаловаться';

  @override
  String get chatReportTitle => 'Пожаловаться на сообщение';

  @override
  String get chatReportReasonSpam => 'Спам';

  @override
  String get chatReportReasonAbuse => 'Оскорбление';

  @override
  String get chatReportReasonConfidential => 'Конфиденциальные данные';

  @override
  String get chatReportReasonOther => 'Другое';

  @override
  String get chatReportComment => 'Комментарий (необязательно)';

  @override
  String get chatReportSend => 'Отправить жалобу';

  @override
  String get chatReportSent => 'Жалоба отправлена. Модераторы её рассмотрят.';

  @override
  String get chatReportReviewed => 'Ваша жалоба рассмотрена. Спасибо!';

  @override
  String get chatReportPrivacyHint => 'Автор не узнает, кто пожаловался.';

  @override
  String get chatForwardForbidden => 'Пересылка из этого чата запрещена';

  @override
  String get chatMemberRestricted => 'Вам временно запрещено писать в этот чат';

  @override
  String chatSystemProtectionChanged(String actor) {
    return '$actor изменил(а) настройки защиты чата';
  }

  @override
  String get chatSystemModerationWarning =>
      'Модератор вынес предупреждение за нарушение правил';

  @override
  String get chatSystemMemberRestricted =>
      'Участнику временно запрещено писать';

  @override
  String get chatProtection => 'Защита чата';

  @override
  String get chatProtectionActive => 'Защита включена';

  @override
  String get chatProtectionNone => 'Защита не включена';

  @override
  String get chatProtectionNoForward => 'Запретить пересылку и копирование';

  @override
  String get chatProtectionNoForwardHint =>
      'Сообщения нельзя переслать, скопировать или сохранить';

  @override
  String get chatProtectionScreenshots => 'Защита от скриншотов';

  @override
  String get chatProtectionScreenshotsHint =>
      'На Android снимки и запись экрана блокируются, на iPhone чат скрывается при сворачивании';

  @override
  String get chatProtectionDisappearing => 'Исчезающие сообщения';

  @override
  String get chatProtectionDisappearingHint =>
      'Новые сообщения удаляются у всех по таймеру';

  @override
  String get chatProtectionAdminsOnly =>
      'Изменять защиту могут только администраторы';

  @override
  String get chatProtectionPeerNotified =>
      'Собеседник увидит сообщение об изменении';

  @override
  String get chatProtectionMembersNotified =>
      'Участники увидят сообщение об изменении';

  @override
  String get chatDisappearingOff => 'Выкл.';

  @override
  String get chatDisappearingDay => '1 день';

  @override
  String get chatDisappearingWeek => '1 неделя';

  @override
  String get chatDisappearingMonth => '1 месяц';

  @override
  String chatDisappearingCustom(int hours) {
    return '$hours ч';
  }

  @override
  String get chatDisappearingMessage => 'Исчезающее сообщение';

  @override
  String get chatStickers => 'Эмодзи и стикеры';

  @override
  String get chatEmoji => 'Эмодзи';

  @override
  String get chatStickersRecent => 'Недавние';

  @override
  String get chatStickersEmpty => 'Стикеры пока недоступны';

  @override
  String get chatAttachmentSticker => 'Стикер';

  @override
  String get chatStickerUnavailable => 'Стикер недоступен';

  @override
  String get chatTranscribe => 'Расшифровать';

  @override
  String get chatTranscribing => 'Расшифровка…';

  @override
  String get chatTranscriptFailed => 'Не удалось расшифровать';

  @override
  String get chatTranscriptRetry => 'Повторить';

  @override
  String get chatTranscriptEmpty => 'Речь не распознана';

  @override
  String get chatTranscriptShow => 'Показать текст';

  @override
  String get chatTranscriptHide => 'Текст';

  @override
  String get chatTranscriptionBusy =>
      'Очередь расшифровки занята, попробуйте позже';

  @override
  String get chatAutoTranscribe => 'Расшифровывать голосовые автоматически';

  @override
  String get chatAutoTranscribeHint =>
      'Расшифровка выполняется на сервере университета';

  @override
  String get moderationTitle => 'Модерация';

  @override
  String get moderationHint => 'Жалобы на сообщения';

  @override
  String get moderationTabOpen => 'Открытые';

  @override
  String get moderationTabResolved => 'Решённые';

  @override
  String get moderationTabDismissed => 'Отклонённые';

  @override
  String get moderationEmpty => 'Жалоб нет';

  @override
  String get moderationEmptyHint => 'Здесь появятся жалобы участников';

  @override
  String get moderationGlobalScope => 'Все чаты организации';

  @override
  String get moderationGroupScope => 'Группы, где вы администратор';

  @override
  String get moderationReport => 'Жалоба';

  @override
  String moderationReportFrom(String name) {
    return 'Жалоба от $name';
  }

  @override
  String moderationAuthor(String name) {
    return 'Автор: $name';
  }

  @override
  String get moderationDirectChat => 'Личный чат';

  @override
  String get moderationMember => 'Участник';

  @override
  String get moderationContext => 'Контекст переписки';

  @override
  String get moderationComment => 'Комментарий';

  @override
  String get moderationActions => 'Действия';

  @override
  String get moderationDeleteMessage => 'Удалить сообщение у всех';

  @override
  String get moderationWarn => 'Предупредить автора';

  @override
  String get moderationRemove => 'Исключить из группы';

  @override
  String get moderationMute => 'Запретить писать';

  @override
  String moderationMuteHours(int hours) {
    return 'На $hours ч';
  }

  @override
  String get moderationDismiss => 'Отклонить жалобу';

  @override
  String get moderationNote => 'Заметка для журнала (необязательно)';

  @override
  String get moderationConfirm => 'Применить';

  @override
  String get moderationDone => 'Готово';

  @override
  String get moderationAlreadyHandled => 'Жалоба уже рассмотрена';

  @override
  String moderationResolution(String action) {
    return 'Решение: $action';
  }

  @override
  String moderationRestrictedUntil(String time) {
    return 'Не может писать до $time';
  }

  @override
  String get moderationNotMember => 'Уже не участник чата';

  @override
  String get moderationDeletedContent => 'Сообщение удалено';

  @override
  String get statusTitle => 'Статус';

  @override
  String get statusSet => 'Установить статус';

  @override
  String get statusNone => 'Статус не установлен';

  @override
  String get statusPresetInClass => 'На паре';

  @override
  String get statusPresetMeeting => 'На совещании';

  @override
  String get statusPresetBusinessTrip => 'В командировке';

  @override
  String get statusPresetVacation => 'В отпуске';

  @override
  String get statusPresetSick => 'Болею';

  @override
  String get statusPresetDnd => 'Не беспокоить';

  @override
  String get statusPresetCustom => 'Свой статус';

  @override
  String get statusTextLabel => 'Текст статуса';

  @override
  String get statusEmojiPick => 'Выбрать эмодзи статуса';

  @override
  String get statusUntilLabel => 'До';

  @override
  String get statusUntilNone => 'Без срока';

  @override
  String get statusUntilHour => '1 час';

  @override
  String get statusUntilDay => 'До конца дня';

  @override
  String get statusUntilWeek => 'До конца недели';

  @override
  String get statusUntilPick => 'Выбрать дату и время';

  @override
  String statusUntilShort(String time) {
    return 'до $time';
  }

  @override
  String get statusAutoReplyLabel => 'Автоответ (необязательно)';

  @override
  String get statusAutoReplyHint =>
      'Придёт в личном чате тому, кто вам напишет, — один раз в день на чат';

  @override
  String get statusDndHint =>
      'Пока статус активен, push-уведомления о сообщениях не приходят';

  @override
  String get statusClear => 'Сбросить статус';

  @override
  String get statusSaved => 'Статус установлен';

  @override
  String get statusCleared => 'Статус сброшен';

  @override
  String get statusInvalid =>
      'Проверьте статус: текст до 70 символов, срок в будущем и не дальше года';

  @override
  String get statusCustomRequired => 'Введите текст или выберите эмодзи';

  @override
  String chatAutoReplyText(String text) {
    return 'Автоответ: $text';
  }

  @override
  String a11yStatus(String status) {
    return 'статус: $status';
  }

  @override
  String get chatFoldersTitle => 'Папки чатов';

  @override
  String get chatFoldersEdit => 'Настроить папки';

  @override
  String get chatFoldersEmpty =>
      'Соберите рабочие чаты, группы или каналы в отдельную вкладку';

  @override
  String get chatFolderNew => 'Новая папка';

  @override
  String get chatFolderEditTitle => 'Изменить папку';

  @override
  String get chatFolderName => 'Название';

  @override
  String get chatFolderEmoji => 'Выбрать значок папки';

  @override
  String get chatFolderTypes => 'Все чаты этого типа';

  @override
  String get chatFolderTypeDirect => 'Личные';

  @override
  String get chatFolderUnreadOnly => 'Только непрочитанные';

  @override
  String get chatFolderExcludeMuted => 'Скрывать чаты без звука';

  @override
  String get chatFolderChats => 'Чаты в папке';

  @override
  String chatFolderChatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count чата',
      many: '$count чатов',
      few: '$count чата',
      one: '$count чат',
    );
    return '$_temp0';
  }

  @override
  String get chatFolderSearchChats => 'Поиск чатов';

  @override
  String get chatFolderErrorName => 'Введите название (до 32 символов)';

  @override
  String get chatFolderErrorEmpty => 'Добавьте чаты или выберите тип чатов';

  @override
  String get chatFolderErrorChats => 'В папке может быть не больше 200 чатов';

  @override
  String get chatFolderLimit => 'Можно создать не больше 10 папок';

  @override
  String get chatFolderDelete => 'Удалить папку';

  @override
  String chatFolderDeleteConfirm(String name) {
    return 'Удалить папку «$name»? Чаты останутся в списке.';
  }

  @override
  String get chatFolderReorder => 'Перетащите, чтобы изменить порядок';

  @override
  String chatFolderUnreadChats(int count) {
    return 'чатов с непрочитанными: $count';
  }

  @override
  String get chatFoldersPending => 'Изменения сохранятся, когда появится сеть';

  @override
  String get chatFoldersSaveFailed => 'Не удалось сохранить папки';

  @override
  String get chatAddToFolder => 'Добавить в папку';

  @override
  String get chatVoiceModeTitle => 'Запись голосовых';

  @override
  String get chatVoiceModeHold => 'Удерживать';

  @override
  String get chatVoiceModeTap => 'Нажать для записи';

  @override
  String get chatVoiceModeHint =>
      'С TalkBack запись всегда начинается нажатием';

  @override
  String get chatVoiceTapToRecord => 'Записать голосовое';

  @override
  String get channelComments => 'Комментарии';

  @override
  String get channelCommentsHint => 'Подписчики смогут обсуждать посты';

  @override
  String commentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count комментария',
      many: '$count комментариев',
      few: '$count комментария',
      one: '$count комментарий',
    );
    return '$_temp0';
  }

  @override
  String get commentsLeave => 'Комментировать';

  @override
  String get commentsEmpty => 'Комментариев пока нет — напишите первым';

  @override
  String get commentsDisabled => 'Комментарии к постам отключены';

  @override
  String get commentsInvalidThread =>
      'Ответить можно только на пост или комментарий к нему';

  @override
  String get commentsPostUnavailable => 'Пост удалён или недоступен';

  @override
  String get scheduleWhenOnline => 'Когда появится в сети';

  @override
  String get scheduleWhenOnlineHint => 'Ждём до 7 дней';

  @override
  String get scheduledWhenOnline => 'Когда появится в сети';

  @override
  String get scheduledWhenOnlineCreated =>
      'Отправим, когда собеседник появится в сети';

  @override
  String get scheduledWhenOnlineTimeout =>
      'Не отправлено: собеседник не появился в сети';

  @override
  String get scheduleWhenOnlineUnavailable =>
      'Собеседник скрывает, когда он в сети';

  @override
  String get officialTitle => 'Официальные сообщения';

  @override
  String get officialEmpty => 'Официальных сообщений пока нет';

  @override
  String get officialNoAccess => 'Нет доступа к официальным сообщениям';

  @override
  String get officialNotFound => 'Сообщение не найдено';

  @override
  String get officialUnread => 'Не прочитано';

  @override
  String get officialRequiresAck => 'Требует ознакомления';

  @override
  String get officialAcknowledged => 'Ознакомлен(а)';

  @override
  String get officialAcknowledgeButton => 'Ознакомлен(а)';

  @override
  String officialAcknowledgedAt(String date) {
    return 'Вы ознакомились: $date';
  }

  @override
  String get officialAckHint =>
      'Отправитель просит подтвердить, что вы ознакомились с сообщением.';

  @override
  String officialLimitNote(int count) {
    return 'Показаны последние $count сообщений';
  }

  @override
  String get officialNew => 'Новое сообщение';

  @override
  String get officialReceivedTab => 'Входящие';

  @override
  String get officialSentTab => 'Отправленные';

  @override
  String get officialSentEmpty =>
      'Здесь появятся сообщения, отправленные с этого устройства';

  @override
  String officialRecipientCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count получателя',
      many: '$count получателей',
      few: '$count получателя',
      one: '$count получатель',
    );
    return '$_temp0';
  }

  @override
  String officialSentToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Отправлено получателям: $count',
      one: 'Отправлено $count получателю',
    );
    return '$_temp0';
  }

  @override
  String get officialComposeTitle => 'Официальное сообщение';

  @override
  String get officialFieldTitle => 'Заголовок';

  @override
  String get officialFieldBody => 'Текст сообщения';

  @override
  String get officialTitleRequired => 'Введите заголовок';

  @override
  String get officialBodyRequired => 'Введите текст сообщения';

  @override
  String get officialRequireAck => 'Требовать ознакомление';

  @override
  String get officialRequireAckHint =>
      'Каждый получатель должен будет нажать «Ознакомлен(а)»';

  @override
  String get officialRecipients => 'Получатели';

  @override
  String get officialRecipientsOrganization => 'Вся организация';

  @override
  String get officialRecipientsDepartments => 'Отделы';

  @override
  String get officialRecipientsUsers => 'Сотрудники';

  @override
  String get officialRecipientsRequired => 'Выберите получателей';

  @override
  String get officialSearchUsers => 'Поиск сотрудников';

  @override
  String get officialNoUsers => 'Никого не найдено';

  @override
  String get officialNoDepartments => 'Нет доступных отделов';

  @override
  String officialSelectedDone(int count) {
    return 'Готово ($count)';
  }

  @override
  String get officialSend => 'Отправить';

  @override
  String get officialStatsTitle => 'Статистика';

  @override
  String get officialStatsRecipients => 'Получатели';

  @override
  String get officialStatsRead => 'Прочитали';

  @override
  String get officialStatsAcknowledged => 'Ознакомились';

  @override
  String get officialStatsNoData =>
      'Нет данных. Статистика доступна только отправителю сообщения.';

  @override
  String get officialStatsAggregateNote =>
      'Сервер сообщает только общие количества, без списка получателей.';

  @override
  String get officialErrNotFound =>
      'Сообщение не найдено или не требует ознакомления';

  @override
  String get officialErrInvalid => 'Заполните заголовок и текст сообщения';

  @override
  String get officialErrInvalidRecipients =>
      'Не удалось определить получателей';

  @override
  String get officialErrNoRecipients =>
      'Среди выбранных нет активных пользователей';

  @override
  String get officialErrForbidden =>
      'Недостаточно прав для отправки официальных сообщений этим получателям';

  @override
  String get officialErrNotSent =>
      'Сервер не принял сообщение. Попробуйте ещё раз.';

  @override
  String mailUxUnbookmarkedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count писем убрано из закладок',
      few: '$count письма убрано из закладок',
      one: '$count письмо убрано из закладок',
    );
    return '$_temp0';
  }

  @override
  String mailUxArchivedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count писем перемещено в архив',
      few: '$count письма перемещено в архив',
      one: '$count письмо перемещено в архив',
    );
    return '$_temp0';
  }

  @override
  String get mailUxSwipeSection => 'Жесты в списке писем';

  @override
  String get mailUxSwipeLeft => 'Свайп влево';

  @override
  String get mailUxSwipeRight => 'Свайп вправо';

  @override
  String get mailUxSwipeNone => 'Ничего';

  @override
  String get mailUxSwipeTrash => 'В корзину';

  @override
  String get mailUxSwipeArchive => 'В архив';

  @override
  String get mailUxSwipeRead => 'Прочитано / не прочитано';

  @override
  String get mailUxSwipeBookmark => 'Закладка';

  @override
  String get mailUxSwipeHint =>
      'В корзине и черновиках свайп «В корзину» удаляет письмо навсегда — после подтверждения. Пока выбрано несколько писем, свайпы отключены.';

  @override
  String get mailUxSendSection => 'Отправка';

  @override
  String get mailUxUndoSend => 'Отмена отправки';

  @override
  String get mailUxUndoSendOff => 'Выключено';

  @override
  String mailUxUndoSendSeconds(int seconds) {
    return '$seconds с';
  }

  @override
  String get mailUxUndoSendHint =>
      'письмо уходит после паузы, за это время его можно отменить';

  @override
  String get mailUxSending => 'Письмо отправляется…';

  @override
  String mailUxSendFailed(String error) {
    return 'Письмо не отправлено: $error';
  }

  @override
  String get mailUxEdit => 'Изменить';

  @override
  String get mailUxAttachFile => 'Файл';

  @override
  String get mailUxAttachGallery => 'Фото или видео из галереи';

  @override
  String get mailUxAttachCameraPhoto => 'Сделать фото';

  @override
  String get mailUxAttachCameraVideo => 'Снять видео';

  @override
  String get mailUxRecentRecipient => 'Недавний адрес';

  @override
  String get mailUxForwardToChat => 'Переслать в чат';

  @override
  String get mailUxForwardToChatAttachments =>
      'Какие вложения отправить в чат?';

  @override
  String get mailUxNext => 'Далее';

  @override
  String get mailUxDownloading => 'Загрузка вложений…';

  @override
  String get mailUxChatDate => 'Дата';

  @override
  String get mailUxChatSubject => 'Тема';

  @override
  String get mailUxChatFrom => 'От';

  @override
  String get mailUxSendByMail => 'Отправить по почте';

  @override
  String get tasksTitle => 'Задачи';

  @override
  String get tasksScreenTitle => 'Мои задачи';

  @override
  String get tasksSectionMine => 'Мне';

  @override
  String get tasksSectionAssigned => 'Я поручил(а)';

  @override
  String tasksSectionDone(int count) {
    return 'Выполненные · $count';
  }

  @override
  String get tasksEmpty => 'Задач нет';

  @override
  String get tasksEmptyHint => 'Создайте задачу или добавьте письмо в задачи';

  @override
  String get tasksUnavailable => 'Задачи недоступны для вашей учётной записи';

  @override
  String get tasksNew => 'Новая задача';

  @override
  String get tasksEdit => 'Изменить задачу';

  @override
  String get tasksDetails => 'Задача';

  @override
  String get tasksFieldTitle => 'Название';

  @override
  String get tasksFieldDescription => 'Описание';

  @override
  String get tasksFieldDue => 'Срок';

  @override
  String get tasksFieldReminder => 'Напоминание';

  @override
  String get tasksFieldAssignee => 'Исполнитель';

  @override
  String get tasksFieldPriority => 'Приоритет';

  @override
  String get tasksNoDue => 'Без срока';

  @override
  String get tasksNoReminder => 'Без напоминания';

  @override
  String get tasksAssigneeSelf => 'Я';

  @override
  String get tasksAssigneePick => 'Кому поручить';

  @override
  String get tasksAssigneeSearch => 'Поиск сотрудника';

  @override
  String get tasksAssigneeEmpty => 'В ваших отделах нет сотрудников';

  @override
  String get tasksPriorityLow => 'Низкий';

  @override
  String get tasksPriorityNormal => 'Обычный';

  @override
  String get tasksPriorityHigh => 'Высокий';

  @override
  String get tasksPriorityUrgent => 'Срочно';

  @override
  String get tasksOverdue => 'Просрочено';

  @override
  String get tasksDueToday => 'Сегодня';

  @override
  String tasksDueOn(String date) {
    return 'до $date';
  }

  @override
  String tasksAssignedTo(String name) {
    return 'Исполнитель: $name';
  }

  @override
  String tasksAssignedBy(String name) {
    return 'Поручил(а): $name';
  }

  @override
  String get tasksAssignedToColleague => 'Поручено сотруднику';

  @override
  String get tasksReminderFixed =>
      'Напоминание задаётся только при создании задачи';

  @override
  String get tasksReadOnly =>
      'Изменять и удалять задачу может только исполнитель';

  @override
  String get tasksTitleRequired => 'Введите название';

  @override
  String get tasksClear => 'Убрать';

  @override
  String get tasksCreate => 'Создать';

  @override
  String get tasksDelete => 'Удалить задачу';

  @override
  String tasksDeleteConfirm(String title) {
    return 'Удалить задачу «$title»? Её напоминания тоже удалятся.';
  }

  @override
  String get tasksDeleted => 'Задача удалена';

  @override
  String get tasksCreated => 'Задача создана';

  @override
  String get tasksSaved => 'Задача сохранена';

  @override
  String get tasksMarkDone => 'Отметить выполненной';

  @override
  String get tasksMarkUndone => 'Вернуть в работу';

  @override
  String get tasksOpenMessage => 'Открыть письмо';

  @override
  String get tasksOpen => 'Открыть';

  @override
  String get tasksNotFound => 'Задача не найдена';

  @override
  String get tasksErrInvalid => 'Проверьте поля задачи';

  @override
  String get tasksErrOwner => 'Сотрудник не состоит в вашей организации';

  @override
  String get tasksErrReminder => 'Не удалось сохранить напоминание';

  @override
  String get tasksErrForbidden => 'Нет прав поручить задачу этому сотруднику';

  @override
  String get taskBoardsTitle => 'Доски';

  @override
  String get taskBoardPersonal => 'Мои задачи';

  @override
  String get taskBoardNew => 'Новая доска';

  @override
  String get taskBoardCreate => 'Создать доску';

  @override
  String get taskBoardRename => 'Переименовать доску';

  @override
  String get taskBoardName => 'Название доски';

  @override
  String get taskBoardNameHint => 'Например: Приёмная кампания';

  @override
  String get taskBoardDescription => 'Описание';

  @override
  String get taskBoardColor => 'Цвет';

  @override
  String get taskBoardShare => 'Поделиться';

  @override
  String get taskBoardDelete => 'Удалить доску';

  @override
  String taskBoardDeleteConfirm(String name) {
    return 'Удалить доску «$name»? Её задачи вернутся в «Мои задачи», а коллеги потеряют к ним доступ.';
  }

  @override
  String get taskBoardDeleted => 'Доска удалена';

  @override
  String get taskBoardCreated => 'Доска создана';

  @override
  String get taskBoardSaved => 'Доска сохранена';

  @override
  String get taskBoardShared => 'Доступ обновлён';

  @override
  String get taskBoardNameRequired => 'Введите название доски';

  @override
  String taskBoardOwnedBy(String name) {
    return 'Доска сотрудника $name';
  }

  @override
  String get taskBoardRoleEditor => 'Может изменять';

  @override
  String get taskBoardRoleViewer => 'Только просмотр';

  @override
  String get taskBoardReadOnly => 'Доска доступна только для просмотра';

  @override
  String taskBoardShareTitle(String name) {
    return 'Доступ к доске «$name»';
  }

  @override
  String get taskBoardShareHint =>
      'Участники видят задачи доски. Редакторы могут создавать и изменять их, наблюдатели — только читать.';

  @override
  String get taskBoardShareSearch => 'Поиск сотрудника';

  @override
  String get taskBoardShareEmpty => 'Доска пока никому не доступна';

  @override
  String taskBoardShareMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '$count участник',
      zero: 'Нет участников',
    );
    return '$_temp0';
  }

  @override
  String get taskBoardRemoveMember => 'Убрать доступ';

  @override
  String get taskBoardEmpty => 'На этой доске пока нет задач';

  @override
  String get taskBoardMoveHere => 'Перенести сюда';

  @override
  String taskBoardMoved(String name) {
    return 'Задача перенесена: $name';
  }

  @override
  String taskBoardOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count задачи',
      many: '$count задач',
      few: '$count задачи',
      one: '$count задача',
      zero: 'Нет задач',
    );
    return '$_temp0';
  }

  @override
  String get taskBoardErrNotFound => 'Доска не найдена';

  @override
  String get taskBoardErrForbidden => 'Нет прав изменять эту доску';

  @override
  String get taskBoardErrName => 'Название доски: от 1 до 120 символов';

  @override
  String get taskBoardErrMember => 'Сотрудник не состоит в вашей организации';

  @override
  String get taskBoardsRailHide => 'Скрыть список досок';

  @override
  String get taskBoardsRailShow => 'Показать список досок';

  @override
  String get translateAction => 'Перевести';

  @override
  String get translateMail => 'Перевести письмо';

  @override
  String get translateInProgress => 'Перевод…';

  @override
  String get translateFailed => 'Не удалось перевести';

  @override
  String get translateRetry => 'Повторить';

  @override
  String get translateShowOriginal => 'Показать оригинал';

  @override
  String translateLabel(String from, String to) {
    return 'Перевод: $from → $to';
  }

  @override
  String translateSameLanguage(String language) {
    return 'Текст уже на языке: $language';
  }

  @override
  String get translateLangRu => 'русский';

  @override
  String get translateLangKk => 'казахский';

  @override
  String get translateLangEn => 'английский';

  @override
  String translateAutoInChat(String language) {
    return 'Переводить автоматически на $language';
  }

  @override
  String get translateAutoInChatHint =>
      'Входящие сообщения на другом языке, на этом устройстве';

  @override
  String get translateTargetSetting => 'Язык перевода';

  @override
  String translateTargetAppLanguage(String language) {
    return 'Как в приложении ($language)';
  }

  @override
  String get translateUnavailable =>
      'Перевод сейчас недоступен. Попробуйте позже.';

  @override
  String get translateTooLong => 'Текст слишком длинный для перевода';

  @override
  String get translateRateLimited =>
      'Слишком много переводов. Попробуйте позже.';

  @override
  String translateMailProgress(int done, int total) {
    return 'Перевод: $done из $total';
  }

  @override
  String get searchEverywhere => 'Поиск везде';

  @override
  String get searchHint => 'Люди, чаты, почта, события';

  @override
  String get searchIntro => 'Ищите сразу по людям, чатам, почте и календарю';

  @override
  String get searchRecent => 'Недавние';

  @override
  String get searchRecentClear => 'Очистить';

  @override
  String get searchRecentRemove => 'Удалить из истории';

  @override
  String get searchSectionPeople => 'Люди';

  @override
  String get searchSectionChats => 'Чаты';

  @override
  String get searchSectionMail => 'Почта';

  @override
  String get searchSectionEvents => 'События';

  @override
  String get searchShowAll => 'Показать все';

  @override
  String get searchSectionError => 'Не удалось выполнить поиск';

  @override
  String get searchEmpty => 'Ничего не найдено';

  @override
  String get searchNothingAvailable =>
      'Поиск недоступен для вашей учётной записи';

  @override
  String get searchOfflineHint => 'Офлайн — только сохранённое';

  @override
  String get searchNoSubject => '(без темы)';

  @override
  String get todayTab => 'Сегодня';

  @override
  String get todayStartScreen => 'Начальный экран';

  @override
  String get todayStartScreenHint =>
      'Вкладка, которая открывается при запуске. «Сегодня» добавляет вкладку со сводкой дня.';

  @override
  String get todayGreetingMorning => 'Доброе утро';

  @override
  String get todayGreetingAfternoon => 'Добрый день';

  @override
  String get todayGreetingEvening => 'Добрый вечер';

  @override
  String get todayGreetingNight => 'Доброй ночи';

  @override
  String get todayMailTitle => 'Непрочитанная почта';

  @override
  String get todayMailEmpty => 'Все письма прочитаны';

  @override
  String get todayChatsTitle => 'Непрочитанные чаты';

  @override
  String get todayChatsEmpty => 'Новых сообщений нет';

  @override
  String get todayEventsTitle => 'Сегодня в календаре';

  @override
  String get todayEventsEmpty => 'Больше событий сегодня нет';

  @override
  String get todayJoin => 'Подключиться';

  @override
  String get todayMissedCallsTitle => 'Пропущенные звонки';

  @override
  String get todayMissedCallsEmpty => 'Сегодня пропущенных нет';

  @override
  String get todayNewMail => 'Письмо';

  @override
  String get todayNewChat => 'Сообщение';

  @override
  String get todayNewCall => 'Звонок';

  @override
  String get callsShareChoose => 'Что показать';

  @override
  String get callsShareEntireScreen => 'Весь экран';

  @override
  String get callsShareWindow => 'Окно';

  @override
  String get callsShareStart => 'Показать';

  @override
  String get desktopTrayOpen => 'Открыть XatBox';

  @override
  String get desktopTrayQuit => 'Выйти из XatBox';

  @override
  String get desktopSearch => 'Поиск';

  @override
  String get desktopMore => 'Ещё';

  @override
  String get contactsSelect => 'Выберите сотрудника, чтобы открыть профиль';

  @override
  String get callsSelect => 'Выберите звонок, чтобы открыть карточку';

  @override
  String get desktopRefresh => 'Обновить';

  @override
  String get desktopPrevious => 'Назад';

  @override
  String get desktopNext => 'Вперёд';

  @override
  String get aboutPrivacyPushBodyDesktop =>
      'На компьютере уведомления приходят напрямую от сервера организации по защищённому соединению, без Google и Apple.';

  @override
  String get remindersEmptyHintDesktop =>
      'Нажмите на сообщение правой кнопкой мыши и выберите «Напомнить»';

  @override
  String get chatProtectionScreenshotsHintDesktop =>
      'На компьютере чат скрывается, когда окно свёрнуто';

  @override
  String get settingsLockWindowsHello => 'Разблокировка через Windows Hello';

  @override
  String get composeMinimize => 'Свернуть';

  @override
  String get composeExpand => 'Развернуть';

  @override
  String get composeRestoreSize => 'Восстановить размер';

  @override
  String get composeSaveAndClose => 'Сохранить и закрыть';

  @override
  String get composeAddCcBcc => 'Копия / Скрытая копия';

  @override
  String get desktopCollapseSidebar => 'Свернуть меню';

  @override
  String get desktopExpandSidebar => 'Развернуть меню';

  @override
  String get desktopZoom => 'Масштаб';

  @override
  String get desktopZoomHint =>
      'Размер всего интерфейса. Горячие клавиши: Ctrl + плюс, Ctrl + минус, Ctrl + 0.';

  @override
  String get desktopZoomReset => 'Сбросить';

  @override
  String get desktopNotifTest => 'Проверить уведомления';

  @override
  String get desktopNotifTestHint => 'Показать пробное уведомление Windows';

  @override
  String get desktopNotifTestBody => 'Уведомления работают';

  @override
  String get desktopNotifTestSent =>
      'Уведомление отправлено. Если его не видно, включите уведомления для XatBox в параметрах системы и выключите режим «Не беспокоить».';

  @override
  String desktopNotifTestFailed(String error) {
    return 'Система не показала уведомление: $error';
  }

  @override
  String get desktopSettingsIntro =>
      'Профиль, оформление, уведомления и безопасность. Изменения сохраняются сразу.';

  @override
  String get updateInstallFailedDesktop =>
      'Не удалось запустить установщик обновления';

  @override
  String desktopCalendarMore(int count) {
    return '+$count ещё';
  }

  @override
  String get desktopCalendarSelectedDay => 'Выбранный день';

  @override
  String composeDraftSavedAt(String time) {
    return 'Черновик сохранён $time';
  }

  @override
  String get desktopShortcutsTitle => 'Горячие клавиши';

  @override
  String get desktopShortcutsMail => 'Письма';

  @override
  String get desktopShortcutsEverywhere => 'Везде';

  @override
  String get desktopShortcutNext => 'Следующее письмо';

  @override
  String get desktopShortcutPrevious => 'Предыдущее письмо';

  @override
  String get desktopShortcutOpen => 'Открыть письмо';

  @override
  String get desktopShortcutClose => 'Закрыть письмо';

  @override
  String get desktopShortcutReadToggle => 'Прочитано / не прочитано';

  @override
  String get desktopShortcutSend => 'Отправить письмо';

  @override
  String get desktopShortcutModules =>
      'Почта · Чат · Звонки · Календарь · Контакты';

  @override
  String get desktopShortcutZoom => 'Масштаб: крупнее · мельче · как было';

  @override
  String get desktopPrint => 'Печать';

  @override
  String get desktopPrintFailed => 'Не удалось открыть письмо для печати';

  @override
  String get desktopOpenInWindow => 'Открыть в отдельном окне';

  @override
  String get desktopDefaultMailApp => 'Почтовая программа по умолчанию';

  @override
  String get desktopDefaultMailAppHint =>
      'Ссылки на почтовые адреса (mailto:) в браузере и документах будут открывать новое письмо в XatBox. Откроются параметры Windows: выберите XatBox для MAILTO.';

  @override
  String get desktopAppSection => 'Приложение для компьютера';

  @override
  String get updateRestartNow => 'Перезапустить и обновить';

  @override
  String get updateOnQuit => 'Обновить при выходе';

  @override
  String get updateOnQuitScheduled =>
      'Обновление установится, когда вы выйдете из XatBox: значок в трее → «Выйти из XatBox».';

  @override
  String get updateManagedByAdmin =>
      'XatBox установлен для всех пользователей компьютера. Новые версии устанавливает администратор.';

  @override
  String get desktopPrintDate => 'Дата';

  @override
  String get desktopPrintAttachments => 'Вложения';

  @override
  String get desktopDefaultMailAppHintMac =>
      'Ссылки на почтовые адреса (mailto:) в браузере и документах будут открывать новое письмо в XatBox. macOS попросит подтвердить.';

  @override
  String get desktopDefaultMailAppDone =>
      'XatBox теперь открывает ссылки mailto:';

  @override
  String desktopMailMore(int count) {
    return 'Ещё новых писем: $count';
  }

  @override
  String get desktopMailNotifications => 'Уведомлять о новых письмах';

  @override
  String get desktopMailNotificationsHint =>
      'Уведомление с кнопками «Ответить», «Прочитано», «Удалить», пока XatBox свёрнут или в другом разделе';

  @override
  String get desktopFileHint =>
      'Перетащите в папку · Пробел — быстрый просмотр';

  @override
  String get desktopEmlUnreadable => 'Не удалось прочитать файл письма';

  @override
  String get desktopAwayStatus => 'Отошёл';

  @override
  String get desktopMiniCallMute => 'Выключить микрофон';

  @override
  String get desktopMiniCallUnmute => 'Включить микрофон';

  @override
  String get desktopMiniCallEnd => 'Завершить';

  @override
  String get desktopMiniCallExpand => 'Развернуть';

  @override
  String get desktopLaunchAtLogin => 'Запускать при входе в систему';

  @override
  String get desktopLaunchAtLoginHint =>
      'XatBox стартует свёрнутым в трей и сразу получает письма и сообщения';

  @override
  String get desktopLaunchAtLoginManaged =>
      'Включено администратором для всех пользователей компьютера';

  @override
  String get desktopGlobalHotkeys => 'Глобальные сочетания клавиш';

  @override
  String desktopGlobalHotkeysHint(String compose, String show) {
    return '$compose — новое письмо, $show — показать XatBox, из любой программы';
  }

  @override
  String get desktopAutoAway => 'Статус «Отошёл» автоматически';

  @override
  String get desktopAutoAwayHint =>
      'Когда компьютер заблокирован или без действий 10 минут. Свой статус XatBox не меняет';

  @override
  String get desktopMiniCall => 'Мини-окно звонка';

  @override
  String get desktopMiniCallHint =>
      'При переходе в другую программу звонок остаётся маленьким окном поверх всех окон';

  @override
  String get desktopNotificationSound => 'Звук уведомлений';

  @override
  String get desktopNotificationSoundHint =>
      'Новые сообщения в чате и новые письма';

  @override
  String get desktopSoundXatbox => 'XatBox';

  @override
  String get desktopSoundSystem => 'Системный';

  @override
  String get desktopSoundNone => 'Без звука';

  @override
  String get desktopRingtone => 'Мелодия звонка';

  @override
  String get desktopRingtoneHint => 'Входящий звонок';

  @override
  String get desktopRingtoneClassic => 'Классическая';

  @override
  String get desktopSoundPreview => 'Прослушать';

  @override
  String get chatWritePersonally => 'Написать лично';

  @override
  String get chatMemberActions => 'Участник';

  @override
  String get desktopBetaUpdates => 'Получать бета-версии';

  @override
  String get desktopBetaUpdatesHint =>
      'Новые версии приходят сразу, на день раньше, чем всем. В них могут быть ошибки.';

  @override
  String get updateDownloadOnly => 'Скачать';

  @override
  String get updateLinuxOpen => 'Открыть пакет';

  @override
  String get updateLinuxOpened => 'Пакет открыт в установщике';

  @override
  String get updateLinuxOpenedHint =>
      'Установите его (понадобится пароль администратора) и перезапустите XatBox. Файл .deb сохранён в папке «Загрузки».';

  @override
  String get desktopSpellCheck => 'Проверка орфографии в письмах';

  @override
  String get desktopSpellCheckHint =>
      'Ошибки подчёркиваются, варианты — по правой кнопке. Словари системы: русский, английский, казахский (если установлен)';

  @override
  String get desktopShortcutQuickLook =>
      'Быстрый просмотр вложения (под курсором)';

  @override
  String get desktopShortcutGlobalCompose => 'Новое письмо из любой программы';

  @override
  String get desktopShortcutGlobalShow => 'Показать XatBox из любой программы';

  @override
  String get desktopCalendarOpen => 'Открыть';

  @override
  String get desktopCalendarGoToDate => 'Перейти к дате';

  @override
  String get desktopCalendarNewHere => 'Создать событие здесь';

  @override
  String desktopCalendarWeekNumber(int week) {
    return 'Неделя $week';
  }

  @override
  String get desktopSelectMessageToRead => 'Выберите письмо';

  @override
  String get desktopSelectMessageToReadHint =>
      'Выберите письмо из списка. Оно откроется здесь, и вы не потеряете своё место.';

  @override
  String get desktopProfileFullName => 'Полное имя';

  @override
  String get desktopRoleMember => 'Сотрудник';

  @override
  String get desktopRoleUserManager => 'Менеджер пользователей';

  @override
  String get desktopRoleOrgAdmin => 'Администратор организации';

  @override
  String get desktopRoleDomainAdmin => 'Администратор домена';

  @override
  String get desktopRoleDeveloper => 'Разработчик';

  @override
  String get desktopRoleSecurityAnalyst => 'Аналитик безопасности';

  @override
  String get desktopRoleAuditor => 'Аудитор';

  @override
  String get desktopRoleSupport => 'Поддержка';

  @override
  String get desktopRoleTenantOwner => 'Владелец тенанта';

  @override
  String get desktopRoleSuperAdmin => 'Суперадминистратор';

  @override
  String get desktopRolePlatformSuperAdmin => 'Суперадминистратор платформы';

  @override
  String get desktopContactMeeting => 'Встреча';

  @override
  String get desktopContactScheduleMeeting => 'Назначить встречу';

  @override
  String get desktopContactCopyAddress => 'Скопировать адрес';

  @override
  String get desktopCalendarEmailParticipants => 'Написать участникам';

  @override
  String get desktopCalendarExternalGroup => 'Внешние участники';

  @override
  String get desktopCalendarNoDepartment => 'Без подразделения';

  @override
  String get desktopPaletteHint => 'Команда, раздел или поиск…';

  @override
  String desktopPaletteSearch(String query) {
    return 'Искать «$query» везде';
  }

  @override
  String get desktopPaletteToggleTheme => 'Переключить светлую / тёмную тему';

  @override
  String get desktopPaletteGoTo => 'Перейти';

  @override
  String get desktopPaletteCreate => 'Создать';

  @override
  String get desktopPaletteNothing => 'Ничего не найдено';

  @override
  String get desktopCallStart => 'Позвонить';

  @override
  String get desktopCallWithVideo => 'С видео';

  @override
  String get desktopCallShortcuts => 'Звонок';

  @override
  String get desktopMailSettingsShortcuts => 'Клавиши';

  @override
  String get desktopMailSettingsShortcutsHint =>
      'Работайте без мыши. Нажмите ? в любом месте, чтобы открыть этот список.';

  @override
  String get desktopMailKeysCalendarPrevNext => 'Предыдущий / следующий период';

  @override
  String get desktopMailKeysCalendarClosePanel => 'Закрыть панель события';

  @override
  String get desktopMailRestored => 'Возвращено';

  @override
  String get desktopCrashTitle => 'XatBox закрылся неожиданно';

  @override
  String get desktopCrashBody =>
      'В прошлый раз программа завершилась с ошибкой. Отправить разработчикам журнал её последних действий? В нём нет текста писем и сообщений, паролей и адресов.';

  @override
  String get desktopCrashSend => 'Отправить';

  @override
  String get desktopCrashSkip => 'Не отправлять';

  @override
  String get desktopCrashSent => 'Спасибо, отчёт отправлен';

  @override
  String desktopCrashReport(String version, String time) {
    return 'Автоотчёт: XatBox $version закрылся неожиданно (запуск $time)';
  }

  @override
  String desktopMailMovedTo(String folder) {
    return 'Перемещено в «$folder»';
  }

  @override
  String get desktopMailHideList => 'Скрыть список писем';

  @override
  String get desktopMailShowList => 'Показать список писем';

  @override
  String get desktopMailLinkElsewhereTitle => 'Ссылка ведёт на другой сайт';

  @override
  String desktopMailLinkElsewhereBody(String shown, String real) {
    return 'В тексте показан один адрес, а открывается другой. Всё равно открыть?\n\nПоказано: $shown\nОткрывается: $real';
  }

  @override
  String get desktopMailLinkOpenAnyway => 'Всё равно открыть';

  @override
  String desktopMailQuickReplyHint(String keys) {
    return 'Напишите ответ… ($keys для отправки)';
  }

  @override
  String get desktopMailQuickReplyAttach => 'Прикрепить файл';

  @override
  String get desktopMailQuickReplyUploading => 'Загрузка…';

  @override
  String get desktopMailQuickReplyUploadFailed => 'Не удалось загрузить';

  @override
  String get desktopMailQuickReplyRemoveFile => 'Убрать файл';

  @override
  String desktopMailQuickReplySentTo(String recipients, String time) {
    return 'Отправлено: $recipients · $time';
  }

  @override
  String get desktopShortcutPalette => 'Палитра команд';

  @override
  String get desktopChatCreate => 'Создать';

  @override
  String get desktopChatDetails => 'Сведения';

  @override
  String get mailOutboxQueued =>
      'Нет сети — письмо в «Исходящих» и уйдёт, когда появится связь';

  @override
  String mailOutboxTitle(int count) {
    return 'Исходящие: $count';
  }

  @override
  String get mailOutboxHint => 'отправятся автоматически, когда появится связь';

  @override
  String get mailOutboxWaiting => 'Ждёт сети';

  @override
  String get mailOutboxSending => 'Отправляется…';

  @override
  String mailOutboxFailed(String error) {
    return 'Не отправлено: $error';
  }

  @override
  String get mailOutboxSendNow => 'Отправить сейчас';

  @override
  String get mailOutboxDiscard => 'Удалить из «Исходящих»';

  @override
  String mailOutboxSent(int count) {
    return 'Письма из «Исходящих» отправлены: $count';
  }

  @override
  String get skinGlassForest => 'Лесное стекло';

  @override
  String get skinGlassForestHint => 'Прозрачные панели над утренним лесом';

  @override
  String get skinGlassSpace => 'Космос';

  @override
  String get skinGlassSpaceHint => 'Прозрачные панели над звёздным небом';

  @override
  String get desktopEventTitleHint => 'Добавьте название';

  @override
  String desktopEventDurationMinutes(int count) {
    return '$count мин';
  }

  @override
  String desktopEventDurationHours(int count) {
    return '$count ч';
  }

  @override
  String desktopEventDurationHoursMinutes(int hours, int minutes) {
    return '$hours ч $minutes мин';
  }

  @override
  String get desktopEventParticipantsHint => 'Пригласите коллег: имя или email';

  @override
  String desktopEventInviteEmail(String email) {
    return 'Пригласить $email';
  }

  @override
  String get desktopEventLocationHint => 'Добавить место';

  @override
  String get desktopEventDescriptionHint => 'Описание или повестка';

  @override
  String get desktopEventMore => 'Ещё: ссылка, переговорная, подбор времени';

  @override
  String get desktopEventLess => 'Скрыть дополнительные настройки';

  @override
  String get desktopEventRepeatCustom => 'Настроить…';

  @override
  String desktopEventSaveHint(String keys) {
    return '$keys — сохранить';
  }

  @override
  String get desktopEventReminder => 'Напоминание';

  @override
  String get desktopEventOtherTime => 'Другое время…';

  @override
  String get desktopEventNoReminders => 'Без напоминаний';

  @override
  String get tasksBoardByDue => 'По срокам';

  @override
  String get tasksBoardByStatus => 'По статусу';

  @override
  String get tasksColumnTomorrow => 'Завтра';

  @override
  String get tasksColumnLater => 'Позже';

  @override
  String get tasksColumnDone => 'Готово';

  @override
  String get tasksColumnTodo => 'К выполнению';

  @override
  String get tasksColumnInProgress => 'В работе';

  @override
  String get tasksQuickAdd => 'Добавить задачу';

  @override
  String get tasksQuickAddHint => 'Что нужно сделать? Enter — добавить';

  @override
  String get tasksDropHere => 'Перетащите задачу сюда';

  @override
  String get tasksBoardHintDue =>
      'Перетаскивайте карточки между колонками — срок изменится сам';

  @override
  String get tasksBoardHintStatus =>
      'Перетаскивайте карточки, чтобы менять статус';

  @override
  String tasksStatToday(int count) {
    return 'На сегодня: $count';
  }

  @override
  String tasksStatOverdue(int count) {
    return 'Просрочено: $count';
  }

  @override
  String tasksStatDone(int count) {
    return 'Выполнено: $count';
  }

  @override
  String tasksShowAll(int count) {
    return 'Показать все · $count';
  }

  @override
  String get tasksShowLess => 'Свернуть';

  @override
  String get tasksPickDay => 'На какой день перенести?';

  @override
  String get tasksSearchHint => 'Поиск по задачам';

  @override
  String get tasksFromMail => 'Из письма';

  @override
  String get tasksMarkInProgress => 'Взять в работу';

  @override
  String get tasksArchive => 'В архив';

  @override
  String get tasksArchived => 'Задача перенесена в архив';

  @override
  String get tasksRestore => 'Вернуть';

  @override
  String get tasksRestored => 'Задача возвращена на доску';

  @override
  String get tasksArchiveTitle => 'Архив';

  @override
  String get tasksArchiveEmpty =>
      'В архиве пока пусто. Готовые задачи можно убрать сюда из меню карточки.';

  @override
  String get tasksArchiveAllBoards => 'Все доски';

  @override
  String get tasksArchiveThisBoard => 'Только эта доска';

  @override
  String get myContactsTitle => 'Мои контакты';

  @override
  String get myContactsAllStaff => 'Все сотрудники';

  @override
  String get myContactsDepartments => 'Отделы';

  @override
  String get myContactsNew => 'Новый контакт';

  @override
  String get myContactsPin => 'Добавить в мои контакты';

  @override
  String get myContactsUnpin => 'Убрать из моих контактов';

  @override
  String myContactsPinned(String name) {
    return '$name — в ваших контактах';
  }

  @override
  String get myContactsEmptyTitle => 'Здесь будут ваши контакты';

  @override
  String get myContactsEmptyHint =>
      'Закрепите коллег звёздочкой в списке сотрудников или добавьте человека не из университета';

  @override
  String get myContactsBrowseStaff => 'Открыть сотрудников';

  @override
  String get myContactsSectionStaff => 'Сотрудники';

  @override
  String get myContactsSectionPersonal => 'Личные контакты';

  @override
  String get myContactsPersonalTag => 'Личный';

  @override
  String get myContactsSelect => 'Выберите контакт, чтобы увидеть подробности';

  @override
  String get myContactsNothingFound => 'Никого не нашли';

  @override
  String get personalContactName => 'Имя и фамилия';

  @override
  String get personalContactNameRequired => 'Введите имя';

  @override
  String get personalContactEmail => 'Email';

  @override
  String get personalContactEmailInvalid => 'Проверьте адрес почты';

  @override
  String get personalContactPhone => 'Телефон';

  @override
  String get personalContactOrganization => 'Организация';

  @override
  String get personalContactPosition => 'Должность';

  @override
  String get personalContactNote => 'Заметка';

  @override
  String get personalContactEdit => 'Изменить контакт';

  @override
  String get personalContactDelete => 'Удалить контакт';

  @override
  String personalContactDeleteConfirm(String name) {
    return 'Удалить «$name» из ваших контактов?';
  }

  @override
  String get personalContactSaved => 'Контакт сохранён';

  @override
  String get personalContactDeleted => 'Контакт удалён';

  @override
  String get personalContactLocalNote =>
      'Личные контакты хранятся на этом компьютере';

  @override
  String get personalContactCall => 'Позвонить';

  @override
  String get skinGlassAstana => 'Астана';

  @override
  String get skinGlassAstanaHint => 'Прозрачные панели над фотографией Астаны';

  @override
  String get skinGlassSemey => 'Семей';

  @override
  String get skinGlassSemeyHint => 'Прозрачные панели над мостом через Иртыш';

  @override
  String get skinGlassCustom => 'Свой фон';

  @override
  String get skinGlassCustomHint => 'Прозрачные панели над вашей картинкой';

  @override
  String get settingsBackdropOwn => 'Своя картинка';

  @override
  String get settingsBackdropOwnHint =>
      'Картинка скопирована в папку XatBox, оригинал можно удалить';

  @override
  String get settingsBackdropNone =>
      'Картинка не выбрана — пока просто тёмный фон';

  @override
  String get settingsBackdropPick => 'Выбрать картинку';

  @override
  String get settingsBackdropReplace => 'Заменить картинку';

  @override
  String get settingsBackdropRemove => 'Убрать';

  @override
  String get settingsBackdropDim => 'Затемнение';

  @override
  String get settingsBackdropBlur => 'Размытие';

  @override
  String get settingsBackdropFailed => 'Не удалось прочитать картинку';

  @override
  String get settingsBackdropCredits => 'Фотографии фонов';

  @override
  String get settingsBackdropCreditAstana =>
      '«Астана» — фото Dauren Nabijan, CC0, Wikimedia Commons';

  @override
  String get settingsBackdropCreditSemey =>
      '«Семей» — фото Иван Быков, CC BY 3.0, обрезано, Wikimedia Commons';

  @override
  String get mailSettingsImport => 'Импорт почты';

  @override
  String get mailSettingsImportSubtitle =>
      'Перенести письма из прежней почтовой системы';

  @override
  String get mailImportHint =>
      'Перенесите письма из прежней почтовой системы в этот ящик. Ничего не заменяется: всё, что уже лежит в папках, остаётся, а письмо, которое у вас уже есть, распознаётся и не задваивается.';

  @override
  String get mailImportFile => 'Архив (.tgz)';

  @override
  String get mailImportFileHint =>
      'Файл, который прежняя почтовая система выгрузила для вашей учётной записи. Zimbra: Настройки → Импорт/Экспорт → Экспорт. До 2 ГБ; импорт идёт в фоне, приложение можно закрыть.';

  @override
  String get mailImportChoose => 'Выбрать архив';

  @override
  String get mailImportStart => 'Загрузить и импортировать';

  @override
  String mailImportUploading(int percent) {
    return 'Загрузка $percent%';
  }

  @override
  String get mailImportCancelUpload => 'Прервать загрузку';

  @override
  String get mailImportPickFile => 'Сначала выберите архив';

  @override
  String mailImportWrongName(String mailbox) {
    return 'Архив назван не по вашему ящику. Загрузите файл с именем $mailbox.tgz';
  }

  @override
  String get mailImportQueued =>
      'Файл загружен: импорт начнётся через несколько секунд';

  @override
  String mailImportImported(int imported, int total) {
    return '$imported из $total импортировано';
  }

  @override
  String mailImportAlready(int count) {
    return '$count уже были здесь';
  }

  @override
  String mailImportFailedCount(int count) {
    return '$count не удалось добавить';
  }

  @override
  String mailImportNotMail(int count) {
    return '$count не почта (контакты, календарь)';
  }

  @override
  String get mailImportDeleteTitle => 'Убрать эту запись об импорте?';

  @override
  String get mailImportDeleteBody =>
      'Запись и загруженный файл будут удалены. Уже импортированные письма останутся в ваших папках.';

  @override
  String get mailImportFailedGeneric => 'Не удалось начать импорт';

  @override
  String get mailImportStatusQueued => 'В очереди';

  @override
  String get mailImportStatusRunning => 'Импорт идёт';

  @override
  String get mailImportStatusDone => 'Готово';

  @override
  String get mailImportStatusFailed => 'Ошибка';

  @override
  String requestsNumber(int number) {
    return 'Заявка №$number';
  }

  @override
  String get requestsWhat => 'Что случилось';

  @override
  String get requestsWhatHint => 'Опишите проблему';

  @override
  String get requestsRoom => 'Кабинет';

  @override
  String get requestsRoomHint => 'Например, 305';

  @override
  String get requestsDate => 'Дата';

  @override
  String get requestsSubmit => 'Отправить заявку';

  @override
  String get requestsFillAll => 'Заполните все три поля';

  @override
  String get requestsStatusNew => 'Новая';

  @override
  String get requestsStatusInProgress => 'В работе';

  @override
  String get requestsStatusDone => 'Выполнена';

  @override
  String get requestsStatusRejected => 'Отклонена';

  @override
  String get requestsEmptyTitle => 'Здесь будут ваши заявки';

  @override
  String get requestsEmptyHint =>
      'Заполните форму ниже: что случилось, кабинет и дата. Ответ придёт в этот чат.';

  @override
  String get requestsListHint => 'Подать заявку';

  @override
  String get tabMore => 'Ещё';

  @override
  String get contactsFilterMine => 'Мои';

  @override
  String get notifTestHintPhone =>
      'Показать пробное уведомление на этом телефоне';
}
