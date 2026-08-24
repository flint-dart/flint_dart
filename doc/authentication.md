# Authentication

Authentication is implemented by the static `Auth` facade in `lib/src/auth/auth.dart`, `AuthConfig`, `AuthService`, `FlintJwt`, and request/session helpers.

## Configuration

`Auth._loadConfig()` reads environment variables:

```text
AUTH_TABLE=users
AUTH_EMAIL_COLUMN=email
AUTH_PASSWORD_COLUMN=password
AUTH_NAME_COLUMN=name
AUTH_PROVIDER_COLUMN=provider
AUTH_PROVIDER_ID_COLUMN=provider_id
JWT_SECRET
JWT_EXPIRY_HOURS
AUTH_ACCESS_TOKEN_MINUTES
AUTH_ENABLE_REFRESH_TOKENS
AUTH_REFRESH_TOKEN_DAYS
AUTH_ENABLE_LOGIN_THROTTLE
AUTH_LOGIN_MAX_ATTEMPTS
AUTH_LOGIN_LOCK_MINUTES
PASSWORD_MIN_LENGTH
REQUIRE_EMAIL_VERIFICATION
REDIRECT_BASE
GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET
GITHUB_CLIENT_ID / GITHUB_CLIENT_SECRET
FACEBOOK_CLIENT_ID / FACEBOOK_CLIENT_SECRET
APPLE_CLIENT_ID / APPLE_TEAM_ID / APPLE_KEY_ID / APPLE_PRIVATE_KEY
```

In production, `Auth` rejects the default or short `JWT_SECRET`.

## Register And Login

The sample `example/lib/controllers/auth_controller.dart` uses request validation and `Auth`:

```dart
final data = await req.validate({
  "name": "string|required",
  "email": "string|required",
  "password": "string|required|confirmed",
});

final user = await Auth.register(
  email: data["email"],
  password: data['password'],
  name: data["name"],
);

return res.respond({"msg": "User created successfully", "data": user});
```

Login:

```dart
final data = await req.validate({
  "email": "required|string",
  "password": "required|string",
});

final result = await Auth.login(data["email"], data["password"]);
return res.respond({"msg": "Login successful", "data": result});
```

Internally, `Auth.login()` queries the configured table by email, verifies the password with `Hashing().verify`, optionally checks `email_verified_at`, sanitizes the user data, and issues a JWT.

## Current User

`Request.user` first checks a bearer token or auth cookie, verifies it with `Auth.verifyToken`, merges it with session data if present, and stores the payload under request storage key `user`.

```dart
app.get('/me', (req, res) async {
  final user = await req.user;
  if (user == null) {
    return res.status(401).json({'message': 'Unauthenticated'});
  }
  return res.json({'user': user});
});
```

`Request.requireUser()` reads the cached user from request storage. Because `isAuthenticated` only checks that cache, call `await req.user` first or populate the storage in middleware.

## Tokens And Refresh Tokens

`Auth.generateToken()` and `Auth.verifyToken()` use `FlintJwt`.

`Auth.loginWithTokens()` returns an access token and, when `AUTH_ENABLE_REFRESH_TOKENS=true`, creates a hashed refresh-token record in `auth_refresh_tokens`.

`Auth.ensureFrameworkTablesExist()` creates:

- `password_reset_tokens`
- `email_verification_tokens`
- `auth_refresh_tokens`

## OAuth

`Auth` can authenticate provider payloads for Google, GitHub, Facebook, and Apple through provider classes. `AuthService` can generate provider authorization URLs and stores OAuth state/code-verifier data in in-memory maps with a 10-minute cleanup timer.

```dart
final url = AuthService.getGoogleAuthUrl(
  callbackUrl: 'http://localhost:3000/auth/google/callback',
);
return res.redirect(url);
```

## Important Limits

- `AuthService` state storage is in memory, so it is not shared across processes.
- `Auth.register()` inserts only columns that exist in the configured auth table.
- Password reset and verification tokens/codes are stored hashed.
- `Request.authToken` checks `Authorization: Bearer ...`, then `FLINT_AUTH_COOKIE` or `flint.auth.token`.
- Login throttling is in memory and is enabled only by `AUTH_ENABLE_LOGIN_THROTTLE`.
