import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../data/chat_messenger2.dart';
import '../data/chat_models.dart';
import 'chat_providers.dart';

/// Providers of messenger part 2: server features, stickers, transcription
/// preferences, report status updates.

final chatMessenger2ApiProvider = Provider<ChatMessenger2Api>(
  (ref) => ChatMessenger2Api(ref.watch(chatApiClientProvider)),
);

/// `GET /features` of the signed-in user (none when chat is off or the
/// server is older).
final chatFeaturesProvider = FutureProvider<ChatFeatures>((ref) async {
  ref.watch(currentUserProvider.select((u) => u?.id));
  if (!ref.watch(chatEnabledProvider)) return ChatFeatures.none;
  try {
    return await ref.watch(chatMessenger2ApiProvider).features();
  } on AppException catch (e) {
    DiagnosticLog.warn('chat', 'features unavailable', error: e);
    return ChatFeatures.none;
  }
});

/// Sticker packs available to the organization (default pack first).
final chatStickerPacksProvider = FutureProvider<List<ChatStickerPack>>((
  ref,
) async {
  ref.watch(currentUserProvider.select((u) => u?.id));
  if (!ref.watch(chatEnabledProvider)) return const [];
  return ref.watch(chatMessenger2ApiProvider).stickerPacks();
});

/// A sticker image on disk (`chat_media/stickers`), downloaded once: sticker
/// images never change (a new upload gets a new id).
final chatStickerFileProvider = FutureProvider.family<File, String>((
  ref,
  stickerId,
) async {
  final root = await ref.watch(chatMediaRootProvider)();
  final dir = Directory(p.join(root.path, 'chat_media', 'stickers'));
  final safe = stickerId.replaceAll(RegExp(r'[^0-9a-fA-F-]'), '');
  final file = File(p.join(dir.path, '$safe.img'));
  if (await file.exists() && await file.length() > 0) return file;
  await dir.create(recursive: true);
  final part = File('${file.path}.part');
  await ref.read(chatMessenger2ApiProvider).downloadSticker(stickerId, part.path);
  return part.rename(file.path);
});

/// Recently sent stickers (newest first, persisted in the chat cache).
class ChatRecentStickersNotifier extends Notifier<List<ChatSticker>> {
  static const _key = 'recent_stickers';
  static const max = 16;

  @override
  List<ChatSticker> build() {
    unawaited(_load());
    return const [];
  }

  Future<void> _load() async {
    final raw = await ref.read(chatCacheProvider).readMeta(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => ChatSticker.fromJson(e.cast<String, dynamic>()))
          .where((s) => s.id.isNotEmpty)
          .toList();
      if (ref.mounted && state.isEmpty) state = list;
    } on FormatException {
      // corrupted meta: start over
    }
  }

  Future<void> use(ChatSticker sticker) async {
    final next = [
      sticker,
      ...state.where((s) => s.id != sticker.id),
    ].take(max).toList();
    state = next;
    await ref
        .read(chatCacheProvider)
        .writeMeta(_key, jsonEncode([for (final s in next) s.toJson()]));
  }
}

final chatRecentStickersProvider =
    NotifierProvider<ChatRecentStickersNotifier, List<ChatSticker>>(
      ChatRecentStickersNotifier.new,
    );

/// «Автоматически расшифровывать голосовые» (this device).
class ChatAutoTranscribeNotifier extends Notifier<bool> {
  static const _key = 'auto_transcribe';

  @override
  bool build() {
    unawaited(
      ref.read(chatCacheProvider).readMeta(_key).then((v) {
        if (ref.mounted && v == '1') state = true;
      }),
    );
    return false;
  }

  Future<void> set(bool value) async {
    state = value;
    await ref.read(chatCacheProvider).writeMeta(_key, value ? '1' : '0');
  }
}

final chatAutoTranscribeProvider =
    NotifierProvider<ChatAutoTranscribeNotifier, bool>(
      ChatAutoTranscribeNotifier.new,
    );

/// `report.updated` for the caller's own reports (always a neutral
/// "reviewed").
final chatReportReviewedProvider = StreamProvider<ChatEvent>(
  (ref) => ref
      .watch(chatRepositoryProvider)
      .events
      .where((e) => e.type == 'report.updated'),
);

/// Messages still visible now: expired disappearing messages (and their
/// deleted copies) are dropped. Returns [messages] itself when nothing is
/// filtered, so memoised lists stay identical.
List<ChatMessage> withoutExpired(List<ChatMessage> messages, DateTime now) {
  var any = false;
  for (final m in messages) {
    if (m.expiresAt != null && (m.isDeleted || m.isExpiredAt(now))) {
      any = true;
      break;
    }
  }
  if (!any) return messages;
  return [
    for (final m in messages)
      if (!(m.expiresAt != null && (m.isDeleted || m.isExpiredAt(now)))) m,
  ];
}

/// The next moment a visible message expires (null = none).
DateTime? nextExpiry(List<ChatMessage> messages, DateTime now) {
  DateTime? next;
  for (final m in messages) {
    final at = m.expiresAt;
    if (at == null || m.isDeleted || !at.isAfter(now)) continue;
    if (next == null || at.isBefore(next)) next = at;
  }
  return next;
}
