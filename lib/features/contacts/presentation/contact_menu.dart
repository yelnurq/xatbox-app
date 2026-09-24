import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../calendar/data/calendar_models.dart';
import '../../calendar/presentation/calendar_providers.dart';
import '../../calendar/presentation/calendar_widgets.dart';
import '../../calendar/presentation/event_edit_screen.dart' show EventEditArgs;
import '../../calls/presentation/calls_providers.dart';
import '../../chat/presentation/chat_formatters.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../mail/presentation/compose_screen.dart';
import '../../mail/presentation/compose_window.dart';
import '../data/contact_models.dart';
import 'contacts_providers.dart';

/// Desktop «Назначить встречу» with [contact]: the new-event dialog with
/// the colleague already invited.
Future<void> scheduleMeetingWith(BuildContext context, Contact contact) => openEventEditor(
  context,
  EventEditArgs.create(
    participants: [DraftParticipant.internal(userId: contact.id, label: contact.label, email: contact.mailAddress)],
  ),
);

/// Desktop: the directory row's right-click menu at [at] — message, call,
/// letter, meeting, copy the address (the web's contact actions).
Future<void> showContactMenu(BuildContext context, WidgetRef ref, Contact contact, Offset at) async {
  final l10n = context.l10n;
  final chat = ref.read(chatEnabledProvider);
  final calls = ref.read(callsEnabledProvider);
  final meeting = ref.read(calendarEnabledProvider) && ref.read(calendarCanCreateProvider);
  final address = contact.mailAddress;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  PopupMenuItem<String> item(String value, IconData icon, String label) => PopupMenuItem(
    key: Key('contact_menu_$value'),
    value: value,
    child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(icon, size: 18), title: Text(label)),
  );
  final pinned = ref.read(contactsFavouriteIdsProvider).contains(contact.id);
  final picked = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(at & const Size(1, 1), Offset.zero & overlay.size),
    items: [
      item('pin', pinned ? LucideIcons.starOff : LucideIcons.star, pinned ? l10n.myContactsUnpin : l10n.myContactsPin),
      if (chat) item('chat', LucideIcons.messageCircle, l10n.contactsWrite),
      if (calls) ...[
        item('audio', LucideIcons.phone, l10n.contactsAudioCall),
        item('video', LucideIcons.video, l10n.contactsVideoCall),
      ],
      if (address.isNotEmpty) item('mail', LucideIcons.mail, l10n.contactsWriteEmail),
      if (meeting) item('meeting', LucideIcons.calendarPlus, l10n.desktopContactScheduleMeeting),
      if (address.isNotEmpty) item('copy', LucideIcons.copy, l10n.desktopContactCopyAddress),
    ],
  );
  if (picked == null || !context.mounted) return;
  await runContactAction(context, ref, contact, picked);
}

/// Desktop: one contact action — `pin` (my contacts), `chat`, `audio`,
/// `video`, `mail`, `meeting`, `copy` — from the menu or a row's buttons.
Future<void> runContactAction(BuildContext context, WidgetRef ref, Contact contact, String picked) async {
  final l10n = context.l10n;
  final address = contact.mailAddress;
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  switch (picked) {
    case 'pin':
      final pinned = ref.read(contactsFavouriteIdsProvider).contains(contact.id);
      await ref.read(contactsFavouritesProvider.notifier).toggle(contact);
      if (!pinned) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.myContactsPinned(contact.label))));
      }
    case 'chat':
      try {
        final repo = ref.read(chatRepositoryProvider);
        final existing = (await repo.cachedConversations())
            .where((c) => !c.isGroup && c.peer?.userId == contact.id)
            .firstOrNull;
        final conv = existing ?? await repo.createDirect(contact.id);
        // Desktop: the messenger's pane (app_router redirect).
        unawaited(router.push(Routes.chatConversationPath(conv.id)));
      } on AppException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(ChatFormat.error(l10n, e))));
      }
    case 'audio' || 'video':
      final future = ref
          .read(callControllerProvider.notifier)
          .startCall(calleeIds: [contact.id], video: picked == 'video', mode: 'direct');
      unawaited(router.push(Routes.call));
      await future;
    case 'mail':
      openCompose(ref, ComposeArgs.to([address]));
    case 'meeting':
      await scheduleMeetingWith(context, contact);
    case 'copy':
      await Clipboard.setData(ClipboardData(text: address));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.contactsCopied(address))));
  }
}
