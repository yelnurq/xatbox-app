import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../data/chat_models.dart';
import '../../data/chat_translation.dart';
import '../chat_providers.dart';
import '../messenger2_providers.dart';

/// Translation providers: availability (server flag), the target language
/// (Settings → Язык, defaults to the app language), per-chat auto
/// translation and the translations of messages on screen.

final chatTranslateApiProvider = Provider<ChatTranslateApi>(
  (ref) => ChatTranslateApi(ref.watch(chatApiClientProvider)),
);

/// The server has a translator (`GET /features` → `translation`). False
/// while loading, when chat is off or chat-service is unreachable.
final translationAvailableProvider = Provider<bool>(
  (ref) => ref.watch(chatFeaturesProvider).value?.translation ?? false,
);

/// The chosen target language; null = the app language.
class TranslateTargetNotifier extends Notifier<String?> {
  static const _key = 'pref:translate_target';

  @override
  String? build() {
    unawaited(
      ref.read(chatCacheProvider).readMeta(_key).then((v) {
        if (ref.mounted && TranslateLanguages.supported.contains(v)) state = v;
      }),
    );
    return null;
  }

  Future<void> set(String? code) async {
    state = TranslateLanguages.supported.contains(code) ? code : null;
    await ref.read(chatCacheProvider).writeMeta(_key, state ?? '');
  }
}

final translateTargetPrefProvider =
    NotifierProvider<TranslateTargetNotifier, String?>(
      TranslateTargetNotifier.new,
    );

/// The effective target: the preference or the app language. [listen]
/// false outside build methods.
String translateTarget(
  WidgetRef ref,
  BuildContext context, {
  bool listen = true,
}) =>
    (listen
        ? ref.watch(translateTargetPrefProvider)
        : ref.read(translateTargetPrefProvider)) ??
    TranslateLanguages.normalize(Localizations.localeOf(context).languageCode);

/// Language name for labels («русский», «қазақ тілі», «English»…).
String translateLanguageName(AppLocalizations l10n, String code) =>
    switch (code) {
      'kk' => l10n.translateLangKk,
      'en' => l10n.translateLangEn,
      'ru' => l10n.translateLangRu,
      _ => code,
    };

/// Localized error text of a failed translation.
String translateErrorText(AppLocalizations l10n, Object e) {
  if (e is ApiException) {
    switch (e.code) {
      case 'RATE_LIMITED':
        return l10n.translateRateLimited;
      case 'TEXT_TOO_LONG':
        return l10n.translateTooLong;
      case 'TRANSLATION_UNAVAILABLE':
      case 'TRANSLATION_BUSY':
      case 'FEATURE_DISABLED':
        return l10n.translateUnavailable;
    }
  }
  return l10n.translateFailed;
}

/// Conversations where incoming messages are translated automatically.
class ChatAutoTranslateNotifier extends Notifier<Set<String>> {
  static const _key = 'translate_auto_chats';

  @override
  Set<String> build() {
    unawaited(_load());
    return const {};
  }

  Future<void> _load() async {
    final raw = await ref.read(chatCacheProvider).readMeta(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final ids = (jsonDecode(raw) as List).whereType<String>().toSet();
      if (ref.mounted && state.isEmpty) state = ids;
    } on FormatException {
      // corrupted meta: start over
    }
  }

  Future<void> set(String conversationId, bool on) async {
    state = on
        ? {...state, conversationId}
        : ({...state}..remove(conversationId));
    await ref
        .read(chatCacheProvider)
        .writeMeta(_key, jsonEncode(state.toList()));
  }
}

final chatAutoTranslateProvider =
    NotifierProvider<ChatAutoTranslateNotifier, Set<String>>(
      ChatAutoTranslateNotifier.new,
    );

enum MessageTranslationStatus { loading, done, failed }

class MessageTranslationState {
  const MessageTranslationState(
    this.status, {
    this.result,
    this.error,
    this.auto = false,
  });
  final MessageTranslationStatus status;
  final ChatTranslationResult? result;
  final Object? error;

  /// Requested by «Переводить автоматически» (failures stay quiet).
  final bool auto;
}

/// Translations of messages, keyed by [ChatTranslationStore.key] (message,
/// edit version, target). Messages in [hidden] show their original only.
class ChatTranslationsState {
  const ChatTranslationsState({this.items = const {}, this.hidden = const {}});
  final Map<String, MessageTranslationState> items;
  final Set<String> hidden;

  ChatTranslationsState copyWith({
    Map<String, MessageTranslationState>? items,
    Set<String>? hidden,
  }) => ChatTranslationsState(
    items: items ?? this.items,
    hidden: hidden ?? this.hidden,
  );
}

class ChatTranslationsNotifier extends Notifier<ChatTranslationsState> {
  @override
  ChatTranslationsState build() {
    // A different account never sees translations of the previous one.
    ref.watch(chatRepositoryProvider);
    return const ChatTranslationsState();
  }

  ChatTranslationStore get _store =>
      ChatTranslationStore(ref.read(chatCacheProvider));

  void _put(String key, MessageTranslationState s) {
    if (!ref.mounted) return;
    state = state.copyWith(items: {...state.items, key: s});
  }

  /// Translates [m] into [target]: memory, then the device cache, then the
  /// server (which caches per message version for every reader).
  Future<void> request(
    ChatMessage m,
    String target, {
    bool auto = false,
  }) async {
    final key = ChatTranslationStore.key(m, target);
    if (state.hidden.contains(m.id)) {
      state = state.copyWith(hidden: {...state.hidden}..remove(m.id));
    }
    final current = state.items[key];
    if (current != null && current.status != MessageTranslationStatus.failed) {
      // A manual request shows what auto translation kept quiet.
      if (!auto && current.auto) {
        _put(
          key,
          MessageTranslationState(current.status, result: current.result),
        );
      }
      return;
    }
    _put(
      key,
      MessageTranslationState(MessageTranslationStatus.loading, auto: auto),
    );
    try {
      var result = await _store.read(key);
      if (result == null) {
        result = await ref
            .read(chatTranslateApiProvider)
            .translateMessage(m.id, target);
        await _store.write(key, result);
      }
      _put(
        key,
        MessageTranslationState(
          MessageTranslationStatus.done,
          result: result,
          auto: auto,
        ),
      );
    } on AppException catch (e) {
      _put(
        key,
        MessageTranslationState(
          MessageTranslationStatus.failed,
          error: e,
          auto: auto,
        ),
      );
      if (!auto) rethrow;
    }
  }

  /// «Показать оригинал».
  void hide(String messageId) {
    state = state.copyWith(hidden: {...state.hidden, messageId});
  }
}

final chatTranslationsProvider =
    NotifierProvider<ChatTranslationsNotifier, ChatTranslationsState>(
      ChatTranslationsNotifier.new,
    );
