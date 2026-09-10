# Sessions And Cookies

Flint has server-side sessions, HTTP cookie helpers, flash-message cookies, and
browser-side Flint UI session helpers. They solve different problems, so do not
treat them as one system.

Use this guide before adding login sessions, remember-me cookies, flash
messages, browser auth state, or middleware that reads/writes cookies.

## Framework Source References

When behavior is unclear, inspect these files in the installed package:

- `lib/session.dart`
- `lib/src/session/session.dart`
- `lib/src/session/session_service.dart`
- `lib/src/session/cookie.dart`
- `lib/src/session/cookie_service.dart`
- `lib/src/middleware/cookie_session_middleware.dart`
- `lib/src/request.dart`
- `lib/src/response.dart`
- `lib/src/template_engine/all_expression/session.dart`
- `lib/src/ui/auth/auth_session.dart`
- `lib/src/ui/storage/cookies.dart`

Read `docs/templates.md` before changing `session(...)`, `hasSession(...)`,
flash rendering, or template syntax.

## Imports

Most server app code can use:

```dart
import 'package:flint_dart/flint_dart.dart';
```

Focused session/cookie imports are also available:

```dart
import 'package:flint_dart/session.dart';
```

Frontend Flint UI code should use:

```dart
import 'package:flint_dart/ui.dart';
```

## The Mental Model

There are three common cookie/session shapes in Flint:

- Server sessions: the browser receives a `FLINTSESSID` cookie, and the session
  data lives on the server through `SessionManager`.
- Plain HTTP cookies: the app writes a specific cookie value with
  `res.setCookie(...)` or `CookieService.set(...)`.
- Browser UI auth session: Flint UI stores a token and user payload in browser
  storage through `AuthSessionManager`.

Server sessions are good for server-rendered pages, cookie login flows, and
request-side auth fallback.

Plain cookies are good for small preferences, flash messages, non-secret browser
state, or controlled auth cookies.

Browser auth sessions are good for client-side UI state, but values in
`localStorage`, `sessionStorage`, or JavaScript-readable cookies are visible to
browser JavaScript. Do not store secrets there unless the app accepts that risk.

## Default Middleware

`CookieSessionMiddleware` initializes the static cookie/session services for each
HTTP request:

```dart
CookieService.init(ctx.req, res);
SessionService.init(ctx.req, res);
```

`Flint` installs this middleware by default. Even when
`withDefaultMiddleware: false`, the constructor still adds
`CookieSessionMiddleware`, so HTTP routes can initialize cookies and sessions.

The middleware checks `ctx.res` first. WebSocket contexts pass through without
initializing `CookieService` or `SessionService`, because WebSocket handlers do
not have an HTTP response after upgrade.

For new route and controller code, prefer the instance helpers on `req` and
`res`. Use `SessionService` and `CookieService` when app code intentionally wants
the static request-local convenience layer.

## Environment

Server sessions read configuration from environment values through `FlintEnv`.
Set these before the session manager is first used.

```text
SESSION_DRIVER=memory
SESSION_TTL=7d
SESSION_FILE=sessions.json
SESSION_DB_TABLE=sessions
SESSION_COOKIE_SECURE=false
SESSION_COOKIE_HTTP_ONLY=true
SESSION_COOKIE_SAMESITE=Lax
SESSION_COOKIE_PATH=/
APP_ENV=development
```

Supported session drivers:

- `memory`: stores sessions in the current Dart process.
- `file`: stores sessions in a JSON file.
- `db`: stores sessions in a database table.

TTL values currently support days and hours:

```text
SESSION_TTL=7d
SESSION_TTL=12h
```

Any other shape falls back to seven days.

Cookie defaults:

- `SESSION_COOKIE_SECURE` defaults to `true` when `APP_ENV=production`; otherwise
  it defaults to `false`.
- `SESSION_COOKIE_HTTP_ONLY` defaults to `true`.
- `SESSION_COOKIE_SAMESITE` defaults to `Lax`.
- `SESSION_COOKIE_PATH` defaults to `/`.

For cross-site cookies, browsers usually require `SameSite=None` and `Secure`.
Use that only when the app is actually served over HTTPS.

## Session Drivers

### Memory

The memory driver is the default:

```text
SESSION_DRIVER=memory
```

It stores session data in a process-local map. This is fine for development,
tests, and simple local apps. It is not durable. Sessions disappear when the
process restarts and are not shared across multiple server processes.

### File

The file driver stores session data in a JSON file:

```text
SESSION_DRIVER=file
SESSION_FILE=storage/sessions.json
```

If the file does not exist, Flint creates it and writes `{}`. Use a path that
your server process can read and write. Do not put the session file under
`public/`.

### Database

The database driver stores sessions in a table:

```text
SESSION_DRIVER=db
SESSION_DB_TABLE=sessions
```

The session manager creates the table if it does not exist. The table contains:

- `id`
- `user_id`
- `data`
- `created_at`
- `expires_at`

The `data` column uses `JSONB` on PostgreSQL and `JSON` on MySQL. The database
connection must be available before database-backed sessions are used.

Keep `SESSION_DB_TABLE` as a safe table identifier such as `sessions` or
`app_sessions`.

## Reading Cookies

Read request cookies from `req.cookies`:

```dart
final theme = req.cookies['theme'];
final sessionId = req.sessionId;
```

`req.cookies` parses the `Cookie` header into a `Map<String, String>`.
`req.sessionId` is a shortcut for:

```dart
req.cookies['FLINTSESSID'];
```

Use cookies for small values. Do not trust cookie values just because the server
can read them. Validate them, sign them, or store only opaque ids that point to
server-side data.

## Writing Cookies

Use response instance methods to write cookies:

```dart
return res
    .setCookie(
      'theme',
      'dark',
      maxAge: 60 * 60 * 24 * 30,
      path: '/',
      httpOnly: false,
      secure: true,
      sameSite: 'Lax',
    )
    .json({'ok': true});
```

`res.setCookie(...)` accepts:

- `name`
- `value`
- `expires`
- `maxAge` in seconds
- `path`
- `httpOnly`
- `secure`
- `sameSite`

Remove a cookie with:

```dart
return res.clearCookie('theme').json({'ok': true});
```

`clearCookie(...)` must use the same `path` that was used when the cookie was
created. If the app set `path: '/admin'`, clear it with:

```dart
res.clearCookie('theme', path: '/admin');
```

## CookieService

`CookieService` is a static convenience API initialized per HTTP request by
`CookieSessionMiddleware`.

```dart
CookieService.set(
  'theme',
  'dark',
  httpOnly: false,
  maxAge: const Duration(days: 30),
);

final theme = CookieService.get('theme');

CookieService.delete('theme');
```

`CookieService.set(...)` accepts:

- `name`
- `value`
- `httpOnly`
- `secure`
- `path`
- `maxAge` as a `Duration`
- `expires`
- `sameSite`

When `secure` is not supplied, `CookieService` uses the same secure-cookie
default as sessions: secure in production, not secure in development.

Do not call `CookieService` from startup code, queue jobs, isolates, or
WebSocket event callbacks. It depends on the current HTTP request and response.

## Creating A Server Session

Use `req.startSession(...)` in a route or controller after the user has passed
the app's checks:

```dart
class LoginController extends Controller {
  Future<Response> store() async {
    final input = await req.validate({
      'email': 'required|email',
      'password': 'required|string',
    });

    final user = await User().where('email', input['email']).first();
    if (user == null || !Hashing().verify(input['password'], user.password!)) {
      return res.status(401).json({'message': 'Invalid credentials'});
    }

    await req.startSession({
      'id': user.id,
      'email': user.email,
      'role': user.role,
    });

    return res.json({'user': user});
  }
}
```

`startSession(...)`:

- creates a random session id
- stores the data through the configured session driver
- adds `expires_at` to the stored data
- writes the `FLINTSESSID` cookie
- caches the same data as `user` in request-scoped storage
- returns the new session id

You can pass a custom TTL:

```dart
await req.startSession(
  {'id': user.id, 'role': user.role},
  ttl: const Duration(hours: 8),
);
```

Keep session data small. Store ids, roles, and flags. Do not put entire model
graphs, large payloads, passwords, password hashes, OTPs, or private tokens in
the session.

## Reading A Server Session

Use `await req.session`:

```dart
final session = await req.session;
if (session == null) {
  return res.status(401).json({'message': 'Login required'});
}

return res.json({
  'user': {
    'id': session['id'],
    'email': session['email'],
  },
});
```

`req.session` reads `FLINTSESSID`, loads the session from the configured driver,
checks expiration, and returns `null` when the session is missing or expired.

Expired sessions are removed from memory, file, or database storage when read.

## Updating A Server Session

Use `req.updateSession(...)` to merge values into the current session:

```dart
await req.updateSession({
  'role': 'admin',
  'last_seen_at': DateTime.now().toIso8601String(),
});
```

`updateSession(...)`:

- reads the current session
- returns `null` when no current session exists
- merges the new values into existing data
- destroys the old session
- creates a new session
- writes a new `FLINTSESSID` cookie
- caches the merged data as `user` in request storage

Because the session id changes, call it before the response is sent.

## Destroying A Server Session

Use `req.destroySession()` for logout:

```dart
class LogoutController extends Controller {
  Future<Response> destroy() async {
    await req.destroySession();

    return res.json({'message': 'Logged out'});
  }
}
```

`destroySession()` removes the stored session, clears the `FLINTSESSID` cookie,
and removes the cached request user.

## SessionService

`SessionService` is a static convenience API for key-by-key session access.

```dart
await SessionService.set('cart_id', cart.id);

final cartId = await SessionService.get('cart_id');

await SessionService.remove('cart_id');

await SessionService.destroy();
```

It is initialized by `CookieSessionMiddleware` and depends on the current HTTP
request/response. Use it only inside HTTP request handling.

`SessionService.set(...)` reads the current `FLINTSESSID`, loads existing
session data or starts with `{}`, changes one key, and creates a session with
the updated data.

`SessionService.remove(...)` removes a key from the current session data and
creates a session with the remaining data.

For login, logout, and sensitive auth changes, prefer `req.startSession(...)`,
`req.updateSession(...)`, and `req.destroySession()` so the flow is explicit in
the controller or action.

## Auth And Sessions

`req.user` checks authentication in this order:

1. Read a token from `req.authToken`.
2. Verify the token with `Auth.verifyToken`.
3. If a server session also exists, merge the session data with the token
   payload.
4. If no valid token exists, fall back to server session data.
5. Cache the user payload in request-scoped storage.

`req.authToken` reads:

1. `Authorization: Bearer <token>`
2. the cookie named by `FLINT_AUTH_COOKIE`, defaulting to `auth.token`
3. `flint.auth.token`

Important: `req.isAuthenticated` only checks whether `req.user` has already
cached a user on the request. It does not perform the lookup by itself.

Use:

```dart
final user = await req.user;
if (user == null) {
  return res.status(401).json({'message': 'Unauthorized'});
}
```

or load the user in middleware and write it to the context:

```dart
class AuthMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Context ctx) async {
      final res = ctx.res;
      if (res == null) return await next(ctx);

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

Then controllers can read:

```dart
final user = read<Map<String, dynamic>>();
```

## JWT Cookie Login

Some apps use a JWT in an HTTP-only cookie instead of returning the token only
in JSON.

```dart
final token = Auth.generateToken(user.toMap());

return res
    .setCookie(
      'auth.token',
      token,
      httpOnly: true,
      secure: true,
      sameSite: 'Lax',
      path: '/',
      maxAge: 60 * 60 * 24 * 7,
    )
    .json({'user': user});
```

Then `req.authToken` can read that cookie on later requests.

For browser clients that need to call APIs with `Authorization: Bearer`, return
the token in JSON and let the frontend store it intentionally. Do not store the
same sensitive token in many places without a reason.

## Flash Messages

Flash messages are one-request messages usually used after redirects.

```dart
return res.withSuccess('Course saved').redirect('/courses');
```

or:

```dart
return res.withError('Unable to save course').back(fallback: '/courses/new');
```

`withSuccess(...)` and `withError(...)` use `withFlash(...)` internally.
`withFlash(...)` writes an HTTP-only cookie named:

```text
FLINT_FLASH_<key>
```

By default, flash cookies live for 120 seconds.

When `res.view(...)` renders the next template, Flint:

1. Reads `FLINT_FLASH_*` cookies from the request.
2. Adds them to the template data under `flash`.
3. Adds each key directly to the template data.
4. Adds them to `TemplateEngine().sessions`.
5. Clears the flash cookies after rendering.

Template usage:

```html
{{ if hasSession('success') }}
  <p>{{ session('success') }}</p>
{{ endif }}

{{ if hasSession('error') }}
  <p>{{ session('error') }}</p>
{{ endif }}
```

`{{ session('key') }}` reads from `TemplateEngine().sessions`.
`hasSession('key')` becomes `true` or `false` during template rendering.

Flash cookies are for short messages, not private data.

## Templates And Sessions

Template session helpers are not the same as `req.session`.

`req.session` reads server session data through `SessionManager`.

`{{ session('key') }}` reads `TemplateEngine().sessions`, which is populated by
flash messages during `res.view(...)` or by code that intentionally writes to
the template engine before rendering.

For normal server session values, pass the data explicitly:

```dart
final session = await req.session;

return res.view('dashboard.index', data: {
  'userName': session?['name'] ?? 'Guest',
});
```

Template:

```html
<h1>Hello {{ userName }}</h1>
```

This keeps templates clear and avoids assuming all server session values are
automatically exposed to HTML.

## Browser Cookies In Flint UI

Frontend code can use the shared `cookies` helper:

```dart
cookies.write(
  'theme',
  'dark',
  maxAge: const Duration(days: 30),
  sameSite: CookieSameSite.lax,
);

final theme = cookies.read('theme');

cookies.remove('theme');
```

Browser cookies written from JavaScript cannot be `HttpOnly`. Use them for
preferences and non-secret state.

`cookies.readAll()` returns all JavaScript-visible cookies. It cannot read
HTTP-only cookies created by the server.

## Browser Auth Session In Flint UI

Flint UI has `AuthSessionManager` for simple browser-side auth state:

```dart
authSession.save(
  token: token,
  user: {
    'id': user['id'],
    'role': user['role'],
  },
);

final loggedIn = authSession.isLoggedIn;
final current = authSession.current;
final role = authSession.role;

authSession.clear();
```

By default, `authSession` stores:

```text
auth.token
auth.user
```

in `localStorage`.

Use custom keys when needed:

```dart
const adminSession = AuthSessionManager(
  tokenKey: 'admin.auth.token',
  userKey: 'admin.auth.user',
);
```

Use `sessionStorage` instead of `localStorage` when the login should be tied to
the browser tab/session:

```dart
const tabSession = AuthSessionManager(
  tokenKey: 'auth.session.token',
  userKey: 'auth.session.user',
  storage: sessionStorage,
);
```

Browser auth session is not a server session. Saving a token in
`AuthSessionManager` does not create `FLINTSESSID`, and destroying
`FLINTSESSID` does not automatically clear browser storage. Clear both when the
app uses both.

## WebSockets

WebSocket handlers receive a `Context` with `ctx.req` and `ctx.socket`.
`ctx.res` is null after the upgrade.

The WebSocket handshake request can read cookies and bearer tokens:

```dart
app.websocket('/chat', (Context ctx) {
  final token = ctx.req.authToken;
  final sessionId = ctx.req.sessionId;
  final socket = ctx.socket;

  if (socket == null) return;
  socket.emit('connected', {'sessionId': sessionId});
});
```

Do not use `CookieService`, `SessionService`, `res.setCookie(...)`, or
`req.startSession(...)` inside WebSocket event callbacks. Those operations need
an HTTP response.

Authenticate sockets during the handshake or with a token sent by the client,
then store any verified identity on the socket or in your own connection state.

## Security Guidance

For session and cookie work:

- Keep server session data small and non-sensitive.
- Keep passwords, password hashes, OTPs, reset tokens, API keys, and private
  provider tokens out of sessions and JavaScript-visible storage.
- Use `httpOnly: true` for server-written auth/session cookies.
- Use `secure: true` in production HTTPS.
- Use `SameSite=Lax` for most app cookies.
- Use `SameSite=Strict` for highly sensitive same-site-only flows.
- Use `SameSite=None` only with `Secure` for cross-site use cases.
- Rotate the session id after login, privilege changes, or sensitive account
  changes.
- Clear cookies on logout.
- Validate every cookie value before using it.
- Prefer server-side sessions for secrets and browser storage only for data the
  frontend is allowed to read.

## Controller Examples

Login with server session:

```dart
class LoginController extends Controller {
  Future<Response> store() async {
    final input = await req.validate({
      'email': 'required|email',
      'password': 'required|string',
    });

    final user = await User().where('email', input['email']).first();
    if (user == null || !Hashing().verify(input['password'], user.password!)) {
      return res.status(401).json({'message': 'Invalid credentials'});
    }

    await req.startSession({
      'id': user.id,
      'email': user.email,
      'role': user.role,
    });

    return res.json({'user': user});
  }
}
```

Current user from token or session:

```dart
class CurrentUserController extends Controller {
  Future<Response> show() async {
    final user = await req.user;
    if (user == null) {
      return res.status(401).json({'message': 'Unauthorized'});
    }

    return res.json({'user': user});
  }
}
```

Logout:

```dart
class LogoutController extends Controller {
  Future<Response> destroy() async {
    await req.destroySession();

    return res
        .clearCookie('auth.token')
        .json({'message': 'Logged out'});
  }
}
```

Flash redirect:

```dart
class CourseController extends Controller {
  Future<Response> store() async {
    final data = await req.validate({
      'title': 'required|string|min:3',
    });

    await Course().create(data);

    return res.withSuccess('Course created').redirect('/courses');
  }
}
```

## File Organization

Keep session/cookie behavior in named files:

```text
lib/controllers/login_controller.dart
lib/controllers/logout_controller.dart
lib/middlewares/auth_middleware.dart
lib/services/auth/create_login_session_action.dart
lib/services/auth/clear_login_session_action.dart
lib/ui/state/auth_session_state.dart
```

Do not hide login/session behavior inside private helper methods on a route file.
Follow the Flint class-per-file pattern.

## Common Mistakes

- Treating browser `authSession` storage as the same thing as server
  `FLINTSESSID`.
- Calling `req.isAuthenticated` before `await req.user`.
- Calling `CookieService` or `SessionService` outside an HTTP request.
- Trying to set or clear cookies after `res.json(...)`, `res.send(...)`,
  `res.view(...)`, or another response-writing method has closed the response.
- Putting session files under `public/`.
- Using `SESSION_DRIVER=memory` for a multi-process production app.
- Storing passwords, OTPs, or private tokens in sessions.
- Forgetting `secure: true` for production auth cookies.
- Using `SameSite=None` without HTTPS.
- Forgetting to clear both server cookies and browser storage when the app uses
  both.
- Expecting template `{{ session('key') }}` to automatically expose every
  `req.session` value.
- Using WebSocket callbacks to create server sessions or set cookies.

## Review Checklist

Before finishing session/cookie work:

1. The route or controller uses `Context`/`Controller` correctly.
2. Cookies are written before the response is sent.
3. Auth cookies are `HttpOnly` and `Secure` in production.
4. `SameSite` matches the app's same-site or cross-site behavior.
5. Server sessions store only small allowed values.
6. Logout clears the server session and any auth cookie.
7. Frontend logout also clears `authSession` when browser storage is used.
8. Code calls `await req.user` before using `req.isAuthenticated` or
   `req.requireUser()`.
9. Templates receive normal session data explicitly, while flash uses
   `withSuccess(...)`, `withError(...)`, or `withFlash(...)`.
10. Middleware checks `ctx.res` before writing HTTP cookies or responses.
