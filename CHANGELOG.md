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
