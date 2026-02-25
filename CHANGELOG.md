# Flint Dart Changelog

All notable changes to this project are documented in this file.

## [1.0.0+29] - 2026-02-25

### Release Status
- Public release build.

### Added
- Added request-scoped `Controller` base with `bind(Context)` and internal context storage.
- Added controller getters: `req`, `res`, `socket`, plus `isHttp` / `isWebSocket`.
- Added meaningful controller context errors when `res` is used in WebSocket routes or `socket` is used in HTTP routes.
- Added `controllerAction(...)` helper for binding controller instances per HTTP/WebSocket route invocation.
- Added `useController(...)` and `useControllerVoid(...)` extension helpers for shorter route group controller registration.
- Added extensible `Context.extras` storage and typed `read<T>()` / `write<T>()` helpers for future session/user injection.

### Changed
- Added controller-based HTTP and WebSocket route examples to the example app and docs.
- Updated route-group examples to use controller actions without `Context` method parameters inside controllers.

## [1.0.0+28] - 2026-02-18

### Release Status
- Public release build.

### Changed
- Bumped package version to `1.0.0+28`.

## [1.0.0+27] - 2026-02-11

### Release Status
- Public stable release `1.0.1` is planned for a later date.

### Added
- Added new documentation screens in `flint_docs`: `What's New` and `Changelog`.
- Added automatic loading of framework release notes from `flint_dart/CHANGELOG.md` in the changelog page.

### Changed
- Updated documentation to a context-first handler style using `(Context ctx)` examples.
- Refined WebSocket route examples to emphasize route-level middleware usage.

### Improved
- Improved changelog UI readability with one card per version.
- Clarified route handler return behavior for serializable values.

### Fixed
- Fixed response lifecycle handling to avoid duplicate header-write crashes in error paths.
- Simplified WebSocket route flow by relying on route-level middleware execution.

## [1.0.0+26] - 2025-12-20

### Fixed
- Fixed hot reload behavior on Linux.

## [1.0.0+25] - 2025-12-20

### Notes
- Maintenance release.

## [1.0.0+24] - 2025-12-20

### Added
- Live hot reload for `.flint.html` templates without restarting the server.
- WebSocket-based reload listener for development mode.
- Automatic WebSocket reconnection for hot reload when the connection drops.

### Improved
- Developer experience when editing view templates.
- Faster iteration on UI changes with instant browser refresh.

### Fixed
- Hot reload disconnect issues when the server restarts.

## [1.0.0+23] - 2025-12-17
### Added
- **WebSocketManager helpers**: `emitToRoom`, `emitToClient`, `emitToAll` for room-scoped and global event emission.
- **Global room system** using `Set<FlintWebSocket>` to prevent duplicate clients in rooms.
- **IsolateTask** class for running heavy or long-running tasks in isolates with optional completion and error callbacks.
- **ViewMailable** class to send and queue emails from `.flint.html` templates, replacing the old `FlintUI` mail system.
- Support for **task progress broadcasting** over WebSockets in background tasks.
- OOP-based **RouteGroup system**, enabling modular and nested route registration with middleware inheritance.

### Changed
- Refactored `AppRoutes` and other route groups to OOP style, replacing procedural callbacks.
- `FlintWebSocket` now fully cleans up event listeners and rooms on disconnect.
- Improved middleware inheritance across nested route groups.
- `Flint` framework now supports emitting events safely from background isolates.

### Fixed
- Prevented potential memory leaks on WebSocket disconnect.
- Minor JSON decoding fixes in `FlintWebSocket._handleIncomingMessage`.
- Fixed edge cases in queued mail sending.

### Notes
- Internal build increment only (`+23`) — no breaking changes.
- All APIs are backward-compatible; some procedural route registration can be migrated to `RouteGroup` classes.

All notable changes to Flint Dart will be documented in this file.
## [1.0.0+22]

---

## [1.0.0+21] — 2025-12-02
### 🆕 New Features
* **Full QueryBuilder Dartdoc:** Added complete documentation for all QueryBuilder methods.
* **Enhanced LIKE Helpers:** `whereContains`, `whereStartsWith`, `whereEndsWith`, and their OR counterparts now fully documented.
* **Date and Range Filtering:** `whereDate`, `whereBetween`, `whereNotBetween` fully documented with examples.
* **Aggregate Functions:** `count`, `max`, `min`, `avg`, `sum` updated with usage examples.

---

## [1.0.0+20] — 2025-11-28
### 🆕 New Features
* **UUID Primary Key Support:** Automatically generates UUIDs for string-based primary keys when no value is provided.
* **Database-Aware Inserts:** Insert logic now checks column types and auto-increment settings for both MySQL and PostgreSQL.
* **Column Info Caching:** Reduces repeated queries to `information_schema` by caching column metadata per table.
* **Seamless Auto-Increment Handling:** Integer primary keys without values are left to DB auto-increment; no manual intervention needed.
* **PostgreSQL & MySQL Compatible:** Insert logic and ID handling work consistently across both supported databases.

---

## [1.0.0+19] — 2025-11-25
### 🆕 New Features
* **QueryBuilder `orWhereLike` and `orWhereNotLike`:** Adds OR-based LIKE conditions for more flexible queries.
* **Eager-Loaded Relations Support:** `withRelations()` method added for automatic relation fetching.
* **Pagination Improvements:** `paginate()` method now restores original limits/offsets after fetching.

---

## [1.0.0+18] — 2025-11-22
### 🆕 New Features
* **Helper Methods for LIKE:** Added `whereContains`, `whereStartsWith`, `whereEndsWith` helpers for clean queries.
* **OR Helper Methods:** `orWhereContains`, `orWhereStartsWith`, `orWhereEndsWith` for OR-based matching.
* **Case Sensitivity Toggle:** All LIKE helpers support `caseSensitive` parameter.
* **Escape Special Characters:** LIKE patterns automatically escape `%` and `_` with `_escapeLike()` helper.

* **Aggregate Functions:** Added `count`, `max`, `min`, `avg`, and `sum` for QueryBuilder.
* **Group & Order:** `groupBy()` and `orderBy()` methods enhanced to support multiple fields.
* **LIMIT & OFFSET:** Fluent interface for pagination and query control.
# 🚀 Flint Dart — Version 1.0.0+17
### 🆕 New Features

* **UUID Primary Key Support:** Automatically generates UUIDs for string-based primary keys when no value is provided.
* **Database-Aware Inserts:** Insert logic now checks column types and auto-increment settings for both MySQL and PostgreSQL.
* **Column Info Caching:** Reduces repeated queries to `information_schema` by caching column metadata per table.
* **Seamless Auto-Increment Handling:** Integer primary keys without values are left to DB auto-increment; no manual intervention needed.
* **PostgreSQL & MySQL Compatible:** Insert logic and ID handling work consistently across both supported databases.

### 🛠 Improvements

* Enhanced debug logging for column info and UUID generation.
* Optimized fallback for missing column info.
* Refactored `_loadIdColumnInfo` for reliable type detection across DB drivers.
* Improved safety when inserting rows without IDs.

### ✅ Fixes

* Resolved issues with inserting into tables with integer primary keys without breaking auto-increment.
* Fixed type conversion issues in MySQL when fetching column data.

---

# 🚀 **Flint Dart — Version 1.0.0+16**
### ✨ New Features

* **Automatic Model Response Handling**
  Flint Dart can now automatically respond with a `Model`, a `List<Model>`, or even a `Future<Model>` / `Future<List<Model>>` — no manual conversion required.

* **`.toMap()` / `.toJson()` Object Support**
  Any object implementing a `.toMap()` or `.toJson()` method will automatically be serialized into JSON when passed to `res.respond()` or `res.json()`.

* **`.asMaps()` Added for `List<Model>`**
  You can now easily convert a list of models into a list of maps for flexible use in responses or logic.

  ```dart
  var allUsers = await User().all();
  var users = allUsers.asMaps(); // ✅ Converts to List<Map<String, dynamic>>
  return res.json(users);
  ```

### ⚙️ Improvements

* Enhanced **JSON serialization** to handle:

  * `Future<Model>` and `Future<List<Model>>`
  * Nested `Future`s within lists or maps
  * Custom classes exposing `toMap()` or `toJson()`
* Fully **async-safe** response system:
  `respond()` automatically awaits pending data before sending the response.
* Smarter **RespondType inference** — now correctly detects:

  * Flint widgets (`RespondType.flint`)
  * JSON data (maps, lists, models, or futures)
  * HTML strings (`<html>` / `<!DOCTYPE html>`)
  * Plain text fallbacks

### 🧠 Example Usage

```dart
// Single Model
return res.respond(user);

// List of Models
return res.respond(users);

// Future<List<Model>>
return res.respond(User().all());

// Object with toMap() or toJson()
return res.respond(customObject);

// Manual list-to-map conversion
var allUsers = await User().all();
return res.json(allUsers.asMaps());
```

### 🧩 Summary

This update makes Flint Dart’s response system:

* **Smarter** — understands models, lists, and async responses automatically
* **Safer** — cleans and serializes all nested data properly
* **Simpler** — no need for manual `.toMap()` calls in most cases


# 🚀 Flint Dart — Version 1.0.0+15
# 🚀 Flint Dart — Version 1.0.0+14
# 🚀 Flint Dart — Version 1.0.0+13
# 🚀 Flint Dart — Version 1.0.0+12
# 🚀 Flint Dart — Version 1.0.0+11

## 🧩 Updates & Improvements
- 🛠️ **Bug Fixes:** Resolved several minor issues across the framework for improved stability.
- ⚙️ **Patch Enhancements:** Applied multiple patches to improve reliability and developer experience.
- 🧰 **CLI Upgrade:** The CLI has been **updated and upgraded** with new commands and performance improvements.
- 🔄 **Update System Added:** Introduced support for automatic update checks and smoother upgrade handling.

Flint Dart continues to evolve toward a more seamless, developer-friendly backend framework for Dart.

# 🚀 Flint Dart — Version 1.0.0+10

Flint Dart continues to evolve into a complete **backend + UI ecosystem for Dart**, combining powerful server-side tools with a new rendering engine — **Flint UI**.


## 🎨 Flint UI — Cross-Platform Rendering System

Flint UI introduces a **Flutter-like declarative UI engine** for generating **HTML, email layouts, and console output** directly from Dart — no React or HTML strings required.

### ✨ Core Concept

Flint UI widgets are **class-based**, **composable**, and **type-safe**, similar to Flutter widgets — but designed for rendering to multiple formats (HTML, text, JSON).

```dart
final button = FlintButton(
  text: "Click Me",
  onClick: () => Log.debug("Button clicked!"),
  style: ButtonStyle(color: "#0066FF"),
);
````

This can render to:

```html
<button style="background-color:#0066FF;">Click Me</button>
```

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

Log.debug(email.toHtml());
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
    Log.debug('💬 ${socket.id} says: $data');
    socket.broadcastToRoom('chat', {'event': 'message', 'data': data});
  });
});
````

Client-side:

```dart
final ws = FlintWebSocketClient("wss://api.example.com/chat");
ws.on('message', (data) => Log.debug("📩 $data"));
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
