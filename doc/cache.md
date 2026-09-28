# Cache

Flint has two different caching tools:

- `CacheStore` stores application data such as expensive query results,
  computed summaries, external API responses, or rendered fragments.
- `CacheMiddleware`, `ETagMiddleware`, and response cache helpers write HTTP
  cache headers so browsers and proxies know how to reuse or revalidate a
  response.

Keep that difference clear. `CacheStore` does not set HTTP headers.
`CacheMiddleware` does not store response bodies on the server.

## Framework Source References

When behavior is unclear, inspect these files in the installed package:

- `lib/cache.dart`
- `lib/src/cache/cache_manager.dart`
- `lib/src/cache/file_based.dart`
- `lib/src/cache/redis_cache.dart`
- `lib/src/middleware/cache_middleware.dart`
- `lib/src/middleware/static_file_middleware.dart`
- `lib/src/response.dart`

Tests that show expected behavior:

- `test/cache_test.dart`
- `test/middleware_test.dart`
- `test/request_response_test.dart`

## Imports

Use the focused cache entrypoint:

```dart
import 'package:flint_dart/cache.dart';
```

Most route/controller code can also use:

```dart
import 'package:flint_dart/flint_dart.dart';
```

Middleware classes are available through:

```dart
import 'package:flint_dart/middlewares.dart';
```

## CacheStore

`CacheStore` is the application data cache contract.

```dart
abstract class CacheStore {
  Future<void> set(String key, dynamic value, {Duration? ttl});
  Future<dynamic> get(String key);
  Future<void> remove(String key);
  Future<void> removeMany(Iterable<String> keys);
  Future<void> removeWhere(bool Function(String key) shouldRemove);
  Future<void> clear();

  Future<T> remember<T>(
    String key,
    Duration ttl,
    Future<T> Function() loader,
  );
}
```

Use a cache store when the app itself wants to avoid repeating work:

- repeated database reads
- expensive aggregate counts
- remote API calls
- generated reports
- server-rendered snippets
- feature flag/config lookups

Do not use a cache store as a source of truth. The database, filesystem, external
service, or model layer remains the source of truth.

## Application Cache And Driver Selection

Every `Flint` app owns one shared `CacheStore`. Flint attaches that same store
to each HTTP and WebSocket `Context`, so routes and middleware use `ctx.cache`.
Controllers use the inherited `cache` getter, and startup code can use
`app.cache`.

Memory is the default driver. A minimal app needs no cache setup:

```dart
final app = Flint();

app.get('/settings', (ctx) async {
  final settings = await ctx.cache.remember<Map<String, dynamic>>(
    'settings.public',
    const Duration(minutes: 5),
    () => PublicSettings().load(),
  );

  return {'settings': settings};
});
```

Select a driver in `.env` or the process environment:

```env
CACHE_DRIVER=memory
# CACHE_MEMORY_MAX_SIZE=100
```

```env
CACHE_DRIVER=file
CACHE_DIRECTORY=storage/cache
```

```env
CACHE_DRIVER=redis
REDIS_URL=redis://default:password@localhost:6379/0
```

`CACHE_DRIVER` accepts `memory`, `file`, or `redis`, without regard to case.
An unknown value fails while `Flint` is being created. When the variable is
omitted, Flint uses `memory`.

Constructor settings override the environment:

```dart
final app = Flint(
  cacheDriver: CacheDriver.file,
  cacheDirectory: 'storage/cache',
  cacheMemoryMaxSize: 200,
);
```

`cacheDirectory` only configures the file driver. If it and
`CACHE_DIRECTORY` are omitted, file cache uses `<working directory>/cache`.
`cacheMemoryMaxSize` overrides `CACHE_MEMORY_MAX_SIZE`, whose default is `100`.

Middleware receives the same cache as a route:

```dart
class LoadFlagsMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (ctx) async {
      final flags = await ctx.cache.get('feature-flags');
      ctx['featureFlags'] = flags;
      return next(ctx);
    };
  }
}
```

Controllers use `cache` directly:

```dart
class DashboardController extends Controller {
  Future<Object?> show() async {
    final stats = await cache.remember<Map<String, dynamic>>(
      'dashboard.stats',
      const Duration(minutes: 2),
      () => DashboardStats().load(),
    );
    return res.json({'data': stats});
  }
}
```

Do not create a new store in each request. Flint's app-owned store is what lets
values be reused across routes, middleware, and controllers.

## MemoryCacheStore

`MemoryCacheStore` keeps cached values in the current Dart process.

```dart
final cache = MemoryCacheStore(maxSize: 200);
```

Default max size:

```dart
MemoryCacheStore({this.maxSize = 100});
```

When the cache is full, it removes the first inserted key. This is a simple size
limit, not a full LRU cache.

Example:

```dart
final cache = MemoryCacheStore();

await cache.set(
  'courses.count',
  42,
  ttl: const Duration(minutes: 5),
);

final count = await cache.get('courses.count');
```

Expired values are removed when read.

Use memory cache for:

- local development
- tests
- short-lived process cache
- data that can be recomputed

Do not use memory cache when values must survive a process restart or be shared
across multiple server processes.

## FileCacheStore

`FileCacheStore` stores each key as a JSON file.

```dart
final cache = FileCacheStore(directory: 'storage/cache');
```

If no directory is passed, it uses:

```text
<current working directory>/cache
```

Keys are encoded with `Uri.encodeComponent(key)` and written as `.json` files.
Each file stores:

```json
{
  "value": "...",
  "expires": "2026-09-09T12:00:00.000"
}
```

Use file cache for simple durable cache values that can survive a process
restart.

Important limits:

- Values must be JSON-encodable.
- Complex Dart objects should be converted to maps/lists/primitives before
  storing.
- Values are decoded back from JSON, so typed lists and custom objects must be
  rebuilt by app code.
- Do not put the cache directory under `public/`.
- File cache is not ideal for high-write or multi-process workloads.

Example:

```dart
final cache = FileCacheStore(directory: 'storage/cache');

await cache.set(
  'settings.public',
  {
    'supportEmail': 'support@example.com',
    'maintenance': false,
  },
  ttl: const Duration(minutes: 10),
);

final settings = await cache.get('settings.public') as Map<String, dynamic>?;
```

## RedisCacheStore

`RedisCacheStore` shares cached JSON values across Flint processes and uses
Redis TTLs for expiration. It is independent of Flint's SQL database. Calling
`cache.set(...)` writes only to Redis; it does not call `DB`, save a model, or
otherwise copy the value into MySQL/PostgreSQL. Redis itself may persist data to
disk through its own RDB/AOF configuration, but that is separate from Flint's
database layer.

Use the focused import or the main Flint export:

```dart
import 'package:flint_dart/cache.dart';
// Or: import 'package:flint_dart/flint_dart.dart';
```

### Redis URLs

Flint accepts standard Redis URLs in this shape:

```text
redis[s]://[username:password@]host[:port][/database]
```

- `redis://` opens a normal TCP connection.
- `rediss://` opens a TLS connection.
- The default port is `6379` when no port is present.
- The optional path selects a zero-based Redis database such as `/0` or `/2`.
- Credentials are optional. Managed Redis commonly uses the username
  `default` plus a password.
- Percent-encode reserved characters in credentials. For example, `@` in a
  password becomes `%40`.

Never commit a real Redis URL containing credentials. Put it in the hosting
platform's secret manager, the process environment, or a local ignored `.env`
file. Rotate a credential if it is exposed in source control, logs, screenshots,
issues, or chat.

Connect a standalone store directly from a URL:

```dart
final cache = await RedisCacheStore.connectFromUrl(
  'redis://default:password@localhost:6379/0',
);

await cache.set(
  'verification.user-123',
  {'code': '482901'},
  ttl: const Duration(minutes: 5),
);
```

The component-based API remains available when an app does not use a URL:

```dart
final cache = await RedisCacheStore.connect(
  host: 'localhost',
  port: 6379,
  username: 'default',
  password: redisPassword,
  database: 0,
  secure: false,
);
```

### Automatic Flint Connection

For automatic Flint startup, select Redis and put the URL in the system
environment or `.env`:

```env
CACHE_DRIVER=redis
REDIS_URL=redis://default:password@localhost:6379/0
```

Then create and use the app normally:

```dart
final app = Flint();

app.get('/settings', (ctx) async {
  final settings = await ctx.cache.get('settings.public');
  return {'settings': settings};
});

await app.listen();
```

When Redis is selected, Flint establishes the connection before accepting HTTP
requests. Dedicated workers started with `app.runJobsWorker()` use the same
automatic connection. `autoConnectRedis: true` remains supported as a
backwards-compatible shortcut:

```dart
final app = Flint(autoConnectRedis: true);
```

Do not combine that shortcut with a non-Redis `cacheDriver`.

Flint reads `REDIS_URL` through `FlintEnv`, so a real process environment value
overrides the value in `.env`. A URL is convenient for managed providers, but it
is not required. Keep Redis connection details out of `Flint(...)` and connect
explicitly when host/port configuration is preferred:

```dart
final app = Flint();

await app.connectRedis(
  host: 'localhost',
  port: 6379,
  secure: false,
  username: 'default', // Optional.
  password: redisPassword, // Optional.
  database: 0, // Optional.
);
```

Calling `connectRedis(...)` switches `app.cache` to that Redis store, and Flint
then injects it as `ctx.cache`. Automatic Redis startup throws when `REDIS_URL`
is missing or invalid, authentication or database selection fails, or the
server cannot be reached. This is intentional: an app that selects Redis does
not start with an unavailable cache.

Check connection state without touching the cache:

```dart
if (app.isRedisConnected) {
  await app.cache.set('health.redis', true);
}
```

With memory and file drivers, `app.cache` is available immediately. With a
Redis driver, accessing it before Flint startup or manual connection throws
`StateError`. Connect manually when startup code needs Redis before
`app.listen()`:

```dart
await app.connectRedis(); // Reads REDIS_URL.
await app.connectRedis(url: anotherRedisUrl);

await app.connectRedis(
  host: 'localhost',
  port: 6379,
  secure: false,
  username: 'default',
  password: redisPassword,
  database: 0,
);
```

Repeated or concurrent `app.connectRedis()` calls reuse the connection already
owned by the app. Pass the intended URL or host settings on the first call.

### Values And TTL

Values are encoded with `jsonEncode` and decoded with `jsonDecode`. Store JSON
values such as strings, numbers, booleans, null, lists, and maps with string
keys. Convert `DateTime`, models, and custom objects to JSON-friendly values
before caching them. Decoded maps and lists are dynamic; rebuild application
types after reading when needed.

```dart
await app.cache.set(
  'user.42.summary',
  {
    'id': 42,
    'name': 'Ada',
    'cachedAt': DateTime.now().toIso8601String(),
  },
  ttl: const Duration(minutes: 10),
);

final summary =
    await app.cache.get('user.42.summary') as Map<String, dynamic>?;
```

- Omitting `ttl` leaves the Redis key without an expiration.
- A positive `ttl` uses Redis's native millisecond expiration.
- A zero or negative `ttl` removes the key instead of storing it.
- `get(...)` returns `null` when the key does not exist or has expired.

Use `remember(...)` when Redis should load and retain a value only on a miss:

```dart
final settings = await app.cache.remember<Map<String, dynamic>>(
  'settings.public',
  const Duration(minutes: 5),
  () async => PublicSettings().load(),
);
```

Redis is best for cache data, OTPs, rate-limit counters, short-lived state, and
shared computed results. Do not make cached data the only copy of business data
that must survive expiration, eviction, Redis restarts, or cache clearing.

### Prefixes And Cleanup

The default key prefix is `flint:cache:`. Set a different namespace per app:

```dart
await app.connectRedis(
  host: 'localhost',
  prefix: 'billing:cache:',
);
```

All store operations add the prefix. `get('settings')`, for example, reads the
Redis key `billing:cache:settings` with the configuration above.

`clear()` and `removeWhere()` use Redis `SCAN` and only delete keys within the
configured prefix; they do not run `FLUSHDB`. Use separate prefixes for apps or
environments that share one Redis database.

```dart
await app.cache.remove('user.42.summary');
await app.cache.removeMany(['settings.public', 'catalog.count']);
await app.cache.removeWhere((key) => key.startsWith('catalog.'));
await app.cache.clear(); // Only this store's prefix.
```

### Lifecycle And Operations

Flint closes its Redis connection when its HTTP worker or dedicated jobs worker
shuts down normally through the framework signal handlers. Close manually
managed connections explicitly:

```dart
await app.closeRedis(); // Connection owned by Flint.
await cache.close(); // Standalone RedisCacheStore.
```

The current adapter maintains one connection per `RedisCacheStore` and does not
implement pooling or automatic reconnection after a live connection drops.
Command and connection errors propagate to the caller. Deploy the app where it
can resolve and reach the provider's Redis hostname, use `rediss://` when the
provider requires TLS, and configure monitoring/restarts appropriate for the
application.

## Remember

`remember(...)` reads a key and only calls the loader when the key is missing or
expired.

```dart
final cache = MemoryCacheStore();

final stats = await cache.remember<Map<String, dynamic>>(
  'dashboard.stats',
  const Duration(minutes: 5),
  () async {
    final users = await User().count();
    final courses = await Course().count();

    return {
      'users': users,
      'courses': courses,
    };
  },
);
```

`remember(...)` treats `null` as a cache miss because `get(...)` returns `null`
for missing and expired values. Do not use `null` as a meaningful cached value.
Wrap it instead:

```dart
await cache.set('maybe.course', {'found': false});
```

## Cache Keys

Use stable, descriptive keys:

```text
courses.index.published.page.1
courses.show.<id>
dashboard.stats.admin
tenant.<tenant_id>.settings
```

Include every value that changes the result:

- tenant id
- user id, when data is user-specific
- role, when role changes visibility
- page number
- search term
- filter values
- locale
- feature flag/version

Avoid using raw user input directly as an unbounded key. Normalize it first.

Example:

```dart
final query = (req.queryParam('q') ?? '').trim().toLowerCase();
final safeQuery = query.replaceAll(RegExp(r'\s+'), '-');
final key = 'courses.search.$safeQuery.page.$page';
```

## Invalidating App Data

Clear cache keys when the source data changes.

```dart
await cache.remove('courses.show.$id');
await cache.removeWhere((key) => key.startsWith('courses.index.'));
```

Remove several known keys:

```dart
await cache.removeMany([
  'dashboard.stats',
  'courses.count',
]);
```

Clear everything only when that is safe:

```dart
await cache.clear();
```

Flint cache stores do not currently provide tags. Use consistent key prefixes
and `removeWhere(...)` when you need group invalidation.

## Service Example

Keep cache behavior in a named service or action file.

File: `lib/services/courses/course_cache.dart`

```dart
import 'package:flint_dart/cache.dart';

import '../../models/course.dart';

class CourseCache {
  CourseCache(this.cache);

  final CacheStore cache;

  Future<Map<String, dynamic>> stats() {
    return cache.remember<Map<String, dynamic>>(
      'courses.stats',
      const Duration(minutes: 5),
      () async {
        final total = await Course().count();
        final published = await Course()
            .where('status', 'published')
            .count();

        return {
          'total': total,
          'published': published,
        };
      },
    );
  }

  Future<void> forgetLists() {
    return cache.removeWhere((key) => key.startsWith('courses.'));
  }
}
```

Route/controller usage should reuse Flint's application cache:

```dart
app.get('/courses/stats', (Context ctx) async {
  final courseCache = CourseCache(ctx.cache);
  final stats = await courseCache.stats();
  return ctx.res?.json({'data': stats});
});
```

Pass `ctx.cache`, `controller.cache`, or `app.cache` into services that accept a
`CacheStore`. Do not create a new `MemoryCacheStore()` inside every request if
the goal is to reuse cached values across requests.

## Response Cache Helpers

`Response` has instance helpers for HTTP cache headers:

```dart
res.cachePublic(
  const Duration(minutes: 5),
  sharedMaxAge: const Duration(minutes: 10),
  immutable: true,
  mustRevalidate: false,
);

res.cachePrivate(
  const Duration(minutes: 5),
  mustRevalidate: true,
);

res.revalidate();
res.noStore();
res.etag('catalog-v1');
res.lastModified(DateTime.now());
```

These helpers write headers on the HTTP response.

`cachePublic(...)` writes:

```text
Cache-Control: public, max-age=<seconds>
```

It can also include:

```text
s-maxage=<seconds>
immutable
must-revalidate
```

Use `public` only when the response is safe for shared caches such as proxies or
CDNs.

`cachePrivate(...)` writes:

```text
Cache-Control: private, max-age=<seconds>
```

Use `private` for browser-only caching of user-specific responses.

`revalidate()` writes:

```text
Cache-Control: no-cache, must-revalidate
```

This allows storage but requires revalidation before reuse.

`noStore()` writes:

```text
Cache-Control: no-store, no-cache, must-revalidate
Pragma: no-cache
Expires: 0
```

Use `noStore()` for login, logout, payments, private account data, and any
response that should not be saved by the browser or an intermediary.

## CacheMiddleware

`CacheMiddleware` applies response cache headers before the route handler runs.
It only applies to:

- `GET`
- `HEAD`
- `QUERY`

It skips methods such as `POST`, `PUT`, `PATCH`, and `DELETE`.

Public cache:

```dart
app
    .get('/catalog', (Context ctx) async {
      final courses = await Course()
          .where('status', 'published')
          .get();

      return ctx.res?.json({'data': courses});
    })
    .useMiddleware(
      CacheMiddleware.public(
        const Duration(minutes: 5),
        sharedMaxAge: const Duration(minutes: 10),
      ),
    );
```

Private cache:

```dart
app
    .get('/me/preferences', (Context ctx) async {
      final user = await ctx.req.user;
      return ctx.res?.json({'theme': user?['theme']});
    })
    .useMiddleware(
      CacheMiddleware.private(
        const Duration(minutes: 2),
        mustRevalidate: true,
      ),
    );
```

No store:

```dart
app
    .get('/account/billing', (Context ctx) async {
      return ctx.res?.json(await BillingSummary().load(ctx));
    })
    .useMiddleware(CacheMiddleware.noStore());
```

Revalidate every time:

```dart
app
    .get('/settings/public', (Context ctx) async {
      return ctx.res?.json(await PublicSettings().load());
    })
    .useMiddleware(CacheMiddleware.revalidate());
```

Since the middleware sets headers before the handler, the handler can still
override them by calling `res.noStore()`, `res.cachePrivate(...)`, or another
response header helper before it writes the response.

## CacheScope

The middleware uses this enum:

```dart
enum CacheScope {
  public,
  private,
  noStore,
  revalidate,
}
```

Most app code should use the named constructors:

```dart
CacheMiddleware.public(...)
CacheMiddleware.private(...)
CacheMiddleware.noStore()
CacheMiddleware.revalidate()
```

Use the raw constructor only when the scope is computed:

```dart
CacheMiddleware(
  scope: CacheScope.public,
  maxAge: const Duration(minutes: 5),
);
```

## ETag Behavior

An ETag is a version value for a response. A client can send:

```text
If-None-Match: "catalog-v1"
```

If the current ETag is the same, the server can return:

```text
304 Not Modified
```

and skip the response body.

In Flint, set an ETag manually:

```dart
return res
    .etag('catalog-v1')
    .json({'data': courses});
```

`res.etag('catalog-v1')` writes:

```text
ETag: "catalog-v1"
```

Weak ETag:

```dart
res.etag('catalog-v1', weak: true);
```

writes:

```text
ETag: W/"catalog-v1"
```

If the value already starts with `W/`, Flint uses it as provided.

## ETagMiddleware

`ETagMiddleware` computes an ETag before running the handler. If
`If-None-Match` exactly matches the response ETag, it returns `304 Not Modified`
and does not call the handler.

```dart
app
    .get('/catalog', (Context ctx) async {
      final courses = await Course()
          .where('status', 'published')
          .get();

      return ctx.res?.json({'data': courses});
    })
    .useMiddleware(
      ETagMiddleware((ctx) => 'catalog-v1'),
    );
```

The value function receives the same `Context` as the route:

```dart
ETagMiddleware((ctx) {
  final locale = ctx.req.queryParam('locale') ?? 'en';
  return 'catalog-$locale-v1';
});
```

The ETag value should be cheap to compute. Good ETag inputs include:

- a deployment version
- a content version column
- the latest `updated_at` timestamp
- a known file hash
- a manually bumped settings version

Avoid doing the expensive work you are trying to skip just to compute the ETag.

Important detail: `ETagMiddleware` compares the exact header value. Since
`res.etag('catalog-v1')` writes `"catalog-v1"`, the client must send:

```text
If-None-Match: "catalog-v1"
```

not:

```text
If-None-Match: catalog-v1
```

## Last-Modified

Use `lastModified(...)` when a response has a meaningful modification time:

```dart
final latestValue = await Course().max('updated_at');
final latest = DateTime.parse(latestValue.toString());

return res
    .lastModified(latest)
    .cachePublic(const Duration(minutes: 5))
    .json({'data': courses});
```

`lastModified(...)` writes an HTTP-date in the `Last-Modified` header.

The response helper only writes the header. It does not automatically check
`If-Modified-Since`. Static file middleware does that automatically for public
files.

## Static Files

`StaticFileMiddleware` has its own file caching behavior for assets in `public`.
It automatically sets:

- `ETag`
- `Last-Modified`
- `Cache-Control`
- MIME type
- compression headers when needed

It can return `304 Not Modified` when the request has a matching
`If-None-Match` or a valid `If-Modified-Since`.

Static file cache rules:

- `index.html`, `manifest.json`, `flint-sw.js`, and files ending in `-sw.js`
  revalidate every request.
- When `FLINT_HOT=1`, static files use no-store/no-cache behavior.
- Fingerprinted assets such as `main.abcdef123456.dart.js` are cached for one
  year with `immutable`.
- Assets requested with a `v` query parameter are cached for one year with
  `immutable`.
- Other public files use the middleware's configured cache duration.

Do not add `CacheMiddleware` around static files unless you have a specific
reason. `StaticFileMiddleware` already handles asset caching.

## Response Cache Vs App Data Cache

Use response cache headers when the whole HTTP response can be reused or
revalidated by the browser/proxy.

Good response-cache cases:

- public catalog pages
- public settings JSON
- versioned assets
- public documentation pages
- read-only `QUERY` search responses with stable query parameters

Use app data cache when the server needs to avoid repeating work before building
a response.

Good app-data-cache cases:

- dashboard counts
- expensive joins or reports
- external API responses
- feature config loaded from the database
- generated recommendation lists

Often, you can use both:

```dart
class PublicCatalogController extends Controller {
  PublicCatalogController(this.cache);

  final CacheStore cache;

  Future<Response> index() async {
    final data = await cache.remember<List<dynamic>>(
      'catalog.public',
      const Duration(minutes: 5),
      () async {
        return await Course()
            .where('status', 'published')
            .get();
      },
    );

    return res
        .cachePublic(
          const Duration(minutes: 2),
          sharedMaxAge: const Duration(minutes: 5),
        )
        .json({'data': data});
  }
}
```

But do not use public response caching for user-specific output. If the response
depends on the current user, tenant, role, cart, session, or private headers,
use `cachePrivate(...)`, `noStore()`, or no response cache header.

## Authenticated Responses

Default rule:

- Public response: `cachePublic(...)` only when every user may see the exact same
  response.
- User-specific response: `cachePrivate(...)` if browser reuse is acceptable.
- Sensitive response: `noStore()`.

Examples:

```dart
// Public and same for everyone.
res.cachePublic(const Duration(minutes: 10));

// Specific to the logged-in browser.
res.cachePrivate(const Duration(minutes: 2), mustRevalidate: true);

// Should not be stored.
res.noStore();
```

For `CacheStore`, include user or tenant identity in the key when data is not
global:

```dart
final user = await req.user;
final key = 'dashboard.${user?['id']}.stats';
```

Do not store one user's private data under a shared key like `dashboard.stats`.

## Controllers And Middleware

For small read routes, route middleware is fine:

```dart
app
    .get('/status', (Context ctx) {
      return ctx.res?.json({'ok': true});
    })
    .useMiddleware(CacheMiddleware.public(const Duration(seconds: 30)));
```

For feature routes, keep caching decisions in controllers or services:

```dart
class DashboardController extends Controller {
  DashboardController(this.cache);

  final CacheStore cache;

  Future<Response> show() async {
    final user = await req.user;
    if (user == null) {
      return res.noStore().status(401).json({'message': 'Unauthorized'});
    }

    final stats = await cache.remember<Map<String, dynamic>>(
      'dashboard.${user['id']}.stats',
      const Duration(minutes: 3),
      () => DashboardStatsAction().call(user['id']),
    );

    return res.cachePrivate(const Duration(minutes: 1)).json({'data': stats});
  }
}
```

Keep controllers request-scoped and register them with `app.controller(...)`.
Do not hide cache behavior in private methods when it is reusable; extract a
service/action in its own file.

## Jobs And Cache

Queue jobs can warm or clear caches after writes:

```dart
class RefreshCatalogCacheJob extends QueueJob {
  @override
  String get type => 'refresh_catalog_cache';

  @override
  Future<void> handle(QueueJobContext ctx) async {
    final cache = FileCacheStore(directory: 'storage/cache');

    await cache.removeWhere((key) => key.startsWith('catalog.'));

    final courses = await Course()
        .where('status', 'published')
        .get();

    await cache.set(
      'catalog.public',
      courses.map((course) => course.toMap()).toList(),
      ttl: const Duration(minutes: 10),
    );
  }
}
```

Jobs do not have an HTTP response, so they should not use `CacheMiddleware` or
response cache helpers. Use `CacheStore` inside jobs.

## Testing Cache

Test app data cache behavior by asserting the loader is only called once:

```dart
test('remember reuses cached value', () async {
  final cache = MemoryCacheStore();
  var calls = 0;

  Future<int> load() async => ++calls;

  expect(await cache.remember('answer', const Duration(minutes: 1), load), 1);
  expect(await cache.remember('answer', const Duration(minutes: 1), load), 1);
  expect(calls, 1);
});
```

Test response cache headers with a fake request/response:

```dart
final handler = CacheMiddleware.public(
  const Duration(minutes: 5),
  sharedMaxAge: const Duration(minutes: 10),
).handle((ctx) async => ctx.res?.send('ok'));
```

Expected header:

```text
Cache-Control: public, max-age=300, s-maxage=600
```

For ETags, test both paths:

- no `If-None-Match`: handler runs and response body is written
- matching `If-None-Match`: middleware returns `304` and handler does not run

## Common Mistakes

- Using `CacheMiddleware` and expecting Flint to store response bodies.
- Using `CacheStore` and expecting browsers to cache HTTP responses.
- Creating a new `MemoryCacheStore()` inside every request.
- Caching user-specific data under a global key.
- Using `cachePublic(...)` for authenticated account data.
- Storing non-JSON values in `FileCacheStore`.
- Storing `null` as a meaningful cached value.
- Forgetting to invalidate list/detail keys after create, update, or delete.
- Computing an ETag with the same expensive work the ETag is meant to avoid.
- Sending `If-None-Match` without the exact quotes/weak prefix Flint wrote.
- Adding cache headers after the response has already been sent.
- Putting cache files under `public/`.

## Review Checklist

Before finishing cache work:

1. The code uses `CacheStore` for app data and response headers for HTTP
   caching.
2. Cache keys include user, tenant, role, query, page, and locale when those
   values change the result.
3. Mutations invalidate all affected keys.
4. Public cache headers are only used for public, shared-safe responses.
5. Private or sensitive responses use `cachePrivate(...)` or `noStore()`.
6. ETag values are cheap and stable.
7. File cache values are JSON-encodable.
8. Cache services/actions live in their own files.
9. Tests cover cache hits, invalidation, and any important response headers.
