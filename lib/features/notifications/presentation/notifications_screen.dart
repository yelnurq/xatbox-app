import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/desktop_layout.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/error_text.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/state_view.dart';
import '../../tasks/presentation/tasks_providers.dart';
import '../data/notification_models.dart';
import '../domain/notification_target.dart';
import 'notifications_providers.dart';

/// In-app notifications (`/notifications`): latest 100 from the Mail API,
/// pull to refresh, rows revealed while scrolling, tap = mark read + open.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.onOpened});

  /// Desktop bell panel: closes itself once a notification is opened.
  final VoidCallback? onOpened;

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the screen always shows fresh data (the badge may be stale).
    Future.microtask(() {
      if (!mounted) return;
      final s = ref.read(notificationsProvider);
      if (s.loaded && !s.loading) {
        unawaited(ref.read(notificationsProvider.notifier).refresh());
      }
    });
  }

  Future<void> _open(AppNotification n) async {
    unawaited(ref.read(notificationsProvider.notifier).markRead(n.id));
    var location = notificationTargetLocation(n.targetUrl);
    // Task notifications without a mapped target open «Мои задачи».
    if (location == null && isTaskNotificationKind(n.kind)) {
      location = Routes.tasks;
    }
    if (location != null &&
        isTaskLocation(location) &&
        !ref.read(tasksEnabledProvider)) {
      location = null;
    }
    if (location == null || !mounted) return;
    widget.onOpened?.call();
    if (isTabRootLocation(location)) {
      context.go(location);
    } else {
      unawaited(context.push(location));
    }
  }

  Future<void> _readAll() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final error = await ref.read(notificationsProvider.notifier).markAllRead();
    if (error != null && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(ErrorText.describe(l10n, error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    final Widget body;
    if (!state.loaded && state.items.isEmpty) {
      body = const StateView.loading();
    } else if (state.items.isEmpty && state.error != null) {
      body = ErrorText.isOffline(state.error)
          ? StateView.offline(
              message: ErrorText.describe(l10n, state.error!),
              onRetry: notifier.refresh,
            )
          : StateView.error(
              message: ErrorText.describe(l10n, state.error!),
              onRetry: notifier.refresh,
            );
    } else {
      final visible = state.visible;
      body = Column(
        children: [
          if (state.error != null)
            OfflineBanner(
              text: ErrorText.isOffline(state.error)
                  ? l10n.offlineBanner
                  : ErrorText.describe(l10n, state.error!),
              onRetry: notifier.refresh,
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: notifier.refresh,
              child: visible.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: 320,
                          child: StateView.empty(
                            title: l10n.notificationsEmpty,
                            icon: LucideIcons.bell,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      key: const Key('notifications_list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: visible.length + 1,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        if (i == visible.length) {
                          // Footer built near the viewport end: reveal the
                          // next page (infinite scroll without requests).
                          if (state.hasMore) {
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => notifier.loadMore(),
                            );
                          }
                          return _ListFooter(state: state);
                        }
                        final n = visible[i];
                        return NotificationTile(
                          key: ValueKey('notification_${n.id}'),
                          notification: n,
                          onTap: () => _open(n),
                        );
                      },
                    ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          // Desktop: no pull to refresh with a mouse.
          if (ref.watch(desktopLayoutProvider))
            IconButton(
              key: const Key('notifications_refresh'),
              tooltip: l10n.desktopRefresh,
              icon: const Icon(LucideIcons.refreshCw),
              onPressed: notifier.refresh,
            ),
          if (state.unread > 0)
            TextButton(
              key: const Key('notifications_read_all'),
              onPressed: state.markingAll ? null : _readAll,
              child: Text(l10n.notificationsReadAll),
            ),
        ],
      ),
      body: body,
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.state});
  final NotificationsState state;

  @override
  Widget build(BuildContext context) {
    if (state.hasMore) {
      return const Padding(
        padding: EdgeInsets.all(Space.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.items.length >= NotificationPage.maxItems) {
      return Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Text(
          context.l10n.notificationsLimitNote(NotificationPage.maxItems),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.tokens.textMuted),
        ),
      );
    }
    return const SizedBox(height: Space.lg);
  }
}

/// One notification row: kind icon, title, body, time, unread dot.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  static IconData iconFor(String kind) {
    if (kind == 'message' || kind == 'mention') {
      return LucideIcons.messageCircle;
    }
    if (kind.startsWith('calendar')) return LucideIcons.calendar;
    if (kind == 'assigned_task') return LucideIcons.circleCheck;
    if (kind == 'reminder') return LucideIcons.alarmClock;
    if (kind == 'official') return LucideIcons.megaphone;
    return LucideIcons.bell;
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final unread = !n.isRead;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: unread ? tokens.brand : tokens.textMuted,
        child: Icon(iconFor(n.kind)),
      ),
      title: Text(
        n.title.isNotEmpty ? n.title : n.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: n.title.isNotEmpty && n.body.isNotEmpty
          ? Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis)
          : null,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            FormatUtils.listDate(n.createdAt, locale),
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textMuted,
            ),
          ),
          const SizedBox(height: Space.xs),
          if (unread)
            Container(
              key: const Key('notification_unread_dot'),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: tokens.unreadBadge,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

/// App-bar entry with the unread badge; opens [NotificationsScreen].
class NotificationsBellButton extends ConsumerWidget {
  const NotificationsBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Desktop: the module rail has this entry (with the badge).
    if (ref.watch(desktopLayoutProvider)) return const SizedBox.shrink();
    final count = ref.watch(notificationsUnreadBadgeProvider);
    final tokens = context.tokens;
    const icon = Icon(LucideIcons.bell);
    return IconButton(
      key: const Key('notifications_bell'),
      tooltip: context.l10n.notificationsTitle,
      onPressed: () => context.push(Routes.notifications),
      icon: count <= 0
          ? icon
          : Badge(
              label: Text(count > 99 ? '99+' : '$count'),
              backgroundColor: tokens.unreadBadge,
              textColor: tokens.onUnreadBadge,
              child: icon,
            ),
    );
  }
}
