import 'package:flint_dart/jobs.dart';
import 'package:flint_dart/src/jobs/flint_job_store.dart';
import 'package:test/test.dart';

class _CountingJob extends FlintJob {
  _CountingJob(this.calls);

  final List<Map<String, dynamic>> calls;

  @override
  String get type => 'COUNTING';

  @override
  Future<void> handle(FlintJobContext ctx) async {
    calls.add(Map<String, dynamic>.from(ctx.payload));
    ctx.payload['handled'] = true;
  }
}

class _FailingJob extends FlintJob {
  _FailingJob({this.max = 2});

  final int max;

  @override
  String get type => 'FAILING';

  @override
  int get maxAttempts => max;

  @override
  Duration? retryDelay(int attempt) => Duration.zero;

  @override
  Future<void> handle(FlintJobContext ctx) async {
    throw StateError('boom ${ctx.attempt}');
  }
}

class _ReleaseJob extends FlintJob {
  @override
  String get type => 'RELEASE';

  @override
  Future<void> handle(FlintJobContext ctx) async {
    await ctx.release(
      nextRunAt: DateTime.now().add(const Duration(hours: 1)),
      reason: 'waiting',
    );
  }
}

void main() {
  late FlintMemoryJobStore store;

  setUp(() {
    store = FlintMemoryJobStore();
    FlintJobs.clearRegistry();
    FlintJobs.useStore(store);
  });

  tearDown(() {
    FlintJobs.stopWorker();
    FlintJobs.clearRegistry();
    FlintJobs.useDatabaseStore();
  });

  group('FlintJobs', () {
    test('dispatch creates a pending durable job record', () async {
      final record = await FlintJobs.dispatch(
        'COUNTING',
        payload: {'hello': 'world'},
      );

      expect(record.type, 'COUNTING');
      expect(record.status, FlintJobStatus.pending);
      expect(record.payload['hello'], 'world');
      expect(store.jobs, hasLength(1));
    });

    test('dispatch with the same key is idempotent', () async {
      final first = await FlintJobs.dispatch('COUNTING', key: 'same-key');
      final second = await FlintJobs.dispatch('COUNTING', key: 'same-key');

      expect(second.id, first.id);
      expect(store.jobs, hasLength(1));
    });

    test('runOnce executes a registered job and records a run', () async {
      final calls = <Map<String, dynamic>>[];
      FlintJobs.register([_CountingJob(calls)]);

      await FlintJobs.dispatch('COUNTING', payload: {'n': 1});
      final handled = await FlintJobs.runOnce();

      expect(handled, 1);
      expect(calls, [
        {'n': 1},
      ]);
      expect(store.jobs.single.status, FlintJobStatus.completed);
      expect(store.jobs.single.payload['handled'], isTrue);
      expect(store.runs.single.status, FlintJobStatus.completed);
    });

    test('unknown job fails clearly', () async {
      await FlintJobs.dispatch('MISSING');
      await FlintJobs.runOnce();

      expect(store.jobs.single.status, FlintJobStatus.failed);
      expect(store.jobs.single.lastError, contains('No Flint job registered'));
      expect(store.runs.single.status, FlintJobStatus.failed);
    });

    test('failed job retries until max attempts', () async {
      FlintJobs.register([_FailingJob(max: 2)]);
      await FlintJobs.dispatch('FAILING');

      await FlintJobs.runOnce();
      expect(store.jobs.single.status, FlintJobStatus.pending);
      expect(store.jobs.single.attempts, 1);

      await FlintJobs.runOnce();
      expect(store.jobs.single.status, FlintJobStatus.failed);
      expect(store.jobs.single.attempts, 2);
      expect(store.runs, hasLength(2));
    });

    test('released job waits for runAt', () async {
      FlintJobs.register([_ReleaseJob()]);
      await FlintJobs.dispatch('RELEASE');

      await FlintJobs.runOnce();
      expect(store.jobs.single.status, FlintJobStatus.pending);
      expect(store.jobs.single.runAt, isNotNull);

      final secondPass = await FlintJobs.runOnce();
      expect(secondPass, 0);
      expect(store.runs, hasLength(1));
    });

    test('future runAt job is not executed early', () async {
      final calls = <Map<String, dynamic>>[];
      FlintJobs.register([_CountingJob(calls)]);

      await FlintJobs.dispatch(
        'COUNTING',
        runAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final handled = await FlintJobs.runOnce();
      expect(handled, 0);
      expect(calls, isEmpty);
      expect(store.jobs.single.status, FlintJobStatus.pending);
    });

    test('stale running job returns to pending', () async {
      final record = await FlintJobs.dispatch('COUNTING');
      final claimed = await store.claim(record, workerId: 'old-worker');
      expect(claimed, isNotNull);

      final recovered = await store.recoverStaleRunning(
        staleAfter: Duration.zero,
        now: DateTime.now().add(const Duration(milliseconds: 1)),
      );

      expect(recovered, 1);
      expect(store.jobs.single.status, FlintJobStatus.pending);
      expect(store.jobs.single.lastError, contains('Recovered stale'));
    });
  });
}
