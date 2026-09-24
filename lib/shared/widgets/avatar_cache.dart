import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_session.dart';
import '../utils/diagnostic_log.dart';

/// A cached answer of `GET /avatars/by-email`: photo bytes, or "no photo"
/// (a cached 404), valid until [expiresAt].
class AvatarEntry {
  const AvatarEntry({
    required this.email,
    required this.expiresAt,
    this.bytes,
    this.etag,
  });

  /// Normalized (trimmed, lowercased) address.
  final String email;
  final Uint8List? bytes;
  final String? etag;
  final DateTime expiresAt;

  bool get hasPhoto => bytes != null && bytes!.isNotEmpty;
  bool isFresh(DateTime now) => now.isBefore(expiresAt);

  AvatarEntry revalidated(DateTime expiresAt, {String? etag}) => AvatarEntry(
    email: email,
    bytes: bytes,
    etag: etag ?? this.etag,
    expiresAt: expiresAt,
  );
}

/// Persistent second level of the avatar cache.
abstract class AvatarDiskStore {
  Future<AvatarEntry?> read(String email);
  Future<void> write(AvatarEntry entry);
  Future<void> clear();
}

/// In-memory store (tests, platforms without a cache directory).
class MemoryAvatarDiskStore implements AvatarDiskStore {
  MemoryAvatarDiskStore({this.maxEntries = 200});
  final int maxEntries;
  /// Map literals keep insertion order: first key = least recently used.
  final _entries = <String, AvatarEntry>{};

  int get length => _entries.length;

  @override
  Future<AvatarEntry?> read(String email) async {
    final e = _entries.remove(email);
    if (e != null) _entries[email] = e;
    return e;
  }

  @override
  Future<void> write(AvatarEntry entry) async {
    _entries.remove(entry.email);
    _entries[entry.email] = entry;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  @override
  Future<void> clear() async => _entries.clear();
}

/// Small LRU on disk in the app cache directory: `<key>.json` (metadata) and
/// `<key>.img` (bytes). Recency is the metadata file's modification time;
/// the oldest entries are evicted beyond [maxEntries] / [maxBytes]. Every
/// failure only disables the disk level — avatars are never critical.
class FileAvatarDiskStore implements AvatarDiskStore {
  FileAvatarDiskStore({
    Future<Directory> Function()? baseDirectory,
    this.maxEntries = 300,
    this.maxBytes = 10 * 1024 * 1024,
    this.trimEvery = 20,
  }) : _baseDirectory = baseDirectory ?? getApplicationCacheDirectory;

  final Future<Directory> Function() _baseDirectory;
  final int maxEntries;
  final int maxBytes;

  /// Eviction runs on the first write and then every [trimEvery] writes.
  final int trimEvery;

  Future<Directory?>? _dir;
  int _writesSinceTrim = 0;

  static const _subdir = 'xatbox_avatars';

  Future<Directory?> _directory() => _dir ??= () async {
    try {
      final base = await _baseDirectory();
      final dir = Directory(p.join(base.path, _subdir));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } on Object catch (e) {
      DiagnosticLog.warn('avatar', 'disk cache unavailable', error: e);
      return null;
    }
  }();

  /// FNV-1a 64-bit of the address: file names never contain the address.
  static String keyOf(String email) {
    var hash = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.parse('100000001b3', radix: 16);
    final mask = (BigInt.one << 64) - BigInt.one;
    for (final b in utf8.encode(email)) {
      hash = ((hash ^ BigInt.from(b)) * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  @override
  Future<AvatarEntry?> read(String email) async {
    final dir = await _directory();
    if (dir == null) return null;
    try {
      final key = keyOf(email);
      final meta = File(p.join(dir.path, '$key.json'));
      if (!await meta.exists()) return null;
      final json = jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
      if (json['email'] != email) return null;
      final expires = DateTime.tryParse((json['expires_at'] as String?) ?? '');
      if (expires == null) return null;
      Uint8List? bytes;
      if (json['has_photo'] == true) {
        final img = File(p.join(dir.path, '$key.img'));
        if (!await img.exists()) return null;
        bytes = await img.readAsBytes();
      }
      unawaited(
        meta.setLastModified(DateTime.now()).catchError((Object _) {}),
      );
      return AvatarEntry(
        email: email,
        bytes: bytes,
        etag: json['etag'] as String?,
        expiresAt: expires,
      );
    } on Object catch (e) {
      DiagnosticLog.warn('avatar', 'disk cache read failed', error: e);
      return null;
    }
  }

  @override
  Future<void> write(AvatarEntry entry) async {
    final dir = await _directory();
    if (dir == null) return;
    try {
      final key = keyOf(entry.email);
      final img = File(p.join(dir.path, '$key.img'));
      if (entry.hasPhoto) {
        await img.writeAsBytes(entry.bytes!, flush: true);
      } else if (await img.exists()) {
        await img.delete();
      }
      await File(p.join(dir.path, '$key.json')).writeAsString(
        jsonEncode({
          'email': entry.email,
          'etag': entry.etag,
          'has_photo': entry.hasPhoto,
          'expires_at': entry.expiresAt.toUtc().toIso8601String(),
        }),
      );
      if (_writesSinceTrim++ % (trimEvery < 1 ? 1 : trimEvery) == 0) {
        await _trim(dir);
      }
    } on Object catch (e) {
      DiagnosticLog.warn('avatar', 'disk cache write failed', error: e);
    }
  }

  Future<void> _trim(Directory dir) async {
    final metas = <(File, DateTime, int)>[];
    var total = 0;
    await for (final f in dir.list()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      final stat = await f.stat();
      final img = File('${f.path.substring(0, f.path.length - 5)}.img');
      final imgSize = await img.exists() ? await img.length() : 0;
      total += stat.size + imgSize;
      metas.add((f, stat.modified, stat.size + imgSize));
    }
    if (metas.length <= maxEntries && total <= maxBytes) return;
    metas.sort((a, b) => a.$2.compareTo(b.$2));
    var count = metas.length;
    for (final (file, _, size) in metas) {
      if (count <= maxEntries && total <= maxBytes) break;
      final img = File('${file.path.substring(0, file.path.length - 5)}.img');
      if (await img.exists()) await img.delete();
      await file.delete();
      count--;
      total -= size;
    }
  }

  @override
  Future<void> clear() async {
    final dir = await _directory();
    if (dir == null) return;
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
      _dir = null;
    } on Object catch (e) {
      DiagnosticLog.warn('avatar', 'disk cache clear failed', error: e);
    }
  }
}

/// Sender photos by email (`GET /avatars/by-email`), for any module.
///
/// * memory LRU → disk LRU → network, each answer honouring `Cache-Control:
///   max-age`;
/// * stale photos are revalidated with `If-None-Match` (304 keeps the bytes);
/// * the plain-text 404 is cached as "no photo" for its `max-age` (600 s);
///   without the header it is remembered in memory only, briefly;
/// * concurrent requests for one address share a single HTTP call;
/// * failures (offline, 5xx) fall back to the stale entry or initials.
class AvatarCache {
  AvatarCache({
    required ApiClient client,
    AvatarDiskStore? disk,
    DateTime Function()? clock,
    this.memoryEntries = 200,
  }) : _client = client, // ignore: prefer_initializing_formals
       _disk = disk ?? MemoryAvatarDiskStore(),
       _clock = clock ?? DateTime.now;

  final ApiClient _client;
  final AvatarDiskStore _disk;
  final DateTime Function() _clock;
  final int memoryEntries;

  /// Insertion-ordered: the first key is the least recently used.
  final _memory = <String, AvatarEntry>{};
  final _inflight = <String, Future<AvatarEntry?>>{};

  static const defaultPhotoTtl = Duration(seconds: 300);
  static const unmarkedMissTtl = Duration(seconds: 60);

  static String normalize(String email) => email.trim().toLowerCase();

  static bool _lookupable(String email) {
    final at = email.indexOf('@');
    return at > 0 && at < email.length - 1;
  }

  /// `max-age` seconds from a `Cache-Control` header, if any.
  static Duration? maxAge(String? cacheControl) {
    if (cacheControl == null) return null;
    final lower = cacheControl.toLowerCase();
    if (lower.contains('no-store')) return Duration.zero;
    final m = RegExp(r'max-age\s*=\s*"?(\d+)').firstMatch(lower);
    return m == null ? null : Duration(seconds: int.parse(m.group(1)!));
  }

  /// Memory-only lookup for the first frame (may be stale).
  AvatarEntry? peek(String email) => _memory[normalize(email)];

  /// Photo bytes, or null when the user has no photo / it is unavailable.
  Future<Uint8List?> photo(String email) async {
    final entry = await resolve(email);
    return entry != null && entry.hasPhoto ? entry.bytes : null;
  }

  Future<AvatarEntry?> resolve(String email) {
    final key = normalize(email);
    if (!_lookupable(key)) return Future.value();
    final mem = _memory[key];
    if (mem != null && mem.isFresh(_clock())) {
      _remember(mem);
      return Future.value(mem);
    }
    final running = _inflight[key];
    if (running != null) return running;
    // Block body: returning the removed (same) future from whenComplete
    // would make the future wait for itself.
    final future = _load(key, mem).whenComplete(() {
      _inflight.remove(key);
    });
    _inflight[key] = future;
    return future;
  }

  Future<void> clear() async {
    _memory.clear();
    await _disk.clear();
  }

  void _remember(AvatarEntry entry) {
    _memory.remove(entry.email);
    _memory[entry.email] = entry;
    while (_memory.length > memoryEntries) {
      _memory.remove(_memory.keys.first);
    }
  }

  Future<AvatarEntry?> _load(String key, AvatarEntry? memory) async {
    var cached = memory;
    if (cached == null) {
      try {
        cached = await _disk.read(key);
      } on Object catch (e) {
        DiagnosticLog.warn('avatar', 'disk read failed', error: e);
      }
      if (cached != null) {
        _remember(cached);
        if (cached.isFresh(_clock())) return cached;
      }
    }

    final Response<List<int>> res;
    try {
      res = await _client.send(
        () => _client.dio.get<List<int>>(
          '/avatars/by-email',
          queryParameters: {'email': key},
          options: Options(
            responseType: ResponseType.bytes,
            headers: {
              'Accept': 'image/*',
              if (cached != null && cached.hasPhoto && cached.etag != null)
                'If-None-Match': cached.etag,
            },
          ),
        ),
        expectedStatuses: const {200, 304, 404},
      );
    } on AppException catch (e) {
      if (e is! NetworkException && e is! CancelledException) {
        DiagnosticLog.warn('avatar', 'avatar lookup failed', error: e);
      }
      return cached;
    }

    final now = _clock();
    final ttl = maxAge(res.headers.value('cache-control'));
    switch (res.statusCode) {
      case 200:
        final bytes = Uint8List.fromList(res.data ?? const []);
        final entry = AvatarEntry(
          email: key,
          bytes: bytes,
          etag: res.headers.value('etag'),
          expiresAt: now.add(ttl ?? defaultPhotoTtl),
        );
        return _store(entry, persist: true);
      case 304:
        if (cached == null || !cached.hasPhoto) return null;
        return _store(
          cached.revalidated(
            now.add(ttl ?? defaultPhotoTtl),
            etag: res.headers.value('etag'),
          ),
          persist: true,
        );
      default: // 404: "no photo", plain text
        final entry = AvatarEntry(
          email: key,
          expiresAt: now.add(ttl ?? unmarkedMissTtl),
        );
        return _store(entry, persist: ttl != null);
    }
  }

  Future<AvatarEntry> _store(AvatarEntry entry, {required bool persist}) async {
    _remember(entry);
    if (persist) {
      try {
        await _disk.write(entry);
      } on Object catch (e) {
        DiagnosticLog.warn('avatar', 'disk write failed', error: e);
      }
    }
    return entry;
  }
}

/// Disk level; override in tests.
final avatarDiskStoreProvider = Provider<AvatarDiskStore>(
  (_) => FileAvatarDiskStore(),
);

/// App-wide avatar cache; wiped when the user signs out.
final avatarCacheProvider = Provider<AvatarCache>((ref) {
  final cache = AvatarCache(
    client: ref.watch(apiClientProvider),
    disk: ref.watch(avatarDiskStoreProvider),
  );
  ref.listen<AuthState>(authStateProvider, (previous, next) {
    if (previous?.status == AuthStatus.authenticated &&
        next.status == AuthStatus.unauthenticated) {
      unawaited(cache.clear());
    }
  });
  return cache;
});

/// Desktop: the mark of the domain a sender writes from (Zoom, Fortinet…),
/// shown when they have no photo here, as in the web's message list. Read
/// through the web's `/api/sender-icon?domain=` on our own server, which
/// fetches and caches it, so the app never asks a third party about the
/// people who write to the user. 404 (no mark) is remembered as none.
class DomainLogoCache {
  DomainLogoCache({required String apiBaseUrl, Dio? dio, this.entries = 300})
    : _origin = Uri.tryParse(apiBaseUrl)?.origin ?? '',
      _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 15)));

  final String _origin;
  final Dio _dio;
  final int entries;
  final _known = <String, Future<Uint8List?>>{};

  static final _domainRe = RegExp(r'^[a-z0-9.-]+\.[a-z]{2,}$');

  /// The domain of [email], or null when it has none worth asking about.
  static String? domainOf(String email) {
    final at = email.lastIndexOf('@');
    if (at < 0) return null;
    final domain = email.substring(at + 1).trim().toLowerCase();
    return _domainRe.hasMatch(domain) ? domain : null;
  }

  /// The logo bytes for [email]'s domain, or null.
  Future<Uint8List?> logo(String email) {
    final domain = domainOf(email);
    if (domain == null || _origin.isEmpty) return Future.value();
    final known = _known.remove(domain);
    if (known != null) {
      _known[domain] = known;
      return known;
    }
    final future = _fetch(domain);
    _known[domain] = future;
    while (_known.length > entries) {
      _known.remove(_known.keys.first);
    }
    return future;
  }

  Future<Uint8List?> _fetch(String domain) async {
    try {
      final res = await _dio.get<List<int>>(
        '$_origin/api/sender-icon',
        queryParameters: {'domain': domain},
        options: Options(responseType: ResponseType.bytes, validateStatus: (s) => s != null && s < 500),
      );
      final data = res.data;
      if (res.statusCode != 200 || data == null || data.isEmpty) return null;
      return Uint8List.fromList(data);
    } on Object {
      // Offline or the server busy: try again later (not remembered).
      _known.remove(domain);
      return null;
    }
  }
}

final domainLogoCacheProvider = Provider<DomainLogoCache>(
  (ref) => DomainLogoCache(apiBaseUrl: ref.watch(appEnvProvider).apiBaseUrl),
);
