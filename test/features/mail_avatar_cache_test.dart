import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/api/api_client.dart';
import 'package:xatbox_mobile/shared/widgets/avatar_cache.dart';

/// Minimal avatar endpoint: bytes + headers, request log, optional gate.
class _AvatarServer implements HttpClientAdapter {
  _AvatarServer(this.handler);

  ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];
  Completer<void>? gate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (gate != null) await gate!.future;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

final _png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);

ResponseBody _photo({String etag = '"v1"', String? cacheControl}) =>
    ResponseBody.fromBytes(
      _png,
      200,
      headers: {
        'content-type': ['image/png'],
        'etag': [etag],
        'cache-control': [cacheControl ?? 'private, max-age=300'],
      },
    );

ResponseBody _notModified() => ResponseBody.fromBytes(
  const [],
  304,
  headers: {
    'etag': ['"v1"'],
    'cache-control': ['private, max-age=300'],
  },
);

ResponseBody _noPhoto({bool cacheHeader = true}) => ResponseBody.fromString(
  '404 page not found',
  404,
  headers: {
    'content-type': ['text/plain; charset=utf-8'],
    if (cacheHeader) 'cache-control': ['private, max-age=600'],
  },
);

void main() {
  late _AvatarServer server;
  late DateTime now;
  late MemoryAvatarDiskStore disk;

  AvatarCache cache() => AvatarCache(
    client: ApiClient(
      baseUrl: 'http://test.local/api/v1',
      userAgent: 'test',
      adapter: server,
      tokenReader: () => 'tok',
      onUnauthenticated: () {},
    ),
    disk: disk,
    clock: () => now,
  );

  setUp(() {
    now = DateTime.utc(2026, 9, 15, 12);
    disk = MemoryAvatarDiskStore();
    server = _AvatarServer((_) => _photo());
  });

  test('200 is cached for max-age, then revalidated with If-None-Match → 304', () async {
    final c = cache();
    expect(await c.photo(' Sender@Example.KZ '), _png);
    final first = server.requests.single;
    expect(first.path, '/avatars/by-email');
    expect(first.queryParameters, {'email': 'sender@example.kz'});
    expect(first.headers['Authorization'], 'Bearer tok');
    expect(first.headers.containsKey('If-None-Match'), isFalse);

    now = now.add(const Duration(seconds: 299));
    expect(await c.photo('sender@example.kz'), _png);
    expect(server.requests, hasLength(1), reason: 'fresh in memory');

    now = now.add(const Duration(seconds: 2));
    server.handler = (_) => _notModified();
    expect(await c.photo('sender@example.kz'), _png, reason: '304 keeps bytes');
    expect(server.requests, hasLength(2));
    expect(server.requests.last.headers['If-None-Match'], '"v1"');

    now = now.add(const Duration(seconds: 200));
    expect(await c.photo('sender@example.kz'), _png);
    expect(server.requests, hasLength(2), reason: '304 renewed max-age');
  });

  test('plain-text 404 is cached as "no photo" for its max-age, on disk too', () async {
    server.handler = (_) => _noPhoto();
    final c = cache();
    expect(await c.photo('nobody@example.kz'), isNull);
    expect(await c.photo('nobody@example.kz'), isNull);
    expect(server.requests, hasLength(1));
    expect(disk.length, 1);
    expect((await disk.read('nobody@example.kz'))!.hasPhoto, isFalse);

    // A new process (fresh memory) still trusts the negative answer.
    final restarted = cache();
    now = now.add(const Duration(seconds: 599));
    expect(await restarted.photo('nobody@example.kz'), isNull);
    expect(server.requests, hasLength(1));

    now = now.add(const Duration(seconds: 2));
    server.handler = (_) => _photo();
    expect(await restarted.photo('nobody@example.kz'), _png);
    expect(server.requests, hasLength(2));
    expect(
      server.requests.last.headers.containsKey('If-None-Match'),
      isFalse,
      reason: 'a negative entry has no ETag to revalidate',
    );
  });

  test('404 without Cache-Control is remembered only briefly, in memory', () async {
    server.handler = (_) => _noPhoto(cacheHeader: false);
    final c = cache();
    expect(await c.photo('x@example.kz'), isNull);
    expect(disk.length, 0);
    now = now.add(AvatarCache.unmarkedMissTtl - const Duration(seconds: 1));
    await c.photo('x@example.kz');
    expect(server.requests, hasLength(1));
    now = now.add(const Duration(seconds: 2));
    await c.photo('x@example.kz');
    expect(server.requests, hasLength(2));
  });

  test('concurrent lookups of one address share a single request', () async {
    server.gate = Completer<void>();
    final c = cache();
    final results = Future.wait([
      c.photo('a@example.kz'),
      c.photo('A@example.kz'),
      c.photo(' a@example.kz'),
    ]);
    await Future<void>.delayed(Duration.zero);
    server.gate!.complete();
    expect(await results, [_png, _png, _png]);
    expect(server.requests, hasLength(1));
  });

  test('offline keeps the stale photo; malformed addresses are not looked up', () async {
    final c = cache();
    await c.photo('a@example.kz');
    now = now.add(const Duration(hours: 1));
    server.handler = (_) => throw const SocketException('offline');
    expect(await c.photo('a@example.kz'), _png);

    final before = server.requests.length;
    expect(await c.photo(''), isNull);
    expect(await c.photo('not-an-email'), isNull);
    expect(server.requests.length, before);
  });

  test('clear() forgets memory and disk', () async {
    final c = cache();
    await c.photo('a@example.kz');
    await c.clear();
    expect(disk.length, 0);
    expect(c.peek('a@example.kz'), isNull);
  });

  test('Cache-Control parsing', () {
    expect(AvatarCache.maxAge('private, max-age=300'), const Duration(seconds: 300));
    expect(AvatarCache.maxAge('MAX-AGE = 600'), const Duration(seconds: 600));
    expect(AvatarCache.maxAge('no-store'), Duration.zero);
    expect(AvatarCache.maxAge('private'), isNull);
    expect(AvatarCache.maxAge(null), isNull);
  });

  group('FileAvatarDiskStore', () {
    late Directory tmp;
    setUp(() async => tmp = await Directory.systemTemp.createTemp('avatars'));
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    AvatarEntry entry(String email, {bool photo = true}) => AvatarEntry(
      email: email,
      bytes: photo ? _png : null,
      etag: photo ? '"e-$email"' : null,
      expiresAt: DateTime.utc(2026, 9, 15, 13),
    );

    test('round-trips photos and negatives; evicts the least recently used', () async {
      final store = FileAvatarDiskStore(
        baseDirectory: () async => tmp,
        maxEntries: 2,
        trimEvery: 1,
      );
      await store.write(entry('a@example.kz'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await store.write(entry('b@example.kz', photo: false));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final a = await store.read('a@example.kz');
      expect(a!.bytes, _png);
      expect(a.etag, '"e-a@example.kz"');
      expect(a.expiresAt, DateTime.utc(2026, 9, 15, 13));
      final b = await store.read('b@example.kz');
      expect(b!.hasPhoto, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      // Touch "a" so "b" becomes the least recently used.
      await File(
        '${tmp.path}/xatbox_avatars/${FileAvatarDiskStore.keyOf('a@example.kz')}.json',
      ).setLastModified(DateTime.now().add(const Duration(seconds: 5)));

      await store.write(entry('c@example.kz'));
      expect(await store.read('b@example.kz'), isNull, reason: 'evicted');
      expect(await store.read('a@example.kz'), isNotNull);
      expect(await store.read('c@example.kz'), isNotNull);

      final names = tmp
          .listSync(recursive: true)
          .map((f) => f.path.split(Platform.pathSeparator).last)
          .join(' ');
      expect(names, isNot(contains('@')), reason: 'no addresses in file names');

      await store.clear();
      expect(await store.read('a@example.kz'), isNull);
    });

    test('an unavailable directory disables the disk level silently', () async {
      final store = FileAvatarDiskStore(
        baseDirectory: () async => throw const FileSystemException('nope'),
      );
      await store.write(entry('a@example.kz'));
      expect(await store.read('a@example.kz'), isNull);
    });
  });
}
