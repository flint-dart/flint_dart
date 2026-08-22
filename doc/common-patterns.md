# Common Patterns

## Return Values

Handlers may write a response directly or return data. `Flint._applyHandlerResult()` handles returned values:

```dart
app.get('/health', (req, res) {
  return {'ok': true};
});
```

Maps, lists, `Model` instances, and objects with `toMap()` or `toJson()` become JSON. Other values go through `Response.respond()`.

## Request Input

Use the specific parser when you know the content type:

```dart
final body = await req.json();
final form = await req.form();
final file = await req.file('avatar');
final input = await req.allInput();
```

`Request.rawBody()` caches bytes so the body can be reused for custom decoders or signature verification.

## Responses

Common helpers:

```dart
return res.json({'ok': true});
return res.status(404).json({'message': 'Not found'});
return res.send('hello');
return res.redirect('/login');
return res.back(fallback: '/');
return res.view('emails.welcome', data: {'name': 'Ada'});
return res.page('Welcome', props: {'version': '1.0.4'});
```

`res.view()` looks for `lib/views/<name>.flint.html` and then `lib/views/<name>.html`. Dot notation maps to nested paths.

## Context Extras

`Context` supports keyed and type-keyed storage:

```dart
class CurrentTenant {
  final String id;
  CurrentTenant(this.id);
}

class TenantMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (ctx) {
      ctx.write(CurrentTenant(ctx.req.headers['x-tenant'] ?? 'default'));
      return next(ctx);
    };
  }
}

app.get('/tenant', (ctx) {
  final tenant = ctx.read<CurrentTenant>();
  return ctx.res?.json({'tenant': tenant?.id});
});
```

## File Uploads

Multipart uploads become `UploadedFile` objects:

```dart
if (await req.hasFile('profile_pic')) {
  final saved = await req.storeFile('profile_pic', directory: 'public/uploads');
  return res.json({'path': saved});
}
```

The sample `UserController.update` uses `req.hasFile`, `req.file`, and `Storage.update/create`.

## Models In JSON

`Response.json()` recursively converts:

- `DateTime` to ISO strings
- `Model` to `toMap()`
- lists and maps recursively
- custom objects through `toMap()` or `toJson()` when present

This is why `PostController.index` can return:

```dart
return res.json({
  'message': 'PostController index',
  'data': await PostModel().all(),
});
```

## Query Safety

Prefer query builder methods or `DB.query` parameters:

```dart
await DB.query(
  'SELECT * FROM users WHERE email = :email',
  namedParams: {'email': email},
);
```

Do not interpolate untrusted request input into SQL strings.

## Important Limits

- `Response.redirect()` sets status and `Location` but does not close automatically; return it from the handler so Flint can finish the response.
- `Request.isAuthenticated` only checks cached storage, so call `await req.user` first.
- `Response.view()` falls back to raw file content if template rendering throws.
- `StaticFileMiddleware` skips `/api`, `/docs`, `/swagger`, and other known dynamic prefixes.
