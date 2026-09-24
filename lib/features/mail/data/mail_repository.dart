import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/utils/diagnostic_log.dart';
import 'mail_api.dart';
import 'mail_cache.dart';
import 'mail_models.dart';

/// Result of a list load with provenance.
class MailListResult {
  const MailListResult({
    required this.items,
    required this.total,
    required this.nextOffset,
    required this.fromCache,
  });
  final List<MailListItem> items;
  final int total;
  final int? nextOffset;
  final bool fromCache;
}

class MailDetailResult {
  const MailDetailResult({required this.detail, required this.fromCache});
  final MailMessageDetail detail;
  final bool fromCache;
}

/// Mutation events so every open list / detail can update without reloading.
sealed class MailEvent {
  const MailEvent();
}

class MailFlagsChanged extends MailEvent {
  const MailFlagsChanged(this.id, {this.isRead, this.isStarred});
  final String id;
  final bool? isRead;
  final bool? isStarred;
}

class MailMessageRemoved extends MailEvent {
  const MailMessageRemoved(this.id, {this.movedTo});
  final String id;

  /// Target folder when the removal was a move; null when destroyed.
  final String? movedTo;
}

class MailSummaryStale extends MailEvent {
  const MailSummaryStale();
}

/// Cache-first reads, network-first with offline fallback, and mutations that
/// keep the cache and every listener in sync.
class MailRepository {
  MailRepository({required MailApi api, required MailCache cache})
    : _api = api, // ignore: prefer_initializing_formals
      _cache = cache; // ignore: prefer_initializing_formals

  final MailApi _api;
  final MailCache _cache;
  final _events = StreamController<MailEvent>.broadcast();

  Stream<MailEvent> get events => _events.stream;
  MailCache get cache => _cache;

  void dispose() => _events.close();

  // ---- summary / folders --------------------------------------------------

  Future<MailSummary?> cachedSummary() => _cache.readSummary();

  Future<MailSummary> fetchSummary() async {
    final summary = await _api.summary();
    await _cache.writeSummary(summary);
    return summary;
  }

  // ---- lists ----------------------------------------------------------------

  /// First page from cache (unfiltered folders only) for instant start.
  Future<MailListResult?> cachedFirstPage(MailListQuery query) async {
    if (query.hasFilters || query.offset != 0 || query.threads) return null;
    final cached = await _cache.readList(query.folder);
    if (cached == null) return null;
    return MailListResult(
      items: cached.items,
      total: cached.total,
      nextOffset: cached.items.length < cached.total
          ? cached.items.length
          : null,
      fromCache: true,
    );
  }

  Future<MailListResult> fetchPage(
    MailListQuery query, {
    CancelToken? cancelToken,
  }) async {
    final page = await _api.listMessages(query, cancelToken: cancelToken);
    if (!query.hasFilters && query.offset == 0 && !query.threads) {
      await _cache.writeList(query.folder, page.messages, total: page.total);
    }
    return MailListResult(
      items: page.messages,
      total: page.total,
      nextOffset: page.computeNextOffset(),
      fromCache: false,
    );
  }

  /// [query]'s search text over the cached rows (no network), with its
  /// read / star / attachment filters.
  Future<List<MailListItem>> searchCached(MailListQuery query) => _cache.search(
    query.folder,
    query.q ?? '',
    unread: query.unread,
    starred: query.starred,
    attachments: query.attachments,
  );

  // ---- detail ---------------------------------------------------------------

  /// Network first (the server marks the message read as a side effect);
  /// falls back to the cached copy when offline.
  Future<MailDetailResult> getMessage(
    String id, {
    CancelToken? cancelToken,
  }) async {
    try {
      final detail = await _api.getMessage(id, cancelToken: cancelToken);
      await _cache.writeMessage(detail);
      if (detail.isRead) {
        await _cache.patchListItem(id, isRead: true);
        _events.add(MailFlagsChanged(id, isRead: true));
        _events.add(const MailSummaryStale());
      }
      return MailDetailResult(detail: detail, fromCache: false);
    } on NetworkException {
      final cached = await _cache.readMessage(id);
      if (cached != null) {
        return MailDetailResult(detail: cached, fromCache: true);
      }
      rethrow;
    }
  }

  // ---- mutations ------------------------------------------------------------

  Future<void> setRead(String id, bool isRead) async {
    await _api.patchMessage(id, isRead: isRead);
    await _cache.patchListItem(id, isRead: isRead);
    await _cache.patchMessage(id, isRead: isRead);
    _events.add(MailFlagsChanged(id, isRead: isRead));
    _events.add(const MailSummaryStale());
  }

  Future<void> setStarred(String id, bool isStarred) async {
    await _api.patchMessage(id, isStarred: isStarred);
    await _cache.patchListItem(id, isStarred: isStarred);
    await _cache.patchMessage(id, isStarred: isStarred);
    _events.add(MailFlagsChanged(id, isStarred: isStarred));
    _events.add(const MailSummaryStale());
  }

  Future<void> moveTo(String id, String folder) async {
    await _api.patchMessage(id, folder: folder);
    await _cache.removeListItem(id);
    await _cache.patchMessage(id, folder: folder);
    _events.add(MailMessageRemoved(id, movedTo: folder));
    _events.add(const MailSummaryStale());
  }

  /// Trash, or destroy if already in Trash/Drafts (server decides).
  Future<void> delete(String id, {required bool permanent}) async {
    await _api.deleteMessage(id);
    await _cache.removeListItem(id);
    if (permanent) {
      await _cache.removeMessage(id);
    } else {
      await _cache.patchMessage(id, folder: MailFolderType.trash);
    }
    _events.add(
      MailMessageRemoved(id, movedTo: permanent ? null : MailFolderType.trash),
    );
    _events.add(const MailSummaryStale());
  }

  Future<String> report(String id, MailReportKind kind) async {
    final folder = await _api.reportMessage(id, kind);
    await _cache.removeListItem(id);
    await _cache.patchMessage(id, folder: folder);
    _events.add(MailMessageRemoved(id, movedTo: folder));
    _events.add(const MailSummaryStale());
    return folder;
  }

  Future<String> send(
    MailSendRequest request, {
    String? draftIdToDelete,
  }) async {
    final id = await _api.send(request);
    if (draftIdToDelete != null) {
      // Recommended by the spec: send the full form, then drop the draft copy.
      try {
        await _api.deleteMessage(draftIdToDelete);
        await _cache.removeListItem(draftIdToDelete);
        await _cache.removeMessage(draftIdToDelete);
        _events.add(MailMessageRemoved(draftIdToDelete));
      } on AppException catch (e) {
        DiagnosticLog.warn('mail', 'draft cleanup after send failed', error: e);
      }
    }
    _events.add(const MailSummaryStale());
    return id;
  }

  /// Creates or replaces a draft; returns the id to use from now on.
  Future<String> saveDraft(
    MailDraftRequest request, {
    String? existingId,
  }) async {
    final String id;
    if (existingId == null) {
      id = await _api.createDraft(request);
    } else {
      id = await _api.updateDraft(existingId, request);
      if (id != existingId) {
        await _cache.removeListItem(existingId);
        await _cache.removeMessage(existingId);
        _events.add(MailMessageRemoved(existingId));
      }
    }
    _events.add(const MailSummaryStale());
    return id;
  }

  Future<void> clearCache() => _cache.clear();
  Future<MailCacheStats> cacheStats() => _cache.stats();
}
