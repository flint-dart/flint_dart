# Seeders

Seeders create or update known database records. Use them for required roles,
default settings, demo users, lookup tables, development fixtures, and test
data that should be reproducible.

In Flint, a seeder is a Dart class that extends `Seeder`. A seeder registry is
the app-level object that lists which seeders run and in what order.

## The Mental Model

There are four pieces:

- `Seeder`: the base class for one unit of seed logic.
- `SeederRegistry`: the app object that owns the ordered seeder list.
- `SeederRunner`: the runtime that executes seeders one by one.
- `flint seed`: the CLI command that runs `lib/config/seeder_registry.dart`.

The shape is intentionally object-oriented. Do not treat seeders as framework
magic or as copied migration syntax from another ecosystem. A seeder is just a
class with a `run()` method, and the registry is just a class that returns
seeder instances.

## Seeders Are Not Migrations

Migrations define database structure. Seeders write data into that structure.

Use migrations for tables, columns, indexes, constraints, and schema changes.
Use seeders for records: roles, permissions, settings, demo accounts, sample
courses, lookup values, and other rows the app needs.

In Flint, startup migrations run before startup seeders when both are enabled.
If you run commands manually, run `migrate` before `seed` when seeders need new
tables or columns.

## Files

Use this layout:

```text
lib/
  seeders/
    role_seeder.dart
    admin_user_seeder.dart
    course_seeder.dart
  config/
    seeder_registry.dart
```

Keep one seeder class per file. Do not place several seeders in one large
`seeders.dart` file. If seed logic needs a reusable helper, extract that helper
to its own file instead of hiding behavior in a private method.

## Creating A Seeder

Use the CLI generator:

```bash
dart run flint_dart:flint --make-seeder RoleSeeder
```

If the name does not end with `Seeder`, Flint appends it:

```bash
dart run flint_dart:flint --make-seeder Role
```

`Role` creates:

```text
lib/seeders/role_seeder.dart
```

Generated shape:

```dart
import 'package:flint_dart/flint_dart.dart';

class RoleSeeder extends Seeder {
  @override
  Future<void> run() async {
    Log.debug('RoleSeeder ran successfully.');
  }
}
```

Replace the placeholder with the actual seed work.

## Writing A Seeder

A seeder should be safe to run more than once unless it is intentionally creating
fresh demo rows each time.

Prefer `upsert(...)`, `upsertMany(...)`, or `firstOrCreate(...)` for stable
records:

```dart
import 'package:flint_dart/flint_dart.dart';

import '../models/role.dart';

class RoleSeeder extends Seeder {
  @override
  Future<void> run() async {
    await Role().upsertMany(
      uniqueBy: ['slug'],
      records: [
        {'slug': 'admin', 'name': 'Administrator'},
        {'slug': 'teacher', 'name': 'Teacher'},
        {'slug': 'student', 'name': 'Student'},
      ],
    );
  }
}
```

Use `create(...)` only when duplicates are acceptable:

```dart
await Course().create({
  'title': 'Demo course ${DateTime.now().millisecondsSinceEpoch}',
});
```

Most production seeders should not do that. Re-running a deployment seed should
not keep creating duplicate admins, duplicate roles, or duplicate settings.

## Seeder Names

`Seeder.name` defaults to the runtime type. Flint uses it in logs:

```text
Running seeder: RoleSeeder
Seeder completed: RoleSeeder
```

Override `name` only when a different log label is useful:

```dart
class RequiredRoleSeeder extends Seeder {
  @override
  String get name => 'required roles';

  @override
  Future<void> run() async {
    // ...
  }
}
```

## Seeder Registry

The modern registry extends `SeederRegistry`:

```dart
import 'package:flint_dart/flint_dart.dart';

import '../seeders/admin_user_seeder.dart';
import '../seeders/role_seeder.dart';

class AppSeederRegistry extends SeederRegistry {
  const AppSeederRegistry();

  @override
  Iterable<Seeder> get seeders => [
        RoleSeeder(),
        AdminUserSeeder(),
      ];
}

Future<void> main() => const AppSeederRegistry().registerAll();
```

The registry file belongs at:

```text
lib/config/seeder_registry.dart
```

The `seeders` list order is the execution order. Put dependency records first.
For example, seed roles before users if users reference roles. Seed users before
posts if posts reference users.

## What RegisterAll Does

`SeederRegistry.registerAll()` calls `registerSeeders(...)`, which calls
`SeederRunner.run(...)`.

This means:

- seeders run sequentially, not in parallel
- each seeder is awaited before the next seeder starts
- if a seeder throws, later seeders do not run
- the error bubbles to the caller
- when `closeConnection` is `true`, `SeederRunner` closes the DB connection in a
  `finally` block if the DB is connected

`registerAll()` defaults to `closeConnection: true`:

```dart
Future<void> main() => const AppSeederRegistry().registerAll();
```

For a standalone CLI seeding process, closing the connection at the end is the
right default.

## Running Seeders From The CLI

Run seeders with:

```bash
dart run flint_dart:flint seed
```

Behavior:

- Flint looks for `lib/config/seeder_registry.dart`.
- If that file does not exist, Flint checks the legacy
  `lib/seeders/seeder.dart`.
- The selected file runs through `dart run`.
- The registry `main()` function is the entrypoint.
- If the seeder process exits with a non-zero code, the CLI exits with code `1`.

`--make-seeder` creates `lib/config/seeder_registry.dart` when it is missing and
adds the new seeder import and instance to the registry.

## Low-Level Helpers

The registry is the main pattern, but Flint also exposes helper functions:

```dart
await runSeeders([
  RoleSeeder(),
  AdminUserSeeder(),
]);

await registerSeeders([
  RoleSeeder(),
  AdminUserSeeder(),
]);
```

These call `SeederRunner.run(...)` directly. They are useful for small scripts,
tests, and older registry files. New application code should prefer
`SeederRegistry` because it gives the app one clear seed registry object.

## Database Connection

Seeders use normal model and `DB` APIs, so they need a database connection.

In most standalone registry files, this works without manual connection code
because `DB` can lazy-connect on first use:

```dart
Future<void> main() => const AppSeederRegistry().registerAll();
```

If your process disables lazy auto-connect, call `DB.autoConnect()` before
running the registry:

```dart
Future<void> main() async {
  await DB.autoConnect();
  await const AppSeederRegistry().registerAll();
}
```

If you pass `closeConnection: false`, Flint keeps the connection open:

```dart
await const AppSeederRegistry().registerAll(closeConnection: false);
```

Use that only when the same process needs the connection after seeding.

## App.seed

A `Flint` app can run its configured registry:

```dart
import 'package:flint_dart/flint_dart.dart';

import 'config/seeder_registry.dart';

Future<void> main() async {
  final app = Flint(
    seederRegistry: const AppSeederRegistry(),
  );

  await app.seed(closeConnection: false);
  await app.listen(port: 3000);
}
```

`app.seed(...)` requires `seederRegistry`. If the app does not have one, Flint
throws a `StateError`.

Use `app.seed(...)` when you want to seed from an app bootstrap or test setup.
For normal developer usage, prefer the CLI command:

```bash
dart run flint_dart:flint seed
```

## Auto Seed On Startup

Flint can run seeders automatically during startup:

```dart
final app = Flint(
  seederRegistry: const AppSeederRegistry(),
  autoSeed: true,
  closeSeederConnection: false,
);
```

Startup order:

1. `listen(...)` starts the worker process.
2. Flint runs startup migrations when migration options enable them.
3. Flint runs seeders when `autoSeed` is `true`.
4. Flint registers configured job schedules.
5. Flint binds the HTTP server.

`autoSeed` is `false` by default because seeders create or mutate application
data. Enable it only when the seeders are idempotent and safe for the target
environment.

`closeSeederConnection` controls the `closeConnection` value used by startup
seeding. Its default is `false`, which keeps the database connection available
for the server after seeders run.

If `autoSeed: true` is set without `seederRegistry`, startup seeding cannot run.
Configure the registry or disable `autoSeed`.

## Auto Migrate And Seed Together

If seeders depend on tables that may not exist yet, run migrations first.

For local development:

```bash
dart run flint_dart:flint migrate --create-db
dart run flint_dart:flint seed
```

For startup automation:

```dart
final app = Flint(
  tableRegistry: const AppTableRegistry(),
  seederRegistry: const AppSeederRegistry(),
  autoMigrate: true,
  autoMigrateCreateDatabase: true,
  autoSeed: true,
  closeSeederConnection: false,
);
```

Do this only when the seeders are repeatable. Use environment checks before
seeding large demo data in production.

## Environment-Aware Seeders

Some seeders should only run in development. Keep the rule inside the seeder so
the registry stays simple:

```dart
class DemoCourseSeeder extends Seeder {
  @override
  Future<void> run() async {
    final env = FlintEnv.get('APP_ENV', 'development');
    if (env == 'production') return;

    await Course().upsert(
      where: {'slug': 'intro-to-flint'},
      data: {
        'slug': 'intro-to-flint',
        'title': 'Intro to Flint',
      },
    );
  }
}
```

For required production data, make the seed idempotent instead of skipping it.
Roles, permissions, feature flags, and core settings are often safe to upsert in
every environment.

## Seeding Related Data

When records depend on each other, seed in order and query the parent before
creating children:

```dart
class CourseSeeder extends Seeder {
  @override
  Future<void> run() async {
    final teacher = await User().upsert(
      where: {'email': 'teacher@example.com'},
      data: {
        'email': 'teacher@example.com',
        'name': 'Demo Teacher',
      },
    );

    await Course().upsert(
      where: {'slug': 'dart-backend-basics'},
      data: {
        'slug': 'dart-backend-basics',
        'title': 'Dart Backend Basics',
        'teacherId': teacher?.id,
      },
    );
  }
}
```

If a child record needs a parent ID, make sure the parent seeder runs first or
create both records in the same seeder.

## Raw SQL In Seeders

Prefer models for most seed work. Use raw SQL only when the model API is not the
right shape for the operation.

When using raw SQL, parameterize values:

```dart
await DB.query(
  'SELECT * FROM users WHERE email = :email',
  namedParams: {'email': 'admin@example.com'},
);
```

Do not interpolate untrusted input into SQL. Seeders often use trusted static
data, but parameterized SQL should still be the habit.

## Testing Seeders

Seeders are plain classes, so they can be tested directly:

```dart
test('role seeder creates required roles', () async {
  await DB.autoConnect();

  await RoleSeeder().run();

  final admin = await Role().where('slug', 'admin').first();
  expect(admin, isNotNull);
});
```

For registry tests, call:

```dart
await const AppSeederRegistry().registerAll(closeConnection: false);
```

Use a test database. Do not run destructive or broad fixture seeders against a
shared development or production database.

## Common Mistakes

- Do not run `autoSeed: true` with non-idempotent seeders.
- Do not seed before the required tables exist.
- Do not forget to add the seeder to `AppSeederRegistry`.
- Do not put multiple seeder classes in one file.
- Do not create duplicate rows every time `seed` runs unless duplicates are the
  goal.
- Do not use a private helper method for reusable seed logic; extract a named
  helper or service in its own file.
- Do not close the database connection during app startup unless the app will
  reconnect before handling requests.
- Do not assume `flint seed` runs routes, middleware, or HTTP boot logic. It
  runs the seeder registry file as a Dart script.

## Review Checklist

Before finishing seed work, check:

- every seeder extends `Seeder`
- every seeder has its own file under `lib/seeders`
- `lib/config/seeder_registry.dart` imports and lists the seeder
- registry order matches data dependencies
- seeders are idempotent when they may run more than once
- migrations have run before seeders need tables
- `autoSeed` is enabled only when it is safe
- `closeSeederConnection` is correct for CLI vs app startup
- demo data is guarded by environment checks when needed
