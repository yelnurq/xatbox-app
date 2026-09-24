import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/chat_models.dart';
import 'chat_status_providers.dart';

/// «📅 На совещании · до 15:00» for a user, or nothing without a status.
/// Usable inside lazily built rows (it is its own consumer).
class ChatStatusLine extends ConsumerWidget {
  const ChatStatusLine({
    super.key,
    required this.userId,
    required this.loaded,
    this.style,
    this.withUntil = true,
    this.maxLines = 1,
    this.textAlign,
  });

  final String userId;
  final ChatUserStatus? loaded;
  final TextStyle? style;
  final bool withUntil;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = watchUserStatus(ref, userId, loaded);
    if (status == null) return const SizedBox.shrink();
    return Text(
      ChatStatusFormat.line(context, status, withUntil: withUntil),
      key: ValueKey('status_line_$userId'),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: style,
    );
  }
}
