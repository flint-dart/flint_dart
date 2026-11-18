# Isolate Tasks

Flint isolate tasks are for work that should run away from the main Dart server
isolate.

Use an `IsolateTask` when a piece of work is CPU-heavy, blocking, or expensive
enough that it could slow down HTTP requests, WebSockets, or other app code if
it runs on the main event loop.

Before coding an isolate task in an app, inspect these files:

- `lib/isolate/`
- `lib/isolate/tasks/`
- `docs/jobs-and-workers.md` if the work also needs queueing, retries, or
  schedule state
- `docs/mail.md` if the task sends mail
- `docs/models-and-database.md` if the task reads or writes database data
- `docs/cli.md` for the `--make-isolate` generator

## What An Isolate Is

Dart code normally runs on one isolate. An isolate has its own memory and event
loop. Heavy synchronous work on the main isolate can block the server from
responding quickly.

An `IsolateTask` uses Flint's isolate helper, backed by `worker_manager`, to run
the task logic in a separate isolate:

```dart
class ResizeImageTask extends IsolateTask<String> {
  ResizeImageTask({
    required this.sourcePath,
    required this.outputPath,
  });

  final String sourcePath;
  final String outputPath;

  @override
  Future<String> performTask() async {
    // Heavy file/image work here.
    return outputPath;
  }
}
```

Run it with:

```dart
final done = Completer<String>();

await ResizeImageTask(
  sourcePath: 'storage/uploads/photo.png',
  outputPath: 'storage/processed/photo-small.png',
).perform(
  onDone: done.complete,
  onError: done.completeError,
);

final resizedPath = await done.future;
```

`performTask()` is the method you implement. `perform(...)` is the method you
call to run the task through Flint's isolate helper.

## Generate A Task

Use the CLI:

```bash
dart run flint_dart:flint --make-isolate resize_image
```

Behavior:

- Names may contain letters, numbers, underscores, and hyphens.
- `resize_image` becomes class `ResizeImageTask`.
- The file path becomes `lib/isolate/tasks/resize_image_task.dart`.
- Existing isolate task files are not overwritten.
- The generated class extends `IsolateTask<void>`.
- The generated method is `performTask()`.

Generated shape:

```dart
import 'package:flint_dart/isolate.dart';
import 'package:flint_dart/logs.dart';

class ResizeImageTask extends IsolateTask<void> {
  @override
  Future<void> performTask() async {
    // Heavy or blocking logic here.
    Log.debug('ResizeImageTask running in isolate');
  }
}
```

Change the generic type when the task should produce a value:

```dart
class SumTask extends IsolateTask<int> {
  SumTask(this.a, this.b);

  final int a;
  final int b;

  @override
  Future<int> performTask() async {
    return a + b;
  }
}
```

## IsolateTask API

`IsolateTask<T>` has three important methods:

```dart
abstract class IsolateTask<T> {
  FutureOr<T> performTask();

  Future<void> perform({
    void Function(T result)? onDone,
    void Function(Object error)? onError,
  });

  void dispose();
}
```

`performTask()`:

- contains the actual work
- runs in a separate isolate through `worker_manager`
- may return a value of type `T`
- may throw an error

`perform(...)`:

- initializes the worker manager the first time it is used
- runs `performTask()` in the isolate
- calls `onDone(result)` when the task completes
- calls `onError(error)` when the task fails
- logs the error when no `onError` callback is provided
- returns `Future<void>`, not `Future<T>`

Because `perform(...)` does not return the result directly, use `onDone` when
the caller needs the result.

```dart
final result = Completer<int>();

await SumTask(2, 3).perform(
  onDone: result.complete,
  onError: result.completeError,
);

final value = await result.future;
```

When the caller does not need the result, the callback can be omitted:

```dart
await WarmCacheTask().perform();
```

This still waits for the task to finish. It only discards the task result.

Use `dispose()` only when the app or tool owns the isolate worker lifecycle and
is shutting it down. Do not call `dispose()` after every small task in a running
server, because it disposes the shared worker manager.

## What To Pass Into An Isolate

Isolate memory is separate from the main server isolate. Pass simple,
serializable input values:

- strings
- numbers
- booleans
- lists
- maps
- IDs
- file paths
- plain configuration values

Good:

```dart
await ResizeImageTask(
  sourcePath: upload.path,
  outputPath: outputPath,
).perform();
```

Avoid passing request-scoped or connection-backed objects:

- `Context`
- `Request`
- `Response`
- `FlintWebSocket`
- controller instances
- open database connections
- open file handles
- live streams
- service objects that hold sockets or connection state

Instead of passing a model instance or request object, pass IDs and simple data:

```dart
await GenerateInvoicePdfTask(
  invoiceId: invoice.id,
  outputPath: outputPath,
).perform();
```

If the isolate needs framework configuration, load it inside the isolate task.

```dart
class SendBulkMailTask extends IsolateTask<void> {
  @override
  Future<void> performTask() async {
    MailConfig.load();
    await DB.autoConnect();
    // Send mail or read data.
  }
}
```

## When To Use IsolateTask

Use `IsolateTask` for:

- PDF generation
- image resizing or compression
- video or audio metadata extraction
- parsing large CSV, JSON, or XML files
- hashing or encryption of large payloads
- archive creation or extraction
- CPU-heavy calculations
- expensive cache warmups
- report rendering

Do not use `IsolateTask` only because a function is `async`. Normal async I/O,
such as one database query or one HTTP call, already yields to the event loop.
Use isolates when the work itself would keep the CPU busy or block progress.

## IsolateTask Vs QueueJob

`IsolateTask` and `QueueJob` are different tools.

Use `IsolateTask` when the question is:

```text
Should this work run away from the main Dart isolate?
```

Use `QueueJob` when the question is:

```text
Should this work be saved, retried, scheduled, logged, or processed by a worker?
```

Comparison:

| Need | Use |
| --- | --- |
| Avoid blocking HTTP/WebSocket handling | `IsolateTask` |
| Persist work in the database | `QueueJob` |
| Retry after failure | `QueueJob` |
| Run every few minutes or hours | `QueueJob` plus `FlintSchedule` |
| Process urgent mail outside the request path | `QueueJob` |
| Resize an image during a request | `IsolateTask` |
| Generate a long-running report reliably | `QueueJob`, optionally with `IsolateTask` inside |

Together:

```dart
class GenerateReportJob extends QueueJob {
  @override
  String get type => 'reports.generate';

  @override
  String get queue => 'reports';

  @override
  Future<void> handle(QueueJobContext ctx) async {
    await GenerateReportPdfTask(
      reportId: ctx.payload['reportId'] as String,
      outputPath: ctx.payload['outputPath'] as String,
    ).perform(
      onError: (error) {
        throw StateError('Report isolate failed: $error');
      },
    );

    await ctx.log('Report generated');
  }
}
```

In that example, the `QueueJob` owns durability, retries, logs, and worker
execution. The `IsolateTask` owns CPU isolation.

## Multiple Tasks

Use `IsolateTaskQueue.scheduleTasks(...)` to start several isolate tasks:

```dart
await IsolateTaskQueue.scheduleTasks(
  [
    ResizeImageTask(sourcePath: 'a.png', outputPath: 'a-small.png'),
    ResizeImageTask(sourcePath: 'b.png', outputPath: 'b-small.png'),
  ],
  onDone: (task, result) {
    Log.debug('Task finished: $result');
  },
  onError: (task, error) {
    Log.debug('Task failed: $error');
  },
);
```

Important behavior:

- `scheduleTasks(...)` initializes the worker manager.
- Each task is submitted to `worker_manager`.
- The method returns after tasks are scheduled.
- Completion is reported through `onDone`.
- Errors are reported through `onError`.

If the caller must wait for all tasks, track completion with a `Completer`,
counter, or app-level coordinator.

```dart
final tasks = [
  SumTask(1, 2),
  SumTask(3, 4),
];

final results = <int>[];
final done = Completer<void>();

await IsolateTaskQueue.scheduleTasks(
  tasks,
  onDone: (task, result) {
    results.add(result as int);
    if (results.length == tasks.length && !done.isCompleted) {
      done.complete();
    }
  },
  onError: (task, error) {
    if (!done.isCompleted) done.completeError(error);
  },
);

await done.future;
```

## Using Isolates In Controllers

Controllers should stay request-focused. If a route uses an isolate directly,
keep the route small and pass only safe values into the task.

```dart
class UploadController extends Controller {
  Future<Response> thumbnail() async {
    final data = await req.validate({
      'path': 'required|string',
    });

    final sourcePath = data['path'] as String;
    final outputPath = 'storage/thumbnails/${DateTime.now().millisecondsSinceEpoch}.png';
    final done = Completer<String>();

    await ResizeImageTask(
      sourcePath: sourcePath,
      outputPath: outputPath,
    ).perform(
      onDone: done.complete,
      onError: done.completeError,
    );

    final thumbnailPath = await done.future;

    return res.json({
      'thumbnailPath': thumbnailPath,
    });
  }
}
```

If the route should return immediately and let the work continue, dispatch a
`QueueJob` instead of starting an isolate task directly from the controller.

## Error Handling

Handle errors with `onError`:

```dart
final done = Completer<void>();

await GeneratePdfTask().perform(
  onDone: (_) => done.complete(),
  onError: done.completeError,
);

await done.future;
```

If no `onError` is provided, Flint logs the error through `Log.debug(...)`.
Use `onError` when the caller must return an error response, fail a queue job,
or update a model.

Inside a `QueueJob`, make isolate failures visible to the job system:

```dart
final done = Completer<void>();

await GeneratePdfTask().perform(
  onDone: (_) => done.complete(),
  onError: done.completeError,
);

await done.future;
```

If `done.future` completes with an error, `QueueJob.handle(ctx)` throws and
Flint can record the job failure and retry when attempts remain.

## Mail And Database Inside Isolates

Static configuration and live connections are isolate-local. If a task sends
mail or touches the database, prepare that inside `performTask()`.

```dart
class ExportUsersTask extends IsolateTask<String> {
  ExportUsersTask(this.outputPath);

  final String outputPath;

  @override
  Future<String> performTask() async {
    await DB.autoConnect();

    final users = await User().select(['id', 'email']).get();
    // Write CSV to outputPath.

    return outputPath;
  }
}
```

For mail:

```dart
class SendSummaryMailTask extends IsolateTask<void> {
  @override
  Future<void> performTask() async {
    MailConfig.load();
    await SummaryMail().send();
  }
}
```

## File Organization

Keep each isolate task in its own file:

```text
lib/isolate/tasks/resize_image_task.dart
lib/isolate/tasks/generate_report_pdf_task.dart
lib/isolate/tasks/import_users_csv_task.dart
```

Do not hide heavy work in private controller methods such as
`_resizeImage()` or `_generatePdf()`. Extract a named `IsolateTask` when the
work is heavy enough to need an isolate.

## Testing

Test isolate tasks directly:

```dart
class SumTask extends IsolateTask<int> {
  SumTask(this.a, this.b);

  final int a;
  final int b;

  @override
  Future<int> performTask() async {
    return a + b;
  }
}

void main() {
  test('SumTask returns result', () async {
    final result = Completer<int>();

    await SumTask(2, 3).perform(
      onDone: result.complete,
      onError: result.completeError,
    );

    expect(await result.future, 5);
  });
}
```

For task queues, test that all expected callbacks complete. Do not assume
`scheduleTasks(...)` waits for every task to finish.

## Common Mistakes

- Using an isolate when the work should be a durable `QueueJob`.
- Passing `Context`, `Request`, `Response`, sockets, or open DB connections into
  an isolate task.
- Expecting `perform(...)` to return the task result directly.
- Forgetting to use `onError` when the caller must know the task failed.
- Calling `dispose()` after every task in a long-running server.
- Putting multiple task classes in one file.
- Hiding heavy logic inside private controller methods instead of an
  `IsolateTask`.
- Forgetting that mail config and database connections are isolate-local.

## Review Checklist

When reviewing isolate work:

1. Read `docs/isolate-tasks.md`.
2. Confirm the work is CPU-heavy or blocking enough to need an isolate.
3. Confirm the work does not need durable queue behavior; if it does, use
   `QueueJob` and call the isolate task inside the job.
4. Confirm the task extends `IsolateTask<T>`.
5. Confirm the task implements `performTask()`.
6. Confirm the caller uses `perform(...)`.
7. Confirm results are read through `onDone`.
8. Confirm errors are handled through `onError` when needed.
9. Confirm only simple data, IDs, and paths are passed into the task.
10. Confirm each task lives in its own file under `lib/isolate/tasks`.
