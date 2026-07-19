import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

List<Table> flintJobTables() {
  return [FlintJobModel().table, FlintJobRunModel().table];
}

class FlintJobModel extends Model<FlintJobModel> {
  FlintJobModel() : super(FlintJobModel.new);

  String get type => getAttribute<String>('type') ?? '';
  String get queue => getAttribute<String>('queue') ?? 'default';
  Map<String, dynamic> get payload =>
      getAttribute<Map<String, dynamic>>('payload') ?? <String, dynamic>{};
  String? get jobKey => getAttribute<String>('jobKey');
  String get status => getAttribute<String>('status') ?? 'PENDING';
  int get attempts => getAttribute<int>('attempts') ?? 0;
  int get maxAttempts => getAttribute<int>('maxAttempts') ?? 3;
  DateTime? get runAt => getAttribute<DateTime>('runAt');
  DateTime? get lockedAt => getAttribute<DateTime>('lockedAt');
  String? get lockedBy => getAttribute<String>('lockedBy');
  DateTime? get startedAt => getAttribute<DateTime>('startedAt');
  DateTime? get finishedAt => getAttribute<DateTime>('finishedAt');
  String? get lastError => getAttribute<String>('lastError');
  Map<String, dynamic> get metadata =>
      getAttribute<Map<String, dynamic>>('metadata') ?? <String, dynamic>{};

  @override
  Table get table => Table(
        name: 'flint_jobs',
        columns: [
          Column(name: 'type', type: ColumnType.string),
          Column(
            name: 'queue',
            type: ColumnType.string,
            defaultValue: 'default',
          ),
          Column(name: 'payload', type: ColumnType.json),
          Column(
            name: 'jobKey',
            type: ColumnType.string,
            isNullable: true,
            isUnique: true,
          ),
          Column(
            name: 'status',
            type: ColumnType.string,
            defaultValue: 'PENDING',
          ),
          Column(name: 'attempts', type: ColumnType.integer, defaultValue: 0),
          Column(
            name: 'maxAttempts',
            type: ColumnType.integer,
            defaultValue: 3,
          ),
          Column(name: 'runAt', type: ColumnType.datetime, isNullable: true),
          Column(name: 'lockedAt', type: ColumnType.datetime, isNullable: true),
          Column(name: 'lockedBy', type: ColumnType.string, isNullable: true),
          Column(
              name: 'startedAt', type: ColumnType.datetime, isNullable: true),
          Column(
            name: 'finishedAt',
            type: ColumnType.datetime,
            isNullable: true,
          ),
          Column(name: 'lastError', type: ColumnType.text, isNullable: true),
          Column(name: 'metadata', type: ColumnType.json, isNullable: true),
        ],
        indexes: [
          Index(
              columns: ['queue', 'status', 'runAt'],
              name: 'idx_flint_jobs_next'),
          Index(columns: ['type'], name: 'idx_flint_jobs_type'),
        ],
      );
}

class FlintJobRunModel extends Model<FlintJobRunModel> {
  FlintJobRunModel() : super(FlintJobRunModel.new);

  @override
  Table get table => Table(
        name: 'flint_job_runs',
        columns: [
          Column(name: 'jobId', type: ColumnType.string),
          Column(name: 'type', type: ColumnType.string),
          Column(
            name: 'queue',
            type: ColumnType.string,
            defaultValue: 'default',
          ),
          Column(name: 'status', type: ColumnType.string),
          Column(name: 'attempt', type: ColumnType.integer),
          Column(name: 'startedAt', type: ColumnType.datetime),
          Column(
              name: 'finishedAt', type: ColumnType.datetime, isNullable: true),
          Column(name: 'elapsedMs', type: ColumnType.integer, isNullable: true),
          Column(name: 'error', type: ColumnType.text, isNullable: true),
          Column(name: 'workerId', type: ColumnType.string, isNullable: true),
          Column(name: 'metadata', type: ColumnType.json, isNullable: true),
        ],
        indexes: [
          Index(columns: ['jobId'], name: 'idx_flint_job_runs_job'),
          Index(columns: ['type'], name: 'idx_flint_job_runs_type'),
        ],
      );
}
