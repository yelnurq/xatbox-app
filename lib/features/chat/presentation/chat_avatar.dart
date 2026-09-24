import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../data/chat_models.dart';
import 'chat_providers.dart';

/// Conversation avatar: the group picture (`GET /chats/{id}/avatar`, cached
/// on disk) when there is one, otherwise the group icon or the peer initials.
/// [showOnline] adds the presence dot of a direct chat's peer.
class ChatAvatar extends ConsumerWidget {
  const ChatAvatar({
    super.key,
    required this.conversation,
    this.radius = 20,
    this.showOnline = false,
  });

  final ChatConversation conversation;
  final double radius;
  final bool showOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = _avatar(context, ref);
    if (!showOnline || conversation.peer?.online != true) return avatar;
    final t = context.tokens;
    final dot = (radius * 0.55).clamp(9.0, 14.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        // Decorative: "в сети" is part of the row / title label.
        Positioned(
          right: -1,
          bottom: -1,
          child: ExcludeSemantics(
            child: Container(
              key: ValueKey('chat_online_${conversation.id}'),
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: t.success,
                shape: BoxShape.circle,
                border: Border.all(color: t.surface, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatar(BuildContext context, WidgetRef ref) {
    final c = conversation;
    final t = context.tokens;
    if (c.isSaved) {
      return SavedMessagesAvatar(
        key: ValueKey('chat_avatar_saved_${c.id}'),
        radius: radius,
      );
    }
    if (c.isRequests) {
      return RequestsAvatar(
        key: ValueKey('chat_avatar_requests_${c.id}'),
        radius: radius,
      );
    }
    final fallback = c.isGroup || c.isChannel
        ? Container(
            key: ValueKey('chat_avatar_fallback_${c.id}'),
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              color: t.avatarColorFor(c.id),
              shape: BoxShape.circle,
            ),
            child: Icon(
              c.isChannel ? LucideIcons.megaphone : LucideIcons.users,
              size: radius,
              color: t.avatarTextColorFor(c.id),
            ),
          )
        // Direct chat: the peer's profile photo, by the same address the
        // mail module uses, with the initials circle as the fallback.
        : (c.peer?.email.isNotEmpty ?? false)
        ? UserAvatar(
            key: ValueKey('chat_avatar_peer_${c.id}'),
            email: c.peer!.email,
            label: c.title,
            radius: radius,
            excludeFromSemantics: true,
          )
        : InitialsAvatar(
            label: c.title,
            colorKey: c.peer?.userId ?? c.id,
            radius: radius,
          );
    if (!(c.isGroup || c.isChannel) || !c.hasAvatar) return fallback;
    final file = ref
        .watch(chatAvatarProvider((id: c.id, hasAvatar: c.hasAvatar)))
        .value;
    if (file == null) return fallback;
    final px = (radius * 2 * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipOval(
      key: ValueKey('chat_avatar_image_${c.id}'),
      child: Image.file(
        file,
        // The chat title is spoken by the row / app bar next to it.
        excludeFromSemantics: true,
        width: radius * 2,
        height: radius * 2,
        cacheWidth: px,
        cacheHeight: px,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

/// Bookmark avatar of «Избранное».
/// «Заявки» (desktop): the chat of the user's requests.
class RequestsAvatar extends StatelessWidget {
  const RequestsAvatar({super.key, this.radius = 20});
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Decorative: «Заявки» is the row title.
    return ExcludeSemantics(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(color: t.warning, shape: BoxShape.circle),
        child: Icon(LucideIcons.clipboardList, size: radius, color: t.textInverse),
      ),
    );
  }
}

class SavedMessagesAvatar extends StatelessWidget {
  const SavedMessagesAvatar({super.key, this.radius = 20});
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Decorative: «Избранное» is the row title.
    return ExcludeSemantics(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
        child: Icon(LucideIcons.bookmark, size: radius, color: t.textInverse),
      ),
    );
  }
}
