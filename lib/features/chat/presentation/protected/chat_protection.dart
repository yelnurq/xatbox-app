import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/platform/desktop.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../../core/security/app_lock.dart';
import '../../../../core/theme/tokens.dart';
import '../../data/chat_models.dart';
import '../chat_formatters.dart';
import '../chat_providers.dart';
import '../messenger2_providers.dart';
import '../../../../shared/widgets/app_sheet.dart';

/// Protected chats: FLAG_SECURE while the conversation is open (Android),
/// a blur over the content whenever the app is not in the foreground (iOS
/// app switcher, Android recents), the shield sheet and its settings.

/// Label of a disappearing timer.
String disappearingLabel(AppLocalizations l10n, int ttl) => switch (ttl) {
  0 => l10n.chatDisappearingOff,
  86400 => l10n.chatDisappearingDay,
  604800 => l10n.chatDisappearingWeek,
  2592000 => l10n.chatDisappearingMonth,
  _ => l10n.chatDisappearingCustom((ttl / 3600).round()),
};

/// Who may change the protection: either member of a 1:1 chat, admins of
/// groups and channels; never «Избранное».
bool canEditProtection(ChatConversation c) =>
    !c.isSaved && (c.type == 'direct' || c.isAdmin);

class ChatProtectedScope extends ConsumerStatefulWidget {
  const ChatProtectedScope({
    super.key,
    required this.protection,
    required this.child,
  });
  final ChatProtection protection;
  final Widget child;

  @override
  ConsumerState<ChatProtectedScope> createState() => _ChatProtectedScopeState();
}

class _ChatProtectedScopeState extends ConsumerState<ChatProtectedScope>
    with WidgetsBindingObserver {
  bool _secured = false;
  bool _obscured = false;

  /// The app-wide «hide content» preference, cached: `ref` must not be used
  /// in dispose.
  late bool _appWantsSecure = ref.read(appPreferencesProvider).hideInSwitcher;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apply();
  }

  @override
  void didUpdateWidget(covariant ChatProtectedScope old) {
    super.didUpdateWidget(old);
    _apply();
  }

  void _apply() {
    final want = widget.protection.screenshotProtection;
    if (want == _secured) return;
    _secured = want;
    unawaited(WindowSecurity.setSecure(want || _appWantsSecure));
    if (!want && _obscured) setState(() => _obscured = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.protection.screenshotProtection) return;
    // Desktop: blur when minimized / hidden, not on every focus change.
    final hide = isDesktop
        ? state == AppLifecycleState.hidden || state == AppLifecycleState.paused
        : state != AppLifecycleState.resumed;
    if (hide != _obscured && mounted) setState(() => _obscured = hide);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_secured) unawaited(WindowSecurity.setSecure(_appWantsSecure));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    _appWantsSecure = ref.watch(
      appPreferencesProvider.select((p) => p.hideInSwitcher),
    );
    return Stack(
      children: [
        widget.child,
        if (_obscured)
          Positioned.fill(
            key: const Key('chat_protected_blur'),
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: ColoredBox(
                  color: t.surface.withValues(alpha: 0.7),
                  child: Center(
                    child: Icon(LucideIcons.shieldCheck, size: 56, color: t.primary),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The shield in the chat header (only when some protection is on).
class ChatProtectionHeaderButton extends StatelessWidget {
  const ChatProtectionHeaderButton({super.key, required this.conversation});
  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IconButton(
      key: const Key('chat_protection_shield'),
      tooltip: context.l10n.chatProtectionActive,
      icon: Icon(LucideIcons.shieldCheck, color: t.success),
      onPressed: () => ChatProtectionSheet.show(context, conversation.id),
    );
  }
}

/// Explains what is on and, for those allowed, changes it.
class ChatProtectionSheet extends ConsumerStatefulWidget {
  const ChatProtectionSheet({super.key, required this.conversationId});
  final String conversationId;

  static Future<void> show(BuildContext context, String conversationId) =>
      showAppSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => ChatProtectionSheet(conversationId: conversationId),
      );

  @override
  ConsumerState<ChatProtectionSheet> createState() =>
      _ChatProtectionSheetState();
}

class _ChatProtectionSheetState extends ConsumerState<ChatProtectionSheet> {
  ChatProtection? _pending;
  bool _busy = false;

  Future<void> _save(ChatProtection next, ChatConversation conv) async {
    final before = _pending ?? conv.protection;
    setState(() {
      _pending = next;
      _busy = true;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    try {
      final json = await ref
          .read(chatMessenger2ApiProvider)
          .setProtection(
            conv.id,
            noForward: next.noForward != before.noForward ? next.noForward : null,
            screenshotProtection:
                next.screenshotProtection != before.screenshotProtection
                ? next.screenshotProtection
                : null,
            disappearingTtl: next.disappearingTtl != before.disappearingTtl
                ? next.disappearingTtl
                : null,
          );
      await ref
          .read(chatRepositoryProvider)
          .putConversationLocal(ChatConversation.fromJson(json));
      if (mounted) setState(() => _pending = null);
    } on AppException catch (e) {
      if (mounted) setState(() => _pending = before);
      messenger?.showSnackBar(SnackBar(content: Text(ChatFormat.error(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final conv = ref.watch(
      conversationProvider(widget.conversationId).select((s) => s.conversation),
    );
    if (conv == null) {
      return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
    }
    final p = _pending ?? conv.protection;
    final editable = canEditProtection(conv);
    final onChanged = editable && !_busy;
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('chat_protection_sheet'),
        padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: p.active ? t.successSoft : t.surfaceSubtle,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  p.active ? LucideIcons.shieldCheck : LucideIcons.shield,
                  size: 32,
                  color: p.active ? t.success : t.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: Space.smd),
            Text(
              l10n.chatProtection,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Space.xs),
            Text(
              p.active ? l10n.chatProtectionActive : l10n.chatProtectionNone,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: Space.md),
            _Row(
              key: const Key('protection_no_forward'),
              icon: LucideIcons.copyX,
              title: l10n.chatProtectionNoForward,
              hint: l10n.chatProtectionNoForwardHint,
              value: p.noForward,
              onChanged: onChanged
                  ? (v) => _save(p.copyWith(noForward: v), conv)
                  : null,
            ),
            _Row(
              key: const Key('protection_screenshots'),
              icon: LucideIcons.scanEye,
              title: l10n.chatProtectionScreenshots,
              hint: isDesktop ? l10n.chatProtectionScreenshotsHintDesktop : l10n.chatProtectionScreenshotsHint,
              value: p.screenshotProtection,
              onChanged: onChanged
                  ? (v) => _save(p.copyWith(screenshotProtection: v), conv)
                  : null,
            ),
            const SizedBox(height: Space.sm),
            Row(
              children: [
                Icon(LucideIcons.timer, size: 20, color: t.textSecondary),
                const SizedBox(width: Space.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.chatProtectionDisappearing, style: theme.textTheme.bodyLarge),
                      Text(
                        l10n.chatProtectionDisappearingHint,
                        style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Wrap(
              key: const Key('protection_ttl_options'),
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                for (final ttl in ChatProtection.ttlOptions)
                  ChoiceChip(
                    key: ValueKey('protection_ttl_$ttl'),
                    label: Text(disappearingLabel(l10n, ttl)),
                    selected: p.disappearingTtl == ttl,
                    selectedColor: t.primarySoft,
                    labelStyle: TextStyle(
                      color: p.disappearingTtl == ttl ? t.primary : t.textSecondary,
                      fontWeight: p.disappearingTtl == ttl ? FontWeight.w600 : null,
                    ),
                    onSelected: onChanged && p.disappearingTtl != ttl
                        ? (_) => _save(p.copyWith(disappearingTtl: ttl), conv)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Icon(LucideIcons.info, size: 16, color: t.textTertiary),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text(
                    !editable
                        ? l10n.chatProtectionAdminsOnly
                        : (conv.type == 'direct'
                              ? l10n.chatProtectionPeerNotified
                              : l10n.chatProtectionMembersNotified),
                    style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary),
                  ),
                ),
                if (_busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String hint;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: value ? t.success : t.textSecondary),
      title: Text(title),
      subtitle: Text(hint, style: TextStyle(color: t.textTertiary)),
      value: value,
      onChanged: onChanged,
    );
  }
}
