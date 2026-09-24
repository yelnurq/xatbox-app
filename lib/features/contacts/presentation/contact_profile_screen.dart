import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop_layout.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/ds/x_badge.dart';
import '../../../shared/widgets/state_view.dart';
import '../../calls/presentation/calls_providers.dart';
import '../../calendar/presentation/calendar_providers.dart';
import '../../chat/data/chat_models.dart';
import '../../chat/presentation/chat_avatar.dart';
import '../../chat/presentation/chat_formatters.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../chat/presentation/status/chat_status_providers.dart';
import '../../mail/presentation/compose_screen.dart';
import '../data/contact_models.dart';
import 'contact_widgets.dart';
import 'contact_menu.dart';
import 'contacts_providers.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../mail/presentation/compose_window.dart';

/// Colleague profile (`/contacts/u/:id`): hero with presence, quick actions
/// (chat, audio/video call, email), contact and department cards, colleagues,
/// shared groups, favourite and share.
/// Two columns (card + details) need this much width; the contacts page's
/// side pane (340–480 px) shows the one-column profile instead.
const _twoColumnMinWidth = 720.0;

class ContactProfileScreen extends ConsumerStatefulWidget {
  const ContactProfileScreen({super.key, required this.userId, this.initial});

  final String userId;

  /// Row tapped in the list (shown at once, refreshed from the service);
  /// null for deep links.
  final Contact? initial;

  @override
  ConsumerState<ContactProfileScreen> createState() =>
      _ContactProfileScreenState();
}

/// "в сети" / "был(а) N мин назад" (pure except for the clock).
String contactPresenceText(
  BuildContext context,
  Contact contact, {
  DateTime? now,
}) {
  final l10n = context.l10n;
  if (contact.online) return l10n.chatOnline;
  final seen = contact.lastSeenAt;
  if (seen == null) return '';
  final diff = (now ?? DateTime.now()).difference(seen.toLocal());
  if (diff.inMinutes < 1) return l10n.contactsSeenJustNow;
  if (diff.inMinutes < 60) return l10n.contactsSeenMinutes(diff.inMinutes);
  if (diff.inHours < 24) return l10n.contactsSeenHours(diff.inHours);
  return ChatFormat.presence(context, contact.toChatUser());
}

String _conversationTitle(ChatConversation c) {
  if (c.isGroup || c.peer == null) return c.title;
  final p = c.peer!;
  return p.displayName.trim().isNotEmpty ? p.displayName : p.email;
}

class _ContactProfileScreenState extends ConsumerState<ContactProfileScreen> {
  bool _openingChat = false;

  /// Opens the existing direct chat with this colleague or creates it
  /// (`POST /chats {type: direct, user_id}` returns the existing one too).
  Future<void> _openChat(Contact contact) async {
    if (_openingChat) return;
    setState(() => _openingChat = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final repo = ref.read(chatRepositoryProvider);
      final existing = (await repo.cachedConversations())
          .where((c) => !c.isGroup && c.peer?.userId == contact.id)
          .firstOrNull;
      final conv = existing ?? await repo.createDirect(contact.id);
      if (!mounted) return;
      unawaited(router.push(Routes.chatConversationPath(conv.id)));
    } on AppException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ChatFormat.error(l10n, e))),
      );
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  Future<void> _call(Contact contact, {required bool video}) async {
    if (!ref.read(callsEnabledProvider)) return;
    final router = GoRouter.of(context);
    final future = ref
        .read(callControllerProvider.notifier)
        .startCall(calleeIds: [contact.id], video: video, mode: 'direct');
    unawaited(router.push(Routes.call));
    await future;
  }

  void _writeEmail(Contact contact) {
    openCompose(ref, ComposeArgs.to([contact.mailAddress]));
  }

  Future<void> _copy(String value) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: value));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.contactsCopied(value))));
  }

  Future<void> _share(Contact contact, {required bool chatEnabled}) async {
    final choice = await showAppSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (chatEnabled)
                ListTile(
                  key: const Key('contact_share_chat'),
                  leading: const Icon(LucideIcons.messageCircle),
                  title: Text(l10n.contactsShareToChat),
                  onTap: () => Navigator.pop(ctx, 'chat'),
                ),
              ListTile(
                key: const Key('contact_share_vcard'),
                leading: const Icon(LucideIcons.idCard),
                title: Text(l10n.contactsCopyVCard),
                onTap: () => Navigator.pop(ctx, 'vcard'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || choice == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    switch (choice) {
      case 'vcard':
        await Clipboard.setData(ClipboardData(text: contact.toVCard()));
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.contactsVCardCopied)),
        );
      case 'chat':
        final convs = await ref.read(contactsConversationsProvider.future);
        if (!mounted) return;
        final conv = await showAppSheet<ChatConversation>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (ctx) => _ChatPickerSheet(conversations: convs),
        );
        if (conv == null || !mounted) return;
        try {
          await ref
              .read(chatRepositoryProvider)
              .sendContact(conv.id, contact.toChatContact());
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.contactsShareSent(_conversationTitle(conv))),
            ),
          );
        } on AppException catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text(ChatFormat.error(l10n, e))),
          );
        }
    }
  }

  void _openProfile(Contact contact) =>
      context.push(Routes.contactProfilePath(contact.id), extra: contact);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lookup = ref.watch(contactByIdProvider(widget.userId));
    // Reuse the directory only when the tab already loaded it (watching it
    // here would start a full directory load for a deep link).
    final listed = ref.exists(contactsProvider)
        ? ref
              .watch(contactsProvider.select((s) => s.contacts))
              .where((c) => c.id == widget.userId)
              .firstOrNull
        : null;
    final known = lookup.value ?? widget.initial ?? listed;
    if (known != null) return _scaffold(context, known);
    return lookup.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.contactsProfileTitle)),
        body: const StateView.loading(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.contactsProfileTitle)),
        body: StateView.error(
          message: ChatFormat.error(l10n, e),
          onRetry: () => ref.invalidate(contactByIdProvider(widget.userId)),
        ),
      ),
      data: (_) => Scaffold(
        appBar: AppBar(title: Text(l10n.contactsProfileTitle)),
        body: StateView.empty(
          title: l10n.contactsProfileNotFound,
          icon: LucideIcons.userX,
        ),
      ),
    );
  }

  Widget _scaffold(BuildContext context, Contact contact) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final isSelf = ref.watch(currentUserProvider)?.id == contact.id;
    final chatEnabled = ref.watch(chatEnabledProvider);
    final canChat = chatEnabled && !isSelf;
    final callsEnabled = ref.watch(callsEnabledProvider) && !isSelf;
    final canMail =
        contact.email.isNotEmpty &&
        ref.watch(hasPermissionProvider(Permissions.mailSend));
    final favourite = ref
        .watch(contactsFavouriteIdsProvider)
        .contains(contact.id);
    final presence = contactPresenceText(context, contact);
    final status = watchUserStatus(ref, contact.id, contact.status);
    final department = contact.departmentId.isEmpty
        ? null
        : ref.watch(contactsDepartmentProvider(contact.departmentId));
    if (contact.departmentId.isNotEmpty) {
      // Load the department list (manager, head count) lazily.
      ref.watch(contactsDepartmentsProvider);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.contactsProfileTitle),
        actions: [
          if (!isSelf)
            // Toggle state for screen readers; the tooltip names the action.
            MergeSemantics(
              child: Semantics(
              toggled: favourite,
              child: IconButton(
              key: const Key('contact_favourite'),
              tooltip: favourite
                  ? l10n.contactsRemoveFavourite
                  : l10n.contactsAddFavourite,
              icon: Icon(
                LucideIcons.star,
                color: favourite ? t.warning : null,
                fill: favourite ? 1 : 0,
              ),
              onPressed: () => ref
                  .read(contactsFavouritesProvider.notifier)
                  .toggle(contact),
            ),
              ),
            ),
          IconButton(
            key: const Key('contact_share'),
            tooltip: l10n.contactsShare,
            icon: const Icon(LucideIcons.share2),
            onPressed: () => _share(contact, chatEnabled: chatEnabled),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, box) => ref.watch(desktopLayoutProvider) && box.maxWidth >= _twoColumnMinWidth
          // Desktop: the profile card on the left (photo, name, actions),
          // the details on the right, instead of one stretched column. In
          // the contacts page's side pane there is no room for two columns
          // and the profile stays one column, like on the phone.
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 400,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: Space.xl),
                    children: [
          _Hero(
            contact: contact,
            presence: presence,
            status: status,
            favourite: favourite,
          ),
          if (canChat || callsEnabled || canMail)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.md,
                Space.md,
                0,
              ),
              child: Row(
                children: [
                  if (canChat)
                    _BigAction(
                      key: const Key('contact_write'),
                      icon: LucideIcons.messageCircle,
                      label: l10n.contactsWrite,
                      busy: _openingChat,
                      primary: true,
                      onPressed: () => _openChat(contact),
                    ),
                  if (callsEnabled) ...[
                    _BigAction(
                      key: const Key('contact_audio_call'),
                      icon: LucideIcons.phone,
                      label: l10n.contactsActionAudio,
                      tooltip: l10n.contactsAudioCall,
                      onPressed: () => _call(contact, video: false),
                    ),
                    _BigAction(
                      key: const Key('contact_video_call'),
                      icon: LucideIcons.video,
                      label: l10n.contactsActionVideo,
                      tooltip: l10n.contactsVideoCall,
                      onPressed: () => _call(contact, video: true),
                    ),
                  ],
                  if (canMail)
                    _BigAction(
                      key: const Key('contact_write_email'),
                      icon: LucideIcons.mail,
                      label: l10n.contactsActionEmail,
                      tooltip: l10n.contactsWriteEmail,
                      onPressed: () => _writeEmail(contact),
                    ),
                  // The web's «Назначить встречу».
                  if (ref.watch(calendarEnabledProvider) &&
                      ref.watch(calendarCanCreateProvider))
                    _BigAction(
                      key: const Key('contact_schedule_meeting'),
                      icon: LucideIcons.calendarPlus,
                      label: l10n.desktopContactMeeting,
                      tooltip: l10n.desktopContactScheduleMeeting,
                      onPressed: () => scheduleMeetingWith(context, contact),
                    ),
                ],
              ),
            ),
                    ],
                  ),
                ),
                VerticalDivider(width: t.borderWidth, color: t.border),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(Space.sm, 0, Space.sm, Space.xl),
                    children: [
          if (contact.email.isNotEmpty ||
              contact.mailbox.isNotEmpty ||
              contact.position.isNotEmpty) ...[
            ContactCardTitle(l10n.contactsEmail),
            ContactCard(
              children: [
                if (contact.email.isNotEmpty)
                  ContactInfoRow(
                    key: const Key('contact_email_row'),
                    icon: LucideIcons.atSign,
                    label: l10n.contactsEmail,
                    value: contact.email,
                    onTap: () => _copy(contact.email),
                    onLongPress: () => _copy(contact.email),
                    trailing: Icon(
                      LucideIcons.copy,
                      size: 16,
                      color: t.textTertiary,
                      semanticLabel: l10n.contactsCopy,
                    ),
                  ),
                if (contact.mailbox.isNotEmpty)
                  ContactInfoRow(
                    key: const Key('contact_mailbox_row'),
                    icon: LucideIcons.inbox,
                    label: l10n.contactsMailbox,
                    value: contact.mailbox,
                    onTap: () => _copy(contact.mailbox),
                    onLongPress: () => _copy(contact.mailbox),
                    trailing: Icon(
                      LucideIcons.copy,
                      size: 16,
                      color: t.textTertiary,
                      semanticLabel: l10n.contactsCopy,
                    ),
                  ),
                if (contact.position.isNotEmpty)
                  ContactInfoRow(
                    icon: LucideIcons.idCard,
                    label: l10n.contactsPosition,
                    value: contact.position,
                  ),
              ],
            ),
          ],
          if (contact.department.isNotEmpty || department != null) ...[
            ContactCardTitle(l10n.contactsDepartment),
            ContactCard(
              key: const Key('contact_department_card'),
              children: [
                ContactInfoRow(
                  icon: LucideIcons.building2,
                  label: l10n.contactsDepartment,
                  value: department?.name ?? contact.department,
                  trailing: department != null && department.employeeCount > 0
                      ? XBadge(
                          l10n.contactsEmployeeCount(department.employeeCount),
                          tone: BadgeTone.neutral,
                        )
                      : null,
                ),
                if (department != null &&
                    department.description.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.md,
                      Space.smd,
                      Space.md,
                      Space.smd,
                    ),
                    child: Text(
                      department.description.trim(),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                if (department != null && department.hasManager)
                  ContactInfoRow(
                    key: const Key('contact_department_manager'),
                    icon: LucideIcons.userStar,
                    label: l10n.contactsManager,
                    value: department.managerLabel,
                    maxLines: 1,
                    onTap: department.managerUserId == contact.id
                        ? null
                        : () => _openProfile(
                            Contact(
                              id: department.managerUserId,
                              email: department.managerEmail,
                              displayName: department.managerName,
                              department: department.name,
                              departmentId: department.id,
                            ),
                          ),
                    trailing: department.managerUserId == contact.id
                        ? null
                        : Icon(
                            LucideIcons.chevronRight,
                            size: 16,
                            color: t.textTertiary,
                          ),
                  ),
              ],
            ),
          ],
          if (contact.departmentId.isNotEmpty)
            _Colleagues(
              departmentId: contact.departmentId,
              exceptId: contact.id,
              onOpen: _openProfile,
            ),
          if (chatEnabled && !isSelf)
            _SharedChats(
              userId: contact.id,
              onOpen: (c) => context.push(Routes.chatConversationPath(c.id)),
            ),
                    ],
                  ),
                ),
              ],
            )
          : ListView(
        padding: const EdgeInsets.only(bottom: Space.xl),
        children: [
          _Hero(
            contact: contact,
            presence: presence,
            status: status,
            favourite: favourite,
          ),
          if (canChat || callsEnabled || canMail)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.md,
                Space.md,
                0,
              ),
              child: Row(
                children: [
                  if (canChat)
                    _BigAction(
                      key: const Key('contact_write'),
                      icon: LucideIcons.messageCircle,
                      label: l10n.contactsWrite,
                      busy: _openingChat,
                      primary: true,
                      onPressed: () => _openChat(contact),
                    ),
                  if (callsEnabled) ...[
                    _BigAction(
                      key: const Key('contact_audio_call'),
                      icon: LucideIcons.phone,
                      label: l10n.contactsActionAudio,
                      tooltip: l10n.contactsAudioCall,
                      onPressed: () => _call(contact, video: false),
                    ),
                    _BigAction(
                      key: const Key('contact_video_call'),
                      icon: LucideIcons.video,
                      label: l10n.contactsActionVideo,
                      tooltip: l10n.contactsVideoCall,
                      onPressed: () => _call(contact, video: true),
                    ),
                  ],
                  if (canMail)
                    _BigAction(
                      key: const Key('contact_write_email'),
                      icon: LucideIcons.mail,
                      label: l10n.contactsActionEmail,
                      tooltip: l10n.contactsWriteEmail,
                      onPressed: () => _writeEmail(contact),
                    ),
                  // The web's «Назначить встречу».
                  if (ref.watch(calendarEnabledProvider) &&
                      ref.watch(calendarCanCreateProvider))
                    _BigAction(
                      key: const Key('contact_schedule_meeting'),
                      icon: LucideIcons.calendarPlus,
                      label: l10n.desktopContactMeeting,
                      tooltip: l10n.desktopContactScheduleMeeting,
                      onPressed: () => scheduleMeetingWith(context, contact),
                    ),
                ],
              ),
            ),
          if (contact.email.isNotEmpty ||
              contact.mailbox.isNotEmpty ||
              contact.position.isNotEmpty) ...[
            ContactCardTitle(l10n.contactsEmail),
            ContactCard(
              children: [
                if (contact.email.isNotEmpty)
                  ContactInfoRow(
                    key: const Key('contact_email_row'),
                    icon: LucideIcons.atSign,
                    label: l10n.contactsEmail,
                    value: contact.email,
                    onTap: () => _copy(contact.email),
                    onLongPress: () => _copy(contact.email),
                    trailing: Icon(
                      LucideIcons.copy,
                      size: 16,
                      color: t.textTertiary,
                      semanticLabel: l10n.contactsCopy,
                    ),
                  ),
                if (contact.mailbox.isNotEmpty)
                  ContactInfoRow(
                    key: const Key('contact_mailbox_row'),
                    icon: LucideIcons.inbox,
                    label: l10n.contactsMailbox,
                    value: contact.mailbox,
                    onTap: () => _copy(contact.mailbox),
                    onLongPress: () => _copy(contact.mailbox),
                    trailing: Icon(
                      LucideIcons.copy,
                      size: 16,
                      color: t.textTertiary,
                      semanticLabel: l10n.contactsCopy,
                    ),
                  ),
                if (contact.position.isNotEmpty)
                  ContactInfoRow(
                    icon: LucideIcons.idCard,
                    label: l10n.contactsPosition,
                    value: contact.position,
                  ),
              ],
            ),
          ],
          if (contact.department.isNotEmpty || department != null) ...[
            ContactCardTitle(l10n.contactsDepartment),
            ContactCard(
              key: const Key('contact_department_card'),
              children: [
                ContactInfoRow(
                  icon: LucideIcons.building2,
                  label: l10n.contactsDepartment,
                  value: department?.name ?? contact.department,
                  trailing: department != null && department.employeeCount > 0
                      ? XBadge(
                          l10n.contactsEmployeeCount(department.employeeCount),
                          tone: BadgeTone.neutral,
                        )
                      : null,
                ),
                if (department != null &&
                    department.description.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.md,
                      Space.smd,
                      Space.md,
                      Space.smd,
                    ),
                    child: Text(
                      department.description.trim(),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                if (department != null && department.hasManager)
                  ContactInfoRow(
                    key: const Key('contact_department_manager'),
                    icon: LucideIcons.userStar,
                    label: l10n.contactsManager,
                    value: department.managerLabel,
                    maxLines: 1,
                    onTap: department.managerUserId == contact.id
                        ? null
                        : () => _openProfile(
                            Contact(
                              id: department.managerUserId,
                              email: department.managerEmail,
                              displayName: department.managerName,
                              department: department.name,
                              departmentId: department.id,
                            ),
                          ),
                    trailing: department.managerUserId == contact.id
                        ? null
                        : Icon(
                            LucideIcons.chevronRight,
                            size: 16,
                            color: t.textTertiary,
                          ),
                  ),
              ],
            ),
          ],
          if (contact.departmentId.isNotEmpty)
            _Colleagues(
              departmentId: contact.departmentId,
              exceptId: contact.id,
              onOpen: _openProfile,
            ),
          if (chatEnabled && !isSelf)
            _SharedChats(
              userId: contact.id,
              onOpen: (c) => context.push(Routes.chatConversationPath(c.id)),
            ),
        ],
      ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.contact,
    required this.presence,
    required this.favourite,
    this.status,
  });

  final Contact contact;
  final String presence;
  final bool favourite;

  /// «🌴 В отпуске · до 20 сент., 09:00».
  final ChatUserStatus? status;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.lg,
        Space.md,
        Space.lg,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.primarySoft, t.surface],
        ),
        border: Border.all(color: t.border, width: t.borderWidth),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ContactAvatar(contact: contact, radius: 48, ring: true),
              if (favourite)
                Positioned(
                  top: 0,
                  right: 0,
                  // Decorative: the favourite button exposes the state.
                  child: ExcludeSemantics(
                    child: Container(
                    padding: const EdgeInsets.all(Space.xs),
                    decoration: BoxDecoration(
                      color: t.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.border),
                    ),
                    child: Icon(LucideIcons.star, size: 14, color: t.warning),
                  ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          Text(
            contact.label,
            key: const Key('contact_profile_name'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.headlineSmall?.copyWith(
              color: t.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (contact.position.isNotEmpty) ...[
            const SizedBox(height: Space.xs),
            Text(
              contact.position,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(color: t.textSecondary),
            ),
          ],
          if (contact.department.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            XBadge(
              contact.department,
              key: const Key('contact_department_chip'),
              tone: BadgeTone.primary,
              icon: LucideIcons.building2,
            ),
          ],
          if (presence.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: contact.online ? t.success : t.textDisabled,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: Space.xs),
                Flexible(
                  child: Text(
                    presence,
                    key: const Key('contact_presence'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: contact.online ? t.success : t.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (status != null) ...[
            const SizedBox(height: Space.sm),
            Text(
              ChatStatusFormat.line(context, status!),
              key: const Key('contact_status'),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(color: t.textPrimary),
            ),
          ],
        ],
      ),
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.busy = false,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback onPressed;
  final bool busy;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bg = primary ? t.primary : t.primarySoft;
    final fg = primary ? t.textInverse : t.primary;
    return Expanded(
      child: Tooltip(
        message: tooltip ?? label,
        // Announced once, by the node below (not tooltip + visible label).
        excludeFromSemantics: true,
        child: Semantics(
          container: true,
          button: true,
          enabled: !busy,
          label: tooltip ?? label,
          child: InkWell(
            onTap: busy ? null : onPressed,
            borderRadius: BorderRadius.circular(t.radiusMd),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(t.radiusLg),
                      ),
                      child: busy
                          ? Padding(
                              padding: const EdgeInsets.all(Space.md),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: fg,
                              ),
                            )
                          : Icon(icon, color: fg, size: 22),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: t.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Colleagues extends ConsumerWidget {
  const _Colleagues({
    required this.departmentId,
    required this.exceptId,
    required this.onOpen,
  });

  final String departmentId;
  final String exceptId;
  final ValueChanged<Contact> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = (ref.watch(contactsColleaguesProvider(departmentId)).value ??
            const <Contact>[])
        .where((c) => c.id != exceptId)
        .take(30)
        .toList();
    if (list.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    final height =
        56 + Space.xs + scaler.scale(text.labelSmall?.fontSize ?? 11) * 1.5 + 16;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContactCardTitle(context.l10n.contactsColleagues),
        SizedBox(
          height: math.max(height, 88),
          child: ListView.separated(
            key: const Key('contact_colleagues'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
            itemBuilder: (context, i) {
              final c = list[i];
              final first = c.label.split(RegExp(r'\s+')).first;
              // Only the first name fits under the avatar; the full name
              // (and presence) is the label.
              return Semantics(
                container: true,
                label: c.online
                    ? '${c.label}, ${context.l10n.chatOnline}'
                    : c.label,
                child: InkWell(
                  key: ValueKey('contact_colleague_${c.id}'),
                  borderRadius: BorderRadius.circular(t.radiusMd),
                  onTap: () => onOpen(c),
                  child: ExcludeSemantics(
                    child: SizedBox(
                      width: 72,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: Space.xs),
                        child: Column(
                          children: [
                            ContactAvatar(contact: c, radius: 26),
                            const SizedBox(height: Space.xs),
                            Text(
                              first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: text.labelSmall?.copyWith(
                                color: t.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SharedChats extends ConsumerWidget {
  const _SharedChats({required this.userId, required this.onOpen});
  final String userId;
  final ValueChanged<ChatConversation> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(contactsSharedChatsProvider(userId));
    if (chats.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContactCardTitle(l10n.contactsSharedChats),
        ContactCard(
          key: const Key('contact_shared_chats'),
          children: [
            for (final c in chats.take(10))
              MergeSemantics(
                child: InkWell(
                key: ValueKey('contact_shared_${c.id}'),
                onTap: () => onOpen(c),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.md,
                    vertical: Space.sm,
                  ),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: ChatAvatar(conversation: c, radius: 18),
                      ),
                      const SizedBox(width: Space.smd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium?.copyWith(
                                color: t.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              l10n.contactsChatMembers(c.memberCount),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(
                                color: t.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color: t.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChatPickerSheet extends StatelessWidget {
  const _ChatPickerSheet({required this.conversations});
  final List<ChatConversation> conversations;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                0,
                Space.md,
                Space.sm,
              ),
              child: Text(
                l10n.contactsShareToChat,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (conversations.isEmpty)
              Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Text(
                  l10n.contactsShareNoChats,
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: conversations.length,
                  itemBuilder: (context, i) {
                    final c = conversations[i];
                    return ListTile(
                      key: ValueKey('contact_share_to_${c.id}'),
                      leading: ChatAvatar(conversation: c, radius: 18),
                      title: Text(
                        _conversationTitle(c),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.pop(context, c),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
