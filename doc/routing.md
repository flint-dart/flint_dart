# Routing

Routing is implemented by `Flint`, `Router`, `RouteBuilder`, and `RouteGroup`.

## Registering Routes

`Flint` exposes helpers for `get`, `post`, `put`, `patch`, `delete`, `query`, and arbitrary `route`.

```dart
app.get('/users/:id', (Request req, Response res) async {
  final id = req.params['id'];
  return res.json({'id': id});
});

app.route('HEAD', '/health', (req, res) {
  return res.status(204).send('');
});
```

`example/lib/routes/user_routes.dart` registers routes inside a group:

```dart
class UserRoutes extends RouteGroup {
  @override
  String get prefix => '/users';

  @override
  void register(Flint app) {
    final controller = UserController();
    app.get("/", controller.index).useMiddleware(AuthMiddleware());
    app.get("/:id", controller.show).useMiddleware(LoggerMiddleware());
    app.post('/', controller.create);
  }
}
```

Register the group with:

```dart
app.routes(UserRoutes());
```

## Route Matching

`Router.match()` tries routes in this order:

1. Exact and parameter matches for the request method.
2. Wildcard routes ending in `/*`.
3. `HEAD` fallback to matching `GET`.
4. `OPTIONS` or `405 Method Not Allowed` when the path exists for another method.

Path parameters use `:name`:

```dart
app.get('/posts/:id', (req, res) => res.json({'id': req.param('id')}));
```

The router also supports parameter regex segments:

```dart
app.get('/users/:id(\\d+)', (req, res) {
  return res.json({'id': req.params['id']});
});
```

Internally, `RouteBuilder.normalizedPath` ensures a leading slash and removes a trailing slash except for `/`. `Flint.normalizePath()` also collapses duplicate slashes on incoming requests.

## Route Groups and Mounting

`RouteGroup` provides:

```dart
abstract class RouteGroup {
  String get prefix => '';
  String get tag => '';
  List<Middleware> get middlewares => const [];
  void register(Flint app);
}
```

`Flint.routes(group, children: [...])` calls `mount()`. `mount()` creates a sub-`Flint`, registers the group routes into it, then copies those routes into the parent with the prefix and group middleware applied.

Middleware order is:

```text
global middleware
group/mount middleware
route-specific middleware
handler
```

## Controller Helpers

There are two controller styles in the repository.

Simple controllers can expose `(Request, Response)` methods, as in `example/lib/controllers/post_controller.dart`:

```dart
class PostController {
  Future<Response> store(Request req, Response res) async {
    await req.validate({'title': 'required|string|min:3'});
    return res.json({'message': 'created'});
  }
}
```

Request-scoped controllers can extend `Controller` and be bound per request:

```dart
class ProfileController extends Controller {
  Future<Object?> show() async {
    final user = await req.user;
    return res.json({'user': user});
  }
}

app.controller(ProfileController.new).get('/profile', (c) => c.show());
```

Internally, `controllerAction()` creates a fresh controller, calls `bind(ctx)`, runs the callback, and then calls `unbind()`.

## Important Limits

- Wildcards only match route paths ending in `/*`.
- Route-specific middleware must be added through `.useMiddleware(...)`; the code does not expose a `.use(...)` alias on `RouteBuilder`.
- `QUERY` is supported by Flint's router but is not a standard OpenAPI operation key.
- `mount()` creates a new `Flint(rootPath: rootPath)`, so default middleware is also constructed on the sub-app, but only route handlers and route middleware are copied to the parent.
