# Logging

Use this guide when adding application logs, request logs, job logs, error logs,
or deployment log settings. Flint provides a small logging API through `Log` so
app code can produce consistent, filterable output without using `print`.

## Files To Inspect First

Before changing logging behavior, inspect:

- `lib/main.dart` for global middleware such as `LoggerMiddleware`.
- `lib/middlewares/` for custom request, auth, security, and audit middleware.
- `lib/controllers/` and `lib/routes/` for request handlers that catch or report
  errors.
- `lib/jobs/` for `QueueJob` classes and job-specific progress logs.
- `lib/config/jobs_registry.dart` and `bin/worker.dart` for worker setup.
- `.env`, `.env.example`, hosting secrets, or deployment environment settings
  for `LOG_*` values.
- `docs/middleware.md` before changing request pipeline behavior.
- `docs/jobs-and-workers.md` before changing job worker behavior.
- `docs/deployment.md` before changing production log configuration.

## Imports

Most app code can import the main Flint entrypoint:

```dart
import 'package:flint_dart/flint_dart.dart';
```

Focused utility code can import only logging:

```dart
import 'package:flint_dart/logs.dart';
```

`package:flint_dart/flint_dart.dart` already exports `Log`, `LogLevel`, and the
framework middleware that uses them.

## The `Log` API

Use the level helper that matches the event:

```dart
Log.debug('Loading course filters', tag: 'courses');
Log.info('Course published', tag: 'courses');
Log.warning('Rate limit threshold reached', tag: 'security');
Log.error('Course publish failed', tag: 'courses', error: error, stackTrace: stack);
Log.critical('Payment provider is unavailable', tag: 'billing');
```

For dynamic levels, call `Log.log(...)` directly:

```dart
Log.log(
  LogLevel.warning,
  'Webhook signature mismatch',
  tag: 'webhooks',
);
```

`Log.success(...)` also exists for CLI-style success messages. Internally it is
logged at debug level, so do not use it for production events that must remain
visible when `LOG_LEVEL=info` or stricter.

## Log Levels

Choose levels by how much attention the event needs:

- `debug`: local development details, branch decisions, temporary diagnostics,
  and verbose framework work. Hide these in production with `LOG_LEVEL=info`.
- `info`: normal lifecycle events that help operators understand what happened:
  app startup, migration completion, mail queued, job completed, user-visible
  workflow completed.
- `warning`: unexpected but handled conditions: validation abuse, retryable
  provider failures, fallback behavior, stale worker recovery, suspicious paths,
  or ignored webhook events.
- `error`: failed operations that need attention but do not necessarily mean the
  whole process is unhealthy. Include `error` and `stackTrace` when catching an
  exception.
- `critical`: urgent failures such as unavailable core dependencies, repeated
  worker crashes, data-loss risks, or startup failures that should page someone.

Use `tag` to group logs by area. Good tags are short and stable:
`request`, `auth`, `jobs`, `mail`, `db`, `storage`, `websocket`, `security`,
or a feature name such as `courses`.

## Environment Configuration

`Log` reads configuration from `FlintEnv`, so values can come from real
environment variables or from `.env` in local development.

```text
LOG_ENABLED=true
LOG_LEVEL=info
LOG_TO_CONSOLE=true
LOG_TO_FILE=false
LOG_DIR=logs
```

Behavior:

- `LOG_ENABLED=false` disables framework logging.
- `LOG_LEVEL` can be `debug`, `info`, `warning`, `error`, or `critical`.
- `LOG_TO_CONSOLE=true` writes colored console output to stdout.
- `LOG_TO_FILE=true` writes JSON lines to a daily log file.
- `LOG_DIR` controls where file logs are written. The default is `logs`.

When file logging is enabled, Flint writes to:

```text
logs/flint_YYYY-MM-DD.log
```

Each file line is JSON with these fields:

- `timestamp`
- `level`
- `tag`
- `message`
- `error`
- `stack`

`Log` configures itself on first use. If an app wants to create the log
directory during boot, call `await Log.init()` early in `main()`.

```dart
Future<void> main(List<String> args) async {
  await Log.init();

  final app = Flint();
  app.listen(port: env('PORT', 3000));
}
```

## Request Logging Middleware

Use `LoggerMiddleware` when the app needs one log line per request:

```dart
final app = Flint();

app.use(LoggerMiddleware());
```

`Flint` installs `ExceptionMiddleware`, `CookieSessionMiddleware`, and
`StaticFileMiddleware` by default. `LoggerMiddleware` is opt-in, so add it in
`lib/main.dart` when request logs are useful for the app or environment.

The built-in middleware logs:

- request method
- request path
- response status code, or `socket` for WebSocket contexts
- elapsed time in milliseconds
- client IP from `req.clientIpAddress`

It intentionally does not log cookies, raw headers, authorization tokens,
request bodies, passwords, OTP values, session IDs, or full query strings.

For custom request logging, create a middleware class in its own file:

File: `lib/middlewares/request_id_middleware.dart`

```dart
import 'package:flint_dart/flint_dart.dart';

class RequestIdMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Context ctx) async {
      final requestId = ctx.req.headers['x-request-id'] ?? Str.uuid();
      ctx.write<String>(requestId);

      Log.debug(
        'Request started id=$requestId method=${ctx.req.method} path=${ctx.req.path}',
        tag: 'request',
      );

      return next(ctx);
    };
  }
}
```

Keep custom request logs sanitized. If a value came from a header, query string,
cookie, form field, JSON body, uploaded filename, or user profile, treat it as
untrusted and possibly sensitive.

## Error Logs

For route errors, prefer the framework exception flow:

```dart
class CourseController extends Controller {
  Future<Response> show() async {
    final course = await Course().find(req.param('id'));
    if (course == null) {
      throw NotFoundException('Course not found');
    }

    return res.json({'data': course});
  }
}
```

`ExceptionMiddleware` converts known exceptions into HTTP responses. Use it so
controllers do not duplicate response formatting.

When catching an exception because the handler can recover or add useful
context, log once with the error and stack trace:

```dart
class PublishCourseAction {
  Future<void> call(String id) async {
    try {
      await Course().update(id: id, data: {'status': 'published'});
    } catch (error, stack) {
      Log.error(
        'Could not publish course id=$id',
        tag: 'courses',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }
}
```

Do not catch only to log and silently continue unless the failure is truly
optional. Either return a deliberate response, release/fail a job, or rethrow so
Flint's exception path can handle it.

## Job Logs

Queue jobs have two useful logging channels:

- `await ctx.log(...)` stores history on the job record.
- `Log.*(...)` writes process logs for the worker, console, and optional log
  files.

Use `ctx.log(...)` for progress that belongs to a specific job:

```dart
class SendOtpJob extends QueueJob {
  @override
  String get type => 'auth.send_otp';

  @override
  String get queue => 'mail';

  @override
  Future<void> handle(QueueJobContext ctx) async {
    final userId = ctx.payload['userId'] as String?;
    final email = ctx.payload['email'] as String;

    await ctx.log('Preparing OTP email', metadata: {'userId': userId});
    await OtpMail(email).send();
    await ctx.log('OTP email sent', metadata: {'userId': userId});

    await ctx.complete();
  }
}
```

Use `Log.*(...)` for worker-level events that should be visible outside the job
record:

```dart
class SyncInvoiceJob extends QueueJob {
  @override
  String get type => 'billing.sync_invoice';

  @override
  Future<void> handle(QueueJobContext ctx) async {
    try {
      await SyncInvoiceAction().call(ctx.payload);
      Log.info('Invoice sync completed', tag: 'jobs');
      await ctx.complete();
    } catch (error, stack) {
      Log.error(
        'Invoice sync failed for job ${ctx.record.id}',
        tag: 'jobs',
        error: error,
        stackTrace: stack,
      );
      await ctx.fail(error);
    }
  }
}
```

Keep job metadata small and safe. Do not store raw mail bodies, access tokens,
passwords, OTP codes, full payment payloads, or uploaded file contents in
`ctx.log(...)`.

## WebSocket Logs

WebSocket handlers receive `Context ctx` and use `ctx.socket`:

```dart
app.websocket('/chat', (Context ctx) {
  final socket = ctx.socket;
  if (socket == null) return;

  Log.info('Socket connected id=${socket.id}', tag: 'websocket');

  socket.onClose((_) {
    Log.info('Socket closed id=${socket.id}', tag: 'websocket');
  });
});
```

Log connection lifecycle, room joins/leaves, and handler failures. Do not log
entire chat messages, binary payloads, tokens, or private user content unless
the product has an explicit audit requirement and a safe retention policy.

## Logging Instead Of `print`

Use `Log.*(...)` in application and framework code:

- controllers
- route handlers
- middleware
- queue jobs and worker entrypoints
- isolate task callbacks
- mail sending paths
- auth, session, and security code
- storage/upload paths
- database maintenance code
- CLI commands

Avoid `print(...)` because it cannot be filtered by level, cannot be disabled by
`LOG_ENABLED`, cannot write structured file logs, and does not carry a tag,
error object, or stack trace.

`print(...)` is acceptable only for short-lived local debugging that will not be
committed, or for a tiny script whose only purpose is terminal output. In app
code that ships, use `Log`.

## Security Rules

Never log:

- passwords or password hashes
- OTP codes, password reset tokens, email verification tokens, JWTs, API keys,
  OAuth secrets, private keys, or session IDs
- raw `Cookie` or `Authorization` headers
- complete request bodies from login, registration, checkout, webhook, or upload
  routes
- credit card data, bank data, or provider secrets
- private user content unless there is an explicit audit requirement

Prefer stable identifiers over sensitive values:

```dart
Log.warning(
  'Failed login userId=$userId ip=${req.clientIpAddress}',
  tag: 'auth',
);
```

If no stable identifier exists, log a sanitized summary:

```dart
Log.warning(
  'Failed login for unknown account ip=${req.clientIpAddress}',
  tag: 'auth',
);
```

## Production Guidance

For container platforms, keep `LOG_TO_CONSOLE=true` so the platform can collect
stdout logs. Use file logs only when the server has persistent disk and a log
rotation or retention plan.

Common production settings:

```text
APP_ENV=production
APP_DEBUG=false
LOG_ENABLED=true
LOG_LEVEL=info
LOG_TO_CONSOLE=true
LOG_TO_FILE=false
```

For a single server with persistent disk:

```text
LOG_TO_FILE=true
LOG_DIR=/var/log/my_app
```

When queue jobs are deployed, check logs from both processes:

- the HTTP server process for request and route failures
- the jobs worker process for queue execution, retries, and worker errors

Read `docs/deployment.md` before changing how logs are collected in production.

## Common Mistakes

- Using `print(...)` in committed controllers, middleware, jobs, or services.
- Logging cookies, authorization headers, request bodies, passwords, OTPs, or
  tokens.
- Using `debug` for important production events that disappear under
  `LOG_LEVEL=info`.
- Catching an exception only to log it, then hiding the failure from the caller.
- Logging the same error in a controller, service, and middleware.
- Writing large objects into job metadata.
- Enabling file logs in a container without persistent storage or retention.
