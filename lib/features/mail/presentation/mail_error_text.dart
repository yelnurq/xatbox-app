import '../../../core/api/api_error_codes.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../shared/utils/error_text.dart';

/// Mail-settings / invitation error codes on top of the shared mapping.
abstract final class MailErrorText {
  static String describe(AppLocalizations l10n, Object error) {
    if (error is ApiException) {
      final text = switch (error.code) {
        ApiErrorCodes.invalidFolderName => l10n.mailBookmarkFolderNameInvalid,
        ApiErrorCodes.folderExists => l10n.mailErrFolderExists,
        ApiErrorCodes.signatureTooLong => l10n.mailSignatureTooLong,
        ApiErrorCodes.subjectTooLong => l10n.mailVacationSubjectTooLong,
        ApiErrorCodes.bodyTooLong => l10n.mailVacationBodyTooLong,
        ApiErrorCodes.vacationBodyRequired => l10n.mailVacationBodyRequired,
        ApiErrorCodes.invalidDates => l10n.mailVacationDatesInvalid,
        ApiErrorCodes.invalidTimeZone => l10n.mailVacationTimeZoneInvalid,
        ApiErrorCodes.invalidList => l10n.mailErrInvalidList,
        ApiErrorCodes.emptyPattern => l10n.mailErrEmptyPattern,
        ApiErrorCodes.topLevelDomain => l10n.mailErrTopLevelDomain,
        ApiErrorCodes.networkTooWide => l10n.mailErrNetworkTooWide,
        ApiErrorCodes.ipv6Network => l10n.mailErrIpv6Network,
        ApiErrorCodes.invalidPattern => l10n.mailErrInvalidPattern,
        ApiErrorCodes.noteTooLong => l10n.mailErrNoteTooLong,
        ApiErrorCodes.ruleLimit => l10n.mailErrRuleLimit,
        ApiErrorCodes.ruleExists => l10n.mailErrRuleExists,
        ApiErrorCodes.ruleNotFound => l10n.mailErrRuleNotFound,
        ApiErrorCodes.icsNotFound => l10n.mailErrIcsNotFound,
        ApiErrorCodes.icsTooLarge => l10n.mailErrIcsTooLarge,
        ApiErrorCodes.invalidIcs => l10n.mailErrInvalidIcs,
        ApiErrorCodes.invalidRsvp => l10n.mailErrInvalidRsvp,
        _ => null,
      };
      if (text != null) return text;
    }
    return ErrorText.describe(l10n, error);
  }
}
