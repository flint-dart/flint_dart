abstract class CacheStore {
  Future<void> set(String key, dynamic value, {Duration? ttl});
  Future<dynamic> get(String key);
  Future<void> remove(String key);
  Future<void> removeMany(Iterable<String> keys);
  Future<void> removeWhere(bool Function(String key) shouldRemove);
  Future<void> clear();

  Future<T> remember<T>(
    String key,
    Duration ttl,
    Future<T> Function() loader,
  ) async {
    final cached = await get(key);
    if (cached != null) return cached as T;

    final value = await loader();
    await set(key, value, ttl: ttl);
    return value;
  }
}

class MemoryCacheStore implements CacheStore {
  final _cache = <String, Map<String, dynamic>>{};
  final int maxSize;

  MemoryCacheStore({this.maxSize = 100});

  @override
  Future<T> remember<T>(
    String key,
    Duration ttl,
    Future<T> Function() loader,
  ) async {
    final cached = await get(key);
    if (cached != null) return cached as T;

    final value = await loader();
    await set(key, value, ttl: ttl);
    return value;
  }

  @override
  Future<void> set(String key, dynamic value, {Duration? ttl}) async {
    if (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = {
      'value': value,
      'expires': ttl != null ? DateTime.now().add(ttl) : null
    };
  }

  @override
  Future<dynamic> get(String key) async {
    final data = _cache[key];
    if (data == null) return null;
    final expires = data['expires'] as DateTime?;
    if (expires != null && expires.isBefore(DateTime.now())) {
      _cache.remove(key);
      return null;
    }
    return data['value'];
  }

  @override
  Future<void> remove(String key) async => _cache.remove(key);

  @override
  Future<void> removeMany(Iterable<String> keys) async {
    for (final key in keys) {
      _cache.remove(key);
    }
  }

  @override
  Future<void> removeWhere(bool Function(String key) shouldRemove) async {
    final keys = _cache.keys.where(shouldRemove).toList();
    await removeMany(keys);
  }

  @override
  Future<void> clear() async => _cache.clear();
}

// class RedisCacheStore implements CacheStore {
//   final Commands<String, String> _commands;

//   RedisCacheStore(this._commands);

//   @override
//   Future<void> set(String key, dynamic value, {Duration? ttl}) async {
//     final jsonValue = jsonEncode(value);
//     if (ttl != null) {
//       await _commands.setex(key, ttl.inSeconds, jsonValue);
//     } else {
//       await _commands.set(key, jsonValue);
//     }
//   }

//   @override
//   Future<dynamic> get(String key) async {
//     final result = await _commands.get(key);
//     if (result == null) return null;
//     return jsonDecode(result);
//   }

//   @override
//   Future<void> remove(String key) async => await _commands.del([key]);
//   @override
//   Future<void> clear() async {
//     // Optional: flush all keys (careful in shared Redis)
//     await _commands.flushdb();
//   }
// }
