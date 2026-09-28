# Validation

Validation in Flint is built around `Request.validate(...)` and
`Validator.validate(...)`.

Use this guide before writing controller actions, route handlers, form submits,
API docs, or middleware that accepts user input. It explains how Flint
validation behaves before implementation.

Before changing validation code in an app, inspect:

- `lib/controllers/` for the action that reads the request.
- `lib/routes/` for path params such as `/:id` and route middleware.
- `lib/middlewares/` for auth, tenant, upload, or validation middleware.
- `lib/models/` before passing validated maps into `create(...)` or `update(...)`.
- `lib/ui/` when frontend forms need to display server validation errors.
- `docs/routing.md` for request input helpers.
- `docs/swagger-and-api-docs.md` for documenting request bodies and `422` errors.

Framework source to inspect when behavior is unclear:

- `lib/src/request.dart`
- `lib/src/validation/validator.dart`
- `lib/src/error/validation_exception.dart`
- `lib/src/middleware/exception_middleware.dart`
- `lib/src/ui/widgets/forms/validation.dart`
- `lib/src/ui/widgets/forms/controllers.dart`

## The Mental Model

`req.validate(...)` does three things:

1. Reads normalized input from the request.
2. Runs the rule map through `Validator.validate(...)`.
3. Returns the validated input map or throws `ValidationException`.

In a controller:

```dart
import 'package:flint_dart/flint_dart.dart';

import '../models/course.dart';

class CourseController extends Controller {
  Future<Response> store() async {
    final data = await req.validate({
      'title': 'required|string|min:3',
      'status': 'in:draft,published',
    });

    final course = await Course().create(data);
    return res.status(201).json({'data': course});
  }
}
```

In a small inline route:

```dart
app.post('/courses', (Context ctx) async {
  final data = await ctx.req.validate({
    'title': 'required|string|min:3',
  });

  return ctx.res?.status(201).json({'data': data});
});
```

Inside `Controller`, use the bound `req`, `res`, and `context` properties.
Register feature controllers with `app.controller(YourController.new)` so Flint
binds the current `Context` for each request.

## Input Sources

`Request.validate(...)` calls `allInput()` before validation.

`allInput()` merges:

- query string values from `req.query`
- JSON body fields
- URL-encoded form fields
- multipart form fields
- uploaded file fields
- route params from `req.params`

Precedence is:

```text
query < body/form fields < uploaded files < route params
```

If the same key appears in multiple places, the later source wins. For example,
on `/courses/:id`, the route param `id` overrides an `id` value sent in the body.

## Validation Is An Allow-List

The rule map is also the list of scalar fields Flint allows.

This passes:

```dart
final data = await req.validate({
  'email': 'required|email',
  'password': 'required|string|min:8',
});
```

This request body fails because `role` is not in the rules:

```json
{
  "email": "ada@example.com",
  "password": "secret123",
  "role": "admin"
}
```

The response will contain a validation error for `role`.

This is intentional. It helps prevent accidental mass assignment, where a user
sends fields the controller did not mean to accept.

## Route Params Count As Input

Because `validate(...)` reads `allInput()`, route params are included. On routes
with path params, include those params in the rule map.

```dart
class CourseController extends Controller {
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

    final course = await Course().update(
      id: input['id'],
      data: data,
    );

    return res.json({'data': course});
  }
}
```

Do not write this on an `/:id` route:

```dart
final data = await req.validate({
  'title': 'string|min:3',
});
```

That can reject the request because the route param `id` is present but not
listed in the rules.

After validation, pass only the fields that should be persisted into the model.
Do not blindly save route params, confirmation fields, or helper-only fields.

## Optional Fields

A field is optional unless it has `required`.

```dart
final data = await req.validate({
  'title': 'string|min:3',
  'status': 'in:draft,published',
});
```

If `title` is missing, no `string` or `min` error is added. If `title` is present,
it must be a `String` and must have at least three characters.

Use optional rules for partial updates. Use `required` when the route cannot do
its job without the field.

## Strict Types

Flint validation does not coerce strings into numbers or booleans.

These rules are strict:

- `int` requires a Dart `int`.
- `double` requires a Dart `double`.
- `bool` requires a Dart `bool`.
- `list` requires a Dart `List`.

JSON can preserve typed values:

```json
{
  "age": 25,
  "price": 10.5,
  "published": true,
  "tags": ["dart", "flint"]
}
```

This can pass:

```dart
await req.validate({
  'age': 'required|int',
  'price': 'required|double',
  'published': 'bool',
  'tags': 'list:string',
});
```

Query strings and URL-encoded forms are strings. `?page=1` is the string `"1"`,
not an `int`.

For query params, validate the string and parse it after validation:

```dart
final input = await req.validate({
  'page': 'string',
  'perPage': 'string',
});

final page = int.tryParse(input['page']?.toString() ?? '1') ?? 1;
final perPage = int.tryParse(input['perPage']?.toString() ?? '20') ?? 20;
```

## Rule Reference

Supported rules:

| Rule | Behavior |
| --- | --- |
| `required` | Value must not be `null`; strings must not be empty. |
| `string` | Non-null value must be a `String`. |
| `int` | Non-null value must be an `int`. |
| `double` | Non-null value must be a `double`. |
| `bool` | Non-null value must be a `bool`. |
| `email` | Non-null value must be a string shaped like an email address. |
| `regex:<pattern>` | Non-null string value must match the regex pattern. |
| `list` | Non-null value must be a `List`. |
| `list:string` | Value must be a list of strings. |
| `list:int` | Value must be a list of integers. |
| `list:double` | Value must be a list of doubles. |
| `list:bool` | Value must be a list of booleans. |
| `confirmed` | Value must match `<field>_confirmation` or `confirm_<field>`. |
| `date` | Value must be a `DateTime` or parse with `DateTime.parse(...)`. |
| `in:a,b,c` | Value string must be one of the listed options. |
| `not_in:a,b,c` | Value string must not be one of the listed options. |
| `min:<n>` | Minimum string length, list length, or numeric value. |
| `max:<n>` | Maximum string length, list length, or numeric value. |

Rules are pipe-separated:

```dart
await req.validate({
  'email': 'required|email',
  'password': 'required|string|min:8|confirmed',
});
```

## `required`

`required` checks for `null` and empty strings.

```dart
await req.validate({
  'title': 'required|string',
});
```

For lists, pair `required` with `list|min:1` when an empty list should fail:

```dart
await req.validate({
  'tags': 'required|list:string|min:1',
});
```

For files, `required` checks that the upload field exists:

```dart
final data = await req.validate({
  'avatar': 'required',
});

final avatar = data['avatar'] as UploadedFile;
```

File size, extension, and content type need app-specific checks.

## `confirmed`

`confirmed` supports these confirmation field names:

- `<field>_confirmation`
- `confirm_<field>`

Example:

```dart
final data = await req.validate({
  'password': 'required|string|min:8|confirmed',
});
```

Accepted payloads:

```json
{
  "password": "secret123",
  "password_confirmation": "secret123"
}
```

```json
{
  "password": "secret123",
  "confirm_password": "secret123"
}
```

`confirmPassword` is not a built-in confirmation name for the `confirmed` rule.
If an app uses `confirmPassword`, validate it as its own field and compare it in
the controller or action.

`req.validate(...)` keeps confirmation fields in the returned map so the
validator can compare them. Remove them before saving user records.

```dart
final input = await req.validate({
  'email': 'required|email',
  'password': 'required|string|min:8|confirmed',
});

final userData = {
  'email': input['email'],
  'password': input['password'],
};
```

## `min` And `max`

`min:<n>` and `max:<n>` work differently based on the value type:

- string: character length
- list: item count, when a `list` or `list:<type>` rule is also present
- number: numeric value

Examples:

```dart
await req.validate({
  'title': 'required|string|min:3|max:120',
  'age': 'int|min:18|max:99',
  'tags': 'list:string|min:1|max:5',
});
```

`min` and `max` values must be whole numbers in the rule string.

## `in` And `not_in`

Use `in` for enums, statuses, modes, roles, and option sets.

```dart
await req.validate({
  'status': 'required|in:draft,published,archived',
  'role': 'not_in:owner,system',
});
```

These rules compare `value.toString()` against the listed options.

## `date`

`date` accepts a `DateTime` or anything that can be parsed by
`DateTime.parse(...)`.

```dart
await req.validate({
  'startsAt': 'required|date',
});
```

Common accepted strings include ISO-style values such as:

```text
2026-09-09
2026-09-09T10:30:00Z
```

## `regex`

`regex:<pattern>` creates a Dart `RegExp` from the pattern after `regex:`.

```dart
await req.validate({
  'slug': r'required|string|regex:^[a-z0-9-]+$',
});
```

Current limit: validation rules are split on `|`, so regex patterns containing
`|` conflict with the rule format. Prefer a named app-specific check when a
regex becomes complex.

## Custom Messages

Custom messages can be passed to `req.validate(...)` or
`Validator.validate(...)`.

Message lookup order is:

1. `field.rule`
2. `field`
3. `rule`

Example:

```dart
final data = await req.validate(
  {
    'email': 'required|email|min:5',
    'password': 'required|string|min:8|confirmed',
  },
  messages: {
    'email.required': 'Email is required.',
    'email.email': 'Enter a valid email address.',
    'password.min': 'Password must be at least :min characters.',
    'confirmed': 'The :field confirmation does not match.',
    'unknown': 'The :field field is not allowed.',
  },
);
```

Supported placeholders:

- `:field`
- `:min`
- `:max`
- `:value`

For list item type rules, the rule key includes the list type:

```dart
await req.validate(
  {'tags': 'list:string'},
  messages: {
    'tags.list:string': 'Every tag must be text.',
  },
);
```

## Error Handling

When validation fails, Flint throws `ValidationException`.

`ValidationException` stores:

```dart
final Map<String, List<String>> errors;
```

The default `ExceptionMiddleware` turns it into a JSON response:

```json
{
  "status": false,
  "errors": {
    "email": ["The email field is required."]
  }
}
```

The status code is `422`.

Most controllers should let `ValidationException` bubble to
`ExceptionMiddleware`.

```dart
Future<Response> store() async {
  final data = await req.validate({
    'title': 'required|string|min:3',
  });

  final course = await Course().create(data);
  return res.status(201).json({'data': course});
}
```

Catch it only when the route needs a custom response shape:

```dart
try {
  final data = await req.validate({'email': 'required|email'});
  return res.json({'data': data});
} on ValidationException catch (error) {
  return res.status(422).json({
    'message': 'Please check the form.',
    'errors': error.errors,
  });
}
```

`ValidationError` is compatible with `ValidationException`. Use it when code
already uses that class name.

## Manual Validation

Use `Validator.validate(...)` when validating a plain map that did not come
directly from `Request`.

```dart
final payload = {
  'email': 'ada@example.com',
  'password': 'secret123',
};

await Validator.validate(payload, {
  'email': 'required|email',
  'password': 'required|string|min:8',
});
```

`Validator.validate(...)` returns `void`. It throws when invalid.

## Business Validation

Validation rules handle shape, type, and simple constraints. App-specific
business checks belong in controllers, actions, services, policies, or
validator classes.

Example: checking whether an email is already used.

```dart
import 'package:flint_dart/flint_dart.dart';

import '../../models/user.dart';

class EnsureEmailIsAvailable {
  Future<void> call(String email) async {
    final existing = await User().where('email', email).first();
    if (existing != null) {
      throw ValidationException({
        'email': ['Email is already in use.'],
      });
    }
  }
}
```

Then call it after shape validation:

```dart
final data = await req.validate({
  'email': 'required|email',
  'password': 'required|string|min:8|confirmed',
});

await EnsureEmailIsAvailable().call(data['email'].toString());
```

## Reusable Validator Classes

When rules are reused or the request becomes important enough to name, create a
validator class in its own file. Do not hide reusable validation inside a private
`_someThing()` method on the controller.

File: `lib/validators/create_course_validator.dart`

```dart
class CreateCourseValidator {
  Map<String, String> get rules => {
        'title': 'required|string|min:3|max:120',
        'status': 'in:draft,published',
        'tags': 'list:string',
      };

  Map<String, String> get messages => {
        'title.required': 'Course title is required.',
        'status.in': 'Status must be draft or published.',
      };
}
```

Controller usage:

```dart
import '../validators/create_course_validator.dart';

class CourseController extends Controller {
  Future<Response> store() async {
    final validator = CreateCourseValidator();
    final data = await req.validate(
      validator.rules,
      messages: validator.messages,
    );

    final course = await Course().create(data);
    return res.status(201).json({'data': course});
  }
}
```

Use one validator class per file. If update rules differ from create rules,
create a separate `UpdateCourseValidator`.

## Validation In Middleware

Prefer validating inside the controller action because the action knows which
fields it will use. Use middleware validation for cross-cutting request shapes,
such as a shared API key payload or a webhook envelope.

```dart
class WebhookPayloadMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Context ctx) async {
      await ctx.req.validate({
        'event': 'required|string',
        'payload': 'required',
      });

      return await next(ctx);
    };
  }
}
```

Let `ValidationException` reach `ExceptionMiddleware` unless the middleware has a
strong reason to format the response itself.

## File Upload Validation

`validate(...)` can check that an uploaded file field exists:

```dart
final data = await req.validate({
  'avatar': 'required',
});

final avatar = data['avatar'] as UploadedFile;
```

Then do file-specific checks yourself:

```dart
if (avatar.size != null && avatar.size! > 2 * 1024 * 1024) {
  throw ValidationException({
    'avatar': ['Avatar must be 2 MB or smaller.'],
  });
}

final allowedTypes = {'image/png', 'image/jpeg'};
if (!allowedTypes.contains(avatar.contentType)) {
  throw ValidationException({
    'avatar': ['Avatar must be a PNG or JPEG image.'],
  });
}
```

For multiple uploads, use `req.files(...)`, `req.hasFiles(...)`, and custom
checks.

```dart
final uploads = await req.files('gallery');
if (uploads.isEmpty) {
  throw ValidationException({
    'gallery': ['At least one gallery image is required.'],
  });
}
```

## Frontend Form Errors

Flint is fullstack. Backend validation errors can be consumed by frontend code
under `lib/ui`.

`ExceptionMiddleware` returns:

```json
{
  "status": false,
  "errors": {
    "email": ["Email is required."]
  }
}
```

`FormErrors.from(...)` understands that shape:

```dart
final errors = FormErrors.from({
  'errors': {
    'email': ['Email is required.'],
    'password': 'Password is required.',
  },
});

errors.field('email'); // Email is required.
errors.fieldMessages('email'); // All email messages.
errors.firstMessages; // First message per field.
```

`FormController.submit(...)` captures validation-like payloads thrown by the
submit action:

```dart
final form = useForm({
  'email': '',
  'password': '',
});

await form.submit(
  (data) async {
    final response = await clientRouter.post<Map<String, dynamic>>(
      '/auth/login',
      body: data,
    );
    if (response.isError) {
      throw response.error ?? response.data;
    }
    return response.data;
  },
  onValidationError: (errors) {
    // Use errors.field('email') or bind errors to controls.
  },
);
```

Form controls such as `TextField`, `TextArea`, `Select`, `Checkbox`,
`RadioGroup`, `DatePicker`, and rich text controls can receive `errors` and
resolve the message for their `name`.

Keep each page, section, component, or reusable form helper in its own file
under `lib/ui`.

## Swagger Documentation

`--docs-generate` does not inspect `req.validate(...)`. Document request bodies
and validation errors in route comments.

```dart
/// @summary Create course
/// @response 201 Course created
/// @response 422 Validation failed
/// @body {"title": "string", "status": "string"}
courses.post('/', (controller) => controller.store());
```

For path params and query params, also document:

```dart
/// @param id path string required Course ID
/// @query page string optional Page number
```

Use OpenAPI types in Swagger comments. For example, Swagger uses `number`, while
Flint validation uses `double`.

## Deprecated `validateForm`

`Request.validateForm(...)` still exists for older apps, but it is deprecated.

Use:

```dart
await req.validate({
  'email': 'required|email',
});
```

instead of:

```dart
await req.validateForm({
  'email': 'required|email',
});
```

`validate(...)` auto-detects JSON, URL-encoded forms, multipart forms, uploads,
query params, and route params.

## Current Limits

Do not invent rules the framework does not support yet.

Currently supported rules are the ones listed in this document. Flint does not
currently provide built-in validation rules such as:

- `unique`
- `exists`
- `nullable`
- `sometimes`
- `numeric`
- `url`
- `file`
- `image`
- `mimes`
- `max_file_size`

Use explicit app code for those checks.

Other important limits:

- Unknown rule names are ignored by the current validator, so typos may silently do nothing.
- `int`, `double`, `bool`, and `list` do not coerce strings.
- `double` does not accept an `int`.
- `required` does not fail an empty list by itself; use `list|min:1`.
- `regex` patterns containing `|` conflict with the pipe-separated rule format.
- Unknown scalar fields are rejected.
- Confirmation-style fields ending in `_confirmation` or starting with `confirm_` are skipped by unknown-field checks and can remain in the returned map.
- File fields are only included in validation data when they are named in the rules.
- Multiple file validation needs custom code with `req.files(...)`.

## Review Checklist

Before finishing a feature that accepts input:

1. The controller extends `Controller` and uses bound `req`, `res`, and `context`.
2. The route is registered with `app.controller(YourController.new)` when using controller actions.
3. Every accepted scalar field is listed in the validation rules.
4. Every route param such as `id` is listed when the route uses `req.validate(...)`.
5. Query-string values are treated as strings and parsed after validation.
6. Confirmation fields are removed before saving records.
7. File size, type, and count checks are handled with explicit app code.
8. Business checks throw `ValidationException` with field-specific errors.
9. Reusable validators or business checks live in their own files.
10. Swagger route comments include `@body`, `@param`, `@query`, and `@response 422` where needed.
