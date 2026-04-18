# Flint Dart

A modern, production‑ready backend framework for Dart. Flint Dart gives you routing, middleware, ORM, authentication, validation, views, and auto‑generated Swagger docs—built for real apps, not just demos.

- Website: flintdart.eulogia.net
- Status: Stable Release (v1.0.2)
- Maintainers: Eulogia Technologies

---

## Why Flint Dart

- **Fast, clean routing** for REST APIs
- **Middleware-first** design for security and control
- **Built‑in ORM** for MySQL and PostgreSQL
- **Auth helpers** (JWT + social providers)
- **Validation** on requests (JSON + form)
- **Views** with a simple template engine
- **Swagger UI** auto‑docs from route annotations
- **CLI** to scaffold projects and files

---

## Installation

### 1) Install CLI globally

```bash
# Activate CLI

dart pub global activate flint_dart

# Create a new project
flint create my_app
cd my_app

# Run the app
flint run
```

### 2) Add to an existing project

```bash

dart pub add flint_dart
```

---

## Hello World

```dart
import 'package:flint_dart/flint_dart.dart';

void main() {
  final app = Flint();

  app.get('/', (Context ctx) async {
    return ctx.res?.send('Welcome to Flint Dart!');
  });

  app.listen(port: 3000);
}
```

---

## Routing

```dart
app.get('/users/:id', (Context ctx) async {
  final id = ctx.req.param('id');
  return ctx.res?.json({'id': id});
});

app.post('/users', (Context ctx) async {
  final body = await ctx.req.json();
  return ctx.res?.json({'created': true, 'data': body});
});
```

### Controller-based routes (v1.0.2)

Flint also supports request-scoped controllers for both HTTP and WebSocket routes.
Controller methods can use `req`, `res`, and `socket` directly after binding.

```dart
import 'package:flint_dart/flint_dart.dart';

class UserController extends Controller {
  Future<Response> create() async {
    final body = await req.json();
    return res.json({'created': true, 'data': body});
  }
}

class ChatController extends Controller {
  void connect() {
    socket.emit('connected', {'id': socket.id});
  }
}
```

Route registration:

```dart
app.post(
  '/users',
  controllerAction(UserController.new, (c) => c.create()),
);

app.websocket(
  '/chat',
  controllerAction(ChatController.new, (c) {
    c.connect();
    return null;
  }),
);
```

RouteGroup shorthand (no mixin required):

```dart
class UserRoutes extends RouteGroup {
  @override
  String get prefix => '/users';

  @override
  void register(Flint app) {
    app.post('/', useController(UserController.new, (c) => c.create()));
  }
}
```

### Unified Context handlers

Flint uses a unified `Context` object for route handlers.

- `ctx.req` is always available.
- `ctx.res` is available for HTTP routes.
- `ctx.socket` is available for WebSocket routes.
- `ctx.extras` and `ctx.read<T>()` / `ctx.write<T>()` support future request-scoped injection (e.g. session/user).

```dart
app.get('/health', (Context ctx) {
  return ctx.res?.json({'ok': true});
});

app.websocket('/chat', (Context ctx) {
  ctx.socket?.on('ping', (_) {
    ctx.socket?.emit('pong', {'ok': true});
  });
});
```

### Request helpers

- `ctx.req.param('id')` — route parameter
- `ctx.req.queryParam('page')` — query parameter
- `ctx.req.rawBody()` — raw body bytes for custom decoding/signature checks
- `ctx.req.body()` — raw body string
- `ctx.req.input('key')` — normalized input from query, JSON, form, multipart, files, and params
- `ctx.req.allInput()` — all normalized input
- `ctx.req.validate({...})` — auto-detects request input and validates it
- `ctx.req.json()` — JSON body (Map)
- `ctx.req.form()` — text form fields only (urlencoded or multipart)
- `ctx.req.file('avatar')` / `ctx.req.files('gallery')` — uploaded files

### Response helpers

- `ctx.res?.send('text')`
- `ctx.res?.json({...})`
- `ctx.res?.view('home', data: {...})`
- `ctx.res?.respond(data)` — auto‑detects type
- `ctx.res?.back(fallback: '/settings')` — redirect to previous URL
- `ctx.res?.withSuccess('Saved')` / `ctx.res?.withError('Failed')` — flash messages for next template render

You can also return data directly from a handler. Flint will serialize:
- `Map` / `List` as JSON
- primitives as text/auto response
- custom objects that implement `toMap()` or `toJson()`

```dart
app.post('/settings', (Context ctx) async {
  final data = await ctx.req.validate({'name': 'required|string|min:2'});
  // ... persist data
  return ctx.res
      ?.withSuccess('Settings updated successfully.')
      .back(fallback: '/settings');
});
```

```dart
class UserDto {
  final int id;
  final String email;
  UserDto(this.id, this.email);

  Map<String, dynamic> toMap() => {'id': id, 'email': email};
}

app.get('/me', (Context ctx) async {
  return UserDto(1, 'ada@example.com'); // auto JSON via toMap()
});
```

---

## Middleware

### Global middleware

```dart
app.use(AuthMiddleware());
```

### Route middleware

```dart
app.get('/admin', handler).use(AuthMiddleware());
```

### Route group middleware

```dart
class AdminRoutes extends RouteGroup {
  @override
  String get prefix => '/admin';

  @override
  List<Middleware> get middlewares => [AuthMiddleware()];

  @override
  void register(Flint app) {
    app.get('/users', (Context ctx) async => ctx.res?.json([]));
  }
}
```

Built‑in middleware:
- `ExceptionMiddleware` — error handling
- `CookieSessionMiddleware` — cookies/sessions
- `CorsMiddleware` — CORS headers
- `LoggerMiddleware` — request logging
- `StaticFileMiddleware` — static files

---

## Validation

```dart
app.post('/register', (Context ctx) async {
  final data = await ctx.req.validate({
    'name': 'required|string|min:3',
    'email': 'required|email',
    'password': 'required|string|min:8',
  }, messages: {
    'email.required': 'Email is required.',
    'password.min': 'Password must be at least :min characters.',
  });

  return ctx.res?.json({'ok': true, 'data': data});
});
```

`validate()`, `input()`, and `allInput()` now normalize incoming data for you, so the same handler can accept:

- JSON requests
- `application/x-www-form-urlencoded`
- `multipart/form-data`

Example:

```dart
app.post('/profile', (Context ctx) async {
  final data = await ctx.req.validate({
    'name': 'required|string|min:2',
    'email': 'required|email',
    'avatar': 'required',
  });

  final name = await ctx.req.input('name');
  final avatar = await ctx.req.input('avatar'); // UploadedFile for multipart

  return ctx.res?.json({
    'ok': true,
    'name': name,
    'hasAvatar': avatar != null,
    'data': data,
  });
});
```

Use the lower-level helpers only when you need a specific payload shape:

- `json()` when you want a strict JSON object
- `form()` when you only want text form fields
- `file()` / `files()` when working directly with uploads
- `rawBody()` when you need the exact undecoded payload

## WebSockets

WebSocket emits now normalize common Dart values before JSON encoding, so you can send normal app objects without manually converting everything first.

```dart
app.websocket('/chat', (Context ctx) {
  ctx.socket?.emit('connected', {
    'id': ctx.socket?.id,
    'connectedAt': DateTime.now(),
    'profile': UserDto(1, 'ada@example.com'),
  });
});
```

That means values like `DateTime`, nested `List`/`Map` data, and custom objects with `toMap()` or `toJson()` are converted safely before they are sent over the socket.

---

## Views & Templates

Flint’s view engine uses `.flint.html` templates with a small set of processors. Views live in
`lib/views` and can extend layouts, include partials, loop, and render variables.

### Render a view

```dart
app.get('/', (Context ctx) async {
  return ctx.res?.view('home', data: {'title': 'Flint Docs'});
});
```

### Layouts, sections, and yield

```html
<!-- lib/views/layouts/app.flint.html -->
<!doctype html>
<html>
  <head>
    <title>{{ title ?? 'Flint' }}</title>
  </head>
  <body>
    {{ yield('content') }}
  </body>
</html>
```

```html
<!-- lib/views/home.flint.html -->
{{ extends('layouts.app') }}

{{ section('content') }}
  <h1>{{ title }}</h1>
{{ endsection }}
```

### Includes (partials)

```html
{{ include('partials.nav') }}
```

### Variables

```html
<h2>{{ user.name }}</h2>
```

### Conditionals

```html
{{ if user }}
  <p>Welcome back, {{ user.name }}</p>
{{ endif }}
```

### Loops

```html
<ul>
  {{ for item in items }}
    <li>{{ item }}</li>
  {{ endfor }}
</ul>
```

### Switch / Case

```html
{{ switch status }}
  {{ case 'paid' }}<span>Paid</span>{{ endcase }}
  {{ case 'pending' }}<span>Pending</span>{{ endcase }}
  {{ default }}<span>Unknown</span>{{ enddefault }}
{{ endswitch }}
```

### Built‑in Processors

- `extends` — layout inheritance
- `section` / `yield` — slot content into layouts
- `include` — partials/partials with data
- `variables` — `{{ ... }}` interpolation
- `if_statement` — `if/endif`
- `for_loop` — `for/endfor`
- `switch_cases` — `switch/case/default`
- `comment` — template comments
- `assets` — asset helper tags
- `session` — session/error helpers in templates
- `old_processor` — legacy tags support

---

## Mail (SMTP + Flint Templates)

Flint supports sending email with SMTP and rendering email bodies from `.flint.html` templates.

### Auto connect mail on app start

Mail config is loaded automatically when the server starts:

```dart
final app = Flint(); // autoConnectMail is true by default
await app.listen(port: 3000);
```

If you want full manual control:

```dart
final app = Flint(autoConnectMail: false);
await MailConfig.load(); // manual setup from .env
await app.listen(port: 3000);
```

### `.env` mail config

```bash
MAIL_PROVIDER=custom   # custom | gmail | outlook | yahoo
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=your_username
MAIL_PASSWORD=your_password
MAIL_ENCRYPTION=tls    # tls | ssl
MAIL_FROM_ADDRESS=noreply@example.com
MAIL_FROM_NAME=My App
```

### Send mail directly

```dart
await Mail()
    .to('user@example.com')
    .subject('Welcome')
    .html('<h1>Hello</h1>')
    .text('Hello')
    .sendMail();
```

Text-only mail:

```dart
await Mail()
    .to('user@example.com')
    .subject('Plain Text Message')
    .text('Hello from Flint Mail')
    .sendMail();
```

### Use Flint view templates for mail (`ViewMailable`)

Generate a mail class + template:

```bash
flint make:mail welcome
```

This creates:
- `lib/mail/welcome_mail.dart`
- `lib/mail/views/welcome.flint.html`

Example:

```dart
import 'package:flint_dart/mail.dart';

class WelcomeMail extends ViewMailable {
  final String recipientName;
  final String recipientEmail;

  WelcomeMail({
    required this.recipientName,
    required this.recipientEmail,
  });

  @override
  String get subject => 'Welcome';

  @override
  String get view => 'mail/views/welcome.flint.html';

  @override
  Map<String, dynamic> get data => {
        'recipientName': recipientName,
      };

  @override
  List<String> get to => [recipientEmail];
}

await WelcomeMail(
  recipientName: 'Ada',
  recipientEmail: 'ada@example.com',
).send();
```

### Template rendering notes

- For web pages, use `ctx.res?.view('home', data: {...})` with templates in `lib/views`.
- For mail templates, `ViewMailable` renders your `.flint.html` file via `TemplateEngine().render(...)`.
- If you are looking for old names like `viewFlintTemplate` or `Viewable`, use the current APIs above (`view`, `TemplateEngine`, `ViewMailable`).

---

## ORM (CRUD)

```dart
// READ
final user = await User().find(1);
final users = await User()
  .where('email', 'test@example.com')
  .orderBy('created_at', desc: true)
  .limit(10)
  .get();

// CREATE
final created = await User().create({
  'name': 'Ada',
  'email': 'ada@example.com',
  'password': 'secret',
});

// UPDATE
await User()
  .where('id', 1)
  .update(data: {'name': 'Ada Lovelace'});

// DELETE
await User().delete(1);
```

### Extra ORM helpers

- `save()` — create/update based on PK
- `firstOrCreate(where, data)`
- `upsert(where, data)` / `upsertMany([...])`
- `countAll()` / `countWhere(field, value)`

---

## Seeders

Flint seeders are meant to run through a registry file.

The main entry point is:

```text
lib/config/seeder_registry.dart
```

That registry is what `flint --db-seed` runs, and it is the file the seeder generator updates when you create new seeders.

Example registry:

```dart
import 'package:flint_dart/flint_dart.dart';
import '../seeders/user_model_seeder.dart';
import '../seeders/post_model_seeder.dart';

Future<void> main() async {
  await runSeeders([
    UserModelSeeder(),
    PostModelSeeder(),
  ]);
}
```

Create a seeder:

```bash
flint make:seeder UserModelSeeder
```

Run all registered seeders:

```bash
flint --db-seed
```

If you want people on your team to follow one pattern, this is the one to emphasize:

- create seeders in `lib/seeders`
- register them in `lib/config/seeder_registry.dart`
- run them through `flint --db-seed`

---

## Models & Tables

```dart
class User extends Model<User> {
  User() : super(() => User());

  String get name => getAttribute('name');
  String get email => getAttribute('email');

  @override
  Table get table => Table(
        name: 'users',
        columns: [
          Column(name: 'name', type: ColumnType.string, length: 255),
          Column(name: 'email', type: ColumnType.string, length: 255),
        ],
      );
}
```

---

## Relations

```dart
class User extends Model<User> {
  @override
  Map<String, RelationDefinition> get relations => {
        'posts': Relations.hasMany('posts', () => Post()),
      };
}

class Post extends Model<Post> {
  @override
  Map<String, RelationDefinition> get relations => {
        'author': Relations.belongsTo('author', () => User()),
      };
}

final posts = await Post().withRelation('author').get();
```

---

## Auth (JWT + Providers)

### Register / Login

```dart
final user = await Auth.register(
  email: data['email'],
  password: data['password'],
  name: data['name'],
  additionalData: {'role': 'admin'},
);

final result = await Auth.login(data['email'], data['password']);
```

### Access + Refresh Tokens (Optional)

Refresh token support is opt-in and disabled by default to keep framework behavior flexible.

```dart
final tokens = await Auth.loginWithTokens(
  data['email'],
  data['password'],
  throttleKey: req.ipAddress, // optional
  ipAddress: req.ipAddress,   // optional metadata
  userAgent: req.headers['user-agent'],
  deviceName: 'web',
);

final rotated = await Auth.refreshAccessToken(
  tokens['refreshToken'],
  rotateRefreshToken: true,
);
```

Revoke helpers:

```dart
await Auth.revokeRefreshToken(refreshToken);
await Auth.revokeAllRefreshTokensForUser(userId);
```

### Login Throttle (Optional)

Login throttle/lockout is also opt-in and disabled by default.

```dart
final result = await Auth.login(
  data['email'],
  data['password'],
  throttleKey: req.ipAddress, // optional (ip/device/etc)
);
```

### OAuth Providers

```dart
final url = Auth.providerRedirectUrl(
  provider: 'google',
  redirectPath: '/auth/google/callback',
);
```

Supported providers: Google, GitHub, Facebook, Apple.

### Auth Environment Options

```bash
# Existing
JWT_SECRET=change-me-to-a-strong-secret
JWT_EXPIRY_HOURS=24
PASSWORD_MIN_LENGTH=6

# Optional refresh-token flow
AUTH_ENABLE_REFRESH_TOKENS=false
AUTH_ACCESS_TOKEN_MINUTES=60
AUTH_REFRESH_TOKEN_DAYS=30

# Optional login throttle
AUTH_ENABLE_LOGIN_THROTTLE=false
AUTH_LOGIN_MAX_ATTEMPTS=5
AUTH_LOGIN_LOCK_MINUTES=15
```

---

## File Uploads & Storage

```dart
final upload = await ctx.req.file('avatar');
if (upload != null) {
  final path = await ctx.req.storeFile('avatar', directory: 'public/uploads');
}
```

---

## AI Runtime

Flint now exposes one AI system only: `ai`.

The AI layer is organized around:

- providers
- tools
- workflows
- memory
- runtime

### Framework entry points

```dart
final app = Flint();

app.ai.registerChatProvider(OpenAiChatProvider(apiKey: 'openai-key'));

app.get('/ai/chat', (Context ctx) async {
  final result = await ctx.ai.chat(
    providerId: 'openai',
    request: const ChatRequest(
      model: 'gpt-4o-mini',
      messages: [
        ChatMessage(role: 'user', content: 'Say hello'),
      ],
    ),
  );

  return ctx.res?.json(result.toMap());
});
```

You can also opt into stricter production defaults:

```dart
final ai = FlintAi.production(
  memoryStore: AutoAiMemoryStore(),
  repository: AutoAiRepository(),
);
```

### Register providers, tools, workflows, memory, and persistence

```dart
final app = Flint();

app.ai.registerChatProvider(OpenAiChatProvider(apiKey: 'openai-key'));
app.ai.registerTool(SummarizeTicketTool());
app.ai.registerWorkflow(SupportEscalationWorkflow());

// Optional explicit production wiring
final hardenedAi = FlintAi.production(
  memoryStore: AutoAiMemoryStore(),
  repository: AutoAiRepository(),
);
```

### Runtime model

- `AiAgent` defines planning and synthesis
- `AiTool` performs controlled side effects
- `AiWorkflow` handles higher-level orchestration
- `AiMemoryStore` tracks run memory
- `AiRepository` persists runs, traces, threads, and artifacts

### Memory and persistence APIs

```dart
await ctx.ai.saveThreadMessage('thread-42', {
  'role': 'user',
  'content': 'Customer cannot reset password',
});

final thread = await ctx.ai.loadThreadMessages('thread-42');
final events = await ctx.ai.loadRunEvents('run-id');
```

### Production note

Flint uses auto-configured AI memory and repository stores by default:

- when the database is connected, DB-backed stores are used
- when it is not connected, Flint falls back to in-memory stores with warnings

For production, connect the database or provide explicit shared stores so runs, traces, threads, and memory survive restarts and work across workers.

### Built-in chat providers

- `OpenAiChatProvider`
- `AnthropicChatProvider`
- `GeminiChatProvider`

These live under `ai` and use the shared AI provider abstractions. There is no separate public `agent` namespace anymore.

### End-to-end example

```dart
class SummarizeTicketTool extends AiTool {
  @override
  String get name => 'support.summarize';

  @override
  String get description => 'Formats a support summary.';

  @override
  bool get enabledByDefault => true;

  @override
  Future<Map<String, dynamic>> execute(AiToolContext context) async {
    final issue = context.arguments['issue']?.toString() ?? '';
    return {'summary': 'Customer issue: $issue'};
  }
}

class SupportAgent extends AiAgent {
  @override
  String get name => 'support_agent';

  @override
  Future<AiPlan> plan(AiRunContext context) async {
    return AiPlan(
      steps: [
        AiPlanStep(
          id: 'summarize',
          type: 'tool',
          description: 'Create a support summary',
          toolName: 'support.summarize',
          arguments: {'issue': context.goal.input['issue']},
        ),
      ],
    );
  }

  @override
  Future<Map<String, dynamic>> synthesize(AiRunContext context) async {
    return {
      'summary': (context.state['summarize'] as Map)['summary'],
      'events': context.run.events.map((event) => event.toMap()).toList(),
    };
  }
}

final app = Flint();
app.ai.registerTool(SummarizeTicketTool());

app.post('/ai/support', (Context ctx) async {
  final body = await ctx.req.json();
  final threadId = body['threadId']?.toString() ?? 'support-thread';

  await ctx.ai.saveThreadMessage(threadId, {
    'role': 'user',
    'content': body['issue'],
  });

  final run = await ctx.ai.run(
    agent: SupportAgent(),
    goal: AiGoal(
      task: 'Resolve support request',
      input: {'issue': body['issue']},
    ),
    userId: 'support-user',
    threadId: threadId,
    context: ctx,
  );

  return ctx.res?.json({
    'run': run.toMap(),
    'thread': await ctx.ai.loadThreadMessages(threadId),
    'events': await ctx.ai.loadRunEvents(run.run.id),
  });
});
```

---

## Swagger UI (Auto Docs)

Enable docs and visit:

```
http://localhost:3000/docs
```

Flint parses annotations above your routes:

```dart
/// @summary Create a new user
/// @auth bearer
/// @response 201 Created
/// @query page integer optional Page
/// @body {"name": "string", "email": "string"}
app.post('/users', controller.create);
```

---

## Database

Configure `.env`:

```bash
DB_CONNECTION=mysql
DB_HOST=localhost
DB_PORT=3306
DB_NAME=flint
DB_USER=root
DB_PASSWORD=secret
DB_SECURE=false
```

Auto‑connect runs on server start. You can disable it and call `DB.connect()` manually.

```dart
final app = Flint(autoConnectDb: false);

try {
  await DB.connect(
    database: env('DB_NAME', 'app_db'),
    host: env('DB_HOST', 'localhost'),
    port: env('DB_PORT', 3306),
    username: env('DB_USER', 'root'),
    password: env('DB_PASSWORD', ''),
  );
} catch (e) {
  Log.debug('Database connection failed: $e');
}
```

---

## Logging

By default, Flint logs to console and does not create log files.

Use `.env` to control logging:

```bash
LOG_ENABLED=true
LOG_TO_CONSOLE=true
LOG_TO_FILE=false
LOG_DIR=logs
LOG_LEVEL=debug
```

- `LOG_TO_FILE=false` prevents creating log files on user systems.
- Set `LOG_TO_FILE=true` only when you want persisted log files.

---

## CLI

```bash
flint create my_app
flint run
flint build
flint docs:generate
flint make:model User
flint make:controller UserController
flint make:middleware AuthMiddleware
```

---

## Contributing

Contributions are welcome. Open issues, suggest improvements, or submit PRs.

---

## License

MIT
