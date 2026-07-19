import 'package:flint_dart/helper.dart';
import 'package:flint_dart/model.dart';
import 'package:flint_dart/src/jobs/flint_job_models.dart';
import 'package:flint_dart/src/jobs/flint_job_record.dart';
import 'package:flint_dart/src/jobs/flint_job_run_record.dart';

abstract class FlintJobStore {
  Future<FlintJobRecord> dispatch({
    required String type,
    required String queue,
    required Map<String, dynamic> payload,
    required int maxAttempts,
    String? key,
    DateTime? runAt,
    Map<String, dynamic> metadata = const {},
  });

  Future<List<FlintJobRecord>> nextRunnable({
    required String queue,
    required int limit,
    required DateTime now,
  });

  Future<FlintJobRecord?> claim(FlintJobRecord record, {String? workerId});

  Future<FlintJobRecord> complete(
    FlintJobRecord record, {
    Map<String, dynamic>? payload,
  });

  Future<FlintJobRecord> fail(
    FlintJobRecord record, {
    required String error,
    required bool retry,
    DateTime? nextRunAt,
  });

  Future<FlintJobRecord> release(
    FlintJobRecord record, {
    required DateTime nextRunAt,
    String? reason,
    Map<String, dynamic>? payload,
  });

  Future<int> recoverStaleRunning({
    required Duration staleAfter,
    required DateTime now,
  });

  Future<FlintJobRunRecord> startRun(
    FlintJobRecord record, {
    String? workerId,
  });

  Future<void> finishRun(
    FlintJobRunRecord run, {
    required String status,
    String? error,
    Map<String, dynamic>? metadata,
  });

  Future<void> log(
    FlintJobRecord record,
    String message, {
    Map<String, dynamic>? metadata,
  });
}

class FlintDatabaseJobStore implements FlintJobStore {
  const FlintDatabaseJobStore();

  @override
  Future<FlintJobRecord> dispatch({
    required String type,
    required String queue,
    required Map<String, dynamic> payload,
    required int maxAttempts,
    String? key,
    DateTime? runAt,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (key != null && key.trim().isNotEmpty) {
      final existing = await FlintJobModel().where('jobKey', key).first();
      if (existing != null) return _recordFromModel(existing);
    }

    final created = await FlintJobModel().create({
      'type': type,
      'queue': queue,
      'payload': payload,
      'jobKey': key,
      'status': FlintJobStatus.pending,
      'attempts': 0,
      'maxAttempts': maxAttempts,
      'runAt': runAt,
      'metadata': metadata,
    });
    if (created == null) {
      throw StateError('Failed to create Flint job record');
    }
    return _recordFromModel(created);
  }

  @override
  Future<List<FlintJobRecord>> nextRunnable({
    required String queue,
    required int limit,
    required DateTime now,
  }) async {
    final candidates = await FlintJobModel()
        .where('queue', queue)
        .where('status', FlintJobStatus.pending)
        .orderBy('created_at')
        .limit(limit * 3)
        .get();

    return candidates
        .map(_recordFromModel)
        .where((job) => _isRunnable(job, now))
        .take(limit)
        .toList();
  }

  @override
  Future<FlintJobRecord?> claim(
    FlintJobRecord record, {
    String? workerId,
  }) async {
    final fresh = await FlintJobModel().find(record.id);
    if (fresh == null || fresh.status != FlintJobStatus.pending) return null;

    final now = DateTime.now();
    final updated = await fresh.update(
      data: {
        'status': FlintJobStatus.running,
        'attempts': fresh.attempts + 1,
        'lockedAt': now,
        'lockedBy': workerId,
        'startedAt': now,
        'finishedAt': null,
        'lastError': null,
      },
    );
    return updated == null ? null : _recordFromModel(updated);
  }

  @override
  Future<FlintJobRecord> complete(
    FlintJobRecord record, {
    Map<String, dynamic>? payload,
  }) async {
    return _updateRecord(record, {
      'status': FlintJobStatus.completed,
      'payload': payload ?? record.payload,
      'finishedAt': DateTime.now(),
      'lockedAt': null,
      'lockedBy': null,
      'lastError': null,
    });
  }

  @override
  Future<FlintJobRecord> fail(
    FlintJobRecord record, {
    required String error,
    required bool retry,
    DateTime? nextRunAt,
  }) async {
    final shouldRetry = retry && record.attempts < record.maxAttempts;
    return _updateRecord(record, {
      'status': shouldRetry ? FlintJobStatus.pending : FlintJobStatus.failed,
      'runAt': shouldRetry ? nextRunAt : null,
      'finishedAt': shouldRetry ? null : DateTime.now(),
      'lockedAt': null,
      'lockedBy': null,
      'lastError': error,
    });
  }

  @override
  Future<FlintJobRecord> release(
    FlintJobRecord record, {
    required DateTime nextRunAt,
    String? reason,
    Map<String, dynamic>? payload,
  }) async {
    return _updateRecord(record, {
      'status': FlintJobStatus.pending,
      'payload': payload ?? record.payload,
      'runAt': nextRunAt,
      'finishedAt': null,
      'lockedAt': null,
      'lockedBy': null,
      'lastError': reason,
    });
  }

  @override
  Future<int> recoverStaleRunning({
    required Duration staleAfter,
    required DateTime now,
  }) async {
    final cutoff = now.subtract(staleAfter);
    final running =
        await FlintJobModel().where('status', FlintJobStatus.running).get();
    var recovered = 0;
    for (final job in running) {
      final lockedAt = job.lockedAt;
      if (lockedAt != null && lockedAt.isAfter(cutoff)) continue;
      await job.update(
        data: {
          'status': FlintJobStatus.pending,
          'lockedAt': null,
          'lockedBy': null,
          'lastError': 'Recovered stale RUNNING job.',
        },
      );
      recovered++;
    }
    return recovered;
  }

  @override
  Future<FlintJobRunRecord> startRun(
    FlintJobRecord record, {
    String? workerId,
  }) async {
    final created = await FlintJobRunModel().create({
      'jobId': record.id,
      'type': record.type,
      'queue': record.queue,
      'status': FlintJobStatus.running,
      'attempt': record.attempts,
      'startedAt': DateTime.now(),
      'workerId': workerId,
      'metadata': {},
    });
    if (created == null) {
      throw StateError('Failed to create Flint job run record');
    }
    return _runFromModel(created);
  }

  @override
  Future<void> finishRun(
    FlintJobRunRecord run, {
    required String status,
    String? error,
    Map<String, dynamic>? metadata,
  }) async {
    final finishedAt = DateTime.now();
    await FlintJobRunModel().update(
      id: run.id,
      data: {
        'status': status,
        'finishedAt': finishedAt,
        'elapsedMs': finishedAt.difference(run.startedAt).inMilliseconds,
        'error': error,
        'metadata': metadata ?? run.metadata,
      },
    );
  }

  @override
  Future<void> log(
    FlintJobRecord record,
    String message, {
    Map<String, dynamic>? metadata,
  }) async {
    final logs = List<Map<String, dynamic>>.from(
      (record.metadata['logs'] as List?) ?? const [],
    );
    logs.add({
      'message': message,
      'metadata': metadata ?? const {},
      'loggedAt': DateTime.now().toIso8601String(),
    });
    await _updateRecord(record, {
      'metadata': {...record.metadata, 'logs': logs},
    });
  }

  Future<FlintJobRecord> _updateRecord(
    FlintJobRecord record,
    Map<String, dynamic> data,
  ) async {
    final updated = await FlintJobModel().update(id: record.id, data: data);
    if (updated == null) {
      throw StateError('Failed to update Flint job ${record.id}');
    }
    return _recordFromModel(updated);
  }
}

class FlintMemoryJobStore implements FlintJobStore {
  final Map<String, FlintJobRecord> _jobs = {};
  final Map<String, FlintJobRunRecord> _runs = {};

  List<FlintJobRecord> get jobs => _jobs.values.toList();
  List<FlintJobRunRecord> get runs => _runs.values.toList();

  @override
  Future<FlintJobRecord> dispatch({
    required String type,
    required String queue,
    required Map<String, dynamic> payload,
    required int maxAttempts,
    String? key,
    DateTime? runAt,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (key != null && key.trim().isNotEmpty) {
      final existing = _jobs.values.where((job) => job.jobKey == key);
      if (existing.isNotEmpty) return existing.first;
    }

    final now = DateTime.now();
    final record = FlintJobRecord(
      id: Str.uuid(),
      type: type,
      queue: queue,
      payload: Map<String, dynamic>.from(payload),
      jobKey: key,
      status: FlintJobStatus.pending,
      attempts: 0,
      maxAttempts: maxAttempts,
      runAt: runAt,
      metadata: Map<String, dynamic>.from(metadata),
      createdAt: now,
    );
    _jobs[record.id] = record;
    return record;
  }

  @override
  Future<List<FlintJobRecord>> nextRunnable({
    required String queue,
    required int limit,
    required DateTime now,
  }) async {
    final records = _jobs.values
        .where((job) => job.queue == queue)
        .where((job) => _isRunnable(job, now))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return records.take(limit).toList();
  }

  @override
  Future<FlintJobRecord?> claim(
    FlintJobRecord record, {
    String? workerId,
  }) async {
    final fresh = _jobs[record.id];
    if (fresh == null || fresh.status != FlintJobStatus.pending) return null;
    final claimed = fresh.copyWith(
      status: FlintJobStatus.running,
      attempts: fresh.attempts + 1,
      lockedAt: DateTime.now(),
      lockedBy: workerId,
      startedAt: DateTime.now(),
      clearFinishedAt: true,
      clearLastError: true,
    );
    _jobs[record.id] = claimed;
    return claimed;
  }

  @override
  Future<FlintJobRecord> complete(
    FlintJobRecord record, {
    Map<String, dynamic>? payload,
  }) async {
    final updated = record.copyWith(
      status: FlintJobStatus.completed,
      payload: payload ?? record.payload,
      finishedAt: DateTime.now(),
      clearLockedAt: true,
      clearLockedBy: true,
      clearLastError: true,
    );
    _jobs[record.id] = updated;
    return updated;
  }

  @override
  Future<FlintJobRecord> fail(
    FlintJobRecord record, {
    required String error,
    required bool retry,
    DateTime? nextRunAt,
  }) async {
    final shouldRetry = retry && record.attempts < record.maxAttempts;
    final updated = record.copyWith(
      status: shouldRetry ? FlintJobStatus.pending : FlintJobStatus.failed,
      runAt: shouldRetry ? nextRunAt : null,
      clearRunAt: !shouldRetry,
      finishedAt: shouldRetry ? null : DateTime.now(),
      clearFinishedAt: shouldRetry,
      clearLockedAt: true,
      clearLockedBy: true,
      lastError: error,
    );
    _jobs[record.id] = updated;
    return updated;
  }

  @override
  Future<FlintJobRecord> release(
    FlintJobRecord record, {
    required DateTime nextRunAt,
    String? reason,
    Map<String, dynamic>? payload,
  }) async {
    final updated = record.copyWith(
      status: FlintJobStatus.pending,
      payload: payload ?? record.payload,
      runAt: nextRunAt,
      clearFinishedAt: true,
      clearLockedAt: true,
      clearLockedBy: true,
      lastError: reason,
      clearLastError: reason == null,
    );
    _jobs[record.id] = updated;
    return updated;
  }

  @override
  Future<int> recoverStaleRunning({
    required Duration staleAfter,
    required DateTime now,
  }) async {
    final cutoff = now.subtract(staleAfter);
    var recovered = 0;
    for (final record in _jobs.values.toList()) {
      if (record.status != FlintJobStatus.running) continue;
      final lockedAt = record.lockedAt;
      if (lockedAt != null && lockedAt.isAfter(cutoff)) continue;
      _jobs[record.id] = record.copyWith(
        status: FlintJobStatus.pending,
        clearLockedAt: true,
        clearLockedBy: true,
        lastError: 'Recovered stale RUNNING job.',
      );
      recovered++;
    }
    return recovered;
  }

  @override
  Future<FlintJobRunRecord> startRun(
    FlintJobRecord record, {
    String? workerId,
  }) async {
    final run = FlintJobRunRecord(
      id: Str.uuid(),
      jobId: record.id,
      type: record.type,
      queue: record.queue,
      status: FlintJobStatus.running,
      attempt: record.attempts,
      startedAt: DateTime.now(),
      workerId: workerId,
    );
    _runs[run.id] = run;
    return run;
  }

  @override
  Future<void> finishRun(
    FlintJobRunRecord run, {
    required String status,
    String? error,
    Map<String, dynamic>? metadata,
  }) async {
    final finishedAt = DateTime.now();
    _runs[run.id] = run.copyWith(
      status: status,
      finishedAt: finishedAt,
      elapsedMs: finishedAt.difference(run.startedAt).inMilliseconds,
      error: error,
      clearError: error == null,
      metadata: metadata,
    );
  }

  @override
  Future<void> log(
    FlintJobRecord record,
    String message, {
    Map<String, dynamic>? metadata,
  }) async {
    final logs = List<Map<String, dynamic>>.from(
      (record.metadata['logs'] as List?) ?? const [],
    );
    logs.add({
      'message': message,
      'metadata': metadata ?? const {},
      'loggedAt': DateTime.now().toIso8601String(),
    });
    _jobs[record.id] = record.copyWith(
      metadata: {...record.metadata, 'logs': logs},
    );
  }
}

bool _isRunnable(FlintJobRecord job, DateTime now) {
  if (job.status != FlintJobStatus.pending) return false;
  if (job.attempts >= job.maxAttempts) return false;
  final runAt = job.runAt;
  return runAt == null || !runAt.isAfter(now);
}

FlintJobRecord _recordFromModel(FlintJobModel model) {
  return FlintJobRecord(
    id: model.id.toString(),
    type: model.type,
    queue: model.queue,
    payload: model.payload,
    jobKey: model.jobKey,
    status: model.status,
    attempts: model.attempts,
    maxAttempts: model.maxAttempts,
    runAt: model.runAt,
    lockedAt: model.lockedAt,
    lockedBy: model.lockedBy,
    startedAt: model.startedAt,
    finishedAt: model.finishedAt,
    lastError: model.lastError,
    metadata: model.metadata,
    createdAt: model.createdAt ?? DateTime.now(),
  );
}

FlintJobRunRecord _runFromModel(FlintJobRunModel model) {
  return FlintJobRunRecord(
    id: model.id.toString(),
    jobId: model.getAttribute<String>('jobId') ?? '',
    type: model.getAttribute<String>('type') ?? '',
    queue: model.getAttribute<String>('queue') ?? 'default',
    status: model.getAttribute<String>('status') ?? FlintJobStatus.running,
    attempt: model.getAttribute<int>('attempt') ?? 0,
    startedAt: model.getAttribute<DateTime>('startedAt') ?? DateTime.now(),
    finishedAt: model.getAttribute<DateTime>('finishedAt'),
    elapsedMs: model.getAttribute<int>('elapsedMs'),
    error: model.getAttribute<String>('error'),
    workerId: model.getAttribute<String>('workerId'),
    metadata: model.getAttribute<Map<String, dynamic>>('metadata') ??
        <String, dynamic>{},
  );
}
