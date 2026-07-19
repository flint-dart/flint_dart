import 'dart:async';
import 'dart:math';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/jobs/flint_job.dart';
import 'package:flint_dart/src/jobs/flint_job_context.dart';
import 'package:flint_dart/src/jobs/flint_job_record.dart';
import 'package:flint_dart/src/jobs/flint_job_schedule.dart';
import 'package:flint_dart/src/jobs/flint_job_store.dart';

class FlintJobs {
  FlintJobs._();

  static final Map<String, FlintJob> _registry = {};
  static final Map<String, FlintSchedule> _schedules = {};
  static FlintJobStore _store = const FlintDatabaseJobStore();
  static Timer? _workerTimer;
  static Timer? _schedulerTimer;
  static bool _workerRunning = false;
  static bool _schedulerRunning = false;

  static Map<String, FlintJob> get registered => Map.unmodifiable(_registry);
  static Map<String, FlintSchedule> get schedules =>
      Map.unmodifiable(_schedules);

  static void register(Iterable<FlintJob> jobs) {
    for (final job in jobs) {
      final type = job.type.trim();
      if (type.isEmpty) {
        throw ArgumentError('FlintJob.type cannot be empty');
      }
      _registry[type] = job;
    }
  }

  static void unregister(String type) {
    _registry.remove(type);
  }

  static void clearRegistry() {
    _registry.clear();
  }

  static Future<void> schedule(FlintSchedule schedule) async {
    final name = schedule.name.trim();
    if (name.isEmpty) {
      throw ArgumentError('FlintSchedule.name cannot be empty');
    }
    if (schedule.jobType.trim().isEmpty) {
      throw ArgumentError('FlintSchedule.jobType cannot be empty');
    }
    _schedules[name] = schedule;
    await _store.upsertSchedule(schedule, now: DateTime.now());
  }

  static Future<void> scheduleAll(Iterable<FlintSchedule> schedules) async {
    for (final schedule in schedules) {
      await FlintJobs.schedule(schedule);
    }
  }

  static void unschedule(String name) {
    _schedules.remove(name);
  }

  static void clearSchedules() {
    _schedules.clear();
  }

  static void useStore(FlintJobStore store) {
    _store = store;
  }

  static void useDatabaseStore() {
    _store = const FlintDatabaseJobStore();
  }

  static FlintJobStore get store => _store;

  static Future<FlintJobRecord> dispatch(
    String type, {
    Map<String, dynamic> payload = const {},
    String? key,
    DateTime? runAt,
    String? queue,
    int? maxAttempts,
    Map<String, dynamic> metadata = const {},
  }) async {
    final definition = _registry[type];
    final resolvedQueue = queue ?? definition?.queue ?? 'default';
    final resolvedMaxAttempts = maxAttempts ?? definition?.maxAttempts ?? 3;
    return _store.dispatch(
      type: type,
      queue: resolvedQueue,
      payload: Map<String, dynamic>.from(payload),
      key: key,
      runAt: runAt,
      maxAttempts: resolvedMaxAttempts,
      metadata: Map<String, dynamic>.from(metadata),
    );
  }

  static Future<int> runOnce({
    String queue = 'default',
    int limit = 20,
    String? workerId,
    Duration staleRunningAfter = const Duration(minutes: 15),
  }) async {
    await _store.recoverStaleRunning(
      staleAfter: staleRunningAfter,
      now: DateTime.now(),
    );

    final jobs = await _store.nextRunnable(
      queue: queue,
      limit: limit,
      now: DateTime.now(),
    );

    var handled = 0;
    for (final job in jobs) {
      final claimed = await _store.claim(job, workerId: workerId);
      if (claimed == null) continue;
      await _runClaimed(claimed, workerId: workerId);
      handled++;
    }
    return handled;
  }

  static void startWorker({
    String queue = 'default',
    int limit = 20,
    String? workerId,
    Duration pollInterval = const Duration(seconds: 10),
    Duration staleRunningAfter = const Duration(minutes: 15),
  }) {
    _workerTimer?.cancel();
    _workerTimer = Timer.periodic(pollInterval, (_) {
      if (_workerRunning) return;
      _workerRunning = true;
      unawaited(
        runOnce(
          queue: queue,
          limit: limit,
          workerId: workerId,
          staleRunningAfter: staleRunningAfter,
        ).whenComplete(() => _workerRunning = false),
      );
    });
  }

  static void stopWorker() {
    _workerTimer?.cancel();
    _workerTimer = null;
    _workerRunning = false;
  }

  static Future<int> tickSchedules({
    int limit = 100,
    DateTime? now,
  }) async {
    final tickAt = now ?? DateTime.now();
    final due = await _store.dueSchedules(now: tickAt, limit: limit);
    var enqueued = 0;

    for (final record in due) {
      final definition = _schedules[record.name];
      if (definition == null || !definition.enabled) {
        await _store.markScheduleTicked(
          record,
          lastRunAt: tickAt,
          nextRunAt: null,
          error: 'No registered schedule definition for ${record.name}',
        );
        continue;
      }

      try {
        await dispatch(
          definition.jobType,
          payload: definition.payload,
          key: definition.jobKey(tickAt),
          runAt: tickAt,
          queue: definition.queue,
          metadata: {
            'schedule': definition.name,
            'scheduledAt': tickAt.toIso8601String(),
          },
        );
        final nextRunAt = definition.nextRunAfter(tickAt, tickAt);
        await _store.markScheduleTicked(
          record,
          lastRunAt: tickAt,
          nextRunAt: nextRunAt,
        );
        enqueued++;
      } catch (error) {
        final nextRunAt = definition.nextRunAfter(record.lastRunAt, tickAt);
        await _store.markScheduleTicked(
          record,
          lastRunAt: record.lastRunAt ?? tickAt,
          nextRunAt: nextRunAt,
          error: error.toString(),
        );
        Log.error(
          'Flint schedule failed name=${record.name}: $error',
          tag: 'jobs',
        );
      }
    }

    return enqueued;
  }

  static void startScheduler({
    Duration tickInterval = const Duration(minutes: 1),
    int limit = 100,
  }) {
    _schedulerTimer?.cancel();
    _schedulerTimer = Timer.periodic(tickInterval, (_) {
      if (_schedulerRunning) return;
      _schedulerRunning = true;
      unawaited(
        tickSchedules(limit: limit).whenComplete(
          () => _schedulerRunning = false,
        ),
      );
    });
  }

  static void stopScheduler() {
    _schedulerTimer?.cancel();
    _schedulerTimer = null;
    _schedulerRunning = false;
  }

  static Future<void> _runClaimed(
    FlintJobRecord record, {
    String? workerId,
  }) async {
    final definition = _registry[record.type];
    final run = await _store.startRun(record, workerId: workerId);

    if (definition == null) {
      final error = 'No Flint job registered for type "${record.type}"';
      await _store.fail(record, error: error, retry: false);
      await _store.finishRun(run, status: FlintJobStatus.failed, error: error);
      Log.warning(error, tag: 'jobs');
      return;
    }

    final context = FlintJobContext(
      store: _store,
      record: record,
      attempt: record.attempts,
    );

    try {
      final timeout = definition.timeout;
      final future = Future<void>.sync(() => definition.handle(context));
      if (timeout == null) {
        await future;
      } else {
        await future.timeout(timeout);
      }

      if (!context.finished) {
        await context.complete();
      }
      await _store.finishRun(
        run,
        status: context.record.status,
        metadata: {'jobStatus': context.record.status},
      );
    } catch (error, stack) {
      final delay = definition.retryDelay(record.attempts);
      final nextRunAt = delay == null ? null : DateTime.now().add(delay);
      await _store.fail(
        record,
        error: error.toString(),
        retry: true,
        nextRunAt: nextRunAt,
      );
      await _store.finishRun(
        run,
        status: FlintJobStatus.failed,
        error: error.toString(),
      );
      Log.error(
        'Flint job failed type=${record.type} id=${record.id}: $error',
        stackTrace: stack,
        tag: 'jobs',
      );
    }
  }

  static String randomWorkerId({String prefix = 'worker'}) {
    final value = Random().nextInt(0x7fffffff).toRadixString(16);
    return '${prefix}_$value';
  }
}
