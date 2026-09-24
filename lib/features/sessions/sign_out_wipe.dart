import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/security/app_lock.dart';
import '../../shared/utils/diagnostic_log.dart';
import '../calendar/presentation/calendar_providers.dart';
import '../calls/presentation/calls_providers.dart';
import '../chat/presentation/chat_providers.dart';
import '../contacts/presentation/contacts_providers.dart';
import '../search/presentation/search_providers.dart';
import '../home_widget/home_widget_service.dart';
import '../mail/presentation/mail_outbox.dart';
import '../mail/presentation/mail_providers.dart';
import '../mail/presentation/mail_undo_send.dart';
import '../mail/presentation/mail_ux_settings.dart';
import '../official/presentation/official_providers.dart';
import '../tasks/presentation/tasks_providers.dart';
import '../update/presentation/update_controller.dart';

/// Everything a sign-out wipes on this device (ТЗ п.24.4). The same hooks
/// run for an explicit «Выйти», for a session ended from another device
/// («Мои устройства и сеансы» → the next request or socket answers 401) and
/// for a stored token rejected at launch: mail cache and drafts, opened
/// attachments, calls, chat stores / media / push key, calendar, contacts,
/// queued error reports, downloaded update APKs and the app-lock PIN.
void registerSignOutWipes(ProviderContainer container) {
  final session = container.read(authSessionProvider);
  session.addSignOutHook(
    () => container.read(mailRepositoryProvider).clearCache(),
  );
  session.addSignOutHook(
    () => container.read(attachmentDownloaderProvider).clearTemporaryFiles(),
  );
  // Recently used recipients; sends still waiting out the undo delay stay
  // as drafts on the server.
  session.addSignOutHook(() async {
    container.invalidate(mailUndoSendProvider);
    await container.read(mailRecentRecipientsProvider.notifier).clear();
  });
  // Letters still waiting in «Исходящие».
  session.addSignOutHook(() => mailOutboxSignOut(container));
  // Calls first: it hangs up and removes the VoIP registration through the
  // chat API, which chatSignOut then closes.
  session.addSignOutHook(() => callsSignOut(container));
  session.addSignOutHook(() => chatSignOut(container));
  session.addSignOutHook(() => calendarSignOut(container));
  session.addSignOutHook(() => contactsSignOut(container));
  session.addSignOutHook(() => officialSignOut(container));
  session.addSignOutHook(() => tasksSignOut(container));
  session.addSignOutHook(() => searchSignOut(container));
  // Home screen widget and recent-chat app shortcuts keep no chat data.
  session.addSignOutHook(() => clearLauncherData(container));
  session.addSignOutHook(() async {
    try {
      await container.read(apkDownloaderProvider).clear();
    } on Object catch (e) {
      DiagnosticLog.warn('update', 'downloaded APKs not removed', error: e);
    }
  });
  // The PIN belongs to the signed-in user.
  session.addSignOutHook(() => container.read(appLockProvider.notifier).reset());
}
