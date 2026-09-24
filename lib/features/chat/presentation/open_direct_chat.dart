import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import 'chat_formatters.dart';
import 'chat_providers.dart';

/// «Написать лично»: opens the one-to-one chat with [userId] — the one
/// already there, or a new one. On the desktop the route lands in the
/// messenger's pane (app_router redirect), exactly as a tap in the list.
Future<void> openDirectChat(BuildContext context, WidgetRef ref, String userId) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final repo = ref.read(chatRepositoryProvider);
    final existing = (await repo.cachedConversations())
        .where((c) => !c.isGroup && !c.isChannel && c.peer?.userId == userId)
        .firstOrNull;
    final conv = existing ?? await repo.createDirect(userId);
    unawaited(router.push(Routes.chatConversationPath(conv.id)));
  } on AppException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(ChatFormat.error(l10n, e))));
  }
}
