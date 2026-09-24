import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_kk.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('kk'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'XatBox'**
  String get appTitle;

  /// No description provided for @chatFilterChannels.
  ///
  /// In ru, this message translates to:
  /// **'Каналы'**
  String get chatFilterChannels;

  /// No description provided for @channelsDiscoverTitle.
  ///
  /// In ru, this message translates to:
  /// **'Каналы организации'**
  String get channelsDiscoverTitle;

  /// No description provided for @channelsSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск каналов'**
  String get channelsSearchHint;

  /// No description provided for @channelsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'В организации пока нет публичных каналов'**
  String get channelsEmpty;

  /// No description provided for @channelsNothingFound.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get channelsNothingFound;

  /// No description provided for @channelSubscribe.
  ///
  /// In ru, this message translates to:
  /// **'Подписаться'**
  String get channelSubscribe;

  /// No description provided for @channelSubscribed.
  ///
  /// In ru, this message translates to:
  /// **'Вы подписаны'**
  String get channelSubscribed;

  /// No description provided for @channelUnsubscribe.
  ///
  /// In ru, this message translates to:
  /// **'Отписаться'**
  String get channelUnsubscribe;

  /// No description provided for @channelUnsubscribeConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Отписаться от канала «{title}»?'**
  String channelUnsubscribeConfirm(String title);

  /// No description provided for @channelSubscribersCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} подписчик} few{{count} подписчика} many{{count} подписчиков} other{{count} подписчика}}'**
  String channelSubscribersCount(int count);

  /// No description provided for @channelCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать канал'**
  String get channelCreate;

  /// No description provided for @channelNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название канала'**
  String get channelNameLabel;

  /// No description provided for @channelDescriptionLabel.
  ///
  /// In ru, this message translates to:
  /// **'Описание (необязательно)'**
  String get channelDescriptionLabel;

  /// No description provided for @channelPublic.
  ///
  /// In ru, this message translates to:
  /// **'Публичный канал'**
  String get channelPublic;

  /// No description provided for @channelPublicHint.
  ///
  /// In ru, this message translates to:
  /// **'Любой сотрудник найдёт канал в «Каналах организации» и подпишется'**
  String get channelPublicHint;

  /// No description provided for @channelPrivateHint.
  ///
  /// In ru, this message translates to:
  /// **'Подписчиков добавляют администраторы канала'**
  String get channelPrivateHint;

  /// No description provided for @channelReadOnly.
  ///
  /// In ru, this message translates to:
  /// **'Публикуют только администраторы канала'**
  String get channelReadOnly;

  /// No description provided for @channelBadge.
  ///
  /// In ru, this message translates to:
  /// **'Канал'**
  String get channelBadge;

  /// No description provided for @channelSubscribers.
  ///
  /// In ru, this message translates to:
  /// **'Подписчики'**
  String get channelSubscribers;

  /// No description provided for @channelAdmins.
  ///
  /// In ru, this message translates to:
  /// **'Администраторы'**
  String get channelAdmins;

  /// No description provided for @channelAddSubscriber.
  ///
  /// In ru, this message translates to:
  /// **'Добавить подписчика'**
  String get channelAddSubscriber;

  /// No description provided for @channelViews.
  ///
  /// In ru, this message translates to:
  /// **'Просмотры: {count}'**
  String channelViews(int count);

  /// No description provided for @channelNoPermission.
  ///
  /// In ru, this message translates to:
  /// **'У вас нет права создавать каналы'**
  String get channelNoPermission;

  /// No description provided for @pollAttach.
  ///
  /// In ru, this message translates to:
  /// **'Опрос'**
  String get pollAttach;

  /// No description provided for @pollNewTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новый опрос'**
  String get pollNewTitle;

  /// No description provided for @pollQuestionLabel.
  ///
  /// In ru, this message translates to:
  /// **'Вопрос'**
  String get pollQuestionLabel;

  /// No description provided for @pollOptionsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Варианты ответа'**
  String get pollOptionsLabel;

  /// No description provided for @pollOptionHint.
  ///
  /// In ru, this message translates to:
  /// **'Вариант {n}'**
  String pollOptionHint(int n);

  /// No description provided for @pollAddOption.
  ///
  /// In ru, this message translates to:
  /// **'Добавить вариант'**
  String get pollAddOption;

  /// No description provided for @pollRemoveOption.
  ///
  /// In ru, this message translates to:
  /// **'Удалить вариант'**
  String get pollRemoveOption;

  /// No description provided for @pollAnonymous.
  ///
  /// In ru, this message translates to:
  /// **'Анонимное голосование'**
  String get pollAnonymous;

  /// No description provided for @pollMultiple.
  ///
  /// In ru, this message translates to:
  /// **'Несколько вариантов ответа'**
  String get pollMultiple;

  /// No description provided for @pollQuiz.
  ///
  /// In ru, this message translates to:
  /// **'Режим викторины'**
  String get pollQuiz;

  /// No description provided for @pollQuizHint.
  ///
  /// In ru, this message translates to:
  /// **'Отметьте правильный ответ'**
  String get pollQuizHint;

  /// No description provided for @pollCloseSection.
  ///
  /// In ru, this message translates to:
  /// **'Завершить автоматически'**
  String get pollCloseSection;

  /// No description provided for @pollCloseNever.
  ///
  /// In ru, this message translates to:
  /// **'Нет'**
  String get pollCloseNever;

  /// No description provided for @pollClose1h.
  ///
  /// In ru, this message translates to:
  /// **'Через час'**
  String get pollClose1h;

  /// No description provided for @pollClose1d.
  ///
  /// In ru, this message translates to:
  /// **'Через сутки'**
  String get pollClose1d;

  /// No description provided for @pollCloseWeek.
  ///
  /// In ru, this message translates to:
  /// **'Через неделю'**
  String get pollCloseWeek;

  /// No description provided for @pollCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get pollCreate;

  /// No description provided for @pollErrorQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Введите вопрос'**
  String get pollErrorQuestion;

  /// No description provided for @pollErrorOptions.
  ///
  /// In ru, this message translates to:
  /// **'Нужно от 2 до 10 разных вариантов'**
  String get pollErrorOptions;

  /// No description provided for @pollKindAnonymous.
  ///
  /// In ru, this message translates to:
  /// **'Анонимный опрос'**
  String get pollKindAnonymous;

  /// No description provided for @pollKindPublic.
  ///
  /// In ru, this message translates to:
  /// **'Открытый опрос'**
  String get pollKindPublic;

  /// No description provided for @pollKindQuiz.
  ///
  /// In ru, this message translates to:
  /// **'Викторина'**
  String get pollKindQuiz;

  /// No description provided for @pollClosed.
  ///
  /// In ru, this message translates to:
  /// **'Опрос завершён'**
  String get pollClosed;

  /// No description provided for @pollVote.
  ///
  /// In ru, this message translates to:
  /// **'Голосовать'**
  String get pollVote;

  /// No description provided for @pollRetract.
  ///
  /// In ru, this message translates to:
  /// **'Отменить голос'**
  String get pollRetract;

  /// No description provided for @pollCloseNow.
  ///
  /// In ru, this message translates to:
  /// **'Завершить опрос'**
  String get pollCloseNow;

  /// No description provided for @pollVotes.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{Нет голосов} one{{count} голос} few{{count} голоса} many{{count} голосов} other{{count} голоса}}'**
  String pollVotes(int count);

  /// No description provided for @pollEndsAt.
  ///
  /// In ru, this message translates to:
  /// **'до {time}'**
  String pollEndsAt(String time);

  /// No description provided for @pollVotersTitle.
  ///
  /// In ru, this message translates to:
  /// **'Проголосовали'**
  String get pollVotersTitle;

  /// No description provided for @pollNoVoters.
  ///
  /// In ru, this message translates to:
  /// **'Этот вариант пока никто не выбрал'**
  String get pollNoVoters;

  /// No description provided for @pollCorrect.
  ///
  /// In ru, this message translates to:
  /// **'Правильный ответ'**
  String get pollCorrect;

  /// No description provided for @scheduleSendLater.
  ///
  /// In ru, this message translates to:
  /// **'Отправить позже'**
  String get scheduleSendLater;

  /// No description provided for @scheduleIn1h.
  ///
  /// In ru, this message translates to:
  /// **'Через 1 час'**
  String get scheduleIn1h;

  /// No description provided for @scheduleTonight.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня вечером'**
  String get scheduleTonight;

  /// No description provided for @scheduleTomorrowMorning.
  ///
  /// In ru, this message translates to:
  /// **'Завтра утром'**
  String get scheduleTomorrowMorning;

  /// No description provided for @schedulePick.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать дату и время'**
  String get schedulePick;

  /// No description provided for @scheduleTooEarly.
  ///
  /// In ru, this message translates to:
  /// **'Выберите время в будущем'**
  String get scheduleTooEarly;

  /// No description provided for @scheduledTitle.
  ///
  /// In ru, this message translates to:
  /// **'Запланированные'**
  String get scheduledTitle;

  /// No description provided for @scheduledBadge.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} запланированное сообщение} few{{count} запланированных сообщения} many{{count} запланированных сообщений} other{{count} запланированного сообщения}}'**
  String scheduledBadge(int count);

  /// No description provided for @scheduledEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет запланированных сообщений'**
  String get scheduledEmpty;

  /// No description provided for @scheduledSendNow.
  ///
  /// In ru, this message translates to:
  /// **'Отправить сейчас'**
  String get scheduledSendNow;

  /// No description provided for @scheduledEditText.
  ///
  /// In ru, this message translates to:
  /// **'Изменить текст'**
  String get scheduledEditText;

  /// No description provided for @scheduledEditTime.
  ///
  /// In ru, this message translates to:
  /// **'Изменить время'**
  String get scheduledEditTime;

  /// No description provided for @scheduledFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не отправлено'**
  String get scheduledFailed;

  /// No description provided for @scheduledCreated.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение будет отправлено {when}'**
  String scheduledCreated(String when);

  /// No description provided for @scheduledAttachments.
  ///
  /// In ru, this message translates to:
  /// **'Вложений: {count}'**
  String scheduledAttachments(int count);

  /// No description provided for @remindAction.
  ///
  /// In ru, this message translates to:
  /// **'Напомнить'**
  String get remindAction;

  /// No description provided for @remindSheetTitle.
  ///
  /// In ru, this message translates to:
  /// **'Напомнить о сообщении'**
  String get remindSheetTitle;

  /// No description provided for @remindersTitle.
  ///
  /// In ru, this message translates to:
  /// **'Напоминания'**
  String get remindersTitle;

  /// No description provided for @remindersEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Напоминаний нет'**
  String get remindersEmpty;

  /// No description provided for @remindersEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Удерживайте сообщение и выберите «Напомнить»'**
  String get remindersEmptyHint;

  /// No description provided for @remindersUpcoming.
  ///
  /// In ru, this message translates to:
  /// **'Предстоящие'**
  String get remindersUpcoming;

  /// No description provided for @remindersDone.
  ///
  /// In ru, this message translates to:
  /// **'Сработавшие'**
  String get remindersDone;

  /// No description provided for @reminderSetDone.
  ///
  /// In ru, this message translates to:
  /// **'Напомню {when}'**
  String reminderSetDone(String when);

  /// No description provided for @reminderReschedule.
  ///
  /// In ru, this message translates to:
  /// **'Перенести'**
  String get reminderReschedule;

  /// No description provided for @reminderDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить напоминание'**
  String get reminderDelete;

  /// No description provided for @reminderNotificationTitle.
  ///
  /// In ru, this message translates to:
  /// **'Напоминание'**
  String get reminderNotificationTitle;

  /// No description provided for @notifPrefsChannels.
  ///
  /// In ru, this message translates to:
  /// **'Каналы'**
  String get notifPrefsChannels;

  /// No description provided for @chatWhenToday.
  ///
  /// In ru, this message translates to:
  /// **'сегодня в {time}'**
  String chatWhenToday(String time);

  /// No description provided for @chatWhenTomorrow.
  ///
  /// In ru, this message translates to:
  /// **'завтра в {time}'**
  String chatWhenTomorrow(String time);

  /// No description provided for @chatWhenDate.
  ///
  /// In ru, this message translates to:
  /// **'{date} в {time}'**
  String chatWhenDate(String date, String time);

  /// No description provided for @tabMail.
  ///
  /// In ru, this message translates to:
  /// **'Почта'**
  String get tabMail;

  /// No description provided for @tabChat.
  ///
  /// In ru, this message translates to:
  /// **'Чат'**
  String get tabChat;

  /// No description provided for @tabCalls.
  ///
  /// In ru, this message translates to:
  /// **'Звонки'**
  String get tabCalls;

  /// No description provided for @comingSoon.
  ///
  /// In ru, this message translates to:
  /// **'Скоро'**
  String get comingSoon;

  /// No description provided for @chatComingSoonBody.
  ///
  /// In ru, this message translates to:
  /// **'Модуль чата появится в следующем обновлении.'**
  String get chatComingSoonBody;

  /// No description provided for @callsComingSoonBody.
  ///
  /// In ru, this message translates to:
  /// **'Модуль звонков появится в следующем обновлении.'**
  String get callsComingSoonBody;

  /// No description provided for @splashChecking.
  ///
  /// In ru, this message translates to:
  /// **'Проверяем сессию…'**
  String get splashChecking;

  /// No description provided for @splashUnreachableTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сервер недоступен'**
  String get splashUnreachableTitle;

  /// No description provided for @splashUnreachableBody.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось проверить сессию. Проверьте подключение и повторите.'**
  String get splashUnreachableBody;

  /// No description provided for @splashSignInAgain.
  ///
  /// In ru, this message translates to:
  /// **'Войти заново'**
  String get splashSignInAgain;

  /// No description provided for @loginTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход в XatBox'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Используйте учётную запись корпоративной почты'**
  String get loginSubtitle;

  /// No description provided for @loginEmail.
  ///
  /// In ru, this message translates to:
  /// **'Email'**
  String get loginEmail;

  /// No description provided for @loginPassword.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get loginPassword;

  /// No description provided for @loginButton.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get loginButton;

  /// No description provided for @loginEmailRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите email'**
  String get loginEmailRequired;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите пароль'**
  String get loginPasswordRequired;

  /// No description provided for @loginEmailInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Некорректный email'**
  String get loginEmailInvalid;

  /// No description provided for @sessionExpiredBanner.
  ///
  /// In ru, this message translates to:
  /// **'Сессия истекла. Войдите снова.'**
  String get sessionExpiredBanner;

  /// No description provided for @errInvalidCredentialsFormat.
  ///
  /// In ru, this message translates to:
  /// **'Введите email и пароль.'**
  String get errInvalidCredentialsFormat;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In ru, this message translates to:
  /// **'Неверный email или пароль.'**
  String get errInvalidCredentials;

  /// No description provided for @errUserDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Учётная запись отключена. Обратитесь к администратору.'**
  String get errUserDisabled;

  /// No description provided for @errOrganizationSuspended.
  ///
  /// In ru, this message translates to:
  /// **'Подписка организации приостановлена. Обратитесь к администратору.'**
  String get errOrganizationSuspended;

  /// No description provided for @errDirectoryDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Вход через корпоративный каталог отключён. Обратитесь к администратору.'**
  String get errDirectoryDisabled;

  /// No description provided for @errTooManyAttempts.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много попыток входа. Попробуйте позже.'**
  String get errTooManyAttempts;

  /// No description provided for @errDirectoryUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Корпоративный каталог недоступен. Попробуйте позже.'**
  String get errDirectoryUnavailable;

  /// No description provided for @errSubscriptionLimit.
  ///
  /// In ru, this message translates to:
  /// **'Достигнут лимит пользователей организации. Обратитесь к администратору.'**
  String get errSubscriptionLimit;

  /// No description provided for @errInternal.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сервера. Попробуйте позже.'**
  String get errInternal;

  /// No description provided for @errNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Нет соединения с сервером. Проверьте подключение к интернету.'**
  String get errNetwork;

  /// No description provided for @errTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Сервер долго не отвечает. Попробуйте ещё раз.'**
  String get errTimeout;

  /// No description provided for @errUnauthenticated.
  ///
  /// In ru, this message translates to:
  /// **'Сессия истекла. Войдите снова.'**
  String get errUnauthenticated;

  /// No description provided for @errForbidden.
  ///
  /// In ru, this message translates to:
  /// **'У вас нет прав для этого действия.'**
  String get errForbidden;

  /// No description provided for @errNoMailbox.
  ///
  /// In ru, this message translates to:
  /// **'У вашей учётной записи нет активного почтового ящика.'**
  String get errNoMailbox;

  /// No description provided for @errMailServiceUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Почтовый сервис временно недоступен.'**
  String get errMailServiceUnavailable;

  /// No description provided for @errMessageNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Письмо не найдено.'**
  String get errMessageNotFound;

  /// No description provided for @errFolderNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Папка не найдена.'**
  String get errFolderNotFound;

  /// No description provided for @errInvalidMessage.
  ///
  /// In ru, this message translates to:
  /// **'Письмо не прошло проверку: {detail}'**
  String errInvalidMessage(String detail);

  /// No description provided for @errInvalidBody.
  ///
  /// In ru, this message translates to:
  /// **'Некорректный запрос. Обновите приложение.'**
  String get errInvalidBody;

  /// No description provided for @errAttachmentTooLarge.
  ///
  /// In ru, this message translates to:
  /// **'Файл слишком большой.'**
  String get errAttachmentTooLarge;

  /// No description provided for @errStorageUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Хранилище файлов недоступно. Попробуйте позже.'**
  String get errStorageUnavailable;

  /// No description provided for @errConverterUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Предпросмотр документов недоступен на сервере.'**
  String get errConverterUnavailable;

  /// No description provided for @errNotConvertible.
  ///
  /// In ru, this message translates to:
  /// **'Этот файл нельзя показать как PDF.'**
  String get errNotConvertible;

  /// No description provided for @errConvertTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось подготовить предпросмотр: превышено время ожидания.'**
  String get errConvertTimeout;

  /// No description provided for @errConvertFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось подготовить предпросмотр.'**
  String get errConvertFailed;

  /// No description provided for @errUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Что-то пошло не так ({code}).'**
  String errUnknown(String code);

  /// No description provided for @errUnexpected.
  ///
  /// In ru, this message translates to:
  /// **'Неожиданный ответ сервера.'**
  String get errUnexpected;

  /// No description provided for @errRequestId.
  ///
  /// In ru, this message translates to:
  /// **'Код запроса: {id}'**
  String errRequestId(String id);

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In ru, this message translates to:
  /// **'ОК'**
  String get ok;

  /// No description provided for @close.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;

  /// No description provided for @delete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get delete;

  /// No description provided for @send.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get send;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @search.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get search;

  /// No description provided for @loading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка…'**
  String get loading;

  /// No description provided for @offlineBanner.
  ///
  /// In ru, this message translates to:
  /// **'Нет сети — показаны сохранённые данные'**
  String get offlineBanner;

  /// No description provided for @offlineProfileBanner.
  ///
  /// In ru, this message translates to:
  /// **'Сервер недоступен, работа в офлайн-режиме'**
  String get offlineProfileBanner;

  /// No description provided for @folderInbox.
  ///
  /// In ru, this message translates to:
  /// **'Входящие'**
  String get folderInbox;

  /// No description provided for @folderSent.
  ///
  /// In ru, this message translates to:
  /// **'Отправленные'**
  String get folderSent;

  /// No description provided for @folderDrafts.
  ///
  /// In ru, this message translates to:
  /// **'Черновики'**
  String get folderDrafts;

  /// No description provided for @folderSpam.
  ///
  /// In ru, this message translates to:
  /// **'Спам'**
  String get folderSpam;

  /// No description provided for @folderTrash.
  ///
  /// In ru, this message translates to:
  /// **'Корзина'**
  String get folderTrash;

  /// No description provided for @folderBookmarks.
  ///
  /// In ru, this message translates to:
  /// **'Закладки'**
  String get folderBookmarks;

  /// No description provided for @sectionSmartFolders.
  ///
  /// In ru, this message translates to:
  /// **'Умные папки'**
  String get sectionSmartFolders;

  /// No description provided for @sectionBookmarkFolders.
  ///
  /// In ru, this message translates to:
  /// **'Папки закладок'**
  String get sectionBookmarkFolders;

  /// No description provided for @mailEmptyFolder.
  ///
  /// In ru, this message translates to:
  /// **'В этой папке нет писем'**
  String get mailEmptyFolder;

  /// No description provided for @mailEmptySearch.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get mailEmptySearch;

  /// No description provided for @mailSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск в папке'**
  String get mailSearchHint;

  /// No description provided for @filterUnread.
  ///
  /// In ru, this message translates to:
  /// **'Непрочитанные'**
  String get filterUnread;

  /// No description provided for @filterStarred.
  ///
  /// In ru, this message translates to:
  /// **'Закладки'**
  String get filterStarred;

  /// No description provided for @filterAttachments.
  ///
  /// In ru, this message translates to:
  /// **'С вложениями'**
  String get filterAttachments;

  /// No description provided for @mailNoSubject.
  ///
  /// In ru, this message translates to:
  /// **'(без темы)'**
  String get mailNoSubject;

  /// No description provided for @mailLoadMoreError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить ещё'**
  String get mailLoadMoreError;

  /// No description provided for @mailMarkRead.
  ///
  /// In ru, this message translates to:
  /// **'Прочитано'**
  String get mailMarkRead;

  /// No description provided for @mailMarkUnread.
  ///
  /// In ru, this message translates to:
  /// **'Не прочитано'**
  String get mailMarkUnread;

  /// No description provided for @mailStar.
  ///
  /// In ru, this message translates to:
  /// **'В закладки'**
  String get mailStar;

  /// No description provided for @mailUnstar.
  ///
  /// In ru, this message translates to:
  /// **'Убрать из закладок'**
  String get mailUnstar;

  /// No description provided for @mailMoveToTrash.
  ///
  /// In ru, this message translates to:
  /// **'В корзину'**
  String get mailMoveToTrash;

  /// No description provided for @mailDeleteForever.
  ///
  /// In ru, this message translates to:
  /// **'Удалить навсегда'**
  String get mailDeleteForever;

  /// No description provided for @mailDeleteForeverConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Письмо будет удалено безвозвратно. Продолжить?'**
  String get mailDeleteForeverConfirm;

  /// No description provided for @mailReportSpam.
  ///
  /// In ru, this message translates to:
  /// **'В спам'**
  String get mailReportSpam;

  /// No description provided for @mailReportNotSpam.
  ///
  /// In ru, this message translates to:
  /// **'Не спам'**
  String get mailReportNotSpam;

  /// No description provided for @mailMoveTo.
  ///
  /// In ru, this message translates to:
  /// **'Переместить в…'**
  String get mailMoveTo;

  /// No description provided for @mailReply.
  ///
  /// In ru, this message translates to:
  /// **'Ответить'**
  String get mailReply;

  /// No description provided for @mailReplyAll.
  ///
  /// In ru, this message translates to:
  /// **'Ответить всем'**
  String get mailReplyAll;

  /// No description provided for @mailForward.
  ///
  /// In ru, this message translates to:
  /// **'Переслать'**
  String get mailForward;

  /// No description provided for @mailCompose.
  ///
  /// In ru, this message translates to:
  /// **'Написать'**
  String get mailCompose;

  /// No description provided for @mailNoPermission.
  ///
  /// In ru, this message translates to:
  /// **'У вас нет доступа к почте.'**
  String get mailNoPermission;

  /// No description provided for @mailAttachments.
  ///
  /// In ru, this message translates to:
  /// **'Вложения'**
  String get mailAttachments;

  /// No description provided for @attachmentOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть'**
  String get attachmentOpen;

  /// No description provided for @attachmentPreviewPdf.
  ///
  /// In ru, this message translates to:
  /// **'Предпросмотр (PDF)'**
  String get attachmentPreviewPdf;

  /// No description provided for @attachmentDownloading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка файла…'**
  String get attachmentDownloading;

  /// No description provided for @attachmentNoApp.
  ///
  /// In ru, this message translates to:
  /// **'Нет приложения для открытия этого файла'**
  String get attachmentNoApp;

  /// No description provided for @mailFrom.
  ///
  /// In ru, this message translates to:
  /// **'От'**
  String get mailFrom;

  /// No description provided for @mailTo.
  ///
  /// In ru, this message translates to:
  /// **'Кому'**
  String get mailTo;

  /// No description provided for @mailCc.
  ///
  /// In ru, this message translates to:
  /// **'Копия'**
  String get mailCc;

  /// No description provided for @mailBcc.
  ///
  /// In ru, this message translates to:
  /// **'Скрытая копия'**
  String get mailBcc;

  /// No description provided for @mailSubject.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get mailSubject;

  /// No description provided for @mailBody.
  ///
  /// In ru, this message translates to:
  /// **'Текст письма'**
  String get mailBody;

  /// No description provided for @mailThreadTitle.
  ///
  /// In ru, this message translates to:
  /// **'Переписка ({count})'**
  String mailThreadTitle(int count);

  /// No description provided for @mailShowHtml.
  ///
  /// In ru, this message translates to:
  /// **'Показать оформление'**
  String get mailShowHtml;

  /// No description provided for @mailShowText.
  ///
  /// In ru, this message translates to:
  /// **'Показать как текст'**
  String get mailShowText;

  /// No description provided for @mailNoBody.
  ///
  /// In ru, this message translates to:
  /// **'(пустое письмо)'**
  String get mailNoBody;

  /// No description provided for @mailRemoteContentBlocked.
  ///
  /// In ru, this message translates to:
  /// **'Внешние изображения заблокированы'**
  String get mailRemoteContentBlocked;

  /// No description provided for @mailOpenLinkTitle.
  ///
  /// In ru, this message translates to:
  /// **'Открыть ссылку?'**
  String get mailOpenLinkTitle;

  /// No description provided for @mailOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть'**
  String get mailOpen;

  /// No description provided for @mailUnreadCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} непрочитанных'**
  String mailUnreadCount(int count);

  /// No description provided for @mailActionDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get mailActionDone;

  /// No description provided for @mailMovedToTrash.
  ///
  /// In ru, this message translates to:
  /// **'Письмо перемещено в корзину'**
  String get mailMovedToTrash;

  /// No description provided for @mailDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Письмо удалено'**
  String get mailDeleted;

  /// No description provided for @mailReportedSpam.
  ///
  /// In ru, this message translates to:
  /// **'Письмо отмечено как спам'**
  String get mailReportedSpam;

  /// No description provided for @mailReportedHam.
  ///
  /// In ru, this message translates to:
  /// **'Письмо возвращено во входящие'**
  String get mailReportedHam;

  /// No description provided for @composeTitleNew.
  ///
  /// In ru, this message translates to:
  /// **'Новое письмо'**
  String get composeTitleNew;

  /// No description provided for @composeTitleReply.
  ///
  /// In ru, this message translates to:
  /// **'Ответ'**
  String get composeTitleReply;

  /// No description provided for @composeTitleForward.
  ///
  /// In ru, this message translates to:
  /// **'Пересылка'**
  String get composeTitleForward;

  /// No description provided for @composeTitleDraft.
  ///
  /// In ru, this message translates to:
  /// **'Черновик'**
  String get composeTitleDraft;

  /// No description provided for @composeRecipientsRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите хотя бы одного получателя'**
  String get composeRecipientsRequired;

  /// No description provided for @composeInvalidAddress.
  ///
  /// In ru, this message translates to:
  /// **'Некорректный адрес: {address}'**
  String composeInvalidAddress(String address);

  /// No description provided for @composeTooManyRecipients.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много получателей (максимум 100)'**
  String get composeTooManyRecipients;

  /// No description provided for @composeSubjectTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Слишком длинная тема'**
  String get composeSubjectTooLong;

  /// No description provided for @composeTooManyAttachments.
  ///
  /// In ru, this message translates to:
  /// **'Не более 20 вложений'**
  String get composeTooManyAttachments;

  /// No description provided for @composeAttachmentTooLarge.
  ///
  /// In ru, this message translates to:
  /// **'Файл «{name}» больше лимита {limit}'**
  String composeAttachmentTooLarge(String name, String limit);

  /// No description provided for @composeAddAttachment.
  ///
  /// In ru, this message translates to:
  /// **'Прикрепить файл'**
  String get composeAddAttachment;

  /// No description provided for @composeSent.
  ///
  /// In ru, this message translates to:
  /// **'Письмо отправлено'**
  String get composeSent;

  /// No description provided for @composeSaveDraft.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить черновик'**
  String get composeSaveDraft;

  /// No description provided for @composeDraftSaved.
  ///
  /// In ru, this message translates to:
  /// **'Черновик сохранён'**
  String get composeDraftSaved;

  /// No description provided for @composeDiscard.
  ///
  /// In ru, this message translates to:
  /// **'Не сохранять'**
  String get composeDiscard;

  /// No description provided for @composeDiscardTitle.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть письмо?'**
  String get composeDiscardTitle;

  /// No description provided for @composeDiscardBody.
  ///
  /// In ru, this message translates to:
  /// **'Несохранённые изменения будут потеряны.'**
  String get composeDiscardBody;

  /// No description provided for @composeSending.
  ///
  /// In ru, this message translates to:
  /// **'Отправка…'**
  String get composeSending;

  /// No description provided for @composeForwardedAttachments.
  ///
  /// In ru, this message translates to:
  /// **'Вложения из исходного письма'**
  String get composeForwardedAttachments;

  /// No description provided for @composeSignatureNote.
  ///
  /// In ru, this message translates to:
  /// **'Подпись добавит сервер при отправке.'**
  String get composeSignatureNote;

  /// No description provided for @composeQuoteHeader.
  ///
  /// In ru, this message translates to:
  /// **'{date}, {from} написал(а):'**
  String composeQuoteHeader(String date, String from);

  /// No description provided for @composeForwardHeader.
  ///
  /// In ru, this message translates to:
  /// **'---------- Пересланное сообщение ----------'**
  String get composeForwardHeader;

  /// No description provided for @composeRecipientHint.
  ///
  /// In ru, this message translates to:
  /// **'адреса через запятую'**
  String get composeRecipientHint;

  /// No description provided for @composeNoSendPermission.
  ///
  /// In ru, this message translates to:
  /// **'У вас нет права отправлять письма.'**
  String get composeNoSendPermission;

  /// No description provided for @profileTitle.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get profileTitle;

  /// No description provided for @profileSessions.
  ///
  /// In ru, this message translates to:
  /// **'Активные сессии'**
  String get profileSessions;

  /// No description provided for @profileCurrentSession.
  ///
  /// In ru, this message translates to:
  /// **'Текущая'**
  String get profileCurrentSession;

  /// No description provided for @profileEndSession.
  ///
  /// In ru, this message translates to:
  /// **'Завершить'**
  String get profileEndSession;

  /// No description provided for @profileEndOthers.
  ///
  /// In ru, this message translates to:
  /// **'Завершить остальные сессии'**
  String get profileEndOthers;

  /// No description provided for @profileDepartment.
  ///
  /// In ru, this message translates to:
  /// **'Подразделение'**
  String get profileDepartment;

  /// No description provided for @profileSessionsEnded.
  ///
  /// In ru, this message translates to:
  /// **'Завершено сессий: {count}'**
  String profileSessionsEnded(int count);

  /// No description provided for @profileExpires.
  ///
  /// In ru, this message translates to:
  /// **'Действует до {date}'**
  String profileExpires(String date);

  /// No description provided for @settingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settingsTitle;

  /// No description provided for @settingsLogout.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get settingsLogout;

  /// No description provided for @settingsLogoutConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из учётной записи на этом устройстве?'**
  String get settingsLogoutConfirm;

  /// No description provided for @settingsCacheSection.
  ///
  /// In ru, this message translates to:
  /// **'Память и данные'**
  String get settingsCacheSection;

  /// No description provided for @settingsCacheLimit.
  ///
  /// In ru, this message translates to:
  /// **'Хранить открытых писем офлайн'**
  String get settingsCacheLimit;

  /// No description provided for @settingsCacheClear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить кэш'**
  String get settingsCacheClear;

  /// No description provided for @settingsCacheCleared.
  ///
  /// In ru, this message translates to:
  /// **'Кэш очищен'**
  String get settingsCacheCleared;

  /// No description provided for @settingsCacheStats.
  ///
  /// In ru, this message translates to:
  /// **'В кэше: {messages} писем, {lists} списков'**
  String settingsCacheStats(int messages, int lists);

  /// No description provided for @settingsVersion.
  ///
  /// In ru, this message translates to:
  /// **'Версия {version}'**
  String settingsVersion(String version);

  /// No description provided for @settingsDiagnostics.
  ///
  /// In ru, this message translates to:
  /// **'Диагностика'**
  String get settingsDiagnostics;

  /// No description provided for @settingsDiagnosticsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Событий пока нет'**
  String get settingsDiagnosticsEmpty;

  /// No description provided for @settingsNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsHint.
  ///
  /// In ru, this message translates to:
  /// **'Какие push-уведомления присылать, тихие часы'**
  String get settingsNotificationsHint;

  /// No description provided for @settingsSendErrorReports.
  ///
  /// In ru, this message translates to:
  /// **'Отправлять отчёты об ошибках'**
  String get settingsSendErrorReports;

  /// No description provided for @settingsSendErrorReportsHint.
  ///
  /// In ru, this message translates to:
  /// **'Технические данные о сбоях уходят только на сервер XatBox — без текстов сообщений и адресов'**
  String get settingsSendErrorReportsHint;

  /// No description provided for @notifPrefsServerHint.
  ///
  /// In ru, this message translates to:
  /// **'Настройки хранятся на сервере: отключённые уведомления не отправляются вовсе'**
  String get notifPrefsServerHint;

  /// No description provided for @notifPrefsTypesSection.
  ///
  /// In ru, this message translates to:
  /// **'Что присылать'**
  String get notifPrefsTypesSection;

  /// No description provided for @notifPrefsDirect.
  ///
  /// In ru, this message translates to:
  /// **'Личные сообщения'**
  String get notifPrefsDirect;

  /// No description provided for @notifPrefsGroups.
  ///
  /// In ru, this message translates to:
  /// **'Группы'**
  String get notifPrefsGroups;

  /// No description provided for @notifPrefsMentionsOnly.
  ///
  /// In ru, this message translates to:
  /// **'Только упоминания в группах'**
  String get notifPrefsMentionsOnly;

  /// No description provided for @notifPrefsCalls.
  ///
  /// In ru, this message translates to:
  /// **'Звонки'**
  String get notifPrefsCalls;

  /// No description provided for @notifPrefsQuietSection.
  ///
  /// In ru, this message translates to:
  /// **'Тихие часы'**
  String get notifPrefsQuietSection;

  /// No description provided for @notifPrefsQuietEnabled.
  ///
  /// In ru, this message translates to:
  /// **'Не беспокоить в тихие часы'**
  String get notifPrefsQuietEnabled;

  /// No description provided for @notifPrefsQuietHint.
  ///
  /// In ru, this message translates to:
  /// **'Каждый день, по времени устройства ({zone})'**
  String notifPrefsQuietHint(String zone);

  /// No description provided for @notifPrefsQuietStart.
  ///
  /// In ru, this message translates to:
  /// **'Начало'**
  String get notifPrefsQuietStart;

  /// No description provided for @notifPrefsQuietEnd.
  ///
  /// In ru, this message translates to:
  /// **'Конец'**
  String get notifPrefsQuietEnd;

  /// No description provided for @notifPrefsQuietAllowCalls.
  ///
  /// In ru, this message translates to:
  /// **'Пропускать звонки в тихие часы'**
  String get notifPrefsQuietAllowCalls;

  /// No description provided for @notifPrefsQuietAllowCallsHint.
  ///
  /// In ru, this message translates to:
  /// **'Входящие звонки звонят как обычно'**
  String get notifPrefsQuietAllowCallsHint;

  /// No description provided for @notifPrefsPending.
  ///
  /// In ru, this message translates to:
  /// **'Изменения отправятся, когда появится связь'**
  String get notifPrefsPending;

  /// No description provided for @notifPrefsLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить настройки уведомлений'**
  String get notifPrefsLoadFailed;

  /// No description provided for @notifPrefsRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get notifPrefsRetry;

  /// No description provided for @notifPrefsSystemSettings.
  ///
  /// In ru, this message translates to:
  /// **'Системные настройки уведомлений'**
  String get notifPrefsSystemSettings;

  /// No description provided for @notifPrefsSystemSettingsHint.
  ///
  /// In ru, this message translates to:
  /// **'Звук, вибрация и каналы Android'**
  String get notifPrefsSystemSettingsHint;

  /// No description provided for @notifBackgroundSection.
  ///
  /// In ru, this message translates to:
  /// **'Соединение'**
  String get notifBackgroundSection;

  /// No description provided for @notifBackgroundTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оставаться на связи в фоне'**
  String get notifBackgroundTitle;

  /// No description provided for @notifBackgroundOneMinute.
  ///
  /// In ru, this message translates to:
  /// **'1 минута'**
  String get notifBackgroundOneMinute;

  /// No description provided for @notifBackgroundFifteenMinutes.
  ///
  /// In ru, this message translates to:
  /// **'15 минут'**
  String get notifBackgroundFifteenMinutes;

  /// No description provided for @notifBackgroundAlways.
  ///
  /// In ru, this message translates to:
  /// **'Всегда'**
  String get notifBackgroundAlways;

  /// No description provided for @notifBackgroundAuto.
  ///
  /// In ru, this message translates to:
  /// **'По умолчанию ({value})'**
  String notifBackgroundAuto(String value);

  /// No description provided for @notifBackgroundHint.
  ///
  /// In ru, this message translates to:
  /// **'Сколько приложение держит соединение после сворачивания. Когда оно закрыто, новые сообщения и звонки приходят только через push-уведомления. Во время звонка соединение не закрывается.'**
  String get notifBackgroundHint;

  /// No description provided for @notifBackgroundNoPush.
  ///
  /// In ru, this message translates to:
  /// **'Push-уведомления не настроены: пока соединение закрыто, сообщения и входящие звонки не приходят'**
  String get notifBackgroundNoPush;

  /// No description provided for @notifBackgroundAlwaysWarning.
  ///
  /// In ru, this message translates to:
  /// **'Быстрее расходует заряд батареи'**
  String get notifBackgroundAlwaysWarning;

  /// No description provided for @permOnboardNotifTitle.
  ///
  /// In ru, this message translates to:
  /// **'Включить уведомления?'**
  String get permOnboardNotifTitle;

  /// No description provided for @permOnboardNotifBody.
  ///
  /// In ru, this message translates to:
  /// **'XatBox сообщит о новых сообщениях, входящих звонках и напоминаниях календаря. Android спросит разрешение — нажмите «Разрешить».'**
  String get permOnboardNotifBody;

  /// No description provided for @permOnboardFsiTitle.
  ///
  /// In ru, this message translates to:
  /// **'Звонки на весь экран'**
  String get permOnboardFsiTitle;

  /// No description provided for @permOnboardFsiBody.
  ///
  /// In ru, this message translates to:
  /// **'Чтобы входящий звонок был виден на заблокированном экране, разрешите XatBox полноэкранные уведомления. Откроются настройки Android: включите переключатель и вернитесь в приложение.'**
  String get permOnboardFsiBody;

  /// No description provided for @permAllow.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить'**
  String get permAllow;

  /// No description provided for @permNotNow.
  ///
  /// In ru, this message translates to:
  /// **'Не сейчас'**
  String get permNotNow;

  /// No description provided for @permOpenSettings.
  ///
  /// In ru, this message translates to:
  /// **'Открыть настройки'**
  String get permOpenSettings;

  /// No description provided for @notifDeviceSection.
  ///
  /// In ru, this message translates to:
  /// **'Этот телефон'**
  String get notifDeviceSection;

  /// No description provided for @notifDeviceNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Разрешение на уведомления'**
  String get notifDeviceNotifications;

  /// No description provided for @notifDeviceGranted.
  ///
  /// In ru, this message translates to:
  /// **'Разрешено'**
  String get notifDeviceGranted;

  /// No description provided for @notifDeviceNotificationsOff.
  ///
  /// In ru, this message translates to:
  /// **'Выключено: сообщения, звонки и напоминания не показываются'**
  String get notifDeviceNotificationsOff;

  /// No description provided for @notifDeviceFullScreen.
  ///
  /// In ru, this message translates to:
  /// **'Звонки на весь экран'**
  String get notifDeviceFullScreen;

  /// No description provided for @notifDeviceFullScreenOff.
  ///
  /// In ru, this message translates to:
  /// **'Выключено: входящий звонок будет только маленьким уведомлением'**
  String get notifDeviceFullScreenOff;

  /// No description provided for @notifDeviceBattery.
  ///
  /// In ru, this message translates to:
  /// **'Без ограничений батареи'**
  String get notifDeviceBattery;

  /// No description provided for @notifDeviceBatteryOn.
  ///
  /// In ru, this message translates to:
  /// **'Android не откладывает работу приложения в фоне'**
  String get notifDeviceBatteryOn;

  /// No description provided for @notifDeviceBatteryOff.
  ///
  /// In ru, this message translates to:
  /// **'Android может откладывать сообщения и напоминания, пока телефоном не пользуются'**
  String get notifDeviceBatteryOff;

  /// No description provided for @notifDeviceBatteryNoPush.
  ///
  /// In ru, this message translates to:
  /// **'Пока push-уведомления не настроены, это особенно важно: без ограничений приложение дольше остаётся на связи'**
  String get notifDeviceBatteryNoPush;

  /// No description provided for @notifDeviceHelp.
  ///
  /// In ru, this message translates to:
  /// **'Автозапуск и фоновая работа'**
  String get notifDeviceHelp;

  /// No description provided for @notifDeviceHelpHint.
  ///
  /// In ru, this message translates to:
  /// **'Xiaomi, Huawei, Honor, Samsung, Oppo, Realme'**
  String get notifDeviceHelpHint;

  /// No description provided for @bgHelpTitle.
  ///
  /// In ru, this message translates to:
  /// **'Работа в фоне'**
  String get bgHelpTitle;

  /// No description provided for @bgHelpIntro.
  ///
  /// In ru, this message translates to:
  /// **'Некоторые производители закрывают приложения в фоне сильнее, чем обычный Android. Если сообщения или звонки приходят с опозданием, проверьте настройки ниже. Названия пунктов могут немного отличаться в разных версиях прошивки.'**
  String get bgHelpIntro;

  /// No description provided for @bgHelpCommonTitle.
  ///
  /// In ru, this message translates to:
  /// **'Для всех телефонов'**
  String get bgHelpCommonTitle;

  /// No description provided for @bgHelpCommonSteps.
  ///
  /// In ru, this message translates to:
  /// **'1. Настройки → Приложения → XatBox → Уведомления: включите все категории.\n2. Там же → Батарея: «Без ограничений» («Не оптимизировать»).\n3. Не смахивайте XatBox из недавних приложений, если ждёте звонка.'**
  String get bgHelpCommonSteps;

  /// No description provided for @bgHelpXiaomiTitle.
  ///
  /// In ru, this message translates to:
  /// **'Xiaomi, Redmi, POCO (MIUI, HyperOS)'**
  String get bgHelpXiaomiTitle;

  /// No description provided for @bgHelpXiaomiSteps.
  ///
  /// In ru, this message translates to:
  /// **'1. Настройки → Приложения → Все приложения → XatBox.\n2. Включите «Автозапуск».\n3. «Контроль активности» (Экономия энергии) → «Нет ограничений».\n4. «Другие разрешения»: разрешите «Экран блокировки» и «Всплывающие окна в фоне».\n5. В недавних приложениях потяните карточку XatBox вниз и закрепите замком.'**
  String get bgHelpXiaomiSteps;

  /// No description provided for @bgHelpHuaweiTitle.
  ///
  /// In ru, this message translates to:
  /// **'Huawei, Honor (EMUI, MagicOS)'**
  String get bgHelpHuaweiTitle;

  /// No description provided for @bgHelpHuaweiSteps.
  ///
  /// In ru, this message translates to:
  /// **'1. Настройки → Батарея → Запуск приложений.\n2. Найдите XatBox и выключите «Автоматическое управление».\n3. В окне включите «Автозапуск», «Косвенный запуск» и «Работа в фоне».\n4. Настройки → Уведомления → XatBox: разрешите уведомления на экране блокировки.'**
  String get bgHelpHuaweiSteps;

  /// No description provided for @bgHelpSamsungTitle.
  ///
  /// In ru, this message translates to:
  /// **'Samsung (One UI)'**
  String get bgHelpSamsungTitle;

  /// No description provided for @bgHelpSamsungSteps.
  ///
  /// In ru, this message translates to:
  /// **'1. Настройки → Приложения → XatBox → Батарея: «Не ограничено».\n2. Настройки → Батарея → Ограничения фоновых приложений: XatBox не должен быть в «Спящих» и «Глубоко спящих».\n3. Добавьте XatBox в «Никогда не спящие приложения».'**
  String get bgHelpSamsungSteps;

  /// No description provided for @bgHelpOppoTitle.
  ///
  /// In ru, this message translates to:
  /// **'Oppo, Realme, OnePlus, Vivo'**
  String get bgHelpOppoTitle;

  /// No description provided for @bgHelpOppoSteps.
  ///
  /// In ru, this message translates to:
  /// **'1. Настройки → Приложения → XatBox → Использование батареи: разрешите «Работу в фоне» и «Автозапуск».\n2. Настройки → Батарея → Оптимизация: для XatBox — «Не оптимизировать».\n3. Закрепите XatBox в недавних приложениях.'**
  String get bgHelpOppoSteps;

  /// No description provided for @bgHelpCheck.
  ///
  /// In ru, this message translates to:
  /// **'Проверка: заблокируйте телефон на 15 минут и попросите коллегу написать или позвонить.'**
  String get bgHelpCheck;

  /// No description provided for @a11ySearchPrevious.
  ///
  /// In ru, this message translates to:
  /// **'Предыдущее совпадение'**
  String get a11ySearchPrevious;

  /// No description provided for @a11ySearchNext.
  ///
  /// In ru, this message translates to:
  /// **'Следующее совпадение'**
  String get a11ySearchNext;

  /// No description provided for @a11yMuted.
  ///
  /// In ru, this message translates to:
  /// **'без звука'**
  String get a11yMuted;

  /// No description provided for @a11yPinned.
  ///
  /// In ru, this message translates to:
  /// **'закреплён'**
  String get a11yPinned;

  /// No description provided for @a11yUnreadCount.
  ///
  /// In ru, this message translates to:
  /// **'непрочитанных: {count}'**
  String a11yUnreadCount(int count);

  /// No description provided for @a11yMarkedUnread.
  ///
  /// In ru, this message translates to:
  /// **'отмечен как непрочитанный'**
  String get a11yMarkedUnread;

  /// No description provided for @a11yMicOff.
  ///
  /// In ru, this message translates to:
  /// **'микрофон выключен'**
  String get a11yMicOff;

  /// No description provided for @a11yHandsRaised.
  ///
  /// In ru, this message translates to:
  /// **'подняли руку: {count}'**
  String a11yHandsRaised(int count);

  /// No description provided for @a11yVoiceSeek.
  ///
  /// In ru, this message translates to:
  /// **'Перемотка голосового сообщения'**
  String get a11yVoiceSeek;

  /// No description provided for @a11yPinEntered.
  ///
  /// In ru, this message translates to:
  /// **'Введено цифр: {filled} из {length}'**
  String a11yPinEntered(int filled, int length);

  /// No description provided for @a11yDecrease.
  ///
  /// In ru, this message translates to:
  /// **'Уменьшить'**
  String get a11yDecrease;

  /// No description provided for @a11yIncrease.
  ///
  /// In ru, this message translates to:
  /// **'Увеличить'**
  String get a11yIncrease;

  /// No description provided for @a11yAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get a11yAdd;

  /// No description provided for @a11yReaction.
  ///
  /// In ru, this message translates to:
  /// **'Реакция {emoji}: {count}'**
  String a11yReaction(String emoji, int count);

  /// No description provided for @a11yVoiceMessage.
  ///
  /// In ru, this message translates to:
  /// **'Голосовое сообщение, {duration}'**
  String a11yVoiceMessage(String duration);

  /// No description provided for @a11ySelected.
  ///
  /// In ru, this message translates to:
  /// **'выбрано'**
  String get a11ySelected;

  /// No description provided for @a11yFavourite.
  ///
  /// In ru, this message translates to:
  /// **'в избранном'**
  String get a11yFavourite;

  /// No description provided for @a11yGuest.
  ///
  /// In ru, this message translates to:
  /// **'гость'**
  String get a11yGuest;

  /// No description provided for @chatTitle.
  ///
  /// In ru, this message translates to:
  /// **'Чат'**
  String get chatTitle;

  /// No description provided for @chatDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Чат не настроен в этой сборке.'**
  String get chatDisabled;

  /// No description provided for @chatNoAccess.
  ///
  /// In ru, this message translates to:
  /// **'У вас нет доступа к чату.'**
  String get chatNoAccess;

  /// No description provided for @chatEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Пока нет чатов. Начните переписку с коллегой.'**
  String get chatEmpty;

  /// No description provided for @chatNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый чат'**
  String get chatNew;

  /// No description provided for @chatNewGroup.
  ///
  /// In ru, this message translates to:
  /// **'Новая группа'**
  String get chatNewGroup;

  /// No description provided for @chatGroupTitle.
  ///
  /// In ru, this message translates to:
  /// **'Название группы'**
  String get chatGroupTitle;

  /// No description provided for @chatCreateGroup.
  ///
  /// In ru, this message translates to:
  /// **'Создать группу'**
  String get chatCreateGroup;

  /// No description provided for @chatSearchUsers.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по имени или email'**
  String get chatSearchUsers;

  /// No description provided for @chatSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по чатам'**
  String get chatSearch;

  /// No description provided for @chatSearchMessages.
  ///
  /// In ru, this message translates to:
  /// **'Сообщения'**
  String get chatSearchMessages;

  /// No description provided for @chatNoUsers.
  ///
  /// In ru, this message translates to:
  /// **'Никого не найдено'**
  String get chatNoUsers;

  /// No description provided for @chatSelectedMembers.
  ///
  /// In ru, this message translates to:
  /// **'Выбрано: {count}'**
  String chatSelectedMembers(int count);

  /// No description provided for @chatConnecting.
  ///
  /// In ru, this message translates to:
  /// **'Подключение…'**
  String get chatConnecting;

  /// No description provided for @chatSyncing.
  ///
  /// In ru, this message translates to:
  /// **'Обновление…'**
  String get chatSyncing;

  /// No description provided for @chatOffline.
  ///
  /// In ru, this message translates to:
  /// **'Нет соединения'**
  String get chatOffline;

  /// No description provided for @chatOnline.
  ///
  /// In ru, this message translates to:
  /// **'в сети'**
  String get chatOnline;

  /// No description provided for @chatLastSeen.
  ///
  /// In ru, this message translates to:
  /// **'был(а) {when}'**
  String chatLastSeen(String when);

  /// No description provided for @chatMembersCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} участников'**
  String chatMembersCount(int count);

  /// No description provided for @chatTyping.
  ///
  /// In ru, this message translates to:
  /// **'{name} печатает…'**
  String chatTyping(String name);

  /// No description provided for @chatTypingMany.
  ///
  /// In ru, this message translates to:
  /// **'печатают…'**
  String get chatTypingMany;

  /// No description provided for @chatRecording.
  ///
  /// In ru, this message translates to:
  /// **'{name} записывает голосовое…'**
  String chatRecording(String name);

  /// No description provided for @chatYou.
  ///
  /// In ru, this message translates to:
  /// **'Вы'**
  String get chatYou;

  /// No description provided for @chatMessageHint.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение'**
  String get chatMessageHint;

  /// No description provided for @chatSend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get chatSend;

  /// No description provided for @chatCameraTitle.
  ///
  /// In ru, this message translates to:
  /// **'Снимок с камеры'**
  String get chatCameraTitle;

  /// No description provided for @chatCameraTake.
  ///
  /// In ru, this message translates to:
  /// **'Снять'**
  String get chatCameraTake;

  /// No description provided for @chatCameraRetake.
  ///
  /// In ru, this message translates to:
  /// **'Переснять'**
  String get chatCameraRetake;

  /// No description provided for @chatCameraDevice.
  ///
  /// In ru, this message translates to:
  /// **'Камера'**
  String get chatCameraDevice;

  /// No description provided for @chatCameraUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Камера недоступна. Проверьте, что она подключена и не занята другой программой.'**
  String get chatCameraUnavailable;

  /// No description provided for @chatAttach.
  ///
  /// In ru, this message translates to:
  /// **'Прикрепить'**
  String get chatAttach;

  /// No description provided for @chatVoiceHold.
  ///
  /// In ru, this message translates to:
  /// **'Удерживайте для записи'**
  String get chatVoiceHold;

  /// No description provided for @chatVoiceSlideCancel.
  ///
  /// In ru, this message translates to:
  /// **'← Смахните, чтобы отменить'**
  String get chatVoiceSlideCancel;

  /// No description provided for @chatVoiceLocked.
  ///
  /// In ru, this message translates to:
  /// **'Запись'**
  String get chatVoiceLocked;

  /// No description provided for @chatVoiceCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get chatVoiceCancel;

  /// No description provided for @chatVoicePreview.
  ///
  /// In ru, this message translates to:
  /// **'Голосовое сообщение'**
  String get chatVoicePreview;

  /// No description provided for @chatMicDenied.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к микрофону. Разрешите его в настройках.'**
  String get chatMicDenied;

  /// No description provided for @chatVoiceStartFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось начать запись. Проверьте микрофон.'**
  String get chatVoiceStartFailed;

  /// No description provided for @chatVoiceSendFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось завершить запись. Попробуйте ещё раз.'**
  String get chatVoiceSendFailed;

  /// No description provided for @chatOpenSettings.
  ///
  /// In ru, this message translates to:
  /// **'Открыть настройки'**
  String get chatOpenSettings;

  /// No description provided for @chatReply.
  ///
  /// In ru, this message translates to:
  /// **'Ответить'**
  String get chatReply;

  /// No description provided for @chatForward.
  ///
  /// In ru, this message translates to:
  /// **'Переслать'**
  String get chatForward;

  /// No description provided for @chatCopy.
  ///
  /// In ru, this message translates to:
  /// **'Копировать'**
  String get chatCopy;

  /// No description provided for @chatEdit.
  ///
  /// In ru, this message translates to:
  /// **'Изменить'**
  String get chatEdit;

  /// No description provided for @chatDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get chatDelete;

  /// No description provided for @chatReact.
  ///
  /// In ru, this message translates to:
  /// **'Реакция'**
  String get chatReact;

  /// No description provided for @chatEdited.
  ///
  /// In ru, this message translates to:
  /// **'изменено'**
  String get chatEdited;

  /// No description provided for @chatDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение удалено'**
  String get chatDeleted;

  /// No description provided for @chatCopied.
  ///
  /// In ru, this message translates to:
  /// **'Скопировано'**
  String get chatCopied;

  /// No description provided for @chatForwardTo.
  ///
  /// In ru, this message translates to:
  /// **'Переслать в…'**
  String get chatForwardTo;

  /// No description provided for @chatForwarded.
  ///
  /// In ru, this message translates to:
  /// **'Переслано'**
  String get chatForwarded;

  /// No description provided for @chatReplyingTo.
  ///
  /// In ru, this message translates to:
  /// **'Ответ на сообщение'**
  String get chatReplyingTo;

  /// No description provided for @chatEditing.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование'**
  String get chatEditing;

  /// No description provided for @chatPending.
  ///
  /// In ru, this message translates to:
  /// **'Отправляется…'**
  String get chatPending;

  /// No description provided for @chatFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не отправлено'**
  String get chatFailed;

  /// No description provided for @chatRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get chatRetry;

  /// No description provided for @chatDiscard.
  ///
  /// In ru, this message translates to:
  /// **'Удалить из очереди'**
  String get chatDiscard;

  /// No description provided for @chatStatusSent.
  ///
  /// In ru, this message translates to:
  /// **'Отправлено'**
  String get chatStatusSent;

  /// No description provided for @chatStatusDelivered.
  ///
  /// In ru, this message translates to:
  /// **'Доставлено'**
  String get chatStatusDelivered;

  /// No description provided for @chatStatusRead.
  ///
  /// In ru, this message translates to:
  /// **'Прочитано'**
  String get chatStatusRead;

  /// No description provided for @chatAttachmentImage.
  ///
  /// In ru, this message translates to:
  /// **'Фото'**
  String get chatAttachmentImage;

  /// No description provided for @chatAttachmentVideo.
  ///
  /// In ru, this message translates to:
  /// **'Видео'**
  String get chatAttachmentVideo;

  /// No description provided for @chatAttachmentVoice.
  ///
  /// In ru, this message translates to:
  /// **'Голосовое сообщение'**
  String get chatAttachmentVoice;

  /// No description provided for @chatAttachmentAudio.
  ///
  /// In ru, this message translates to:
  /// **'Аудио'**
  String get chatAttachmentAudio;

  /// No description provided for @chatAttachmentFile.
  ///
  /// In ru, this message translates to:
  /// **'Файл'**
  String get chatAttachmentFile;

  /// No description provided for @chatFileOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть'**
  String get chatFileOpen;

  /// No description provided for @chatFileDownloading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка…'**
  String get chatFileDownloading;

  /// No description provided for @chatSystemMemberAdded.
  ///
  /// In ru, this message translates to:
  /// **'{actor} добавил(а) {user}'**
  String chatSystemMemberAdded(String actor, String user);

  /// No description provided for @chatSystemMemberRemoved.
  ///
  /// In ru, this message translates to:
  /// **'{actor} удалил(а) {user}'**
  String chatSystemMemberRemoved(String actor, String user);

  /// No description provided for @chatSystemMemberLeft.
  ///
  /// In ru, this message translates to:
  /// **'{user} покинул(а) чат'**
  String chatSystemMemberLeft(String user);

  /// No description provided for @chatSystemTitleChanged.
  ///
  /// In ru, this message translates to:
  /// **'{actor} переименовал(а) чат: {title}'**
  String chatSystemTitleChanged(String actor, String title);

  /// No description provided for @chatSystemGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Служебное сообщение'**
  String get chatSystemGeneric;

  /// No description provided for @chatInfo.
  ///
  /// In ru, this message translates to:
  /// **'Информация'**
  String get chatInfo;

  /// No description provided for @chatMembers.
  ///
  /// In ru, this message translates to:
  /// **'Участники'**
  String get chatMembers;

  /// No description provided for @chatAddMember.
  ///
  /// In ru, this message translates to:
  /// **'Добавить участника'**
  String get chatAddMember;

  /// No description provided for @chatRemoveMember.
  ///
  /// In ru, this message translates to:
  /// **'Удалить из группы'**
  String get chatRemoveMember;

  /// No description provided for @chatLeave.
  ///
  /// In ru, this message translates to:
  /// **'Покинуть группу'**
  String get chatLeave;

  /// No description provided for @chatLeaveConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Вы больше не будете получать сообщения этой группы.'**
  String get chatLeaveConfirm;

  /// No description provided for @chatRename.
  ///
  /// In ru, this message translates to:
  /// **'Переименовать'**
  String get chatRename;

  /// No description provided for @chatRoleOwner.
  ///
  /// In ru, this message translates to:
  /// **'владелец'**
  String get chatRoleOwner;

  /// No description provided for @chatRoleAdmin.
  ///
  /// In ru, this message translates to:
  /// **'админ'**
  String get chatRoleAdmin;

  /// No description provided for @chatRoleMember.
  ///
  /// In ru, this message translates to:
  /// **'участник'**
  String get chatRoleMember;

  /// No description provided for @chatMakeAdmin.
  ///
  /// In ru, this message translates to:
  /// **'Сделать админом'**
  String get chatMakeAdmin;

  /// No description provided for @chatMute.
  ///
  /// In ru, this message translates to:
  /// **'Без звука'**
  String get chatMute;

  /// No description provided for @chatMuteHour.
  ///
  /// In ru, this message translates to:
  /// **'На 1 час'**
  String get chatMuteHour;

  /// No description provided for @chatMuteDay.
  ///
  /// In ru, this message translates to:
  /// **'На 24 часа'**
  String get chatMuteDay;

  /// No description provided for @chatMuteForever.
  ///
  /// In ru, this message translates to:
  /// **'Навсегда'**
  String get chatMuteForever;

  /// No description provided for @chatUnmute.
  ///
  /// In ru, this message translates to:
  /// **'Включить звук'**
  String get chatUnmute;

  /// No description provided for @chatPin.
  ///
  /// In ru, this message translates to:
  /// **'Закрепить'**
  String get chatPin;

  /// No description provided for @chatUnpin.
  ///
  /// In ru, this message translates to:
  /// **'Открепить'**
  String get chatUnpin;

  /// No description provided for @chatArchive.
  ///
  /// In ru, this message translates to:
  /// **'В архив'**
  String get chatArchive;

  /// No description provided for @chatUnarchive.
  ///
  /// In ru, this message translates to:
  /// **'Из архива'**
  String get chatUnarchive;

  /// No description provided for @chatArchived.
  ///
  /// In ru, this message translates to:
  /// **'Архив'**
  String get chatArchived;

  /// No description provided for @chatPinnedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Закреплённое сообщение'**
  String get chatPinnedMessage;

  /// No description provided for @chatPinMessage.
  ///
  /// In ru, this message translates to:
  /// **'Закрепить сообщение'**
  String get chatPinMessage;

  /// No description provided for @chatUnpinMessage.
  ///
  /// In ru, this message translates to:
  /// **'Открепить сообщение'**
  String get chatUnpinMessage;

  /// No description provided for @chatLoadOlder.
  ///
  /// In ru, this message translates to:
  /// **'Загрузить раньше'**
  String get chatLoadOlder;

  /// No description provided for @chatNoMessages.
  ///
  /// In ru, this message translates to:
  /// **'Сообщений пока нет'**
  String get chatNoMessages;

  /// No description provided for @chatToday.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get chatToday;

  /// No description provided for @chatYesterday.
  ///
  /// In ru, this message translates to:
  /// **'Вчера'**
  String get chatYesterday;

  /// No description provided for @chatPrivacySection.
  ///
  /// In ru, this message translates to:
  /// **'Приватность чата'**
  String get chatPrivacySection;

  /// No description provided for @chatPrivacyLastSeen.
  ///
  /// In ru, this message translates to:
  /// **'Показывать «был(а) в сети»'**
  String get chatPrivacyLastSeen;

  /// No description provided for @chatPrivacyOnline.
  ///
  /// In ru, this message translates to:
  /// **'Показывать статус «в сети»'**
  String get chatPrivacyOnline;

  /// No description provided for @chatPrivacyReadReceipts.
  ///
  /// In ru, this message translates to:
  /// **'Отправлять отметки о прочтении'**
  String get chatPrivacyReadReceipts;

  /// No description provided for @chatPrivacyPushPreview.
  ///
  /// In ru, this message translates to:
  /// **'Показывать текст в уведомлениях'**
  String get chatPrivacyPushPreview;

  /// No description provided for @chatCacheStats.
  ///
  /// In ru, this message translates to:
  /// **'Чаты: {chats}, сообщений в кэше: {messages}, в очереди: {outbox}'**
  String chatCacheStats(int chats, int messages, int outbox);

  /// No description provided for @chatMentionHint.
  ///
  /// In ru, this message translates to:
  /// **'Упомянуть'**
  String get chatMentionHint;

  /// No description provided for @chatRateLimited.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много сообщений. Подождите немного.'**
  String get chatRateLimited;

  /// No description provided for @chatFileTooLarge.
  ///
  /// In ru, this message translates to:
  /// **'Файл слишком большой.'**
  String get chatFileTooLarge;

  /// No description provided for @chatFileTypeForbidden.
  ///
  /// In ru, this message translates to:
  /// **'Такой тип файла нельзя отправить.'**
  String get chatFileTypeForbidden;

  /// No description provided for @chatFileInfected.
  ///
  /// In ru, this message translates to:
  /// **'Файл отклонён антивирусом.'**
  String get chatFileInfected;

  /// No description provided for @chatAvUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Антивирус недоступен, попробуйте позже.'**
  String get chatAvUnavailable;

  /// No description provided for @chatMessageTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение слишком длинное.'**
  String get chatMessageTooLong;

  /// No description provided for @chatConversationGone.
  ///
  /// In ru, this message translates to:
  /// **'Чат недоступен.'**
  String get chatConversationGone;

  /// No description provided for @calendarTitle.
  ///
  /// In ru, this message translates to:
  /// **'Календарь'**
  String get calendarTitle;

  /// No description provided for @calendarToday.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get calendarToday;

  /// No description provided for @calendarViewMonth.
  ///
  /// In ru, this message translates to:
  /// **'Месяц'**
  String get calendarViewMonth;

  /// No description provided for @calendarViewWeek.
  ///
  /// In ru, this message translates to:
  /// **'Неделя'**
  String get calendarViewWeek;

  /// No description provided for @calendarViewDay.
  ///
  /// In ru, this message translates to:
  /// **'День'**
  String get calendarViewDay;

  /// No description provided for @calendarViewAgenda.
  ///
  /// In ru, this message translates to:
  /// **'Список'**
  String get calendarViewAgenda;

  /// No description provided for @calendarNoEvents.
  ///
  /// In ru, this message translates to:
  /// **'Нет событий'**
  String get calendarNoEvents;

  /// No description provided for @calendarNoEventsDay.
  ///
  /// In ru, this message translates to:
  /// **'В этот день событий нет'**
  String get calendarNoEventsDay;

  /// No description provided for @calendarAllDay.
  ///
  /// In ru, this message translates to:
  /// **'Весь день'**
  String get calendarAllDay;

  /// No description provided for @calendarOfflineCached.
  ///
  /// In ru, this message translates to:
  /// **'Нет сети — показан сохранённый календарь'**
  String get calendarOfflineCached;

  /// No description provided for @calendarOfflineEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет сети, а этот период ещё не загружен'**
  String get calendarOfflineEmpty;

  /// No description provided for @calendarNoAccess.
  ///
  /// In ru, this message translates to:
  /// **'У вас нет доступа к календарю.'**
  String get calendarNoAccess;

  /// No description provided for @calendarNewEvent.
  ///
  /// In ru, this message translates to:
  /// **'Новое событие'**
  String get calendarNewEvent;

  /// No description provided for @calendarEditEvent.
  ///
  /// In ru, this message translates to:
  /// **'Изменить событие'**
  String get calendarEditEvent;

  /// No description provided for @calendarSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по событиям'**
  String get calendarSearch;

  /// No description provided for @calendarSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Название, место, организатор'**
  String get calendarSearchHint;

  /// No description provided for @calendarSearchEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get calendarSearchEmpty;

  /// No description provided for @calendarSearchCachedOnly.
  ///
  /// In ru, this message translates to:
  /// **'Поиск идёт по загруженным месяцам календаря.'**
  String get calendarSearchCachedOnly;

  /// No description provided for @calendarInvitations.
  ///
  /// In ru, this message translates to:
  /// **'Приглашения'**
  String get calendarInvitations;

  /// No description provided for @calendarInvitationsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет новых приглашений'**
  String get calendarInvitationsEmpty;

  /// No description provided for @calendarPendingSync.
  ///
  /// In ru, this message translates to:
  /// **'Ожидает отправки'**
  String get calendarPendingSync;

  /// No description provided for @calendarSyncing.
  ///
  /// In ru, this message translates to:
  /// **'Обновление…'**
  String get calendarSyncing;

  /// No description provided for @calendarFieldTitle.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get calendarFieldTitle;

  /// No description provided for @calendarFieldTitleRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите название'**
  String get calendarFieldTitleRequired;

  /// No description provided for @calendarFieldTitleTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Слишком длинное название'**
  String get calendarFieldTitleTooLong;

  /// No description provided for @calendarFieldStart.
  ///
  /// In ru, this message translates to:
  /// **'Начало'**
  String get calendarFieldStart;

  /// No description provided for @calendarFieldEnd.
  ///
  /// In ru, this message translates to:
  /// **'Окончание'**
  String get calendarFieldEnd;

  /// No description provided for @calendarFieldEndBeforeStart.
  ///
  /// In ru, this message translates to:
  /// **'Окончание должно быть позже начала'**
  String get calendarFieldEndBeforeStart;

  /// No description provided for @calendarFieldTimezone.
  ///
  /// In ru, this message translates to:
  /// **'Часовой пояс'**
  String get calendarFieldTimezone;

  /// No description provided for @calendarFieldLocation.
  ///
  /// In ru, this message translates to:
  /// **'Место'**
  String get calendarFieldLocation;

  /// No description provided for @calendarFieldLink.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка на встречу'**
  String get calendarFieldLink;

  /// No description provided for @calendarFieldLinkInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Нужна ссылка вида https://…'**
  String get calendarFieldLinkInvalid;

  /// No description provided for @calendarFieldDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get calendarFieldDescription;

  /// No description provided for @calendarFieldCategory.
  ///
  /// In ru, this message translates to:
  /// **'Категория'**
  String get calendarFieldCategory;

  /// No description provided for @calendarFieldPrivate.
  ///
  /// In ru, this message translates to:
  /// **'Личное: описание видно только вам'**
  String get calendarFieldPrivate;

  /// No description provided for @calendarFieldRepeat.
  ///
  /// In ru, this message translates to:
  /// **'Повтор'**
  String get calendarFieldRepeat;

  /// No description provided for @calendarFieldReminders.
  ///
  /// In ru, this message translates to:
  /// **'Напоминания'**
  String get calendarFieldReminders;

  /// No description provided for @calendarFieldParticipants.
  ///
  /// In ru, this message translates to:
  /// **'Участники'**
  String get calendarFieldParticipants;

  /// No description provided for @calendarAddParticipant.
  ///
  /// In ru, this message translates to:
  /// **'Добавить участника'**
  String get calendarAddParticipant;

  /// No description provided for @calendarAddReminder.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get calendarAddReminder;

  /// No description provided for @calendarExternalEmailHint.
  ///
  /// In ru, this message translates to:
  /// **'Email внешнего участника'**
  String get calendarExternalEmailHint;

  /// No description provided for @calendarExternalEmailInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Некорректный email'**
  String get calendarExternalEmailInvalid;

  /// No description provided for @calendarParticipantsUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Справочник коллег недоступен: модуль чата выключен.'**
  String get calendarParticipantsUnavailable;

  /// No description provided for @calendarParticipantsOffline.
  ///
  /// In ru, this message translates to:
  /// **'Участники загрузятся, когда появится сеть.'**
  String get calendarParticipantsOffline;

  /// No description provided for @calendarSearchColleagues.
  ///
  /// In ru, this message translates to:
  /// **'Поиск коллег по имени или email'**
  String get calendarSearchColleagues;

  /// No description provided for @calendarCategoryPersonal.
  ///
  /// In ru, this message translates to:
  /// **'Личное'**
  String get calendarCategoryPersonal;

  /// No description provided for @calendarCategoryMeeting.
  ///
  /// In ru, this message translates to:
  /// **'Встреча'**
  String get calendarCategoryMeeting;

  /// No description provided for @calendarCategoryDepartment.
  ///
  /// In ru, this message translates to:
  /// **'Отдел'**
  String get calendarCategoryDepartment;

  /// No description provided for @calendarCategoryOrganization.
  ///
  /// In ru, this message translates to:
  /// **'Организация'**
  String get calendarCategoryOrganization;

  /// No description provided for @calendarExternal.
  ///
  /// In ru, this message translates to:
  /// **'внешний участник'**
  String get calendarExternal;

  /// No description provided for @calendarRepeatNone.
  ///
  /// In ru, this message translates to:
  /// **'Не повторять'**
  String get calendarRepeatNone;

  /// No description provided for @calendarRepeatDaily.
  ///
  /// In ru, this message translates to:
  /// **'Каждый день'**
  String get calendarRepeatDaily;

  /// No description provided for @calendarRepeatWeekly.
  ///
  /// In ru, this message translates to:
  /// **'Каждую неделю'**
  String get calendarRepeatWeekly;

  /// No description provided for @calendarRepeatMonthly.
  ///
  /// In ru, this message translates to:
  /// **'Каждый месяц'**
  String get calendarRepeatMonthly;

  /// No description provided for @calendarRepeatYearly.
  ///
  /// In ru, this message translates to:
  /// **'Каждый год'**
  String get calendarRepeatYearly;

  /// No description provided for @calendarRepeatEveryDays.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Каждый {count} день} few{Каждые {count} дня} many{Каждые {count} дней} other{Каждые {count} дня}}'**
  String calendarRepeatEveryDays(int count);

  /// No description provided for @calendarRepeatEveryWeeks.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Каждую {count} неделю} few{Каждые {count} недели} many{Каждые {count} недель} other{Каждые {count} недели}}'**
  String calendarRepeatEveryWeeks(int count);

  /// No description provided for @calendarRepeatEveryMonths.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Каждый {count} месяц} few{Каждые {count} месяца} many{Каждые {count} месяцев} other{Каждые {count} месяца}}'**
  String calendarRepeatEveryMonths(int count);

  /// No description provided for @calendarRepeatEveryYears.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Каждый {count} год} few{Каждые {count} года} many{Каждые {count} лет} other{Каждые {count} года}}'**
  String calendarRepeatEveryYears(int count);

  /// No description provided for @calendarRepeatInterval.
  ///
  /// In ru, this message translates to:
  /// **'Интервал'**
  String get calendarRepeatInterval;

  /// No description provided for @calendarRepeatEnds.
  ///
  /// In ru, this message translates to:
  /// **'Окончание повтора'**
  String get calendarRepeatEnds;

  /// No description provided for @calendarRepeatEndsNever.
  ///
  /// In ru, this message translates to:
  /// **'Никогда'**
  String get calendarRepeatEndsNever;

  /// No description provided for @calendarRepeatEndsOn.
  ///
  /// In ru, this message translates to:
  /// **'До даты'**
  String get calendarRepeatEndsOn;

  /// No description provided for @calendarRepeatEndsAfter.
  ///
  /// In ru, this message translates to:
  /// **'После нескольких повторов'**
  String get calendarRepeatEndsAfter;

  /// No description provided for @calendarRepeatUntil.
  ///
  /// In ru, this message translates to:
  /// **'до {date}'**
  String calendarRepeatUntil(String date);

  /// No description provided for @calendarRepeatTimes.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} раз} few{{count} раза} many{{count} раз} other{{count} раза}}'**
  String calendarRepeatTimes(int count);

  /// No description provided for @calendarRepeatCustom.
  ///
  /// In ru, this message translates to:
  /// **'Особое правило повтора'**
  String get calendarRepeatCustom;

  /// No description provided for @calendarRepeatServerNote.
  ///
  /// In ru, this message translates to:
  /// **'Сервер хранит окончание серии, но веб-почта пока показывает такие серии бесконечными.'**
  String get calendarRepeatServerNote;

  /// No description provided for @calendarDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get calendarDone;

  /// No description provided for @calendarReminderAtStart.
  ///
  /// In ru, this message translates to:
  /// **'В момент начала'**
  String get calendarReminderAtStart;

  /// No description provided for @calendarReminderMinutes.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{За {count} минуту} few{За {count} минуты} many{За {count} минут} other{За {count} минуты}}'**
  String calendarReminderMinutes(int count);

  /// No description provided for @calendarReminderHours.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{За {count} час} few{За {count} часа} many{За {count} часов} other{За {count} часа}}'**
  String calendarReminderHours(int count);

  /// No description provided for @calendarReminderDays.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{За {count} день} few{За {count} дня} many{За {count} дней} other{За {count} дня}}'**
  String calendarReminderDays(int count);

  /// No description provided for @calendarReminderLocalNote.
  ///
  /// In ru, this message translates to:
  /// **'Первое напоминание получат и участники; остальные сработают только на этом устройстве.'**
  String get calendarReminderLocalNote;

  /// No description provided for @calendarReminderChannel.
  ///
  /// In ru, this message translates to:
  /// **'Напоминания календаря'**
  String get calendarReminderChannel;

  /// No description provided for @calendarReminderChannelDescription.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления перед началом событий'**
  String get calendarReminderChannelDescription;

  /// No description provided for @calendarOrganizer.
  ///
  /// In ru, this message translates to:
  /// **'Организатор: {name}'**
  String calendarOrganizer(String name);

  /// No description provided for @calendarYourAnswer.
  ///
  /// In ru, this message translates to:
  /// **'Ваш ответ'**
  String get calendarYourAnswer;

  /// No description provided for @calendarRsvpAccept.
  ///
  /// In ru, this message translates to:
  /// **'Приду'**
  String get calendarRsvpAccept;

  /// No description provided for @calendarRsvpTentative.
  ///
  /// In ru, this message translates to:
  /// **'Возможно'**
  String get calendarRsvpTentative;

  /// No description provided for @calendarRsvpDecline.
  ///
  /// In ru, this message translates to:
  /// **'Не приду'**
  String get calendarRsvpDecline;

  /// No description provided for @calendarRsvpPending.
  ///
  /// In ru, this message translates to:
  /// **'Не ответил'**
  String get calendarRsvpPending;

  /// No description provided for @calendarRsvpAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Принял'**
  String get calendarRsvpAccepted;

  /// No description provided for @calendarRsvpTentativeStatus.
  ///
  /// In ru, this message translates to:
  /// **'Под вопросом'**
  String get calendarRsvpTentativeStatus;

  /// No description provided for @calendarRsvpDeclined.
  ///
  /// In ru, this message translates to:
  /// **'Отклонил'**
  String get calendarRsvpDeclined;

  /// No description provided for @calendarRsvpSummary.
  ///
  /// In ru, this message translates to:
  /// **'Придут: {accepted} · Под вопросом: {tentative} · Отказались: {declined} · Не ответили: {pending}'**
  String calendarRsvpSummary(
    int accepted,
    int tentative,
    int declined,
    int pending,
  );

  /// No description provided for @calendarMandatory.
  ///
  /// In ru, this message translates to:
  /// **'Обязательное событие'**
  String get calendarMandatory;

  /// No description provided for @calendarMandatoryCannotDecline.
  ///
  /// In ru, this message translates to:
  /// **'От обязательного события нельзя отказаться.'**
  String get calendarMandatoryCannotDecline;

  /// No description provided for @calendarJoinCall.
  ///
  /// In ru, this message translates to:
  /// **'Присоединиться к звонку'**
  String get calendarJoinCall;

  /// No description provided for @calendarJoinCallSoon.
  ///
  /// In ru, this message translates to:
  /// **'Подключение к звонку из календаря появится в модуле звонков.'**
  String get calendarJoinCallSoon;

  /// No description provided for @calendarEventTimeInZone.
  ///
  /// In ru, this message translates to:
  /// **'{time} по времени {zone}'**
  String calendarEventTimeInZone(String time, String zone);

  /// No description provided for @calendarDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get calendarDelete;

  /// No description provided for @calendarEdit.
  ///
  /// In ru, this message translates to:
  /// **'Изменить'**
  String get calendarEdit;

  /// No description provided for @calendarSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get calendarSave;

  /// No description provided for @calendarDeleteConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить событие? Участники получат уведомление об отмене.'**
  String get calendarDeleteConfirm;

  /// No description provided for @calendarScopeTitleEdit.
  ///
  /// In ru, this message translates to:
  /// **'Изменить повторяющееся событие'**
  String get calendarScopeTitleEdit;

  /// No description provided for @calendarScopeTitleDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить повторяющееся событие'**
  String get calendarScopeTitleDelete;

  /// No description provided for @calendarScopeThis.
  ///
  /// In ru, this message translates to:
  /// **'Только это событие'**
  String get calendarScopeThis;

  /// No description provided for @calendarScopeFollowing.
  ///
  /// In ru, this message translates to:
  /// **'Это и последующие'**
  String get calendarScopeFollowing;

  /// No description provided for @calendarScopeAll.
  ///
  /// In ru, this message translates to:
  /// **'Все события серии'**
  String get calendarScopeAll;

  /// No description provided for @calendarRecreateWarning.
  ///
  /// In ru, this message translates to:
  /// **'Это изменение нельзя внести в существующее событие: оно будет отменено и создано заново, участники получат новое приглашение.'**
  String get calendarRecreateWarning;

  /// No description provided for @calendarContinue.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get calendarContinue;

  /// No description provided for @calendarEventNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Событие не найдено или недоступно.'**
  String get calendarEventNotFound;

  /// No description provided for @calendarNotOrganizer.
  ///
  /// In ru, this message translates to:
  /// **'Изменять событие может только организатор.'**
  String get calendarNotOrganizer;

  /// No description provided for @calendarCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменено'**
  String get calendarCancelled;

  /// No description provided for @calendarProblemsBanner.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} изменение не отправлено} few{{count} изменения не отправлены} many{{count} изменений не отправлено} other{{count} изменения не отправлены}}'**
  String calendarProblemsBanner(int count);

  /// No description provided for @calendarConflictTitle.
  ///
  /// In ru, this message translates to:
  /// **'Событие изменено на другом устройстве'**
  String get calendarConflictTitle;

  /// No description provided for @calendarConflictBody.
  ///
  /// In ru, this message translates to:
  /// **'Применить ваши изменения поверх новой версии или отменить их?'**
  String get calendarConflictBody;

  /// No description provided for @calendarConflictOverwrite.
  ///
  /// In ru, this message translates to:
  /// **'Применить мои'**
  String get calendarConflictOverwrite;

  /// No description provided for @calendarDiscard.
  ///
  /// In ru, this message translates to:
  /// **'Отменить изменения'**
  String get calendarDiscard;

  /// No description provided for @calendarProblemFailed.
  ///
  /// In ru, this message translates to:
  /// **'Изменение отклонено: {reason}'**
  String calendarProblemFailed(String reason);

  /// No description provided for @calendarErrTitle.
  ///
  /// In ru, this message translates to:
  /// **'Название пустое или слишком длинное (не более 300 байт).'**
  String get calendarErrTitle;

  /// No description provided for @calendarErrTime.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте время начала и окончания.'**
  String get calendarErrTime;

  /// No description provided for @calendarErrLink.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка на встречу должна начинаться с https://.'**
  String get calendarErrLink;

  /// No description provided for @calendarErrTimezone.
  ///
  /// In ru, this message translates to:
  /// **'Неизвестный часовой пояс.'**
  String get calendarErrTimezone;

  /// No description provided for @calendarErrAudience.
  ///
  /// In ru, this message translates to:
  /// **'Некоторые участники не из вашей организации.'**
  String get calendarErrAudience;

  /// No description provided for @calendarErrRoom.
  ///
  /// In ru, this message translates to:
  /// **'Переговорная занята в это время.'**
  String get calendarErrRoom;

  /// No description provided for @calendarErrMeetingsDisabled.
  ///
  /// In ru, this message translates to:
  /// **'В организации отключено создание встреч с участниками.'**
  String get calendarErrMeetingsDisabled;

  /// No description provided for @calendarErrTooManyOccurrences.
  ///
  /// In ru, this message translates to:
  /// **'У серии слишком много повторов: сервер не умеет завершать серию, поэтому «это и последующие» недоступно. Удалите серию целиком или отдельные события.'**
  String get calendarErrTooManyOccurrences;

  /// No description provided for @calendarErrOffline.
  ///
  /// In ru, this message translates to:
  /// **'Нужна сеть: данные серии ещё не загружены.'**
  String get calendarErrOffline;

  /// No description provided for @calendarErrSending.
  ///
  /// In ru, this message translates to:
  /// **'Событие отправляется — попробуйте через минуту.'**
  String get calendarErrSending;

  /// No description provided for @calendarErrScope.
  ///
  /// In ru, this message translates to:
  /// **'Это изменение нельзя применить к одному событию серии.'**
  String get calendarErrScope;

  /// No description provided for @calendarErrOverride.
  ///
  /// In ru, this message translates to:
  /// **'Сервер не вернул перенесённое событие — обновите календарь.'**
  String get calendarErrOverride;

  /// No description provided for @callsFilterAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get callsFilterAll;

  /// No description provided for @callsFilterMissed.
  ///
  /// In ru, this message translates to:
  /// **'Пропущенные'**
  String get callsFilterMissed;

  /// No description provided for @callsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Звонков пока нет'**
  String get callsEmpty;

  /// No description provided for @callsMissedEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Пропущенных звонков нет'**
  String get callsMissedEmpty;

  /// No description provided for @callsNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый звонок'**
  String get callsNew;

  /// No description provided for @callsAudio.
  ///
  /// In ru, this message translates to:
  /// **'Аудиозвонок'**
  String get callsAudio;

  /// No description provided for @callsVideo.
  ///
  /// In ru, this message translates to:
  /// **'Видеозвонок'**
  String get callsVideo;

  /// No description provided for @callsDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Звонки недоступны: сервис звонков не настроен.'**
  String get callsDisabled;

  /// No description provided for @callsIncoming.
  ///
  /// In ru, this message translates to:
  /// **'Входящий звонок'**
  String get callsIncoming;

  /// No description provided for @callsIncomingVideo.
  ///
  /// In ru, this message translates to:
  /// **'Входящий видеозвонок'**
  String get callsIncomingVideo;

  /// No description provided for @callsCalling.
  ///
  /// In ru, this message translates to:
  /// **'Вызов…'**
  String get callsCalling;

  /// No description provided for @callsConnecting.
  ///
  /// In ru, this message translates to:
  /// **'Соединение…'**
  String get callsConnecting;

  /// No description provided for @callsReconnecting.
  ///
  /// In ru, this message translates to:
  /// **'Восстанавливаем связь…'**
  String get callsReconnecting;

  /// No description provided for @callsAccept.
  ///
  /// In ru, this message translates to:
  /// **'Ответить'**
  String get callsAccept;

  /// No description provided for @callsDecline.
  ///
  /// In ru, this message translates to:
  /// **'Отклонить'**
  String get callsDecline;

  /// No description provided for @callsHangUp.
  ///
  /// In ru, this message translates to:
  /// **'Завершить'**
  String get callsHangUp;

  /// No description provided for @callsEndForAll.
  ///
  /// In ru, this message translates to:
  /// **'Завершить для всех'**
  String get callsEndForAll;

  /// No description provided for @callsLeave.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из звонка'**
  String get callsLeave;

  /// No description provided for @callsMic.
  ///
  /// In ru, this message translates to:
  /// **'Микрофон'**
  String get callsMic;

  /// No description provided for @callsCamera.
  ///
  /// In ru, this message translates to:
  /// **'Камера'**
  String get callsCamera;

  /// No description provided for @callsSwitchCamera.
  ///
  /// In ru, this message translates to:
  /// **'Сменить камеру'**
  String get callsSwitchCamera;

  /// No description provided for @callsCameraUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось включить камеру'**
  String get callsCameraUnavailable;

  /// No description provided for @callsSpeaker.
  ///
  /// In ru, this message translates to:
  /// **'Динамик'**
  String get callsSpeaker;

  /// No description provided for @callsAudioOutput.
  ///
  /// In ru, this message translates to:
  /// **'Аудиовыход'**
  String get callsAudioOutput;

  /// No description provided for @callsAudioSettings.
  ///
  /// In ru, this message translates to:
  /// **'Звук'**
  String get callsAudioSettings;

  /// No description provided for @callsAudioEarpiece.
  ///
  /// In ru, this message translates to:
  /// **'Телефон (у уха)'**
  String get callsAudioEarpiece;

  /// No description provided for @callsAudioWired.
  ///
  /// In ru, this message translates to:
  /// **'Проводные наушники'**
  String get callsAudioWired;

  /// No description provided for @callsAudioBluetooth.
  ///
  /// In ru, this message translates to:
  /// **'Bluetooth'**
  String get callsAudioBluetooth;

  /// No description provided for @callsScreenShare.
  ///
  /// In ru, this message translates to:
  /// **'Экран'**
  String get callsScreenShare;

  /// No description provided for @callsScreenShareRefused.
  ///
  /// In ru, this message translates to:
  /// **'Демонстрация экрана не разрешена.'**
  String get callsScreenShareRefused;

  /// No description provided for @callsScreenShareNotification.
  ///
  /// In ru, this message translates to:
  /// **'Идёт демонстрация экрана в XatBox'**
  String get callsScreenShareNotification;

  /// No description provided for @callsParticipants.
  ///
  /// In ru, this message translates to:
  /// **'Участники'**
  String get callsParticipants;

  /// No description provided for @callsModMute.
  ///
  /// In ru, this message translates to:
  /// **'Выключить микрофон'**
  String get callsModMute;

  /// No description provided for @callsModRemove.
  ///
  /// In ru, this message translates to:
  /// **'Удалить из звонка'**
  String get callsModRemove;

  /// No description provided for @callsMakeModerator.
  ///
  /// In ru, this message translates to:
  /// **'Сделать модератором'**
  String get callsMakeModerator;

  /// No description provided for @callsHost.
  ///
  /// In ru, this message translates to:
  /// **'организатор'**
  String get callsHost;

  /// No description provided for @callsModerator.
  ///
  /// In ru, this message translates to:
  /// **'модератор'**
  String get callsModerator;

  /// No description provided for @callsYou.
  ///
  /// In ru, this message translates to:
  /// **'Вы'**
  String get callsYou;

  /// No description provided for @callsRedial.
  ///
  /// In ru, this message translates to:
  /// **'Перезвонить'**
  String get callsRedial;

  /// No description provided for @callsEndedHangup.
  ///
  /// In ru, this message translates to:
  /// **'Звонок завершён'**
  String get callsEndedHangup;

  /// No description provided for @callsEndedDeclined.
  ///
  /// In ru, this message translates to:
  /// **'Звонок отклонён'**
  String get callsEndedDeclined;

  /// No description provided for @callsEndedBusy.
  ///
  /// In ru, this message translates to:
  /// **'Абонент занят'**
  String get callsEndedBusy;

  /// No description provided for @callsEndedMissed.
  ///
  /// In ru, this message translates to:
  /// **'Нет ответа'**
  String get callsEndedMissed;

  /// No description provided for @callsEndedCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Звонок отменён'**
  String get callsEndedCancelled;

  /// No description provided for @callsEndedFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось соединиться'**
  String get callsEndedFailed;

  /// No description provided for @callsEndedNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Нет сети — звонок невозможен'**
  String get callsEndedNetwork;

  /// No description provided for @callsEndedElsewhere.
  ///
  /// In ru, this message translates to:
  /// **'Отвечено на другом устройстве'**
  String get callsEndedElsewhere;

  /// No description provided for @callsEndedRemoved.
  ///
  /// In ru, this message translates to:
  /// **'Модератор удалил вас из звонка'**
  String get callsEndedRemoved;

  /// No description provided for @callsPermissionNeeded.
  ///
  /// In ru, this message translates to:
  /// **'Без доступа к микрофону звонок невозможен (для видео нужна и камера). Разрешите доступ, чтобы позвонить.'**
  String get callsPermissionNeeded;

  /// No description provided for @callsQualityPoor.
  ///
  /// In ru, this message translates to:
  /// **'Слабая связь'**
  String get callsQualityPoor;

  /// No description provided for @callsQualityLost.
  ///
  /// In ru, this message translates to:
  /// **'Связь потеряна'**
  String get callsQualityLost;

  /// No description provided for @callsOutcomeMissed.
  ///
  /// In ru, this message translates to:
  /// **'Пропущенный'**
  String get callsOutcomeMissed;

  /// No description provided for @callsOutcomeDeclined.
  ///
  /// In ru, this message translates to:
  /// **'Отклонён'**
  String get callsOutcomeDeclined;

  /// No description provided for @callsOutcomeCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменён'**
  String get callsOutcomeCancelled;

  /// No description provided for @callsOutcomeBusy.
  ///
  /// In ru, this message translates to:
  /// **'Занято'**
  String get callsOutcomeBusy;

  /// No description provided for @callsOutcomeFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не состоялся'**
  String get callsOutcomeFailed;

  /// No description provided for @callsOutgoing.
  ///
  /// In ru, this message translates to:
  /// **'Исходящий'**
  String get callsOutgoing;

  /// No description provided for @callsIncomingShort.
  ///
  /// In ru, this message translates to:
  /// **'Входящий'**
  String get callsIncomingShort;

  /// No description provided for @callsActiveBanner.
  ///
  /// In ru, this message translates to:
  /// **'Идёт звонок — нажмите, чтобы вернуться'**
  String get callsActiveBanner;

  /// No description provided for @callsIncomingChannel.
  ///
  /// In ru, this message translates to:
  /// **'Входящие звонки'**
  String get callsIncomingChannel;

  /// No description provided for @callsMissedChannel.
  ///
  /// In ru, this message translates to:
  /// **'Пропущенные звонки'**
  String get callsMissedChannel;

  /// No description provided for @callsSelectPeople.
  ///
  /// In ru, this message translates to:
  /// **'Выберите одного коллегу или нескольких для группового звонка'**
  String get callsSelectPeople;

  /// No description provided for @callsParticipantsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} участник} few{{count} участника} many{{count} участников} other{{count} участника}}'**
  String callsParticipantsCount(int count);

  /// No description provided for @callsErrNotModerator.
  ///
  /// In ru, this message translates to:
  /// **'Это действие доступно только модератору.'**
  String get callsErrNotModerator;

  /// No description provided for @callsErrAlreadyInCall.
  ///
  /// In ru, this message translates to:
  /// **'Вы уже участвуете в другом звонке.'**
  String get callsErrAlreadyInCall;

  /// No description provided for @callsErrTooMany.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много участников для звонка.'**
  String get callsErrTooMany;

  /// No description provided for @callsErrInvalidParticipants.
  ///
  /// In ru, this message translates to:
  /// **'Некоторые участники недоступны для звонка.'**
  String get callsErrInvalidParticipants;

  /// No description provided for @callsErrRateLimited.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много звонков подряд. Подождите немного.'**
  String get callsErrRateLimited;

  /// No description provided for @appOfflineBanner.
  ///
  /// In ru, this message translates to:
  /// **'Нет подключения к сети'**
  String get appOfflineBanner;

  /// No description provided for @appSizeBytes.
  ///
  /// In ru, this message translates to:
  /// **'{value} Б'**
  String appSizeBytes(String value);

  /// No description provided for @appSizeKb.
  ///
  /// In ru, this message translates to:
  /// **'{value} КБ'**
  String appSizeKb(String value);

  /// No description provided for @appSizeMb.
  ///
  /// In ru, this message translates to:
  /// **'{value} МБ'**
  String appSizeMb(String value);

  /// No description provided for @appSizeGb.
  ///
  /// In ru, this message translates to:
  /// **'{value} ГБ'**
  String appSizeGb(String value);

  /// No description provided for @settingsAppearanceSection.
  ///
  /// In ru, this message translates to:
  /// **'Оформление'**
  String get settingsAppearanceSection;

  /// No description provided for @settingsTheme.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Как в системе'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In ru, this message translates to:
  /// **'Как в системе'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageRu.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get settingsLanguageRu;

  /// No description provided for @settingsLanguageKk.
  ///
  /// In ru, this message translates to:
  /// **'Қазақша'**
  String get settingsLanguageKk;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In ru, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @mailSortSender.
  ///
  /// In ru, this message translates to:
  /// **'Папка для отправителя'**
  String get mailSortSender;

  /// No description provided for @mailSortSenderHint.
  ///
  /// In ru, this message translates to:
  /// **'Письма от {sender} будут собираться в выбранную папку.'**
  String mailSortSenderHint(String sender);

  /// No description provided for @mailSortSenderIncludeExisting.
  ///
  /// In ru, this message translates to:
  /// **'Перенести уже полученные письма'**
  String get mailSortSenderIncludeExisting;

  /// No description provided for @mailSenderSorted.
  ///
  /// In ru, this message translates to:
  /// **'Отправитель добавлен в «{name}»'**
  String mailSenderSorted(String name);

  /// No description provided for @mailSortSenderNoFolders.
  ///
  /// In ru, this message translates to:
  /// **'Сначала создайте умную папку во «Входящих».'**
  String get mailSortSenderNoFolders;

  /// No description provided for @settingsSecurityChangePassword.
  ///
  /// In ru, this message translates to:
  /// **'Сменить пароль'**
  String get settingsSecurityChangePassword;

  /// No description provided for @settingsSecurityChangePasswordHint.
  ///
  /// In ru, this message translates to:
  /// **'Не короче 10 символов. После смены другие сессии продолжают работать — завершите их ниже, если нужно.'**
  String get settingsSecurityChangePasswordHint;

  /// No description provided for @settingsCurrentPassword.
  ///
  /// In ru, this message translates to:
  /// **'Текущий пароль'**
  String get settingsCurrentPassword;

  /// No description provided for @settingsNewPassword.
  ///
  /// In ru, this message translates to:
  /// **'Новый пароль (не короче 10 символов)'**
  String get settingsNewPassword;

  /// No description provided for @settingsRepeatPassword.
  ///
  /// In ru, this message translates to:
  /// **'Повторите новый пароль'**
  String get settingsRepeatPassword;

  /// No description provided for @settingsPasswordsMismatch.
  ///
  /// In ru, this message translates to:
  /// **'Пароли не совпадают'**
  String get settingsPasswordsMismatch;

  /// No description provided for @settingsPasswordChanged.
  ///
  /// In ru, this message translates to:
  /// **'Пароль изменён'**
  String get settingsPasswordChanged;

  /// No description provided for @settingsPasswordTooShort.
  ///
  /// In ru, this message translates to:
  /// **'Не короче 10 символов'**
  String get settingsPasswordTooShort;

  /// No description provided for @mailSettingsClients.
  ///
  /// In ru, this message translates to:
  /// **'Почтовые клиенты'**
  String get mailSettingsClients;

  /// No description provided for @mailSettingsClientsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'IMAP/SMTP для Outlook, Thunderbird и других'**
  String get mailSettingsClientsSubtitle;

  /// No description provided for @mailClientsHint.
  ///
  /// In ru, this message translates to:
  /// **'Параметры подключения для сторонних почтовых программ.'**
  String get mailClientsHint;

  /// No description provided for @mailClientsIncoming.
  ///
  /// In ru, this message translates to:
  /// **'Входящая · IMAP'**
  String get mailClientsIncoming;

  /// No description provided for @mailClientsOutgoing.
  ///
  /// In ru, this message translates to:
  /// **'Исходящая · SMTP'**
  String get mailClientsOutgoing;

  /// No description provided for @mailClientsUsername.
  ///
  /// In ru, this message translates to:
  /// **'Имя пользователя'**
  String get mailClientsUsername;

  /// No description provided for @mailClientsDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Доступ по IMAP/SMTP отключён администратором.'**
  String get mailClientsDisabled;

  /// No description provided for @mailClientsEnabled.
  ///
  /// In ru, this message translates to:
  /// **'Включено'**
  String get mailClientsEnabled;

  /// No description provided for @mailClientsDisabledBadge.
  ///
  /// In ru, this message translates to:
  /// **'Отключено'**
  String get mailClientsDisabledBadge;

  /// No description provided for @profileChangePhoto.
  ///
  /// In ru, this message translates to:
  /// **'Сменить фото'**
  String get profileChangePhoto;

  /// No description provided for @profileRemovePhoto.
  ///
  /// In ru, this message translates to:
  /// **'Удалить фото'**
  String get profileRemovePhoto;

  /// No description provided for @profilePhotoUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Фото обновлено'**
  String get profilePhotoUpdated;

  /// No description provided for @profilePhotoHint.
  ///
  /// In ru, this message translates to:
  /// **'Фото видят коллеги в почте, чате и каталоге.'**
  String get profilePhotoHint;

  /// No description provided for @profileRole.
  ///
  /// In ru, this message translates to:
  /// **'Роль'**
  String get profileRole;

  /// No description provided for @profileAdministrator.
  ///
  /// In ru, this message translates to:
  /// **'Администратор'**
  String get profileAdministrator;

  /// No description provided for @profileMember.
  ///
  /// In ru, this message translates to:
  /// **'Сотрудник'**
  String get profileMember;

  /// No description provided for @mailQuickReplyTo.
  ///
  /// In ru, this message translates to:
  /// **'Ответить: {name}'**
  String mailQuickReplyTo(String name);

  /// No description provided for @mailQuickReplyAll.
  ///
  /// In ru, this message translates to:
  /// **'Ответить всем · {count}'**
  String mailQuickReplyAll(int count);

  /// No description provided for @mailQuickReplyHint.
  ///
  /// In ru, this message translates to:
  /// **'Напишите ответ…'**
  String get mailQuickReplyHint;

  /// No description provided for @mailQuickReplySent.
  ///
  /// In ru, this message translates to:
  /// **'Ответ отправлен'**
  String get mailQuickReplySent;

  /// No description provided for @mailQuickReplyOpenComposer.
  ///
  /// In ru, this message translates to:
  /// **'Открыть в редакторе'**
  String get mailQuickReplyOpenComposer;

  /// No description provided for @mailQuickReplyAnother.
  ///
  /// In ru, this message translates to:
  /// **'Написать ещё'**
  String get mailQuickReplyAnother;

  /// No description provided for @mailQuickReplyViewSent.
  ///
  /// In ru, this message translates to:
  /// **'В отправленные'**
  String get mailQuickReplyViewSent;

  /// No description provided for @mailQuickReplySwitchAll.
  ///
  /// In ru, this message translates to:
  /// **'Всем'**
  String get mailQuickReplySwitchAll;

  /// No description provided for @mailQuickReplySwitchOne.
  ///
  /// In ru, this message translates to:
  /// **'Только отправителю'**
  String get mailQuickReplySwitchOne;

  /// No description provided for @mailRemindMe.
  ///
  /// In ru, this message translates to:
  /// **'Напомнить'**
  String get mailRemindMe;

  /// No description provided for @mailRemindLaterToday.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня позже'**
  String get mailRemindLaterToday;

  /// No description provided for @mailRemindTomorrow.
  ///
  /// In ru, this message translates to:
  /// **'Завтра утром'**
  String get mailRemindTomorrow;

  /// No description provided for @mailRemindNextWeek.
  ///
  /// In ru, this message translates to:
  /// **'На следующей неделе'**
  String get mailRemindNextWeek;

  /// No description provided for @mailReminderCreated.
  ///
  /// In ru, this message translates to:
  /// **'Напоминание создано'**
  String get mailReminderCreated;

  /// No description provided for @mailAddToTasks.
  ///
  /// In ru, this message translates to:
  /// **'В задачи'**
  String get mailAddToTasks;

  /// No description provided for @mailAddedToTasks.
  ///
  /// In ru, this message translates to:
  /// **'Задача создана'**
  String get mailAddedToTasks;

  /// No description provided for @mailHideList.
  ///
  /// In ru, this message translates to:
  /// **'Скрыть список'**
  String get mailHideList;

  /// No description provided for @mailShowList.
  ///
  /// In ru, this message translates to:
  /// **'Показать список'**
  String get mailShowList;

  /// No description provided for @mailMoveToInbox.
  ///
  /// In ru, this message translates to:
  /// **'Во входящие'**
  String get mailMoveToInbox;

  /// No description provided for @mailExternalSender.
  ///
  /// In ru, this message translates to:
  /// **'Внешний отправитель'**
  String get mailExternalSender;

  /// No description provided for @mailRecipientsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} получатель} few{{count} получателя} other{{count} получателей}}'**
  String mailRecipientsCount(int count);

  /// No description provided for @mailConversation.
  ///
  /// In ru, this message translates to:
  /// **'Переписка'**
  String get mailConversation;

  /// No description provided for @mailConversationHistory.
  ///
  /// In ru, this message translates to:
  /// **'история переписки'**
  String get mailConversationHistory;

  /// No description provided for @mailThreadCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} сообщение} few{{count} сообщения} other{{count} сообщений}}'**
  String mailThreadCount(int count);

  /// No description provided for @mailLookalikeWarning.
  ///
  /// In ru, this message translates to:
  /// **'Домен отправителя похож на ваш, но отличается. Возможно, это подделка — проверьте адрес перед ответом.'**
  String get mailLookalikeWarning;

  /// No description provided for @mailAttachmentsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} вложение} few{{count} вложения} other{{count} вложений}}'**
  String mailAttachmentsCount(int count);

  /// No description provided for @mailOpenMessage.
  ///
  /// In ru, this message translates to:
  /// **'Открыть письмо'**
  String get mailOpenMessage;

  /// No description provided for @mailRoleStart.
  ///
  /// In ru, this message translates to:
  /// **'Начало'**
  String get mailRoleStart;

  /// No description provided for @mailRoleReply.
  ///
  /// In ru, this message translates to:
  /// **'Ответ'**
  String get mailRoleReply;

  /// No description provided for @mailRoleLatest.
  ///
  /// In ru, this message translates to:
  /// **'Последнее'**
  String get mailRoleLatest;

  /// No description provided for @mailRoleCurrent.
  ///
  /// In ru, this message translates to:
  /// **'Это письмо'**
  String get mailRoleCurrent;

  /// No description provided for @mailEditSend.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать и отправить'**
  String get mailEditSend;

  /// No description provided for @mailCopyAddress.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать адрес'**
  String get mailCopyAddress;

  /// No description provided for @mailAddressCopied.
  ///
  /// In ru, this message translates to:
  /// **'Адрес скопирован'**
  String get mailAddressCopied;

  /// No description provided for @mailSaveToBookmarkFolder.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить в папку закладок'**
  String get mailSaveToBookmarkFolder;

  /// No description provided for @mailCreateBookmarkFolderFirst.
  ///
  /// In ru, this message translates to:
  /// **'Сначала создайте папку закладок'**
  String get mailCreateBookmarkFolderFirst;

  /// No description provided for @mailSavedToFolder.
  ///
  /// In ru, this message translates to:
  /// **'Сохранено в «{name}»'**
  String mailSavedToFolder(String name);

  /// No description provided for @mailMoreActions.
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get mailMoreActions;

  /// No description provided for @mailDownload.
  ///
  /// In ru, this message translates to:
  /// **'Скачать'**
  String get mailDownload;

  /// No description provided for @mailPreview.
  ///
  /// In ru, this message translates to:
  /// **'Открыть'**
  String get mailPreview;

  /// No description provided for @mailRefresh.
  ///
  /// In ru, this message translates to:
  /// **'Обновить почту'**
  String get mailRefresh;

  /// No description provided for @mailRefreshed.
  ///
  /// In ru, this message translates to:
  /// **'Почта обновлена'**
  String get mailRefreshed;

  /// No description provided for @mailNewFolder.
  ///
  /// In ru, this message translates to:
  /// **'Новая папка'**
  String get mailNewFolder;

  /// No description provided for @mailCreateFirstFolder.
  ///
  /// In ru, this message translates to:
  /// **'Создать первую папку'**
  String get mailCreateFirstFolder;

  /// No description provided for @mailNewBookmarkFolder.
  ///
  /// In ru, this message translates to:
  /// **'Новая папка закладок'**
  String get mailNewBookmarkFolder;

  /// No description provided for @mailCreateFirstBookmarkFolder.
  ///
  /// In ru, this message translates to:
  /// **'Создать папку закладок'**
  String get mailCreateFirstBookmarkFolder;

  /// No description provided for @mailFolderName.
  ///
  /// In ru, this message translates to:
  /// **'Название папки'**
  String get mailFolderName;

  /// No description provided for @mailFolderNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: Бухгалтерия'**
  String get mailFolderNameHint;

  /// No description provided for @mailFolderModalHint.
  ///
  /// In ru, this message translates to:
  /// **'Умная папка собирает письма выбранных отправителей.'**
  String get mailFolderModalHint;

  /// No description provided for @mailBookmarkModalHint.
  ///
  /// In ru, this message translates to:
  /// **'Папка закладок хранит письма, которые вы отметили.'**
  String get mailBookmarkModalHint;

  /// No description provided for @mailFolderCreated.
  ///
  /// In ru, this message translates to:
  /// **'Папка создана'**
  String get mailFolderCreated;

  /// No description provided for @mailBookmarkFolderCreated.
  ///
  /// In ru, this message translates to:
  /// **'Папка закладок создана'**
  String get mailBookmarkFolderCreated;

  /// No description provided for @mailCreating.
  ///
  /// In ru, this message translates to:
  /// **'Создание…'**
  String get mailCreating;

  /// No description provided for @sectionMail.
  ///
  /// In ru, this message translates to:
  /// **'Почта'**
  String get sectionMail;

  /// No description provided for @sectionWorkspace.
  ///
  /// In ru, this message translates to:
  /// **'Рабочее место'**
  String get sectionWorkspace;

  /// No description provided for @mailSelectAll.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать все'**
  String get mailSelectAll;

  /// No description provided for @mailSelectMessage.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать письмо'**
  String get mailSelectMessage;

  /// No description provided for @mailSelectedCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Выбрано {count} письмо} few{Выбрано {count} письма} other{Выбрано {count} писем}}'**
  String mailSelectedCount(int count);

  /// No description provided for @mailUndo.
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get mailUndo;

  /// No description provided for @mailThreadYou.
  ///
  /// In ru, this message translates to:
  /// **'Вы'**
  String get mailThreadYou;

  /// No description provided for @mailReplyBadge.
  ///
  /// In ru, this message translates to:
  /// **'Ответ'**
  String get mailReplyBadge;

  /// No description provided for @mailMessagesTotal.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} письмо} few{{count} письма} other{{count} писем}}'**
  String mailMessagesTotal(int count);

  /// No description provided for @mailSendersTotal.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} отправитель} few{{count} отправителя} other{{count} отправителей}}'**
  String mailSendersTotal(int count);

  /// No description provided for @mailUnreadLabel.
  ///
  /// In ru, this message translates to:
  /// **'непрочитано'**
  String get mailUnreadLabel;

  /// No description provided for @mailBackToAccounts.
  ///
  /// In ru, this message translates to:
  /// **'К отправителям'**
  String get mailBackToAccounts;

  /// No description provided for @mailSelectAccount.
  ///
  /// In ru, this message translates to:
  /// **'Выберите отправителя'**
  String get mailSelectAccount;

  /// No description provided for @mailSelectAccountHint.
  ///
  /// In ru, this message translates to:
  /// **'Письма отправителя появятся здесь.'**
  String get mailSelectAccountHint;

  /// No description provided for @mailExpandInbox.
  ///
  /// In ru, this message translates to:
  /// **'Развернуть папки входящих'**
  String get mailExpandInbox;

  /// No description provided for @mailCollapseInbox.
  ///
  /// In ru, this message translates to:
  /// **'Свернуть папки входящих'**
  String get mailCollapseInbox;

  /// No description provided for @mailCouldNotCreateFolder.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось создать папку'**
  String get mailCouldNotCreateFolder;

  /// No description provided for @mailDeleteSelected.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get mailDeleteSelected;

  /// No description provided for @mailBookmarkSelected.
  ///
  /// In ru, this message translates to:
  /// **'В закладки'**
  String get mailBookmarkSelected;

  /// No description provided for @mailMarkReadSelected.
  ///
  /// In ru, this message translates to:
  /// **'Прочитано'**
  String get mailMarkReadSelected;

  /// No description provided for @mailMarkUnreadSelected.
  ///
  /// In ru, this message translates to:
  /// **'Не прочитано'**
  String get mailMarkUnreadSelected;

  /// No description provided for @mailSpamSelected.
  ///
  /// In ru, this message translates to:
  /// **'В спам'**
  String get mailSpamSelected;

  /// No description provided for @mailNotSpamSelected.
  ///
  /// In ru, this message translates to:
  /// **'Не спам'**
  String get mailNotSpamSelected;

  /// No description provided for @mailDeletedCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Удалено {count} письмо} few{Удалено {count} письма} other{Удалено {count} писем}}'**
  String mailDeletedCount(int count);

  /// No description provided for @mailMovedToSpamCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} письмо отправлено в спам} few{{count} письма отправлено в спам} other{{count} писем отправлено в спам}}'**
  String mailMovedToSpamCount(int count);

  /// No description provided for @mailRestoredCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} письмо возвращено во входящие} few{{count} письма возвращено во входящие} other{{count} писем возвращено во входящие}}'**
  String mailRestoredCount(int count);

  /// No description provided for @mailMarkedReadCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} письмо отмечено прочитанным} few{{count} письма отмечено прочитанными} other{{count} писем отмечено прочитанными}}'**
  String mailMarkedReadCount(int count);

  /// No description provided for @mailMarkedUnreadCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} письмо отмечено непрочитанным} few{{count} письма отмечено непрочитанными} other{{count} писем отмечено непрочитанными}}'**
  String mailMarkedUnreadCount(int count);

  /// No description provided for @mailBookmarkedCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} письмо добавлено в закладки} few{{count} письма добавлено в закладки} other{{count} писем добавлено в закладки}}'**
  String mailBookmarkedCount(int count);

  /// No description provided for @settingsStyle.
  ///
  /// In ru, this message translates to:
  /// **'Стиль'**
  String get settingsStyle;

  /// No description provided for @settingsStyleHint.
  ///
  /// In ru, this message translates to:
  /// **'Выберите облик всего приложения. Размер текста и плотность работают поверх него.'**
  String get settingsStyleHint;

  /// No description provided for @settingsStyleApplied.
  ///
  /// In ru, this message translates to:
  /// **'Стиль применён'**
  String get settingsStyleApplied;

  /// No description provided for @settingsTextSize.
  ///
  /// In ru, this message translates to:
  /// **'Размер текста'**
  String get settingsTextSize;

  /// No description provided for @settingsTextSizeSmall.
  ///
  /// In ru, this message translates to:
  /// **'Мелкий'**
  String get settingsTextSizeSmall;

  /// No description provided for @settingsTextSizeMedium.
  ///
  /// In ru, this message translates to:
  /// **'Обычный'**
  String get settingsTextSizeMedium;

  /// No description provided for @settingsTextSizeLarge.
  ///
  /// In ru, this message translates to:
  /// **'Крупный'**
  String get settingsTextSizeLarge;

  /// No description provided for @settingsListDensity.
  ///
  /// In ru, this message translates to:
  /// **'Плотность списка'**
  String get settingsListDensity;

  /// No description provided for @settingsDensityCompact.
  ///
  /// In ru, this message translates to:
  /// **'Плотно'**
  String get settingsDensityCompact;

  /// No description provided for @settingsDensityNormal.
  ///
  /// In ru, this message translates to:
  /// **'Обычно'**
  String get settingsDensityNormal;

  /// No description provided for @settingsDensitySpacious.
  ///
  /// In ru, this message translates to:
  /// **'Просторно'**
  String get settingsDensitySpacious;

  /// No description provided for @settingsAppearanceHint.
  ///
  /// In ru, this message translates to:
  /// **'Выберите размер текста и плотность списка, удобные лично вам. Настройка сохраняется на этом устройстве.'**
  String get settingsAppearanceHint;

  /// No description provided for @skinStandard.
  ///
  /// In ru, this message translates to:
  /// **'Стандарт'**
  String get skinStandard;

  /// No description provided for @skinStandardHint.
  ///
  /// In ru, this message translates to:
  /// **'Спокойная классика, светлая или тёмная'**
  String get skinStandardHint;

  /// No description provided for @skinSteppe.
  ///
  /// In ru, this message translates to:
  /// **'Степь'**
  String get skinSteppe;

  /// No description provided for @skinSteppeHint.
  ///
  /// In ru, this message translates to:
  /// **'Тёплый песок и терракота'**
  String get skinSteppeHint;

  /// No description provided for @skinPaper.
  ///
  /// In ru, this message translates to:
  /// **'Бумага'**
  String get skinPaper;

  /// No description provided for @skinPaperHint.
  ///
  /// In ru, this message translates to:
  /// **'Кремовая бумага, чернила и антиква'**
  String get skinPaperHint;

  /// No description provided for @skinGraphite.
  ///
  /// In ru, this message translates to:
  /// **'Графит'**
  String get skinGraphite;

  /// No description provided for @skinGraphiteHint.
  ///
  /// In ru, this message translates to:
  /// **'Тёмный, моноширинный, янтарный акцент'**
  String get skinGraphiteHint;

  /// No description provided for @skinKok.
  ///
  /// In ru, this message translates to:
  /// **'Көк'**
  String get skinKok;

  /// No description provided for @skinKokHint.
  ///
  /// In ru, this message translates to:
  /// **'Бирюза и золото, тёмное меню'**
  String get skinKokHint;

  /// No description provided for @skinMidnight.
  ///
  /// In ru, this message translates to:
  /// **'Полночь'**
  String get skinMidnight;

  /// No description provided for @skinMidnightHint.
  ///
  /// In ru, this message translates to:
  /// **'Глубокий индиго, сиреневый акцент'**
  String get skinMidnightHint;

  /// No description provided for @skinTerminal.
  ///
  /// In ru, this message translates to:
  /// **'Терминал'**
  String get skinTerminal;

  /// No description provided for @skinTerminalHint.
  ///
  /// In ru, this message translates to:
  /// **'Зелёный фосфор, весь текст моноширинный'**
  String get skinTerminalHint;

  /// No description provided for @skinLilac.
  ///
  /// In ru, this message translates to:
  /// **'Сирень'**
  String get skinLilac;

  /// No description provided for @skinLilacHint.
  ///
  /// In ru, this message translates to:
  /// **'Лавандовый фон, слива, брусковый шрифт'**
  String get skinLilacHint;

  /// No description provided for @skinContrast.
  ///
  /// In ru, this message translates to:
  /// **'Контраст'**
  String get skinContrast;

  /// No description provided for @skinContrastHint.
  ///
  /// In ru, this message translates to:
  /// **'Чёрное на белом, рамки 2px — для слабого зрения'**
  String get skinContrastHint;

  /// No description provided for @skinForest.
  ///
  /// In ru, this message translates to:
  /// **'Лес'**
  String get skinForest;

  /// No description provided for @skinForestHint.
  ///
  /// In ru, this message translates to:
  /// **'Сосновая тьма, мшистый акцент'**
  String get skinForestHint;

  /// No description provided for @settingsSecuritySection.
  ///
  /// In ru, this message translates to:
  /// **'Безопасность'**
  String get settingsSecuritySection;

  /// No description provided for @settingsLockPin.
  ///
  /// In ru, this message translates to:
  /// **'Вход по PIN-коду'**
  String get settingsLockPin;

  /// No description provided for @settingsLockPinHint.
  ///
  /// In ru, this message translates to:
  /// **'Запрашивать PIN при открытии приложения'**
  String get settingsLockPinHint;

  /// No description provided for @settingsLockChangePin.
  ///
  /// In ru, this message translates to:
  /// **'Сменить PIN-код'**
  String get settingsLockChangePin;

  /// No description provided for @settingsLockBiometric.
  ///
  /// In ru, this message translates to:
  /// **'Разблокировка биометрией'**
  String get settingsLockBiometric;

  /// No description provided for @settingsLockTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Блокировать'**
  String get settingsLockTimeout;

  /// No description provided for @settingsLockOnClose.
  ///
  /// In ru, this message translates to:
  /// **'Запрашивать PIN при закрытии окна'**
  String get settingsLockOnClose;

  /// No description provided for @settingsLockOnCloseHint.
  ///
  /// In ru, this message translates to:
  /// **'Крестик прячет XatBox в трей; при следующем открытии окна — PIN-код'**
  String get settingsLockOnCloseHint;

  /// No description provided for @settingsLockTimeoutImmediately.
  ///
  /// In ru, this message translates to:
  /// **'Сразу после сворачивания'**
  String get settingsLockTimeoutImmediately;

  /// No description provided for @settingsLockTimeoutMinutes.
  ///
  /// In ru, this message translates to:
  /// **'{minutes, plural, one{Через {minutes} минуту} few{Через {minutes} минуты} many{Через {minutes} минут} other{Через {minutes} минуты}}'**
  String settingsLockTimeoutMinutes(int minutes);

  /// No description provided for @settingsHideContent.
  ///
  /// In ru, this message translates to:
  /// **'Скрывать содержимое в списке приложений'**
  String get settingsHideContent;

  /// No description provided for @settingsHideContentHint.
  ///
  /// In ru, this message translates to:
  /// **'На Android также запрещает снимки экрана'**
  String get settingsHideContentHint;

  /// No description provided for @settingsStorageUsed.
  ///
  /// In ru, this message translates to:
  /// **'Занято на устройстве: {size}'**
  String settingsStorageUsed(String size);

  /// No description provided for @lockTitle.
  ///
  /// In ru, this message translates to:
  /// **'Введите PIN-код'**
  String get lockTitle;

  /// No description provided for @lockWrong.
  ///
  /// In ru, this message translates to:
  /// **'{attempts, plural, one{Неверный PIN-код. Осталась {attempts} попытка} few{Неверный PIN-код. Осталось {attempts} попытки} many{Неверный PIN-код. Осталось {attempts} попыток} other{Неверный PIN-код. Осталось {attempts} попытки}}'**
  String lockWrong(int attempts);

  /// No description provided for @lockThrottled.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много попыток. Повторите через {seconds} с'**
  String lockThrottled(int seconds);

  /// No description provided for @lockBiometric.
  ///
  /// In ru, this message translates to:
  /// **'Разблокировать биометрией'**
  String get lockBiometric;

  /// No description provided for @lockBiometricReason.
  ///
  /// In ru, this message translates to:
  /// **'Разблокируйте XatBox'**
  String get lockBiometricReason;

  /// No description provided for @lockForgot.
  ///
  /// In ru, this message translates to:
  /// **'Забыли PIN-код?'**
  String get lockForgot;

  /// No description provided for @lockForgotConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из учётной записи? Затем войдите по паролю и задайте новый PIN-код.'**
  String get lockForgotConfirm;

  /// No description provided for @lockForgotSignOut.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get lockForgotSignOut;

  /// No description provided for @lockDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить цифру'**
  String get lockDelete;

  /// No description provided for @lockSetupTitle.
  ///
  /// In ru, this message translates to:
  /// **'PIN-код'**
  String get lockSetupTitle;

  /// No description provided for @lockSetupEnter.
  ///
  /// In ru, this message translates to:
  /// **'Придумайте PIN-код из 4–6 цифр'**
  String get lockSetupEnter;

  /// No description provided for @lockSetupRepeat.
  ///
  /// In ru, this message translates to:
  /// **'Повторите PIN-код'**
  String get lockSetupRepeat;

  /// No description provided for @lockSetupMismatch.
  ///
  /// In ru, this message translates to:
  /// **'PIN-коды не совпадают. Попробуйте ещё раз.'**
  String get lockSetupMismatch;

  /// No description provided for @lockSetupNext.
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get lockSetupNext;

  /// No description provided for @loginShowPassword.
  ///
  /// In ru, this message translates to:
  /// **'Показать пароль'**
  String get loginShowPassword;

  /// No description provided for @loginHidePassword.
  ///
  /// In ru, this message translates to:
  /// **'Скрыть пароль'**
  String get loginHidePassword;

  /// No description provided for @callsDetailsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Звонок'**
  String get callsDetailsTitle;

  /// No description provided for @callsDetailsType.
  ///
  /// In ru, this message translates to:
  /// **'Тип'**
  String get callsDetailsType;

  /// No description provided for @callsDetailsResult.
  ///
  /// In ru, this message translates to:
  /// **'Итог'**
  String get callsDetailsResult;

  /// No description provided for @callsDetailsStarted.
  ///
  /// In ru, this message translates to:
  /// **'Начало'**
  String get callsDetailsStarted;

  /// No description provided for @callsDetailsDuration.
  ///
  /// In ru, this message translates to:
  /// **'Длительность'**
  String get callsDetailsDuration;

  /// No description provided for @callsDetailsNoConversation.
  ///
  /// In ru, this message translates to:
  /// **'Разговора не было'**
  String get callsDetailsNoConversation;

  /// No description provided for @callsDetailsMessage.
  ///
  /// In ru, this message translates to:
  /// **'Написать'**
  String get callsDetailsMessage;

  /// No description provided for @callsModeDirect.
  ///
  /// In ru, this message translates to:
  /// **'Личный'**
  String get callsModeDirect;

  /// No description provided for @callsModeGroup.
  ///
  /// In ru, this message translates to:
  /// **'Групповой'**
  String get callsModeGroup;

  /// No description provided for @callsModeConference.
  ///
  /// In ru, this message translates to:
  /// **'Конференция'**
  String get callsModeConference;

  /// No description provided for @callsOutcomeAnswered.
  ///
  /// In ru, this message translates to:
  /// **'Состоялся'**
  String get callsOutcomeAnswered;

  /// No description provided for @callsRoleParticipant.
  ///
  /// In ru, this message translates to:
  /// **'участник'**
  String get callsRoleParticipant;

  /// No description provided for @callsPStatusInvited.
  ///
  /// In ru, this message translates to:
  /// **'приглашён'**
  String get callsPStatusInvited;

  /// No description provided for @callsPStatusRinging.
  ///
  /// In ru, this message translates to:
  /// **'звонит'**
  String get callsPStatusRinging;

  /// No description provided for @callsPStatusAccepted.
  ///
  /// In ru, this message translates to:
  /// **'принял'**
  String get callsPStatusAccepted;

  /// No description provided for @callsPStatusJoined.
  ///
  /// In ru, this message translates to:
  /// **'в звонке'**
  String get callsPStatusJoined;

  /// No description provided for @callsPStatusLeft.
  ///
  /// In ru, this message translates to:
  /// **'вышел'**
  String get callsPStatusLeft;

  /// No description provided for @callsPStatusDeclined.
  ///
  /// In ru, this message translates to:
  /// **'отклонил'**
  String get callsPStatusDeclined;

  /// No description provided for @callsPStatusMissed.
  ///
  /// In ru, this message translates to:
  /// **'не ответил'**
  String get callsPStatusMissed;

  /// No description provided for @callsPStatusBusy.
  ///
  /// In ru, this message translates to:
  /// **'занят'**
  String get callsPStatusBusy;

  /// No description provided for @callsPStatusRemoved.
  ///
  /// In ru, this message translates to:
  /// **'удалён'**
  String get callsPStatusRemoved;

  /// No description provided for @callsErrNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Звонок не найден.'**
  String get callsErrNotFound;

  /// No description provided for @callsInvite.
  ///
  /// In ru, this message translates to:
  /// **'Добавить участников'**
  String get callsInvite;

  /// No description provided for @callsInviteSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Пригласить ({count})'**
  String callsInviteSubmit(int count);

  /// No description provided for @callsInviteSent.
  ///
  /// In ru, this message translates to:
  /// **'Приглашения отправлены.'**
  String get callsInviteSent;

  /// No description provided for @callsInviteNobody.
  ///
  /// In ru, this message translates to:
  /// **'Все найденные коллеги уже в звонке'**
  String get callsInviteNobody;

  /// No description provided for @callsMinimize.
  ///
  /// In ru, this message translates to:
  /// **'Свернуть'**
  String get callsMinimize;

  /// No description provided for @callsReturnToCall.
  ///
  /// In ru, this message translates to:
  /// **'Вернуться к звонку'**
  String get callsReturnToCall;

  /// No description provided for @callsMore.
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get callsMore;

  /// No description provided for @callsRaiseHand.
  ///
  /// In ru, this message translates to:
  /// **'Поднять руку'**
  String get callsRaiseHand;

  /// No description provided for @callsLowerHand.
  ///
  /// In ru, this message translates to:
  /// **'Опустить руку'**
  String get callsLowerHand;

  /// No description provided for @callsHandRaised.
  ///
  /// In ru, this message translates to:
  /// **'Поднята рука'**
  String get callsHandRaised;

  /// No description provided for @callsReactions.
  ///
  /// In ru, this message translates to:
  /// **'Реакции'**
  String get callsReactions;

  /// No description provided for @callsChat.
  ///
  /// In ru, this message translates to:
  /// **'Чат'**
  String get callsChat;

  /// No description provided for @callsChatTitle.
  ///
  /// In ru, this message translates to:
  /// **'Чат звонка'**
  String get callsChatTitle;

  /// No description provided for @callsChatHint.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение…'**
  String get callsChatHint;

  /// No description provided for @callsChatSend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get callsChatSend;

  /// No description provided for @callsChatEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Сообщения увидят все участники звонка'**
  String get callsChatEmpty;

  /// No description provided for @callsChatEmptyLinked.
  ///
  /// In ru, this message translates to:
  /// **'Сообщения увидят участники звонка, они сохранятся в чате'**
  String get callsChatEmptyLinked;

  /// No description provided for @callsChatFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не отправлено — нажмите, чтобы повторить'**
  String get callsChatFailed;

  /// No description provided for @callsChatEmoji.
  ///
  /// In ru, this message translates to:
  /// **'Эмодзи'**
  String get callsChatEmoji;

  /// No description provided for @callsChatClose.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть чат'**
  String get callsChatClose;

  /// No description provided for @callsRecord.
  ///
  /// In ru, this message translates to:
  /// **'Записать'**
  String get callsRecord;

  /// No description provided for @callsRecordStop.
  ///
  /// In ru, this message translates to:
  /// **'Остановить запись'**
  String get callsRecordStop;

  /// No description provided for @callsRecordConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Записать звонок?'**
  String get callsRecordConfirmTitle;

  /// No description provided for @callsRecordConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'Все участники увидят индикатор записи. Запись будет доступна участникам в карточке звонка.'**
  String get callsRecordConfirmBody;

  /// No description provided for @callsRecordConfirmStart.
  ///
  /// In ru, this message translates to:
  /// **'Начать запись'**
  String get callsRecordConfirmStart;

  /// No description provided for @callsRecordingBanner.
  ///
  /// In ru, this message translates to:
  /// **'Звонок записывается'**
  String get callsRecordingBanner;

  /// No description provided for @callsRecordingBannerBy.
  ///
  /// In ru, this message translates to:
  /// **'Запись включил(а) {name}'**
  String callsRecordingBannerBy(String name);

  /// No description provided for @callsRecordingStopped.
  ///
  /// In ru, this message translates to:
  /// **'Запись остановлена'**
  String get callsRecordingStopped;

  /// No description provided for @callsRecordings.
  ///
  /// In ru, this message translates to:
  /// **'Записи'**
  String get callsRecordings;

  /// No description provided for @callsRecordingInProgress.
  ///
  /// In ru, this message translates to:
  /// **'Идёт запись'**
  String get callsRecordingInProgress;

  /// No description provided for @callsRecordingFailed.
  ///
  /// In ru, this message translates to:
  /// **'Запись не удалась'**
  String get callsRecordingFailed;

  /// No description provided for @callsRecordingVideo.
  ///
  /// In ru, this message translates to:
  /// **'Видеозапись'**
  String get callsRecordingVideo;

  /// No description provided for @callsRecordingAudio.
  ///
  /// In ru, this message translates to:
  /// **'Аудиозапись'**
  String get callsRecordingAudio;

  /// No description provided for @callsRecordingDownload.
  ///
  /// In ru, this message translates to:
  /// **'Скачать'**
  String get callsRecordingDownload;

  /// No description provided for @callsRecordingOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть'**
  String get callsRecordingOpen;

  /// No description provided for @callsRecordingNoApp.
  ///
  /// In ru, this message translates to:
  /// **'Нет приложения, чтобы открыть файл'**
  String get callsRecordingNoApp;

  /// No description provided for @callsRecordingDownloadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось скачать запись'**
  String get callsRecordingDownloadFailed;

  /// No description provided for @callsErrRecordingUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Запись сейчас недоступна. Попробуйте позже.'**
  String get callsErrRecordingUnavailable;

  /// No description provided for @callsErrRecordingActive.
  ///
  /// In ru, this message translates to:
  /// **'Звонок уже записывается'**
  String get callsErrRecordingActive;

  /// No description provided for @callsErrRecordingDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Запись звонков отключена'**
  String get callsErrRecordingDisabled;

  /// No description provided for @callsLayoutGrid.
  ///
  /// In ru, this message translates to:
  /// **'Сетка'**
  String get callsLayoutGrid;

  /// No description provided for @callsLayoutSpotlight.
  ///
  /// In ru, this message translates to:
  /// **'Спикер'**
  String get callsLayoutSpotlight;

  /// No description provided for @callsDeclineWithMessage.
  ///
  /// In ru, this message translates to:
  /// **'Отклонить с сообщением'**
  String get callsDeclineWithMessage;

  /// No description provided for @callsQuickReplyBusy.
  ///
  /// In ru, this message translates to:
  /// **'Не могу говорить, напишу позже.'**
  String get callsQuickReplyBusy;

  /// No description provided for @callsQuickReplyLater.
  ///
  /// In ru, this message translates to:
  /// **'Перезвоню через несколько минут.'**
  String get callsQuickReplyLater;

  /// No description provided for @callsQuickReplyMeeting.
  ///
  /// In ru, this message translates to:
  /// **'Я на встрече.'**
  String get callsQuickReplyMeeting;

  /// No description provided for @callsQuickReplySent.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение отправлено'**
  String get callsQuickReplySent;

  /// No description provided for @callsMessage.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение'**
  String get callsMessage;

  /// No description provided for @callsModMuteCamera.
  ///
  /// In ru, this message translates to:
  /// **'Выключить камеру'**
  String get callsModMuteCamera;

  /// No description provided for @callsModStopScreenShare.
  ///
  /// In ru, this message translates to:
  /// **'Остановить показ экрана'**
  String get callsModStopScreenShare;

  /// No description provided for @callsMakeParticipant.
  ///
  /// In ru, this message translates to:
  /// **'Сделать участником'**
  String get callsMakeParticipant;

  /// No description provided for @callsRingAgain.
  ///
  /// In ru, this message translates to:
  /// **'Позвонить ещё раз'**
  String get callsRingAgain;

  /// No description provided for @callsRingAgainSent.
  ///
  /// In ru, this message translates to:
  /// **'Вызов отправлен'**
  String get callsRingAgainSent;

  /// No description provided for @callsSectionInCall.
  ///
  /// In ru, this message translates to:
  /// **'В звонке'**
  String get callsSectionInCall;

  /// No description provided for @callsSectionNotInCall.
  ///
  /// In ru, this message translates to:
  /// **'Не подключены'**
  String get callsSectionNotInCall;

  /// No description provided for @callsClose.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get callsClose;

  /// No description provided for @callsTitleHint.
  ///
  /// In ru, this message translates to:
  /// **'Название звонка (необязательно)'**
  String get callsTitleHint;

  /// No description provided for @meetingsSection.
  ///
  /// In ru, this message translates to:
  /// **'Встречи'**
  String get meetingsSection;

  /// No description provided for @meetingsToday.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get meetingsToday;

  /// No description provided for @meetingJoin.
  ///
  /// In ru, this message translates to:
  /// **'Подключиться'**
  String get meetingJoin;

  /// No description provided for @meetingLive.
  ///
  /// In ru, this message translates to:
  /// **'Идёт'**
  String get meetingLive;

  /// No description provided for @meetingOpenNow.
  ///
  /// In ru, this message translates to:
  /// **'Можно подключаться'**
  String get meetingOpenNow;

  /// No description provided for @meetingOpensAt.
  ///
  /// In ru, this message translates to:
  /// **'Откроется в {time}'**
  String meetingOpensAt(String time);

  /// No description provided for @meetingOpensSoonHint.
  ///
  /// In ru, this message translates to:
  /// **'Подключиться можно за 10 минут до начала'**
  String get meetingOpensSoonHint;

  /// No description provided for @meetingPrejoinTitle.
  ///
  /// In ru, this message translates to:
  /// **'Видеовстреча'**
  String get meetingPrejoinTitle;

  /// No description provided for @meetingDevices.
  ///
  /// In ru, this message translates to:
  /// **'Устройства'**
  String get meetingDevices;

  /// No description provided for @meetingDeviceMic.
  ///
  /// In ru, this message translates to:
  /// **'Микрофон: {name}'**
  String meetingDeviceMic(String name);

  /// No description provided for @meetingDeviceCamera.
  ///
  /// In ru, this message translates to:
  /// **'Камера: {name}'**
  String meetingDeviceCamera(String name);

  /// No description provided for @meetingDeviceDefault.
  ///
  /// In ru, this message translates to:
  /// **'по умолчанию'**
  String get meetingDeviceDefault;

  /// No description provided for @meetingDeviceOff.
  ///
  /// In ru, this message translates to:
  /// **'выключен(а)'**
  String get meetingDeviceOff;

  /// No description provided for @meetingCameraOff.
  ///
  /// In ru, this message translates to:
  /// **'Камера выключена'**
  String get meetingCameraOff;

  /// No description provided for @meetingPreviewUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Предпросмотр камеры недоступен'**
  String get meetingPreviewUnavailable;

  /// No description provided for @meetingLobbyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Ожидайте подтверждения'**
  String get meetingLobbyTitle;

  /// No description provided for @meetingLobbyText.
  ///
  /// In ru, this message translates to:
  /// **'Организатор получил запрос и скоро впустит вас.'**
  String get meetingLobbyText;

  /// No description provided for @meetingLobbyDenied.
  ///
  /// In ru, this message translates to:
  /// **'Организатор не впустил вас во встречу'**
  String get meetingLobbyDenied;

  /// No description provided for @meetingNotStarted.
  ///
  /// In ru, this message translates to:
  /// **'Встреча ещё не началась'**
  String get meetingNotStarted;

  /// No description provided for @meetingEnded.
  ///
  /// In ru, this message translates to:
  /// **'Встреча завершена'**
  String get meetingEnded;

  /// No description provided for @meetingCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Встреча отменена'**
  String get meetingCancelled;

  /// No description provided for @meetingNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Встреча не найдена'**
  String get meetingNotFound;

  /// No description provided for @meetingGuestLinkTitle.
  ///
  /// In ru, this message translates to:
  /// **'Это гостевая ссылка'**
  String get meetingGuestLinkTitle;

  /// No description provided for @meetingGuestLinkText.
  ///
  /// In ru, this message translates to:
  /// **'Гостевые ссылки открываются в браузере — для людей без учётной записи.'**
  String get meetingGuestLinkText;

  /// No description provided for @meetingOpenInBrowser.
  ///
  /// In ru, this message translates to:
  /// **'Открыть в браузере'**
  String get meetingOpenInBrowser;

  /// No description provided for @meetingPermissionDenied.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к камере или микрофону'**
  String get meetingPermissionDenied;

  /// No description provided for @calendarXatBoxMeeting.
  ///
  /// In ru, this message translates to:
  /// **'Добавить видеовстречу XatBox'**
  String get calendarXatBoxMeeting;

  /// No description provided for @calendarXatBoxMeetingHint.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка для подключения появится в событии'**
  String get calendarXatBoxMeetingHint;

  /// No description provided for @calendarXatBoxMeetingAdded.
  ///
  /// In ru, this message translates to:
  /// **'Видеовстреча XatBox добавлена'**
  String get calendarXatBoxMeetingAdded;

  /// No description provided for @calendarXatBoxMeetingAllDay.
  ///
  /// In ru, this message translates to:
  /// **'Недоступно для событий на весь день'**
  String get calendarXatBoxMeetingAllDay;

  /// No description provided for @calendarXatBoxMeetingDescription.
  ///
  /// In ru, this message translates to:
  /// **'Видеовстреча XatBox: {url}'**
  String calendarXatBoxMeetingDescription(String url);

  /// No description provided for @calendarXatBoxMeetingFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось создать видеовстречу'**
  String get calendarXatBoxMeetingFailed;

  /// No description provided for @calendarMeetingReminderBody.
  ///
  /// In ru, this message translates to:
  /// **'Через 5 минут. Нажмите «Подключиться»'**
  String get calendarMeetingReminderBody;

  /// No description provided for @callsLobbyWaiting.
  ///
  /// In ru, this message translates to:
  /// **'Ожидают: {count}'**
  String callsLobbyWaiting(int count);

  /// No description provided for @callsLobbyAdmit.
  ///
  /// In ru, this message translates to:
  /// **'Впустить'**
  String get callsLobbyAdmit;

  /// No description provided for @callsLobbyDeny.
  ///
  /// In ru, this message translates to:
  /// **'Отклонить'**
  String get callsLobbyDeny;

  /// No description provided for @callsLobbyStaff.
  ///
  /// In ru, this message translates to:
  /// **'Сотрудник'**
  String get callsLobbyStaff;

  /// No description provided for @callsLobbyBanner.
  ///
  /// In ru, this message translates to:
  /// **'Ожидают входа: {count}'**
  String callsLobbyBanner(int count);

  /// No description provided for @callsLobbyOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть'**
  String get callsLobbyOpen;

  /// No description provided for @callsGuest.
  ///
  /// In ru, this message translates to:
  /// **'Гость'**
  String get callsGuest;

  /// No description provided for @callsGuestsSection.
  ///
  /// In ru, this message translates to:
  /// **'Гости'**
  String get callsGuestsSection;

  /// No description provided for @callsGuestInvite.
  ///
  /// In ru, this message translates to:
  /// **'Пригласить гостя'**
  String get callsGuestInvite;

  /// No description provided for @callsGuestLinkTitle.
  ///
  /// In ru, this message translates to:
  /// **'Гостевая ссылка'**
  String get callsGuestLinkTitle;

  /// No description provided for @callsGuestLinkHint.
  ///
  /// In ru, this message translates to:
  /// **'Для людей без учётной записи XatBox: ссылка откроется в браузере, вы впустите гостя сами.'**
  String get callsGuestLinkHint;

  /// No description provided for @callsGuestLinkExpires.
  ///
  /// In ru, this message translates to:
  /// **'Действует'**
  String get callsGuestLinkExpires;

  /// No description provided for @callsGuestLinkHour.
  ///
  /// In ru, this message translates to:
  /// **'1 час'**
  String get callsGuestLinkHour;

  /// No description provided for @callsGuestLinkDay.
  ///
  /// In ru, this message translates to:
  /// **'1 день'**
  String get callsGuestLinkDay;

  /// No description provided for @callsGuestLinkWeek.
  ///
  /// In ru, this message translates to:
  /// **'7 дней'**
  String get callsGuestLinkWeek;

  /// No description provided for @callsGuestLinkUses.
  ///
  /// In ru, this message translates to:
  /// **'Сколько человек'**
  String get callsGuestLinkUses;

  /// No description provided for @callsGuestLinkUsesValue.
  ///
  /// In ru, this message translates to:
  /// **'до {count} чел.'**
  String callsGuestLinkUsesValue(int count);

  /// No description provided for @callsGuestLinkLobby.
  ///
  /// In ru, this message translates to:
  /// **'Впускать вручную'**
  String get callsGuestLinkLobby;

  /// No description provided for @callsGuestLinkScreen.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить демонстрацию экрана'**
  String get callsGuestLinkScreen;

  /// No description provided for @callsGuestLinkCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать ссылку'**
  String get callsGuestLinkCreate;

  /// No description provided for @callsGuestLinkCopy.
  ///
  /// In ru, this message translates to:
  /// **'Копировать ссылку'**
  String get callsGuestLinkCopy;

  /// No description provided for @callsGuestLinkCopied.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка скопирована'**
  String get callsGuestLinkCopied;

  /// No description provided for @callsQualitySettings.
  ///
  /// In ru, this message translates to:
  /// **'Качество'**
  String get callsQualitySettings;

  /// No description provided for @callsQualityAudio.
  ///
  /// In ru, this message translates to:
  /// **'Обработка звука'**
  String get callsQualityAudio;

  /// No description provided for @callsQualityVideo.
  ///
  /// In ru, this message translates to:
  /// **'Видео'**
  String get callsQualityVideo;

  /// No description provided for @callsNoiseSuppression.
  ///
  /// In ru, this message translates to:
  /// **'Шумоподавление'**
  String get callsNoiseSuppression;

  /// No description provided for @callsEchoCancellation.
  ///
  /// In ru, this message translates to:
  /// **'Эхоподавление'**
  String get callsEchoCancellation;

  /// No description provided for @callsAutoGain.
  ///
  /// In ru, this message translates to:
  /// **'Автоусиление'**
  String get callsAutoGain;

  /// No description provided for @callsMusicMode.
  ///
  /// In ru, this message translates to:
  /// **'Режим музыки'**
  String get callsMusicMode;

  /// No description provided for @callsMusicModeHint.
  ///
  /// In ru, this message translates to:
  /// **'Без фильтров голоса и с высоким битрейтом'**
  String get callsMusicModeHint;

  /// No description provided for @callsDataSaver.
  ///
  /// In ru, this message translates to:
  /// **'Трафик'**
  String get callsDataSaver;

  /// No description provided for @callsDataSaverOff.
  ///
  /// In ru, this message translates to:
  /// **'Обычный'**
  String get callsDataSaverOff;

  /// No description provided for @callsDataSaverLow.
  ///
  /// In ru, this message translates to:
  /// **'Экономия'**
  String get callsDataSaverLow;

  /// No description provided for @callsDataSaverAudio.
  ///
  /// In ru, this message translates to:
  /// **'Только звук'**
  String get callsDataSaverAudio;

  /// No description provided for @callsDataSaverHint.
  ///
  /// In ru, this message translates to:
  /// **'«Экономия» принимает видео в низком качестве, «Только звук» не принимает и не отправляет видео.'**
  String get callsDataSaverHint;

  /// No description provided for @callsBackgroundBlur.
  ///
  /// In ru, this message translates to:
  /// **'Размытие фона'**
  String get callsBackgroundBlur;

  /// No description provided for @callsBackgroundBlurUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Пока недоступно в мобильном приложении'**
  String get callsBackgroundBlurUnavailable;

  /// No description provided for @callsPoorNetworkTitle.
  ///
  /// In ru, this message translates to:
  /// **'Слабая сеть'**
  String get callsPoorNetworkTitle;

  /// No description provided for @callsPoorNetworkText.
  ///
  /// In ru, this message translates to:
  /// **'Включить экономию трафика, чтобы звук не прерывался?'**
  String get callsPoorNetworkText;

  /// No description provided for @callsPoorNetworkAccept.
  ///
  /// In ru, this message translates to:
  /// **'Экономить'**
  String get callsPoorNetworkAccept;

  /// No description provided for @callsPoorNetworkDismiss.
  ///
  /// In ru, this message translates to:
  /// **'Не сейчас'**
  String get callsPoorNetworkDismiss;

  /// No description provided for @callsTranscript.
  ///
  /// In ru, this message translates to:
  /// **'Расшифровка'**
  String get callsTranscript;

  /// No description provided for @callsTranscriptPending.
  ///
  /// In ru, this message translates to:
  /// **'Расшифровка готовится'**
  String get callsTranscriptPending;

  /// No description provided for @callsTranscriptFailed.
  ///
  /// In ru, this message translates to:
  /// **'Расшифровка не удалась'**
  String get callsTranscriptFailed;

  /// No description provided for @callsTranscriptRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить расшифровку'**
  String get callsTranscriptRetry;

  /// No description provided for @callsTranscriptSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск в расшифровке'**
  String get callsTranscriptSearch;

  /// No description provided for @callsTranscriptMatches.
  ///
  /// In ru, this message translates to:
  /// **'Найдено: {count}'**
  String callsTranscriptMatches(int count);

  /// No description provided for @callsTranscriptKeyPhrases.
  ///
  /// In ru, this message translates to:
  /// **'Ключевые фразы'**
  String get callsTranscriptKeyPhrases;

  /// No description provided for @callsTranscriptAutomatic.
  ///
  /// In ru, this message translates to:
  /// **'автоматически'**
  String get callsTranscriptAutomatic;

  /// No description provided for @callsTranscriptKeyPhrasesNote.
  ///
  /// In ru, this message translates to:
  /// **'Выбраны автоматически по частоте слов — это не пересказ разговора.'**
  String get callsTranscriptKeyPhrasesNote;

  /// No description provided for @callsTranscriptCopy.
  ///
  /// In ru, this message translates to:
  /// **'Копировать текст'**
  String get callsTranscriptCopy;

  /// No description provided for @callsTranscriptCopied.
  ///
  /// In ru, this message translates to:
  /// **'Текст скопирован'**
  String get callsTranscriptCopied;

  /// No description provided for @callsTranscriptEmpty.
  ///
  /// In ru, this message translates to:
  /// **'В записи не распознана речь'**
  String get callsTranscriptEmpty;

  /// No description provided for @callsTranscriptNoSeek.
  ///
  /// In ru, this message translates to:
  /// **'Время указано от начала записи.'**
  String get callsTranscriptNoSeek;

  /// No description provided for @callsErrNotOrganizer.
  ///
  /// In ru, this message translates to:
  /// **'Изменить встречу может только организатор'**
  String get callsErrNotOrganizer;

  /// No description provided for @callsErrLobbyDecided.
  ///
  /// In ru, this message translates to:
  /// **'Запрос уже обработан'**
  String get callsErrLobbyDecided;

  /// No description provided for @callsErrGuests.
  ///
  /// In ru, this message translates to:
  /// **'Гостевой доступ недоступен'**
  String get callsErrGuests;

  /// No description provided for @callsErrTranscriptBusy.
  ///
  /// In ru, this message translates to:
  /// **'Очередь расшифровки занята — попробуйте позже'**
  String get callsErrTranscriptBusy;

  /// No description provided for @callsGroupCall.
  ///
  /// In ru, this message translates to:
  /// **'Групповой звонок'**
  String get callsGroupCall;

  /// No description provided for @callsSwapVideo.
  ///
  /// In ru, this message translates to:
  /// **'Поменять местами'**
  String get callsSwapVideo;

  /// No description provided for @callsVideoPaused.
  ///
  /// In ru, this message translates to:
  /// **'Видео приостановлено'**
  String get callsVideoPaused;

  /// No description provided for @chatAttachContact.
  ///
  /// In ru, this message translates to:
  /// **'Контакт'**
  String get chatAttachContact;

  /// No description provided for @chatContactPickTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отправить контакт'**
  String get chatContactPickTitle;

  /// No description provided for @chatContactWrite.
  ///
  /// In ru, this message translates to:
  /// **'Написать'**
  String get chatContactWrite;

  /// No description provided for @chatContactCall.
  ///
  /// In ru, this message translates to:
  /// **'Позвонить'**
  String get chatContactCall;

  /// No description provided for @chatContactInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Этот контакт недоступен.'**
  String get chatContactInvalid;

  /// No description provided for @chatVideoOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть видео'**
  String get chatVideoOpen;

  /// No description provided for @chatMediaLoadPreview.
  ///
  /// In ru, this message translates to:
  /// **'Загрузить превью'**
  String get chatMediaLoadPreview;

  /// No description provided for @chatAvatarChange.
  ///
  /// In ru, this message translates to:
  /// **'Сменить фото группы'**
  String get chatAvatarChange;

  /// No description provided for @chatAvatarUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Фото группы обновлено'**
  String get chatAvatarUpdated;

  /// No description provided for @chatStorageSection.
  ///
  /// In ru, this message translates to:
  /// **'Данные чата'**
  String get chatStorageSection;

  /// No description provided for @chatAutoDownloadTitle.
  ///
  /// In ru, this message translates to:
  /// **'Автозагрузка медиа'**
  String get chatAutoDownloadTitle;

  /// No description provided for @chatAutoDownloadHint.
  ///
  /// In ru, this message translates to:
  /// **'Превью фото и видео, голосовые сообщения. Оригиналы файлов загружаются только по нажатию.'**
  String get chatAutoDownloadHint;

  /// No description provided for @chatAutoDownloadNever.
  ///
  /// In ru, this message translates to:
  /// **'Никогда'**
  String get chatAutoDownloadNever;

  /// No description provided for @chatAutoDownloadWifi.
  ///
  /// In ru, this message translates to:
  /// **'Только Wi‑Fi'**
  String get chatAutoDownloadWifi;

  /// No description provided for @chatAutoDownloadAlways.
  ///
  /// In ru, this message translates to:
  /// **'Всегда'**
  String get chatAutoDownloadAlways;

  /// No description provided for @chatMessagesKeptTitle.
  ///
  /// In ru, this message translates to:
  /// **'Хранить сообщений в каждом чате'**
  String get chatMessagesKeptTitle;

  /// No description provided for @chatMediaSize.
  ///
  /// In ru, this message translates to:
  /// **'Медиафайлы чата: {size}'**
  String chatMediaSize(String size);

  /// No description provided for @chatMediaClear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить медиафайлы'**
  String get chatMediaClear;

  /// No description provided for @chatMediaCleared.
  ///
  /// In ru, this message translates to:
  /// **'Медиафайлы чата удалены'**
  String get chatMediaCleared;

  /// No description provided for @calendarBusyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Занятость'**
  String get calendarBusyTitle;

  /// No description provided for @calendarBusyYou.
  ///
  /// In ru, this message translates to:
  /// **'Вы'**
  String get calendarBusyYou;

  /// No description provided for @calendarBusyFree.
  ///
  /// In ru, this message translates to:
  /// **'свободен'**
  String get calendarBusyFree;

  /// No description provided for @calendarBusyUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить занятость.'**
  String get calendarBusyUnavailable;

  /// No description provided for @calendarFindTime.
  ///
  /// In ru, this message translates to:
  /// **'Подобрать время'**
  String get calendarFindTime;

  /// No description provided for @calendarFindTimeHint.
  ///
  /// In ru, this message translates to:
  /// **'Рабочие часы организации, ближайшие 7 дней от выбранной даты.'**
  String get calendarFindTimeHint;

  /// No description provided for @calendarFindTimeEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Свободных слотов не найдено.'**
  String get calendarFindTimeEmpty;

  /// No description provided for @calendarRoom.
  ///
  /// In ru, this message translates to:
  /// **'Переговорная'**
  String get calendarRoom;

  /// No description provided for @calendarRoomNone.
  ///
  /// In ru, this message translates to:
  /// **'Без переговорной'**
  String get calendarRoomNone;

  /// No description provided for @calendarRoomSeats.
  ///
  /// In ru, this message translates to:
  /// **'Мест: {count}'**
  String calendarRoomSeats(int count);

  /// No description provided for @calendarRoomsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступных переговорных'**
  String get calendarRoomsEmpty;

  /// No description provided for @calendarRoomBusy.
  ///
  /// In ru, this message translates to:
  /// **'Бронь переговорной'**
  String get calendarRoomBusy;

  /// No description provided for @calendarRoomBusyWarning.
  ///
  /// In ru, this message translates to:
  /// **'Переговорная занята в выбранное время.'**
  String get calendarRoomBusyWarning;

  /// No description provided for @contactsTab.
  ///
  /// In ru, this message translates to:
  /// **'Контакты'**
  String get contactsTab;

  /// No description provided for @contactsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Контакты'**
  String get contactsTitle;

  /// No description provided for @contactsSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по имени или почте'**
  String get contactsSearchHint;

  /// No description provided for @contactsLoadMore.
  ///
  /// In ru, this message translates to:
  /// **'Показать ещё'**
  String get contactsLoadMore;

  /// No description provided for @contactsClearSearch.
  ///
  /// In ru, this message translates to:
  /// **'Очистить поиск'**
  String get contactsClearSearch;

  /// No description provided for @contactsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'В справочнике пока никого нет'**
  String get contactsEmpty;

  /// No description provided for @contactsNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Никого не нашлось'**
  String get contactsNotFound;

  /// No description provided for @contactsChatDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Справочник сотрудников работает через сервис чата, а он не настроен в этой сборке.'**
  String get contactsChatDisabled;

  /// No description provided for @contactsCachedBanner.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось обновить — показан сохранённый список'**
  String get contactsCachedBanner;

  /// No description provided for @contactsLimitHint.
  ///
  /// In ru, this message translates to:
  /// **'Показаны первые {count} сотрудников — уточните поиск'**
  String contactsLimitHint(int count);

  /// No description provided for @contactsProfileTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сотрудник'**
  String get contactsProfileTitle;

  /// No description provided for @contactsProfileNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Сотрудник не найден в справочнике'**
  String get contactsProfileNotFound;

  /// No description provided for @contactsWrite.
  ///
  /// In ru, this message translates to:
  /// **'Написать'**
  String get contactsWrite;

  /// No description provided for @contactsAudioCall.
  ///
  /// In ru, this message translates to:
  /// **'Аудиозвонок'**
  String get contactsAudioCall;

  /// No description provided for @contactsVideoCall.
  ///
  /// In ru, this message translates to:
  /// **'Видеозвонок'**
  String get contactsVideoCall;

  /// No description provided for @contactsWriteEmail.
  ///
  /// In ru, this message translates to:
  /// **'Написать письмо'**
  String get contactsWriteEmail;

  /// No description provided for @contactsEmail.
  ///
  /// In ru, this message translates to:
  /// **'Почта'**
  String get contactsEmail;

  /// No description provided for @contactsDepartment.
  ///
  /// In ru, this message translates to:
  /// **'Отдел'**
  String get contactsDepartment;

  /// No description provided for @contactsPosition.
  ///
  /// In ru, this message translates to:
  /// **'Должность'**
  String get contactsPosition;

  /// No description provided for @contactsFilterAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get contactsFilterAll;

  /// No description provided for @contactsFilterOnline.
  ///
  /// In ru, this message translates to:
  /// **'В сети'**
  String get contactsFilterOnline;

  /// No description provided for @contactsFilterFavourites.
  ///
  /// In ru, this message translates to:
  /// **'Избранные'**
  String get contactsFilterFavourites;

  /// No description provided for @contactsFilterDepartment.
  ///
  /// In ru, this message translates to:
  /// **'Отдел'**
  String get contactsFilterDepartment;

  /// No description provided for @contactsDepartmentsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отделы'**
  String get contactsDepartmentsTitle;

  /// No description provided for @contactsAllDepartments.
  ///
  /// In ru, this message translates to:
  /// **'Все отделы'**
  String get contactsAllDepartments;

  /// No description provided for @contactsNoDepartment.
  ///
  /// In ru, this message translates to:
  /// **'Без отдела'**
  String get contactsNoDepartment;

  /// No description provided for @contactsDepartmentsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Список отделов недоступен'**
  String get contactsDepartmentsEmpty;

  /// No description provided for @contactsGroupByDepartment.
  ///
  /// In ru, this message translates to:
  /// **'Группировать по отделам'**
  String get contactsGroupByDepartment;

  /// No description provided for @contactsGroupByName.
  ///
  /// In ru, this message translates to:
  /// **'По алфавиту'**
  String get contactsGroupByName;

  /// No description provided for @contactsFavourites.
  ///
  /// In ru, this message translates to:
  /// **'Избранные'**
  String get contactsFavourites;

  /// No description provided for @contactsRecent.
  ///
  /// In ru, this message translates to:
  /// **'Недавние'**
  String get contactsRecent;

  /// No description provided for @contactsAddFavourite.
  ///
  /// In ru, this message translates to:
  /// **'Добавить в избранное'**
  String get contactsAddFavourite;

  /// No description provided for @contactsRemoveFavourite.
  ///
  /// In ru, this message translates to:
  /// **'Убрать из избранного'**
  String get contactsRemoveFavourite;

  /// No description provided for @contactsNotFoundHint.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте написание или выберите другой отдел'**
  String get contactsNotFoundHint;

  /// No description provided for @contactsNoOnline.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас никого нет в сети'**
  String get contactsNoOnline;

  /// No description provided for @contactsNoFavourites.
  ///
  /// In ru, this message translates to:
  /// **'Нет избранных коллег'**
  String get contactsNoFavourites;

  /// No description provided for @contactsNoFavouritesHint.
  ///
  /// In ru, this message translates to:
  /// **'Откройте профиль и нажмите звёздочку — коллега появится здесь'**
  String get contactsNoFavouritesHint;

  /// No description provided for @contactsMailbox.
  ///
  /// In ru, this message translates to:
  /// **'Почтовый ящик'**
  String get contactsMailbox;

  /// No description provided for @contactsCopied.
  ///
  /// In ru, this message translates to:
  /// **'Скопировано: {value}'**
  String contactsCopied(String value);

  /// No description provided for @contactsCopy.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать'**
  String get contactsCopy;

  /// No description provided for @contactsManager.
  ///
  /// In ru, this message translates to:
  /// **'Руководитель'**
  String get contactsManager;

  /// No description provided for @contactsEmployeeCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} сотрудник} few{{count} сотрудника} many{{count} сотрудников} other{{count} сотрудника}}'**
  String contactsEmployeeCount(int count);

  /// No description provided for @contactsColleagues.
  ///
  /// In ru, this message translates to:
  /// **'Коллеги из отдела'**
  String get contactsColleagues;

  /// No description provided for @contactsSharedChats.
  ///
  /// In ru, this message translates to:
  /// **'Общие группы'**
  String get contactsSharedChats;

  /// No description provided for @contactsChatMembers.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} участник} few{{count} участника} many{{count} участников} other{{count} участника}}'**
  String contactsChatMembers(int count);

  /// No description provided for @contactsShare.
  ///
  /// In ru, this message translates to:
  /// **'Поделиться контактом'**
  String get contactsShare;

  /// No description provided for @contactsShareToChat.
  ///
  /// In ru, this message translates to:
  /// **'Отправить в чат'**
  String get contactsShareToChat;

  /// No description provided for @contactsCopyVCard.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать визитку (vCard)'**
  String get contactsCopyVCard;

  /// No description provided for @contactsVCardCopied.
  ///
  /// In ru, this message translates to:
  /// **'Визитка скопирована'**
  String get contactsVCardCopied;

  /// No description provided for @contactsShareSent.
  ///
  /// In ru, this message translates to:
  /// **'Контакт отправлен в «{chat}»'**
  String contactsShareSent(String chat);

  /// No description provided for @contactsShareNoChats.
  ///
  /// In ru, this message translates to:
  /// **'Нет чатов для отправки'**
  String get contactsShareNoChats;

  /// No description provided for @contactsActionAudio.
  ///
  /// In ru, this message translates to:
  /// **'Аудио'**
  String get contactsActionAudio;

  /// No description provided for @contactsActionVideo.
  ///
  /// In ru, this message translates to:
  /// **'Видео'**
  String get contactsActionVideo;

  /// No description provided for @contactsActionEmail.
  ///
  /// In ru, this message translates to:
  /// **'Письмо'**
  String get contactsActionEmail;

  /// No description provided for @contactsIndexHint.
  ///
  /// In ru, this message translates to:
  /// **'Быстрый переход по алфавиту'**
  String get contactsIndexHint;

  /// No description provided for @contactsSeenJustNow.
  ///
  /// In ru, this message translates to:
  /// **'был(а) только что'**
  String get contactsSeenJustNow;

  /// No description provided for @contactsSeenMinutes.
  ///
  /// In ru, this message translates to:
  /// **'был(а) {count} мин назад'**
  String contactsSeenMinutes(int count);

  /// No description provided for @contactsSeenHours.
  ///
  /// In ru, this message translates to:
  /// **'был(а) {count} ч назад'**
  String contactsSeenHours(int count);

  /// No description provided for @notificationsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get notificationsTitle;

  /// No description provided for @notificationsReadAll.
  ///
  /// In ru, this message translates to:
  /// **'Прочитать все'**
  String get notificationsReadAll;

  /// No description provided for @notificationsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Уведомлений пока нет'**
  String get notificationsEmpty;

  /// No description provided for @notificationsLimitNote.
  ///
  /// In ru, this message translates to:
  /// **'Показаны последние {count} уведомлений'**
  String notificationsLimitNote(int count);

  /// No description provided for @mailFormatToolbar.
  ///
  /// In ru, this message translates to:
  /// **'Форматирование'**
  String get mailFormatToolbar;

  /// No description provided for @mailFormatBold.
  ///
  /// In ru, this message translates to:
  /// **'Жирный'**
  String get mailFormatBold;

  /// No description provided for @mailFormatItalic.
  ///
  /// In ru, this message translates to:
  /// **'Курсив'**
  String get mailFormatItalic;

  /// No description provided for @mailFormatUnderline.
  ///
  /// In ru, this message translates to:
  /// **'Подчёркнутый'**
  String get mailFormatUnderline;

  /// No description provided for @mailFormatBulletList.
  ///
  /// In ru, this message translates to:
  /// **'Маркированный список'**
  String get mailFormatBulletList;

  /// No description provided for @mailFormatNumberedList.
  ///
  /// In ru, this message translates to:
  /// **'Нумерованный список'**
  String get mailFormatNumberedList;

  /// No description provided for @mailFormatQuote.
  ///
  /// In ru, this message translates to:
  /// **'Цитата'**
  String get mailFormatQuote;

  /// No description provided for @mailFormatLink.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка'**
  String get mailFormatLink;

  /// No description provided for @mailFormatTextColor.
  ///
  /// In ru, this message translates to:
  /// **'Цвет текста'**
  String get mailFormatTextColor;

  /// No description provided for @mailFormatHighlight.
  ///
  /// In ru, this message translates to:
  /// **'Цвет выделения'**
  String get mailFormatHighlight;

  /// No description provided for @mailFormatColorNone.
  ///
  /// In ru, this message translates to:
  /// **'Без цвета'**
  String get mailFormatColorNone;

  /// No description provided for @mailFormatTable.
  ///
  /// In ru, this message translates to:
  /// **'Таблица'**
  String get mailFormatTable;

  /// No description provided for @mailFormatPreview.
  ///
  /// In ru, this message translates to:
  /// **'Предпросмотр'**
  String get mailFormatPreview;

  /// No description provided for @mailFormatEdit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get mailFormatEdit;

  /// No description provided for @mailFormatHelp.
  ///
  /// In ru, this message translates to:
  /// **'**жирный**  _курсив_  __подчёркнутый__  - список  1. список  > цитата  [текст](https://…)'**
  String get mailFormatHelp;

  /// No description provided for @mailPreviewEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Письмо пока пустое'**
  String get mailPreviewEmpty;

  /// No description provided for @mailLinkDialogTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вставить ссылку'**
  String get mailLinkDialogTitle;

  /// No description provided for @mailLinkUrl.
  ///
  /// In ru, this message translates to:
  /// **'Адрес ссылки'**
  String get mailLinkUrl;

  /// No description provided for @mailLinkUrlHint.
  ///
  /// In ru, this message translates to:
  /// **'https://… или mailto:…'**
  String get mailLinkUrlHint;

  /// No description provided for @mailLinkText.
  ///
  /// In ru, this message translates to:
  /// **'Текст ссылки'**
  String get mailLinkText;

  /// No description provided for @mailLinkInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Допустимы только ссылки https://, http:// и mailto:'**
  String get mailLinkInvalid;

  /// No description provided for @mailLinkInsert.
  ///
  /// In ru, this message translates to:
  /// **'Вставить'**
  String get mailLinkInsert;

  /// No description provided for @mailSignaturePreviewTitle.
  ///
  /// In ru, this message translates to:
  /// **'При отправке сервер добавит подпись:'**
  String get mailSignaturePreviewTitle;

  /// No description provided for @mailSignaturePreviewNote.
  ///
  /// In ru, this message translates to:
  /// **'Предварительный вид: для ответов и внешних адресатов правила организации могут отличаться.'**
  String get mailSignaturePreviewNote;

  /// No description provided for @mailThreadsMode.
  ///
  /// In ru, this message translates to:
  /// **'Цепочки писем'**
  String get mailThreadsMode;

  /// No description provided for @mailSettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки почты'**
  String get mailSettingsTitle;

  /// No description provided for @mailSettingsSignature.
  ///
  /// In ru, this message translates to:
  /// **'Подпись'**
  String get mailSettingsSignature;

  /// No description provided for @mailSettingsSignatureSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Личная подпись в письмах'**
  String get mailSettingsSignatureSubtitle;

  /// No description provided for @mailSettingsVacation.
  ///
  /// In ru, this message translates to:
  /// **'Автоответ'**
  String get mailSettingsVacation;

  /// No description provided for @mailSettingsVacationSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Ответ, пока вас нет на месте'**
  String get mailSettingsVacationSubtitle;

  /// No description provided for @mailSettingsBlocked.
  ///
  /// In ru, this message translates to:
  /// **'Заблокированные отправители'**
  String get mailSettingsBlocked;

  /// No description provided for @mailSettingsBlockedSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Их письма попадают в «Спам»'**
  String get mailSettingsBlockedSubtitle;

  /// No description provided for @mailSettingsBookmarkFolders.
  ///
  /// In ru, this message translates to:
  /// **'Папки закладок'**
  String get mailSettingsBookmarkFolders;

  /// No description provided for @mailSettingsBookmarkFoldersSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Подборки помеченных писем'**
  String get mailSettingsBookmarkFoldersSubtitle;

  /// No description provided for @mailSettingsSaved.
  ///
  /// In ru, this message translates to:
  /// **'Сохранено'**
  String get mailSettingsSaved;

  /// No description provided for @mailSignatureLabel.
  ///
  /// In ru, this message translates to:
  /// **'Текст подписи'**
  String get mailSignatureLabel;

  /// No description provided for @mailSignatureDefaultNote.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас используется подпись по умолчанию.'**
  String get mailSignatureDefaultNote;

  /// No description provided for @mailSignatureRestoreDefault.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть подпись по умолчанию'**
  String get mailSignatureRestoreDefault;

  /// No description provided for @mailSignatureTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Подпись длиннее 2000 байт.'**
  String get mailSignatureTooLong;

  /// No description provided for @mailSignatureBytes.
  ///
  /// In ru, this message translates to:
  /// **'{used} / {max} байт'**
  String mailSignatureBytes(int used, int max);

  /// No description provided for @mailSignatureNotApplied.
  ///
  /// In ru, this message translates to:
  /// **'Организация сейчас не добавляет личную подпись к письмам.'**
  String get mailSignatureNotApplied;

  /// No description provided for @mailVacationEnabled.
  ///
  /// In ru, this message translates to:
  /// **'Автоответ включён'**
  String get mailVacationEnabled;

  /// No description provided for @mailVacationSubject.
  ///
  /// In ru, this message translates to:
  /// **'Тема (необязательно)'**
  String get mailVacationSubject;

  /// No description provided for @mailVacationBody.
  ///
  /// In ru, this message translates to:
  /// **'Текст автоответа'**
  String get mailVacationBody;

  /// No description provided for @mailVacationStartsOn.
  ///
  /// In ru, this message translates to:
  /// **'Начало'**
  String get mailVacationStartsOn;

  /// No description provided for @mailVacationEndsOn.
  ///
  /// In ru, this message translates to:
  /// **'Окончание'**
  String get mailVacationEndsOn;

  /// No description provided for @mailVacationNoDate.
  ///
  /// In ru, this message translates to:
  /// **'Без даты'**
  String get mailVacationNoDate;

  /// No description provided for @mailVacationClearDate.
  ///
  /// In ru, this message translates to:
  /// **'Убрать дату'**
  String get mailVacationClearDate;

  /// No description provided for @mailVacationTimeZone.
  ///
  /// In ru, this message translates to:
  /// **'Часовой пояс'**
  String get mailVacationTimeZone;

  /// No description provided for @mailVacationActiveNow.
  ///
  /// In ru, this message translates to:
  /// **'Автоответ отправляется сейчас'**
  String get mailVacationActiveNow;

  /// No description provided for @mailVacationPending.
  ///
  /// In ru, this message translates to:
  /// **'Автоответ начнёт отправляться с даты начала'**
  String get mailVacationPending;

  /// No description provided for @mailVacationInactive.
  ///
  /// In ru, this message translates to:
  /// **'Автоответ не отправляется'**
  String get mailVacationInactive;

  /// No description provided for @mailVacationNote.
  ///
  /// In ru, this message translates to:
  /// **'Ответ получают внешние отправители, каждый не чаще раза в 3 дня.'**
  String get mailVacationNote;

  /// No description provided for @mailVacationBodyRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите текст автоответа.'**
  String get mailVacationBodyRequired;

  /// No description provided for @mailVacationSubjectTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Тема длиннее 200 символов.'**
  String get mailVacationSubjectTooLong;

  /// No description provided for @mailVacationBodyTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Текст длиннее 4000 символов.'**
  String get mailVacationBodyTooLong;

  /// No description provided for @mailVacationDatesInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Окончание не может быть раньше начала.'**
  String get mailVacationDatesInvalid;

  /// No description provided for @mailVacationTimeZoneInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Неизвестный часовой пояс.'**
  String get mailVacationTimeZoneInvalid;

  /// No description provided for @mailSyncPending.
  ///
  /// In ru, this message translates to:
  /// **'Изменения применяются на почтовом сервере…'**
  String get mailSyncPending;

  /// No description provided for @mailSyncFailed.
  ///
  /// In ru, this message translates to:
  /// **'Почтовый сервер не принял изменения. Сохраните ещё раз.'**
  String get mailSyncFailed;

  /// No description provided for @mailBlockedEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Заблокированных отправителей нет'**
  String get mailBlockedEmpty;

  /// No description provided for @mailBlockedAdd.
  ///
  /// In ru, this message translates to:
  /// **'Заблокировать'**
  String get mailBlockedAdd;

  /// No description provided for @mailBlockedAddTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заблокировать отправителя'**
  String get mailBlockedAddTitle;

  /// No description provided for @mailBlockedValue.
  ///
  /// In ru, this message translates to:
  /// **'Домен, адрес, IP или сеть'**
  String get mailBlockedValue;

  /// No description provided for @mailBlockedValueHint.
  ///
  /// In ru, this message translates to:
  /// **'example.com, 203.0.113.7, 198.51.100.0/24'**
  String get mailBlockedValueHint;

  /// No description provided for @mailBlockedNote.
  ///
  /// In ru, this message translates to:
  /// **'Заметка (необязательно)'**
  String get mailBlockedNote;

  /// No description provided for @mailBlockedRemoveTitle.
  ///
  /// In ru, this message translates to:
  /// **'Разблокировать {pattern}?'**
  String mailBlockedRemoveTitle(String pattern);

  /// No description provided for @mailBlockedRemove.
  ///
  /// In ru, this message translates to:
  /// **'Разблокировать'**
  String get mailBlockedRemove;

  /// No description provided for @mailBlockedCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} из {limit}'**
  String mailBlockedCount(int count, int limit);

  /// No description provided for @mailBlockedKindDomain.
  ///
  /// In ru, this message translates to:
  /// **'Домен'**
  String get mailBlockedKindDomain;

  /// No description provided for @mailBlockedKindIp.
  ///
  /// In ru, this message translates to:
  /// **'IP-адрес'**
  String get mailBlockedKindIp;

  /// No description provided for @mailBlockedKindNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Сеть'**
  String get mailBlockedKindNetwork;

  /// No description provided for @mailBookmarkFoldersEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Папок закладок пока нет'**
  String get mailBookmarkFoldersEmpty;

  /// No description provided for @mailBookmarkFolderCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать папку'**
  String get mailBookmarkFolderCreate;

  /// No description provided for @mailBookmarkFolderName.
  ///
  /// In ru, this message translates to:
  /// **'Название папки'**
  String get mailBookmarkFolderName;

  /// No description provided for @mailBookmarkFolderNameInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Название — от 1 до 80 символов.'**
  String get mailBookmarkFolderNameInvalid;

  /// No description provided for @mailBookmarkFolderDeleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить папку «{name}»?'**
  String mailBookmarkFolderDeleteTitle(String name);

  /// No description provided for @mailBookmarkFolderDeleteBody.
  ///
  /// In ru, this message translates to:
  /// **'Письма останутся в своих папках и сохранят закладку.'**
  String get mailBookmarkFolderDeleteBody;

  /// No description provided for @mailErrFolderExists.
  ///
  /// In ru, this message translates to:
  /// **'Папка с таким названием уже есть.'**
  String get mailErrFolderExists;

  /// No description provided for @mailErrInvalidList.
  ///
  /// In ru, this message translates to:
  /// **'Можно только блокировать отправителей.'**
  String get mailErrInvalidList;

  /// No description provided for @mailErrEmptyPattern.
  ///
  /// In ru, this message translates to:
  /// **'Укажите домен, адрес, IP или сеть.'**
  String get mailErrEmptyPattern;

  /// No description provided for @mailErrTopLevelDomain.
  ///
  /// In ru, this message translates to:
  /// **'Нельзя заблокировать всю доменную зону.'**
  String get mailErrTopLevelDomain;

  /// No description provided for @mailErrNetworkTooWide.
  ///
  /// In ru, this message translates to:
  /// **'Сеть слишком широкая: допускается не шире /8.'**
  String get mailErrNetworkTooWide;

  /// No description provided for @mailErrIpv6Network.
  ///
  /// In ru, this message translates to:
  /// **'Диапазоны IPv6 не поддерживаются — укажите точный адрес.'**
  String get mailErrIpv6Network;

  /// No description provided for @mailErrInvalidPattern.
  ///
  /// In ru, this message translates to:
  /// **'Это не домен, адрес, IP или сеть.'**
  String get mailErrInvalidPattern;

  /// No description provided for @mailErrNoteTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Заметка длиннее 200 символов.'**
  String get mailErrNoteTooLong;

  /// No description provided for @mailErrRuleLimit.
  ///
  /// In ru, this message translates to:
  /// **'Достигнут лимит в 500 записей.'**
  String get mailErrRuleLimit;

  /// No description provided for @mailErrRuleExists.
  ///
  /// In ru, this message translates to:
  /// **'Этот отправитель уже заблокирован.'**
  String get mailErrRuleExists;

  /// No description provided for @mailErrRuleNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Запись уже удалена.'**
  String get mailErrRuleNotFound;

  /// No description provided for @mailErrIcsNotFound.
  ///
  /// In ru, this message translates to:
  /// **'В письме не найдено приглашение.'**
  String get mailErrIcsNotFound;

  /// No description provided for @mailErrIcsTooLarge.
  ///
  /// In ru, this message translates to:
  /// **'Файл приглашения слишком большой.'**
  String get mailErrIcsTooLarge;

  /// No description provided for @mailErrInvalidIcs.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прочитать приглашение.'**
  String get mailErrInvalidIcs;

  /// No description provided for @mailErrInvalidRsvp.
  ///
  /// In ru, this message translates to:
  /// **'Недопустимый ответ на приглашение.'**
  String get mailErrInvalidRsvp;

  /// No description provided for @mailReportPhishing.
  ///
  /// In ru, this message translates to:
  /// **'Сообщить о фишинге'**
  String get mailReportPhishing;

  /// No description provided for @mailReportPhishingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сообщить о фишинге?'**
  String get mailReportPhishingTitle;

  /// No description provided for @mailReportPhishingBody.
  ///
  /// In ru, this message translates to:
  /// **'Письмо переместится в «Спам» и будет отправлено на проверку. Не переходите по ссылкам из него и не открывайте вложения.'**
  String get mailReportPhishingBody;

  /// No description provided for @mailReportPhishingConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Сообщить'**
  String get mailReportPhishingConfirm;

  /// No description provided for @mailReportedPhishing.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение о фишинге отправлено'**
  String get mailReportedPhishing;

  /// No description provided for @mailDeliveryStatus.
  ///
  /// In ru, this message translates to:
  /// **'Статус доставки'**
  String get mailDeliveryStatus;

  /// No description provided for @mailDeliveryEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных о доставке: письмо отправлено не через платформу.'**
  String get mailDeliveryEmpty;

  /// No description provided for @mailDeliveryRecipients.
  ///
  /// In ru, this message translates to:
  /// **'Получатели'**
  String get mailDeliveryRecipients;

  /// No description provided for @mailDeliveryHistory.
  ///
  /// In ru, this message translates to:
  /// **'История'**
  String get mailDeliveryHistory;

  /// No description provided for @mailDeliveryStateAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Принято'**
  String get mailDeliveryStateAccepted;

  /// No description provided for @mailDeliveryStateProcessing.
  ///
  /// In ru, this message translates to:
  /// **'Обрабатывается'**
  String get mailDeliveryStateProcessing;

  /// No description provided for @mailDeliveryStateDelivered.
  ///
  /// In ru, this message translates to:
  /// **'Доставлено'**
  String get mailDeliveryStateDelivered;

  /// No description provided for @mailDeliveryStatePartiallyDelivered.
  ///
  /// In ru, this message translates to:
  /// **'Доставлено частично'**
  String get mailDeliveryStatePartiallyDelivered;

  /// No description provided for @mailDeliveryStateFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не доставлено'**
  String get mailDeliveryStateFailed;

  /// No description provided for @mailDeliveryStateQuarantined.
  ///
  /// In ru, this message translates to:
  /// **'В карантине'**
  String get mailDeliveryStateQuarantined;

  /// No description provided for @mailDeliveryStatePending.
  ///
  /// In ru, this message translates to:
  /// **'Ожидает'**
  String get mailDeliveryStatePending;

  /// No description provided for @mailDeliveryStateRelayed.
  ///
  /// In ru, this message translates to:
  /// **'Передано внешнему серверу'**
  String get mailDeliveryStateRelayed;

  /// No description provided for @mailDeliveryStateDraft.
  ///
  /// In ru, this message translates to:
  /// **'Черновик'**
  String get mailDeliveryStateDraft;

  /// No description provided for @mailDeliveryEventAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Принято к отправке'**
  String get mailDeliveryEventAccepted;

  /// No description provided for @mailDeliveryEventScanned.
  ///
  /// In ru, this message translates to:
  /// **'Проверено'**
  String get mailDeliveryEventScanned;

  /// No description provided for @mailDeliveryEventDeliveredLocal.
  ///
  /// In ru, this message translates to:
  /// **'Доставлено в ящик'**
  String get mailDeliveryEventDeliveredLocal;

  /// No description provided for @mailDeliveryEventRelayed.
  ///
  /// In ru, this message translates to:
  /// **'Передано внешнему серверу'**
  String get mailDeliveryEventRelayed;

  /// No description provided for @mailDeliveryEventFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка доставки'**
  String get mailDeliveryEventFailed;

  /// No description provided for @mailInviteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Приглашение в календарь'**
  String get mailInviteTitle;

  /// No description provided for @mailInviteMethodRequest.
  ///
  /// In ru, this message translates to:
  /// **'Приглашение'**
  String get mailInviteMethodRequest;

  /// No description provided for @mailInviteMethodCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена события'**
  String get mailInviteMethodCancel;

  /// No description provided for @mailInviteMethodReply.
  ///
  /// In ru, this message translates to:
  /// **'Ответ участника'**
  String get mailInviteMethodReply;

  /// No description provided for @mailInviteOrganizer.
  ///
  /// In ru, this message translates to:
  /// **'Организатор: {name}'**
  String mailInviteOrganizer(String name);

  /// No description provided for @mailInviteYourStatus.
  ///
  /// In ru, this message translates to:
  /// **'Ваш ответ: {status}'**
  String mailInviteYourStatus(String status);

  /// No description provided for @mailInviteStatusAccepted.
  ///
  /// In ru, this message translates to:
  /// **'принято'**
  String get mailInviteStatusAccepted;

  /// No description provided for @mailInviteStatusTentative.
  ///
  /// In ru, this message translates to:
  /// **'возможно'**
  String get mailInviteStatusTentative;

  /// No description provided for @mailInviteStatusDeclined.
  ///
  /// In ru, this message translates to:
  /// **'отклонено'**
  String get mailInviteStatusDeclined;

  /// No description provided for @mailInviteStatusPending.
  ///
  /// In ru, this message translates to:
  /// **'нет ответа'**
  String get mailInviteStatusPending;

  /// No description provided for @mailInviteAccept.
  ///
  /// In ru, this message translates to:
  /// **'Приму'**
  String get mailInviteAccept;

  /// No description provided for @mailInviteMaybe.
  ///
  /// In ru, this message translates to:
  /// **'Возможно'**
  String get mailInviteMaybe;

  /// No description provided for @mailInviteDecline.
  ///
  /// In ru, this message translates to:
  /// **'Отклоню'**
  String get mailInviteDecline;

  /// No description provided for @mailInviteCancelledNote.
  ///
  /// In ru, this message translates to:
  /// **'Организатор отменил событие.'**
  String get mailInviteCancelledNote;

  /// No description provided for @mailInviteApplyCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отметить отмену в календаре'**
  String get mailInviteApplyCancel;

  /// No description provided for @mailInviteReplyFrom.
  ///
  /// In ru, this message translates to:
  /// **'{who} ответил(а): {status}'**
  String mailInviteReplyFrom(String who, String status);

  /// No description provided for @mailInviteApplyReply.
  ///
  /// In ru, this message translates to:
  /// **'Обновить ответ в календаре'**
  String get mailInviteApplyReply;

  /// No description provided for @mailInviteOpenCalendar.
  ///
  /// In ru, this message translates to:
  /// **'Открыть в календаре'**
  String get mailInviteOpenCalendar;

  /// No description provided for @mailInviteSaved.
  ///
  /// In ru, this message translates to:
  /// **'Ответ сохранён в календаре'**
  String get mailInviteSaved;

  /// No description provided for @mailInviteRecurring.
  ///
  /// In ru, this message translates to:
  /// **'Повторяющееся событие'**
  String get mailInviteRecurring;

  /// No description provided for @mailInviteInZone.
  ///
  /// In ru, this message translates to:
  /// **'{time} ({zone})'**
  String mailInviteInZone(String time, String zone);

  /// No description provided for @chatDraft.
  ///
  /// In ru, this message translates to:
  /// **'Черновик'**
  String get chatDraft;

  /// No description provided for @chatUnreadMessages.
  ///
  /// In ru, this message translates to:
  /// **'Непрочитанные сообщения'**
  String get chatUnreadMessages;

  /// No description provided for @chatScrollToBottom.
  ///
  /// In ru, this message translates to:
  /// **'Вниз'**
  String get chatScrollToBottom;

  /// No description provided for @chatForwardedFrom.
  ///
  /// In ru, this message translates to:
  /// **'Переслано от {name}'**
  String chatForwardedFrom(String name);

  /// No description provided for @chatSelect.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать'**
  String get chatSelect;

  /// No description provided for @chatDeleteSelected.
  ///
  /// In ru, this message translates to:
  /// **'Удалить сообщения: {count}?'**
  String chatDeleteSelected(int count);

  /// No description provided for @chatSearchInChat.
  ///
  /// In ru, this message translates to:
  /// **'Поиск в чате'**
  String get chatSearchInChat;

  /// No description provided for @chatSearchNoResults.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get chatSearchNoResults;

  /// No description provided for @chatSearchPosition.
  ///
  /// In ru, this message translates to:
  /// **'{current} из {total}'**
  String chatSearchPosition(int current, int total);

  /// No description provided for @chatMessageNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение недоступно'**
  String get chatMessageNotFound;

  /// No description provided for @chatAttachCamera.
  ///
  /// In ru, this message translates to:
  /// **'Камера'**
  String get chatAttachCamera;

  /// No description provided for @chatAttachGallery.
  ///
  /// In ru, this message translates to:
  /// **'Галерея'**
  String get chatAttachGallery;

  /// No description provided for @chatMoreReactions.
  ///
  /// In ru, this message translates to:
  /// **'Другие реакции'**
  String get chatMoreReactions;

  /// No description provided for @chatEmojiRecent.
  ///
  /// In ru, this message translates to:
  /// **'Недавние'**
  String get chatEmojiRecent;

  /// No description provided for @chatEmojiAll.
  ///
  /// In ru, this message translates to:
  /// **'Все эмодзи'**
  String get chatEmojiAll;

  /// No description provided for @chatMessageInfo.
  ///
  /// In ru, this message translates to:
  /// **'Информация о сообщении'**
  String get chatMessageInfo;

  /// No description provided for @chatReadBy.
  ///
  /// In ru, this message translates to:
  /// **'Прочитали'**
  String get chatReadBy;

  /// No description provided for @chatNoReceipts.
  ///
  /// In ru, this message translates to:
  /// **'Пока никто не прочитал'**
  String get chatNoReceipts;

  /// No description provided for @chatFilterAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get chatFilterAll;

  /// No description provided for @chatFilterUnread.
  ///
  /// In ru, this message translates to:
  /// **'Непрочитанные'**
  String get chatFilterUnread;

  /// No description provided for @chatFilterGroups.
  ///
  /// In ru, this message translates to:
  /// **'Группы'**
  String get chatFilterGroups;

  /// No description provided for @chatEmptyFilter.
  ///
  /// In ru, this message translates to:
  /// **'Здесь пока пусто'**
  String get chatEmptyFilter;

  /// No description provided for @chatArchivedEmpty.
  ///
  /// In ru, this message translates to:
  /// **'В архиве нет чатов'**
  String get chatArchivedEmpty;

  /// No description provided for @chatSelectConversation.
  ///
  /// In ru, this message translates to:
  /// **'Выберите чат, чтобы начать переписку'**
  String get chatSelectConversation;

  /// No description provided for @chatRemoveAdmin.
  ///
  /// In ru, this message translates to:
  /// **'Снять права админа'**
  String get chatRemoveAdmin;

  /// No description provided for @chatOpenExternally.
  ///
  /// In ru, this message translates to:
  /// **'Открыть в другом приложении'**
  String get chatOpenExternally;

  /// No description provided for @chatPlaybackSpeed.
  ///
  /// In ru, this message translates to:
  /// **'Скорость воспроизведения'**
  String get chatPlaybackSpeed;

  /// No description provided for @chatTypingShort.
  ///
  /// In ru, this message translates to:
  /// **'печатает…'**
  String get chatTypingShort;

  /// No description provided for @chatRecordingShort.
  ///
  /// In ru, this message translates to:
  /// **'записывает голосовое…'**
  String get chatRecordingShort;

  /// No description provided for @chatEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Напишите первое сообщение'**
  String get chatEmptyHint;

  /// No description provided for @chatSaved.
  ///
  /// In ru, this message translates to:
  /// **'Избранное'**
  String get chatSaved;

  /// No description provided for @chatSavedHint.
  ///
  /// In ru, this message translates to:
  /// **'Заметки и файлы только для вас'**
  String get chatSavedHint;

  /// No description provided for @chatSaveToSaved.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить в Избранное'**
  String get chatSaveToSaved;

  /// No description provided for @chatSavedDone.
  ///
  /// In ru, this message translates to:
  /// **'Сохранено в Избранное'**
  String get chatSavedDone;

  /// No description provided for @chatDeleteForMe.
  ///
  /// In ru, this message translates to:
  /// **'Удалить у меня'**
  String get chatDeleteForMe;

  /// No description provided for @chatDeleteForAll.
  ///
  /// In ru, this message translates to:
  /// **'Удалить у всех'**
  String get chatDeleteForAll;

  /// No description provided for @chatMarkUnread.
  ///
  /// In ru, this message translates to:
  /// **'Пометить как непрочитанное'**
  String get chatMarkUnread;

  /// No description provided for @chatMarkRead.
  ///
  /// In ru, this message translates to:
  /// **'Пометить как прочитанное'**
  String get chatMarkRead;

  /// No description provided for @chatUnreadShort.
  ///
  /// In ru, this message translates to:
  /// **'Непрочит.'**
  String get chatUnreadShort;

  /// No description provided for @chatReadShort.
  ///
  /// In ru, this message translates to:
  /// **'Прочитано'**
  String get chatReadShort;

  /// No description provided for @chatDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get chatDescription;

  /// No description provided for @chatDescriptionAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить описание'**
  String get chatDescriptionAdd;

  /// No description provided for @chatDescriptionEdit.
  ///
  /// In ru, this message translates to:
  /// **'Изменить описание'**
  String get chatDescriptionEdit;

  /// No description provided for @chatDescriptionTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Не больше 500 символов'**
  String get chatDescriptionTooLong;

  /// No description provided for @chatSystemDescriptionChanged.
  ///
  /// In ru, this message translates to:
  /// **'{actor} изменил(а) описание группы'**
  String chatSystemDescriptionChanged(String actor);

  /// No description provided for @chatMediaFilesLinks.
  ///
  /// In ru, this message translates to:
  /// **'Медиа, файлы и ссылки'**
  String get chatMediaFilesLinks;

  /// No description provided for @chatMediaTabMedia.
  ///
  /// In ru, this message translates to:
  /// **'Медиа'**
  String get chatMediaTabMedia;

  /// No description provided for @chatMediaTabFiles.
  ///
  /// In ru, this message translates to:
  /// **'Файлы'**
  String get chatMediaTabFiles;

  /// No description provided for @chatMediaTabLinks.
  ///
  /// In ru, this message translates to:
  /// **'Ссылки'**
  String get chatMediaTabLinks;

  /// No description provided for @chatMediaTabVoice.
  ///
  /// In ru, this message translates to:
  /// **'Голосовые'**
  String get chatMediaTabVoice;

  /// No description provided for @chatMediaEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Здесь пока ничего нет'**
  String get chatMediaEmpty;

  /// No description provided for @chatShowInChat.
  ///
  /// In ru, this message translates to:
  /// **'Показать в чате'**
  String get chatShowInChat;

  /// No description provided for @chatShareTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отправить в чат'**
  String get chatShareTitle;

  /// No description provided for @chatShareRecent.
  ///
  /// In ru, this message translates to:
  /// **'Недавние чаты'**
  String get chatShareRecent;

  /// No description provided for @chatShareNothing.
  ///
  /// In ru, this message translates to:
  /// **'Нечего отправить'**
  String get chatShareNothing;

  /// No description provided for @chatShareFiles.
  ///
  /// In ru, this message translates to:
  /// **'Вложений: {count}'**
  String chatShareFiles(int count);

  /// No description provided for @chatRemoveAttachment.
  ///
  /// In ru, this message translates to:
  /// **'Убрать вложение'**
  String get chatRemoveAttachment;

  /// No description provided for @chatVideoPlay.
  ///
  /// In ru, this message translates to:
  /// **'Воспроизвести'**
  String get chatVideoPlay;

  /// No description provided for @chatVideoPause.
  ///
  /// In ru, this message translates to:
  /// **'Пауза'**
  String get chatVideoPause;

  /// No description provided for @chatVideoMute.
  ///
  /// In ru, this message translates to:
  /// **'Выключить звук'**
  String get chatVideoMute;

  /// No description provided for @chatVideoUnmute.
  ///
  /// In ru, this message translates to:
  /// **'Включить звук'**
  String get chatVideoUnmute;

  /// No description provided for @chatVideoFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось воспроизвести видео'**
  String get chatVideoFailed;

  /// No description provided for @homeWidgetUnread.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} непрочитанный} few{{count} непрочитанных} many{{count} непрочитанных} other{{count} непрочитанных}}'**
  String homeWidgetUnread(int count);

  /// No description provided for @homeWidgetNoUnread.
  ///
  /// In ru, this message translates to:
  /// **'Нет непрочитанных'**
  String get homeWidgetNoUnread;

  /// No description provided for @homeWidgetNoEvents.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня событий больше нет'**
  String get homeWidgetNoEvents;

  /// No description provided for @homeWidgetSignIn.
  ///
  /// In ru, this message translates to:
  /// **'Войдите в XatBox'**
  String get homeWidgetSignIn;

  /// No description provided for @settingsWidgetSection.
  ///
  /// In ru, this message translates to:
  /// **'Виджет и ярлыки'**
  String get settingsWidgetSection;

  /// No description provided for @settingsWidgetPreview.
  ///
  /// In ru, this message translates to:
  /// **'Текст сообщений в виджете'**
  String get settingsWidgetPreview;

  /// No description provided for @settingsWidgetPreviewHint.
  ///
  /// In ru, this message translates to:
  /// **'Без этого виджет показывает только названия чатов. С блокировкой PIN-кодом или «Скрывать содержимое» — только число непрочитанных.'**
  String get settingsWidgetPreviewHint;

  /// No description provided for @shortcutNewMessage.
  ///
  /// In ru, this message translates to:
  /// **'Новое сообщение'**
  String get shortcutNewMessage;

  /// No description provided for @shortcutCall.
  ///
  /// In ru, this message translates to:
  /// **'Позвонить'**
  String get shortcutCall;

  /// No description provided for @shortcutSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get shortcutSearch;

  /// No description provided for @savedChatOpenFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть Избранное'**
  String get savedChatOpenFailed;

  /// No description provided for @updateTitle.
  ///
  /// In ru, this message translates to:
  /// **'Обновление приложения'**
  String get updateTitle;

  /// No description provided for @updateCurrentVersion.
  ///
  /// In ru, this message translates to:
  /// **'Установлена версия {version}'**
  String updateCurrentVersion(String version);

  /// No description provided for @updateNewVersion.
  ///
  /// In ru, this message translates to:
  /// **'Версия {version}'**
  String updateNewVersion(String version);

  /// No description provided for @updateAvailableTitle.
  ///
  /// In ru, this message translates to:
  /// **'Доступно обновление'**
  String get updateAvailableTitle;

  /// No description provided for @updateMandatoryTitle.
  ///
  /// In ru, this message translates to:
  /// **'Нужно обновить XatBox'**
  String get updateMandatoryTitle;

  /// No description provided for @updateMandatoryBody.
  ///
  /// In ru, this message translates to:
  /// **'Эта версия больше не поддерживается сервером. Обновление займёт минуту — чаты, почта и настройки сохранятся.'**
  String get updateMandatoryBody;

  /// No description provided for @updateUpToDate.
  ///
  /// In ru, this message translates to:
  /// **'У вас последняя версия'**
  String get updateUpToDate;

  /// No description provided for @updateCheckedAt.
  ///
  /// In ru, this message translates to:
  /// **'Проверено {time}'**
  String updateCheckedAt(String time);

  /// No description provided for @updateCheck.
  ///
  /// In ru, this message translates to:
  /// **'Проверить обновления'**
  String get updateCheck;

  /// No description provided for @updateChecking.
  ///
  /// In ru, this message translates to:
  /// **'Проверяем обновления…'**
  String get updateChecking;

  /// No description provided for @updateCheckFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось проверить обновления'**
  String get updateCheckFailed;

  /// No description provided for @updateWhatsNew.
  ///
  /// In ru, this message translates to:
  /// **'Что нового'**
  String get updateWhatsNew;

  /// No description provided for @updateNoNotes.
  ///
  /// In ru, this message translates to:
  /// **'Исправления ошибок и улучшения стабильности.'**
  String get updateNoNotes;

  /// No description provided for @updateDownload.
  ///
  /// In ru, this message translates to:
  /// **'Скачать и установить'**
  String get updateDownload;

  /// No description provided for @updateDownloading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка… {percent}%'**
  String updateDownloading(int percent);

  /// No description provided for @updateDownloadedOf.
  ///
  /// In ru, this message translates to:
  /// **'{received} из {total}'**
  String updateDownloadedOf(String received, String total);

  /// No description provided for @updateCancel.
  ///
  /// In ru, this message translates to:
  /// **'Остановить загрузку'**
  String get updateCancel;

  /// No description provided for @updateResume.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить загрузку'**
  String get updateResume;

  /// No description provided for @updateInstall.
  ///
  /// In ru, this message translates to:
  /// **'Установить'**
  String get updateInstall;

  /// No description provided for @updateInstalling.
  ///
  /// In ru, this message translates to:
  /// **'Открыт установщик Android'**
  String get updateInstalling;

  /// No description provided for @updateInstallingHint.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердите установку. Если окно закрылось, нажмите «Установить» ещё раз.'**
  String get updateInstallingHint;

  /// No description provided for @updateLater.
  ///
  /// In ru, this message translates to:
  /// **'Позже'**
  String get updateLater;

  /// No description provided for @updatePermissionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Разрешите установку обновлений'**
  String get updatePermissionTitle;

  /// No description provided for @updatePermissionBody.
  ///
  /// In ru, this message translates to:
  /// **'Android один раз просит разрешить XatBox устанавливать приложения. Откройте настройки, включите «Разрешить установку из этого источника» и вернитесь — установка продолжится сама.'**
  String get updatePermissionBody;

  /// No description provided for @updatePermissionOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть настройки'**
  String get updatePermissionOpen;

  /// No description provided for @updateFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить обновление'**
  String get updateFailed;

  /// No description provided for @updateIntegrityFailed.
  ///
  /// In ru, this message translates to:
  /// **'Файл повредился при загрузке. Попробуйте ещё раз.'**
  String get updateIntegrityFailed;

  /// No description provided for @updateInstallFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть установщик Android'**
  String get updateInstallFailed;

  /// No description provided for @updateRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get updateRetry;

  /// No description provided for @updateIncompatible.
  ///
  /// In ru, this message translates to:
  /// **'Для этого устройства нет подходящего файла обновления. Обратитесь к администратору.'**
  String get updateIncompatible;

  /// No description provided for @updateUnsupported.
  ///
  /// In ru, this message translates to:
  /// **'Обновления приходят через сервер XatBox и доступны только на Android.'**
  String get updateUnsupported;

  /// No description provided for @updateSignOut.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта'**
  String get updateSignOut;

  /// No description provided for @updateSettingsAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Доступна версия {version}'**
  String updateSettingsAvailable(String version);

  /// No description provided for @updateBadgeNew.
  ///
  /// In ru, this message translates to:
  /// **'Новое'**
  String get updateBadgeNew;

  /// No description provided for @sessionsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Мои устройства и сеансы'**
  String get sessionsTitle;

  /// No description provided for @sessionsSettingsHint.
  ///
  /// In ru, this message translates to:
  /// **'Где выполнен вход в учётную запись'**
  String get sessionsSettingsHint;

  /// No description provided for @sessionsHint.
  ///
  /// In ru, this message translates to:
  /// **'Здесь все устройства, где выполнен вход в вашу учётную запись. Если не узнаёте устройство, завершите сеанс и смените пароль.'**
  String get sessionsHint;

  /// No description provided for @sessionsThisDevice.
  ///
  /// In ru, this message translates to:
  /// **'Это устройство'**
  String get sessionsThisDevice;

  /// No description provided for @sessionsOthers.
  ///
  /// In ru, this message translates to:
  /// **'Другие устройства'**
  String get sessionsOthers;

  /// No description provided for @sessionsNoOthers.
  ///
  /// In ru, this message translates to:
  /// **'Других активных сеансов нет'**
  String get sessionsNoOthers;

  /// No description provided for @sessionsActiveNow.
  ///
  /// In ru, this message translates to:
  /// **'Активно сейчас'**
  String get sessionsActiveNow;

  /// No description provided for @sessionsLastActive.
  ///
  /// In ru, this message translates to:
  /// **'Активность: {time}'**
  String sessionsLastActive(String time);

  /// No description provided for @sessionsSignedIn.
  ///
  /// In ru, this message translates to:
  /// **'Вход: {date}'**
  String sessionsSignedIn(String date);

  /// No description provided for @sessionsIp.
  ///
  /// In ru, this message translates to:
  /// **'IP-адрес {ip}'**
  String sessionsIp(String ip);

  /// No description provided for @sessionsEnd.
  ///
  /// In ru, this message translates to:
  /// **'Выйти на этом устройстве'**
  String get sessionsEnd;

  /// No description provided for @sessionsEndConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Завершить сеанс?'**
  String get sessionsEndConfirmTitle;

  /// No description provided for @sessionsEndConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'На устройстве «{device}» нужно будет снова войти по паролю, а данные XatBox на нём удалятся при следующем подключении.'**
  String sessionsEndConfirmBody(String device);

  /// No description provided for @sessionsEndOthers.
  ///
  /// In ru, this message translates to:
  /// **'Выйти на всех других устройствах'**
  String get sessionsEndOthers;

  /// No description provided for @sessionsEndOthersConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'Все устройства, кроме этого, будут отключены от учётной записи и удалят локальные данные XatBox.'**
  String get sessionsEndOthersConfirmBody;

  /// No description provided for @sessionsEnded.
  ///
  /// In ru, this message translates to:
  /// **'Сеанс завершён'**
  String get sessionsEnded;

  /// No description provided for @sessionsXatBoxApp.
  ///
  /// In ru, this message translates to:
  /// **'Приложение XatBox'**
  String get sessionsXatBoxApp;

  /// No description provided for @sessionsUnknownDevice.
  ///
  /// In ru, this message translates to:
  /// **'Неизвестное устройство'**
  String get sessionsUnknownDevice;

  /// No description provided for @aboutTitle.
  ///
  /// In ru, this message translates to:
  /// **'О приложении'**
  String get aboutTitle;

  /// No description provided for @aboutTagline.
  ///
  /// In ru, this message translates to:
  /// **'Почта, мессенджер и звонки в одном приложении'**
  String get aboutTagline;

  /// No description provided for @aboutVersion.
  ///
  /// In ru, this message translates to:
  /// **'Версия {version} · сборка {build}'**
  String aboutVersion(String version, String build);

  /// No description provided for @aboutAppSection.
  ///
  /// In ru, this message translates to:
  /// **'Приложение'**
  String get aboutAppSection;

  /// No description provided for @aboutServers.
  ///
  /// In ru, this message translates to:
  /// **'Серверы'**
  String get aboutServers;

  /// No description provided for @aboutServerMail.
  ///
  /// In ru, this message translates to:
  /// **'Почта'**
  String get aboutServerMail;

  /// No description provided for @aboutServerChat.
  ///
  /// In ru, this message translates to:
  /// **'Мессенджер'**
  String get aboutServerChat;

  /// No description provided for @aboutServerCalls.
  ///
  /// In ru, this message translates to:
  /// **'Звонки'**
  String get aboutServerCalls;

  /// No description provided for @aboutServerNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Не настроен'**
  String get aboutServerNotConfigured;

  /// No description provided for @aboutServerUnreachable.
  ///
  /// In ru, this message translates to:
  /// **'Недоступен'**
  String get aboutServerUnreachable;

  /// No description provided for @aboutServerDegraded.
  ///
  /// In ru, this message translates to:
  /// **'Работает с ошибками'**
  String get aboutServerDegraded;

  /// No description provided for @aboutServerLatency.
  ///
  /// In ru, this message translates to:
  /// **'{ms} мс'**
  String aboutServerLatency(int ms);

  /// No description provided for @aboutRecheck.
  ///
  /// In ru, this message translates to:
  /// **'Проверить снова'**
  String get aboutRecheck;

  /// No description provided for @aboutWhatsNew.
  ///
  /// In ru, this message translates to:
  /// **'Что нового'**
  String get aboutWhatsNew;

  /// No description provided for @aboutLicenses.
  ///
  /// In ru, this message translates to:
  /// **'Лицензии открытого ПО'**
  String get aboutLicenses;

  /// No description provided for @aboutPrivacy.
  ///
  /// In ru, this message translates to:
  /// **'Конфиденциальность'**
  String get aboutPrivacy;

  /// No description provided for @aboutPrivacyDataTitle.
  ///
  /// In ru, this message translates to:
  /// **'Где хранятся данные'**
  String get aboutPrivacyDataTitle;

  /// No description provided for @aboutPrivacyDataBody.
  ///
  /// In ru, this message translates to:
  /// **'Письма, чаты, файлы и записи звонков хранятся на серверах организации, а не у сторонних сервисов. На устройстве остаётся только кэш для работы без сети — он удаляется при выходе из аккаунта.'**
  String get aboutPrivacyDataBody;

  /// No description provided for @aboutPrivacyPushTitle.
  ///
  /// In ru, this message translates to:
  /// **'Зашифрованные уведомления'**
  String get aboutPrivacyPushTitle;

  /// No description provided for @aboutPrivacyPushBody.
  ///
  /// In ru, this message translates to:
  /// **'Текст уведомлений шифруется ключом, созданным на этом телефоне. Google и Apple доставляют только зашифрованный пакет и не видят, кто и что вам написал.'**
  String get aboutPrivacyPushBody;

  /// No description provided for @aboutPrivacyReportsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отчёты об ошибках'**
  String get aboutPrivacyReportsTitle;

  /// No description provided for @aboutPrivacyReportsBody.
  ///
  /// In ru, this message translates to:
  /// **'Отчёты о сбоях уходят только на сервер XatBox — без текстов сообщений, адресов и паролей. Их можно отключить в настройках.'**
  String get aboutPrivacyReportsBody;

  /// No description provided for @aboutPrivacyLockTitle.
  ///
  /// In ru, this message translates to:
  /// **'Блокировка приложения'**
  String get aboutPrivacyLockTitle;

  /// No description provided for @aboutPrivacyLockBody.
  ///
  /// In ru, this message translates to:
  /// **'PIN-код не хранится в открытом виде: в защищённом хранилище устройства лежит только его хеш с солью.'**
  String get aboutPrivacyLockBody;

  /// No description provided for @reportTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сообщить о проблеме'**
  String get reportTitle;

  /// No description provided for @reportCategory.
  ///
  /// In ru, this message translates to:
  /// **'Что случилось?'**
  String get reportCategory;

  /// No description provided for @reportCategoryBug.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get reportCategoryBug;

  /// No description provided for @reportCategoryIdea.
  ///
  /// In ru, this message translates to:
  /// **'Предложение'**
  String get reportCategoryIdea;

  /// No description provided for @reportCategoryQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Вопрос'**
  String get reportCategoryQuestion;

  /// No description provided for @reportCategoryOther.
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get reportCategoryOther;

  /// No description provided for @reportDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get reportDescription;

  /// No description provided for @reportDescriptionHint.
  ///
  /// In ru, this message translates to:
  /// **'Что вы делали и что пошло не так? Чем подробнее, тем быстрее исправим.'**
  String get reportDescriptionHint;

  /// No description provided for @reportScreenshot.
  ///
  /// In ru, this message translates to:
  /// **'Снимок экрана'**
  String get reportScreenshot;

  /// No description provided for @reportScreenshotAttach.
  ///
  /// In ru, this message translates to:
  /// **'Прикрепить изображение'**
  String get reportScreenshotAttach;

  /// No description provided for @reportScreenshotRemove.
  ///
  /// In ru, this message translates to:
  /// **'Убрать снимок'**
  String get reportScreenshotRemove;

  /// No description provided for @reportDiagnostics.
  ///
  /// In ru, this message translates to:
  /// **'Приложить диагностику'**
  String get reportDiagnostics;

  /// No description provided for @reportDiagnosticsHint.
  ///
  /// In ru, this message translates to:
  /// **'Версия, модель устройства и технический журнал без личных данных'**
  String get reportDiagnosticsHint;

  /// No description provided for @reportDiagnosticsShow.
  ///
  /// In ru, this message translates to:
  /// **'Что будет отправлено'**
  String get reportDiagnosticsShow;

  /// No description provided for @reportShake.
  ///
  /// In ru, this message translates to:
  /// **'Встряхнуть, чтобы сообщить о проблеме'**
  String get reportShake;

  /// No description provided for @reportShakeHint.
  ///
  /// In ru, this message translates to:
  /// **'Встряхните телефон на любом экране — откроется эта форма со снимком экрана'**
  String get reportShakeHint;

  /// No description provided for @reportSend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get reportSend;

  /// No description provided for @reportSentTitle.
  ///
  /// In ru, this message translates to:
  /// **'Спасибо!'**
  String get reportSentTitle;

  /// No description provided for @reportSent.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение отправлено. Мы разберёмся и, если нужно, свяжемся с вами.'**
  String get reportSent;

  /// No description provided for @reportDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get reportDone;

  /// No description provided for @reportRateLimited.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много сообщений подряд. Попробуйте через час.'**
  String get reportRateLimited;

  /// No description provided for @reportUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Отправка недоступна: сервер мессенджера не настроен.'**
  String get reportUnavailable;

  /// No description provided for @lockGreeting.
  ///
  /// In ru, this message translates to:
  /// **'Здравствуйте, {name}'**
  String lockGreeting(String name);

  /// No description provided for @lockReturnToCall.
  ///
  /// In ru, this message translates to:
  /// **'Вернуться к звонку'**
  String get lockReturnToCall;

  /// No description provided for @chatReport.
  ///
  /// In ru, this message translates to:
  /// **'Пожаловаться'**
  String get chatReport;

  /// No description provided for @chatReportTitle.
  ///
  /// In ru, this message translates to:
  /// **'Пожаловаться на сообщение'**
  String get chatReportTitle;

  /// No description provided for @chatReportReasonSpam.
  ///
  /// In ru, this message translates to:
  /// **'Спам'**
  String get chatReportReasonSpam;

  /// No description provided for @chatReportReasonAbuse.
  ///
  /// In ru, this message translates to:
  /// **'Оскорбление'**
  String get chatReportReasonAbuse;

  /// No description provided for @chatReportReasonConfidential.
  ///
  /// In ru, this message translates to:
  /// **'Конфиденциальные данные'**
  String get chatReportReasonConfidential;

  /// No description provided for @chatReportReasonOther.
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get chatReportReasonOther;

  /// No description provided for @chatReportComment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий (необязательно)'**
  String get chatReportComment;

  /// No description provided for @chatReportSend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить жалобу'**
  String get chatReportSend;

  /// No description provided for @chatReportSent.
  ///
  /// In ru, this message translates to:
  /// **'Жалоба отправлена. Модераторы её рассмотрят.'**
  String get chatReportSent;

  /// No description provided for @chatReportReviewed.
  ///
  /// In ru, this message translates to:
  /// **'Ваша жалоба рассмотрена. Спасибо!'**
  String get chatReportReviewed;

  /// No description provided for @chatReportPrivacyHint.
  ///
  /// In ru, this message translates to:
  /// **'Автор не узнает, кто пожаловался.'**
  String get chatReportPrivacyHint;

  /// No description provided for @chatForwardForbidden.
  ///
  /// In ru, this message translates to:
  /// **'Пересылка из этого чата запрещена'**
  String get chatForwardForbidden;

  /// No description provided for @chatMemberRestricted.
  ///
  /// In ru, this message translates to:
  /// **'Вам временно запрещено писать в этот чат'**
  String get chatMemberRestricted;

  /// No description provided for @chatSystemProtectionChanged.
  ///
  /// In ru, this message translates to:
  /// **'{actor} изменил(а) настройки защиты чата'**
  String chatSystemProtectionChanged(String actor);

  /// No description provided for @chatSystemModerationWarning.
  ///
  /// In ru, this message translates to:
  /// **'Модератор вынес предупреждение за нарушение правил'**
  String get chatSystemModerationWarning;

  /// No description provided for @chatSystemMemberRestricted.
  ///
  /// In ru, this message translates to:
  /// **'Участнику временно запрещено писать'**
  String get chatSystemMemberRestricted;

  /// No description provided for @chatProtection.
  ///
  /// In ru, this message translates to:
  /// **'Защита чата'**
  String get chatProtection;

  /// No description provided for @chatProtectionActive.
  ///
  /// In ru, this message translates to:
  /// **'Защита включена'**
  String get chatProtectionActive;

  /// No description provided for @chatProtectionNone.
  ///
  /// In ru, this message translates to:
  /// **'Защита не включена'**
  String get chatProtectionNone;

  /// No description provided for @chatProtectionNoForward.
  ///
  /// In ru, this message translates to:
  /// **'Запретить пересылку и копирование'**
  String get chatProtectionNoForward;

  /// No description provided for @chatProtectionNoForwardHint.
  ///
  /// In ru, this message translates to:
  /// **'Сообщения нельзя переслать, скопировать или сохранить'**
  String get chatProtectionNoForwardHint;

  /// No description provided for @chatProtectionScreenshots.
  ///
  /// In ru, this message translates to:
  /// **'Защита от скриншотов'**
  String get chatProtectionScreenshots;

  /// No description provided for @chatProtectionScreenshotsHint.
  ///
  /// In ru, this message translates to:
  /// **'На Android снимки и запись экрана блокируются, на iPhone чат скрывается при сворачивании'**
  String get chatProtectionScreenshotsHint;

  /// No description provided for @chatProtectionDisappearing.
  ///
  /// In ru, this message translates to:
  /// **'Исчезающие сообщения'**
  String get chatProtectionDisappearing;

  /// No description provided for @chatProtectionDisappearingHint.
  ///
  /// In ru, this message translates to:
  /// **'Новые сообщения удаляются у всех по таймеру'**
  String get chatProtectionDisappearingHint;

  /// No description provided for @chatProtectionAdminsOnly.
  ///
  /// In ru, this message translates to:
  /// **'Изменять защиту могут только администраторы'**
  String get chatProtectionAdminsOnly;

  /// No description provided for @chatProtectionPeerNotified.
  ///
  /// In ru, this message translates to:
  /// **'Собеседник увидит сообщение об изменении'**
  String get chatProtectionPeerNotified;

  /// No description provided for @chatProtectionMembersNotified.
  ///
  /// In ru, this message translates to:
  /// **'Участники увидят сообщение об изменении'**
  String get chatProtectionMembersNotified;

  /// No description provided for @chatDisappearingOff.
  ///
  /// In ru, this message translates to:
  /// **'Выкл.'**
  String get chatDisappearingOff;

  /// No description provided for @chatDisappearingDay.
  ///
  /// In ru, this message translates to:
  /// **'1 день'**
  String get chatDisappearingDay;

  /// No description provided for @chatDisappearingWeek.
  ///
  /// In ru, this message translates to:
  /// **'1 неделя'**
  String get chatDisappearingWeek;

  /// No description provided for @chatDisappearingMonth.
  ///
  /// In ru, this message translates to:
  /// **'1 месяц'**
  String get chatDisappearingMonth;

  /// No description provided for @chatDisappearingCustom.
  ///
  /// In ru, this message translates to:
  /// **'{hours} ч'**
  String chatDisappearingCustom(int hours);

  /// No description provided for @chatDisappearingMessage.
  ///
  /// In ru, this message translates to:
  /// **'Исчезающее сообщение'**
  String get chatDisappearingMessage;

  /// No description provided for @chatStickers.
  ///
  /// In ru, this message translates to:
  /// **'Эмодзи и стикеры'**
  String get chatStickers;

  /// No description provided for @chatEmoji.
  ///
  /// In ru, this message translates to:
  /// **'Эмодзи'**
  String get chatEmoji;

  /// No description provided for @chatStickersRecent.
  ///
  /// In ru, this message translates to:
  /// **'Недавние'**
  String get chatStickersRecent;

  /// No description provided for @chatStickersEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Стикеры пока недоступны'**
  String get chatStickersEmpty;

  /// No description provided for @chatAttachmentSticker.
  ///
  /// In ru, this message translates to:
  /// **'Стикер'**
  String get chatAttachmentSticker;

  /// No description provided for @chatStickerUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Стикер недоступен'**
  String get chatStickerUnavailable;

  /// No description provided for @chatTranscribe.
  ///
  /// In ru, this message translates to:
  /// **'Расшифровать'**
  String get chatTranscribe;

  /// No description provided for @chatTranscribing.
  ///
  /// In ru, this message translates to:
  /// **'Расшифровка…'**
  String get chatTranscribing;

  /// No description provided for @chatTranscriptFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось расшифровать'**
  String get chatTranscriptFailed;

  /// No description provided for @chatTranscriptRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get chatTranscriptRetry;

  /// No description provided for @chatTranscriptEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Речь не распознана'**
  String get chatTranscriptEmpty;

  /// No description provided for @chatTranscriptShow.
  ///
  /// In ru, this message translates to:
  /// **'Показать текст'**
  String get chatTranscriptShow;

  /// No description provided for @chatTranscriptHide.
  ///
  /// In ru, this message translates to:
  /// **'Текст'**
  String get chatTranscriptHide;

  /// No description provided for @chatTranscriptionBusy.
  ///
  /// In ru, this message translates to:
  /// **'Очередь расшифровки занята, попробуйте позже'**
  String get chatTranscriptionBusy;

  /// No description provided for @chatAutoTranscribe.
  ///
  /// In ru, this message translates to:
  /// **'Расшифровывать голосовые автоматически'**
  String get chatAutoTranscribe;

  /// No description provided for @chatAutoTranscribeHint.
  ///
  /// In ru, this message translates to:
  /// **'Расшифровка выполняется на сервере университета'**
  String get chatAutoTranscribeHint;

  /// No description provided for @moderationTitle.
  ///
  /// In ru, this message translates to:
  /// **'Модерация'**
  String get moderationTitle;

  /// No description provided for @moderationHint.
  ///
  /// In ru, this message translates to:
  /// **'Жалобы на сообщения'**
  String get moderationHint;

  /// No description provided for @moderationTabOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открытые'**
  String get moderationTabOpen;

  /// No description provided for @moderationTabResolved.
  ///
  /// In ru, this message translates to:
  /// **'Решённые'**
  String get moderationTabResolved;

  /// No description provided for @moderationTabDismissed.
  ///
  /// In ru, this message translates to:
  /// **'Отклонённые'**
  String get moderationTabDismissed;

  /// No description provided for @moderationEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Жалоб нет'**
  String get moderationEmpty;

  /// No description provided for @moderationEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Здесь появятся жалобы участников'**
  String get moderationEmptyHint;

  /// No description provided for @moderationGlobalScope.
  ///
  /// In ru, this message translates to:
  /// **'Все чаты организации'**
  String get moderationGlobalScope;

  /// No description provided for @moderationGroupScope.
  ///
  /// In ru, this message translates to:
  /// **'Группы, где вы администратор'**
  String get moderationGroupScope;

  /// No description provided for @moderationReport.
  ///
  /// In ru, this message translates to:
  /// **'Жалоба'**
  String get moderationReport;

  /// No description provided for @moderationReportFrom.
  ///
  /// In ru, this message translates to:
  /// **'Жалоба от {name}'**
  String moderationReportFrom(String name);

  /// No description provided for @moderationAuthor.
  ///
  /// In ru, this message translates to:
  /// **'Автор: {name}'**
  String moderationAuthor(String name);

  /// No description provided for @moderationDirectChat.
  ///
  /// In ru, this message translates to:
  /// **'Личный чат'**
  String get moderationDirectChat;

  /// No description provided for @moderationMember.
  ///
  /// In ru, this message translates to:
  /// **'Участник'**
  String get moderationMember;

  /// No description provided for @moderationContext.
  ///
  /// In ru, this message translates to:
  /// **'Контекст переписки'**
  String get moderationContext;

  /// No description provided for @moderationComment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий'**
  String get moderationComment;

  /// No description provided for @moderationActions.
  ///
  /// In ru, this message translates to:
  /// **'Действия'**
  String get moderationActions;

  /// No description provided for @moderationDeleteMessage.
  ///
  /// In ru, this message translates to:
  /// **'Удалить сообщение у всех'**
  String get moderationDeleteMessage;

  /// No description provided for @moderationWarn.
  ///
  /// In ru, this message translates to:
  /// **'Предупредить автора'**
  String get moderationWarn;

  /// No description provided for @moderationRemove.
  ///
  /// In ru, this message translates to:
  /// **'Исключить из группы'**
  String get moderationRemove;

  /// No description provided for @moderationMute.
  ///
  /// In ru, this message translates to:
  /// **'Запретить писать'**
  String get moderationMute;

  /// No description provided for @moderationMuteHours.
  ///
  /// In ru, this message translates to:
  /// **'На {hours} ч'**
  String moderationMuteHours(int hours);

  /// No description provided for @moderationDismiss.
  ///
  /// In ru, this message translates to:
  /// **'Отклонить жалобу'**
  String get moderationDismiss;

  /// No description provided for @moderationNote.
  ///
  /// In ru, this message translates to:
  /// **'Заметка для журнала (необязательно)'**
  String get moderationNote;

  /// No description provided for @moderationConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get moderationConfirm;

  /// No description provided for @moderationDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get moderationDone;

  /// No description provided for @moderationAlreadyHandled.
  ///
  /// In ru, this message translates to:
  /// **'Жалоба уже рассмотрена'**
  String get moderationAlreadyHandled;

  /// No description provided for @moderationResolution.
  ///
  /// In ru, this message translates to:
  /// **'Решение: {action}'**
  String moderationResolution(String action);

  /// No description provided for @moderationRestrictedUntil.
  ///
  /// In ru, this message translates to:
  /// **'Не может писать до {time}'**
  String moderationRestrictedUntil(String time);

  /// No description provided for @moderationNotMember.
  ///
  /// In ru, this message translates to:
  /// **'Уже не участник чата'**
  String get moderationNotMember;

  /// No description provided for @moderationDeletedContent.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение удалено'**
  String get moderationDeletedContent;

  /// No description provided for @statusTitle.
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get statusTitle;

  /// No description provided for @statusSet.
  ///
  /// In ru, this message translates to:
  /// **'Установить статус'**
  String get statusSet;

  /// No description provided for @statusNone.
  ///
  /// In ru, this message translates to:
  /// **'Статус не установлен'**
  String get statusNone;

  /// No description provided for @statusPresetInClass.
  ///
  /// In ru, this message translates to:
  /// **'На паре'**
  String get statusPresetInClass;

  /// No description provided for @statusPresetMeeting.
  ///
  /// In ru, this message translates to:
  /// **'На совещании'**
  String get statusPresetMeeting;

  /// No description provided for @statusPresetBusinessTrip.
  ///
  /// In ru, this message translates to:
  /// **'В командировке'**
  String get statusPresetBusinessTrip;

  /// No description provided for @statusPresetVacation.
  ///
  /// In ru, this message translates to:
  /// **'В отпуске'**
  String get statusPresetVacation;

  /// No description provided for @statusPresetSick.
  ///
  /// In ru, this message translates to:
  /// **'Болею'**
  String get statusPresetSick;

  /// No description provided for @statusPresetDnd.
  ///
  /// In ru, this message translates to:
  /// **'Не беспокоить'**
  String get statusPresetDnd;

  /// No description provided for @statusPresetCustom.
  ///
  /// In ru, this message translates to:
  /// **'Свой статус'**
  String get statusPresetCustom;

  /// No description provided for @statusTextLabel.
  ///
  /// In ru, this message translates to:
  /// **'Текст статуса'**
  String get statusTextLabel;

  /// No description provided for @statusEmojiPick.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать эмодзи статуса'**
  String get statusEmojiPick;

  /// No description provided for @statusUntilLabel.
  ///
  /// In ru, this message translates to:
  /// **'До'**
  String get statusUntilLabel;

  /// No description provided for @statusUntilNone.
  ///
  /// In ru, this message translates to:
  /// **'Без срока'**
  String get statusUntilNone;

  /// No description provided for @statusUntilHour.
  ///
  /// In ru, this message translates to:
  /// **'1 час'**
  String get statusUntilHour;

  /// No description provided for @statusUntilDay.
  ///
  /// In ru, this message translates to:
  /// **'До конца дня'**
  String get statusUntilDay;

  /// No description provided for @statusUntilWeek.
  ///
  /// In ru, this message translates to:
  /// **'До конца недели'**
  String get statusUntilWeek;

  /// No description provided for @statusUntilPick.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать дату и время'**
  String get statusUntilPick;

  /// No description provided for @statusUntilShort.
  ///
  /// In ru, this message translates to:
  /// **'до {time}'**
  String statusUntilShort(String time);

  /// No description provided for @statusAutoReplyLabel.
  ///
  /// In ru, this message translates to:
  /// **'Автоответ (необязательно)'**
  String get statusAutoReplyLabel;

  /// No description provided for @statusAutoReplyHint.
  ///
  /// In ru, this message translates to:
  /// **'Придёт в личном чате тому, кто вам напишет, — один раз в день на чат'**
  String get statusAutoReplyHint;

  /// No description provided for @statusDndHint.
  ///
  /// In ru, this message translates to:
  /// **'Пока статус активен, push-уведомления о сообщениях не приходят'**
  String get statusDndHint;

  /// No description provided for @statusClear.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить статус'**
  String get statusClear;

  /// No description provided for @statusSaved.
  ///
  /// In ru, this message translates to:
  /// **'Статус установлен'**
  String get statusSaved;

  /// No description provided for @statusCleared.
  ///
  /// In ru, this message translates to:
  /// **'Статус сброшен'**
  String get statusCleared;

  /// No description provided for @statusInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте статус: текст до 70 символов, срок в будущем и не дальше года'**
  String get statusInvalid;

  /// No description provided for @statusCustomRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите текст или выберите эмодзи'**
  String get statusCustomRequired;

  /// No description provided for @chatAutoReplyText.
  ///
  /// In ru, this message translates to:
  /// **'Автоответ: {text}'**
  String chatAutoReplyText(String text);

  /// No description provided for @a11yStatus.
  ///
  /// In ru, this message translates to:
  /// **'статус: {status}'**
  String a11yStatus(String status);

  /// No description provided for @chatFoldersTitle.
  ///
  /// In ru, this message translates to:
  /// **'Папки чатов'**
  String get chatFoldersTitle;

  /// No description provided for @chatFoldersEdit.
  ///
  /// In ru, this message translates to:
  /// **'Настроить папки'**
  String get chatFoldersEdit;

  /// No description provided for @chatFoldersEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Соберите рабочие чаты, группы или каналы в отдельную вкладку'**
  String get chatFoldersEmpty;

  /// No description provided for @chatFolderNew.
  ///
  /// In ru, this message translates to:
  /// **'Новая папка'**
  String get chatFolderNew;

  /// No description provided for @chatFolderEditTitle.
  ///
  /// In ru, this message translates to:
  /// **'Изменить папку'**
  String get chatFolderEditTitle;

  /// No description provided for @chatFolderName.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get chatFolderName;

  /// No description provided for @chatFolderEmoji.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать значок папки'**
  String get chatFolderEmoji;

  /// No description provided for @chatFolderTypes.
  ///
  /// In ru, this message translates to:
  /// **'Все чаты этого типа'**
  String get chatFolderTypes;

  /// No description provided for @chatFolderTypeDirect.
  ///
  /// In ru, this message translates to:
  /// **'Личные'**
  String get chatFolderTypeDirect;

  /// No description provided for @chatFolderUnreadOnly.
  ///
  /// In ru, this message translates to:
  /// **'Только непрочитанные'**
  String get chatFolderUnreadOnly;

  /// No description provided for @chatFolderExcludeMuted.
  ///
  /// In ru, this message translates to:
  /// **'Скрывать чаты без звука'**
  String get chatFolderExcludeMuted;

  /// No description provided for @chatFolderChats.
  ///
  /// In ru, this message translates to:
  /// **'Чаты в папке'**
  String get chatFolderChats;

  /// No description provided for @chatFolderChatsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} чат} few{{count} чата} many{{count} чатов} other{{count} чата}}'**
  String chatFolderChatsCount(int count);

  /// No description provided for @chatFolderSearchChats.
  ///
  /// In ru, this message translates to:
  /// **'Поиск чатов'**
  String get chatFolderSearchChats;

  /// No description provided for @chatFolderErrorName.
  ///
  /// In ru, this message translates to:
  /// **'Введите название (до 32 символов)'**
  String get chatFolderErrorName;

  /// No description provided for @chatFolderErrorEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте чаты или выберите тип чатов'**
  String get chatFolderErrorEmpty;

  /// No description provided for @chatFolderErrorChats.
  ///
  /// In ru, this message translates to:
  /// **'В папке может быть не больше 200 чатов'**
  String get chatFolderErrorChats;

  /// No description provided for @chatFolderLimit.
  ///
  /// In ru, this message translates to:
  /// **'Можно создать не больше 10 папок'**
  String get chatFolderLimit;

  /// No description provided for @chatFolderDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить папку'**
  String get chatFolderDelete;

  /// No description provided for @chatFolderDeleteConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить папку «{name}»? Чаты останутся в списке.'**
  String chatFolderDeleteConfirm(String name);

  /// No description provided for @chatFolderReorder.
  ///
  /// In ru, this message translates to:
  /// **'Перетащите, чтобы изменить порядок'**
  String get chatFolderReorder;

  /// No description provided for @chatFolderUnreadChats.
  ///
  /// In ru, this message translates to:
  /// **'чатов с непрочитанными: {count}'**
  String chatFolderUnreadChats(int count);

  /// No description provided for @chatFoldersPending.
  ///
  /// In ru, this message translates to:
  /// **'Изменения сохранятся, когда появится сеть'**
  String get chatFoldersPending;

  /// No description provided for @chatFoldersSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить папки'**
  String get chatFoldersSaveFailed;

  /// No description provided for @chatAddToFolder.
  ///
  /// In ru, this message translates to:
  /// **'Добавить в папку'**
  String get chatAddToFolder;

  /// No description provided for @chatVoiceModeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Запись голосовых'**
  String get chatVoiceModeTitle;

  /// No description provided for @chatVoiceModeHold.
  ///
  /// In ru, this message translates to:
  /// **'Удерживать'**
  String get chatVoiceModeHold;

  /// No description provided for @chatVoiceModeTap.
  ///
  /// In ru, this message translates to:
  /// **'Нажать для записи'**
  String get chatVoiceModeTap;

  /// No description provided for @chatVoiceModeHint.
  ///
  /// In ru, this message translates to:
  /// **'С TalkBack запись всегда начинается нажатием'**
  String get chatVoiceModeHint;

  /// No description provided for @chatVoiceTapToRecord.
  ///
  /// In ru, this message translates to:
  /// **'Записать голосовое'**
  String get chatVoiceTapToRecord;

  /// No description provided for @channelComments.
  ///
  /// In ru, this message translates to:
  /// **'Комментарии'**
  String get channelComments;

  /// No description provided for @channelCommentsHint.
  ///
  /// In ru, this message translates to:
  /// **'Подписчики смогут обсуждать посты'**
  String get channelCommentsHint;

  /// No description provided for @commentsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} комментарий} few{{count} комментария} many{{count} комментариев} other{{count} комментария}}'**
  String commentsCount(int count);

  /// No description provided for @commentsLeave.
  ///
  /// In ru, this message translates to:
  /// **'Комментировать'**
  String get commentsLeave;

  /// No description provided for @commentsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Комментариев пока нет — напишите первым'**
  String get commentsEmpty;

  /// No description provided for @commentsDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Комментарии к постам отключены'**
  String get commentsDisabled;

  /// No description provided for @commentsInvalidThread.
  ///
  /// In ru, this message translates to:
  /// **'Ответить можно только на пост или комментарий к нему'**
  String get commentsInvalidThread;

  /// No description provided for @commentsPostUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Пост удалён или недоступен'**
  String get commentsPostUnavailable;

  /// No description provided for @scheduleWhenOnline.
  ///
  /// In ru, this message translates to:
  /// **'Когда появится в сети'**
  String get scheduleWhenOnline;

  /// No description provided for @scheduleWhenOnlineHint.
  ///
  /// In ru, this message translates to:
  /// **'Ждём до 7 дней'**
  String get scheduleWhenOnlineHint;

  /// No description provided for @scheduledWhenOnline.
  ///
  /// In ru, this message translates to:
  /// **'Когда появится в сети'**
  String get scheduledWhenOnline;

  /// No description provided for @scheduledWhenOnlineCreated.
  ///
  /// In ru, this message translates to:
  /// **'Отправим, когда собеседник появится в сети'**
  String get scheduledWhenOnlineCreated;

  /// No description provided for @scheduledWhenOnlineTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Не отправлено: собеседник не появился в сети'**
  String get scheduledWhenOnlineTimeout;

  /// No description provided for @scheduleWhenOnlineUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Собеседник скрывает, когда он в сети'**
  String get scheduleWhenOnlineUnavailable;

  /// No description provided for @officialTitle.
  ///
  /// In ru, this message translates to:
  /// **'Официальные сообщения'**
  String get officialTitle;

  /// No description provided for @officialEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Официальных сообщений пока нет'**
  String get officialEmpty;

  /// No description provided for @officialNoAccess.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к официальным сообщениям'**
  String get officialNoAccess;

  /// No description provided for @officialNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение не найдено'**
  String get officialNotFound;

  /// No description provided for @officialUnread.
  ///
  /// In ru, this message translates to:
  /// **'Не прочитано'**
  String get officialUnread;

  /// No description provided for @officialRequiresAck.
  ///
  /// In ru, this message translates to:
  /// **'Требует ознакомления'**
  String get officialRequiresAck;

  /// No description provided for @officialAcknowledged.
  ///
  /// In ru, this message translates to:
  /// **'Ознакомлен(а)'**
  String get officialAcknowledged;

  /// No description provided for @officialAcknowledgeButton.
  ///
  /// In ru, this message translates to:
  /// **'Ознакомлен(а)'**
  String get officialAcknowledgeButton;

  /// No description provided for @officialAcknowledgedAt.
  ///
  /// In ru, this message translates to:
  /// **'Вы ознакомились: {date}'**
  String officialAcknowledgedAt(String date);

  /// No description provided for @officialAckHint.
  ///
  /// In ru, this message translates to:
  /// **'Отправитель просит подтвердить, что вы ознакомились с сообщением.'**
  String get officialAckHint;

  /// No description provided for @officialLimitNote.
  ///
  /// In ru, this message translates to:
  /// **'Показаны последние {count} сообщений'**
  String officialLimitNote(int count);

  /// No description provided for @officialNew.
  ///
  /// In ru, this message translates to:
  /// **'Новое сообщение'**
  String get officialNew;

  /// No description provided for @officialReceivedTab.
  ///
  /// In ru, this message translates to:
  /// **'Входящие'**
  String get officialReceivedTab;

  /// No description provided for @officialSentTab.
  ///
  /// In ru, this message translates to:
  /// **'Отправленные'**
  String get officialSentTab;

  /// No description provided for @officialSentEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Здесь появятся сообщения, отправленные с этого устройства'**
  String get officialSentEmpty;

  /// No description provided for @officialRecipientCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} получатель} few{{count} получателя} many{{count} получателей} other{{count} получателя}}'**
  String officialRecipientCount(int count);

  /// No description provided for @officialSentToast.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Отправлено {count} получателю} other{Отправлено получателям: {count}}}'**
  String officialSentToast(int count);

  /// No description provided for @officialComposeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Официальное сообщение'**
  String get officialComposeTitle;

  /// No description provided for @officialFieldTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заголовок'**
  String get officialFieldTitle;

  /// No description provided for @officialFieldBody.
  ///
  /// In ru, this message translates to:
  /// **'Текст сообщения'**
  String get officialFieldBody;

  /// No description provided for @officialTitleRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите заголовок'**
  String get officialTitleRequired;

  /// No description provided for @officialBodyRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите текст сообщения'**
  String get officialBodyRequired;

  /// No description provided for @officialRequireAck.
  ///
  /// In ru, this message translates to:
  /// **'Требовать ознакомление'**
  String get officialRequireAck;

  /// No description provided for @officialRequireAckHint.
  ///
  /// In ru, this message translates to:
  /// **'Каждый получатель должен будет нажать «Ознакомлен(а)»'**
  String get officialRequireAckHint;

  /// No description provided for @officialRecipients.
  ///
  /// In ru, this message translates to:
  /// **'Получатели'**
  String get officialRecipients;

  /// No description provided for @officialRecipientsOrganization.
  ///
  /// In ru, this message translates to:
  /// **'Вся организация'**
  String get officialRecipientsOrganization;

  /// No description provided for @officialRecipientsDepartments.
  ///
  /// In ru, this message translates to:
  /// **'Отделы'**
  String get officialRecipientsDepartments;

  /// No description provided for @officialRecipientsUsers.
  ///
  /// In ru, this message translates to:
  /// **'Сотрудники'**
  String get officialRecipientsUsers;

  /// No description provided for @officialRecipientsRequired.
  ///
  /// In ru, this message translates to:
  /// **'Выберите получателей'**
  String get officialRecipientsRequired;

  /// No description provided for @officialSearchUsers.
  ///
  /// In ru, this message translates to:
  /// **'Поиск сотрудников'**
  String get officialSearchUsers;

  /// No description provided for @officialNoUsers.
  ///
  /// In ru, this message translates to:
  /// **'Никого не найдено'**
  String get officialNoUsers;

  /// No description provided for @officialNoDepartments.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступных отделов'**
  String get officialNoDepartments;

  /// No description provided for @officialSelectedDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово ({count})'**
  String officialSelectedDone(int count);

  /// No description provided for @officialSend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get officialSend;

  /// No description provided for @officialStatsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Статистика'**
  String get officialStatsTitle;

  /// No description provided for @officialStatsRecipients.
  ///
  /// In ru, this message translates to:
  /// **'Получатели'**
  String get officialStatsRecipients;

  /// No description provided for @officialStatsRead.
  ///
  /// In ru, this message translates to:
  /// **'Прочитали'**
  String get officialStatsRead;

  /// No description provided for @officialStatsAcknowledged.
  ///
  /// In ru, this message translates to:
  /// **'Ознакомились'**
  String get officialStatsAcknowledged;

  /// No description provided for @officialStatsNoData.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных. Статистика доступна только отправителю сообщения.'**
  String get officialStatsNoData;

  /// No description provided for @officialStatsAggregateNote.
  ///
  /// In ru, this message translates to:
  /// **'Сервер сообщает только общие количества, без списка получателей.'**
  String get officialStatsAggregateNote;

  /// No description provided for @officialErrNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение не найдено или не требует ознакомления'**
  String get officialErrNotFound;

  /// No description provided for @officialErrInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Заполните заголовок и текст сообщения'**
  String get officialErrInvalid;

  /// No description provided for @officialErrInvalidRecipients.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось определить получателей'**
  String get officialErrInvalidRecipients;

  /// No description provided for @officialErrNoRecipients.
  ///
  /// In ru, this message translates to:
  /// **'Среди выбранных нет активных пользователей'**
  String get officialErrNoRecipients;

  /// No description provided for @officialErrForbidden.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно прав для отправки официальных сообщений этим получателям'**
  String get officialErrForbidden;

  /// No description provided for @officialErrNotSent.
  ///
  /// In ru, this message translates to:
  /// **'Сервер не принял сообщение. Попробуйте ещё раз.'**
  String get officialErrNotSent;

  /// No description provided for @mailUxUnbookmarkedCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} письмо убрано из закладок} few{{count} письма убрано из закладок} other{{count} писем убрано из закладок}}'**
  String mailUxUnbookmarkedCount(int count);

  /// No description provided for @mailUxArchivedCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} письмо перемещено в архив} few{{count} письма перемещено в архив} other{{count} писем перемещено в архив}}'**
  String mailUxArchivedCount(int count);

  /// No description provided for @mailUxSwipeSection.
  ///
  /// In ru, this message translates to:
  /// **'Жесты в списке писем'**
  String get mailUxSwipeSection;

  /// No description provided for @mailUxSwipeLeft.
  ///
  /// In ru, this message translates to:
  /// **'Свайп влево'**
  String get mailUxSwipeLeft;

  /// No description provided for @mailUxSwipeRight.
  ///
  /// In ru, this message translates to:
  /// **'Свайп вправо'**
  String get mailUxSwipeRight;

  /// No description provided for @mailUxSwipeNone.
  ///
  /// In ru, this message translates to:
  /// **'Ничего'**
  String get mailUxSwipeNone;

  /// No description provided for @mailUxSwipeTrash.
  ///
  /// In ru, this message translates to:
  /// **'В корзину'**
  String get mailUxSwipeTrash;

  /// No description provided for @mailUxSwipeArchive.
  ///
  /// In ru, this message translates to:
  /// **'В архив'**
  String get mailUxSwipeArchive;

  /// No description provided for @mailUxSwipeRead.
  ///
  /// In ru, this message translates to:
  /// **'Прочитано / не прочитано'**
  String get mailUxSwipeRead;

  /// No description provided for @mailUxSwipeBookmark.
  ///
  /// In ru, this message translates to:
  /// **'Закладка'**
  String get mailUxSwipeBookmark;

  /// No description provided for @mailUxSwipeHint.
  ///
  /// In ru, this message translates to:
  /// **'В корзине и черновиках свайп «В корзину» удаляет письмо навсегда — после подтверждения. Пока выбрано несколько писем, свайпы отключены.'**
  String get mailUxSwipeHint;

  /// No description provided for @mailUxSendSection.
  ///
  /// In ru, this message translates to:
  /// **'Отправка'**
  String get mailUxSendSection;

  /// No description provided for @mailUxUndoSend.
  ///
  /// In ru, this message translates to:
  /// **'Отмена отправки'**
  String get mailUxUndoSend;

  /// No description provided for @mailUxUndoSendOff.
  ///
  /// In ru, this message translates to:
  /// **'Выключено'**
  String get mailUxUndoSendOff;

  /// No description provided for @mailUxUndoSendSeconds.
  ///
  /// In ru, this message translates to:
  /// **'{seconds} с'**
  String mailUxUndoSendSeconds(int seconds);

  /// No description provided for @mailUxUndoSendHint.
  ///
  /// In ru, this message translates to:
  /// **'письмо уходит после паузы, за это время его можно отменить'**
  String get mailUxUndoSendHint;

  /// No description provided for @mailUxSending.
  ///
  /// In ru, this message translates to:
  /// **'Письмо отправляется…'**
  String get mailUxSending;

  /// No description provided for @mailUxSendFailed.
  ///
  /// In ru, this message translates to:
  /// **'Письмо не отправлено: {error}'**
  String mailUxSendFailed(String error);

  /// No description provided for @mailUxEdit.
  ///
  /// In ru, this message translates to:
  /// **'Изменить'**
  String get mailUxEdit;

  /// No description provided for @mailUxAttachFile.
  ///
  /// In ru, this message translates to:
  /// **'Файл'**
  String get mailUxAttachFile;

  /// No description provided for @mailUxAttachGallery.
  ///
  /// In ru, this message translates to:
  /// **'Фото или видео из галереи'**
  String get mailUxAttachGallery;

  /// No description provided for @mailUxAttachCameraPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Сделать фото'**
  String get mailUxAttachCameraPhoto;

  /// No description provided for @mailUxAttachCameraVideo.
  ///
  /// In ru, this message translates to:
  /// **'Снять видео'**
  String get mailUxAttachCameraVideo;

  /// No description provided for @mailUxRecentRecipient.
  ///
  /// In ru, this message translates to:
  /// **'Недавний адрес'**
  String get mailUxRecentRecipient;

  /// No description provided for @mailUxForwardToChat.
  ///
  /// In ru, this message translates to:
  /// **'Переслать в чат'**
  String get mailUxForwardToChat;

  /// No description provided for @mailUxForwardToChatAttachments.
  ///
  /// In ru, this message translates to:
  /// **'Какие вложения отправить в чат?'**
  String get mailUxForwardToChatAttachments;

  /// No description provided for @mailUxNext.
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get mailUxNext;

  /// No description provided for @mailUxDownloading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка вложений…'**
  String get mailUxDownloading;

  /// No description provided for @mailUxChatDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get mailUxChatDate;

  /// No description provided for @mailUxChatSubject.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get mailUxChatSubject;

  /// No description provided for @mailUxChatFrom.
  ///
  /// In ru, this message translates to:
  /// **'От'**
  String get mailUxChatFrom;

  /// No description provided for @mailUxSendByMail.
  ///
  /// In ru, this message translates to:
  /// **'Отправить по почте'**
  String get mailUxSendByMail;

  /// No description provided for @tasksTitle.
  ///
  /// In ru, this message translates to:
  /// **'Задачи'**
  String get tasksTitle;

  /// No description provided for @tasksScreenTitle.
  ///
  /// In ru, this message translates to:
  /// **'Мои задачи'**
  String get tasksScreenTitle;

  /// No description provided for @tasksSectionMine.
  ///
  /// In ru, this message translates to:
  /// **'Мне'**
  String get tasksSectionMine;

  /// No description provided for @tasksSectionAssigned.
  ///
  /// In ru, this message translates to:
  /// **'Я поручил(а)'**
  String get tasksSectionAssigned;

  /// No description provided for @tasksSectionDone.
  ///
  /// In ru, this message translates to:
  /// **'Выполненные · {count}'**
  String tasksSectionDone(int count);

  /// No description provided for @tasksEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Задач нет'**
  String get tasksEmpty;

  /// No description provided for @tasksEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Создайте задачу или добавьте письмо в задачи'**
  String get tasksEmptyHint;

  /// No description provided for @tasksUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Задачи недоступны для вашей учётной записи'**
  String get tasksUnavailable;

  /// No description provided for @tasksNew.
  ///
  /// In ru, this message translates to:
  /// **'Новая задача'**
  String get tasksNew;

  /// No description provided for @tasksEdit.
  ///
  /// In ru, this message translates to:
  /// **'Изменить задачу'**
  String get tasksEdit;

  /// No description provided for @tasksDetails.
  ///
  /// In ru, this message translates to:
  /// **'Задача'**
  String get tasksDetails;

  /// No description provided for @tasksFieldTitle.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get tasksFieldTitle;

  /// No description provided for @tasksFieldDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get tasksFieldDescription;

  /// No description provided for @tasksFieldDue.
  ///
  /// In ru, this message translates to:
  /// **'Срок'**
  String get tasksFieldDue;

  /// No description provided for @tasksFieldReminder.
  ///
  /// In ru, this message translates to:
  /// **'Напоминание'**
  String get tasksFieldReminder;

  /// No description provided for @tasksFieldAssignee.
  ///
  /// In ru, this message translates to:
  /// **'Исполнитель'**
  String get tasksFieldAssignee;

  /// No description provided for @tasksFieldPriority.
  ///
  /// In ru, this message translates to:
  /// **'Приоритет'**
  String get tasksFieldPriority;

  /// No description provided for @tasksNoDue.
  ///
  /// In ru, this message translates to:
  /// **'Без срока'**
  String get tasksNoDue;

  /// No description provided for @tasksNoReminder.
  ///
  /// In ru, this message translates to:
  /// **'Без напоминания'**
  String get tasksNoReminder;

  /// No description provided for @tasksAssigneeSelf.
  ///
  /// In ru, this message translates to:
  /// **'Я'**
  String get tasksAssigneeSelf;

  /// No description provided for @tasksAssigneePick.
  ///
  /// In ru, this message translates to:
  /// **'Кому поручить'**
  String get tasksAssigneePick;

  /// No description provided for @tasksAssigneeSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск сотрудника'**
  String get tasksAssigneeSearch;

  /// No description provided for @tasksAssigneeEmpty.
  ///
  /// In ru, this message translates to:
  /// **'В ваших отделах нет сотрудников'**
  String get tasksAssigneeEmpty;

  /// No description provided for @tasksPriorityLow.
  ///
  /// In ru, this message translates to:
  /// **'Низкий'**
  String get tasksPriorityLow;

  /// No description provided for @tasksPriorityNormal.
  ///
  /// In ru, this message translates to:
  /// **'Обычный'**
  String get tasksPriorityNormal;

  /// No description provided for @tasksPriorityHigh.
  ///
  /// In ru, this message translates to:
  /// **'Высокий'**
  String get tasksPriorityHigh;

  /// No description provided for @tasksPriorityUrgent.
  ///
  /// In ru, this message translates to:
  /// **'Срочно'**
  String get tasksPriorityUrgent;

  /// No description provided for @tasksOverdue.
  ///
  /// In ru, this message translates to:
  /// **'Просрочено'**
  String get tasksOverdue;

  /// No description provided for @tasksDueToday.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get tasksDueToday;

  /// No description provided for @tasksDueOn.
  ///
  /// In ru, this message translates to:
  /// **'до {date}'**
  String tasksDueOn(String date);

  /// No description provided for @tasksAssignedTo.
  ///
  /// In ru, this message translates to:
  /// **'Исполнитель: {name}'**
  String tasksAssignedTo(String name);

  /// No description provided for @tasksAssignedBy.
  ///
  /// In ru, this message translates to:
  /// **'Поручил(а): {name}'**
  String tasksAssignedBy(String name);

  /// No description provided for @tasksAssignedToColleague.
  ///
  /// In ru, this message translates to:
  /// **'Поручено сотруднику'**
  String get tasksAssignedToColleague;

  /// No description provided for @tasksReminderFixed.
  ///
  /// In ru, this message translates to:
  /// **'Напоминание задаётся только при создании задачи'**
  String get tasksReminderFixed;

  /// No description provided for @tasksReadOnly.
  ///
  /// In ru, this message translates to:
  /// **'Изменять и удалять задачу может только исполнитель'**
  String get tasksReadOnly;

  /// No description provided for @tasksTitleRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите название'**
  String get tasksTitleRequired;

  /// No description provided for @tasksClear.
  ///
  /// In ru, this message translates to:
  /// **'Убрать'**
  String get tasksClear;

  /// No description provided for @tasksCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get tasksCreate;

  /// No description provided for @tasksDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить задачу'**
  String get tasksDelete;

  /// No description provided for @tasksDeleteConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить задачу «{title}»? Её напоминания тоже удалятся.'**
  String tasksDeleteConfirm(String title);

  /// No description provided for @tasksDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Задача удалена'**
  String get tasksDeleted;

  /// No description provided for @tasksCreated.
  ///
  /// In ru, this message translates to:
  /// **'Задача создана'**
  String get tasksCreated;

  /// No description provided for @tasksSaved.
  ///
  /// In ru, this message translates to:
  /// **'Задача сохранена'**
  String get tasksSaved;

  /// No description provided for @tasksMarkDone.
  ///
  /// In ru, this message translates to:
  /// **'Отметить выполненной'**
  String get tasksMarkDone;

  /// No description provided for @tasksMarkUndone.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть в работу'**
  String get tasksMarkUndone;

  /// No description provided for @tasksOpenMessage.
  ///
  /// In ru, this message translates to:
  /// **'Открыть письмо'**
  String get tasksOpenMessage;

  /// No description provided for @tasksOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть'**
  String get tasksOpen;

  /// No description provided for @tasksNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Задача не найдена'**
  String get tasksNotFound;

  /// No description provided for @tasksErrInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте поля задачи'**
  String get tasksErrInvalid;

  /// No description provided for @tasksErrOwner.
  ///
  /// In ru, this message translates to:
  /// **'Сотрудник не состоит в вашей организации'**
  String get tasksErrOwner;

  /// No description provided for @tasksErrReminder.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить напоминание'**
  String get tasksErrReminder;

  /// No description provided for @tasksErrForbidden.
  ///
  /// In ru, this message translates to:
  /// **'Нет прав поручить задачу этому сотруднику'**
  String get tasksErrForbidden;

  /// No description provided for @taskBoardsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Доски'**
  String get taskBoardsTitle;

  /// No description provided for @taskBoardPersonal.
  ///
  /// In ru, this message translates to:
  /// **'Мои задачи'**
  String get taskBoardPersonal;

  /// No description provided for @taskBoardNew.
  ///
  /// In ru, this message translates to:
  /// **'Новая доска'**
  String get taskBoardNew;

  /// No description provided for @taskBoardCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать доску'**
  String get taskBoardCreate;

  /// No description provided for @taskBoardRename.
  ///
  /// In ru, this message translates to:
  /// **'Переименовать доску'**
  String get taskBoardRename;

  /// No description provided for @taskBoardName.
  ///
  /// In ru, this message translates to:
  /// **'Название доски'**
  String get taskBoardName;

  /// No description provided for @taskBoardNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: Приёмная кампания'**
  String get taskBoardNameHint;

  /// No description provided for @taskBoardDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get taskBoardDescription;

  /// No description provided for @taskBoardColor.
  ///
  /// In ru, this message translates to:
  /// **'Цвет'**
  String get taskBoardColor;

  /// No description provided for @taskBoardShare.
  ///
  /// In ru, this message translates to:
  /// **'Поделиться'**
  String get taskBoardShare;

  /// No description provided for @taskBoardDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить доску'**
  String get taskBoardDelete;

  /// No description provided for @taskBoardDeleteConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить доску «{name}»? Её задачи вернутся в «Мои задачи», а коллеги потеряют к ним доступ.'**
  String taskBoardDeleteConfirm(String name);

  /// No description provided for @taskBoardDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Доска удалена'**
  String get taskBoardDeleted;

  /// No description provided for @taskBoardCreated.
  ///
  /// In ru, this message translates to:
  /// **'Доска создана'**
  String get taskBoardCreated;

  /// No description provided for @taskBoardSaved.
  ///
  /// In ru, this message translates to:
  /// **'Доска сохранена'**
  String get taskBoardSaved;

  /// No description provided for @taskBoardShared.
  ///
  /// In ru, this message translates to:
  /// **'Доступ обновлён'**
  String get taskBoardShared;

  /// No description provided for @taskBoardNameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите название доски'**
  String get taskBoardNameRequired;

  /// No description provided for @taskBoardOwnedBy.
  ///
  /// In ru, this message translates to:
  /// **'Доска сотрудника {name}'**
  String taskBoardOwnedBy(String name);

  /// No description provided for @taskBoardRoleEditor.
  ///
  /// In ru, this message translates to:
  /// **'Может изменять'**
  String get taskBoardRoleEditor;

  /// No description provided for @taskBoardRoleViewer.
  ///
  /// In ru, this message translates to:
  /// **'Только просмотр'**
  String get taskBoardRoleViewer;

  /// No description provided for @taskBoardReadOnly.
  ///
  /// In ru, this message translates to:
  /// **'Доска доступна только для просмотра'**
  String get taskBoardReadOnly;

  /// No description provided for @taskBoardShareTitle.
  ///
  /// In ru, this message translates to:
  /// **'Доступ к доске «{name}»'**
  String taskBoardShareTitle(String name);

  /// No description provided for @taskBoardShareHint.
  ///
  /// In ru, this message translates to:
  /// **'Участники видят задачи доски. Редакторы могут создавать и изменять их, наблюдатели — только читать.'**
  String get taskBoardShareHint;

  /// No description provided for @taskBoardShareSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск сотрудника'**
  String get taskBoardShareSearch;

  /// No description provided for @taskBoardShareEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Доска пока никому не доступна'**
  String get taskBoardShareEmpty;

  /// No description provided for @taskBoardShareMembers.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{Нет участников} one{{count} участник} few{{count} участника} many{{count} участников} other{{count} участника}}'**
  String taskBoardShareMembers(int count);

  /// No description provided for @taskBoardRemoveMember.
  ///
  /// In ru, this message translates to:
  /// **'Убрать доступ'**
  String get taskBoardRemoveMember;

  /// No description provided for @taskBoardEmpty.
  ///
  /// In ru, this message translates to:
  /// **'На этой доске пока нет задач'**
  String get taskBoardEmpty;

  /// No description provided for @taskBoardMoveHere.
  ///
  /// In ru, this message translates to:
  /// **'Перенести сюда'**
  String get taskBoardMoveHere;

  /// No description provided for @taskBoardMoved.
  ///
  /// In ru, this message translates to:
  /// **'Задача перенесена: {name}'**
  String taskBoardMoved(String name);

  /// No description provided for @taskBoardOpenCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{Нет задач} one{{count} задача} few{{count} задачи} many{{count} задач} other{{count} задачи}}'**
  String taskBoardOpenCount(int count);

  /// No description provided for @taskBoardErrNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Доска не найдена'**
  String get taskBoardErrNotFound;

  /// No description provided for @taskBoardErrForbidden.
  ///
  /// In ru, this message translates to:
  /// **'Нет прав изменять эту доску'**
  String get taskBoardErrForbidden;

  /// No description provided for @taskBoardErrName.
  ///
  /// In ru, this message translates to:
  /// **'Название доски: от 1 до 120 символов'**
  String get taskBoardErrName;

  /// No description provided for @taskBoardErrMember.
  ///
  /// In ru, this message translates to:
  /// **'Сотрудник не состоит в вашей организации'**
  String get taskBoardErrMember;

  /// No description provided for @taskBoardsRailHide.
  ///
  /// In ru, this message translates to:
  /// **'Скрыть список досок'**
  String get taskBoardsRailHide;

  /// No description provided for @taskBoardsRailShow.
  ///
  /// In ru, this message translates to:
  /// **'Показать список досок'**
  String get taskBoardsRailShow;

  /// No description provided for @translateAction.
  ///
  /// In ru, this message translates to:
  /// **'Перевести'**
  String get translateAction;

  /// No description provided for @translateMail.
  ///
  /// In ru, this message translates to:
  /// **'Перевести письмо'**
  String get translateMail;

  /// No description provided for @translateInProgress.
  ///
  /// In ru, this message translates to:
  /// **'Перевод…'**
  String get translateInProgress;

  /// No description provided for @translateFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось перевести'**
  String get translateFailed;

  /// No description provided for @translateRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get translateRetry;

  /// No description provided for @translateShowOriginal.
  ///
  /// In ru, this message translates to:
  /// **'Показать оригинал'**
  String get translateShowOriginal;

  /// No description provided for @translateLabel.
  ///
  /// In ru, this message translates to:
  /// **'Перевод: {from} → {to}'**
  String translateLabel(String from, String to);

  /// No description provided for @translateSameLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Текст уже на языке: {language}'**
  String translateSameLanguage(String language);

  /// No description provided for @translateLangRu.
  ///
  /// In ru, this message translates to:
  /// **'русский'**
  String get translateLangRu;

  /// No description provided for @translateLangKk.
  ///
  /// In ru, this message translates to:
  /// **'казахский'**
  String get translateLangKk;

  /// No description provided for @translateLangEn.
  ///
  /// In ru, this message translates to:
  /// **'английский'**
  String get translateLangEn;

  /// No description provided for @translateAutoInChat.
  ///
  /// In ru, this message translates to:
  /// **'Переводить автоматически на {language}'**
  String translateAutoInChat(String language);

  /// No description provided for @translateAutoInChatHint.
  ///
  /// In ru, this message translates to:
  /// **'Входящие сообщения на другом языке, на этом устройстве'**
  String get translateAutoInChatHint;

  /// No description provided for @translateTargetSetting.
  ///
  /// In ru, this message translates to:
  /// **'Язык перевода'**
  String get translateTargetSetting;

  /// No description provided for @translateTargetAppLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Как в приложении ({language})'**
  String translateTargetAppLanguage(String language);

  /// No description provided for @translateUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Перевод сейчас недоступен. Попробуйте позже.'**
  String get translateUnavailable;

  /// No description provided for @translateTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Текст слишком длинный для перевода'**
  String get translateTooLong;

  /// No description provided for @translateRateLimited.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много переводов. Попробуйте позже.'**
  String get translateRateLimited;

  /// No description provided for @translateMailProgress.
  ///
  /// In ru, this message translates to:
  /// **'Перевод: {done} из {total}'**
  String translateMailProgress(int done, int total);

  /// No description provided for @searchEverywhere.
  ///
  /// In ru, this message translates to:
  /// **'Поиск везде'**
  String get searchEverywhere;

  /// No description provided for @searchHint.
  ///
  /// In ru, this message translates to:
  /// **'Люди, чаты, почта, события'**
  String get searchHint;

  /// No description provided for @searchIntro.
  ///
  /// In ru, this message translates to:
  /// **'Ищите сразу по людям, чатам, почте и календарю'**
  String get searchIntro;

  /// No description provided for @searchRecent.
  ///
  /// In ru, this message translates to:
  /// **'Недавние'**
  String get searchRecent;

  /// No description provided for @searchRecentClear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get searchRecentClear;

  /// No description provided for @searchRecentRemove.
  ///
  /// In ru, this message translates to:
  /// **'Удалить из истории'**
  String get searchRecentRemove;

  /// No description provided for @searchSectionPeople.
  ///
  /// In ru, this message translates to:
  /// **'Люди'**
  String get searchSectionPeople;

  /// No description provided for @searchSectionChats.
  ///
  /// In ru, this message translates to:
  /// **'Чаты'**
  String get searchSectionChats;

  /// No description provided for @searchSectionMail.
  ///
  /// In ru, this message translates to:
  /// **'Почта'**
  String get searchSectionMail;

  /// No description provided for @searchSectionEvents.
  ///
  /// In ru, this message translates to:
  /// **'События'**
  String get searchSectionEvents;

  /// No description provided for @searchShowAll.
  ///
  /// In ru, this message translates to:
  /// **'Показать все'**
  String get searchShowAll;

  /// No description provided for @searchSectionError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выполнить поиск'**
  String get searchSectionError;

  /// No description provided for @searchEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get searchEmpty;

  /// No description provided for @searchNothingAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Поиск недоступен для вашей учётной записи'**
  String get searchNothingAvailable;

  /// No description provided for @searchOfflineHint.
  ///
  /// In ru, this message translates to:
  /// **'Офлайн — только сохранённое'**
  String get searchOfflineHint;

  /// No description provided for @searchNoSubject.
  ///
  /// In ru, this message translates to:
  /// **'(без темы)'**
  String get searchNoSubject;

  /// No description provided for @todayTab.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get todayTab;

  /// No description provided for @todayStartScreen.
  ///
  /// In ru, this message translates to:
  /// **'Начальный экран'**
  String get todayStartScreen;

  /// No description provided for @todayStartScreenHint.
  ///
  /// In ru, this message translates to:
  /// **'Вкладка, которая открывается при запуске. «Сегодня» добавляет вкладку со сводкой дня.'**
  String get todayStartScreenHint;

  /// No description provided for @todayGreetingMorning.
  ///
  /// In ru, this message translates to:
  /// **'Доброе утро'**
  String get todayGreetingMorning;

  /// No description provided for @todayGreetingAfternoon.
  ///
  /// In ru, this message translates to:
  /// **'Добрый день'**
  String get todayGreetingAfternoon;

  /// No description provided for @todayGreetingEvening.
  ///
  /// In ru, this message translates to:
  /// **'Добрый вечер'**
  String get todayGreetingEvening;

  /// No description provided for @todayGreetingNight.
  ///
  /// In ru, this message translates to:
  /// **'Доброй ночи'**
  String get todayGreetingNight;

  /// No description provided for @todayMailTitle.
  ///
  /// In ru, this message translates to:
  /// **'Непрочитанная почта'**
  String get todayMailTitle;

  /// No description provided for @todayMailEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Все письма прочитаны'**
  String get todayMailEmpty;

  /// No description provided for @todayChatsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Непрочитанные чаты'**
  String get todayChatsTitle;

  /// No description provided for @todayChatsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Новых сообщений нет'**
  String get todayChatsEmpty;

  /// No description provided for @todayEventsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня в календаре'**
  String get todayEventsTitle;

  /// No description provided for @todayEventsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Больше событий сегодня нет'**
  String get todayEventsEmpty;

  /// No description provided for @todayJoin.
  ///
  /// In ru, this message translates to:
  /// **'Подключиться'**
  String get todayJoin;

  /// No description provided for @todayMissedCallsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Пропущенные звонки'**
  String get todayMissedCallsTitle;

  /// No description provided for @todayMissedCallsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня пропущенных нет'**
  String get todayMissedCallsEmpty;

  /// No description provided for @todayNewMail.
  ///
  /// In ru, this message translates to:
  /// **'Письмо'**
  String get todayNewMail;

  /// No description provided for @todayNewChat.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение'**
  String get todayNewChat;

  /// No description provided for @todayNewCall.
  ///
  /// In ru, this message translates to:
  /// **'Звонок'**
  String get todayNewCall;

  /// No description provided for @callsShareChoose.
  ///
  /// In ru, this message translates to:
  /// **'Что показать'**
  String get callsShareChoose;

  /// No description provided for @callsShareEntireScreen.
  ///
  /// In ru, this message translates to:
  /// **'Весь экран'**
  String get callsShareEntireScreen;

  /// No description provided for @callsShareWindow.
  ///
  /// In ru, this message translates to:
  /// **'Окно'**
  String get callsShareWindow;

  /// No description provided for @callsShareStart.
  ///
  /// In ru, this message translates to:
  /// **'Показать'**
  String get callsShareStart;

  /// No description provided for @desktopTrayOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть XatBox'**
  String get desktopTrayOpen;

  /// No description provided for @desktopTrayQuit.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из XatBox'**
  String get desktopTrayQuit;

  /// No description provided for @desktopSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get desktopSearch;

  /// No description provided for @desktopMore.
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get desktopMore;

  /// No description provided for @contactsSelect.
  ///
  /// In ru, this message translates to:
  /// **'Выберите сотрудника, чтобы открыть профиль'**
  String get contactsSelect;

  /// No description provided for @callsSelect.
  ///
  /// In ru, this message translates to:
  /// **'Выберите звонок, чтобы открыть карточку'**
  String get callsSelect;

  /// No description provided for @desktopRefresh.
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get desktopRefresh;

  /// No description provided for @desktopPrevious.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get desktopPrevious;

  /// No description provided for @desktopNext.
  ///
  /// In ru, this message translates to:
  /// **'Вперёд'**
  String get desktopNext;

  /// No description provided for @aboutPrivacyPushBodyDesktop.
  ///
  /// In ru, this message translates to:
  /// **'На компьютере уведомления приходят напрямую от сервера организации по защищённому соединению, без Google и Apple.'**
  String get aboutPrivacyPushBodyDesktop;

  /// No description provided for @remindersEmptyHintDesktop.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите на сообщение правой кнопкой мыши и выберите «Напомнить»'**
  String get remindersEmptyHintDesktop;

  /// No description provided for @chatProtectionScreenshotsHintDesktop.
  ///
  /// In ru, this message translates to:
  /// **'На компьютере чат скрывается, когда окно свёрнуто'**
  String get chatProtectionScreenshotsHintDesktop;

  /// No description provided for @settingsLockWindowsHello.
  ///
  /// In ru, this message translates to:
  /// **'Разблокировка через Windows Hello'**
  String get settingsLockWindowsHello;

  /// No description provided for @composeMinimize.
  ///
  /// In ru, this message translates to:
  /// **'Свернуть'**
  String get composeMinimize;

  /// No description provided for @composeExpand.
  ///
  /// In ru, this message translates to:
  /// **'Развернуть'**
  String get composeExpand;

  /// No description provided for @composeRestoreSize.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить размер'**
  String get composeRestoreSize;

  /// No description provided for @composeSaveAndClose.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить и закрыть'**
  String get composeSaveAndClose;

  /// No description provided for @composeAddCcBcc.
  ///
  /// In ru, this message translates to:
  /// **'Копия / Скрытая копия'**
  String get composeAddCcBcc;

  /// No description provided for @desktopCollapseSidebar.
  ///
  /// In ru, this message translates to:
  /// **'Свернуть меню'**
  String get desktopCollapseSidebar;

  /// No description provided for @desktopExpandSidebar.
  ///
  /// In ru, this message translates to:
  /// **'Развернуть меню'**
  String get desktopExpandSidebar;

  /// No description provided for @desktopZoom.
  ///
  /// In ru, this message translates to:
  /// **'Масштаб'**
  String get desktopZoom;

  /// No description provided for @desktopZoomHint.
  ///
  /// In ru, this message translates to:
  /// **'Размер всего интерфейса. Горячие клавиши: Ctrl + плюс, Ctrl + минус, Ctrl + 0.'**
  String get desktopZoomHint;

  /// No description provided for @desktopZoomReset.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get desktopZoomReset;

  /// No description provided for @desktopNotifTest.
  ///
  /// In ru, this message translates to:
  /// **'Проверить уведомления'**
  String get desktopNotifTest;

  /// No description provided for @desktopNotifTestHint.
  ///
  /// In ru, this message translates to:
  /// **'Показать пробное уведомление Windows'**
  String get desktopNotifTestHint;

  /// No description provided for @desktopNotifTestBody.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления работают'**
  String get desktopNotifTestBody;

  /// No description provided for @desktopNotifTestSent.
  ///
  /// In ru, this message translates to:
  /// **'Уведомление отправлено. Если его не видно, включите уведомления для XatBox в параметрах системы и выключите режим «Не беспокоить».'**
  String get desktopNotifTestSent;

  /// No description provided for @desktopNotifTestFailed.
  ///
  /// In ru, this message translates to:
  /// **'Система не показала уведомление: {error}'**
  String desktopNotifTestFailed(String error);

  /// No description provided for @desktopSettingsIntro.
  ///
  /// In ru, this message translates to:
  /// **'Профиль, оформление, уведомления и безопасность. Изменения сохраняются сразу.'**
  String get desktopSettingsIntro;

  /// No description provided for @updateInstallFailedDesktop.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось запустить установщик обновления'**
  String get updateInstallFailedDesktop;

  /// No description provided for @desktopCalendarMore.
  ///
  /// In ru, this message translates to:
  /// **'+{count} ещё'**
  String desktopCalendarMore(int count);

  /// No description provided for @desktopCalendarSelectedDay.
  ///
  /// In ru, this message translates to:
  /// **'Выбранный день'**
  String get desktopCalendarSelectedDay;

  /// No description provided for @composeDraftSavedAt.
  ///
  /// In ru, this message translates to:
  /// **'Черновик сохранён {time}'**
  String composeDraftSavedAt(String time);

  /// No description provided for @desktopShortcutsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Горячие клавиши'**
  String get desktopShortcutsTitle;

  /// No description provided for @desktopShortcutsMail.
  ///
  /// In ru, this message translates to:
  /// **'Письма'**
  String get desktopShortcutsMail;

  /// No description provided for @desktopShortcutsEverywhere.
  ///
  /// In ru, this message translates to:
  /// **'Везде'**
  String get desktopShortcutsEverywhere;

  /// No description provided for @desktopShortcutNext.
  ///
  /// In ru, this message translates to:
  /// **'Следующее письмо'**
  String get desktopShortcutNext;

  /// No description provided for @desktopShortcutPrevious.
  ///
  /// In ru, this message translates to:
  /// **'Предыдущее письмо'**
  String get desktopShortcutPrevious;

  /// No description provided for @desktopShortcutOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть письмо'**
  String get desktopShortcutOpen;

  /// No description provided for @desktopShortcutClose.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть письмо'**
  String get desktopShortcutClose;

  /// No description provided for @desktopShortcutReadToggle.
  ///
  /// In ru, this message translates to:
  /// **'Прочитано / не прочитано'**
  String get desktopShortcutReadToggle;

  /// No description provided for @desktopShortcutSend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить письмо'**
  String get desktopShortcutSend;

  /// No description provided for @desktopShortcutModules.
  ///
  /// In ru, this message translates to:
  /// **'Почта · Чат · Звонки · Календарь · Контакты'**
  String get desktopShortcutModules;

  /// No description provided for @desktopShortcutZoom.
  ///
  /// In ru, this message translates to:
  /// **'Масштаб: крупнее · мельче · как было'**
  String get desktopShortcutZoom;

  /// No description provided for @desktopPrint.
  ///
  /// In ru, this message translates to:
  /// **'Печать'**
  String get desktopPrint;

  /// No description provided for @desktopPrintFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть письмо для печати'**
  String get desktopPrintFailed;

  /// No description provided for @desktopOpenInWindow.
  ///
  /// In ru, this message translates to:
  /// **'Открыть в отдельном окне'**
  String get desktopOpenInWindow;

  /// No description provided for @desktopDefaultMailApp.
  ///
  /// In ru, this message translates to:
  /// **'Почтовая программа по умолчанию'**
  String get desktopDefaultMailApp;

  /// No description provided for @desktopDefaultMailAppHint.
  ///
  /// In ru, this message translates to:
  /// **'Ссылки на почтовые адреса (mailto:) в браузере и документах будут открывать новое письмо в XatBox. Откроются параметры Windows: выберите XatBox для MAILTO.'**
  String get desktopDefaultMailAppHint;

  /// No description provided for @desktopAppSection.
  ///
  /// In ru, this message translates to:
  /// **'Приложение для компьютера'**
  String get desktopAppSection;

  /// No description provided for @updateRestartNow.
  ///
  /// In ru, this message translates to:
  /// **'Перезапустить и обновить'**
  String get updateRestartNow;

  /// No description provided for @updateOnQuit.
  ///
  /// In ru, this message translates to:
  /// **'Обновить при выходе'**
  String get updateOnQuit;

  /// No description provided for @updateOnQuitScheduled.
  ///
  /// In ru, this message translates to:
  /// **'Обновление установится, когда вы выйдете из XatBox: значок в трее → «Выйти из XatBox».'**
  String get updateOnQuitScheduled;

  /// No description provided for @updateManagedByAdmin.
  ///
  /// In ru, this message translates to:
  /// **'XatBox установлен для всех пользователей компьютера. Новые версии устанавливает администратор.'**
  String get updateManagedByAdmin;

  /// No description provided for @desktopPrintDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get desktopPrintDate;

  /// No description provided for @desktopPrintAttachments.
  ///
  /// In ru, this message translates to:
  /// **'Вложения'**
  String get desktopPrintAttachments;

  /// No description provided for @desktopDefaultMailAppHintMac.
  ///
  /// In ru, this message translates to:
  /// **'Ссылки на почтовые адреса (mailto:) в браузере и документах будут открывать новое письмо в XatBox. macOS попросит подтвердить.'**
  String get desktopDefaultMailAppHintMac;

  /// No description provided for @desktopDefaultMailAppDone.
  ///
  /// In ru, this message translates to:
  /// **'XatBox теперь открывает ссылки mailto:'**
  String get desktopDefaultMailAppDone;

  /// No description provided for @desktopMailMore.
  ///
  /// In ru, this message translates to:
  /// **'Ещё новых писем: {count}'**
  String desktopMailMore(int count);

  /// No description provided for @desktopMailNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Уведомлять о новых письмах'**
  String get desktopMailNotifications;

  /// No description provided for @desktopMailNotificationsHint.
  ///
  /// In ru, this message translates to:
  /// **'Уведомление с кнопками «Ответить», «Прочитано», «Удалить», пока XatBox свёрнут или в другом разделе'**
  String get desktopMailNotificationsHint;

  /// No description provided for @desktopFileHint.
  ///
  /// In ru, this message translates to:
  /// **'Перетащите в папку · Пробел — быстрый просмотр'**
  String get desktopFileHint;

  /// No description provided for @desktopEmlUnreadable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прочитать файл письма'**
  String get desktopEmlUnreadable;

  /// No description provided for @desktopAwayStatus.
  ///
  /// In ru, this message translates to:
  /// **'Отошёл'**
  String get desktopAwayStatus;

  /// No description provided for @desktopMiniCallMute.
  ///
  /// In ru, this message translates to:
  /// **'Выключить микрофон'**
  String get desktopMiniCallMute;

  /// No description provided for @desktopMiniCallUnmute.
  ///
  /// In ru, this message translates to:
  /// **'Включить микрофон'**
  String get desktopMiniCallUnmute;

  /// No description provided for @desktopMiniCallEnd.
  ///
  /// In ru, this message translates to:
  /// **'Завершить'**
  String get desktopMiniCallEnd;

  /// No description provided for @desktopMiniCallExpand.
  ///
  /// In ru, this message translates to:
  /// **'Развернуть'**
  String get desktopMiniCallExpand;

  /// No description provided for @desktopLaunchAtLogin.
  ///
  /// In ru, this message translates to:
  /// **'Запускать при входе в систему'**
  String get desktopLaunchAtLogin;

  /// No description provided for @desktopLaunchAtLoginHint.
  ///
  /// In ru, this message translates to:
  /// **'XatBox стартует свёрнутым в трей и сразу получает письма и сообщения'**
  String get desktopLaunchAtLoginHint;

  /// No description provided for @desktopLaunchAtLoginManaged.
  ///
  /// In ru, this message translates to:
  /// **'Включено администратором для всех пользователей компьютера'**
  String get desktopLaunchAtLoginManaged;

  /// No description provided for @desktopGlobalHotkeys.
  ///
  /// In ru, this message translates to:
  /// **'Глобальные сочетания клавиш'**
  String get desktopGlobalHotkeys;

  /// No description provided for @desktopGlobalHotkeysHint.
  ///
  /// In ru, this message translates to:
  /// **'{compose} — новое письмо, {show} — показать XatBox, из любой программы'**
  String desktopGlobalHotkeysHint(String compose, String show);

  /// No description provided for @desktopAutoAway.
  ///
  /// In ru, this message translates to:
  /// **'Статус «Отошёл» автоматически'**
  String get desktopAutoAway;

  /// No description provided for @desktopAutoAwayHint.
  ///
  /// In ru, this message translates to:
  /// **'Когда компьютер заблокирован или без действий 10 минут. Свой статус XatBox не меняет'**
  String get desktopAutoAwayHint;

  /// No description provided for @desktopMiniCall.
  ///
  /// In ru, this message translates to:
  /// **'Мини-окно звонка'**
  String get desktopMiniCall;

  /// No description provided for @desktopMiniCallHint.
  ///
  /// In ru, this message translates to:
  /// **'При переходе в другую программу звонок остаётся маленьким окном поверх всех окон'**
  String get desktopMiniCallHint;

  /// No description provided for @desktopNotificationSound.
  ///
  /// In ru, this message translates to:
  /// **'Звук уведомлений'**
  String get desktopNotificationSound;

  /// No description provided for @desktopNotificationSoundHint.
  ///
  /// In ru, this message translates to:
  /// **'Новые сообщения в чате и новые письма'**
  String get desktopNotificationSoundHint;

  /// No description provided for @desktopSoundXatbox.
  ///
  /// In ru, this message translates to:
  /// **'XatBox'**
  String get desktopSoundXatbox;

  /// No description provided for @desktopSoundSystem.
  ///
  /// In ru, this message translates to:
  /// **'Системный'**
  String get desktopSoundSystem;

  /// No description provided for @desktopSoundNone.
  ///
  /// In ru, this message translates to:
  /// **'Без звука'**
  String get desktopSoundNone;

  /// No description provided for @desktopRingtone.
  ///
  /// In ru, this message translates to:
  /// **'Мелодия звонка'**
  String get desktopRingtone;

  /// No description provided for @desktopRingtoneHint.
  ///
  /// In ru, this message translates to:
  /// **'Входящий звонок'**
  String get desktopRingtoneHint;

  /// No description provided for @desktopRingtoneClassic.
  ///
  /// In ru, this message translates to:
  /// **'Классическая'**
  String get desktopRingtoneClassic;

  /// No description provided for @desktopSoundPreview.
  ///
  /// In ru, this message translates to:
  /// **'Прослушать'**
  String get desktopSoundPreview;

  /// No description provided for @chatWritePersonally.
  ///
  /// In ru, this message translates to:
  /// **'Написать лично'**
  String get chatWritePersonally;

  /// No description provided for @chatMemberActions.
  ///
  /// In ru, this message translates to:
  /// **'Участник'**
  String get chatMemberActions;

  /// No description provided for @desktopBetaUpdates.
  ///
  /// In ru, this message translates to:
  /// **'Получать бета-версии'**
  String get desktopBetaUpdates;

  /// No description provided for @desktopBetaUpdatesHint.
  ///
  /// In ru, this message translates to:
  /// **'Новые версии приходят сразу, на день раньше, чем всем. В них могут быть ошибки.'**
  String get desktopBetaUpdatesHint;

  /// No description provided for @updateDownloadOnly.
  ///
  /// In ru, this message translates to:
  /// **'Скачать'**
  String get updateDownloadOnly;

  /// No description provided for @updateLinuxOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть пакет'**
  String get updateLinuxOpen;

  /// No description provided for @updateLinuxOpened.
  ///
  /// In ru, this message translates to:
  /// **'Пакет открыт в установщике'**
  String get updateLinuxOpened;

  /// No description provided for @updateLinuxOpenedHint.
  ///
  /// In ru, this message translates to:
  /// **'Установите его (понадобится пароль администратора) и перезапустите XatBox. Файл .deb сохранён в папке «Загрузки».'**
  String get updateLinuxOpenedHint;

  /// No description provided for @desktopSpellCheck.
  ///
  /// In ru, this message translates to:
  /// **'Проверка орфографии в письмах'**
  String get desktopSpellCheck;

  /// No description provided for @desktopSpellCheckHint.
  ///
  /// In ru, this message translates to:
  /// **'Ошибки подчёркиваются, варианты — по правой кнопке. Словари системы: русский, английский, казахский (если установлен)'**
  String get desktopSpellCheckHint;

  /// No description provided for @desktopShortcutQuickLook.
  ///
  /// In ru, this message translates to:
  /// **'Быстрый просмотр вложения (под курсором)'**
  String get desktopShortcutQuickLook;

  /// No description provided for @desktopShortcutGlobalCompose.
  ///
  /// In ru, this message translates to:
  /// **'Новое письмо из любой программы'**
  String get desktopShortcutGlobalCompose;

  /// No description provided for @desktopShortcutGlobalShow.
  ///
  /// In ru, this message translates to:
  /// **'Показать XatBox из любой программы'**
  String get desktopShortcutGlobalShow;

  /// No description provided for @desktopCalendarOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть'**
  String get desktopCalendarOpen;

  /// No description provided for @desktopCalendarGoToDate.
  ///
  /// In ru, this message translates to:
  /// **'Перейти к дате'**
  String get desktopCalendarGoToDate;

  /// No description provided for @desktopCalendarNewHere.
  ///
  /// In ru, this message translates to:
  /// **'Создать событие здесь'**
  String get desktopCalendarNewHere;

  /// No description provided for @desktopCalendarWeekNumber.
  ///
  /// In ru, this message translates to:
  /// **'Неделя {week}'**
  String desktopCalendarWeekNumber(int week);

  /// No description provided for @desktopSelectMessageToRead.
  ///
  /// In ru, this message translates to:
  /// **'Выберите письмо'**
  String get desktopSelectMessageToRead;

  /// No description provided for @desktopSelectMessageToReadHint.
  ///
  /// In ru, this message translates to:
  /// **'Выберите письмо из списка. Оно откроется здесь, и вы не потеряете своё место.'**
  String get desktopSelectMessageToReadHint;

  /// No description provided for @desktopProfileFullName.
  ///
  /// In ru, this message translates to:
  /// **'Полное имя'**
  String get desktopProfileFullName;

  /// No description provided for @desktopRoleMember.
  ///
  /// In ru, this message translates to:
  /// **'Сотрудник'**
  String get desktopRoleMember;

  /// No description provided for @desktopRoleUserManager.
  ///
  /// In ru, this message translates to:
  /// **'Менеджер пользователей'**
  String get desktopRoleUserManager;

  /// No description provided for @desktopRoleOrgAdmin.
  ///
  /// In ru, this message translates to:
  /// **'Администратор организации'**
  String get desktopRoleOrgAdmin;

  /// No description provided for @desktopRoleDomainAdmin.
  ///
  /// In ru, this message translates to:
  /// **'Администратор домена'**
  String get desktopRoleDomainAdmin;

  /// No description provided for @desktopRoleDeveloper.
  ///
  /// In ru, this message translates to:
  /// **'Разработчик'**
  String get desktopRoleDeveloper;

  /// No description provided for @desktopRoleSecurityAnalyst.
  ///
  /// In ru, this message translates to:
  /// **'Аналитик безопасности'**
  String get desktopRoleSecurityAnalyst;

  /// No description provided for @desktopRoleAuditor.
  ///
  /// In ru, this message translates to:
  /// **'Аудитор'**
  String get desktopRoleAuditor;

  /// No description provided for @desktopRoleSupport.
  ///
  /// In ru, this message translates to:
  /// **'Поддержка'**
  String get desktopRoleSupport;

  /// No description provided for @desktopRoleTenantOwner.
  ///
  /// In ru, this message translates to:
  /// **'Владелец тенанта'**
  String get desktopRoleTenantOwner;

  /// No description provided for @desktopRoleSuperAdmin.
  ///
  /// In ru, this message translates to:
  /// **'Суперадминистратор'**
  String get desktopRoleSuperAdmin;

  /// No description provided for @desktopRolePlatformSuperAdmin.
  ///
  /// In ru, this message translates to:
  /// **'Суперадминистратор платформы'**
  String get desktopRolePlatformSuperAdmin;

  /// No description provided for @desktopContactMeeting.
  ///
  /// In ru, this message translates to:
  /// **'Встреча'**
  String get desktopContactMeeting;

  /// No description provided for @desktopContactScheduleMeeting.
  ///
  /// In ru, this message translates to:
  /// **'Назначить встречу'**
  String get desktopContactScheduleMeeting;

  /// No description provided for @desktopContactCopyAddress.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать адрес'**
  String get desktopContactCopyAddress;

  /// No description provided for @desktopCalendarEmailParticipants.
  ///
  /// In ru, this message translates to:
  /// **'Написать участникам'**
  String get desktopCalendarEmailParticipants;

  /// No description provided for @desktopCalendarExternalGroup.
  ///
  /// In ru, this message translates to:
  /// **'Внешние участники'**
  String get desktopCalendarExternalGroup;

  /// No description provided for @desktopCalendarNoDepartment.
  ///
  /// In ru, this message translates to:
  /// **'Без подразделения'**
  String get desktopCalendarNoDepartment;

  /// No description provided for @desktopPaletteHint.
  ///
  /// In ru, this message translates to:
  /// **'Команда, раздел или поиск…'**
  String get desktopPaletteHint;

  /// No description provided for @desktopPaletteSearch.
  ///
  /// In ru, this message translates to:
  /// **'Искать «{query}» везде'**
  String desktopPaletteSearch(String query);

  /// No description provided for @desktopPaletteToggleTheme.
  ///
  /// In ru, this message translates to:
  /// **'Переключить светлую / тёмную тему'**
  String get desktopPaletteToggleTheme;

  /// No description provided for @desktopPaletteGoTo.
  ///
  /// In ru, this message translates to:
  /// **'Перейти'**
  String get desktopPaletteGoTo;

  /// No description provided for @desktopPaletteCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get desktopPaletteCreate;

  /// No description provided for @desktopPaletteNothing.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get desktopPaletteNothing;

  /// No description provided for @desktopCallStart.
  ///
  /// In ru, this message translates to:
  /// **'Позвонить'**
  String get desktopCallStart;

  /// No description provided for @desktopCallWithVideo.
  ///
  /// In ru, this message translates to:
  /// **'С видео'**
  String get desktopCallWithVideo;

  /// No description provided for @desktopCallShortcuts.
  ///
  /// In ru, this message translates to:
  /// **'Звонок'**
  String get desktopCallShortcuts;

  /// No description provided for @desktopMailSettingsShortcuts.
  ///
  /// In ru, this message translates to:
  /// **'Клавиши'**
  String get desktopMailSettingsShortcuts;

  /// No description provided for @desktopMailSettingsShortcutsHint.
  ///
  /// In ru, this message translates to:
  /// **'Работайте без мыши. Нажмите ? в любом месте, чтобы открыть этот список.'**
  String get desktopMailSettingsShortcutsHint;

  /// No description provided for @desktopMailKeysCalendarPrevNext.
  ///
  /// In ru, this message translates to:
  /// **'Предыдущий / следующий период'**
  String get desktopMailKeysCalendarPrevNext;

  /// No description provided for @desktopMailKeysCalendarClosePanel.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть панель события'**
  String get desktopMailKeysCalendarClosePanel;

  /// No description provided for @desktopMailRestored.
  ///
  /// In ru, this message translates to:
  /// **'Возвращено'**
  String get desktopMailRestored;

  /// No description provided for @desktopCrashTitle.
  ///
  /// In ru, this message translates to:
  /// **'XatBox закрылся неожиданно'**
  String get desktopCrashTitle;

  /// No description provided for @desktopCrashBody.
  ///
  /// In ru, this message translates to:
  /// **'В прошлый раз программа завершилась с ошибкой. Отправить разработчикам журнал её последних действий? В нём нет текста писем и сообщений, паролей и адресов.'**
  String get desktopCrashBody;

  /// No description provided for @desktopCrashSend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get desktopCrashSend;

  /// No description provided for @desktopCrashSkip.
  ///
  /// In ru, this message translates to:
  /// **'Не отправлять'**
  String get desktopCrashSkip;

  /// No description provided for @desktopCrashSent.
  ///
  /// In ru, this message translates to:
  /// **'Спасибо, отчёт отправлен'**
  String get desktopCrashSent;

  /// No description provided for @desktopCrashReport.
  ///
  /// In ru, this message translates to:
  /// **'Автоотчёт: XatBox {version} закрылся неожиданно (запуск {time})'**
  String desktopCrashReport(String version, String time);

  /// No description provided for @desktopMailMovedTo.
  ///
  /// In ru, this message translates to:
  /// **'Перемещено в «{folder}»'**
  String desktopMailMovedTo(String folder);

  /// No description provided for @desktopMailHideList.
  ///
  /// In ru, this message translates to:
  /// **'Скрыть список писем'**
  String get desktopMailHideList;

  /// No description provided for @desktopMailShowList.
  ///
  /// In ru, this message translates to:
  /// **'Показать список писем'**
  String get desktopMailShowList;

  /// No description provided for @desktopMailLinkElsewhereTitle.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка ведёт на другой сайт'**
  String get desktopMailLinkElsewhereTitle;

  /// No description provided for @desktopMailLinkElsewhereBody.
  ///
  /// In ru, this message translates to:
  /// **'В тексте показан один адрес, а открывается другой. Всё равно открыть?\n\nПоказано: {shown}\nОткрывается: {real}'**
  String desktopMailLinkElsewhereBody(String shown, String real);

  /// No description provided for @desktopMailLinkOpenAnyway.
  ///
  /// In ru, this message translates to:
  /// **'Всё равно открыть'**
  String get desktopMailLinkOpenAnyway;

  /// No description provided for @desktopMailQuickReplyHint.
  ///
  /// In ru, this message translates to:
  /// **'Напишите ответ… ({keys} для отправки)'**
  String desktopMailQuickReplyHint(String keys);

  /// No description provided for @desktopMailQuickReplyAttach.
  ///
  /// In ru, this message translates to:
  /// **'Прикрепить файл'**
  String get desktopMailQuickReplyAttach;

  /// No description provided for @desktopMailQuickReplyUploading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка…'**
  String get desktopMailQuickReplyUploading;

  /// No description provided for @desktopMailQuickReplyUploadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить'**
  String get desktopMailQuickReplyUploadFailed;

  /// No description provided for @desktopMailQuickReplyRemoveFile.
  ///
  /// In ru, this message translates to:
  /// **'Убрать файл'**
  String get desktopMailQuickReplyRemoveFile;

  /// No description provided for @desktopMailQuickReplySentTo.
  ///
  /// In ru, this message translates to:
  /// **'Отправлено: {recipients} · {time}'**
  String desktopMailQuickReplySentTo(String recipients, String time);

  /// No description provided for @desktopShortcutPalette.
  ///
  /// In ru, this message translates to:
  /// **'Палитра команд'**
  String get desktopShortcutPalette;

  /// No description provided for @desktopChatCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get desktopChatCreate;

  /// No description provided for @desktopChatDetails.
  ///
  /// In ru, this message translates to:
  /// **'Сведения'**
  String get desktopChatDetails;

  /// No description provided for @mailOutboxQueued.
  ///
  /// In ru, this message translates to:
  /// **'Нет сети — письмо в «Исходящих» и уйдёт, когда появится связь'**
  String get mailOutboxQueued;

  /// No description provided for @mailOutboxTitle.
  ///
  /// In ru, this message translates to:
  /// **'Исходящие: {count}'**
  String mailOutboxTitle(int count);

  /// No description provided for @mailOutboxHint.
  ///
  /// In ru, this message translates to:
  /// **'отправятся автоматически, когда появится связь'**
  String get mailOutboxHint;

  /// No description provided for @mailOutboxWaiting.
  ///
  /// In ru, this message translates to:
  /// **'Ждёт сети'**
  String get mailOutboxWaiting;

  /// No description provided for @mailOutboxSending.
  ///
  /// In ru, this message translates to:
  /// **'Отправляется…'**
  String get mailOutboxSending;

  /// No description provided for @mailOutboxFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не отправлено: {error}'**
  String mailOutboxFailed(String error);

  /// No description provided for @mailOutboxSendNow.
  ///
  /// In ru, this message translates to:
  /// **'Отправить сейчас'**
  String get mailOutboxSendNow;

  /// No description provided for @mailOutboxDiscard.
  ///
  /// In ru, this message translates to:
  /// **'Удалить из «Исходящих»'**
  String get mailOutboxDiscard;

  /// No description provided for @mailOutboxSent.
  ///
  /// In ru, this message translates to:
  /// **'Письма из «Исходящих» отправлены: {count}'**
  String mailOutboxSent(int count);

  /// No description provided for @skinGlassForest.
  ///
  /// In ru, this message translates to:
  /// **'Лесное стекло'**
  String get skinGlassForest;

  /// No description provided for @skinGlassForestHint.
  ///
  /// In ru, this message translates to:
  /// **'Прозрачные панели над утренним лесом'**
  String get skinGlassForestHint;

  /// No description provided for @skinGlassSpace.
  ///
  /// In ru, this message translates to:
  /// **'Космос'**
  String get skinGlassSpace;

  /// No description provided for @skinGlassSpaceHint.
  ///
  /// In ru, this message translates to:
  /// **'Прозрачные панели над звёздным небом'**
  String get skinGlassSpaceHint;

  /// No description provided for @desktopEventTitleHint.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте название'**
  String get desktopEventTitleHint;

  /// No description provided for @desktopEventDurationMinutes.
  ///
  /// In ru, this message translates to:
  /// **'{count} мин'**
  String desktopEventDurationMinutes(int count);

  /// No description provided for @desktopEventDurationHours.
  ///
  /// In ru, this message translates to:
  /// **'{count} ч'**
  String desktopEventDurationHours(int count);

  /// No description provided for @desktopEventDurationHoursMinutes.
  ///
  /// In ru, this message translates to:
  /// **'{hours} ч {minutes} мин'**
  String desktopEventDurationHoursMinutes(int hours, int minutes);

  /// No description provided for @desktopEventParticipantsHint.
  ///
  /// In ru, this message translates to:
  /// **'Пригласите коллег: имя или email'**
  String get desktopEventParticipantsHint;

  /// No description provided for @desktopEventInviteEmail.
  ///
  /// In ru, this message translates to:
  /// **'Пригласить {email}'**
  String desktopEventInviteEmail(String email);

  /// No description provided for @desktopEventLocationHint.
  ///
  /// In ru, this message translates to:
  /// **'Добавить место'**
  String get desktopEventLocationHint;

  /// No description provided for @desktopEventDescriptionHint.
  ///
  /// In ru, this message translates to:
  /// **'Описание или повестка'**
  String get desktopEventDescriptionHint;

  /// No description provided for @desktopEventMore.
  ///
  /// In ru, this message translates to:
  /// **'Ещё: ссылка, переговорная, подбор времени'**
  String get desktopEventMore;

  /// No description provided for @desktopEventLess.
  ///
  /// In ru, this message translates to:
  /// **'Скрыть дополнительные настройки'**
  String get desktopEventLess;

  /// No description provided for @desktopEventRepeatCustom.
  ///
  /// In ru, this message translates to:
  /// **'Настроить…'**
  String get desktopEventRepeatCustom;

  /// No description provided for @desktopEventSaveHint.
  ///
  /// In ru, this message translates to:
  /// **'{keys} — сохранить'**
  String desktopEventSaveHint(String keys);

  /// No description provided for @desktopEventReminder.
  ///
  /// In ru, this message translates to:
  /// **'Напоминание'**
  String get desktopEventReminder;

  /// No description provided for @desktopEventOtherTime.
  ///
  /// In ru, this message translates to:
  /// **'Другое время…'**
  String get desktopEventOtherTime;

  /// No description provided for @desktopEventNoReminders.
  ///
  /// In ru, this message translates to:
  /// **'Без напоминаний'**
  String get desktopEventNoReminders;

  /// No description provided for @tasksBoardByDue.
  ///
  /// In ru, this message translates to:
  /// **'По срокам'**
  String get tasksBoardByDue;

  /// No description provided for @tasksBoardByStatus.
  ///
  /// In ru, this message translates to:
  /// **'По статусу'**
  String get tasksBoardByStatus;

  /// No description provided for @tasksColumnTomorrow.
  ///
  /// In ru, this message translates to:
  /// **'Завтра'**
  String get tasksColumnTomorrow;

  /// No description provided for @tasksColumnLater.
  ///
  /// In ru, this message translates to:
  /// **'Позже'**
  String get tasksColumnLater;

  /// No description provided for @tasksColumnDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get tasksColumnDone;

  /// No description provided for @tasksColumnTodo.
  ///
  /// In ru, this message translates to:
  /// **'К выполнению'**
  String get tasksColumnTodo;

  /// No description provided for @tasksColumnInProgress.
  ///
  /// In ru, this message translates to:
  /// **'В работе'**
  String get tasksColumnInProgress;

  /// No description provided for @tasksQuickAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить задачу'**
  String get tasksQuickAdd;

  /// No description provided for @tasksQuickAddHint.
  ///
  /// In ru, this message translates to:
  /// **'Что нужно сделать? Enter — добавить'**
  String get tasksQuickAddHint;

  /// No description provided for @tasksDropHere.
  ///
  /// In ru, this message translates to:
  /// **'Перетащите задачу сюда'**
  String get tasksDropHere;

  /// No description provided for @tasksBoardHintDue.
  ///
  /// In ru, this message translates to:
  /// **'Перетаскивайте карточки между колонками — срок изменится сам'**
  String get tasksBoardHintDue;

  /// No description provided for @tasksBoardHintStatus.
  ///
  /// In ru, this message translates to:
  /// **'Перетаскивайте карточки, чтобы менять статус'**
  String get tasksBoardHintStatus;

  /// No description provided for @tasksStatToday.
  ///
  /// In ru, this message translates to:
  /// **'На сегодня: {count}'**
  String tasksStatToday(int count);

  /// No description provided for @tasksStatOverdue.
  ///
  /// In ru, this message translates to:
  /// **'Просрочено: {count}'**
  String tasksStatOverdue(int count);

  /// No description provided for @tasksStatDone.
  ///
  /// In ru, this message translates to:
  /// **'Выполнено: {count}'**
  String tasksStatDone(int count);

  /// No description provided for @tasksShowAll.
  ///
  /// In ru, this message translates to:
  /// **'Показать все · {count}'**
  String tasksShowAll(int count);

  /// No description provided for @tasksShowLess.
  ///
  /// In ru, this message translates to:
  /// **'Свернуть'**
  String get tasksShowLess;

  /// No description provided for @tasksPickDay.
  ///
  /// In ru, this message translates to:
  /// **'На какой день перенести?'**
  String get tasksPickDay;

  /// No description provided for @tasksSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по задачам'**
  String get tasksSearchHint;

  /// No description provided for @tasksFromMail.
  ///
  /// In ru, this message translates to:
  /// **'Из письма'**
  String get tasksFromMail;

  /// No description provided for @tasksMarkInProgress.
  ///
  /// In ru, this message translates to:
  /// **'Взять в работу'**
  String get tasksMarkInProgress;

  /// No description provided for @tasksArchive.
  ///
  /// In ru, this message translates to:
  /// **'В архив'**
  String get tasksArchive;

  /// No description provided for @tasksArchived.
  ///
  /// In ru, this message translates to:
  /// **'Задача перенесена в архив'**
  String get tasksArchived;

  /// No description provided for @tasksRestore.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть'**
  String get tasksRestore;

  /// No description provided for @tasksRestored.
  ///
  /// In ru, this message translates to:
  /// **'Задача возвращена на доску'**
  String get tasksRestored;

  /// No description provided for @tasksArchiveTitle.
  ///
  /// In ru, this message translates to:
  /// **'Архив'**
  String get tasksArchiveTitle;

  /// No description provided for @tasksArchiveEmpty.
  ///
  /// In ru, this message translates to:
  /// **'В архиве пока пусто. Готовые задачи можно убрать сюда из меню карточки.'**
  String get tasksArchiveEmpty;

  /// No description provided for @tasksArchiveAllBoards.
  ///
  /// In ru, this message translates to:
  /// **'Все доски'**
  String get tasksArchiveAllBoards;

  /// No description provided for @tasksArchiveThisBoard.
  ///
  /// In ru, this message translates to:
  /// **'Только эта доска'**
  String get tasksArchiveThisBoard;

  /// No description provided for @myContactsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Мои контакты'**
  String get myContactsTitle;

  /// No description provided for @myContactsAllStaff.
  ///
  /// In ru, this message translates to:
  /// **'Все сотрудники'**
  String get myContactsAllStaff;

  /// No description provided for @myContactsDepartments.
  ///
  /// In ru, this message translates to:
  /// **'Отделы'**
  String get myContactsDepartments;

  /// No description provided for @myContactsNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый контакт'**
  String get myContactsNew;

  /// No description provided for @myContactsPin.
  ///
  /// In ru, this message translates to:
  /// **'Добавить в мои контакты'**
  String get myContactsPin;

  /// No description provided for @myContactsUnpin.
  ///
  /// In ru, this message translates to:
  /// **'Убрать из моих контактов'**
  String get myContactsUnpin;

  /// No description provided for @myContactsPinned.
  ///
  /// In ru, this message translates to:
  /// **'{name} — в ваших контактах'**
  String myContactsPinned(String name);

  /// No description provided for @myContactsEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Здесь будут ваши контакты'**
  String get myContactsEmptyTitle;

  /// No description provided for @myContactsEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Закрепите коллег звёздочкой в списке сотрудников или добавьте человека не из университета'**
  String get myContactsEmptyHint;

  /// No description provided for @myContactsBrowseStaff.
  ///
  /// In ru, this message translates to:
  /// **'Открыть сотрудников'**
  String get myContactsBrowseStaff;

  /// No description provided for @myContactsSectionStaff.
  ///
  /// In ru, this message translates to:
  /// **'Сотрудники'**
  String get myContactsSectionStaff;

  /// No description provided for @myContactsSectionPersonal.
  ///
  /// In ru, this message translates to:
  /// **'Личные контакты'**
  String get myContactsSectionPersonal;

  /// No description provided for @myContactsPersonalTag.
  ///
  /// In ru, this message translates to:
  /// **'Личный'**
  String get myContactsPersonalTag;

  /// No description provided for @myContactsSelect.
  ///
  /// In ru, this message translates to:
  /// **'Выберите контакт, чтобы увидеть подробности'**
  String get myContactsSelect;

  /// No description provided for @myContactsNothingFound.
  ///
  /// In ru, this message translates to:
  /// **'Никого не нашли'**
  String get myContactsNothingFound;

  /// No description provided for @personalContactName.
  ///
  /// In ru, this message translates to:
  /// **'Имя и фамилия'**
  String get personalContactName;

  /// No description provided for @personalContactNameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя'**
  String get personalContactNameRequired;

  /// No description provided for @personalContactEmail.
  ///
  /// In ru, this message translates to:
  /// **'Email'**
  String get personalContactEmail;

  /// No description provided for @personalContactEmailInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте адрес почты'**
  String get personalContactEmailInvalid;

  /// No description provided for @personalContactPhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get personalContactPhone;

  /// No description provided for @personalContactOrganization.
  ///
  /// In ru, this message translates to:
  /// **'Организация'**
  String get personalContactOrganization;

  /// No description provided for @personalContactPosition.
  ///
  /// In ru, this message translates to:
  /// **'Должность'**
  String get personalContactPosition;

  /// No description provided for @personalContactNote.
  ///
  /// In ru, this message translates to:
  /// **'Заметка'**
  String get personalContactNote;

  /// No description provided for @personalContactEdit.
  ///
  /// In ru, this message translates to:
  /// **'Изменить контакт'**
  String get personalContactEdit;

  /// No description provided for @personalContactDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить контакт'**
  String get personalContactDelete;

  /// No description provided for @personalContactDeleteConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить «{name}» из ваших контактов?'**
  String personalContactDeleteConfirm(String name);

  /// No description provided for @personalContactSaved.
  ///
  /// In ru, this message translates to:
  /// **'Контакт сохранён'**
  String get personalContactSaved;

  /// No description provided for @personalContactDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Контакт удалён'**
  String get personalContactDeleted;

  /// No description provided for @personalContactLocalNote.
  ///
  /// In ru, this message translates to:
  /// **'Личные контакты хранятся на этом компьютере'**
  String get personalContactLocalNote;

  /// No description provided for @personalContactCall.
  ///
  /// In ru, this message translates to:
  /// **'Позвонить'**
  String get personalContactCall;

  /// No description provided for @skinGlassAstana.
  ///
  /// In ru, this message translates to:
  /// **'Астана'**
  String get skinGlassAstana;

  /// No description provided for @skinGlassAstanaHint.
  ///
  /// In ru, this message translates to:
  /// **'Прозрачные панели над фотографией Астаны'**
  String get skinGlassAstanaHint;

  /// No description provided for @skinGlassSemey.
  ///
  /// In ru, this message translates to:
  /// **'Семей'**
  String get skinGlassSemey;

  /// No description provided for @skinGlassSemeyHint.
  ///
  /// In ru, this message translates to:
  /// **'Прозрачные панели над мостом через Иртыш'**
  String get skinGlassSemeyHint;

  /// No description provided for @skinGlassCustom.
  ///
  /// In ru, this message translates to:
  /// **'Свой фон'**
  String get skinGlassCustom;

  /// No description provided for @skinGlassCustomHint.
  ///
  /// In ru, this message translates to:
  /// **'Прозрачные панели над вашей картинкой'**
  String get skinGlassCustomHint;

  /// No description provided for @settingsBackdropOwn.
  ///
  /// In ru, this message translates to:
  /// **'Своя картинка'**
  String get settingsBackdropOwn;

  /// No description provided for @settingsBackdropOwnHint.
  ///
  /// In ru, this message translates to:
  /// **'Картинка скопирована в папку XatBox, оригинал можно удалить'**
  String get settingsBackdropOwnHint;

  /// No description provided for @settingsBackdropNone.
  ///
  /// In ru, this message translates to:
  /// **'Картинка не выбрана — пока просто тёмный фон'**
  String get settingsBackdropNone;

  /// No description provided for @settingsBackdropPick.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать картинку'**
  String get settingsBackdropPick;

  /// No description provided for @settingsBackdropReplace.
  ///
  /// In ru, this message translates to:
  /// **'Заменить картинку'**
  String get settingsBackdropReplace;

  /// No description provided for @settingsBackdropRemove.
  ///
  /// In ru, this message translates to:
  /// **'Убрать'**
  String get settingsBackdropRemove;

  /// No description provided for @settingsBackdropDim.
  ///
  /// In ru, this message translates to:
  /// **'Затемнение'**
  String get settingsBackdropDim;

  /// No description provided for @settingsBackdropBlur.
  ///
  /// In ru, this message translates to:
  /// **'Размытие'**
  String get settingsBackdropBlur;

  /// No description provided for @settingsBackdropFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прочитать картинку'**
  String get settingsBackdropFailed;

  /// No description provided for @settingsBackdropCredits.
  ///
  /// In ru, this message translates to:
  /// **'Фотографии фонов'**
  String get settingsBackdropCredits;

  /// No description provided for @settingsBackdropCreditAstana.
  ///
  /// In ru, this message translates to:
  /// **'«Астана» — фото Dauren Nabijan, CC0, Wikimedia Commons'**
  String get settingsBackdropCreditAstana;

  /// No description provided for @settingsBackdropCreditSemey.
  ///
  /// In ru, this message translates to:
  /// **'«Семей» — фото Иван Быков, CC BY 3.0, обрезано, Wikimedia Commons'**
  String get settingsBackdropCreditSemey;

  /// No description provided for @mailSettingsImport.
  ///
  /// In ru, this message translates to:
  /// **'Импорт почты'**
  String get mailSettingsImport;

  /// No description provided for @mailSettingsImportSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Перенести письма из прежней почтовой системы'**
  String get mailSettingsImportSubtitle;

  /// No description provided for @mailImportHint.
  ///
  /// In ru, this message translates to:
  /// **'Перенесите письма из прежней почтовой системы в этот ящик. Ничего не заменяется: всё, что уже лежит в папках, остаётся, а письмо, которое у вас уже есть, распознаётся и не задваивается.'**
  String get mailImportHint;

  /// No description provided for @mailImportFile.
  ///
  /// In ru, this message translates to:
  /// **'Архив (.tgz)'**
  String get mailImportFile;

  /// No description provided for @mailImportFileHint.
  ///
  /// In ru, this message translates to:
  /// **'Файл, который прежняя почтовая система выгрузила для вашей учётной записи. Zimbra: Настройки → Импорт/Экспорт → Экспорт. До 2 ГБ; импорт идёт в фоне, приложение можно закрыть.'**
  String get mailImportFileHint;

  /// No description provided for @mailImportChoose.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать архив'**
  String get mailImportChoose;

  /// No description provided for @mailImportStart.
  ///
  /// In ru, this message translates to:
  /// **'Загрузить и импортировать'**
  String get mailImportStart;

  /// No description provided for @mailImportUploading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка {percent}%'**
  String mailImportUploading(int percent);

  /// No description provided for @mailImportCancelUpload.
  ///
  /// In ru, this message translates to:
  /// **'Прервать загрузку'**
  String get mailImportCancelUpload;

  /// No description provided for @mailImportPickFile.
  ///
  /// In ru, this message translates to:
  /// **'Сначала выберите архив'**
  String get mailImportPickFile;

  /// No description provided for @mailImportWrongName.
  ///
  /// In ru, this message translates to:
  /// **'Архив назван не по вашему ящику. Загрузите файл с именем {mailbox}.tgz'**
  String mailImportWrongName(String mailbox);

  /// No description provided for @mailImportQueued.
  ///
  /// In ru, this message translates to:
  /// **'Файл загружен: импорт начнётся через несколько секунд'**
  String get mailImportQueued;

  /// No description provided for @mailImportImported.
  ///
  /// In ru, this message translates to:
  /// **'{imported} из {total} импортировано'**
  String mailImportImported(int imported, int total);

  /// No description provided for @mailImportAlready.
  ///
  /// In ru, this message translates to:
  /// **'{count} уже были здесь'**
  String mailImportAlready(int count);

  /// No description provided for @mailImportFailedCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} не удалось добавить'**
  String mailImportFailedCount(int count);

  /// No description provided for @mailImportNotMail.
  ///
  /// In ru, this message translates to:
  /// **'{count} не почта (контакты, календарь)'**
  String mailImportNotMail(int count);

  /// No description provided for @mailImportDeleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Убрать эту запись об импорте?'**
  String get mailImportDeleteTitle;

  /// No description provided for @mailImportDeleteBody.
  ///
  /// In ru, this message translates to:
  /// **'Запись и загруженный файл будут удалены. Уже импортированные письма останутся в ваших папках.'**
  String get mailImportDeleteBody;

  /// No description provided for @mailImportFailedGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось начать импорт'**
  String get mailImportFailedGeneric;

  /// No description provided for @mailImportStatusQueued.
  ///
  /// In ru, this message translates to:
  /// **'В очереди'**
  String get mailImportStatusQueued;

  /// No description provided for @mailImportStatusRunning.
  ///
  /// In ru, this message translates to:
  /// **'Импорт идёт'**
  String get mailImportStatusRunning;

  /// No description provided for @mailImportStatusDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get mailImportStatusDone;

  /// No description provided for @mailImportStatusFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get mailImportStatusFailed;

  /// No description provided for @requestsNumber.
  ///
  /// In ru, this message translates to:
  /// **'Заявка №{number}'**
  String requestsNumber(int number);

  /// No description provided for @requestsWhat.
  ///
  /// In ru, this message translates to:
  /// **'Что случилось'**
  String get requestsWhat;

  /// No description provided for @requestsWhatHint.
  ///
  /// In ru, this message translates to:
  /// **'Опишите проблему'**
  String get requestsWhatHint;

  /// No description provided for @requestsRoom.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет'**
  String get requestsRoom;

  /// No description provided for @requestsRoomHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, 305'**
  String get requestsRoomHint;

  /// No description provided for @requestsDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get requestsDate;

  /// No description provided for @requestsSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Отправить заявку'**
  String get requestsSubmit;

  /// No description provided for @requestsFillAll.
  ///
  /// In ru, this message translates to:
  /// **'Заполните все три поля'**
  String get requestsFillAll;

  /// No description provided for @requestsStatusNew.
  ///
  /// In ru, this message translates to:
  /// **'Новая'**
  String get requestsStatusNew;

  /// No description provided for @requestsStatusInProgress.
  ///
  /// In ru, this message translates to:
  /// **'В работе'**
  String get requestsStatusInProgress;

  /// No description provided for @requestsStatusDone.
  ///
  /// In ru, this message translates to:
  /// **'Выполнена'**
  String get requestsStatusDone;

  /// No description provided for @requestsStatusRejected.
  ///
  /// In ru, this message translates to:
  /// **'Отклонена'**
  String get requestsStatusRejected;

  /// No description provided for @requestsEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Здесь будут ваши заявки'**
  String get requestsEmptyTitle;

  /// No description provided for @requestsEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Заполните форму ниже: что случилось, кабинет и дата. Ответ придёт в этот чат.'**
  String get requestsEmptyHint;

  /// No description provided for @requestsListHint.
  ///
  /// In ru, this message translates to:
  /// **'Подать заявку'**
  String get requestsListHint;

  /// No description provided for @tabMore.
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get tabMore;

  /// No description provided for @contactsFilterMine.
  ///
  /// In ru, this message translates to:
  /// **'Мои'**
  String get contactsFilterMine;

  /// No description provided for @notifTestHintPhone.
  ///
  /// In ru, this message translates to:
  /// **'Показать пробное уведомление на этом телефоне'**
  String get notifTestHintPhone;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'kk', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'kk':
      return AppLocalizationsKk();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
