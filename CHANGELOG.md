

Perfect — here’s a **complete and well-structured changelog Markdown (`CHANGELOG.md`)** for **Flint Dart — Version 1.0.0+10**, integrating your new **Flint UI system**, with consistency to your previous release format and style.
It highlights new UI, database, and internal framework enhancements with developer examples.

---

````markdown
# 🚀 Flint Dart — Version 1.0.0+10

Flint Dart continues to evolve into a complete **backend + UI ecosystem for Dart**, combining powerful server-side tools with a new rendering engine — **Flint UI**.

---

## 🎨 Flint UI — Cross-Platform Rendering System

Flint UI introduces a **Flutter-like declarative UI engine** for generating **HTML, email layouts, and console output** directly from Dart — no React or HTML strings required.

### ✨ Core Concept

Flint UI widgets are **class-based**, **composable**, and **type-safe**, similar to Flutter widgets — but designed for rendering to multiple formats (HTML, text, JSON).

```dart
final button = FlintButton(
  text: "Click Me",
  onClick: () => print("Button clicked!"),
  style: ButtonStyle(color: "#0066FF"),
);
````

This can render to:

```html
<button style="background-color:#0066FF;">Click Me</button>
```

or to plain text:

```
[Click Me]
```

---

### 🧱 Widget Architecture

Every Flint UI element extends `FlintWidget`, which defines multi-output rendering:

```dart
abstract class FlintWidget {
  String toHtml();
  String toText();
  Map<String, dynamic> toJson();
}
```

Flint UI currently includes:

| Widget                     | Purpose                                      |
| -------------------------- | -------------------------------------------- |
| `FlintText`                | Render styled text                           |
| `FlintButton`              | Interactive button element                   |
| `FlintImage`               | Display images with `ImageStyle`             |
| `FlintContainer`           | Layout box with padding, border, and shadows |
| `FlintRow` / `FlintColumn` | Flexbox-style layout widgets                 |
| `FlintCard`                | For email-style components                   |
| `FlintSpacer`              | Adds layout spacing between elements         |

---

### 🎨 Styling System

Flint UI introduces **style classes** for full layout and visual control, mirroring Flutter's intuitive APIs.

#### 🖼️ ImageStyle

```dart
const ImageStyle(
  opacity: 0.9,
  fit: ObjectFit.cover,
  filter: "grayscale(100%)",
  title: "Profile Picture",
);
```

➡️ Converts to:

```css
opacity: 0.9;
object-fit: cover;
filter: grayscale(100%);
```

#### 📦 BoxStyle

Includes `BoxBorder`, `BorderRadius`, `BoxShadow`, and `BoxConstraints`.

```dart
FlintContainer(
  style: BoxDecoration(
    gradient: Gradient.linear(
      stops: [
        ColorStop("#FF5733", 0.0),
        ColorStop("#FFC300", 1.0),
      ],
    ),
  ),
);
```

➡️ Generates:

```css
background: linear-gradient(to bottom, #FF5733 0%, #FFC300 100%);
```

---

### 📄 Output Formats

| Format      | Method                                           | Description |
| ----------- | ------------------------------------------------ | ----------- |
| `.toHtml()` | Returns HTML markup for emails and web           |             |
| `.toText()` | Returns text-only layout (for CLI or plain mail) |             |
| `.toJson()` | Returns serializable structure (for API UI sync) |             |

---

### 💡 Use Case Examples

#### Email Templates

```dart
final email = FlintContainer(
  child: FlintColumn(children: [
    FlintText("Welcome to Flint!", style: TextStyle(fontSize: 24)),
    FlintButton(text: "Get Started", onClick: () {}),
  ]),
);

print(email.toHtml());
```

#### Server-Side Rendering (SSR)

Use Flint UI widgets to **generate HTML views** for your backend routes.

```dart
app.get('/welcome', (req, res) {
  final ui = FlintText("Welcome to Flint Server!");
  return res.html(ui.toHtml());
});
```

---

## 🧩 Database Enhancements

Flint Dart’s ORM and schema engine continue to mature with smarter migration logic and framework-level introspection.

### 🕓 Auto–Managed Timestamp Columns

Flint automatically injects `created_at` and `updated_at` columns into every table migration (if missing).

```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

✅ Supported on **MySQL** and **PostgreSQL**.

---

### 🔐 Auth Table Enhancements

When the table matches your `.env` `AUTH_TABLE` (e.g. `users`), Flint automatically adds:

| Column        | Type         | Purpose                               |
| ------------- | ------------ | ------------------------------------- |
| `provider`    | VARCHAR(100) | Login provider (Google, GitHub, etc.) |
| `provider_id` | VARCHAR(255) | Provider user ID                      |

Example `.env`:

```
AUTH_TABLE=users
AUTH_PROVIDER_COLUMN=provider
AUTH_PROVIDER_ID_COLUMN=provider_id
```

💡 Non-auth tables skip these fields automatically.

---

## 📫 Mail System Upgrade

### 🧠 Smarter Configuration via `.env`

Flint’s Mail system now reads all SMTP credentials directly from `.env`.

```env
MAIL_PROVIDER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=youremail@gmail.com
MAIL_PASSWORD=yourpassword
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=youremail@gmail.com
MAIL_FROM_NAME=Eulogia Technologies
```

### ⚙️ Automatic Setup

Initialize with:

```dart
await MailConfig.load();
```

✅ Auto-detects provider
✅ Applies SSL/TLS
✅ Logs configuration status

Example output:

```
📧 Mail configured for provider: gmail (youremail@gmail.com)
```

---

### 🧰 Mail API Enhancements

* `.from()` → Custom sender via `.env`
* `.queue()` → Background mail sending with isolates
* `.sendMail()` → Automatic plain-text fallback
* Unified configuration for all SMTP providers

Example:

```dart
await Mail()
  .to("user@example.com")
  .subject("Welcome to Flint Dart!")
  .html("<h1>Hello!</h1>")
  .sendMail();
```

---

## 🪶 Internal Framework Improvements

* Fixed MySQL syntax for index creation (`CREATE INDEX IF NOT EXISTS`).
* Improved migration resilience for missing columns.
* Added consistent JSON serializers for all UI classes.
* Flint CLI updates for better hot reload and DB sync logging.
* Framework-level integration between **Flint UI** and **Mail API** for generating email bodies via widgets.

---

## 📚 Documentation Updates

* Added **Flint UI Developer Guide**
* Added **Flint Mail Setup & .env Reference**
* Added **Database Schema Enhancements** section
* Added **UI JSON Output** specification for external integrations
* Updated **Framework Change Log** and migration system examples

---

> Built with ❤️ by **Eulogia Technologies**
> Empowering Dart developers to build **modern full-stack systems** — backend + UI — all in Dart.

```


# 🚀 Flint Dart — Version 1.0.0+7

Flint Dart continues to evolve into a complete backend framework for Dart  modern tooling, and now a powerful real-time WebSocket system.
````markdown
# 🚀 Flint Dart — Version 1.0.0+6

Flint Dart continues to evolve into a complete backend framework for Dart developers — with Laravel-style syntax, modern tooling, and now a powerful real-time WebSocket system.




---

## 🧩 WebSocket System (Major Upgrade)

### 🔁 Socket.IO–like API
Flint now ships with an easy-to-use WebSocket engine with event-based communication:

```dart
app.ws('/chat', (socket, params) {
  socket.on('message', (data) {
    print('💬 ${socket.id} says: $data');
    socket.broadcastToRoom('chat', {'event': 'message', 'data': data});
  });
});
````

Client-side:

```dart
final ws = FlintWebSocketClient("wss://api.example.com/chat");
ws.on('message', (data) => print("📩 $data"));
ws.emit('message', {'text': 'Hello World'});
```

---

### 💬 Core Features

* **`.emit(event, data)`** → Send named events easily
* **`.on(event, callback)`** → Listen for specific events
* **`.onMessage()`** and **`.onJsonMessage()`** remain supported for backward compatibility
* **`.join(room)`** and **`.leave(room)`** for group messaging
* **`.broadcast()`** and **`.broadcastToRoom()`** for real-time updates
* **Auto Reconnect** on the client when connection drops
* **JWT Support** using the same middleware chain as HTTP routes
* **Auth Middleware** can now protect both HTTP and WebSocket connections

---

## 🧠 Middleware Enhancements

Middleware can now be used directly on WebSocket routes with the same `.useMiddleware()` API.

### Example

```dart
app.ws('/notifications', (socket, params) {
  socket.on('ping', (_) => socket.emit('pong', 'ok'));
}).useMiddleware(AuthMiddleware());
```

### WebSocket Auth Example

```dart
class AuthMiddleware extends Middleware {
  @override
  Handler handle(Handler next) {
    return (Request req, Response res) async {
      final token = req.bearerToken;
      if (token == null || token != "expected_token") {
        return res.status(401).send("Unauthorized");
      }
      return await next(req, res);
    };
  }
}
```

---

## 📫 Mail Integration

WebSocket events can now trigger Flint's Mail API, enabling instant notification workflows (e.g., send an email when a user joins a chat).

```dart
socket.on('userJoined', (data) async {
  await Mail.to(data['email']).subject("Welcome!").send("Welcome to the chat!");
});
```

---

## 🧩 Developer Experience

* Unified `.emit()` and `.on()` API across both **server and client**
* Auto-room management for group messages
* Cleaner connection logs:

  ```
  ✅ Client connected: <uuid>
  ❌ Client disconnected: <uuid>
  ```
* Consistent `app.ws()` route definition similar to `app.get()` and `app.post()`

---

## 🧰 CLI & Internal

* Stability improvements for CLI and WebSocket debugging
* Hot reload-safe connections for development
* No new CLI commands introduced in this version

---

## 📚 Documentation

* Added **WebSocket Usage Guide**:

  * Connecting with JWT
  * Using `.emit()` and `.on()`
  * Broadcasting
  * Room system
* Added **Middleware for WebSockets** section.
* Added example for mail integration within socket events.
* Updated Swagger documentation to include WebSocket annotations *(experimental)*

> Built with ❤️ by **Eulogia Technologies**
> Empowering Dart developers to build modern, scalable backends.

```

---


```

## 1.0.0+5

### Middleware
- Added `.useMiddleware()` API for attaching middleware directly to routes, making route-level middleware usage cleaner and more expressive.  
  Example:  
  ```dart
  app.get('/profile', controller.show).useMiddleware(AuthMiddleware());
Fixed bugs in middleware chaining to ensure multiple middlewares execute in the correct order.

Database
Minor internal bug fixes in query builder (stability improvements).

Response API
No changes.

Static Files
No changes.

Error Handling
Stability improvements when using custom middlewares with ExceptionMiddleware.

📄 Swagger Documentation
Flint Dart ships with best-in-class API documentation out of the box. Using Swagger-style annotations, you can describe your routes directly in code and automatically generate OpenAPI specifications with an interactive Swagger UI.

Annotating Routes
Add /// comments above each route to document summary, request body, responses, and security requirements.

dart
Copy code
import 'package:flint_dart/flint_dart.dart';
import 'package:sample/src/middlewares/auth_middleware.dart';
import '../controllers/user_controller.dart';

void registerUserRoutes(Flint app) {
  final controller = UserController();

  /// @summary List all users
  /// @server http://localhost:3000
  /// @server https://api.mydomain.com
  /// @prefix /users
  app.get("/", controller.index);

  /// @summary Get a user by ID
  /// @prefix /users
  app.get("/:id", controller.show);

  /// @prefix /users
  /// @summary Create a new user
  /// @response 200 User registered successfully
  /// @response 404 User not found
  /// @body {"email": "string", "password": "string"}
  app.post('/', controller.create);

  /// @prefix /users
  app.put('/:id', AuthMiddleware().handle(controller.update));

  /// @prefix /users
  /// @auth basicAuth
  app.delete('/:id', AuthMiddleware().handle(controller.delete));
}
Supported Annotations
@summary → Short description of the endpoint.

@server → Define server base URLs.

@prefix → Path prefix for grouped routes.

@response [code] [description] → Document response codes.

@body {} → Example request body JSON.

@auth [scheme] → Specify authentication (e.g., basicAuth, bearerAuth).

Generating Swagger UI
Flint Dart parses these annotations and serves Swagger docs at /docs or /swagger.
Developers can explore and test endpoints directly from the browser.


void main() {
  // Enable swagger docs
  final app = Flint(enableSwaggerDocs: true);

  // Register routes
  app.mount("/users", registerUserRoutes);

  app.listen(3000);
}
CLI Commands
Flint Dart also includes CLI tools to manage and export your API documentation.
This keeps docs in sync with your routes and is useful for CI/CD pipelines.

# Generate Swagger JSON from your routes
flint docs:generate
Example Swagger UI
After running your app, visit:
👉 http://localhost:3000/docs
to view the interactive API documentation generated from your annotations.

Docs
Updated middleware documentation with new .useMiddleware usage examples.

Added notes on bug fixes for route-level middleware chaining.

Added new section for Swagger docs integration with setup guide and usage examples.


## 1.0.0+4
### Database
- Added `whereIn` query builder method for filtering by a list of values.  
  Example:  
  ```dart
  await User.query().whereIn('id', [1, 2, 3]);
Added as alias support in query builder.
Example:

dart
Copy code
await User.query().select(['id', 'name.as(username)']).get();
PostgreSQL integration fully verified:

Auto-increment (primary key sequences) working correctly.

Migrations and schema syncing stable.

Middleware
ExceptionMiddleware now handles a wider range of errors globally:

FormatException

TimeoutException

ArgumentError

PgException

MySQLClientException

MySQLException

ForbiddenError

Generic Exception

Response API
No changes (see +3 for chaining improvements).

Static Files
No changes.

Error Handling
No changes (ExceptionMiddleware improvements listed above).

Docs
Added usage examples for whereIn and as in query builder section.

Updated middleware docs to reflect new exception handling coverage.


## 1.0.0+3
- Database: Added autoConnectDb flag to allow disabling automatic DB connection (app.listen(port, autoConnectDb: false)).
# Middleware:
- Added default ExceptionMiddleware (handles ValidationException and unexpected errors globally).
- Added withDefaultMiddleware flag to let users disable auto-injected middlewares.
# Response API: 
- All Response helpers (json, send, status, etc.) now return Response for consistent chaining.
- Handler typedef: Updated to FutureOr<Response?> Function(Request, Response) for better type safety and chaining.
# Static Files: 
- Fixed static file serving to always return a Response.
# Error Handling:
- Default 404 Not Found handler now returns a proper response.

# Docs: 
- Improved docstrings for autoConnectDb, withDefaultMiddleware, and middleware behavior.

## 1.0.0+2
- Initial public release of Flint Dart.
- Added Websocket.

## 1.0.0+1
- Initial public release of Flint Dart.
- Added CLI commands: `create`, `start`, `migrate`, `make:model`.
- Added MySQL and PostgreSQL ORM support.

## 1.0.0
- Bug fixes in migration system.
