# Common Patterns

This guide collects the Flint patterns that appear across most applications.
Use it after `docs/getting-started.md` and before editing app code when the task
is not tied to one narrow topic.

Before coding, inspect the local app:

- `lib/main.dart` for the `Flint(...)` app, global middleware, routes, static assets, and `listen(...)`.
- `lib/routes/` for `RouteGroup` classes.
- `lib/controllers/` for request-scoped controllers.
- `lib/models/` for `Model<T>` classes and `Table` definitions.
- `lib/config/database_api.dart` for Database API resources, if the app exposes model resources.
- `lib/seeders/` and `lib/config/seeder_registry.dart` for seed data.
- `lib/jobs/` and `lib/config/jobs_registry.dart` for queue jobs, workers, and schedules.
- `lib/isolate/` for CPU-heavy or blocking isolate tasks.
- `lib/middlewares/` for guards and request pipeline behavior.
- `docs/logging.md` before adding request logs, job logs, error logs, or
  committed logging calls.
- `docs/testing.md` before adding route, controller, middleware, validator,
  storage, job, seeder, or UI component tests.
- `lib/config/ai.dart`, `lib/ai/`, and `docs/ai.md` before changing AI
  providers, agents, tools, workflows, memory, or persistence.
- `docs/sessions-and-cookies.md` before changing sessions, cookies, flash messages, or browser auth session storage.
- `public/` and `docs/storage.md` for public uploaded files.
- `lib/services/` or `lib/actions/` for business workflows.
- `lib/mail/`, `lib/mail/views/`, `docs/mail.md`, and
  `docs/templates.md` when the feature sends email or renders HTML templates.
- `lib/ui/` and `docs/ui-widgets.md` for Flint fullstack frontend code,
  components, forms, buttons, layouts, overlays, tables, charts, storage,
  navigation, and state.
- `docs/build-and-rendering.md` before changing `flint build`, `flint web`, browser entrypoints, generated bundles, page registry behavior, or SSR.
- `docs/deployment.md` before changing Docker, production startup, environment variables, deploy scripts, or worker process setup.
- `docs/routing.md`, `docs/middleware.md`, `docs/logging.md`, `docs/testing.md`, `docs/validation.md`, `docs/models-and-database.md`, `docs/database-api.md`, `docs/ai.md`, `docs/seeders.md`, `docs/jobs-and-workers.md`, `docs/isolate-tasks.md`, `docs/sessions-and-cookies.md`, `docs/templates.md`, `docs/cache.md`, `docs/storage.md`, `docs/security-and-utilities.md`, `docs/frontend-ui.md`, `docs/ui-widgets.md`, `docs/build-and-rendering.md`, and `docs/deployment.md` when the task touches those areas.

## One Reusable Thing Per File

The most important Flint application pattern is simple: every meaningful,
reusable thing gets its own Dart file.

This applies to backend and frontend code:

- models
- controllers
- route groups
- middleware
- actions and services
- queue jobs
- isolate tasks
- DTOs, resources, presenters, and view models
- policies, validators, and exceptions
- mail classes
- Flint UI pages
- Flint UI sections
- Flint UI components
- state holders and browser helpers
- top-level helper functions that return `View`, `Node`, `FlintNode`, or `FlintComponent`

Use snake_case file names that match the class or helper responsibility:

```text
lib/models/course.dart
lib/controllers/course_controller.dart
lib/routes/course_routes.dart
lib/services/courses/create_course_action.dart
lib/services/courses/publish_course_action.dart
lib/middlewares/role_middleware.dart
lib/config/ai.dart
lib/ai/agents/ticket_triage_agent.dart
lib/ai/tools/ticket_summary_tool.dart
lib/ai/workflows/support_reply_workflow.dart
lib/jobs/send_course_created_mail_job.dart
lib/isolate/tasks/generate_course_report_task.dart
lib/mail/course_created_mail.dart
lib/ui/pages/courses_page.dart
lib/ui/sections/course_list_section.dart
lib/ui/components/course_card.dart
lib/ui/helpers/course_empty_state.dart
```

Do not add a second class, component, section, or reusable helper to an existing
file because the new thing feels small. Small files are good when each file has
one reason to change.

## Private Helper Methods

Do not hide feature behavior inside private methods on controllers, pages, or
large classes.

Avoid this shape:

```dart
class CourseController extends Controller {
  Future<Response> store() async {
    final data = await req.validate({'title': 'required|string'});
    final course = await _createCourse(data);
    await _sendCourseCreatedMail(course);
    return res.status(201).json({'data': course});
  }

  Future<Course> _createCourse(Map<String, dynamic> data) async {
    final course = await Course().create(data);
    if (course == null) {
      throw Exception('Course could not be created');
    }
    return course;
  }

  Future<void> _sendCourseCreatedMail(Course course) async {}
}
```

Prefer named classes in their own files:

File: `lib/services/courses/create_course_action.dart`

```dart
import '../../models/course.dart';

class CreateCourseAction {
  Future<Course> call(Map<String, dynamic> data) async {
    final course = await Course().create(data);
    if (course == null) {
      throw Exception('Course could not be created');
    }
    return course;
  }
}
```

File: `lib/services/courses/send_course_created_mail_action.dart`

```dart
import '../../mail/course_created_mail.dart';
import '../../models/course.dart';

class SendCourseCreatedMailAction {
  Future<void> call(Course course) async {
    await CourseCreatedMail(course).send();
  }
}
```

File: `lib/controllers/course_controller.dart`

```dart
import 'package:flint_dart/flint_dart.dart';

import '../services/courses/create_course_action.dart';
import '../services/courses/send_course_created_mail_action.dart';

class CourseController extends Controller {
  Future<Response> store() async {
    final data = await req.validate({'title': 'required|string'});
    final course = await CreateCourseAction().call(data);
    await SendCourseCreatedMailAction().call(course);
    return res.status(201).json({'data': course});
  }
}
```

The controller now reads like a workflow. The workflow steps can be tested,
reused, replaced, or read without digging through private helpers.

## Thin Route Groups

Use route groups to describe the URL surface. Keep business behavior in
controllers and actions.

File: `lib/routes/course_routes.dart`

```dart
import 'package:flint_dart/flint_dart.dart';

import '../controllers/course_controller.dart';
import '../middlewares/auth_middleware.dart';

class CourseRoutes extends RouteGroup {
  @override
  String get prefix => '/courses';

  @override
  String get tag => 'Courses';

  @override
  void register(Flint app) {
    final courses = app.controller(CourseController.new);

    courses.get('/', (controller) => controller.index());
    courses.post('/', (controller) => controller.store())
        .useMiddleware(AuthMiddleware());
    courses.get('/:id', (controller) => controller.show());
    courses.patch('/:id', (controller) => controller.update())
        .useMiddleware(AuthMiddleware());
    courses.delete('/:id', (controller) => controller.destroy())
        .useMiddleware(AuthMiddleware());
  }
}
```

Route groups should not contain database workflows. They should register routes,
prefixes, tags, and middleware.

## Request-Scoped Controllers

Feature controllers should extend `Controller`. Flint binds the current
`Context` for each request when the route is registered with `app.controller(...)`.

File: `lib/controllers/course_controller.dart`

```dart
import 'package:flint_dart/flint_dart.dart';

import '../models/course.dart';
import '../services/courses/create_course_action.dart';
import '../services/courses/update_course_action.dart';

class CourseController extends Controller {
  Future<Response> index() async {
    final page = int.tryParse(req.queryParam('page') ?? '1') ?? 1;
    final courses = await Course()
        .orderBy('created_at', desc: true)
        .paginate(page, 20);

    return res.json(courses);
  }

  Future<Response> store() async {
    final data = await req.validate({
      'title': 'required|string|min:3',
      'status': 'in:draft,published',
    });

    final course = await CreateCourseAction().call(data);
    return res.status(201).json({'data': course});
  }

  Future<Response> show() async {
    final course = await Course().find(req.param('id'));
    if (course == null) {
      return res.status(404).json({'message': 'Course not found'});
    }
    return res.json({'data': course});
  }

  Future<Response> update() async {
    final input = await req.validate({
      'id': 'required|string',
      'title': 'string|min:3',
      'status': 'in:draft,published',
    });

    final data = {
      if (input.containsKey('title')) 'title': input['title'],
      if (input.containsKey('status')) 'status': input['status'],
    };

    final course = await UpdateCourseAction().call(input['id'], data);
    return res.json({'data': course});
  }

  Future<Response> destroy() async {
    await Course().delete(req.param('id'));
    return res.status(204).send('');
  }
}
```

Inside a controller:

- `context` is the bound `Context`.
- `req` is the request.
- `res` is the response for HTTP actions.
- `socket` is the WebSocket for WebSocket actions.
- `read<T>()` reads typed context data written by middleware.
- `write<T>(value)` writes typed context data for later code.

## Small Inline Routes

Inline `Context` routes are fine for small framework endpoints, health checks,
previews, and simple redirects.

```dart
app.get('/health', (Context ctx) {
  return {'ok': true};
});

app.get('/preview/email/otp', (Context ctx) {
  return ctx.res?.renderEmail(PreviewOtpMail());
});
```

When a route starts validating input, touching models, sending mail, or making
several decisions, move it into a controller and action classes.

## Request Input

Use the narrowest request helper that matches the source of the data.

```dart
final id = req.param('id');
final page = req.queryParam('page');
final body = await req.json();
final form = await req.form();
final file = await req.file('avatar');
final input = await req.allInput();
```

Common request helpers:

- `req.param('id')` reads a route parameter.
- `req.queryParam('page')` reads a URL query parameter.
- `req['id']` checks route params first, then query params.
- `req.input('email')` reads one value from normalized input.
- `req.allInput()` merges query, body/form fields, files, and route params.
- `req.body()` returns the raw body as text.
- `req.rawBody()` returns cached raw bytes for custom decoders or signature checks.
- `req.json()` parses a JSON object body.
- `req.form()` parses URL-encoded or multipart form fields.

`req.get('key')` is request-scoped storage, not query input. Use
`req.queryParam(...)`, `req.input(...)`, or `req.allInput()` for incoming data.

## Validation

Prefer `req.validate(...)` before using user input.

```dart
final data = await req.validate({
  'email': 'required|email',
  'password': 'required|string|min:8|confirmed',
});
```

`validate(...)` reads normalized input. It can validate route params, query
params, JSON body fields, form fields, and uploaded files. It throws
`ValidationException`; `ExceptionMiddleware` turns that into a JSON response for
HTTP requests.

Because route params are part of normalized input, an `/:id` route that calls
`req.validate(...)` should include `id` in its rules.

Use app-specific validator classes when validation rules are reused or become
long.

File: `lib/validators/create_course_validator.dart`

```dart
class CreateCourseValidator {
  Map<String, String> get rules => {
        'title': 'required|string|min:3',
        'status': 'in:draft,published',
      };
}
```

Controller usage:

```dart
final data = await req.validate(CreateCourseValidator().rules);
```

## Responses

Use response instance methods from `ctx.res` or controller `res`.

```dart
return res.json({'ok': true});
return res.status(201).json({'data': course});
return res.status(404).json({'message': 'Not found'});
return res.send('hello');
return res.redirect('/login');
return res.back(fallback: '/');
return res.view('emails.welcome', data: {'name': 'Ada'});
return res.page('Dashboard', props: {'title': 'Dashboard'});
```

Handlers may also return data directly:

```dart
app.get('/health', (Context ctx) {
  return {'ok': true};
});
```

Returned `Model` instances and objects with `toMap()` or `toJson()` are sent as
JSON. Other values are written through the response instance's `respond(...)`
behavior, which infers JSON, HTML, or plain text.

After `res.send(...)`, `res.json(...)`, `res.respond(...)`, `res.view(...)`, or
`res.page(...)`, the response is considered handled. Return it and do not write
to the response again later.

## JSON Resource Objects

When a response shape is reused, create a small resource or presenter class in
its own file. Do not rebuild the same map in many controllers.

File: `lib/resources/course_resource.dart`

```dart
import '../models/course.dart';

class CourseResource {
  CourseResource(this.course);

  final Course course;

  Map<String, dynamic> toMap() {
    return {
      'id': course.id,
      'title': course.title,
      'status': course.status,
      'createdAt': course.createdAt?.toIso8601String(),
    };
  }
}
```

Controller usage:

```dart
return res.json({'data': CourseResource(course).toMap()});
```

For simple one-off responses, inline maps are fine. Extract a resource when the
shape is reused by several routes, needs computed fields, or conceals sensitive
attributes.

## Models In JSON

The response instance method `res.json(...)` recursively converts:

- `DateTime` to ISO strings
- `Model` to `toMap()`
- lists and maps recursively
- custom objects through `toMap()` or `toJson()` when present
- `Exception` values to an error map

This is why a controller can return model results directly:

```dart
final courses = await Course().orderBy('created_at', desc: true).get();
return res.json({'data': courses});
```

If a field should not be exposed, conceal it on the model or return a resource
object with the exact API shape.

## Model Query Patterns

Use model methods for normal CRUD:

```dart
final course = await Course().find(id);
final firstDraft = await Course().where('status', 'draft').first();
final published = await Course().where('status', 'published').get();
final page = await Course().orderBy('created_at', desc: true).paginate(1, 20);
final count = await Course().where('status', 'published').count();
```

Creation:

```dart
final course = await Course().create({
  'title': data['title'],
  'status': data['status'] ?? 'draft',
});
```

Update by primary key:

```dart
final course = await Course().update(
  id: id,
  data: {
    'title': data['title'],
    'status': data['status'],
  },
);
```

Delete by primary key:

```dart
await Course().delete(id);
```

Use `whereOperator`, `whereIn`, `whereNull`, `whereLike`, `whereContains`, and
the matching `orWhere...` helpers when a query needs more than equality.

## Database Safety

Prefer model query helpers or parameterized `DB.query(...)`.

```dart
await DB.query(
  'SELECT * FROM users WHERE email = :email',
  namedParams: {'email': email},
);
```

Do not interpolate untrusted request input into SQL strings.

Avoid this:

```dart
await DB.query("SELECT * FROM users WHERE email = '$email'");
```

`AntiSqlInjectionMiddleware` is only a defense-in-depth tripwire. It does not
replace parameterized queries, authorization, validation, or model constraints.

## Database API Resources

Use `FlintDatabaseApi` only when the app intentionally exposes a model as a
resource. A resource should declare its operations, writable fields, hidden
fields, and policies clearly.

```dart
final api = FlintDatabaseApi(
  config: FlintDatabaseApiConfig(
    auth: const FlintDbAuth.enabled(defaultRole: 'user'),
  ),
  resources: [
    Course.new.resource.readOnly(),
  ],
);

app.databaseApi(api);
```

Do not assume a model is public because it exists. Do not expose sensitive
columns through generic CRUD. Read `docs/database-api.md` before adding or
changing Database API resources.

## Context Extras

Use `Context` extras when middleware computes data that later code needs.

File: `lib/context/current_tenant.dart`

```dart
class CurrentTenant {
  CurrentTenant(this.id);

  final String id;
}
```

File: `lib/middlewares/tenant_middleware.dart`

```dart
import 'package:flint_dart/flint_dart.dart';

import '../context/current_tenant.dart';

class TenantMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Context ctx) async {
      final tenantId = ctx.req.headers['x-tenant'] ?? 'default';
      ctx.write(CurrentTenant(tenantId));
      return await next(ctx);
    };
  }
}
```

Controller usage:

```dart
final tenant = read<CurrentTenant>();
return res.json({'tenant': tenant?.id});
```

Use `ctx.write<T>(...)` and `ctx.read<T>()` for typed data. Use `ctx.setExtra`
and `ctx.getExtra` only when type keys are not enough.

## Auth Checks

For protected routes, prefer middleware. Let middleware load the user once and
write it into `Context`.

File: `lib/middlewares/auth_middleware.dart`

```dart
import 'package:flint_dart/flint_dart.dart';

class AuthMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Context ctx) async {
      final res = ctx.res;
      if (res == null) {
        return await next(ctx);
      }

      final user = await ctx.req.user;
      if (user == null) {
        return res.status(401).json({'message': 'Unauthorized'});
      }

      ctx.write<Map<String, dynamic>>(user);
      return await next(ctx);
    };
  }
}
```

Controller usage:

```dart
final user = read<Map<String, dynamic>>();
```

Important: `req.isAuthenticated` only checks whether `req.user` has already
cached a user on the request. Call `await req.user` first, or let auth
middleware do it.

Read `docs/authentication.md` before adding login, register, current-user,
refresh token, password reset, send OTP, verify OTP, or resend OTP behavior.
Read `docs/sessions-and-cookies.md` before adding login cookies, server
sessions, flash messages, or browser auth session storage.

## File Uploads

Multipart uploads become `UploadedFile` objects.

```dart
if (!await req.hasFile('avatar')) {
  return res.status(422).json({'message': 'Avatar is required'});
}

final upload = await req.file('avatar');
```

Use `Storage` when the app stores public files and needs public URLs:

```dart
final avatarUrl = await Storage.create(
  upload!,
  subdirectory: 'uploads/avatars',
);
```

Read `docs/storage.md` before adding public file storage.

Use `req.storeFile(...)` when a saved filesystem path is enough:

```dart
final path = await req.storeFile(
  'avatar',
  directory: 'public/uploads/avatars',
);
```

Use `req.files(...)`, `req.hasFiles(...)`, `req.allFiles()`, and
`req.storeFiles(...)` for multi-file fields.

Always validate:

- the user is allowed to upload
- the field exists
- file size
- file extension and MIME type
- storage directory
- whether the old file should be deleted or replaced

## Mail And OTP Workflows

Controllers should not build raw SMTP messages. Put mail in a `ViewMailable`
class and call it from an action.

File: `lib/services/auth/send_auth_otp_action.dart`

```dart
import '../../mail/otp_verification_mail.dart';

class SendAuthOtpAction {
  Future<void> call({
    required String email,
    required String otp,
  }) async {
    await OTPVerificationMail(
      recipientEmail: email,
      otp: otp,
    ).send();
  }
}
```

Controller usage:

```dart
final otp = await Auth.generateNumericVerificationCode(email);
await SendAuthOtpAction().call(email: email, otp: otp);
```

For password reset OTPs, use the password reset auth helpers described in
`docs/authentication.md`. For email templates and `{{ ... }}` syntax, read
`docs/mail.md` and `docs/templates.md`.

## Middleware Pattern

Middleware should either pass through with `await next(ctx)` or return a response
to stop the pipeline.

```dart
class ApiKeyMiddleware extends Middleware {
  ApiKeyMiddleware(this.expectedKey);

  final String expectedKey;

  @override
  Handler handle(Handler next) {
    return (Context ctx) async {
      final res = ctx.res;
      if (res == null) {
        return await next(ctx);
      }

      if (ctx.req.headers['x-api-key'] != expectedKey) {
        return res.status(401).json({'message': 'Invalid API key'});
      }

      return await next(ctx);
    };
  }
}
```

Global middleware can run for WebSocket contexts, so check `ctx.res` before
using response methods. See `docs/middleware.md` for order and built-ins.

## Logging Pattern

Use Flint's `Log` helpers instead of committed `print(...)` calls:

```dart
Log.info('Course published', tag: 'courses');
Log.warning('Invalid API key attempt ip=${req.clientIpAddress}', tag: 'security');
```

When catching an exception, include the error and stack trace once, then return
a deliberate response or rethrow so `ExceptionMiddleware` can handle it:

```dart
try {
  await PublishCourseAction().call(req.param('id'));
} catch (error, stack) {
  final id = req.param('id');
  Log.error(
    'Course publish failed id=$id',
    tag: 'courses',
    error: error,
    stackTrace: stack,
  );
  rethrow;
}
```

Use `await ctx.log(...)` inside `QueueJob` handlers for progress that belongs
to that job record. Use `Log.*(...)` for worker process logs.

Read `docs/logging.md` before adding log configuration, custom request logs, job
logs, or error reporting. Do not log cookies, authorization headers, raw request
bodies, passwords, OTP values, session IDs, or tokens.

## Frontend UI Pattern

Flint is fullstack. Frontend source belongs in `lib/ui`.

Use one component, section, page, state holder, or reusable UI helper per file.
Do not hide UI pieces inside private page methods.

Avoid this:

```dart
class CoursesPage extends StatelessComponent {
  @override
  View build() {
    return Column(children: [
      _header(),
      _courseCard('Intro to Dart'),
    ]);
  }

  View _header() => PageHeader(title: 'Courses');

  View _courseCard(String title) => Card(child: Text(title));
}
```

Prefer this file layout:

```text
lib/ui/pages/courses_page.dart
lib/ui/components/course_header.dart
lib/ui/sections/course_list_section.dart
lib/ui/components/course_card.dart
```

File: `lib/ui/pages/courses_page.dart`

```dart
import 'package:flint_dart/ui.dart';

import '../components/course_header.dart';
import '../sections/course_list_section.dart';

class CoursesPage extends StatelessComponent {
  @override
  View build() {
    return Column(
      children: [
        CourseHeader(),
        CourseListSection(),
      ],
    );
  }
}
```

Any extracted method or function that returns `View`, `Node`, `FlintNode`, or
`FlintComponent` should become a standalone component or helper file when it
represents a reusable UI piece.

## Error Handling

Let `ExceptionMiddleware` handle common framework exceptions:

- `ValidationException`
- `AuthException`
- `ForbiddenException`
- `BaseException`
- format, timeout, argument, and database exceptions

Read `docs/security-and-utilities.md` before adding hashing, JWT helpers,
rate-limit middleware, custom exceptions, or `Str` helpers.

Inside app code, prefer clear domain exceptions or response branches.

```dart
final course = await Course().find(req.param('id'));
if (course == null) {
  return res.status(404).json({'message': 'Course not found'});
}
```

Do not catch broad exceptions just to return generic responses unless the route
needs custom recovery. Let the global exception middleware produce the framework
error shape.

## Generated Output

Treat these as generated or derived output:

- `docs/swagger.json`
- `public/assets/js/flint-ui/`
- `public/assets/css/flint-ui/`
- `public/flint-sw.js`
- generated API HTML under `doc/api/`

Do not hand-edit generated output when the source file can be fixed instead.

## Common Mistakes

- Do not put multiple classes in one Dart file.
- Do not add reusable behavior as private `_someThing()` methods.
- Do not put business workflows in route closures.
- Do not instantiate one controller and reuse it across requests; use `app.controller(YourController.new)`.
- Do not use `req.get(...)` for query or body input.
- Do not rely on `req.isAuthenticated` before `await req.user`.
- Do not write to `res` after `res.send(...)`, `res.json(...)`, `res.respond(...)`, `res.view(...)`, or `res.page(...)`.
- Do not attach route middleware with `.use(...)`; use `.useMiddleware(...)`.
- Do not put frontend pages, sections, components, and UI helpers in the same file.
- Do not interpolate request input into SQL.
- Do not expose models through `FlintDatabaseApi` without explicit operations,
  field rules, and policies.
- Do not use `print(...)` for committed application logs; use `Log.*(...)`.
- Do not log cookies, tokens, OTPs, passwords, authorization headers, or raw
  request bodies.
- Do not hand-edit generated docs or built frontend assets.
- Do not use `deploy-globe`, `globe.yaml`, or `globe_cli`; Globe deployment is no longer supported.

## Implementation Checklist

Before finishing a feature:

1. The route group only registers routes, middleware, prefixes, and tags.
2. The controller extends `Controller` and uses bound `req`, `res`, and `context`.
3. Each workflow step that has a name is an action/service in its own file.
4. Each class, middleware, mail class, model, route group, and UI component has its own file.
5. Request data is validated with `req.validate(...)`.
6. Auth and role checks live in middleware or clearly named policy/action files.
7. Models use Flint query helpers or parameterized SQL.
8. Responses use `res.json(...)`, `res.status(...).json(...)`, `res.send(...)`, `res.view(...)`, or `res.page(...)`.
9. Frontend UI under `lib/ui` is split into pages, sections, components, and helpers.
10. Logging uses `Log.*(...)` or job `ctx.log(...)` and does not include secrets.
11. The right topic docs were read before coding.
