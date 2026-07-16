import 'dart:io';

import 'package:flint_dart/cache.dart';
import 'package:test/test.dart';

void main() {
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
}
