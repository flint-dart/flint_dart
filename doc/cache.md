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

Route/controller usage should reuse the same cache store:

```dart
final appCache = MemoryCacheStore();
final courseCache = CourseCache(appCache);

app.get('/courses/stats', (Context ctx) async {
  final stats = await courseCache.stats();
  return ctx.res?.json({'data': stats});
});
```

For real apps, create the cache store once and inject or pass it into services.
Do not create a new `MemoryCacheStore()` inside every request if the goal is to
reuse cached values across requests.

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
