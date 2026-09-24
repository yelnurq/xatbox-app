import 'package:sembast/sembast.dart';

import '../../../core/storage/app_database.dart';
import '../../../core/storage/cache_policy.dart';
import 'mail_models.dart';

/// Local mail cache (ТЗ п.24.16): folder summary, the first page of each
/// folder and a bounded LRU of opened messages. Never the whole mailbox and
/// never attachment bytes.
class MailCache {
  MailCache(this._db, {this.policy = const CachePolicy()});

  final AppDatabase _db;

  /// Current limits; updated from Settings.
  CachePolicy policy;

  static final _summaryStore = stringMapStoreFactory.store('mail_summary');
  static final _listStore = stringMapStoreFactory.store('mail_lists');
  static final _messageStore = stringMapStoreFactory.store('mail_messages');

  // ---- summary -----------------------------------------------------------

  Future<MailSummary?> readSummary() async {
    final json = await _summaryStore.record('summary').get(_db.db);
    if (json == null) return null;
    return MailSummary.fromJson(Map<String, dynamic>.from(json));
  }

  Future<void> writeSummary(MailSummary summary) =>
      _summaryStore.record('summary').put(_db.db, {
        ...summary.toJson(),
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      });

  // ---- first page per folder ---------------------------------------------

  Future<CachedList?> readList(String folder) async {
    final json = await _listStore.record(folder).get(_db.db);
    if (json == null) return null;
    final cachedAt = DateTime.tryParse((json['cached_at'] as String?) ?? '');
    if (cachedAt != null &&
        DateTime.now().toUtc().difference(cachedAt) > policy.maxAge) {
      await _listStore.record(folder).delete(_db.db);
      return null;
    }
    return CachedList(
      items: ((json['items'] as List?) ?? const [])
          .map(
            (e) => MailListItem.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      cachedAt: cachedAt,
    );
  }

  Future<void> writeList(
    String folder,
    List<MailListItem> items, {
    required int total,
  }) => _listStore.record(folder).put(_db.db, {
    'items': items
        .take(policy.maxListItemsPerFolder)
        .map((i) => i.toJson())
        .toList(),
    'total': total,
    'cached_at': DateTime.now().toUtc().toIso8601String(),
  });

  /// Applies a local flag change to every cached list row with [id].
  Future<void> patchListItem(String id, {bool? isRead, bool? isStarred}) async {
    await _db.db.transaction((txn) async {
      final records = await _listStore.find(txn);
      for (final rec in records) {
        final items = ((rec.value['items'] as List?) ?? const []);
        var changed = false;
        final updated = items.map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          if (map['id'] == id) {
            if (isRead != null) map['is_read'] = isRead;
            if (isStarred != null) map['is_starred'] = isStarred;
            changed = true;
          }
          return map;
        }).toList();
        if (changed) {
          await _listStore.record(rec.key).put(txn, {
            ...rec.value,
            'items': updated,
          });
        }
      }
    });
  }

  Future<void> removeListItem(String id) async {
    await _db.db.transaction((txn) async {
      final records = await _listStore.find(txn);
      for (final rec in records) {
        final items = ((rec.value['items'] as List?) ?? const []);
        final kept = items.where((e) => (e as Map)['id'] != id).toList();
        if (kept.length != items.length) {
          final total = ((rec.value['total'] as num?)?.toInt() ?? 1) - 1;
          await _listStore.record(rec.key).put(txn, {
            ...rec.value,
            'items': kept,
            'total': total < 0 ? 0 : total,
          });
        }
      }
    });
  }

  // ---- opened messages (LRU) ---------------------------------------------

  Future<MailMessageDetail?> readMessage(String id) async {
    final json = await _messageStore.record(id).get(_db.db);
    if (json == null) return null;
    final detail = MailMessageDetail.fromJson(
      Map<String, dynamic>.from(json['detail'] as Map),
    );
    // Touch for LRU.
    await _messageStore.record(id).update(_db.db, {
      'opened_at': DateTime.now().toUtc().toIso8601String(),
    });
    return detail;
  }

  Future<void> writeMessage(MailMessageDetail detail) async {
    await _messageStore.record(detail.id).put(_db.db, {
      'detail': detail.toJson(),
      'opened_at': DateTime.now().toUtc().toIso8601String(),
    });
    await trimMessages();
  }

  Future<void> patchMessage(
    String id, {
    bool? isRead,
    bool? isStarred,
    String? folder,
  }) async {
    final rec = await _messageStore.record(id).get(_db.db);
    if (rec == null) return;
    final detail = Map<String, dynamic>.from(rec['detail'] as Map);
    if (isRead != null) detail['is_read'] = isRead;
    if (isStarred != null) detail['is_starred'] = isStarred;
    if (folder != null) detail['folder'] = folder;
    await _messageStore.record(id).put(_db.db, {...rec, 'detail': detail});
  }

  Future<void> removeMessage(String id) =>
      _messageStore.record(id).delete(_db.db);

  /// Enforces [CachePolicy.maxCachedMessages] and [CachePolicy.maxAge].
  Future<void> trimMessages() async {
    final records = await _messageStore.find(
      _db.db,
      finder: Finder(sortOrders: [SortOrder('opened_at', false)]),
    );
    final now = DateTime.now().toUtc();
    for (var i = 0; i < records.length; i++) {
      final rec = records[i];
      final openedAt = DateTime.tryParse(
        (rec.value['opened_at'] as String?) ?? '',
      );
      final tooOld =
          openedAt != null && now.difference(openedAt) > policy.maxAge;
      if (i >= policy.maxCachedMessages || tooOld) {
        await _messageStore.record(rec.key).delete(_db.db);
      }
    }
  }

  // ---- offline search -----------------------------------------------------

  /// Cached rows of [folder] (the first page and opened messages; every
  /// cached list for a smart folder) whose subject, sender or text contains
  /// [q], case-insensitively; newest first. Offline search on desktop.
  Future<List<MailListItem>> search(
    String folder,
    String q, {
    bool unread = false,
    bool starred = false,
    bool attachments = false,
  }) async {
    final ql = q.trim().toLowerCase();
    if (ql.isEmpty) return const [];
    final all = MailFolderType.isSmart(folder);
    final seen = <String>{};
    final hits = <MailListItem>[];
    void add(MailListItem m, String text) {
      if (unread && m.isRead) return;
      if (starred && !m.isStarred) return;
      if (attachments && !m.hasAttachments) return;
      final match =
          m.subject.toLowerCase().contains(ql) ||
          m.fromDisplay.toLowerCase().contains(ql) ||
          m.from.toLowerCase().contains(ql) ||
          text.toLowerCase().contains(ql);
      if (match && seen.add(m.id)) hits.add(m);
    }

    for (final rec in await _listStore.find(_db.db)) {
      if (!all && rec.key != folder) continue;
      for (final e in (rec.value['items'] as List?) ?? const []) {
        final m = MailListItem.fromJson(Map<String, dynamic>.from(e as Map));
        add(m, m.snippet);
      }
    }
    for (final rec in await _messageStore.find(_db.db)) {
      final json = Map<String, dynamic>.from(rec.value['detail'] as Map);
      if (!all && json['folder'] != folder) continue;
      final d = MailMessageDetail.fromJson(json);
      final text = d.bodyText.replaceAll(RegExp(r'\s+'), ' ').trim();
      add(
        MailListItem(
          id: d.id,
          messageId: d.messageId,
          from: d.from,
          fromDisplay: d.fromDisplay,
          folderType: d.folder,
          subject: d.subject,
          snippet: text.length > 160 ? text.substring(0, 160) : text,
          rawDate: (json['date'] as String?) ?? '',
          date: d.date,
          isRead: d.isRead,
          isStarred: d.isStarred,
          hasAttachments: d.hasAttachments,
        ),
        text,
      );
    }
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    hits.sort((a, b) => (b.date ?? epoch).compareTo(a.date ?? epoch));
    return hits;
  }

  // ---- maintenance --------------------------------------------------------

  Future<MailCacheStats> stats() async => MailCacheStats(
    cachedMessages: await _messageStore.count(_db.db),
    cachedLists: await _listStore.count(_db.db),
  );

  /// Wipes everything. Called on sign-out and from Settings.
  Future<void> clear() async {
    await _summaryStore.delete(_db.db);
    await _listStore.delete(_db.db);
    await _messageStore.delete(_db.db);
  }
}

class CachedList {
  const CachedList({required this.items, required this.total, this.cachedAt});
  final List<MailListItem> items;
  final int total;
  final DateTime? cachedAt;
}

class MailCacheStats {
  const MailCacheStats({
    required this.cachedMessages,
    required this.cachedLists,
  });
  final int cachedMessages;
  final int cachedLists;
}
