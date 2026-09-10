# Database API

Flint's Database API exposes selected models through a bounded JSON protocol.
Use it when an app needs a safe fullstack data endpoint that can be queried by a
Flint client, browser UI, mobile app, or another trusted consumer.

This is not a replacement for normal model code. Backend features should still
use `Model<T>`, `QueryBuilder`, controllers, actions, and route groups when the
workflow has business rules. The Database API is best for resources that can be
described as controlled CRUD over model fields.

## Framework Source References

When behavior is unclear, inspect these files in the installed package:

- `lib/db_api.dart`
- `lib/db.dart`
- `lib/src/database/api/flint_database_api.dart`
- `lib/src/database/api/config/flint_database_api_config.dart`
- `lib/src/database/api/exposure/flint_db_resource.dart`
- `lib/src/database/api/exposure/flint_db_resource_registry.dart`
- `lib/src/database/api/policy/flint_db_policy.dart`
- `lib/src/database/api/execution/flint_db_query_compiler.dart`
- `lib/src/database/api/errors/flint_db_api_exception.dart`

The query/result protocol is exported from `flint_client` and re-exported by
`package:flint_dart/db.dart` and `package:flint_dart/db_api.dart`.

## Imports

Server-side DB API setup can use the focused entrypoint:

```dart
import 'package:flint_dart/db_api.dart';
import 'package:flint_dart/flint_dart.dart';
```

Normal app files can also use:

```dart
import 'package:flint_dart/flint_dart.dart';
```

Client code can use:

```dart
import 'package:flint_client/flint_client.dart';
```

In a Flint Dart app, `package:flint_dart/flint_dart.dart` also re-exports the
client protocol classes.

## The Mental Model

The Database API has four layers:

- `FlintDatabaseApi`: registers the HTTP routes and owns the config.
- `FlintDbResourceRegistry`: stores the exposed resources by name.
- `FlintDbResource`: describes one model resource, its operations, readable
  fields, writable fields, hidden fields, and policies.
- `FlintDbQueryCompiler`: validates protocol queries and turns them into
  parameterized `QueryBuilder` calls.

A model is not public just because it exists. The app must register a resource.
A field is not public just because it exists on the table. The resource decides
what can be read, written, filtered, and ordered.

## Register The API

Create a database API object and register it on the app:

```dart
import 'package:flint_dart/flint_dart.dart';

import 'models/course.dart';

void main() {
  final app = Flint();

  app.databaseApi(
    FlintDatabaseApi(
      config: FlintDatabaseApiConfig(
        auth: const FlintDbAuth.enabled(defaultRole: 'user'),
      ),
      resources: [
        Course.new.resource,
      ],
    ),
  );

  app.listen(port: 3000);
}
```

The default base path is:

```text
/db/v1
```

So the example registers routes such as:

```text
GET    /db/v1/health
GET    /db/v1/schema
GET    /db/v1/courses
POST   /db/v1/courses/query
POST   /db/v1/courses
PATCH  /db/v1/courses/:id
DELETE /db/v1/courses/:id
```

If `auth: const FlintDbAuth.enabled(...)` is set, the API also registers:

```text
POST /db/v1/auth/register
POST /db/v1/auth/login
GET  /db/v1/auth/me
```

## Default Authorization

The Database API is deny-first.

With the default config, `auth` is disabled and no custom `authorizer` is set,
so protected DB API routes deny access. `GET /health` is the only open health
check.

Use one of these shapes:

```dart
FlintDatabaseApiConfig(
  auth: const FlintDbAuth.enabled(defaultRole: 'user'),
)
```

or:

```dart
FlintDatabaseApiConfig(
  authorizer: (Context ctx) async {
    final user = await ctx.req.user;
    return user != null && user['role'] == 'admin';
  },
)
```

When auth is enabled and no custom authorizer is supplied, Flint checks
`ctx.req.authToken`. That reads `Authorization: Bearer <token>` first and can
also read the configured auth cookie. The token is verified with `Auth.verifyToken`.

Use app-specific middleware and normal route groups when the authorization rule
is more than "this identity may access this resource".

## Owned CRUD Resources

The easiest resource shape is `ownedCrud`:

```dart
resources: [
  Course.new.resource,
]
```

This extension calls:

```dart
FlintDbResource.ownedCrud(Course.new)
```

Owned CRUD expects the model table to have an owner column named `user_id` by
default. On insert, the API injects that owner value from the authenticated JWT
identity. The client cannot write the owner field.

Example model:

```dart
import 'package:flint_dart/flint_dart.dart';

class Course extends Model<Course> {
  Course() : super(Course.new);

  String? get title => getAttribute('title');
  String? get status => getAttribute('status');
  String? get userId => getAttribute('user_id');

  @override
  Table get table => Table(
        name: 'courses',
        columns: [
          Column(name: 'title', type: ColumnType.string),
          Column(name: 'status', type: ColumnType.string),
          Column(name: 'user_id', type: ColumnType.string),
        ],
      );
}
```

`ownedCrud` grants:

```dart
{
  FlintDbOperation.select,
  FlintDbOperation.insert,
  FlintDbOperation.update,
  FlintDbOperation.delete,
}
```

It also protects:

- the primary key
- the owner field
- model concealed fields
- fields passed in `hiddenFields`

Those protected fields are not writable. Concealed, hidden, and policy-owned
fields are not returned in responses.

If the owner column has a different name:

```dart
FlintDbResource.ownedCrud(
  Course.new,
  ownerField: 'account_id',
)
```

If the resource name should be different from the table name:

```dart
FlintDbResource.ownedCrud(
  Course.new,
  name: 'learning_courses',
)
```

## Custom Resources

Use `FlintDbResource.fromModel(...)` when you need exact control:

```dart
final publicCourses = FlintDbResource.fromModel(
  Course.new,
  name: 'public_courses',
  operations: const {FlintDbOperation.select},
  hiddenFields: const {'internal_notes'},
  writableFields: const {},
  readFilter: (Context ctx) {
    return const FlintDbComparison(
      'status',
      FlintDbOperator.eq,
      'published',
    );
  },
);
```

Important: `fromModel(...)` defaults to no allowed operations. If you do not
pass `operations`, the resource denies reads and writes.

Writable fields must be table columns. Hidden fields must be table columns. Unsafe
resource names and field names are rejected; use normal database identifiers such
as `courses`, `course_lessons`, `title`, and `created_at`.

## Operations

The operation enum is:

```dart
enum FlintDbOperation {
  select,
  insert,
  update,
  delete,
  bulk,
  rpc,
}
```

Current route behavior uses `select`, `insert`, `update`, and `delete`.

`bulk` and `rpc` are protocol names for future or custom use. Do not document a
resource as supporting bulk or RPC behavior unless the app has added that
behavior itself.

Convenience helpers:

```dart
Course.new.resource.readOnly();
Course.new.resource.createOnly();
Course.new.resource.adminOnly();
```

`readOnly()` allows only `select`.

`createOnly()` allows `select` and `insert`.

`adminOnly()` adds a role policy that allows only identities whose JWT payload
has `role: "admin"` by default.

## Policies

Policies restrict access after the request is authenticated.

Owner policy:

```dart
const FlintDbOwnerPolicy(
  field: 'user_id',
  identityField: 'id',
)
```

This limits reads, updates, and deletes to rows where `user_id` matches the
authenticated identity's `id`. Inserts receive `user_id` from the identity.

Parent policy:

```dart
const FlintDbParentPolicy(
  field: 'course_id',
  parentResource: 'courses',
)
```

This protects child records. When a child is created or updated, the referenced
parent row must be visible to the same identity.

Role policy:

```dart
const FlintDbRolePolicy.allow({'admin', 'manager'});
```

This allows the resource only when the authenticated identity contains one of
the required roles. By default it reads `identity['role']`.

You can add policies to a resource:

```dart
final adminReports = FlintDbResource.fromModel(
  Report.new,
  operations: const {FlintDbOperation.select},
).policy(
  const FlintDbRolePolicy.allow({'admin'}),
);
```

## Read Filters

Use `readFilter` when every read should include a server-side condition.

```dart
final publishedCourses = FlintDbResource.fromModel(
  Course.new,
  operations: const {FlintDbOperation.select},
  readFilter: (Context ctx) {
    return const FlintDbComparison(
      'status',
      FlintDbOperator.eq,
      'published',
    );
  },
);
```

The API combines the client filter with the server-enforced filter using `and`.
The client cannot remove the server filter.

Use read filters for cases such as:

- only published records
- tenant-scoped records
- records visible to a role
- rows that are not archived

Use controllers/actions instead when the read rule needs several model queries
or business decisions.

## Resource Schema

`GET /db/v1/schema` returns the registered resources and their exposed fields.

Each resource schema includes:

- `name`
- `operations`
- `fields`

Each field includes:

- `name`
- `type`
- `nullable`
- `primary`
- `writable`

Hidden, concealed, and policy-owned fields are not listed as readable fields.
This helps client code discover what it can safely show and write.

Example shape:

```json
{
  "data": [
    {
      "name": "courses",
      "operations": ["delete", "insert", "select", "update"],
      "fields": [
        {
          "name": "id",
          "type": "string",
          "nullable": false,
          "primary": true,
          "writable": false
        },
        {
          "name": "title",
          "type": "string",
          "nullable": false,
          "primary": false,
          "writable": true
        }
      ]
    }
  ],
  "meta": {
    "requestId": "req_...",
    "count": 1,
    "nextCursor": null
  },
  "error": null
}
```

## List And Find Routes

List records:

```text
GET /db/v1/courses
```

Find one record:

```text
GET /db/v1/courses/:id
```

URL list queries support:

```text
GET /db/v1/courses?select=id,title,status&order=created_at.desc&limit=20&offset=0
```

Use URL list queries for simple reads. Use the query endpoint for filters or
multiple order clauses.

## Query Endpoint

For advanced reads, send a `FlintDbQuery` body:

```text
POST /db/v1/courses/query
```

or:

```text
QUERY /db/v1/courses
```

Example JSON body:

```json
{
  "select": ["id", "title", "status"],
  "filter": {
    "and": [
      {
        "field": "status",
        "operator": "eq",
        "value": "published"
      },
      {
        "field": "title",
        "operator": "contains",
        "value": "Dart"
      }
    ]
  },
  "order": [
    {
      "field": "created_at",
      "direction": "desc"
    }
  ],
  "limit": 20,
  "offset": 0
}
```

Dart equivalent:

```dart
final query = FlintDbQuery(
  select: const ['id', 'title', 'status'],
  filter: FlintDbLogicalFilter(
    FlintDbLogicalOperator.and,
    const [
      FlintDbComparison('status', FlintDbOperator.eq, 'published'),
      FlintDbComparison('title', FlintDbOperator.contains, 'Dart'),
    ],
  ),
  order: const [
    FlintDbOrder('created_at', descending: true),
  ],
  limit: 20,
  offset: 0,
);
```

## Query Rules

Queries are validated before SQL is built.

Supported comparison operators:

- `eq`
- `neq`
- `gt`
- `gte`
- `lt`
- `lte`
- `in`
- `notIn`
- `isNull`
- `isNotNull`
- `contains`
- `startsWith`
- `endsWith`

Notes:

- `in` and `notIn` require a list value.
- `isNull` and `isNotNull` do not include a value in JSON.
- Selected fields must be readable.
- Ordered fields must be readable.
- Filtered fields must be readable or policy-owned.
- `limit` must be between `1` and `maxPageSize`.
- `offset` cannot be negative.
- At most five order clauses are accepted.
- Cursor pagination is parsed by the protocol but rejected by this release.
- `and` filters are supported.
- `or` and `not` parse at the protocol layer but are rejected by the current
  query compiler.

Default limits come from `FlintDatabaseApiConfig`:

```dart
FlintDatabaseApiConfig(
  maxPageSize: 100,
  maxSelectedFields: 50,
  maxFilterComparisons: 25,
  maxLogicalDepth: 5,
)
```

These limits are part of the security model. Raise them only for a clear app
need.

## Insert

Create a record:

```text
POST /db/v1/courses
```

Body:

```json
{
  "title": "Intro To Flint",
  "status": "draft"
}
```

The API accepts only writable fields. If the body contains a field that is not in
`writableFields`, the request fails with `validation_failed`.

For owned CRUD resources, the owner field is injected by the server:

```text
client sends:  title, status
server adds:   user_id from identity.id
```

The client should not send `id`, `user_id`, concealed fields, hidden fields, or
policy-owned fields.

## Update

Update a record:

```text
PATCH /db/v1/courses/:id
```

Body:

```json
{
  "title": "Intro To Flint Dart"
}
```

The API first checks that the owned row exists, then validates writable fields,
then updates the row. Empty update bodies are rejected.

Use custom controllers instead of the Database API when update behavior needs
workflow rules such as publishing checks, payment state changes, audit logs, or
cross-table side effects.

## Delete

Delete a record:

```text
DELETE /db/v1/courses/:id
```

For owned resources, the delete is scoped to the authenticated owner. If the row
is not visible to that owner, the response is `record_not_found`.

Use soft-delete columns and custom controller logic if the app needs restore,
trash, or audit behavior.

## Response Envelope

Successful responses use `FlintDbResult.success`:

```json
{
  "data": [],
  "meta": {
    "requestId": "req_...",
    "count": 0,
    "nextCursor": null
  },
  "error": null
}
```

Failed responses use `FlintDbResult.failure`:

```json
{
  "data": null,
  "meta": {
    "requestId": "req_...",
    "nextCursor": null
  },
  "error": {
    "code": "permission_denied",
    "message": "The operation is not allowed.",
    "details": null
  }
}
```

If the request includes `x-request-id`, Flint returns that value in `meta.requestId`.
Otherwise it creates a request id.

## Error Codes

The protocol error codes are:

- `invalid_request`
- `authentication_required`
- `invalid_token`
- `permission_denied`
- `resource_not_found`
- `record_not_found`
- `conflict`
- `validation_failed`
- `query_limit_exceeded`
- `rate_limited`
- `transaction_failed`
- `internal_error`

The API maps common failures to HTTP status codes:

- `401` for missing/invalid authentication.
- `403` for denied operations or unavailable fields.
- `404` for missing resources or records.
- `409` for auth registration conflicts.
- `422` for validation failures.
- `500` for unexpected database failures.

## Server-Side Select

You can use the API object directly from server code:

```dart
final api = FlintDatabaseApi(
  resources: [
    Course.new.resource.readOnly(),
  ],
);

final rows = await api.select(
  'courses',
  const FlintDbQuery(
    select: ['id', 'title'],
    limit: 10,
  ),
);
```

Use `enforcedFilter` when server code must add a condition the caller cannot
remove:

```dart
final rows = await api.select(
  'courses',
  FlintDbQuery(
    filter: FlintDbComparison('status', FlintDbOperator.eq, 'published'),
  ),
  enforcedFilter: FlintDbComparison('tenant_id', FlintDbOperator.eq, tenantId),
);
```

For normal backend workflows, prefer models or actions. Direct `api.select(...)`
is useful when code wants the same concealment, filters, and field rules as the
external Database API.

## Client Usage

Create a normal Flint client, then wrap it with `FlintDatabaseClient`:

```dart
final http = FlintClient(
  baseUrl: 'http://localhost:3000',
);

final db = FlintDatabaseClient(client: http);
```

Login through the DB API auth helper when the server enabled DB API auth:

```dart
final session = await db.auth.login(
  email: 'ada@example.com',
  password: 'secret123',
);
```

Then create an authenticated client:

```dart
final authedHttp = http.copyWith(
  headers: {
    ...http.headers,
    'Authorization': 'Bearer ${session.token}',
  },
);

final authedDb = FlintDatabaseClient(client: authedHttp);
```

Select rows:

```dart
final courses = await authedDb.from('courses').select(
  fields: const ['id', 'title', 'status'],
  filter: const FlintDbComparison(
    'status',
    FlintDbOperator.eq,
    'published',
  ),
  order: const [
    FlintDbOrder('created_at', descending: true),
  ],
  limit: 20,
);
```

Insert:

```dart
final course = await authedDb.from('courses').insert({
  'title': 'Intro To Flint',
  'status': 'draft',
});
```

Update:

```dart
final updated = await authedDb.from('courses').update(course['id'], {
  'title': 'Intro To Flint Dart',
});
```

Delete:

```dart
await authedDb.from('courses').delete(course['id']);
```

If the server returns a protocol error, the client throws
`FlintDbClientException` with the structured `FlintDbError`.

## Flint UI Usage

Do not import server-side `Model` classes into browser UI files. Browser UI
should use DTO classes, maps, `FlintModelRecord`, or another client-safe data
shape.

A simple UI data wrapper can live in its own file:

File: `lib/ui/data/course_api.dart`

```dart
import 'package:flint_client/flint_client.dart';

class CourseApi {
  CourseApi(this.db);

  final FlintDatabaseClient db;

  Future<List<Map<String, dynamic>>> published() {
    return db.from('courses').select(
      fields: const ['id', 'title', 'status'],
      filter: const FlintDbComparison(
        'status',
        FlintDbOperator.eq,
        'published',
      ),
      order: const [FlintDbOrder('created_at', descending: true)],
      limit: 20,
    );
  }
}
```

Then a component can load data through `ResourceController`:

```dart
import 'package:flint_dart/ui.dart';

import '../data/course_api.dart';

class CourseListResource {
  CourseListResource(CourseApi api)
      : controller = ResourceController<List<Map<String, dynamic>>>(
          loader: api.published,
          loadImmediately: true,
        );

  final ResourceController<List<Map<String, dynamic>>> controller;
}
```

Keep API clients, state holders, components, and pages in separate files under
`lib/ui`.

## Security Checklist

Before exposing a model through the Database API:

1. Confirm the model should be reachable through generic CRUD.
2. Confirm auth or a custom authorizer is configured.
3. Confirm the resource has only the needed operations.
4. Confirm concealed fields and `hiddenFields` cover secrets and internal data.
5. Confirm `writableFields` excludes primary keys, owners, roles, totals, and
   server-computed values.
6. Confirm owner, parent, role, or read filters enforce tenant/user boundaries.
7. Confirm query limits are low enough for the app.
8. Confirm custom workflows still use controllers/actions.
9. Confirm frontend code does not import server models.
10. Confirm tests cover at least one allowed request and one denied request.

## File Organization

Keep Database API setup readable and separate:

```text
lib/config/database_api.dart
lib/config/table_registry.dart
lib/models/course.dart
lib/models/lesson.dart
lib/policies/course_resource_policy.dart
```

Example:

```dart
import 'package:flint_dart/flint_dart.dart';

import '../models/course.dart';
import '../models/lesson.dart';

FlintDatabaseApi createDatabaseApi() {
  return FlintDatabaseApi(
    config: FlintDatabaseApiConfig(
      auth: const FlintDbAuth.enabled(defaultRole: 'user'),
      maxPageSize: 50,
    ),
    resources: [
      Course.new.resource,
      Lesson.new.resource.readOnly(),
    ],
  );
}
```

In `lib/main.dart`:

```dart
import 'config/database_api.dart';

void main() {
  final app = Flint();

  app.databaseApi(createDatabaseApi());

  app.listen(port: 3000);
}
```

Do not put several policy classes, DTOs, or large API helpers into the same file.
Follow the Flint class-per-file pattern.

## Common Mistakes

- Registering `FlintDatabaseApi()` with no `auth` and no `authorizer`, then
  expecting protected routes to be public.
- Exposing a model with `ownedCrud` before adding the owner column.
- Forgetting that `fromModel(...)` allows no operations by default.
- Making sensitive fields readable by omitting `conceal` or `hiddenFields`.
- Making server-controlled fields writable.
- Expecting URL list queries to support complex filters.
- Using `or`, `not`, or `cursor` queries in this release.
- Assuming `bulk` and `rpc` routes exist because the enum contains those names.
- Importing backend `Model` classes into `lib/ui`.
- Using the Database API for business workflows that should be controller
  actions.

## Review Checklist

When reviewing Database API work, check:

1. The app registers the API with `app.databaseApi(...)`.
2. The config is deny-first and intentionally authorized.
3. Each resource is explicitly registered.
4. Each resource grants only needed operations.
5. Readable and writable fields match the public contract.
6. Owner, parent, role, and read filters match the app's security model.
7. Client examples send a bearer token or rely on the app's configured cookie
   flow.
8. Generated Swagger docs are not treated as the source of DB API behavior.
9. Tests cover the allowed and denied paths.
