import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/platform/desktop_layout.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../calls/presentation/calls_providers.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../search/presentation/unified_search_button.dart';
import 'today_providers.dart';
import 'today_sections.dart';
import '../../mail/presentation/compose_window.dart';

/// «Сегодня» (optional start tab, Настройки → Оформление → «Начальный
/// экран»): greeting with the date, the sections of [todaySectionsProvider]
/// and quick actions. Data comes from the modules' own providers.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  /// Greeting for the local hour (pure).
  static String greeting(AppLocalizations l10n, int hour, String name) {
    final base = switch (hour) {
      >= 5 && < 12 => l10n.todayGreetingMorning,
      >= 12 && < 18 => l10n.todayGreetingAfternoon,
      >= 18 && < 23 => l10n.todayGreetingEvening,
      _ => l10n.todayGreetingNight,
    };
    return name.isEmpty ? base : '$base, $name';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final sections = ref.watch(todaySectionsProvider);
    final canSendMail = ref.watch(hasPermissionProvider(Permissions.mailSend));
    final chatOn = ref.watch(chatEnabledProvider);
    final callsOn = ref.watch(callsEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.pageTitle(l10n.todayTab)),
        actions: [
          const UnifiedSearchButton(),
          const NotificationsBellButton(),
          // Desktop: no pull to refresh with a mouse.
          if (ref.watch(desktopLayoutProvider))
            IconButton(
              key: const Key('today_refresh'),
              tooltip: l10n.desktopRefresh,
              icon: const Icon(LucideIcons.refreshCw),
              onPressed: () => refreshToday(ref),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => refreshToday(ref),
        child: ListView(
          key: const Key('today_list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: Space.xl),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.md,
                Space.md,
                Space.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting(l10n, now.hour, ref.watch(todayFirstNameProvider)),
                    key: const Key('today_greeting'),
                    style: text.headlineSmall,
                  ),
                  const SizedBox(height: Space.xxs),
                  Text(
                    toBeginningOfSentenceCase(
                      DateFormat.MMMMEEEEd(locale).format(now),
                    ),
                    style: text.bodyMedium?.copyWith(color: t.textSecondary),
                  ),
                ],
              ),
            ),
            if (canSendMail || chatOn || callsOn)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.md,
                  0,
                  Space.md,
                  Space.md,
                ),
                child: Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    if (canSendMail)
                      ActionChip(
                        key: const Key('today_new_mail'),
                        avatar: const Icon(LucideIcons.squarePen, size: 18),
                        label: Text(l10n.todayNewMail),
                        onPressed: () => openCompose(ref),
                      ),
                    if (chatOn)
                      ActionChip(
                        key: const Key('today_new_chat'),
                        avatar: const Icon(
                          LucideIcons.messageSquarePlus,
                          size: 18,
                        ),
                        label: Text(l10n.todayNewChat),
                        onPressed: () => context.push(Routes.chatNew),
                      ),
                    if (callsOn)
                      ActionChip(
                        key: const Key('today_new_call'),
                        avatar: const Icon(LucideIcons.phoneCall, size: 18),
                        label: Text(l10n.todayNewCall),
                        onPressed: () => context.push(Routes.callsNew),
                      ),
                  ],
                ),
              ),
            for (final build in sections) Builder(builder: build),
          ],
        ),
      ),
    );
  }
}
