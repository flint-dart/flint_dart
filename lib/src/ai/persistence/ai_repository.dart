import 'dart:convert';

import 'package:flint_dart/db.dart';
import 'package:flint_dart/logs.dart';

/// Store for persisted AI run snapshots.
abstract class AiRunStore {
  Future<void> saveRun(Map<String, dynamic> run);
  Future<Map<String, dynamic>?> loadRun(String runId);
}

/// Store for persisted AI thread snapshots.
abstract class AiThreadStore {
  Future<void> saveThread(Map<String, dynamic> thread);
  Future<Map<String, dynamic>?> loadThread(String threadId);
}

/// Store for persisted AI trace events.
abstract class AiTraceStore {
  Future<void> appendTrace(String runId, Map<String, dynamic> event);
}

/// Store for persisted AI artifacts.
abstract class AiArtifactStore {
  Future<void> saveArtifact(Map<String, dynamic> artifact);
}

/// In-memory run store for development and tests.
class InMemoryAiRunStore implements AiRunStore {
  final Map<String, Map<String, dynamic>> _runs = {};

  @override
  Future<Map<String, dynamic>?> loadRun(String runId) async {
    final run = _runs[runId];
    if (run == null) return null;
    return Map<String, dynamic>.from(run);
  }

  @override
  Future<void> saveRun(Map<String, dynamic> run) async {
    final id = run['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ArgumentError('AI run must include an id.');
    }
    _runs[id] = Map<String, dynamic>.from(run);
  }
}

/// In-memory thread store for development and tests.
class InMemoryAiThreadStore implements AiThreadStore {
  final Map<String, Map<String, dynamic>> _threads = {};

  @override
  Future<Map<String, dynamic>?> loadThread(String threadId) async {
    final thread = _threads[threadId];
    if (thread == null) return null;
    return Map<String, dynamic>.from(thread);
  }

  @override
  Future<void> saveThread(Map<String, dynamic> thread) async {
    final id = thread['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ArgumentError('AI thread must include an id.');
    }
    _threads[id] = Map<String, dynamic>.from(thread);
  }
}

/// In-memory trace store for development and tests.
class InMemoryAiTraceStore implements AiTraceStore {
  final Map<String, List<Map<String, dynamic>>> _events = {};

  @override
  Future<void> appendTrace(String runId, Map<String, dynamic> event) async {
    _events.putIfAbsent(runId, () => []).add(Map<String, dynamic>.from(event));
  }

  /// Returns all stored events for a run.
  List<Map<String, dynamic>> eventsForRun(String runId) {
    return (_events[runId] ?? const [])
        .map((event) => Map<String, dynamic>.from(event))
        .toList(growable: false);
  }
}

/// In-memory artifact store for development and tests.
class InMemoryAiArtifactStore implements AiArtifactStore {
  final List<Map<String, dynamic>> _artifacts = [];

  @override
  Future<void> saveArtifact(Map<String, dynamic> artifact) async {
    _artifacts.add(Map<String, dynamic>.from(artifact));
  }

  /// Returns all stored artifacts.
  List<Map<String, dynamic>> get artifacts => _artifacts
      .map((artifact) => Map<String, dynamic>.from(artifact))
      .toList(growable: false);
}

/// Database-backed run store.
class DbAiRunStore implements AiRunStore {
  static const String _tableName = 'ai_runs';
  static bool _ensured = false;

  Future<void> _ensureTable() async {
    if (_ensured) return;
    final exists = await DB.tableExists(_tableName);
    if (!exists) {
      final dbType = DB.driver;
      final idColumn = dbType == DBDriver.mysql
          ? 'id INT PRIMARY KEY AUTO_INCREMENT'
          : 'id SERIAL PRIMARY KEY';
      final textType = dbType == DBDriver.mysql ? 'VARCHAR(255)' : 'TEXT';
      final payloadType = dbType == DBDriver.mysql ? 'LONGTEXT' : 'TEXT';

      await DB.execute('''
        CREATE TABLE IF NOT EXISTS $_tableName (
          $idColumn,
          run_id $textType NOT NULL,
          agent_name $textType NOT NULL,
          user_id $textType NULL,
          tenant_id $textType NULL,
          thread_id $textType NULL,
          status $textType NOT NULL,
          run_json $payloadType NOT NULL,
          created_at $textType NOT NULL,
          updated_at $textType NOT NULL
        )
      ''');
    }
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
    return Map<String, dynamic>.from(
      jsonDecode(rows.first['run_json'].toString()) as Map,
    );
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

/// Database-backed thread store.
class DbAiThreadStore implements AiThreadStore {
  static const String _tableName = 'ai_threads';
  static bool _ensured = false;

  Future<void> _ensureTable() async {
    if (_ensured) return;
    final exists = await DB.tableExists(_tableName);
    if (!exists) {
      final dbType = DB.driver;
      final idColumn = dbType == DBDriver.mysql
          ? 'id INT PRIMARY KEY AUTO_INCREMENT'
          : 'id SERIAL PRIMARY KEY';
      final textType = dbType == DBDriver.mysql ? 'VARCHAR(255)' : 'TEXT';
      final payloadType = dbType == DBDriver.mysql ? 'LONGTEXT' : 'TEXT';

      await DB.execute('''
        CREATE TABLE IF NOT EXISTS $_tableName (
          $idColumn,
          thread_id $textType NOT NULL,
          user_id $textType NULL,
          tenant_id $textType NULL,
          thread_json $payloadType NOT NULL,
          created_at $textType NOT NULL,
          updated_at $textType NOT NULL
        )
      ''');
    }
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
    return Map<String, dynamic>.from(
      jsonDecode(rows.first['thread_json'].toString()) as Map,
    );
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

/// Database-backed trace store.
class DbAiTraceStore implements AiTraceStore {
  static const String _tableName = 'ai_traces';
  static bool _ensured = false;

  Future<void> _ensureTable() async {
    if (_ensured) return;
    final exists = await DB.tableExists(_tableName);
    if (!exists) {
      final dbType = DB.driver;
      final idColumn = dbType == DBDriver.mysql
          ? 'id INT PRIMARY KEY AUTO_INCREMENT'
          : 'id SERIAL PRIMARY KEY';
      final textType = dbType == DBDriver.mysql ? 'VARCHAR(255)' : 'TEXT';
      final payloadType = dbType == DBDriver.mysql ? 'LONGTEXT' : 'TEXT';

      await DB.execute('''
        CREATE TABLE IF NOT EXISTS $_tableName (
          $idColumn,
          run_id $textType NOT NULL,
          event_type $textType NOT NULL,
          event_json $payloadType NOT NULL,
          created_at $textType NOT NULL
        )
      ''');
    }
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

/// Database-backed artifact store.
class DbAiArtifactStore implements AiArtifactStore {
  static const String _tableName = 'ai_artifacts';
  static bool _ensured = false;

  Future<void> _ensureTable() async {
    if (_ensured) return;
    final exists = await DB.tableExists(_tableName);
    if (!exists) {
      final dbType = DB.driver;
      final idColumn = dbType == DBDriver.mysql
          ? 'id INT PRIMARY KEY AUTO_INCREMENT'
          : 'id SERIAL PRIMARY KEY';
      final textType = dbType == DBDriver.mysql ? 'VARCHAR(255)' : 'TEXT';
      final payloadType = dbType == DBDriver.mysql ? 'LONGTEXT' : 'TEXT';

      await DB.execute('''
        CREATE TABLE IF NOT EXISTS $_tableName (
          $idColumn,
          artifact_id $textType NOT NULL,
          run_id $textType NULL,
          kind $textType NOT NULL,
          artifact_json $payloadType NOT NULL,
          created_at $textType NOT NULL
        )
      ''');
    }
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

/// Bundle of stores used by the AI runtime for persistence.
class AiRepository {
  final AiRunStore? runs;
  final AiThreadStore? threads;
  final AiTraceStore? traces;
  final AiArtifactStore? artifacts;

  const AiRepository({
    this.runs,
    this.threads,
    this.traces,
    this.artifacts,
  });
}

/// Repository that prefers database stores and falls back to in-memory stores.
class AutoAiRepository extends AiRepository {
  final InMemoryAiRunStore fallbackRuns;
  final InMemoryAiThreadStore fallbackThreads;
  final InMemoryAiTraceStore fallbackTraces;
  final InMemoryAiArtifactStore fallbackArtifacts;

  factory AutoAiRepository() {
    final fallbackRuns = InMemoryAiRunStore();
    final fallbackThreads = InMemoryAiThreadStore();
    final fallbackTraces = InMemoryAiTraceStore();
    final fallbackArtifacts = InMemoryAiArtifactStore();

    return AutoAiRepository._(
      fallbackRuns: fallbackRuns,
      fallbackThreads: fallbackThreads,
      fallbackTraces: fallbackTraces,
      fallbackArtifacts: fallbackArtifacts,
      runs: _ResilientAiRunStore(
        primary: DbAiRunStore(),
        fallback: fallbackRuns,
      ),
      threads: _ResilientAiThreadStore(
        primary: DbAiThreadStore(),
        fallback: fallbackThreads,
      ),
      traces: _ResilientAiTraceStore(
        primary: DbAiTraceStore(),
        fallback: fallbackTraces,
      ),
      artifacts: _ResilientAiArtifactStore(
        primary: DbAiArtifactStore(),
        fallback: fallbackArtifacts,
      ),
    );
  }

  AutoAiRepository._({
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

class _ResilientAiRunStore implements AiRunStore {
  final AiRunStore primary;
  final AiRunStore fallback;
  bool _warned = false;

  _ResilientAiRunStore({
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

  void _warn(Object error) {
    if (_warned) return;
    _warned = true;
    Log.warning(
      'AI run persistence fell back to in-memory storage. Configure the database for production. Error: $error',
      tag: 'ai',
    );
  }

  void _warnWithoutError() {
    if (_warned) return;
    _warned = true;
    Log.warning(
      'AI run persistence is using in-memory storage because the database is not connected.',
      tag: 'ai',
    );
  }
}

class _ResilientAiThreadStore implements AiThreadStore {
  final AiThreadStore primary;
  final AiThreadStore fallback;
  bool _warned = false;

  _ResilientAiThreadStore({
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

  void _warn(Object error) {
    if (_warned) return;
    _warned = true;
    Log.warning(
      'AI thread persistence fell back to in-memory storage. Configure the database for production. Error: $error',
      tag: 'ai',
    );
  }

  void _warnWithoutError() {
    if (_warned) return;
    _warned = true;
    Log.warning(
      'AI thread persistence is using in-memory storage because the database is not connected.',
      tag: 'ai',
    );
  }
}

class _ResilientAiTraceStore implements AiTraceStore {
  final AiTraceStore primary;
  final AiTraceStore fallback;
  bool _warned = false;

  _ResilientAiTraceStore({
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

  void _warn(Object error) {
    if (_warned) return;
    _warned = true;
    Log.warning(
      'AI trace persistence fell back to in-memory storage. Configure the database for production. Error: $error',
      tag: 'ai',
    );
  }

  void _warnWithoutError() {
    if (_warned) return;
    _warned = true;
    Log.warning(
      'AI trace persistence is using in-memory storage because the database is not connected.',
      tag: 'ai',
    );
  }
}

class _ResilientAiArtifactStore implements AiArtifactStore {
  final AiArtifactStore primary;
  final AiArtifactStore fallback;
  bool _warned = false;

  _ResilientAiArtifactStore({
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

  void _warn(Object error) {
    if (_warned) return;
    _warned = true;
    Log.warning(
      'AI artifact persistence fell back to in-memory storage. Configure the database for production. Error: $error',
      tag: 'ai',
    );
  }

  void _warnWithoutError() {
    if (_warned) return;
    _warned = true;
    Log.warning(
      'AI artifact persistence is using in-memory storage because the database is not connected.',
      tag: 'ai',
    );
  }
}
