# Jobs And Workers

Flint jobs are for background work that should be saved, retried, scheduled,
or executed outside the HTTP request path.

Use this guide when adding email delivery jobs, report generation jobs,
webhook processing, imports, cleanup tasks, scheduled tasks, or any work that
must survive beyond the current request.

Before coding a job in an app, inspect these files:

- `lib/main.dart`
- `lib/jobs/`
- `lib/config/jobs_registry.dart`
- `lib/mail/` and `docs/mail.md` when the job sends email
- `lib/models/` and `docs/models-and-database.md` when the job reads or writes data
- `bin/worker.dart` when the app already has a worker entrypoint
- `docs/cli.md` for the `jobs-work` command
- `docs/logging.md` before adding job progress logs, worker process logs, or
  error logs

If the task is CPU-heavy, also inspect `docs/isolate-tasks.md`, `lib/isolate/`,
and the generated isolate tasks. Jobs and isolates solve different problems.

## The Names

Use these names carefully:

- `QueueJob`: the base class for one queued/background job.
- `FlintJobs`: the framework facade that registers jobs, dispatches jobs,
  schedules jobs, starts the runtime, and manages the job store.
- `JobsRegistry`: the app-level list of queue jobs and schedules.
- `jobs worker`: the separate running process that polls the queue and executes
  registered `QueueJob` classes.
- `IsolateTask`: a Dart isolate task for heavy work that should not block the
  event loop.

`FlintJob` is deprecated. Existing apps that extend `FlintJob` still compile
for compatibility, but new code should extend `QueueJob`.

Do not teach new apps to extend a plain `Job` class. `Job` is too generic and
can conflict with a domain model such as a hiring board's `Job` model.
`QueueJob` says what the class is: a job that belongs to the queue system.

## Job Vs Worker Vs Isolate

A `QueueJob` is the definition of work:

```dart
class SendOtpJob extends QueueJob {
  @override
  String get type => 'auth.send_otp';

  @override
  Future<void> handle(QueueJobContext ctx) async {
    // Send OTP here.
  }
}
```

The worker is the process that runs jobs. It keeps polling the queue, claims
pending job records, finds the matching `QueueJob` by `type`, and executes
`handle(ctx)`.

An isolate is only a Dart execution mechanism. An isolate can keep CPU-heavy
work away from the server event loop, but it does not automatically give the
work a database record, retries, schedule state, or worker ownership. Use a
`QueueJob` when the work must be durable. Use an `IsolateTask` inside a
`QueueJob` when the durable work also needs CPU isolation.

Common choices:

- Send a welcome email after registration: `QueueJob`.
- Send an OTP without making the request wait for SMTP: `QueueJob`.
- Resize one uploaded image inside the current request: `IsolateTask`.
- Generate a report that may take minutes and must retry if the app restarts:
  `QueueJob`, optionally calling an `IsolateTask` inside `handle(ctx)`.
- Run cleanup every night: `QueueJob` plus `FlintSchedule`.

## Job Files

Put one job class in one file:

```text
lib/jobs/send_otp_job.dart
lib/jobs/send_welcome_mail_job.dart
lib/jobs/generate_report_job.dart
lib/jobs/sync_invoice_status_job.dart
```

Do not add multiple job classes to one file because they are small. Jobs are
operational code. One file should describe one background task clearly.

## Defining A QueueJob

File: `lib/jobs/send_otp_job.dart`

```dart
import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/mail.dart';

import '../mail/otp_mail.dart';

class SendOtpJob extends QueueJob {
  @override
  String get type => 'auth.send_otp';

  @override
  String get queue => 'mail';

  @override
  int get maxAttempts => 5;

  @override
  Duration? retryDelay(int attempt) {
    return Duration(minutes: attempt);
  }

  @override
  Future<void> handle(QueueJobContext ctx) async {
    final email = ctx.payload['email'] as String?;
    final code = ctx.payload['code'] as String?;

    if (email == null || email.isEmpty) {
      await ctx.fail('Missing email for OTP job', retry: false);
      return;
    }

    if (code == null || code.isEmpty) {
      await ctx.fail('Missing OTP code for OTP job', retry: false);
      return;
    }

    MailConfig.load();

    await OtpMail(
      recipientEmail: email,
      code: code,
    ).send();

    await ctx.log('OTP mail sent', metadata: {'email': email});
  }
}
```

Important parts:

- `type` is the stable name used when dispatching the job.
- `queue` lets a worker process focus on a queue such as `default`, `mail`, or
  `reports`.
- `maxAttempts` controls retry count.
- `retryDelay(attempt)` controls when a failed job becomes runnable again.
- `timeout` can stop a job that runs too long.
- `handle(ctx)` receives the job context and runs the actual work.

Keep job types stable. Changing a type without migrating pending records can
leave old records without a registered handler.

## QueueJobContext

`QueueJobContext` gives the job access to the current job record and helper
methods.

Useful members:

- `ctx.record`: the current `FlintJobRecord`.
- `ctx.payload`: mutable job payload copied from the record.
- `ctx.attempt`: the current attempt count.
- `ctx.finished`: whether the job already completed, failed, or released itself.
- `ctx.complete(payload: ...)`: marks the job completed.
- `ctx.fail(error, retry: true)`: marks the job failed and optionally retryable.
- `ctx.release(nextRunAt: ..., reason: ...)`: returns the job to pending for a
  future run.
- `ctx.log(message, metadata: ...)`: writes a job run log.

If `handle(ctx)` returns without calling `complete`, `fail`, or `release`,
Flint automatically completes the job.

Use explicit `ctx.fail(..., retry: false)` for invalid payloads. Retrying a job
with missing required data only repeats the same failure.

Use `ctx.release(...)` when the job cannot continue yet but should not be
treated as an error.

```dart
await ctx.release(
  nextRunAt: DateTime.now().add(const Duration(minutes: 10)),
  reason: 'Report source is not ready yet',
);
```

## Job Logs

Use `ctx.log(...)` for progress that belongs to the job record:

```dart
await ctx.log('Report generation started', metadata: {'reportId': reportId});
await ctx.log('Report generation finished');
```

These messages are stored in the job record metadata under `logs`, so they help
debug one job even after the worker process has moved on.

Use `Log.*(...)` for worker process logs:

```dart
Log.info('Report job completed id=${ctx.record.id}', tag: 'jobs');
```

When a job catches an unexpected exception, log the error and stack trace once,
then fail or rethrow:

```dart
try {
  await GenerateReportAction().call(ctx.payload);
  await ctx.complete();
} catch (error, stack) {
  Log.error(
    'Report job failed id=${ctx.record.id}',
    tag: 'jobs',
    error: error,
    stackTrace: stack,
  );
  await ctx.fail(error);
}
```

Do not log OTP codes, passwords, tokens, cookies, mail bodies, provider secrets,
or full webhook payloads in job metadata or worker logs. Store small identifiers
and safe status details only. Read `docs/logging.md` for log levels and
production log settings.

## Registering Jobs

Create a jobs registry for the app.

File: `lib/config/jobs_registry.dart`

```dart
import 'package:flint_dart/flint_dart.dart';

import '../jobs/send_otp_job.dart';
import '../jobs/send_welcome_mail_job.dart';

class AppJobsRegistry extends JobsRegistry {
  const AppJobsRegistry();

  @override
  Iterable<QueueJob> get jobs => [
        SendOtpJob(),
        SendWelcomeMailJob(),
      ];
}
```

Then pass the registry to the app.

```dart
final app = Flint(
  jobsRegistry: const AppJobsRegistry(),
);
```

When `autoRegisterJobs` is `true`, Flint registers job definitions from
`jobsRegistry` while the app is created. This makes `FlintJobs.dispatch(...)`
able to infer the default queue and max attempts from the registered job.

## Dispatching Jobs

Dispatch a job from a controller, action, service, route handler, or another
job:

```dart
await FlintJobs.dispatch(
  'auth.send_otp',
  queue: 'mail',
  payload: {
    'email': user.email,
    'code': otp,
  },
);
```

Common dispatch options:

- `payload`: JSON-like data passed to `QueueJobContext`.
- `queue`: queue name. If omitted, Flint uses the registered job's `queue`.
- `key`: idempotency key. Reusing the same key returns the existing job record
  instead of creating a duplicate.
- `runAt`: future time when the job becomes runnable.
- `maxAttempts`: override the registered job's `maxAttempts`.
- `metadata`: extra operational data stored with the record.

Use a `key` when the same request might be retried by the browser, mobile app,
or payment provider.

```dart
await FlintJobs.dispatch(
  'billing.sync_invoice',
  key: 'invoice:${invoice.id}:sync',
  payload: {'invoiceId': invoice.id},
);
```

Use `runAt` to delay work:

```dart
await FlintJobs.dispatch(
  'reports.expire_download',
  runAt: DateTime.now().add(const Duration(hours: 24)),
  payload: {'reportId': report.id},
);
```

## Running A Worker

The worker is the process that executes queued jobs.

Create a worker entrypoint.

File: `bin/worker.dart`

```dart
import 'package:my_app/main.dart';

Future<void> main(List<String> args) async {
  await app.runJobsWorker(queue: 'default');
}
```

If the app does not expose a top-level `app`, create the app through the same
factory used by `lib/main.dart`:

```dart
import 'package:my_app/app.dart';

Future<void> main(List<String> args) async {
  final app = createApp();
  await app.runJobsWorker(queue: 'mail');
}
```

Run the worker with:

```bash
dart run flint_dart:flint jobs-work
```

The CLI defaults to `bin/worker.dart`. A different file can be passed with
`--entrypoint` or as a positional path:

```bash
dart run flint_dart:flint jobs-work --entrypoint=tool/mail_worker.dart
dart run flint_dart:flint jobs-work tool/mail_worker.dart
```

`app.runJobsWorker(...)` does this:

- ensures migrations when enabled
- registers schedules from `jobsRegistry`
- starts the jobs runtime
- loads mail config when app mail auto-connection is enabled
- keeps the process alive until shutdown
- stops the jobs runtime on shutdown
- closes the DB connection when Flint opened it

Common options:

```dart
await app.runJobsWorker(
  queue: 'mail',
  limit: 20,
  scheduleLimit: 100,
  pollInterval: const Duration(seconds: 30),
  staleRunningAfter: const Duration(minutes: 15),
  runImmediately: true,
);
```

Use one worker process per queue when an app has very different job types:

```bash
dart run flint_dart:flint jobs-work --entrypoint=bin/mail_worker.dart
dart run flint_dart:flint jobs-work --entrypoint=bin/reports_worker.dart
```

## Worker IDs And Locks

Each worker can have a `workerId`. If no ID is provided, Flint generates one.
When a worker claims a job, the job record is marked running and locked by that
worker. This prevents two workers from executing the same record at the same
time.

If a worker process dies while a job is running, `staleRunningAfter` lets Flint
recover stale running records back to pending so another worker can try them.

Choose a larger `staleRunningAfter` than the longest normal job run time.

## Starting Jobs Inside The App Process

`app.startJobs(...)` starts the jobs runtime inside the current app process.
That can be useful for small local apps, demos, and tests.

For production apps, prefer a dedicated worker process through
`app.runJobsWorker(...)` and the `jobs-work` CLI command. A dedicated worker can
be restarted, scaled, and monitored independently from the HTTP server.

Stop an in-process runtime with:

```dart
app.stopJobs();
```

## Running One Tick

Tests and admin tools can run one job tick directly:

```dart
final handled = await FlintJobs.runOnce(queue: 'default', limit: 10);
```

To process due schedules first and then run jobs:

```dart
final handled = await FlintJobs.runRuntimeOnce(
  queue: 'default',
  limit: 10,
  scheduleLimit: 100,
);
```

Use these in tests and maintenance scripts. A real worker should call
`app.runJobsWorker(...)`.

## Scheduling Jobs

Schedules enqueue jobs when they become due. The schedule does not contain the
business logic; it only says which job type to dispatch and how often.

```dart
class AppJobsRegistry extends JobsRegistry {
  const AppJobsRegistry();

  @override
  Iterable<QueueJob> get jobs => [
        CleanupExpiredSessionsJob(),
      ];

  @override
  Iterable<FlintSchedule> get schedules => const [
        EverySchedule(
          name: 'cleanup-expired-sessions',
          jobType: 'sessions.cleanup_expired',
          every: Duration(hours: 1),
          keyTemplate: 'cleanup_sessions_{yyyy}-{MM}-{dd}_{HH}',
        ),
      ];
}
```

Schedule options:

- `name`: stable schedule name.
- `jobType`: `QueueJob.type` to dispatch.
- `queue`: target queue.
- `payload`: payload passed to the job.
- `keyTemplate`: idempotency key template for each scheduled bucket.
- `enabled`: disables schedule dispatching when false.
- `EverySchedule.every`: interval between runs.
- `EverySchedule.runImmediately`: whether the first run is due immediately.

Templates can use:

- `{yyyy}`
- `{MM}`
- `{dd}`
- `{HH}`
- `{mm}`
- `{bucket}`

Schedules are registered when the jobs runtime starts. Passing
`jobsRegistry: const AppJobsRegistry()` to `Flint(...)` is not enough by itself
to execute schedules; a jobs runtime or worker must run.

## Job Tables

Flint job storage uses framework tables for job records, job runs, and job
schedules. When `jobsRegistry` is configured and
`includeJobTablesInMigrations` is `true`, Flint includes those tables in
migration runs.

The durable job store tracks:

- pending jobs
- running jobs
- completed jobs
- failed jobs
- payload and metadata
- attempt count
- run time
- locks
- schedule state

Do not edit job tables directly unless you are writing a maintenance tool. Use
`FlintJobs.dispatch(...)`, `QueueJobContext`, schedules, and the job store API.

## Mail Jobs

Do not make a user wait for SMTP when the mail is not required to finish the
HTTP request.

For important transactional mail, prefer a `QueueJob`:

```dart
await FlintJobs.dispatch(
  'mail.send_welcome',
  queue: 'mail',
  key: 'welcome:${user.id}',
  payload: {
    'userId': user.id,
    'email': user.email,
  },
);
```

Inside the job, load mail config before sending:

```dart
MailConfig.load();
await WelcomeMail(recipientEmail: email).send();
```

The worker also loads mail config when `autoConnectMail` is enabled, but calling
`MailConfig.load()` inside mail jobs is safe and makes the job easy to run from
tests, tools, or isolated worker entrypoints.

## Jobs And Isolates Together

Use an isolate inside a `QueueJob` when the job is durable and part of the work
is CPU-heavy.

```dart
class GenerateReportJob extends QueueJob {
  @override
  String get type => 'reports.generate';

  @override
  String get queue => 'reports';

  @override
  Future<void> handle(QueueJobContext ctx) async {
    await GenerateReportPdfTask(ctx.payload).perform();
    await ctx.log('Report PDF generated');
  }
}
```

The `QueueJob` gives durability, retry, schedule, and logs. The `IsolateTask`
keeps heavy work away from the event loop.

## Error Handling

If `handle(ctx)` throws, Flint marks the job failed for that attempt and retries
when attempts remain.

Use thrown errors for unexpected failures:

```dart
final invoice = await Invoice().find(invoiceId);
if (invoice == null) {
  throw StateError('Invoice $invoiceId was not found');
}
```

Use `ctx.fail(..., retry: false)` for bad payloads:

```dart
if (invoiceId == null) {
  await ctx.fail('Missing invoiceId', retry: false);
  return;
}
```

Use `ctx.release(...)` for normal waiting:

```dart
if (!providerIsReady) {
  await ctx.release(
    nextRunAt: DateTime.now().add(const Duration(minutes: 5)),
    reason: 'Provider is not ready',
  );
  return;
}
```

## Testing Jobs

Use `FlintMemoryJobStore` in tests so the database is not required:

```dart
late FlintMemoryJobStore store;

setUp(() {
  store = FlintMemoryJobStore();
  FlintJobs.clearRegistry();
  FlintJobs.clearSchedules();
  FlintJobs.useStore(store);
});

tearDown(() {
  FlintJobs.stopRuntime();
  FlintJobs.clearRegistry();
  FlintJobs.clearSchedules();
  FlintJobs.useDatabaseStore();
});
```

Register, dispatch, and run one tick:

```dart
class CountingJob extends QueueJob {
  CountingJob(this.calls);

  final List<Map<String, dynamic>> calls;

  @override
  String get type => 'test.counting';

  @override
  Future<void> handle(QueueJobContext ctx) async {
    calls.add(Map<String, dynamic>.from(ctx.payload));
  }
}

final calls = <Map<String, dynamic>>[];

FlintJobs.register([CountingJob(calls)]);
await FlintJobs.dispatch('test.counting', payload: {'email': 'a@example.com'});

final handled = await FlintJobs.runOnce();

expect(handled, 1);
expect(store.jobs.single.status, FlintJobStatus.completed);
```

Test these behaviors when they matter:

- dispatch creates a pending record
- duplicate keys do not create duplicate jobs
- registered jobs complete
- unknown job types fail clearly
- failed jobs retry until `maxAttempts`
- released jobs wait until `runAt`
- future `runAt` jobs do not run early
- stale running jobs recover after `staleRunningAfter`
- due schedules enqueue one job per bucket

## Common Mistakes

- Extending `FlintJob` in new code. Use `QueueJob`.
- Treating an isolate as a durable job queue.
- Dispatching a job type that is not registered in `JobsRegistry`.
- Changing `QueueJob.type` while old pending records still use the old type.
- Sending important mail through a request path when a queue would be safer.
- Running only the HTTP server and forgetting to run `jobs-work`.
- Registering schedules but not running the jobs runtime.
- Retrying invalid payloads instead of failing them permanently.
- Using one queue for very slow reports and urgent mail.
- Putting many unrelated job classes in one file.

## Review Checklist

When reviewing a job feature:

1. Read `docs/jobs-and-workers.md`.
2. Confirm each job extends `QueueJob`, not deprecated `FlintJob`.
3. Confirm each job class has its own file under `lib/jobs`.
4. Confirm `JobsRegistry.jobs` returns every job class needed by dispatches.
5. Confirm scheduled jobs are listed in `JobsRegistry.schedules`.
6. Confirm the app passes `jobsRegistry` to `Flint(...)`.
7. Confirm a worker entrypoint calls `app.runJobsWorker(...)`.
8. Confirm dispatch calls use stable `type` strings and `key` where needed.
9. Confirm mail jobs load mail config before sending.
10. Confirm jobs that need DB access run with DB connection available.
11. Confirm job logs use `ctx.log(...)` for record history and `Log.*(...)` for
    worker process logs.
12. Confirm tests use `FlintMemoryJobStore` for job behavior.
