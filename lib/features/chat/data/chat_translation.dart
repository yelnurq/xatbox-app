import 'dart:convert';

import '../../../core/api/api_client.dart';
import 'chat_cache.dart';
import 'chat_models.dart';

/// Message translation through chat-service (`POST /translate`,
/// `POST /messages/{id}/translate`). The server runs a self-hosted
/// translator; the flag comes from `GET /features` → `translation`.
abstract final class TranslateLanguages {
  static const supported = ['ru', 'kk', 'en'];

  /// A supported code for [code] (the app language), or `ru`.
  static String normalize(String? code) {
    final c = (code ?? '').toLowerCase();
    return supported.contains(c) ? c : 'ru';
  }

  static const _kazakh = 'әғқңөұүһіӘҒҚҢӨҰҮҺІ';

  /// Script heuristic shared with the server: Kazakh-only letters → kk,
  /// other Cyrillic → ru, otherwise en. Kazakh without those letters reads
  /// as Russian.
  static String detect(String text) {
    var cyr = 0, lat = 0, kaz = 0;
    for (final r in text.runes) {
      final ch = String.fromCharCode(r);
      if (_kazakh.contains(ch)) {
        kaz++;
        cyr++;
      } else if (r >= 0x0400 && r <= 0x04FF) {
        cyr++;
      } else if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A)) {
        lat++;
      }
    }
    if (kaz > 0 && cyr >= lat) return 'kk';
    if (cyr > 0 && cyr >= lat) return 'ru';
    return 'en';
  }

  /// Splits [text] into pieces of at most [max] characters, preferring
  /// paragraph, then line, sentence and word boundaries. Joining the pieces
  /// gives [text] back.
  static List<String> chunks(String text, int max) {
    if (max <= 0 || text.length <= max) return [text];
    final out = <String>[];
    var rest = text;
    while (rest.length > max) {
      final cut = _lastBreak(rest.substring(0, max));
      out.add(rest.substring(0, cut));
      rest = rest.substring(cut);
    }
    if (rest.isNotEmpty) out.add(rest);
    return out;
  }

  static int _lastBreak(String s) {
    final min = s.length ~/ 2;
    for (final pattern in [
      RegExp(r'\n\s*\n'),
      RegExp(r'\n'),
      RegExp(r'[.!?…]\s'),
      RegExp(r'\s'),
    ]) {
      final matches = pattern.allMatches(s).where((m) => m.end > min);
      if (matches.isNotEmpty) return matches.last.end;
    }
    return s.length;
  }
}

/// Whether a message has text the server can translate.
bool chatMessageTranslatable(ChatMessage m) =>
    m.seq > 0 &&
    !m.isDeleted &&
    !m.isSystem &&
    !m.isContact &&
    !m.isSticker &&
    !m.isPoll &&
    m.body.trim().isNotEmpty;

class ChatTranslationResult {
  const ChatTranslationResult({
    required this.text,
    required this.source,
    required this.target,
    this.cached = false,
  });
  final String text;

  /// Detected source language (`ru` / `kk` / `en`).
  final String source;
  final String target;
  final bool cached;

  /// The server found the text already in [target].
  bool get sameLanguage => source == target;

  factory ChatTranslationResult.fromJson(
    Map<String, dynamic> j, {
    required String target,
  }) => ChatTranslationResult(
    text: (j['text'] as String?) ?? '',
    source: (j['source_detected'] as String?) ?? '',
    target: (j['target'] as String?) ?? target,
    cached: j['cached'] == true,
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'source_detected': source,
    'target': target,
  };
}

class ChatTranslateApi {
  ChatTranslateApi(this._client);
  final ApiClient _client;

  /// `POST /messages/{id}/translate?target=`.
  Future<ChatTranslationResult> translateMessage(
    String messageId,
    String target,
  ) async {
    final json = await _client.postJson(
      '/messages/${Uri.encodeComponent(messageId)}/translate',
      query: {'target': target},
      expectedStatuses: const {200},
    );
    return ChatTranslationResult.fromJson(json, target: target);
  }

  /// `POST /translate` (≤ `translation_max_chars`; see [translateLong]).
  Future<ChatTranslationResult> translateText(
    String text, {
    String source = 'auto',
    required String target,
  }) async {
    final json = await _client.postJson(
      '/translate',
      body: {'text': text, 'source': source, 'target': target},
      expectedStatuses: const {200},
    );
    return ChatTranslationResult.fromJson(json, target: target);
  }

  /// Translates text of any length piece by piece (paragraph boundaries,
  /// at most [maxChars] per request), reporting progress after each piece.
  Future<ChatTranslationResult> translateLong(
    String text, {
    required String target,
    int maxChars = 4000,
    void Function(String partial, int done, int total)? onProgress,
  }) async {
    final pieces = TranslateLanguages.chunks(text, maxChars);
    final buf = StringBuffer();
    String? source;
    for (var i = 0; i < pieces.length; i++) {
      final piece = pieces[i];
      if (piece.trim().isEmpty) {
        buf.write(piece);
      } else {
        final r = await translateText(
          piece,
          source: source ?? 'auto',
          target: target,
        );
        source ??= r.source.isEmpty ? null : r.source;
        final lead = RegExp(r'^\s*').firstMatch(piece)!.group(0)!;
        final trail = RegExp(r'\s*$').firstMatch(piece)!.group(0)!;
        buf
          ..write(lead)
          ..write(r.text.trim())
          ..write(trail);
      }
      onProgress?.call(buf.toString(), i + 1, pieces.length);
    }
    return ChatTranslationResult(
      text: buf.toString(),
      source: source ?? TranslateLanguages.detect(text),
      target: target,
    );
  }
}

/// Translations kept on the device (chat cache meta, cleared on sign-out),
/// bounded to [maxEntries] most recent.
class ChatTranslationStore {
  ChatTranslationStore(this._cache);
  final ChatCache _cache;

  static const maxEntries = 300;
  static const _indexKey = 'translate:index';

  static String key(ChatMessage m, String target) =>
      '${m.id}|${m.editedAt?.microsecondsSinceEpoch ?? 0}|$target';

  Future<ChatTranslationResult?> read(String key) async {
    final raw = await _cache.readMeta('translate:$key');
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return ChatTranslationResult.fromJson(j, target: key.split('|').last);
    } on Object {
      return null;
    }
  }

  Future<void> write(String key, ChatTranslationResult r) async {
    await _cache.writeMeta('translate:$key', jsonEncode(r.toJson()));
    List<String> index;
    try {
      index = ((jsonDecode(await _cache.readMeta(_indexKey) ?? '[]') as List)
          .whereType<String>()
          .where((k) => k != key)
          .toList());
    } on Object {
      index = [];
    }
    index.add(key);
    while (index.length > maxEntries) {
      // Oldest entries are blanked (the meta store has no delete).
      await _cache.writeMeta('translate:${index.removeAt(0)}', '');
    }
    await _cache.writeMeta(_indexKey, jsonEncode(index));
  }
}
