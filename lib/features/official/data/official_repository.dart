import '../../../core/api/api_exception.dart';
import '../../../shared/utils/diagnostic_log.dart';
import 'official_api.dart';
import 'official_cache.dart';
import 'official_models.dart';

class OfficialListResult {
  const OfficialListResult({
    required this.messages,
    required this.fromCache,
    this.error,
    this.savedAt,
  });
  final List<OfficialMessage> messages;
  final bool fromCache;

  /// Why the cache was served (network / transient server failure).
  final AppException? error;
  final DateTime? savedAt;
}

/// Network first; the list is cached per account. When the network or the
/// server is unavailable the cached list is served. Permission errors are
/// never masked by the cache.
class OfficialRepository {
  OfficialRepository({
    required OfficialApi api,
    required OfficialCache cache,
    required String Function() selfId,
    DateTime Function()? clock,
  }) : _api = api, // ignore: prefer_initializing_formals
       _cache = cache, // ignore: prefer_initializing_formals
       _selfId = selfId, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now;

  final OfficialApi _api;
  final OfficialCache _cache;
  final String Function() _selfId;
  final DateTime Function() _clock;

  OfficialApi get api => _api;
  DateTime now() => _clock();

  static bool canUseCache(AppException e) =>
      e is NetworkException ||
      (e is ApiException && (e.statusCode >= 500 || e.statusCode == 429));

  Future<CachedOfficialList?> cached() => _cache.read(ownerId: _selfId());

  Future<OfficialListResult> load() async {
    try {
      final messages = await _api.list();
      await _cache.write(
        ownerId: _selfId(),
        messages: messages,
        savedAt: _clock(),
      );
      return OfficialListResult(messages: messages, fromCache: false);
    } on AppException catch (e) {
      if (!canUseCache(e)) rethrow;
      final saved = await cached();
      if (saved == null) rethrow;
      DiagnosticLog.warn('official', 'list load failed, using cache', error: e);
      return OfficialListResult(
        messages: saved.messages,
        fromCache: true,
        error: e,
        savedAt: saved.savedAt,
      );
    }
  }

  /// Keeps the cached copy in line with local read / acknowledge changes.
  Future<void> saveList(List<OfficialMessage> messages) =>
      _cache.write(ownerId: _selfId(), messages: messages, savedAt: _clock());

  Future<List<SentOfficial>> sent() => _cache.readSent(ownerId: _selfId());

  /// Sends [draft] and remembers it locally (newest first).
  Future<OfficialCreated> create(OfficialDraft draft) async {
    final created = await _api.create(draft);
    final owner = _selfId();
    final previous = await _cache.readSent(ownerId: owner);
    await _cache.writeSent(
      ownerId: owner,
      sent: [
        SentOfficial(
          id: created.id,
          title: draft.title.trim(),
          recipientCount: created.recipientCount,
          requiresAcknowledgement: draft.requiresAcknowledgement,
          sentAt: _clock(),
        ),
        for (final s in previous)
          if (s.id != created.id) s,
      ],
    );
    return created;
  }

  Future<void> clear() => _cache.clear();
}
