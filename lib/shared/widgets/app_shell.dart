import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/localization/localization.dart';
import '../../core/permissions/permission_onboarding_host.dart';
import '../../core/platform/desktop_layout.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/tokens.dart';
import '../../features/calls/calls_badge.dart';
import '../../features/calendar/presentation/calendar_providers.dart';
import '../../features/calls/presentation/calls_providers.dart';
import '../../features/chat/chat_badge.dart';
import '../../features/mail/presentation/mail_providers.dart';
import '../../features/tasks/presentation/tasks_providers.dart';
import 'ds/x_badge.dart';
import 'glass_tab_bar.dart';

/// Phone navigation host (ТЗ п.24.2). `StatefulShellRoute.indexedStack`
/// keeps each module's navigator and scroll state alive across switches.
///
/// The bar is the iOS 26 style glass capsule ([GlassTabBar]) with the
/// desktop's modules: Почта, Чат, Календарь, Задачи and «Ещё», which opens a
/// glass panel with Звонки, Контакты, «Сегодня» and Настройки. The pages run
/// under the glass (`extendBody`).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  // Shell branch indices (app_router.dart).
  static const mailBranch = 0;
  static const chatBranch = 1;
  static const callsBranch = 2;
  static const contactsBranch = 3;
  static const todayBranch = 4;
  static const calendarBranch = 5;
  static const tasksBranch = 6;

  /// Branches with their own tab, in bar order, for the modules the user
  /// may use; the rest live under «Ещё» (pure).
  static List<int> tabBranches({bool chat = true, bool calendar = true, bool tasks = true}) => [
    mailBranch,
    if (chat) chatBranch,
    if (calendar) calendarBranch,
    if (tasks) tasksBranch,
  ];

  /// Bar index of [branch] among [tabs]: its tab, or «Ещё» (pure).
  static int tabIndexOf(int branch, List<int> tabs) {
    final i = tabs.indexOf(branch);
    return i >= 0 ? i : tabs.length;
  }

  void _go(int branch) {
    navigationShell.goBranch(
      branch,
      // Re-tapping the active module returns to its root.
      initialLocation: branch == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final body = PermissionOnboardingHost(
      callsEnabled: ref.watch(callsEnabledProvider),
      child: navigationShell,
    );
    // Desktop: the web shell (DesktopFrame: sidebar + top bar) replaces the bottom bar.
    if (ref.watch(desktopLayoutProvider)) return Scaffold(body: body);

    final missedCalls = ref.watch(callsBadgeProvider);
    // Chat keeps its tab as before (its screen explains when it is off);
    // calendar and tasks appear for users who may use them.
    final branches = tabBranches(
      calendar: ref.watch(calendarEnabledProvider),
      tasks: ref.watch(tasksEnabledProvider),
    );
    final tabs = [
      for (final branch in branches)
        switch (branch) {
          chatBranch => GlassTab(
            key: const Key('tab_chat'),
            icon: LucideIcons.messageCircle,
            label: l10n.tabChat,
            badge: ref.watch(chatBadgeProvider),
          ),
          calendarBranch => GlassTab(
            key: const Key('tab_calendar'),
            icon: LucideIcons.calendarDays,
            label: l10n.calendarTitle,
            // Pending invitations.
            badge: ref.watch(calendarBadgeProvider),
          ),
          tasksBranch => GlassTab(key: const Key('tab_tasks'), icon: LucideIcons.squareCheckBig, label: l10n.tasksTitle),
          _ => GlassTab(
            key: const Key('tab_mail'),
            icon: LucideIcons.mail,
            label: l10n.tabMail,
            badge: ref.watch(mailUnreadBadgeProvider),
          ),
        },
      GlassTab(key: const Key('tab_more'), icon: LucideIcons.layoutGrid, label: l10n.tabMore, badge: missedCalls),
    ];
    return Scaffold(
      // The pages scroll under the glass bar.
      extendBody: true,
      // Notifications / full-screen calls explainers once after sign-in.
      // extendBody reports the bar's height as bottom padding only; the
      // pages' own Scaffolds place their FAB and snack bars by the view
      // padding, so it grows by the bar too — they float above the glass.
      body: Builder(
        builder: (context) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(viewPadding: mq.viewPadding.copyWith(bottom: mq.padding.bottom)),
            child: body,
          );
        },
      ),
      bottomNavigationBar: GlassTabBar(
        tabs: tabs,
        selectedIndex: tabIndexOf(navigationShell.currentIndex, branches),
        onSelected: (index) {
          if (index < branches.length) {
            _go(branches[index]);
          } else {
            _openMore(context, missedCalls);
          }
        },
      ),
    );
  }

  void _openMore(BuildContext context, int missedCalls) {
    final l10n = context.l10n;
    final current = navigationShell.currentIndex;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      useSafeArea: true,
      builder: (sheet) {
        void pick(VoidCallback go) {
          Navigator.of(sheet).pop();
          go();
        }

        return _MorePanel(
          items: [
            _MoreItem(
              key: const Key('more_calls'),
              icon: LucideIcons.phone,
              label: l10n.tabCalls,
              badge: missedCalls,
              selected: current == callsBranch,
              onTap: () => pick(() => _go(callsBranch)),
            ),
            _MoreItem(
              key: const Key('more_contacts'),
              icon: LucideIcons.users,
              label: l10n.contactsTab,
              selected: current == contactsBranch,
              onTap: () => pick(() => _go(contactsBranch)),
            ),
            _MoreItem(
              key: const Key('more_today'),
              icon: LucideIcons.sunrise,
              label: l10n.todayTab,
              selected: current == todayBranch,
              onTap: () => pick(() => _go(todayBranch)),
            ),
            _MoreItem(
              key: const Key('more_settings'),
              icon: LucideIcons.settings,
              label: l10n.settingsTitle,
              onTap: () => pick(() => context.push(Routes.settings)),
            ),
          ],
        );
      },
    );
  }
}

class _MoreItem {
  const _MoreItem({
    required this.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
    this.selected = false,
  });

  final Key key;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;
  final bool selected;
}

/// «Ещё»: a glass panel over the bar with the other modules as tiles.
class _MorePanel extends StatelessWidget {
  const _MorePanel({required this.items});
  final List<_MoreItem> items;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + GlassTabBar.barHeight + (bottom > 0 ? 0 : 12)),
      child: GlassSurface(
        radius: 28,
        child: Padding(
          padding: const EdgeInsets.all(Space.sm),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final item in items)
                Semantics(
                  button: true,
                  selected: item.selected,
                  label: item.badge > 0 ? '${item.label}, ${item.badge}' : item.label,
                  excludeSemantics: true,
                  child: InkWell(
                    key: item.key,
                    borderRadius: BorderRadius.circular(20),
                    onTap: item.onTap,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: item.selected ? t.primary : t.primarySoft.withValues(alpha: 0.8),
                          ),
                          child: Badge(
                            isLabelVisible: item.badge > 0,
                            label: Text(CountPill.format(item.badge)),
                            backgroundColor: t.danger,
                            textColor: t.textInverse,
                            child: Icon(item.icon, size: 22, color: item.selected ? t.textInverse : t.primary),
                          ),
                        ),
                        const SizedBox(height: Space.xs),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
