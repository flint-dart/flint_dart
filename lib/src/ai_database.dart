import 'dart:convert';

import 'package:flint_ai/flint_ai.dart';
import 'package:flint_dart/db.dart';
import 'package:flint_dart/logs.dart';

/// Database-backed AI memory store for Flint Dart applications.
class FlintDbAiMemoryStore implements AiMemoryStore {
  static const String _runEventsTable = 'ai_run_events';
  static const String _threadMessagesTable = 'ai_thread_messages';
  static bool _ensured = false;

  Future<void> _ensureTables() async {
    if (_ensured) return;
    await _assertAiTablesMigrated([
      _runEventsTable,
      _threadMessagesTable,
    ]);
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
        .map((row) => _decodeMap(row['event_json']))
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
        .map((row) => _decodeMap(row['message_json']))
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

/// AI memory store that uses Flint DB when available and falls back to memory.
class FlintAutoAiMemoryStore implements AiMemoryStore {
  final AiMemoryStore primary;
  final InMemoryAiMemoryStore fallback;
  bool _warned = false;

  FlintAutoAiMemoryStore({
    AiMemoryStore? primary,
    InMemoryAiMemoryStore? fallback,
  })  : primary = primary ?? FlintDbAiMemoryStore(),
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

/// Database-backed AI run store for Flint Dart applications.
class FlintDbAiRunStore implements AiRunStore {
  static const String _tableName = 'ai_runs';
  static bool _ensured = false;

  Future<void> _ensureTable() async {
    if (_ensured) return;
    await _assertAiTablesMigrated([_tableName]);
    _ensured = true;
  }

  @override
  Future<Map<String, dynamic>?> loadRun(String runId) async {
    await _ensureTable();
    final rows = await DB.query(
      'SELECT run_json FROM $_tableName WHERE run_id = ? ORDER BY id DESC ${DB.buildLimitClause(1)}',
      positionalParams: [runId],
    );
    if (rows.isEmpty) return null;
    return _decodeMap(rows.first['run_json']);
  }

  @override
  Future<void> saveRun(Map<String, dynamic> run) async {
    await _ensureTable();
    final runId = run['id']?.toString();
    if (runId == null || runId.isEmpty) {
      throw ArgumentError('AI run must include an id.');
    }

    await DB.execute(
      'DELETE FROM $_tableName WHERE run_id = ?',
      positionalParams: [runId],
    );

    final now = DateTime.now().toIso8601String();
    await DB.execute(
      'INSERT INTO $_tableName (run_id, agent_name, user_id, tenant_id, thread_id, status, run_json, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      positionalParams: [
        runId,
        run['agentName']?.toString() ?? 'unknown',
        run['userId']?.toString(),
        run['tenantId']?.toString(),
        run['threadId']?.toString(),
        run['status']?.toString() ?? 'pending',
        jsonEncode(run),
        now,
        now,
      ],
    );
  }
}

/// Database-backed AI thread store for Flint Dart applications.
class FlintDbAiThreadStore implements AiThreadStore {
  static const String _tableName = 'ai_threads';
  static bool _ensured = false;

  Future<void> _ensureTable() async {
    if (_ensured) return;
    await _assertAiTablesMigrated([_tableName]);
    _ensured = true;
  }

  @override
  Future<Map<String, dynamic>?> loadThread(String threadId) async {
    await _ensureTable();
    final rows = await DB.query(
      'SELECT thread_json FROM $_tableName WHERE thread_id = ? ORDER BY id DESC ${DB.buildLimitClause(1)}',
      positionalParams: [threadId],
    );
    if (rows.isEmpty) return null;
    return _decodeMap(rows.first['thread_json']);
  }

  @override
  Future<void> saveThread(Map<String, dynamic> thread) async {
    await _ensureTable();
    final threadId = thread['id']?.toString();
    if (threadId == null || threadId.isEmpty) {
      throw ArgumentError('AI thread must include an id.');
    }

    await DB.execute(
      'DELETE FROM $_tableName WHERE thread_id = ?',
      positionalParams: [threadId],
    );

    final now = DateTime.now().toIso8601String();
    await DB.execute(
      'INSERT INTO $_tableName (thread_id, user_id, tenant_id, thread_json, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
      positionalParams: [
        threadId,
        thread['userId']?.toString(),
        thread['tenantId']?.toString(),
        jsonEncode(thread),
        now,
        now,
      ],
    );
  }
}

/// Database-backed AI trace store for Flint Dart applications.
class FlintDbAiTraceStore implements AiTraceStore {
  static const String _tableName = 'ai_traces';
  static bool _ensured = false;

  Future<void> _ensureTable() async {
    if (_ensured) return;
    await _assertAiTablesMigrated([_tableName]);
    _ensured = true;
  }

  @override
  Future<void> appendTrace(String runId, Map<String, dynamic> event) async {
    await _ensureTable();
    await DB.execute(
      'INSERT INTO $_tableName (run_id, event_type, event_json, created_at) VALUES (?, ?, ?, ?)',
      positionalParams: [
        runId,
        event['type']?.toString() ?? 'unknown',
        jsonEncode(event),
        DateTime.now().toIso8601String(),
      ],
    );
  }
}

/// Database-backed AI artifact store for Flint Dart applications.
class FlintDbAiArtifactStore implements AiArtifactStore {
  static const String _tableName = 'ai_artifacts';
  static bool _ensured = false;

  Future<void> _ensureTable() async {
    if (_ensured) return;
    await _assertAiTablesMigrated([_tableName]);
    _ensured = true;
  }

  @override
  Future<void> saveArtifact(Map<String, dynamic> artifact) async {
    await _ensureTable();
    await DB.execute(
      'INSERT INTO $_tableName (artifact_id, run_id, kind, artifact_json, created_at) VALUES (?, ?, ?, ?, ?)',
      positionalParams: [
        artifact['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        artifact['runId']?.toString(),
        artifact['kind']?.toString() ?? 'generic',
        jsonEncode(artifact),
        DateTime.now().toIso8601String(),
      ],
    );
  }
}

/// AI repository that uses Flint DB when available and falls back to memory.
class FlintAutoAiRepository extends AiRepository {
  final InMemoryAiRunStore fallbackRuns;
  final InMemoryAiThreadStore fallbackThreads;
  final InMemoryAiTraceStore fallbackTraces;
  final InMemoryAiArtifactStore fallbackArtifacts;

  factory FlintAutoAiRepository() {
    final fallbackRuns = InMemoryAiRunStore();
    final fallbackThreads = InMemoryAiThreadStore();
    final fallbackTraces = InMemoryAiTraceStore();
    final fallbackArtifacts = InMemoryAiArtifactStore();

    return FlintAutoAiRepository._(
      fallbackRuns: fallbackRuns,
      fallbackThreads: fallbackThreads,
      fallbackTraces: fallbackTraces,
      fallbackArtifacts: fallbackArtifacts,
      runs: _FlintResilientAiRunStore(
        primary: FlintDbAiRunStore(),
        fallback: fallbackRuns,
      ),
      threads: _FlintResilientAiThreadStore(
        primary: FlintDbAiThreadStore(),
        fallback: fallbackThreads,
      ),
      traces: _FlintResilientAiTraceStore(
        primary: FlintDbAiTraceStore(),
        fallback: fallbackTraces,
      ),
      artifacts: _FlintResilientAiArtifactStore(
        primary: FlintDbAiArtifactStore(),
        fallback: fallbackArtifacts,
      ),
    );
  }

  FlintAutoAiRepository._({
    required this.fallbackRuns,
    required this.fallbackThreads,
    required this.fallbackTraces,
    required this.fallbackArtifacts,
    required super.runs,
    required super.threads,
    required super.traces,
    required super.artifacts,
  });
}

class _FlintResilientAiRunStore implements AiRunStore {
  final AiRunStore primary;
  final AiRunStore fallback;
  bool _warned = false;

  _FlintResilientAiRunStore({
    required this.primary,
    required this.fallback,
  });

  @override
  Future<Map<String, dynamic>?> loadRun(String runId) async {
    if (!DB.isConnected) {
      _warnWithoutError();
      return fallback.loadRun(runId);
    }

    try {
      return await primary.loadRun(runId);
    } catch (error) {
      _warn(error);
      return fallback.loadRun(runId);
    }
  }

  @override
  Future<void> saveRun(Map<String, dynamic> run) async {
    if (!DB.isConnected) {
      _warnWithoutError();
      await fallback.saveRun(run);
      return;
    }

    try {
      await primary.saveRun(run);
    } catch (error) {
      _warn(error);
      await fallback.saveRun(run);
    }
  }

  void _warn(Object error) => _warnOnce(
        _warned,
        (value) => _warned = value,
        'AI run persistence fell back to in-memory storage. Configure the database for production. Error: $error',
      );

  void _warnWithoutError() => _warnOnce(
        _warned,
        (value) => _warned = value,
        'AI run persistence is using in-memory storage because the database is not connected.',
      );
}

class _FlintResilientAiThreadStore implements AiThreadStore {
  final AiThreadStore primary;
  final AiThreadStore fallback;
  bool _warned = false;

  _FlintResilientAiThreadStore({
    required this.primary,
    required this.fallback,
  });

  @override
  Future<Map<String, dynamic>?> loadThread(String threadId) async {
    if (!DB.isConnected) {
      _warnWithoutError();
      return fallback.loadThread(threadId);
    }

    try {
      return await primary.loadThread(threadId);
    } catch (error) {
      _warn(error);
      return fallback.loadThread(threadId);
    }
  }

  @override
  Future<void> saveThread(Map<String, dynamic> thread) async {
    if (!DB.isConnected) {
      _warnWithoutError();
      await fallback.saveThread(thread);
      return;
    }

    try {
      await primary.saveThread(thread);
    } catch (error) {
      _warn(error);
      await fallback.saveThread(thread);
    }
  }

  void _warn(Object error) => _warnOnce(
        _warned,
        (value) => _warned = value,
        'AI thread persistence fell back to in-memory storage. Configure the database for production. Error: $error',
      );

  void _warnWithoutError() => _warnOnce(
        _warned,
        (value) => _warned = value,
        'AI thread persistence is using in-memory storage because the database is not connected.',
      );
}

class _FlintResilientAiTraceStore implements AiTraceStore {
  final AiTraceStore primary;
  final AiTraceStore fallback;
  bool _warned = false;

  _FlintResilientAiTraceStore({
    required this.primary,
    required this.fallback,
  });

  @override
  Future<void> appendTrace(String runId, Map<String, dynamic> event) async {
    if (!DB.isConnected) {
      _warnWithoutError();
      await fallback.appendTrace(runId, event);
      return;
    }

    try {
      await primary.appendTrace(runId, event);
    } catch (error) {
      _warn(error);
      await fallback.appendTrace(runId, event);
    }
  }

  void _warn(Object error) => _warnOnce(
        _warned,
        (value) => _warned = value,
        'AI trace persistence fell back to in-memory storage. Configure the database for production. Error: $error',
      );

  void _warnWithoutError() => _warnOnce(
        _warned,
        (value) => _warned = value,
        'AI trace persistence is using in-memory storage because the database is not connected.',
      );
}

class _FlintResilientAiArtifactStore implements AiArtifactStore {
  final AiArtifactStore primary;
  final AiArtifactStore fallback;
  bool _warned = false;

  _FlintResilientAiArtifactStore({
    required this.primary,
    required this.fallback,
  });

  @override
  Future<void> saveArtifact(Map<String, dynamic> artifact) async {
    if (!DB.isConnected) {
      _warnWithoutError();
      await fallback.saveArtifact(artifact);
      return;
    }

    try {
      await primary.saveArtifact(artifact);
    } catch (error) {
      _warn(error);
      await fallback.saveArtifact(artifact);
    }
  }

  void _warn(Object error) => _warnOnce(
        _warned,
        (value) => _warned = value,
        'AI artifact persistence fell back to in-memory storage. Configure the database for production. Error: $error',
      );

  void _warnWithoutError() => _warnOnce(
        _warned,
        (value) => _warned = value,
        'AI artifact persistence is using in-memory storage because the database is not connected.',
      );
}

Map<String, dynamic> _decodeMap(Object? value) {
  return Map<String, dynamic>.from(jsonDecode(value.toString()) as Map);
}

Future<void> _assertAiTablesMigrated(List<String> tableNames) async {
  final missing = <String>[];
  for (final tableName in tableNames) {
    if (!await DB.tableExists(tableName)) {
      missing.add(tableName);
    }
  }
  if (missing.isNotEmpty) {
    throw StateError(
      'Flint AI database tables are missing: ${missing.join(', ')}. '
      'Add ...flintAiTables to lib/config/table_registry.dart and run `flint migrate`.',
    );
  }
}

void _warnOnce(
  bool warned,
  void Function(bool value) setWarned,
  String message,
) {
  if (warned) return;
  setWarned(true);
  Log.warning(message, tag: 'ai');
}
