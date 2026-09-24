import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/state_view.dart';
import '../../chat/presentation/chat_providers.dart';
import 'calls_format.dart';
import 'calls_providers.dart';

/// Moderator adds colleagues to a running group / conference call: the same
/// directory as chat, without people already in the call. The server checks
/// the role and the limit again (`NOT_MODERATOR`, `TOO_MANY_PARTICIPANTS`).
class CallInviteSheet extends ConsumerStatefulWidget {
  const CallInviteSheet({super.key});

  @override
  ConsumerState<CallInviteSheet> createState() => _CallInviteSheetState();
}

class _CallInviteSheetState extends ConsumerState<CallInviteSheet> {
  Timer? _debounce;
  String _query = '';
  final Map<String, String> _selected = {};
  bool _busy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    final call = ref.read(callControllerProvider).call;
    if (call == null || _selected.isEmpty || _busy) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (call.participants.length + _selected.length > ref.read(callsConfigProvider).limitFor(call.mode)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.callsErrTooMany)));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(callControllerProvider.notifier).invite(_selected.keys.toList());
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.callsInviteSent)));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(CallsFormat.error(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final call = ref.watch(callControllerProvider.select((s) => s.call));
    if (call == null) return const SizedBox.shrink();
    final selfId = ref.watch(currentUserProvider)?.id ?? '';
    final inCall = {selfId, for (final p in call.participants) p.userId};
    final users = ref.watch(chatUserSearchProvider(_query));
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Text(l10n.callsInvite, style: Theme.of(context).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.md),
              child: TextField(
                key: const Key('call_invite_search'),
                decoration: InputDecoration(hintText: l10n.chatSearchUsers, prefixIcon: const Icon(LucideIcons.search)),
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), () {
                    if (mounted) setState(() => _query = v.trim());
                  });
                },
              ),
            ),
            Expanded(
              child: users.when(
                loading: () => const StateView.loading(),
                error: (e, _) => StateView.error(
                  message: CallsFormat.error(l10n, e),
                  onRetry: () => ref.invalidate(chatUserSearchProvider(_query)),
                ),
                data: (list) {
                  final visible = list.where((u) => !inCall.contains(u.userId)).toList();
                  if (visible.isEmpty) {
                    return StateView.empty(
                      title: list.isEmpty ? l10n.chatNoUsers : l10n.callsInviteNobody,
                      icon: LucideIcons.userSearch,
                    );
                  }
                  return ListView.builder(
                    key: const Key('call_invite_list'),
                    itemCount: visible.length,
                    itemBuilder: (_, i) {
                      final u = visible[i];
                      return CheckboxListTile(
                        key: ValueKey('invite_pick_${u.userId}'),
                        value: _selected.containsKey(u.userId),
                        secondary: InitialsAvatar(label: u.label, colorKey: u.userId),
                        title: Text(u.label),
                        subtitle: Text(u.email),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected[u.userId] = u.label;
                          } else {
                            _selected.remove(u.userId);
                          }
                        }),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.md),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('call_invite_submit'),
                  onPressed: _selected.isEmpty || _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(LucideIcons.userPlus),
                  label: Text(l10n.callsInviteSubmit(_selected.length)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
