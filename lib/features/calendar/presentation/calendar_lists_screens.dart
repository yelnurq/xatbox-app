import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/calendar_models.dart';
import 'calendar_format.dart';
import 'calendar_providers.dart';
import 'calendar_widgets.dart';

/// Invitations from colleagues waiting for an answer.
class CalendarInvitationsScreen extends ConsumerWidget {
  const CalendarInvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final data = ref.watch(calendarInvitationsProvider);
    final repo = ref.read(calendarRepositoryProvider);
    final sync = ref.watch(calendarSyncProvider);
    Future<void> refresh() => ref.read(calendarSyncProvider.notifier).sync();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calendarInvitations)),
      body: Column(
        children: [
          if (sync.offline) OfflineBanner(text: l10n.calendarOfflineCached, onRetry: refresh),
          Expanded(
            child: data.when(
              loading: () => const StateView.loading(),
              error: (e, _) => StateView.error(message: CalendarFormat.error(l10n, e), onRetry: refresh),
              data: (list) => list.isEmpty
                  ? RefreshIndicator(
                      onRefresh: refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: 360,
                            child: StateView.empty(title: l10n.calendarInvitationsEmpty, icon: LucideIcons.mailOpen),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: refresh,
                      child: ListView.separated(
                        key: const Key('invitations_list'),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final o = list[i];
                          return Column(
                            children: [
                              OccurrenceTile(occurrence: o, showDate: true),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.sm),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      key: ValueKey('decline_${o.key}'),
                                      onPressed: o.event.isMandatory ? null : () => repo.respond(o.event, RsvpStatus.declined),
                                      child: Text(l10n.calendarRsvpDecline),
                                    ),
                                    TextButton(
                                      onPressed: () => repo.respond(o.event, RsvpStatus.tentative),
                                      child: Text(l10n.calendarRsvpTentative),
                                    ),
                                    FilledButton.tonal(
                                      key: ValueKey('accept_${o.key}'),
                                      onPressed: () => repo.respond(o.event, RsvpStatus.accepted),
                                      child: Text(l10n.calendarRsvpAccept),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Search over the cached months (the API has no search endpoint).
class CalendarSearchScreen extends ConsumerStatefulWidget {
  const CalendarSearchScreen({super.key, this.initialQuery = ''});

  /// Pre-filled text («Показать все» of the unified search, `?q=`).
  final String initialQuery;

  @override
  ConsumerState<CalendarSearchScreen> createState() => _CalendarSearchScreenState();
}

class _CalendarSearchScreenState extends ConsumerState<CalendarSearchScreen> {
  Timer? _debounce;
  late String _query = widget.initialQuery.trim();
  late final _controller = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final results = _query.length < 2 ? null : ref.watch(calendarSearchProvider(_query));
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const Key('calendar_search_field'),
          controller: _controller,
          autofocus: widget.initialQuery.isEmpty,
          decoration: InputDecoration(hintText: l10n.calendarSearchHint, border: InputBorder.none, isDense: true),
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), () {
              if (mounted) setState(() => _query = v.trim());
            });
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Space.sm),
            child: Text(l10n.calendarSearchCachedOnly, style: TextStyle(color: tokens.textMuted)),
          ),
          Expanded(
            child: results == null
                ? const SizedBox.shrink()
                : results.when(
                    loading: () => const StateView.loading(),
                    error: (e, _) => StateView.error(message: CalendarFormat.error(l10n, e)),
                    data: (list) => list.isEmpty
                        ? StateView.empty(title: l10n.calendarSearchEmpty, icon: LucideIcons.searchX)
                        : ListView(
                            children: [for (final o in list) OccurrenceTile(occurrence: o, showDate: true)],
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
