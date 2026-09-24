import '../../core/api/api_error_codes.dart';
import '../../core/api/api_exception.dart';
import '../../core/localization/localization.dart';

/// Maps API/transport failures to user-facing Russian (localized) text.
/// Raw codes are never shown alone; unknown codes get a generic sentence with
/// the code in brackets so support can still identify it.
abstract final class ErrorText {
  static String describe(AppLocalizations l10n, Object error) {
    switch (error) {
      case NetworkException(:final isTimeout):
        return isTimeout ? l10n.errTimeout : l10n.errNetwork;
      case CancelledException():
        return l10n.errUnexpected;
      case UnexpectedApiException():
        return l10n.errUnexpected;
      case ApiException(:final code, :final serverMessage):
        return switch (code) {
          ApiErrorCodes.invalidCredentialsFormat =>
            l10n.errInvalidCredentialsFormat,
          ApiErrorCodes.invalidCredentials => l10n.errInvalidCredentials,
          ApiErrorCodes.userDisabled => l10n.errUserDisabled,
          ApiErrorCodes.organizationSuspended => l10n.errOrganizationSuspended,
          ApiErrorCodes.directoryDisabled => l10n.errDirectoryDisabled,
          ApiErrorCodes.tooManyAttempts => l10n.errTooManyAttempts,
          ApiErrorCodes.directoryUnavailable => l10n.errDirectoryUnavailable,
          ApiErrorCodes.subscriptionLimit => l10n.errSubscriptionLimit,
          ApiErrorCodes.internal => l10n.errInternal,
          ApiErrorCodes.unauthenticated => l10n.errUnauthenticated,
          ApiErrorCodes.forbidden => l10n.errForbidden,
          ApiErrorCodes.invalidBody => l10n.errInvalidBody,
          ApiErrorCodes.noMailbox => l10n.errNoMailbox,
          ApiErrorCodes.mailServiceUnavailable =>
            l10n.errMailServiceUnavailable,
          ApiErrorCodes.messageNotFound ||
          ApiErrorCodes.draftNotFound => l10n.errMessageNotFound,
          ApiErrorCodes.folderNotFound => l10n.errFolderNotFound,
          ApiErrorCodes.invalidMessage => l10n.errInvalidMessage(serverMessage),
          ApiErrorCodes.attachmentTooLarge => l10n.errAttachmentTooLarge,
          ApiErrorCodes.storageUnavailable => l10n.errStorageUnavailable,
          ApiErrorCodes.converterUnavailable => l10n.errConverterUnavailable,
          ApiErrorCodes.notConvertible => l10n.errNotConvertible,
          ApiErrorCodes.tooLarge => l10n.errAttachmentTooLarge,
          ApiErrorCodes.convertTimeout => l10n.errConvertTimeout,
          ApiErrorCodes.convertFailed => l10n.errConvertFailed,
          _ => l10n.errUnknown(code),
        };
      default:
        return l10n.errUnexpected;
    }
  }

  static bool isOffline(Object? error) => error is NetworkException;
}
