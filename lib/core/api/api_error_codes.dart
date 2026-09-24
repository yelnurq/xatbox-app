/// Stable error codes from the Xatbox Mobile API (`error.code`).
///
/// Only codes the app branches on are listed; unknown codes are still surfaced
/// to the user via a generic message.
abstract final class ApiErrorCodes {
  // Common
  static const unauthenticated = 'UNAUTHENTICATED';
  static const forbidden = 'FORBIDDEN';
  static const invalidBody = 'INVALID_BODY';
  static const internal = 'INTERNAL';

  // Auth
  static const invalidCredentialsFormat = 'INVALID_CREDENTIALS_FORMAT';
  static const invalidCredentials = 'INVALID_CREDENTIALS';
  static const userDisabled = 'USER_DISABLED';
  static const organizationSuspended = 'ORGANIZATION_SUSPENDED';
  static const directoryDisabled = 'DIRECTORY_DISABLED';
  static const tooManyAttempts = 'TOO_MANY_ATTEMPTS';
  static const directoryUnavailable = 'DIRECTORY_UNAVAILABLE';
  static const subscriptionLimit = 'SUBSCRIPTION_LIMIT';

  // Mail
  static const noMailbox = 'NO_MAILBOX';
  static const mailServiceUnavailable = 'MAIL_SERVICE_UNAVAILABLE';
  static const messageNotFound = 'MESSAGE_NOT_FOUND';
  static const folderNotFound = 'FOLDER_NOT_FOUND';
  static const senderNotInFolder = 'SENDER_NOT_IN_FOLDER';
  static const invalidFolder = 'INVALID_FOLDER';
  static const invalidMessage = 'INVALID_MESSAGE';
  static const draftNotFound = 'DRAFT_NOT_FOUND';
  static const attachmentTooLarge = 'ATTACHMENT_TOO_LARGE';
  static const attachmentNotFound = 'ATTACHMENT_NOT_FOUND';
  static const storageUnavailable = 'STORAGE_UNAVAILABLE';
  static const invalidKind = 'INVALID_KIND';

  // Mail: calendar invitations
  static const icsNotFound = 'ICS_NOT_FOUND';
  static const icsTooLarge = 'ICS_TOO_LARGE';
  static const invalidIcs = 'INVALID_ICS';
  static const invalidRsvp = 'INVALID_RSVP';

  // Mail settings / bookmark folders
  static const invalidFolderName = 'INVALID_FOLDER_NAME';
  static const folderExists = 'FOLDER_EXISTS';
  static const signatureTooLong = 'SIGNATURE_TOO_LONG';
  static const subjectTooLong = 'SUBJECT_TOO_LONG';
  static const bodyTooLong = 'BODY_TOO_LONG';
  static const vacationBodyRequired = 'VACATION_BODY_REQUIRED';
  static const invalidDates = 'INVALID_DATES';
  static const invalidTimeZone = 'INVALID_TIME_ZONE';
  static const invalidList = 'INVALID_LIST';
  static const emptyPattern = 'EMPTY_PATTERN';
  static const topLevelDomain = 'TOP_LEVEL_DOMAIN';
  static const networkTooWide = 'NETWORK_TOO_WIDE';
  static const ipv6Network = 'IPV6_NETWORK';
  static const invalidPattern = 'INVALID_PATTERN';
  static const noteTooLong = 'NOTE_TOO_LONG';
  static const ruleLimit = 'RULE_LIMIT';
  static const ruleExists = 'RULE_EXISTS';
  static const ruleNotFound = 'RULE_NOT_FOUND';

  // Blob → PDF preview
  static const converterUnavailable = 'CONVERTER_UNAVAILABLE';
  static const notConvertible = 'NOT_CONVERTIBLE';
  static const tooLarge = 'TOO_LARGE';
  static const convertTimeout = 'CONVERT_TIMEOUT';
  static const convertFailed = 'CONVERT_FAILED';
}
