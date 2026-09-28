# Security And Utilities

This guide covers direct-use security helpers, rate-limiting guidance, framework
exceptions, and stable utility helpers.

Use this guide when a feature hashes passwords, verifies secrets, creates JWTs,
adds auth-sensitive endpoints, handles framework exceptions, stores public
uploads, or needs simple string helpers.

Before coding, inspect:

- `docs/authentication.md` for auth workflows.
- `docs/middleware.md` for middleware behavior.
- `docs/validation.md` for validation errors.
- `docs/storage.md` for upload safety.
- `lib/src/security/` when security helper behavior is unclear.
- `lib/src/error/` and `lib/src/middleware/exception_middleware.dart` when
  exception behavior is unclear.

## Security Utilities

Import the main framework entrypoint:

```dart
import 'package:flint_dart/flint_dart.dart';
```

Focused imports also work:

```dart
import 'package:flint_dart/security.dart';
```

### Security Utilities (Direct Use)

Use `Hashing` when storing or verifying passwords.

```dart
final hasher = Hashing(algorithm: HashingAlgorithm.bcrypt);

final digest = hasher.hash('secret');
final ok = hasher.verify('secret', digest);
```

`HashingAlgorithm.bcrypt` is the default and should be used for user passwords.
Bcrypt includes a salt in the generated hash, so hashing the same password twice
can produce different strings. Always verify with `hasher.verify(...)`.

Do not compare raw passwords or password hashes manually:

```dart
if (!Hashing().verify(password, user.password!)) {
  throw AuthException(message: 'Invalid email or password');
}
```

`HashingAlgorithm.sha256` is available, but do not use plain SHA-256 for user
passwords. It is suitable only for simple deterministic digests where password
storage is not involved.

Use `FlintJwt` when lower-level JWT handling is needed:

```dart
final jwt = FlintJwt('app-secret');

final token = jwt.generateToken(
  {'userId': user.id},
  expiry: const Duration(hours: 2),
);

final payload = jwt.verifyToken(token);

if (payload == null) {
  throw AuthException(message: 'Invalid token');
}
```

`generateToken(...)` adds `iat` and `exp` values. `verifyToken(...)` returns the
payload map when the token is valid and returns `null` when verification fails.

For full login, registration, refresh token, password reset, send OTP, verify
OTP, and current-user flows, prefer the higher-level `Auth` API described in
`docs/authentication.md`.

### Security Middleware

`SecurityMiddleware` watches suspicious paths and repeated 404s.

```dart
app.use(
  SecurityMiddleware(
    config: SecurityConfig.production(
      maxNotFoundAttempts: 10,
      notFoundWindow: const Duration(minutes: 1),
      blockDuration: const Duration(hours: 1),
      suspiciousPathPrefixes: const [
        '/wp-admin',
        '/.env',
      ],
    ),
    onSecurityEvent: (event) {
      Log.warning(event.toString());
    },
  ),
);
```

Useful config values:

- `blockNotFoundAbuse`
- `maxNotFoundAttempts`
- `notFoundWindow`
- `blockDuration`
- `suspiciousPathPrefixes`
- `excludedPrefixes`

Use `SecurityConfig.monitorOnly(...)` when you want events without automatic
temporary IP blocking.

## Rate Limiting

### Rate Limiting (Guidance)

Flint does not currently expose a built-in `RateLimitMiddleware` class. Rate
limiting should be implemented as app middleware until the framework adds a
first-class middleware.

Rate-limit endpoints that create or verify sensitive tokens:

- login
- register
- forgot password
- reset password
- send OTP
- resend OTP
- verify OTP
- OAuth callback exchange
- public contact forms
- file upload endpoints

Common rate-limit keys:

- client IP address
- authenticated user ID
- email address
- route name or route path
- IP plus email for auth endpoints

Recommended behavior:

- return HTTP `429`
- include a clear message
- use stricter limits for OTP and password reset endpoints
- do not reveal whether an email exists
- keep limits short enough for mistakes and strict enough for abuse
- use shared storage for rate limits when the app runs on many processes

Example app middleware:

```dart
class LoginRateLimitMiddleware extends Middleware {
  LoginRateLimitMiddleware({
    this.maxAttempts = 5,
    this.window = const Duration(minutes: 1),
  });

  final int maxAttempts;
  final Duration window;
  final Map<String, List<DateTime>> _attempts = {};

  @override
  Handler handle(Handler next) {
    return (Context ctx) async {
      final key = ctx.req.clientIpAddress;
      final now = DateTime.now();
      final attempts = _attempts.putIfAbsent(key, () => <DateTime>[]);

      attempts.removeWhere((time) => now.difference(time) > window);

      if (attempts.length >= maxAttempts) {
        return ctx.res?.status(429).json({
          'message': 'Too many attempts. Try again later.',
        });
      }

      attempts.add(now);
      return await next(ctx);
    };
  }
}
```

Attach it to sensitive routes:

```dart
auth
    .post('/login', (controller) => controller.login())
    .useMiddleware(LoginRateLimitMiddleware());
```

The example uses in-memory state, so it is only suitable for a single app
process. Production apps with multiple workers should store counters in shared
storage such as a database or cache service.

## Errors And Exceptions

Flint's default `ExceptionMiddleware` converts known exceptions into HTTP JSON
responses when `ctx.res` exists.

Common exceptions:

- `ValidationException`
- `ValidationError`
- `AuthException`
- `Unauthenticated`
- `ForbiddenException`
- `NotFoundException`
- `HttpException`
- `BaseException`

Validation errors usually come from `await req.validate(...)`:

```dart
final data = await req.validate({
  'email': 'required|email',
});
```

When validation fails, `ExceptionMiddleware` returns status `422`:

```json
{"status": false, "errors": {"email": ["The email field is required."]}}
```

Throw `AuthException` or `Unauthenticated` when authentication is missing or
invalid:

```dart
throw AuthException(message: 'Invalid email or password');
```

Response shape:

```json
{"status": false, "error": "Unauthorized", "message": "Invalid email or password"}
```

Throw `ForbiddenException` when the user is authenticated but not allowed:

```dart
throw ForbiddenException(message: 'Admin access required');
```

Throw `HttpException` when a route or service needs an explicit status:

```dart
throw HttpException(409, 'Course already exists', data: {'id': course.id});
```

Use `BaseException` for custom framework-style exceptions:

```dart
class PlanLimitException extends BaseException {
  const PlanLimitException()
      : super(
          message: 'Plan limit reached',
          code: 403,
        );
}
```

Most controllers should not catch validation or auth exceptions only to wrap
them again. Let `ExceptionMiddleware` produce the normal framework response.

WebSocket-only contexts have no `Response`, so exception middleware rethrows
known exceptions when `ctx.res` is null. Handle socket errors inside the
WebSocket handler and send an event back through `ctx.socket`.

## Helpers And Utils

Stable string helpers live behind:

```dart
import 'package:flint_dart/helper.dart';
```

Use `Str` for common string values:

```dart
final id = Str.uuid();
final otp = Str.otp();
final token = Str.token();
final random = Str.random(24);
final letters = Str.randomLetters(8);
final numbers = Str.randomNumbers(6);
final slug = Str.slugify('Hello Flint Dart');
final title = Str.capitalize('flint');
final fileName = Str.snake('CourseController');
final key = Str.camel('course_status');
```

Common uses:

- `Str.uuid()` for random IDs.
- `Str.otp(length)` for numeric one-time codes.
- `Str.token(length)` for URL-safe random tokens.
- `Str.random(length)` for alphanumeric random values.
- `Str.slugify(text)` for URL slugs.
- `Str.snake(text)` for file names or keys.
- `Str.camel(text)` for frontend-style keys.

Use auth-specific helpers from `Auth` for auth codes when the code must be
stored and verified by Flint's auth tables. For example, use
`Auth.generateNumericVerificationCode(email)` for email verification OTPs
instead of only generating `Str.otp()`.

Do not teach `lib/core/helpers.dart` as the stable helper API. That file still
contains older placeholder helpers. Prefer `Str`, request helpers, response
helpers, `Storage`, `Hashing`, `FlintJwt`, and the documented framework APIs.

## Security Review Checklist

When reviewing security-sensitive code:

1. Read `docs/security-and-utilities.md`.
2. Use `HashingAlgorithm.bcrypt` for user passwords.
3. Verify secrets with `Hashing.verify(...)`, not manual comparison.
4. Use higher-level `Auth` helpers for auth workflows when available.
5. Rate-limit login, OTP, password reset, and upload endpoints.
6. Return `429` for rate-limit failures.
7. Use `AuthException` for unauthenticated or invalid credentials.
8. Use `ForbiddenException` for authenticated users who lack permission.
9. Let `ExceptionMiddleware` handle normal validation and auth exceptions.
10. Keep generated secrets, tokens, and OTPs out of logs.
11. Validate uploaded files before calling `Storage.create(...)`.
