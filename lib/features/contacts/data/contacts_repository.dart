import '../../../core/api/api_exception.dart';
import '../../../shared/utils/diagnostic_log.dart';
import 'contact_models.dart';
import 'contacts_api.dart';
import 'contacts_cache.dart';

class ContactsResult {
  const ContactsResult({
    required this.contacts,
    required this.fromCache,
    this.hasMore = false,
    this.offset = 0,
    this.error,
    this.savedAt,
  });
  final List<Contact> contacts;
  final bool fromCache;
  final bool hasMore;

  /// Where this page started in the directory order.
  final int offset;

  /// Why the cache was used (network / transient server failure).
  final AppException? error;
  final DateTime? savedAt;
}

/// Network first; the full list (empty query, no department) is cached. When
/// the network or the service is unavailable, the cached list is served —
/// filtered locally. Permission errors are not masked by the cache.
class ContactsRepository {
  ContactsRepository({
    required ContactsApi api,
    required ContactsCache cache,
    required String Function() selfId,
    ContactsFavouritesStore? favourites,
    DateTime Function()? clock,
  }) : _api = api, // ignore: prefer_initializing_formals
       _cache = cache, // ignore: prefer_initializing_formals
       _favourites = favourites, // ignore: prefer_initializing_formals
       _selfId = selfId, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now;

  final ContactsApi _api;
  final ContactsCache _cache;
  final ContactsFavouritesStore? _favourites;
  final String Function() _selfId;
  final DateTime Function() _clock;

  Future<CachedDirectory?> cached() => _cache.read(ownerId: _selfId());

  static bool _canUseCache(AppException e) =>
      e is NetworkException ||
      (e is ApiException && (e.statusCode >= 500 || e.statusCode == 429));

  /// The route or proxy is missing on an older service.
  static bool _unsupported(AppException e) =>
      e is ApiException && (e.statusCode == 404 || e.statusCode == 405);

  /// One page of the directory. The unpaged full list (no query, no
  /// department, first page, no narrower limit) is what the offline cache
  /// holds, so only that answer overwrites it; a caller that walks the
  /// directory page by page keeps the cache itself with [cacheDirectory].
  Future<ContactsResult> load(
    String query, {
    String? departmentId,
    int limit = ContactsApi.maxLimit,
    int offset = 0,
  }) async {
    final dept = departmentId ?? '';
    final from = offset < 0 ? 0 : offset;
    try {
      final page = await _api.search(
        query,
        departmentId: dept,
        limit: limit,
        offset: from,
      );
      if (query.trim().isEmpty &&
          dept.isEmpty &&
          from == 0 &&
          limit >= ContactsApi.maxLimit) {
        await _cache.write(
          ownerId: _selfId(),
          contacts: page.contacts,
          savedAt: _clock(),
        );
      }
      return ContactsResult(
        contacts: page.contacts,
        fromCache: false,
        hasMore: page.hasMore,
        offset: from,
      );
    } on AppException catch (e) {
      if (!_canUseCache(e)) rethrow;
      final dir = await cached();
      if (dir == null) rethrow;
      DiagnosticLog.warn(
        'contacts',
        'directory load failed, using cache',
        error: e,
      );
      final matching = dir.contacts
          .where(
            (c) => c.matches(query) && (dept.isEmpty || c.departmentId == dept),
          )
          .toList();
      final slice = matching.skip(from).take(limit).toList();
      return ContactsResult(
        contacts: slice,
        fromCache: true,
        hasMore: from + slice.length < matching.length,
        offset: from,
        error: e,
        savedAt: dir.savedAt,
      );
    }
  }

  /// Replaces the offline copy of the directory with [contacts] (the pages
  /// a paging caller has collected so far).
  Future<void> cacheDirectory(List<Contact> contacts) => _cache.write(
    ownerId: _selfId(),
    contacts: contacts,
    savedAt: _clock(),
  );

  /// Looks a colleague up by id: `GET /users/{id}` (fresh presence), then
  /// the cached directory when the service is unreachable or too old.
  Future<Contact?> find(String id) async {
    try {
      final hit = await _api.get(id);
      if (hit != null) return hit;
    } on AppException catch (e) {
      if (!_canUseCache(e) && !_unsupported(e)) rethrow;
      final dir = await cached();
      final hit = dir?.contacts.where((c) => c.id == id).firstOrNull;
      if (hit != null) return hit;
      if (!_unsupported(e)) rethrow;
    }
    final dir = await cached();
    return dir?.contacts.where((c) => c.id == id).firstOrNull;
  }

  /// Departments of the organization (active first by name), cached for
  /// offline use. Without the permission / on an older service: the cached
  /// list or empty.
  Future<List<Department>> departments() async {
    final owner = _selfId();
    try {
      final list = await _api.departments()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      await _cache.writeDepartments(ownerId: owner, departments: list);
      return list;
    } on AppException catch (e) {
      final cached = await _cache.readDepartments(ownerId: owner);
      if (cached != null) return cached;
      if (_canUseCache(e) || _unsupported(e) || e is ApiException) {
        DiagnosticLog.warn('contacts', 'departments unavailable', error: e);
        return const [];
      }
      rethrow;
    }
  }

  /// Colleagues of one department (network, else the cached directory).
  Future<List<Contact>> colleagues(String departmentId) async {
    if (departmentId.isEmpty) return const [];
    final result = await load('', departmentId: departmentId);
    return result.contacts;
  }

  Future<List<Contact>> favourites() async =>
      await _favourites?.read(ownerId: _selfId()) ?? const [];

  Future<void> saveFavourites(List<Contact> contacts) async =>
      _favourites?.write(ownerId: _selfId(), contacts: contacts);

  Future<void> clear() => _cache.clear();
}
