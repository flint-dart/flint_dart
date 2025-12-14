import 'dart:io';
import 'dart:convert';
import 'package:flint_dart/src/cache/cache_manager.dart';
import 'package:path/path.dart' as path;

class FileCacheStore implements CacheStore {
  final String cacheDir;

  FileCacheStore({String? directory})
      : cacheDir = directory ?? path.join(Directory.current.path, 'cache') {
    Directory(cacheDir).createSync(recursive: true);
  }

  String _filePath(String key) =>
      path.join(cacheDir, '${Uri.encodeComponent(key)}.json');

  @override
  Future<void> set(String key, dynamic value, {Duration? ttl}) async {
    final file = File(_filePath(key));
    final data = {
      'value': value,
      'expires': ttl != null ? DateTime.now().add(ttl).toIso8601String() : null,
    };
    await file.writeAsString(jsonEncode(data));
  }

  @override
  Future<dynamic> get(String key) async {
    final file = File(_filePath(key));
    if (!(await file.exists())) return null;

    final data = jsonDecode(await file.readAsString());
    final expires =
        data['expires'] != null ? DateTime.parse(data['expires']) : null;
    if (expires != null && expires.isBefore(DateTime.now())) {
      await file.delete(); // Remove expired
      return null;
    }
    return data['value'];
  }

  @override
  Future<void> remove(String key) async {
    final file = File(_filePath(key));
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> clear() async {
    final dir = Directory(cacheDir);
    if (await dir.exists()) {
      for (var file in dir.listSync()) {
        if (file is File) await file.delete();
      }
    }
  }
}
