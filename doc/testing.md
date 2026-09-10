# Testing Flint Apps

Use this guide when adding or fixing tests for a Flint application. It is
meant to be practical: read the topic docs first, inspect the app shape, then
test the app through the same Flint objects the runtime uses.

Good Flint tests usually focus on app behavior:

- routes accept the right method, path, params, query, body, cookies, and files
- controllers use the bound `Context`, `req`, `res`, and `socket` correctly
- middleware either calls the next handler or intentionally short-circuits
- validators accept only the fields and shapes the feature supports
- storage writes, replaces, deletes, and rejects unsafe paths
- jobs register, dispatch, retry, release, log, and finish predictably
- seeders are ordered, idempotent, and safe to run more than once
- UI components render the expected tree, props, state, and SSR HTML

## Files To Inspect First

Before writing tests, inspect the local app and the related docs:

- `pubspec.yaml` for `test` dependency and lints.
- `lib/main.dart` for app boot options, middleware, routes, jobs, seeders,
  database flags, and SSR settings.
- `test/` for existing app testing style.
- `test/helpers/` for fake requests, fake responses, uploaded files, database
  fakes, and reusable test builders.
- `lib/routes/` and `docs/routing.md` before testing routes.
- `lib/controllers/` and `docs/routing.md` before testing controllers.
- `lib/middlewares/` and `docs/middleware.md` before testing middleware.
- `docs/validation.md` before testing validators and `req.validate(...)`.
- `docs/storage.md` before testing uploads or public files.
- `lib/jobs/`, `lib/config/jobs_registry.dart`, and
  `docs/jobs-and-workers.md` before testing jobs or workers.
- `lib/seeders/`, `lib/config/seeder_registry.dart`, and `docs/seeders.md`
  before testing seed data.
- `lib/ui/`, `docs/frontend-ui.md`, `docs/ui-widgets.md`, and
  `docs/build-and-rendering.md` before testing Flint UI components or SSR.
- `docs/cache.md`, `docs/sessions-and-cookies.md`, `docs/database-api.md`,
  `docs/ai.md`, or `docs/websockets.md` when the feature touches those areas.

Do not guess framework behavior from another framework. Flint tests should use
Flint's `Context`, `Request`, `Response`, `Controller`, `Middleware`,
`QueueJob`, `Seeder`, `Storage`, and Flint UI APIs.

## Test Layout

Keep tests close to the app shape:

```text
test/
  helpers/
    http/
      fake_http_headers.dart
      fake_http_request.dart
      fake_http_response.dart
    storage/
      uploaded_file_for_test.dart
    jobs/
      record_payload_job.dart
    database/
      fake_pg_connection_wrapper.dart
  routes/
    health_route_test.dart
    course_routes_test.dart
  controllers/
    course_controller_test.dart
  middlewares/
    auth_middleware_test.dart
  validators/
    course_payload_validator_test.dart
  storage/
    avatar_storage_test.dart
  jobs/
    send_welcome_email_job_test.dart
  seeders/
    role_seeder_test.dart
  ui/
    course_card_test.dart
    courses_page_ssr_test.dart
```

The one-class-per-file rule still applies in tests. A fake request class,
uploaded file helper, test job, fake database connection, component, page, or
reusable test builder should live in its own file when it is named and reused.

Avoid private reusable helper methods or private fake classes inside a large
test file. Prefer a named helper in its own file:

```text
test/helpers/http/request_for_test.dart
test/helpers/storage/uploaded_file_for_test.dart
test/helpers/jobs/record_payload_job.dart
```

## Commands

Run the full test suite:

```bash
dart test
```

Run one area while working:

```bash
dart test test/routes/course_routes_test.dart
dart test test/controllers/course_controller_test.dart
dart test test/middlewares/auth_middleware_test.dart
dart test test/ui/course_card_test.dart
```

Run analysis after code changes:

```bash
dart analyze
```

The normal testing loop is:

1. Read the related `docs/*.md`.
2. Inspect the app files and existing tests.
3. Add the smallest useful tests around the behavior being changed.
4. Run targeted tests.
5. Run broader tests when the change touches shared routing, middleware,
   database, jobs, validation, storage, or UI rendering.

## HTTP Test Helpers

Most route, controller, request, response, and middleware tests need app-local
HTTP fakes. Create them under `test/helpers/http/` and reuse them.

The fake classes should provide this shape:

- `FakeHttpHeaders`: stores header values, supports `set(...)`, `add(...)`,
  `value(...)`, `[]`, `contentType`, and `contentLength`.
- `FakeHttpResponse`: stores `statusCode`, `headers`, written text, written
  bytes, and a `closed` flag.
- `FakeHttpRequest`: implements `HttpRequest`, exposes `method`, `uri`,
  `headers`, `response`, optional `connectionInfo`, and streams body bytes.
- `utf8Bytes(String value)`: returns UTF-8 bytes for JSON and form body tests.

Application tests should not import the framework package's own `test/helpers`
files. Create app-local fakes, because an installed package does not export its
test helpers.

## Route Tests

Use `Flint.handleRequest(...)` when you want to test routing, path matching,
middleware, and response serialization together.

File: `test/routes/health_route_test.dart`

```dart
import 'package:flint_dart/flint_dart.dart';
import 'package:test/test.dart';

import '../helpers/http/fake_http_request.dart';
import '../helpers/http/fake_http_response.dart';

void main() {
  test('GET /health returns an ok payload', () async {
    final app = Flint(
      withDefaultMiddleware: false,
      autoConnectDb: false,
      autoConnectMail: false,
      enableSwaggerDocs: false,
    );

    app.get('/health', (Context ctx) {
      return ctx.res?.json({'ok': true});
    });

    final raw = FakeHttpRequest(
      method: 'GET',
      uri: Uri.parse('/health'),
    );

    await app.handleRequest(raw);

    final response = raw.response as FakeHttpResponse;
    expect(response.statusCode, 200);
    expect(response.buffer.toString(), contains('"ok":true'));
  });
}
```

Use this style for:

- status codes
- response JSON
- route params such as `/courses/:id`
- query strings
- method matching for `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `QUERY`, and
  custom methods registered through `app.route(...)`
- route-specific middleware attached with `.useMiddleware(...)`
- `RouteGroup.register(Flint app)` integration

For JSON body routes, set the content type and body bytes. In a full test file,
also import `dart:io` for `ContentType`.

```dart
final headers = FakeHttpHeaders()..contentType = ContentType.json;
final raw = FakeHttpRequest(
  method: 'POST',
  uri: Uri.parse('/courses'),
  headers: headers,
  bodyBytes: utf8Bytes('{"title":"Intro to Flint"}'),
);
```

For form routes, use `application/x-www-form-urlencoded` or multipart body
helpers, then assert that the route reads values through `req.input(...)`,
`req.form()`, `req.file(...)`, or `req.validate(...)`.

## Controller Tests

Feature controllers should extend `Controller`. In tests, bind a `Context` to
the controller before calling an action directly.

File: `lib/controllers/health_controller.dart`

```dart
import 'package:flint_dart/flint_dart.dart';

class HealthController extends Controller {
  Future<Response> show() async {
    return res.json({'status': 'ok', 'method': req.method});
  }
}
```

File: `test/controllers/health_controller_test.dart`

```dart
import 'package:flint_dart/flint_dart.dart';
import 'package:test/test.dart';

import '../../lib/controllers/health_controller.dart';
import '../helpers/http/fake_http_request.dart';
import '../helpers/http/fake_http_response.dart';

void main() {
  test('show uses the bound request and response', () async {
    final raw = FakeHttpRequest(
      method: 'GET',
      uri: Uri.parse('/health'),
    );
    final request = Request(raw);
    final response = Response(raw.response, request: request);
    final controller = HealthController()
      ..bind(Context(req: request, res: response));

    await controller.show();

    final rawResponse = raw.response as FakeHttpResponse;
    expect(rawResponse.statusCode, 200);
    expect(rawResponse.buffer.toString(), contains('"status":"ok"'));
    expect(rawResponse.buffer.toString(), contains('"method":"GET"'));
  });
}
```

When testing the route/controller wiring, use `app.controller(...)`:

```dart
final app = Flint(
  withDefaultMiddleware: false,
  autoConnectDb: false,
  autoConnectMail: false,
  enableSwaggerDocs: false,
);
final health = app.controller(HealthController.new);

health.get('/health', (controller) => controller.show());
```

Use direct controller tests for action logic and route tests for URL/middleware
behavior. If a controller action is not registered with `app.controller(...)`,
wrap it with `controller(...)` or `useController(...)` so Flint binds the
current `Context`.

## Middleware Tests

Middleware tests should prove one of two things:

- the middleware calls `next(ctx)` and preserves or changes the response
- the middleware stops the pipeline and returns its own response

File: `test/middlewares/api_key_middleware_test.dart`

```dart
import 'dart:io';

import 'package:flint_dart/flint_dart.dart';
import 'package:test/test.dart';

import '../../lib/middlewares/api_key_middleware.dart';
import '../helpers/http/fake_http_headers.dart';
import '../helpers/http/fake_http_request.dart';
import '../helpers/http/fake_http_response.dart';

void main() {
  test('valid API key reaches the next handler', () async {
    final headers = FakeHttpHeaders()..set('x-api-key', 'test-key');
    final raw = FakeHttpRequest(
      method: 'GET',
      uri: Uri.parse('/secure'),
      headers: headers,
    );
    final request = Request(raw);
    final response = Response(raw.response, request: request);
    final middleware = ApiKeyMiddleware(expectedKey: 'test-key');

    final handler = middleware.handle((Context ctx) {
      return ctx.res?.send('next', status: HttpStatus.accepted);
    });

    await handler(Context(req: request, res: response));

    final rawResponse = raw.response as FakeHttpResponse;
    expect(rawResponse.statusCode, HttpStatus.accepted);
    expect(rawResponse.buffer.toString(), 'next');
  });

  test('missing API key stops the pipeline', () async {
    final raw = FakeHttpRequest(
      method: 'GET',
      uri: Uri.parse('/secure'),
    );
    final request = Request(raw);
    final response = Response(raw.response, request: request);
    final middleware = ApiKeyMiddleware(expectedKey: 'test-key');
    var reachedNext = false;

    final handler = middleware.handle((Context ctx) {
      reachedNext = true;
      return ctx.res?.send('next');
    });

    await handler(Context(req: request, res: response));

    final rawResponse = raw.response as FakeHttpResponse;
    expect(reachedNext, isFalse);
    expect(rawResponse.statusCode, HttpStatus.unauthorized);
  });
}
```

For built-in middleware, assert the observable behavior:

- `LoggerMiddleware`: capture logs and verify secrets are redacted.
- `CorsMiddleware`: assert `Access-Control-*` headers and preflight behavior.
- `CacheMiddleware`: assert `Cache-Control` only on cacheable methods.
- `ETagMiddleware`: assert `ETag` and `304 Not Modified` behavior.
- session middleware: assert session cookies and persisted session values.

Use `Context ctx` in middleware examples. For WebSocket middleware, create a
context with `socket: flintWebSocket` and assert behavior through `ctx.socket`.

## Validator Tests

Use `Validator.validate(...)` to unit-test a reusable validation rule map or
validator object without an HTTP request.

File: `test/validators/course_payload_validator_test.dart`

```dart
import 'package:flint_dart/exception.dart';
import 'package:flint_dart/flint_dart.dart';
import 'package:test/test.dart';

void main() {
  test('course payload accepts valid data', () async {
    final data = <String, dynamic>{
      'title': 'Intro to Flint',
      'status': 'draft',
      'price': 25,
    };

    await Validator.validate(data, {
      'title': 'required|string|min:3|max:120',
      'status': 'required|in:draft,published',
      'price': 'int|min:0',
    });
  });

  test('course payload rejects unknown fields', () async {
    await expectLater(
      Validator.validate(
        {'title': 'Intro', 'adminOnly': true},
        {'title': 'required|string'},
      ),
      throwsA(
        isA<ValidationException>().having(
          (error) => error.errors['adminOnly']?.first,
          'adminOnly error',
          contains('not allowed'),
        ),
      ),
    );
  });
}
```

Use `req.validate(...)` when the behavior depends on request input merging:
path params, query params, JSON body, form body, multipart fields, and uploaded
files.

```dart
final headers = FakeHttpHeaders()..contentType = ContentType.json;
final raw = FakeHttpRequest(
  method: 'PATCH',
  uri: Uri.parse('/courses/42?preview=true'),
  headers: headers,
  bodyBytes: utf8Bytes('{"title":"Updated title"}'),
);
final request = Request(raw, params: {'id': '42'});

final data = await request.validate({
  'id': 'required|string',
  'preview': 'bool',
  'title': 'required|string|min:3',
});

expect(data['id'], '42');
expect(data['title'], 'Updated title');
```

Remember that `validate(...)` rejects unknown scalar fields. If a route accepts
`/:id`, include `id` in the rule map.

## Storage Tests

`Storage` writes under the app's current working directory. In tests, move
`Directory.current` to a temporary directory, then restore it in `tearDown`.

File: `test/helpers/storage/uploaded_file_for_test.dart`

```dart
import 'dart:convert';

import 'package:flint_dart/flint_dart.dart';

UploadedFile uploadedFileForTest(String filename, String content) {
  final bytes = utf8.encode(content);
  return UploadedFile(
    fieldName: 'file',
    filename: filename,
    contentType: 'text/plain',
    size: bytes.length,
    content: Stream<List<int>>.fromIterable([bytes]),
  );
}
```

File: `test/storage/avatar_storage_test.dart`

```dart
import 'dart:io';

import 'package:flint_dart/flint_dart.dart';
import 'package:test/test.dart';

import '../helpers/storage/uploaded_file_for_test.dart';

void main() {
  late Directory previousDirectory;
  late Directory tempDir;

  setUp(() async {
    previousDirectory = Directory.current;
    tempDir = await Directory.systemTemp.createTemp('app_storage_test_');
    Directory.current = tempDir.path;
  });

  tearDown(() async {
    Directory.current = previousDirectory.path;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('creates an uploaded file and returns a public URL', () async {
    final url = await Storage.create(
      uploadedFileForTest('avatar.png', 'image-bytes'),
      subdirectory: 'profiles',
    );

    expect(url, startsWith('/profiles/'));
    expect(await File('public${url.replaceAll('/', Platform.pathSeparator)}')
        .exists(), isTrue);
  });

  test('rejects unsafe storage paths', () async {
    expect(
      () => Storage.create(
        uploadedFileForTest('avatar.png', 'image-bytes'),
        subdirectory: '../private',
      ),
      throwsArgumentError,
    );
  });
}
```

Test the storage behavior your feature depends on:

- upload creation
- old-file deletion when replacing uploads
- explicit deletion
- filename sanitization
- unsafe path rejection
- allowed file size, extension, MIME type, and authorization checks before
  calling `Storage.create(...)`

## Job Tests

New jobs should extend `QueueJob`. Do not create new `FlintJob` classes; that
name is deprecated compatibility.

For queue lifecycle tests, use `FlintJobs` with a test store. The framework's
package tests use `FlintMemoryJobStore` from the internal job store file. That
is acceptable for framework-level tests and can be useful in app tests, but keep
the import limited to tests only.

File: `test/helpers/jobs/record_payload_job.dart`

```dart
import 'package:flint_dart/jobs.dart';

class RecordPayloadJob extends QueueJob {
  RecordPayloadJob(this.calls);

  final List<Map<String, dynamic>> calls;

  @override
  String get type => 'RECORD_PAYLOAD';

  @override
  Future<void> handle(QueueJobContext ctx) async {
    calls.add(Map<String, dynamic>.from(ctx.payload));
    ctx.payload['handled'] = true;
    await ctx.log('Payload recorded');
  }
}
```

File: `test/jobs/record_payload_job_test.dart`

```dart
import 'package:flint_dart/jobs.dart';
import 'package:flint_dart/src/jobs/flint_job_store.dart'
    show FlintMemoryJobStore;
import 'package:test/test.dart';

import '../helpers/jobs/record_payload_job.dart';

void main() {
  late FlintMemoryJobStore store;

  setUp(() {
    store = FlintMemoryJobStore();
    FlintJobs.clearRegistry();
    FlintJobs.clearSchedules();
    FlintJobs.useStore(store);
  });

  tearDown(() {
    FlintJobs.stopWorker();
    FlintJobs.stopScheduler();
    FlintJobs.clearRegistry();
    FlintJobs.clearSchedules();
    FlintJobs.useDatabaseStore();
  });

  test('dispatches and handles a queued job', () async {
    final calls = <Map<String, dynamic>>[];
    FlintJobs.register([RecordPayloadJob(calls)]);

    await FlintJobs.dispatch(
      'RECORD_PAYLOAD',
      payload: {'userId': 'user-1'},
    );
    final handled = await FlintJobs.runOnce();

    expect(handled, 1);
    expect(calls, [
      {'userId': 'user-1'},
    ]);
    expect(store.jobs.single.status, FlintJobStatus.completed);
    expect(store.jobs.single.payload['handled'], isTrue);
  });
}
```

Job tests should cover:

- registration through `FlintJobs.register(...)` or `JobsRegistry`
- `dispatch(...)` payload, queue, key, `runAt`, and max attempts
- idempotent dispatch with the same key
- `runOnce(...)` completion
- thrown errors, retry count, and final failed state
- `ctx.release(...)` for delayed retry or waiting behavior
- `ctx.log(...)` for job logs that explain important work
- schedules through `FlintJobs.schedule(...)` and
  `FlintJobs.tickSchedules(...)`
- cleanup of global worker state in `tearDown`

When the app relies on database-backed jobs, add at least one integration test
against a test database or an app-owned fake store that implements the same
behavior. Do not let a test suite accidentally enqueue production jobs.

## Seeder Tests

Seeder tests should prove order, idempotence, and database effects. A seeder
must be safe to run again, because `autoSeed`, local setup, CI setup, and manual
`flint seed` can run seeders repeatedly.

For simple seeders, test the seeder class directly:

```dart
await RoleSeeder().run();
final roles = await Role().all();
expect(roles.map((role) => role.name), containsAll(['admin', 'member']));
```

For registry or runner behavior, use `runSeeders(...)`:

```dart
final calls = <String>[];

await runSeeders(
  [
    FirstSeeder(calls),
    SecondSeeder(calls),
  ],
  closeConnection: false,
);

expect(calls, ['first', 'second']);
```

When a seeder touches the database:

- use a test database, transaction rollback, or a fake DB wrapper
- call `DB.overrideConnection(...)` only with a test connection
- restore or close DB state in `tearDown`
- assert that running the seeder twice does not duplicate rows
- assert required records by business keys, not by random auto IDs
- test registry order when one seeder depends on another

Keep test seeders and fake DB wrappers in their own files if they are reused.

## UI Component Tests

Use `package:flint_dart/flint_ui_core.dart` for normal component tests. It
gives tests access to Flint UI primitives without mounting a browser app.

File: `test/ui/save_button_test.dart`

```dart
import 'package:flint_dart/flint_ui_core.dart';
import 'package:test/test.dart';

void main() {
  test('save button exposes loading and accessibility props', () {
    final button = Button(
      child: 'Save',
      loading: true,
      tone: Tone.success,
    );

    expect(button.props['disabled'], true);
    expect(button.props['aria-busy'], 'true');
    expect(button.children.first, isA<Spinner>());
  });
}
```

Use `package:flint_dart/flint_ui_server.dart` when the test is specifically
about server rendering, page registry output, escaped HTML, generated markup, or
`res.page(...)` behavior.

File: `test/ui/course_card_ssr_test.dart`

```dart
import 'package:flint_dart/flint_ui_server.dart';
import 'package:test/test.dart';

import '../../lib/ui/components/course_card.dart';

void main() {
  test('course card renders title and status as HTML', () {
    final html = const FlintServerRenderer().render(
      CourseCard(
        title: 'Intro to Flint',
        status: 'published',
      ),
    );

    expect(html, contains('Intro to Flint'));
    expect(html, contains('published'));
  });
}
```

File: `test/ui/courses_page_ssr_test.dart`

```dart
import 'package:flint_dart/flint_ui_server.dart';
import 'package:test/test.dart';

import '../../lib/ui/pages/courses_page.dart';

void main() {
  test('renders the courses page through the page registry', () {
    final registry = FlintComponentRegistry({
      'CoursesPage': (props) => CoursesPage(),
    });

    final html = const FlintServerRenderer().renderPage(
      registry,
      'CoursesPage',
    );

    expect(html, contains('<main'));
    expect(html, contains('Courses'));
  });
}
```

For forms and state, test the controller or signal directly:

```dart
final form = useForm({'email': 'ada@example.com'});

form.setField('email', 'grace@example.com');

expect(form.string('email'), 'grace@example.com');
```

```dart
final count = StateSignal<int>(0);
final values = <int>[];
final cancel = count.listen(values.add, fireImmediately: true);

count.value = 1;
cancel();

expect(values, [0, 1]);
```

UI tests should cover:

- component props and children
- accessibility props such as labels, `aria-*`, and disabled/loading states
- `DartStyle`, `Style`, scoped styles, and style override order
- forms, field errors, controllers, and submit state
- tables and charts with empty, loading, and populated data
- overlays opening and closing
- navigation links and route data
- browser storage wrappers without reading server-only APIs
- SSR output for pages rendered by the server

Browser-only behavior should be separated from VM component tests. Component
tests can assert handlers exist; end-to-end browser tests can click, type, and
observe DOM changes when the app has a browser test setup.

## Request, Response, Session, And Cache Tests

Use request and response tests when a feature depends on lower-level helpers:

- `req.param(...)`, `req.queryParam(...)`, `req[...]`
- `await req.json()`, `await req.form()`, `await req.body()`,
  `await req.rawBody()`, and `await req.allInput()`
- `await req.file(...)`, `await req.files(...)`, and upload helpers
- `req.cookies`, `req.bearerToken`, `req.authToken`, `await req.user`
- `res.status(...).json(...)`, `res.send(...)`, `res.respond(...)`,
  `res.setCookie(...)`, `res.clearCookie(...)`
- `res.cachePublic(...)`, `res.cachePrivate(...)`, `res.noStore()`, and
  `res.revalidate()`

For sessions, use fake cookies and assert persisted session data through the
configured session store. For cache, prefer a `MemoryCacheStore` or temporary
`FileCacheStore` in tests, and assert both the cached value and the expiration
behavior your feature needs.

## Database Tests

Database tests should avoid production state. Use one of these approaches:

- a dedicated test database configured through test environment variables
- a transaction per test with rollback
- a fake DB wrapper for runner or query-normalization behavior
- model-level tests with temporary table data and cleanup

Always use parameterized queries, `QueryBuilder`, or model methods. Never build
SQL by interpolating request input in app code or tests.

For the secure Database API, read `docs/database-api.md` and test:

- exposed resource names
- allowed operations
- allowed fields
- resource policies
- owner or tenant filtering
- validation errors
- rejected unauthorized reads and writes

## WebSocket Tests

For WebSocket handlers and middleware, use a fake `WebSocket` wrapped by
`FlintWebSocket`, then create a context with `socket: socket`.

Test:

- connection guards
- message parsing
- room join and leave behavior
- broadcasts to expected sockets only
- cleanup on close
- controller actions that access `controller.socket`

Use `app.websocket('/chat', (Context ctx) {})` in examples and new code. The
context shape lets HTTP and socket middleware share the same request-scoped
storage and auth checks.

## What Not To Test

Avoid tests that only repeat Flint internals. Do not test that Dart maps work,
that `expect(...)` works, or that Flint's own router can match a basic route
unless your app wiring depends on that route.

Do test:

- your route registration
- your controller decisions
- your middleware guards
- your validation rules
- your database/resource policy
- your job side effects
- your seeder data contract
- your UI output and state behavior
- your security boundaries

## Review Checklist

Before finishing a test change, check:

- Each reusable class, component, fake, job, seeder, and helper has its own
  file.
- New code uses `Context ctx`, `req`, `res`, and `app.controller(...)` in the
  current Flint style.
- Responses use instance methods such as `res.json(...)` and `res.send(...)`.
- Validators include path params and reject unknown input.
- Storage tests use a temporary working directory and restore it.
- Job tests reset `FlintJobs` global registry, schedules, worker, scheduler,
  and store in `tearDown`.
- Seeder tests prove idempotence and do not leave dirty database state.
- UI tests import `flint_ui_core.dart` or `flint_ui_server.dart` for the right
  purpose.
- No test logs, fixtures, or assertions expose passwords, tokens, OTPs,
  cookies, authorization headers, or production credentials.
