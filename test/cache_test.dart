import 'dart:convert';
import 'dart:io';

import 'package:flint_dart/cache.dart';
import 'package:test/test.dart';

void main() {
  group('CacheDriver', () {
    test('parses supported driver names case-insensitively', () {
      expect(CacheDriver.parse('memory'), CacheDriver.memory);
      expect(CacheDriver.parse(' FILE '), CacheDriver.file);
      expect(CacheDriver.parse('Redis'), CacheDriver.redis);
    });

    test('rejects unsupported driver names', () {
      expect(() => CacheDriver.parse('database'), throwsFormatException);
    });
  });

  group('MemoryCacheStore', () {
    test('remember reuses cached values until the key is removed', () async {
      final cache = MemoryCacheStore();
      var calls = 0;

      Future<int> load() async => ++calls;

      expect(
          await cache.remember('answer', const Duration(minutes: 1), load), 1);
      expect(
          await cache.remember('answer', const Duration(minutes: 1), load), 1);
      expect(calls, 1);

      await cache.remove('answer');
      expect(
          await cache.remember('answer', const Duration(minutes: 1), load), 2);
    });

    test('removeMany and removeWhere clear matching keys', () async {
      final cache = MemoryCacheStore();

      await cache.set('products.all', 1);
      await cache.set('products.vps', 2);
      await cache.set('blogs.index', 3);

      await cache.removeMany(['products.all']);
      expect(await cache.get('products.all'), isNull);
      expect(await cache.get('products.vps'), 2);

      await cache.removeWhere((key) => key.startsWith('products.'));
      expect(await cache.get('products.vps'), isNull);
      expect(await cache.get('blogs.index'), 3);
    });
  });

  group('FileCacheStore', () {
    test('removeWhere clears matching files by cache key', () async {
      final dir = await Directory.systemTemp.createTemp('flint_cache_test_');
      try {
        final cache = FileCacheStore(directory: dir.path);

        await cache.set('products.all', 1);
        await cache.set('products.vps', 2);
        await cache.set('blogs.index', 3);

        await cache.removeWhere((key) => key.startsWith('products.'));

        expect(await cache.get('products.all'), isNull);
        expect(await cache.get('products.vps'), isNull);
        expect(await cache.get('blogs.index'), 3);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  group('RedisCacheStore', () {
    test('connectFromUrl applies credentials and database selection', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final transcript = StringBuffer();

      server.listen((socket) {
        socket.listen((bytes) {
          final request = utf8.decode(bytes);
          transcript.write(request);
          final commandCount = RegExp(r'\*\d+\r\n').allMatches(request).length;
          for (var index = 0; index < commandCount; index++) {
            socket.write('+OK\r\n');
          }
        });
      });

      try {
        final cache = await RedisCacheStore.connectFromUrl(
          'redis://default:p%40ss@127.0.0.1:${server.port}/2',
        );
        await cache.close();

        expect(transcript.toString(), contains('AUTH'));
        expect(transcript.toString(), contains('default'));
        expect(transcript.toString(), contains('p@ss'));
        expect(transcript.toString(), contains('SELECT'));
        expect(transcript.toString(), contains(r'$1' '\r\n2\r\n'));
      } finally {
        await server.close();
      }
    });

    test('connectFromUrl rejects invalid Redis URLs before connecting', () {
      expect(
        () => RedisCacheStore.connectFromUrl('http://localhost:6379'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => RedisCacheStore.connectFromUrl('redis://localhost/not-a-db'),
        throwsA(isA<FormatException>()),
      );
    });

    test('stores JSON values with native Redis ttl', () async {
      final redis = _FakeRedis();
      final cache = RedisCacheStore.withSender(redis.send, prefix: 'cache:');

      await cache.set(
        'settings',
        {'enabled': true},
        ttl: const Duration(seconds: 2),
      );

      expect(redis.commands.first, [
        'SET',
        'cache:settings',
        '{"enabled":true}',
        'PX',
        2000,
      ]);
      expect(await cache.get('settings'), {'enabled': true});

      redis.advance(const Duration(milliseconds: 2001));
      expect(await cache.get('settings'), isNull);
    });

    test('removeMany and removeWhere delete logical keys by prefix', () async {
      final redis = _FakeRedis();
      final cache = RedisCacheStore.withSender(redis.send, prefix: 'cache:');
      final other = RedisCacheStore.withSender(redis.send, prefix: 'other:');

      await cache.set('products.all', 1);
      await cache.set('products.vps', 2);
      await cache.set('blogs.index', 3);
      await other.set('products.all', 4);

      await cache.removeMany(['products.all']);
      expect(await cache.get('products.all'), isNull);
      expect(await cache.get('products.vps'), 2);

      await cache.removeWhere((key) => key.startsWith('products.'));
      expect(await cache.get('products.vps'), isNull);
      expect(await cache.get('blogs.index'), 3);
      expect(await other.get('products.all'), 4);
    });

    test('clear only deletes keys owned by the configured prefix', () async {
      final redis = _FakeRedis();
      final cache = RedisCacheStore.withSender(redis.send, prefix: 'cache:');
      final other = RedisCacheStore.withSender(redis.send, prefix: 'other:');

      await cache.set('blogs.index', 1);
      await other.set('blogs.index', 2);

      await cache.clear();

      expect(await cache.get('blogs.index'), isNull);
      expect(await other.get('blogs.index'), 2);
    });
  });
}

class _FakeRedis {
  final commands = <List<Object>>[];
  final _values = <String, String>{};
  final _expiresAt = <String, DateTime>{};

  DateTime now = DateTime(2026);

  Future<dynamic> send(List<Object> command) async {
    commands.add(List<Object>.from(command));

    switch (command.first.toString().toUpperCase()) {
      case 'SET':
        final key = command[1].toString();
        _values[key] = command[2].toString();
        final pxIndex = _indexOfOption(command, 'PX');
        if (pxIndex == -1) {
          _expiresAt.remove(key);
        } else {
          _expiresAt[key] = now.add(
            Duration(milliseconds: int.parse(command[pxIndex + 1].toString())),
          );
        }
        return 'OK';
      case 'GET':
        final key = command[1].toString();
        _expireKey(key);
        return _values[key];
      case 'DEL':
        var removed = 0;
        for (final rawKey in command.skip(1)) {
          final key = rawKey.toString();
          if (_values.remove(key) != null) removed++;
          _expiresAt.remove(key);
        }
        return removed;
      case 'SCAN':
        final matchIndex = _indexOfOption(command, 'MATCH');
        final pattern =
            matchIndex == -1 ? '*' : command[matchIndex + 1].toString();
        final keys = _values.keys.where((key) {
          _expireKey(key);
          return _matchesGlob(pattern, key);
        }).toList(growable: false);
        return ['0', keys];
    }

    throw UnsupportedError('Unsupported Redis command: ${command.first}');
  }

  void advance(Duration duration) {
    now = now.add(duration);
  }

  void _expireKey(String key) {
    final expiresAt = _expiresAt[key];
    if (expiresAt == null || expiresAt.isAfter(now)) return;

    _values.remove(key);
    _expiresAt.remove(key);
  }

  int _indexOfOption(List<Object> command, String option) {
    return command.indexWhere(
      (item) => item.toString().toUpperCase() == option,
    );
  }

  bool _matchesGlob(String pattern, String key) {
    if (pattern == '*') return true;

    if (pattern.endsWith('*')) {
      final prefix = pattern.substring(0, pattern.length - 1);
      return key.startsWith(prefix.replaceAll('\\', ''));
    }

    return key == pattern.replaceAll('\\', '');
  }
}
