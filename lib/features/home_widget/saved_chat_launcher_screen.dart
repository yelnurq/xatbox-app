import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/localization.dart';
import '../../core/routing/routes.dart';
import '../../shared/utils/diagnostic_log.dart';
import '../../shared/widgets/state_view.dart';
import '../chat/presentation/chat_providers.dart';

/// Target of the «Избранное» shortcut (`xatbox://chat/saved`): finds the
/// saved-messages chat (created on first use, `POST /chats/saved`) and
/// replaces itself with that conversation.
class SavedChatLauncherScreen extends ConsumerStatefulWidget {
  const SavedChatLauncherScreen({super.key});

  @override
  ConsumerState<SavedChatLauncherScreen> createState() =>
      _SavedChatLauncherScreenState();
}

class _SavedChatLauncherScreenState
    extends ConsumerState<SavedChatLauncherScreen> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    if (_failed) setState(() => _failed = false);
    try {
      final saved = await ref.read(chatRepositoryProvider).savedConversation();
      if (!mounted) return;
      context.pushReplacement(Routes.chatConversationPath(saved.id));
    } on Object catch (e) {
      DiagnosticLog.warn('launcher', 'saved chat unavailable', error: e);
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      key: const Key('saved_chat_launcher'),
      appBar: AppBar(title: Text(l10n.chatSaved)),
      body: _failed
          ? StateView.error(
              message: l10n.savedChatOpenFailed,
              onRetry: _open,
              retryLabel: l10n.retry,
            )
          : const StateView.loading(),
    );
  }
}
