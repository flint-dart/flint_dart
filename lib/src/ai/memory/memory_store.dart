import 'dart:convert';

import 'package:flint_dart/db.dart';
import 'package:flint_dart/logs.dart';

/// Contract for AI run-event and thread-message memory storage.
abstract class AiMemoryStore {
  Future<void> appendRunEvent(
    String runId,
    Map<String, dynamic> event,
  );

  Future<List<Map<String, dynamic>>> loadRunEvents(String runId);

  Future<void> saveThreadMessage(
    String threadId,
    Map<String, dynamic> message,
  );

  Future<List<Map<String, dynamic>>> loadThreadMessages(String threadId);
}

/// In-memory implementation of [AiMemoryStore] for development and tests.
class InMemoryAiMemoryStore implements AiMemoryStore {
  final Map<String, List<Map<String, dynamic>>> _runEvents = {};
  final Map<String, List<Map<String, dynamic>>> _threadMessages = {};

  @override
  Future<void> appendRunEvent(
    String runId,
    Map<String, dynamic> event,
  ) async {
    _runEvents.putIfAbsent(runId, () => <Map<String, dynamic>>[]).add(event);
  }

  @override
  Future<List<Map<String, dynamic>>> loadRunEvents(String runId) async {
    return List<Map<String, dynamic>>.from(_runEvents[runId] ?? const []);
  }

  @override
  Future<List<Map<String, dynamic>>> loadThreadMessages(String threadId) async {
    return List<Map<String, dynamic>>.from(
      _threadMessages[threadId] ?? const [],
    );
  }

  @override
  Future<void> saveThreadMessage(
    String threadId,
    Map<String, dynamic> message,
  ) async {
    _threadMessages
        .putIfAbsent(threadId, () => <Map<String, dynamic>>[])
        .add(message);
  }
}

/// Database-backed implementation of [AiMemoryStore].
class DbAiMemoryStore implements AiMemoryStore {
  static const String _runEventsTable = 'ai_run_events';
  static const String _threadMessagesTable = 'ai_thread_messages';
  static bool _ensured = false;

  Future<void> _ensureTables() async {
    if (_ensured) return;
    final dbType = DB.driver;
    final idColumn = dbType == DBDriver.mysql
        ? 'id INT PRIMARY KEY AUTO_INCREMENT'
        : 'id SERIAL PRIMARY KEY';
    final textType = dbType == DBDriver.mysql ? 'VARCHAR(255)' : 'TEXT';
    final payloadType = dbType == DBDriver.mysql ? 'LONGTEXT' : 'TEXT';

    if (!await DB.tableExists(_runEventsTable)) {
      await DB.execute('''
        CREATE TABLE IF NOT EXISTS $_runEventsTable (
          $idColumn,
          run_id $textType NOT NULL,
          event_json $payloadType NOT NULL,
          created_at $textType NOT NULL
        )
      ''');
    }

    if (!await DB.tableExists(_threadMessagesTable)) {
      await DB.execute('''
        CREATE TABLE IF NOT EXISTS $_threadMessagesTable (
          $idColumn,
          thread_id $textType NOT NULL,
          message_json $payloadType NOT NULL,
          created_at $textType NOT NULL
        )
      ''');
    }

    _ensured = true;
  }

  @override
  Future<void> appendRunEvent(String runId, Map<String, dynamic> event) async {
    await _ensureTables();
    await DB.execute(
      'INSERT INTO $_runEventsTable (run_id, event_json, created_at) VALUES (?, ?, ?)',
      positionalParams: [
        runId,
        jsonEncode(event),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  @override
  Future<List<Map<String, dynamic>>> loadRunEvents(String runId) async {
    await _ensureTables();
    final rows = await DB.query(
      'SELECT event_json FROM $_runEventsTable WHERE run_id = ? ORDER BY id ASC',
      positionalParams: [runId],
    );
    return rows
        .map(
          (row) => Map<String, dynamic>.from(
            jsonDecode(row['event_json'].toString()) as Map,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> loadThreadMessages(String threadId) async {
    await _ensureTables();
    final rows = await DB.query(
      'SELECT message_json FROM $_threadMessagesTable WHERE thread_id = ? ORDER BY id ASC',
      positionalParams: [threadId],
    );
    return rows
        .map(
          (row) => Map<String, dynamic>.from(
            jsonDecode(row['message_json'].toString()) as Map,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveThreadMessage(
    String threadId,
    Map<String, dynamic> message,
  ) async {
    await _ensureTables();
    await DB.execute(
      'INSERT INTO $_threadMessagesTable (thread_id, message_json, created_at) VALUES (?, ?, ?)',
      positionalParams: [
        threadId,
        jsonEncode(message),
        DateTime.now().toIso8601String(),
      ],
    );
  }
}

/// Memory store that prefers the database and falls back to memory with warnings.
class AutoAiMemoryStore implements AiMemoryStore {
  final AiMemoryStore primary;
  final InMemoryAiMemoryStore fallback;
  bool _warned = false;

  AutoAiMemoryStore({
    AiMemoryStore? primary,
    InMemoryAiMemoryStore? fallback,
  })  : primary = primary ?? DbAiMemoryStore(),
        fallback = fallback ?? InMemoryAiMemoryStore();

  @override
  Future<void> appendRunEvent(String runId, Map<String, dynamic> event) async {
    if (!DB.isConnected) {
      _warnWithoutError();
      await fallback.appendRunEvent(runId, event);
      return;
    }
    try {
      await primary.appendRunEvent(runId, event);
    } catch (error) {
      _warn(error);
      await fallback.appendRunEvent(runId, event);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> loadRunEvents(String runId) async {
    if (!DB.isConnected) {
      _warnWithoutError();
      return fallback.loadRunEvents(runId);
    }
    try {
      return await primary.loadRunEvents(runId);
    } catch (error) {
      _warn(error);
      return fallback.loadRunEvents(runId);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> loadThreadMessages(String threadId) async {
    if (!DB.isConnected) {
      _warnWithoutError();
      return fallback.loadThreadMessages(threadId);
    }
    try {
      return await primary.loadThreadMessages(threadId);
    } catch (error) {
      _warn(error);
      return fallback.loadThreadMessages(threadId);
    }
  }

  @override
  Future<void> saveThreadMessage(
    String threadId,
    Map<String, dynamic> message,
  ) async {
    if (!DB.isConnected) {
      _warnWithoutError();
      await fallback.saveThreadMessage(threadId, message);
      return;
    }
    try {
      await primary.saveThreadMessage(threadId, message);
    } catch (error) {
      _warn(error);
      await fallback.saveThreadMessage(threadId, message);
    }
  }

  void _warn(Object error) {
    if (_warned) return;
    _warned = true;
    Log.warning(
      'AI memory persistence fell back to in-memory storage. Configure the database for production. Error: $error',
      tag: 'ai',
    );
  }

  void _warnWithoutError() {
    if (_warned) return;
    _warned = true;
    Log.warning(
      'AI memory is using in-memory storage because the database is not connected.',
      tag: 'ai',
    );
  }
}
