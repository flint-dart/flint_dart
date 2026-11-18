import 'dart:convert';

import 'package:flint_dart/src/cache/cache_manager.dart';
import 'package:redis/redis.dart';

typedef RedisCommandSender = Future<dynamic> Function(List<Object> command);

class RedisCacheStore implements CacheStore {
  final RedisCommandSender _send;
  final Command? _command;
  final String prefix;
  final int scanCount;
  final int deleteBatchSize;

  RedisCacheStore(
    Command command, {
    this.prefix = 'flint:cache:',
    this.scanCount = 1000,
    this.deleteBatchSize = 500,
  })  : _send = ((items) => command.send_object(items)),
        _command = command {
    _validateOptions();
  }

  RedisCacheStore.withSender(
    RedisCommandSender sender, {
    this.prefix = 'flint:cache:',
    this.scanCount = 1000,
    this.deleteBatchSize = 500,
  })  : _send = sender,
        _command = null {
    _validateOptions();
  }

  static Future<RedisCacheStore> connect({
    String host = 'localhost',
    int port = 6379,
    bool secure = false,
    String? username,
    String? password,
    int? database,
    String prefix = 'flint:cache:',
    int scanCount = 1000,
    int deleteBatchSize = 500,
  }) async {
    if (host.trim().isEmpty) {
      throw ArgumentError.value(host, 'host', 'Must not be empty.');
    }
    if (port <= 0) {
      throw ArgumentError.value(port, 'port', 'Must be greater than zero.');
    }
    if (database != null && database < 0) {
      throw ArgumentError.value(
        database,
        'database',
        'Must be zero or greater.',
      );
    }
    if (username != null && username.isNotEmpty && password == null) {
      throw ArgumentError('password is required when username is provided.');
    }

    final connection = RedisConnection();
    final command = secure
        ? await connection.connectSecure(host, port)
        : await connection.connect(host, port);

    try {
      if (password != null) {
        final authCommand = username == null || username.isEmpty
            ? <Object>['AUTH', password]
            : <Object>['AUTH', username, password];
        await command.send_object(authCommand);
      }

      if (database != null) {
        await command.send_object(<Object>['SELECT', database]);
      }

      return RedisCacheStore(
        command,
        prefix: prefix,
        scanCount: scanCount,
        deleteBatchSize: deleteBatchSize,
      );
    } catch (_) {
      try {
        await connection.close();
      } catch (_) {}
      rethrow;
    }
  }

  /// Connects to Redis using a `redis://` or `rediss://` URL.
  ///
  /// The URL may include a username, password, port, and database number:
  /// `redis://default:password@localhost:6379/0`.
  static Future<RedisCacheStore> connectFromUrl(
    String url, {
    String prefix = 'flint:cache:',
    int scanCount = 1000,
    int deleteBatchSize = 500,
  }) {
    final options = _RedisUrlOptions.parse(url);

    return connect(
      host: options.host,
      port: options.port,
      secure: options.secure,
      username: options.username,
      password: options.password,
      database: options.database,
      prefix: prefix,
      scanCount: scanCount,
      deleteBatchSize: deleteBatchSize,
    );
  }

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
    if (ttl != null && ttl <= Duration.zero) {
      await remove(key);
      return;
    }

    final redisKey = _redisKey(key);
    final encoded = jsonEncode(value);

    if (ttl == null) {
      await _send(<Object>['SET', redisKey, encoded]);
      return;
    }

    final milliseconds = ttl.inMilliseconds <= 0 ? 1 : ttl.inMilliseconds;
    await _send(<Object>['SET', redisKey, encoded, 'PX', milliseconds]);
  }

  @override
  Future<dynamic> get(String key) async {
    final result = await _send(<Object>['GET', _redisKey(key)]);
    if (result == null) return null;

    return jsonDecode(_redisValueAsString(result));
  }

  @override
  Future<void> remove(String key) async {
    await _send(<Object>['DEL', _redisKey(key)]);
  }

  @override
  Future<void> removeMany(Iterable<String> keys) async {
    await _removeNamespacedKeys(keys.map(_redisKey));
  }

  @override
  Future<void> removeWhere(bool Function(String key) shouldRemove) async {
    var cursor = '0';

    do {
      final page = await _scan(cursor);
      cursor = page.cursor;

      final keys = page.keys.where((key) {
        return shouldRemove(_logicalKey(key));
      });
      await _removeNamespacedKeys(keys);
    } while (cursor != '0');
  }

  @override
  Future<void> clear() async {
    await removeWhere((_) => true);
  }

  Future<void> close() async {
    await _command?.get_connection().close();
  }

  Future<_RedisScanPage> _scan(String cursor) async {
    final response = await _send(<Object>[
      'SCAN',
      cursor,
      'MATCH',
      _scanMatchPattern(),
      'COUNT',
      scanCount,
    ]);
    return _RedisScanPage.parse(response);
  }

  Future<void> _removeNamespacedKeys(Iterable<String> keys) async {
    final items = keys.toList(growable: false);
    if (items.isEmpty) return;

    for (var index = 0; index < items.length; index += deleteBatchSize) {
      final batch = items.skip(index).take(deleteBatchSize);
      await _send(<Object>['DEL', ...batch]);
    }
  }

  String _redisKey(String key) => prefix.isEmpty ? key : '$prefix$key';

  String _logicalKey(String redisKey) {
    if (prefix.isEmpty || !redisKey.startsWith(prefix)) return redisKey;
    return redisKey.substring(prefix.length);
  }

  String _scanMatchPattern() {
    if (prefix.isEmpty) return '*';
    return '${_escapeRedisGlob(prefix)}*';
  }

  void _validateOptions() {
    if (scanCount <= 0) {
      throw ArgumentError.value(
        scanCount,
        'scanCount',
        'Must be greater than zero.',
      );
    }
    if (deleteBatchSize <= 0) {
      throw ArgumentError.value(
        deleteBatchSize,
        'deleteBatchSize',
        'Must be greater than zero.',
      );
    }
  }
}

class _RedisUrlOptions {
  const _RedisUrlOptions({
    required this.host,
    required this.port,
    required this.secure,
    this.username,
    this.password,
    this.database,
  });

  final String host;
  final int port;
  final bool secure;
  final String? username;
  final String? password;
  final int? database;

  factory _RedisUrlOptions.parse(String value) {
    final url = value.trim();
    if (url.isEmpty) {
      throw const FormatException('Redis URL cannot be empty.');
    }

    final uri = Uri.parse(url);
    if (uri.scheme != 'redis' && uri.scheme != 'rediss') {
      throw FormatException(
        'Redis URL scheme must be redis:// or rediss://.',
        value,
      );
    }
    if (uri.host.isEmpty) {
      throw FormatException('Redis URL must include a host.', value);
    }

    String? username;
    String? password;
    if (uri.userInfo.isNotEmpty) {
      final separator = uri.userInfo.indexOf(':');
      if (separator == -1) {
        password = Uri.decodeComponent(uri.userInfo);
      } else {
        final rawUsername = uri.userInfo.substring(0, separator);
        username =
            rawUsername.isEmpty ? null : Uri.decodeComponent(rawUsername);
        password = Uri.decodeComponent(uri.userInfo.substring(separator + 1));
      }
    }

    int? database;
    if (uri.path.isNotEmpty && uri.path != '/') {
      final rawDatabase =
          uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
      if (rawDatabase.contains('/')) {
        throw FormatException(
          'Redis URL path must contain only a database number.',
          value,
        );
      }

      database = int.tryParse(Uri.decodeComponent(rawDatabase));
      if (database == null || database < 0) {
        throw FormatException(
          'Redis URL database must be zero or greater.',
          value,
        );
      }
    }

    return _RedisUrlOptions(
      host: uri.host,
      port: uri.port == 0 ? 6379 : uri.port,
      secure: uri.scheme == 'rediss',
      username: username,
      password: password,
      database: database,
    );
  }
}

class _RedisScanPage {
  final String cursor;
  final List<String> keys;

  _RedisScanPage(this.cursor, this.keys);

  factory _RedisScanPage.parse(dynamic response) {
    if (response is! List || response.length < 2 || response[1] is! List) {
      throw StateError('Unexpected Redis SCAN response: $response');
    }

    return _RedisScanPage(
      _redisValueAsString(response[0]),
      (response[1] as List).map(_redisValueAsString).toList(growable: false),
    );
  }
}

String _redisValueAsString(dynamic value) {
  if (value is String) return value;
  if (value is List<int>) return utf8.decode(value);
  return value.toString();
}

String _escapeRedisGlob(String value) {
  final buffer = StringBuffer();

  for (var index = 0; index < value.length; index++) {
    final char = value[index];
    if (char == '*' ||
        char == '?' ||
        char == '[' ||
        char == ']' ||
        char == r'\') {
      buffer.write(r'\');
    }
    buffer.write(char);
  }

  return buffer.toString();
}
