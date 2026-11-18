import 'package:flint_dart/schema.dart';

/// Canonical table definitions used by Flint AI database adapters.
///
/// Add these tables to an application's `lib/config/table_registry.dart`:
///
/// ```dart
/// runTableRegistry([
///   ...flintAiTables,
/// ], _, sendPort);
/// ```
final List<Table> flintAiTables = [
  Table(
    name: 'ai_runs',
    columns: [
      _autoIdColumn(),
      Column(name: 'run_id', type: ColumnType.string, length: 255),
      Column(name: 'agent_name', type: ColumnType.string, length: 255),
      Column(name: 'user_id', type: ColumnType.string, isNullable: true),
      Column(name: 'tenant_id', type: ColumnType.string, isNullable: true),
      Column(name: 'thread_id', type: ColumnType.string, isNullable: true),
      Column(name: 'status', type: ColumnType.string, length: 255),
      Column(name: 'run_json', type: ColumnType.text),
      Column(name: 'created_at', type: ColumnType.string, length: 255),
      Column(name: 'updated_at', type: ColumnType.string, length: 255),
    ],
    indexes: [
      Index(name: 'idx_ai_runs_run_id', columns: ['run_id']),
      Index(name: 'idx_ai_runs_thread_id', columns: ['thread_id']),
      Index(name: 'idx_ai_runs_user_id', columns: ['user_id']),
    ],
  ),
  Table(
    name: 'ai_threads',
    columns: [
      _autoIdColumn(),
      Column(name: 'thread_id', type: ColumnType.string, length: 255),
      Column(name: 'user_id', type: ColumnType.string, isNullable: true),
      Column(name: 'tenant_id', type: ColumnType.string, isNullable: true),
      Column(name: 'thread_json', type: ColumnType.text),
      Column(name: 'created_at', type: ColumnType.string, length: 255),
      Column(name: 'updated_at', type: ColumnType.string, length: 255),
    ],
    indexes: [
      Index(name: 'idx_ai_threads_thread_id', columns: ['thread_id']),
      Index(name: 'idx_ai_threads_user_id', columns: ['user_id']),
    ],
  ),
  Table(
    name: 'ai_traces',
    columns: [
      _autoIdColumn(),
      Column(name: 'run_id', type: ColumnType.string, length: 255),
      Column(name: 'event_type', type: ColumnType.string, length: 255),
      Column(name: 'event_json', type: ColumnType.text),
      Column(name: 'created_at', type: ColumnType.string, length: 255),
    ],
    indexes: [
      Index(name: 'idx_ai_traces_run_id', columns: ['run_id']),
      Index(name: 'idx_ai_traces_event_type', columns: ['event_type']),
    ],
  ),
  Table(
    name: 'ai_artifacts',
    columns: [
      _autoIdColumn(),
      Column(name: 'artifact_id', type: ColumnType.string, length: 255),
      Column(name: 'run_id', type: ColumnType.string, isNullable: true),
      Column(name: 'kind', type: ColumnType.string, length: 255),
      Column(name: 'artifact_json', type: ColumnType.text),
      Column(name: 'created_at', type: ColumnType.string, length: 255),
    ],
    indexes: [
      Index(name: 'idx_ai_artifacts_artifact_id', columns: ['artifact_id']),
      Index(name: 'idx_ai_artifacts_run_id', columns: ['run_id']),
      Index(name: 'idx_ai_artifacts_kind', columns: ['kind']),
    ],
  ),
  Table(
    name: 'ai_run_events',
    columns: [
      _autoIdColumn(),
      Column(name: 'run_id', type: ColumnType.string, length: 255),
      Column(name: 'event_json', type: ColumnType.text),
      Column(name: 'created_at', type: ColumnType.string, length: 255),
    ],
    indexes: [
      Index(name: 'idx_ai_run_events_run_id', columns: ['run_id']),
    ],
  ),
  Table(
    name: 'ai_thread_messages',
    columns: [
      _autoIdColumn(),
      Column(name: 'thread_id', type: ColumnType.string, length: 255),
      Column(name: 'message_json', type: ColumnType.text),
      Column(name: 'created_at', type: ColumnType.string, length: 255),
    ],
    indexes: [
      Index(
        name: 'idx_ai_thread_messages_thread_id',
        columns: ['thread_id'],
      ),
    ],
  ),
];

Column _autoIdColumn() {
  return Column(
    name: 'id',
    type: ColumnType.integer,
    isPrimaryKey: true,
    isAutoIncrement: true,
  );
}
