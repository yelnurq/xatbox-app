import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/chat_providers.dart';

/// Unread chats for the "Чат" tab badge (unmuted conversations).
final chatBadgeProvider = Provider<int>(
  (ref) => ref.watch(chatUnreadBadgeProvider),
);
