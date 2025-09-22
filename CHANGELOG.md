## 1.0.0+5

### Middleware
- Added `.withMiddleware()` API for attaching middleware directly to routes, making route-level middleware usage cleaner and more expressive.  
  Example:  
  ```dart
  app.get('/profile', controller.show).withMiddleware(AuthMiddleware());
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
Updated middleware documentation with new .withMiddleware usage examples.

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
