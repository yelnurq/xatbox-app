import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/localization/localization.dart';
import '../../core/platform/desktop_layout.dart';
import '../../core/theme/tokens.dart';
import '../../shared/models/profile_session.dart';
import '../../shared/utils/error_text.dart';
import '../../shared/utils/format_utils.dart';
import '../../shared/widgets/avatar_cache.dart';
import '../../shared/widgets/ds/x_badge.dart';
import '../../shared/widgets/state_view.dart';
import '../../shared/widgets/user_avatar.dart';
import '../mail/presentation/mail_providers.dart';

final _sessionsProvider = FutureProvider.autoDispose<List<ProfileSession>>(
  (ref) => ref.watch(authApiProvider).sessions(),
);

/// `GET /me` + `GET /me/sessions` (ТЗ п.24.15 "Устройства/сессии"), laid out
/// like the web settings "Profile" section: the facts (name, mailbox, role,
/// department) beside the photo with change / remove, then the sessions.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _photoBusy = false;

  Future<bool> _confirmEndOthers() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.profileEndOthers),
        content: Text(l10n.sessionsEndOthersConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            key: const Key('profile_end_others_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.profileEndOthers),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _run(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await action();
      ref.invalidate(_sessionsProvider);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.describe(l10n, e))));
    }
  }

  Future<void> _changePhoto() async {
    final picked = await FilePicker.pickFiles(type: FileType.image);
    final file = picked.firstOrNull;
    final path = file?.path;
    if (file == null || path == null || !mounted) return;
    final bytes = await File(path).readAsBytes();
    if (!mounted) return;
    await _photo(() => ref.read(authApiProvider).uploadAvatar(filename: file.name, bytes: bytes));
  }

  Future<void> _removePhoto() => _photo(() => ref.read(authApiProvider).deleteAvatar());

  Future<void> _photo(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _photoBusy = true);
    try {
      await action();
      await ref.read(avatarCacheProvider).clear();
      await ref.read(authSessionProvider).refreshProfile();
      messenger.showSnackBar(SnackBar(content: Text(l10n.profilePhotoUpdated)));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.describe(l10n, e))));
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = ref.watch(desktopLayoutProvider);
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final sessions = ref.watch(_sessionsProvider);
    final locale = Localizations.localeOf(context).toString();
    final mailbox = ref.watch(mailSummaryProvider).summary?.mailboxAddress;

    Widget row(String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.smd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(label, style: theme.textTheme.labelMedium), const SizedBox(height: 4), value],
      ),
    );

    // Desktop: the panels sit on the settings page itself (the section
    // list names the page), not inside a second panel.
    return Scaffold(
      backgroundColor: desktop ? Colors.transparent : null,
      appBar: desktop ? null : AppBar(title: Text(l10n.profileTitle)),
      body: user == null
          ? const StateView.loading()
          : ListView(
              padding: desktop ? const EdgeInsets.only(bottom: Space.md) : const EdgeInsets.all(Space.md),
              children: [
                _Panel(
                  title: l10n.profileTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            UserAvatar(key: ValueKey(user.avatarUpdatedAt), email: user.email, label: user.displayName, radius: 48),
                            const SizedBox(height: Space.smd),
                            Wrap(
                              spacing: Space.sm,
                              alignment: WrapAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  key: const Key('profile_change_photo'),
                                  onPressed: _photoBusy ? null : _changePhoto,
                                  icon: const Icon(LucideIcons.camera, size: 14),
                                  label: Text(l10n.profileChangePhoto),
                                ),
                                if (user.avatarUpdatedAt != null)
                                  TextButton(
                                    key: const Key('profile_remove_photo'),
                                    onPressed: _photoBusy ? null : _removePhoto,
                                    child: Text(l10n.profileRemovePhoto),
                                  ),
                              ],
                            ),
                            const SizedBox(height: Space.xs),
                            Text(l10n.profilePhotoHint, textAlign: TextAlign.center, style: theme.textTheme.labelSmall),
                          ],
                        ),
                      ),
                      Divider(color: t.divider, height: Space.lg),
                      row(
                        desktop ? l10n.desktopProfileFullName : l10n.profileTitle,
                        Text(user.displayName, style: theme.textTheme.bodyMedium),
                      ),
                      Divider(color: t.divider),
                      row(
                        l10n.loginEmail,
                        SelectableText(mailbox?.isNotEmpty == true ? mailbox! : user.email, style: theme.textTheme.bodyMedium!.copyWith(fontFamily: 'JetBrains Mono')),
                      ),
                      Divider(color: t.divider),
                      row(
                        l10n.profileRole,
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            // As the web: the granted roles by name (the
                            // generic badge only when there are none).
                            if (user.roles.isEmpty)
                              XBadge(
                                user.permissions.contains('users.manage') ? l10n.profileAdministrator : l10n.profileMember,
                                tone: user.permissions.contains('users.manage') ? BadgeTone.primary : BadgeTone.neutral,
                              ),
                            for (final g in user.roles)
                              XBadge(
                                roleLabel(l10n, g.role),
                                tone: g.role == 'member' ? BadgeTone.neutral : BadgeTone.primary,
                              ),
                          ],
                        ),
                      ),
                      if (user.departmentName != null) ...[
                        Divider(color: t.divider),
                        row(l10n.profileDepartment, Text(user.departmentName!, style: theme.textTheme.bodyMedium)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Space.md),
                _Panel(
                  title: l10n.profileSessions,
                  aside: TextButton(
                    onPressed: () => _run(() async {
                      // Asks first, as the web does.
                      if (!await _confirmEndOthers()) return;
                      final ended = await ref.read(authApiProvider).endOtherSessions();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileSessionsEnded(ended))));
                      }
                    }),
                    child: Text(l10n.profileEndOthers),
                  ),
                  flush: true,
                  child: sessions.when(
                    loading: () => const Padding(padding: EdgeInsets.all(Space.md), child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => StateView.error(message: ErrorText.describe(l10n, e), onRetry: () => ref.invalidate(_sessionsProvider)),
                    data: (list) => Column(
                      children: [
                        for (final s in list)
                          ListTile(
                            leading: Icon(switch (s.kind) {
                              'mobile' => LucideIcons.smartphone,
                              'tablet' => LucideIcons.tablet,
                              'desktop' => LucideIcons.monitor,
                              _ => LucideIcons.monitorSmartphone,
                            }),
                            title: Row(
                              children: [
                                Flexible(child: Text(s.deviceLabel, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                if (s.current) ...[const SizedBox(width: Space.sm), XBadge(l10n.profileCurrentSession, tone: BadgeTone.success, small: true)],
                              ],
                            ),
                            subtitle: Text([if (s.ip != null) s.ip!, l10n.profileExpires(FormatUtils.fullDate(s.expiresAt, locale))].join(' · ')),
                            trailing: s.current
                                ? null
                                : TextButton(
                                    onPressed: () => _run(() => ref.read(authApiProvider).endSession(s.id)),
                                    child: Text(l10n.profileEndSession),
                                  ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.aside, this.flush = false});
  final String title;
  final Widget child;
  final Widget? aside;
  final bool flush;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.radiusLg),
        border: Border.all(color: t.border, width: t.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(Space.mlg, Space.sm, Space.sm, Space.sm),
            decoration: BoxDecoration(color: t.surfaceSubtle, border: Border(bottom: BorderSide(color: t.border, width: t.borderWidth))),
            child: Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
                ?aside,
              ],
            ),
          ),
          if (flush) child else Padding(padding: const EdgeInsets.all(Space.mlg), child: child),
        ],
      ),
    );
  }
}

/// A role code as people read it (the web's `roleLabel`): «Администратор
/// организации», not `org_admin`. Unknown codes lose their underscores.
String roleLabel(AppLocalizations l10n, String code) => switch (code) {
  'member' => l10n.desktopRoleMember,
  'org_admin' || 'organization_admin' => l10n.desktopRoleOrgAdmin,
  'domain_admin' => l10n.desktopRoleDomainAdmin,
  'user_manager' => l10n.desktopRoleUserManager,
  'developer' => l10n.desktopRoleDeveloper,
  'security_analyst' => l10n.desktopRoleSecurityAnalyst,
  'auditor' => l10n.desktopRoleAuditor,
  'support' => l10n.desktopRoleSupport,
  'tenant_owner' => l10n.desktopRoleTenantOwner,
  'super_admin' => l10n.desktopRoleSuperAdmin,
  'platform_super_admin' => l10n.desktopRolePlatformSuperAdmin,
  _ => code.replaceAll('_', ' '),
};
