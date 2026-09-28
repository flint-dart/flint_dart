# CLI

The Flint CLI entrypoint is `bin/flint_dart.dart`. It registers command objects
from `lib/src/cli/`, resolves aliases, and calls the selected command with the
remaining arguments.

Most examples use:

```bash
dart run flint_dart:flint <command> [options]
```

If the CLI is globally activated, the shorter form is:

```bash
flint <command> [options]
```

## Command Dispatch

The first CLI argument is the command name. The CLI checks `aliasCommands` first,
then looks up the final key in `commands`.

If no command is passed, Flint prints usage. If the command is unknown, Flint
prints usage and exits with code `1`. If a command throws, the entrypoint prints
the error and sets `exitCode = 1`.

## Deprecation Notice

Use the `--make-*` generator commands in new docs, examples, and applications.
The `make:*` aliases still work today for compatibility, but they are deprecated
and scheduled for removal in Flint Dart `1.5.0`.

This is not only a naming cleanup. Flint is a Dart-first, object-oriented
framework with its own architecture. It has controllers, routes, models,
migrations, middleware, WebSockets, UI, and CLI generators, but those pieces
should be learned as Flint concepts, not copied from another framework's
conventions. The ORM and migration ideas may feel familiar, but the API,
request context, route registration, validation flow, fullstack UI layout, and
generator behavior are Flint's own.

The `--make-*` style reads like normal Dart command-line tooling and keeps the
CLI away from framework-copy assumptions. Treat `make:*` as legacy
compatibility syntax only and do not infer Laravel-style behavior from it.

For example, teach this:

```bash
dart run flint_dart:flint --make-model Course
dart run flint_dart:flint --make-controller CourseController
dart run flint_dart:flint --make-route Course
```

Do not teach the `make:model`, `make:controller`, or `make:route` alias style
for new apps.

## Command List

These are the registered commands and the important aliases currently accepted
by the CLI.

| Primary command | Compatibility aliases | Purpose |
| --- | --- | --- |
| `create` | none | Create a new Flint app from the sample template. |
| `agent` | `agents`, `docs:agent`, `docs:agents` | Copy Flint framework docs into an app. |
| `run` | `start`, `serve`, `server` | Run the development server. |
| `stop` | `port:stop`, `kill-port`, `port-stop` | Stop the process listening on a port. |
| `jobs-work` | `worker`, `jobs`, `jobs:work`, `job:work`, `--jobs-work`, `--job-work` | Run the jobs worker entrypoint. |
| `build` | `--build` | Build the app for production. |
| `web` | `--web`, `web:run`, `web:serve`, `web:build` | Build and optionally serve Flint UI browser assets. |
| `migrate` | `db:migrate`, `db-migrate` | Run database migrations. |
| `seed` | `--seed`, `--db-seed`, `db:seed`, `db-seed` | Run database seeders. |
| `--db-create` | `db:create`, `db-create` | Create the configured database or a named database. |
| `--db-user-create` | `db:user:create`, `db-user-create` | Create a database user and grant privileges. |
| `--db-export` | `db:export`, `db-export` | Export a database dump. |
| `--db-table-export` | `db:table:export`, `db-table-export` | Export one table. |
| `--make-model` | `make:model`, `make-model` | Create a model class. |
| `--make-controller` | `make:controller`, `make-controller` | Create a controller class. |
| `--make-resource` | `make:resource`, `make-resource` | Create controller, routes, and route registration. |
| `--make-middleware` | `make:middleware`, `make-middleware` | Create middleware. |
| `--make-docker` | `make:docker`, `make-docker` | Create Docker deployment files. |
| `--make-isolate` | `make:isolate`, `make-isolate` | Create an isolate task. |
| `--make-seeder` | `make:seeder`, `make-seeder` | Create and register a seeder. |
| `--make-route` | `make:route`, `make-route`, `route` | Create a route group. |
| `--make-page` | `make:page`, `make-page`, `page` | Create a Flint UI page. |
| `--make-ui` | `make:ui`, `make-ui`, `ui` | Create Flint UI pages, components, sections, and root design files. |
| `--make-mail` | `make:mail`, `make-mail` | Create a mail class and `.flint.html` template. |
| `--docs-generate` | `docs:generate`, `docs-generate` | Generate Swagger JSON from route comments. |
| `update` | `--update` | Update direct Flint package dependencies in the app. |
| `upgrade` | `--upgrade` | Run project dependency upgrade and global CLI activation. |
| `version` | `--version`, `-v`, `--v` | Print the installed Flint Dart version. |

## Create

`create` makes a new Flint project by cloning the official sample app.

```bash
dart run flint_dart:flint create course_app
```

Behavior:

- If no project name is passed, the command prompts for one.
- Empty names are rejected.
- If the target directory already exists, creation stops.
- The sample repository is cloned with `git clone --depth 1`.
- The cloned `.git` directory is removed so the app starts as a fresh project.
- `pubspec.yaml` is updated so `name:` matches the project name.
- Dart imports that point at `package:sample/` are rewritten to the new package
  name.
- `AGENTS.md` is written if it does not already exist.
- `dart pub get` runs in the new project.

After creation:

```bash
cd course_app
dart run flint_dart:flint run
```

This command needs `git`, network access, and a working Dart SDK.

## Local Framework Docs

`agent` creates local Flint framework docs inside an existing Flint app.

```bash
dart run flint_dart:flint agent
dart run flint_dart:flint agent --force
dart run flint_dart:flint agent -f
```

Behavior:

- The command must be run from an app root with `pubspec.yaml`.
- It resolves the installed `flint_dart` package and reads its top-level
  `doc/*.md` files.
- `doc/AGENTS.md` is copied to the app root as `AGENTS.md`.
- Every other Markdown file is copied under the app's `docs/` directory.
- Existing files are skipped by default.
- `--force` or `-f` overwrites existing files.
- `{{project_name}}` inside the source `AGENTS.md` is replaced with the app name
  from `pubspec.yaml`.

Use this command when an app should carry local framework docs such as
`docs/authentication.md`, `docs/routing.md`, `docs/websockets.md`, and
`docs/validation.md`. For test work, read `docs/testing.md` before changing
route, controller, middleware, validator, storage, job, seeder, or UI component
tests. For server-rendered HTML or mail templates, read `docs/templates.md`.

## Run

`run` starts the app in development mode.

```bash
dart run flint_dart:flint run
dart run flint_dart:flint run 3000
dart run flint_dart:flint run --port=3000
dart run flint_dart:flint run --port 3000
dart run flint_dart:flint run --no-web-build
```

Port resolution order:

- `--port=3000`
- `--port 3000`
- a positional number such as `3000`
- `PORT` from `.env`
- default `8080`

Behavior:

- Hot reload is enabled by default.
- With hot reload enabled, the command starts
  `dart run flint_dart:hot_reload lib --port=<port>`.
- Set `FLINT_HOT=0` or `FLINT_HOT=false` to disable hot reload.
- With hot reload disabled, the command runs `dart run lib/main.dart <port>`.
- When hot reload is disabled and web building is not skipped, Flint builds
  Flint UI assets if a UI entrypoint is present.
- `--no-web-build` skips the optional web asset build.
- Set `FLINT_DEBUG_VM_SERVICE=1`, `true`, or `yes` to pass
  `--enable-vm-service` into the hot reload command.
- `Ctrl+C` forwards `SIGINT` to the child process before exiting.

Use `run` while developing server routes, controllers, middleware, WebSockets,
and Flint UI together.

## Stop

`stop` frees a local port by finding and killing the process listening on it.

```bash
dart run flint_dart:flint stop 3000
dart run flint_dart:flint stop --port=3000
dart run flint_dart:flint stop --port 3000
dart run flint_dart:flint stop -p 3000
```

Behavior:

- The port must be between `1` and `65535`.
- On Windows, Flint reads `netstat -ano` and uses `taskkill /T /F`.
- On Unix-like systems, Flint tries `lsof`, then `ss`, then `netstat`.
- On Unix-like systems, Flint sends `SIGTERM` first, then `SIGKILL` if the port
  is still busy.
- The CLI avoids killing its own process ID.

Use this when a previous dev server kept a port busy.

## Jobs Worker

`jobs-work` runs a dedicated Flint jobs worker entrypoint.

Read `docs/jobs-and-workers.md` before building job features. New background
jobs should extend `QueueJob`; the older `FlintJob` base class is deprecated
compatibility for existing apps.

```bash
dart run flint_dart:flint jobs-work
dart run flint_dart:flint jobs-work --entrypoint=tool/jobs_worker.dart
dart run flint_dart:flint jobs-work --entrypoint tool/jobs_worker.dart
dart run flint_dart:flint jobs-work tool/jobs_worker.dart
```

Behavior:

- The default entrypoint is `bin/worker.dart`.
- A positional path or `--entrypoint` changes the entrypoint.
- The entrypoint must exist.
- Flint runs `dart run <entrypoint>`.
- `Ctrl+C` forwards shutdown to the worker.
- On non-Windows platforms, `SIGTERM` is also forwarded.

The worker entrypoint should call the app's jobs worker setup, for example
`app.runJobsWorker()`.

The worker is not the same thing as an isolate task. The worker is a process
that polls durable queued job records and executes registered `QueueJob`
classes. An isolate task is only a Dart execution mechanism for heavy work.

## Build

`build` creates a production bundle in `build/`.

```bash
dart run flint_dart:flint build
dart run flint_dart:flint build --entry lib/main.dart
dart run flint_dart:flint build --platform linux
dart run flint_dart:flint build --linux
dart run flint_dart:flint build --windows
dart run flint_dart:flint build --macos
dart run flint_dart:flint build --both
dart run flint_dart:flint build --help
```

Options:

- `--entry <path>` chooses the Dart entrypoint.
- `--platform <value>` accepts `linux`, `windows`, `macos`, or `both`.
- `--linux`, `--windows`, `--macos`, and `--both` are shortcuts.
- `--help` or `-h` prints help.

Entrypoint resolution:

- If `--entry` is passed, that file must exist.
- Without `--entry`, Flint checks `bin/server.dart`, `bin/main.dart`, then
  `lib/main.dart`.

Behavior:

- The previous `build/` directory is removed.
- Flint builds Flint UI assets if a UI entrypoint is present.
- The app name is read from `pubspec.yaml`.
- Non-Dart app resources are copied into `build/`.
- The command skips `.dart_tool`, `.git`, `.idea`, `.vscode`, `doc`,
  `pubspec.yaml`, `pubspec.lock`, and the build directory itself.
- `docs/swagger.json` or root `swagger.json` is copied to
  `build/public/swagger.json` and `build/public/docs/swagger.json` when present.
- Swagger UI assets are copied when available from the package or local
  framework paths.
- `build/public` is precompressed when it exists.
- Dart compiles the app with `dart compile exe`.
- The host OS is used by default.
- `--both` builds Linux and Windows binaries.
- Linux and macOS outputs get `start.sh`.
- Windows output gets `start.bat`.
- A Dockerfile is generated only when a Linux binary exists, so use `--linux` or
  `--both` if the build output should include a Dockerfile.

The generated Dockerfile in `build/` runs the prebuilt Linux executable through
`start.sh`; it is different from the source-level Docker files created by
`--make-docker`.

Read `docs/deployment.md` before wiring build output into production servers,
Docker images, migrations, static files, or worker processes.

Read `docs/build-and-rendering.md` for the full relationship between
`flint build`, `flint web`, browser entrypoints, generated bundles, page
registry lookup, and SSR.

## Web

`web` builds Flint UI browser assets and, unless `--build-only` is used, serves
the static directory locally.

```bash
dart run flint_dart:flint web
dart run flint_dart:flint web --port 3000
dart run flint_dart:flint web --entry lib/ui/main.dart --web-dir public
dart run flint_dart:flint web --out public/assets/js/flint-ui/main.dart.js
dart run flint_dart:flint web --build-only
dart run flint_dart:flint web --build-only --page-bundles
dart run flint_dart:flint web --build-only --no-page-bundles
dart run flint_dart:flint web --build-only --shared-runtime
dart run flint_dart:flint web --build-only --page Home
```

Options:

- `--entry <path>` chooses the Dart web entry file.
- `--web-dir <path>` chooses the static web root.
- `--out <path>` chooses the JavaScript output file.
- `--shared-runtime` compiles one shared runtime with deferred page chunks.
- `--page-bundles` compiles page-level bundles. This is the default.
- `--no-page-bundles` compiles only one global JavaScript bundle.
- `--no-shared-runtime` disables shared runtime mode.
- `--pages-config <path>` chooses the page bundle config file.
- `--page <name>` compiles one page-level bundle by component name.
- `--port <number>` chooses the local static server port. The default is `8080`.
- `--build-only` compiles without starting the static server.
- `--help` or `-h` prints help.

Entrypoint auto-detection checks common paths including:

- `lib/ui/main.dart`
- `flint_ui/main.dart`
- `flint_ui/flint_ui/main.dart`
- `lib/flint_ui/main.dart`
- `web/main.dart`
- `lib/web/main.dart`

Static directory resolution:

- For `lib/ui/main.dart`, Flint prefers `public/` when it exists.
- For a `flint_ui` entry directory, Flint checks sibling `web/`, then sibling
  `public/`.
- Otherwise it checks root `web/`, then root `public/`.
- If no static directory is found, the entry file's directory is used.

Output defaults:

- For `lib/ui/main.dart` with `public/`, JavaScript is written under
  `public/assets/js/flint-ui/`.
- CSS is written under `public/assets/css/flint-ui/`.
- Other layouts default to `main.dart.js` and `style.css` in the static web
  directory.

The build also handles root design CSS, page bundle manifests, hashed JavaScript
asset names, compressed assets, and `flint-sw.js` service worker output.

Set `FLINT_WEB_UI_VERBOSE=1`, `true`, or `yes` when you need verbose web build
logs.

Read `docs/build-and-rendering.md` before changing Flint UI build output,
bundle mode, `flint_ui.yaml`, generated assets, page response script
resolution, or SSR.

## Migrate

`migrate` applies database schema changes from `lib/config/table_registry.dart`.

```bash
dart run flint_dart:flint migrate
dart run flint_dart:flint migrate --no-interaction
dart run flint_dart:flint migrate --create-db
dart run flint_dart:flint migrate --yes
dart run flint_dart:flint migrate --force
dart run flint_dart:flint migrate --drop
dart run flint_dart:flint migrate --verbose
```

Options:

- `--no-interaction` disables the prompt to create a missing database.
- `--create-db` creates the configured database if it is missing.
- `--yes` also allows database creation.
- `--force` drops and recreates existing registered tables.
- `--drop` drops all existing tables and stops.
- `--verbose` includes stack traces and deeper failure details.

Behavior:

- Flint checks `.env` for database settings such as `DB_CONNECTION`, `DB_HOST`,
  `DB_PORT`, `DB_USER`, `DB_PASSWORD`, and `DB_NAME`.
- If the configured database is missing, Flint can prompt or create it depending
  on the options.
- The app connects through `DB.autoConnect()`.
- `lib/config/table_registry.dart` is spawned as an isolate.
- The registry must send registered table definitions back to the migration
  command.
- If no registry file exists or no tables are registered, migration stops.
- New tables are created from each model's `Table`.
- Missing `created_at` and `updated_at` columns are injected and ensured.
- On the auth table, provider columns are protected and may be injected.
- On PostgreSQL, MySQL-style DDL is normalized where possible.
- On PostgreSQL, Flint creates or refreshes an `updated_at` trigger.
- Existing tables are compared against declared schemas.
- Missing columns are added.
- Columns with `renamedFrom` can be renamed instead of recreated.
- Compatible type, nullability, default, timestamp, and comment changes are
  applied.
- Declared indexes and inline `UNIQUE` indexes are synced.
- Columns missing from the declared schema are dropped unless protected.

Important: removing a column from a model `Table` can drop that column on the
next migration. Check `docs/models-and-database.md` before changing table
schemas.

## Seed

`seed` runs the app's seeder registry.

```bash
dart run flint_dart:flint seed
```

Behavior:

- Flint prefers `lib/config/seeder_registry.dart`.
- If that file does not exist, Flint checks the legacy
  `lib/seeders/seeder.dart`.
- If neither file exists, the command exits with code `1`.
- The selected file runs through `dart run`.
- A non-zero seeder process exits the CLI with code `1`.

Use `--make-seeder` to create the modern seeder file and registry.
Read `docs/seeders.md` for `Seeder`, `SeederRegistry`, `autoSeed`, registry
ordering, and idempotent seed patterns.

## Database Admin

The database admin commands read the same `.env` database settings as the app.

Create a database:

```bash
dart run flint_dart:flint --db-create
dart run flint_dart:flint --db-create course_app
```

Behavior:

- If a name is passed, that name is used.
- Otherwise `DB_NAME` from `.env` is used.
- MySQL connects to the admin database named `mysql`.
- PostgreSQL connects to the admin database named `postgres`.
- MySQL uses `CREATE DATABASE IF NOT EXISTS`.
- PostgreSQL uses `CREATE DATABASE`.

Create a database user:

```bash
dart run flint_dart:flint --db-user-create
dart run flint_dart:flint --db-user-create app_user secure_password
```

Behavior:

- The first argument is the target user.
- The second argument is the target password.
- If omitted, the command uses `DB_USER` and `DB_PASSWORD` from `.env`, with
  fallback development defaults.
- `DB_NAME` must be set.
- MySQL creates the user for `%`, grants privileges on `DB_NAME`, then flushes
  privileges.
- PostgreSQL creates a login role if missing and grants privileges on `DB_NAME`.

Export the whole database:

```bash
dart run flint_dart:flint --db-export
dart run flint_dart:flint --db-export backup.sql
```

Export one table:

```bash
dart run flint_dart:flint --db-table-export users
dart run flint_dart:flint --db-table-export users users_backup.sql
```

Export behavior:

- MySQL uses `mysqldump`.
- PostgreSQL uses `pg_dump`.
- The dump utility must be installed and available in `PATH`.
- If no output file is passed, Flint writes a timestamped `.sql` file.
- Table export accepts table names with only letters, numbers, and underscores.
- Passwords are passed through `MYSQL_PWD` or `PGPASSWORD` environment values.

## Model Generator

`--make-model` creates a model file under `lib/models`.

```bash
dart run flint_dart:flint --make-model BlogPost
```

Behavior:

- `BlogPost` becomes class `BlogPost`.
- The file path becomes `lib/models/blog_post.dart`.
- The generated class extends `Model<BlogPost>`.
- The default table name is the snake-case file stem plus `s`, such as
  `blog_posts`.
- A sample nullable `name` getter and `name` column are included.
- Existing model files are not overwritten.
- If `lib/config/table_registry.dart` exists, Flint tries to add the import and
  register `BlogPost().table`.
- Auto-registration expects a compatible `runTableRegistry([...], _, sendPort)`
  or `runTableRegistry([...])` call.

Generated model shape:

```dart
import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

class BlogPost extends Model<BlogPost> {
  BlogPost() : super(() => BlogPost());

  String? get name => getAttribute("name");

  @override
  Table get table => Table(
        name: 'blog_posts',
        columns: [
          Column(name: 'name', type: ColumnType.string),
        ],
      );
}
```

After generating, edit the model in its own file and keep table changes
intentional because `migrate` uses the registered table schema.

## Controller Generator

`--make-controller` creates a request-scoped controller.

```bash
dart run flint_dart:flint --make-controller CourseController
```

Behavior:

- `CourseController` becomes class `CourseController`.
- The file path becomes `lib/controllers/course_controller.dart`.
- Existing controller files are not overwritten.
- The generated class extends `Controller`.
- Actions are `index`, `show`, `create`, `update`, and `delete`.
- Actions use bound `req` and `res` from the current `Context`.
- The generated template does not use legacy two-argument action parameters.

Controllers should be routed through `app.controller(YourController.new)` so
Flint binds the active request context before each action.

## Route Generator

`--make-route` creates a `RouteGroup` file.

```bash
dart run flint_dart:flint --make-route Course
```

Behavior:

- `Course` becomes class `CourseRoutes`.
- The file path becomes `lib/routes/course_routes.dart`.
- The route file imports `../controllers/course_controller.dart`.
- The group prefix is `'/Course'` when the raw input is `Course`; adjust it if
  you want lowercase URLs such as `'/courses'`.
- The group tag is the capitalized name.
- The generated route group uses
  `final routes = app.controller(CourseController.new)`.
- CRUD routes are created for list, create, show, update, and delete.
- Swagger comments are included above each route.
- Existing route files are not overwritten.

Generated route shape:

```dart
class CourseRoutes extends RouteGroup {
  @override
  String get prefix => '/Course';

  @override
  String get tag => 'Course';

  @override
  void register(Flint app) {
    final routes = app.controller(CourseController.new);

    routes.get('/', (controller) => controller.index());
    routes.post('/', (controller) => controller.create());
    routes.get('/:id', (controller) => controller.show());
    routes.put('/:id', (controller) => controller.update());
    routes.delete('/:id', (controller) => controller.delete());
  }
}
```

For production code, normalize the prefix and then update the controller methods
to validate input and use models.

## Resource Generator

`--make-resource` creates the controller and route group together, then tries to
register the route group.

```bash
dart run flint_dart:flint --make-resource Course
```

Behavior:

- Creates `lib/controllers/course_controller.dart` when missing.
- Creates `lib/routes/course_routes.dart` when missing.
- Existing generated files are kept.
- The controller extends `Controller`.
- The route file uses `app.controller(CourseController.new)`.
- The route file includes Swagger comments.
- If `lib/routes/app_routes.dart` exists, Flint inserts the route import and
  `app.routes(CourseRoutes());`.
- If `lib/routes/app_routes.dart` does not exist, auto-registration is skipped.

Use this when starting a new API resource. Then split real behavior into
models, services, validators, middleware, and UI files as needed. Keep one class
or reusable helper per file.

## Middleware Generator

`--make-middleware` creates a `Middleware` class.

```bash
dart run flint_dart:flint --make-middleware AuthMiddleware
```

Behavior:

- `AuthMiddleware` becomes class `AuthMiddleware`.
- The file path becomes `lib/middlewares/auth_middleware.dart`.
- Existing middleware files are not overwritten.
- The generated class extends `Middleware`.
- `handle` returns a `Handler`.
- The returned handler receives `Context ctx`.
- The template checks `ctx.res` because WebSocket contexts do not have a
  response object.
- The template reads `ctx.req.bearerToken`.
- HTTP unauthorized responses use `res.status(401).send('Unauthorized')`.
- WebSocket requests pass through by default in the generated template.

Customize the template for the app. For socket-specific authorization, attach
middleware through the WebSocket route's `middlewares:` argument and close the
socket when the client is not allowed.

## UI Generator

`--make-ui` creates modern Flint UI files under `lib/ui` by default.

```bash
dart run flint_dart:flint --make-ui --page Courses
dart run flint_dart:flint --make-ui --component CourseCard
dart run flint_dart:flint --make-ui --section CourseList
dart run flint_dart:flint --make-ui --root-design
dart run flint_dart:flint --make-ui --page Courses --with-root-design
dart run flint_dart:flint --make-ui --path lib/ui --page Courses
```

Options and aliases:

- `--page <Name>` or `-page <Name>` creates a page.
- `--component <Name>` or `-component <Name>` creates a component.
- `--section <Name>` or `-section <Name>` creates a section.
- `--root-design` or `-root-design` creates `components/root_design.dart`.
- `--with-root-design` creates or updates the page entrypoint to use root
  design.
- `--path <path>`, `--p <path>`, `-p <path>`, `--c <path>`, or `-c <path>`
  chooses the UI root.
- `--help` or `-h` prints help.

UI root resolution:

- An explicit `--path` is created and used.
- If `lib/ui` exists, it is used.
- If a compatible `flint_ui` layout exists, it is used.
- Otherwise `lib/ui` is created.

Generated files:

- Pages go in `lib/ui/pages/<name>_page.dart`.
- Components go in `lib/ui/components/<name>.dart`.
- Sections go in `lib/ui/sections/<name>_section.dart`.
- Root design goes in `lib/ui/components/root_design.dart`.
- `lib/ui/main.dart` is created when a page or root design needs it.
- `lib/ui/component_registry.dart` is created when a page needs registration.
- Pages are registered in `PageRegistry`.

Use this generator instead of adding private UI helper methods inside an
existing page. Flint is fullstack, and frontend code follows the same one
class/component/helper per file rule as backend code.

## Page Generator

`--make-page` is a focused page generator for Flint UI.

```bash
dart run flint_dart:flint --make-page Dashboard
dart run flint_dart:flint --make-page Settings --no-register
```

Options:

- `--no-register` creates the page without updating `component_registry.dart`.
- `--help` or `-h` prints help.

Behavior:

- The UI root is resolved from `lib/ui`, `flint_ui`, `flint_ui/flint_ui`, or
  `lib/flint_ui`.
- If no UI root exists, `lib/ui` is created.
- The page is written to `pages/<name>_page.dart`.
- `main.dart` is created when missing.
- Unless `--no-register` is used, `component_registry.dart` is created and the
  page is registered.
- Existing page files are not overwritten.

For new apps, prefer `--make-ui --page <Name>` because it also supports
components, sections, root design, and explicit UI paths.

## Mail Generator

`--make-mail` creates a `ViewMailable` class and a `.flint.html` template.

```bash
dart run flint_dart:flint --make-mail welcome
dart run flint_dart:flint --make-mail PasswordReset
```

Behavior:

- Names may contain letters, numbers, underscores, and hyphens.
- The Dart class is written to `lib/mail/<name>_mail.dart`.
- The template is written to `lib/mail/views/<name>.flint.html`.
- Existing mail files are not overwritten.
- The generated class extends `ViewMailable`.
- The generated class defines `subject`, `view`, `data`, and `to`.
- The template uses Flint template expressions such as `{{ recipientName }}`.

After generating, edit the mail class and template together. See `docs/mail.md`
for mail configuration, OTP email patterns, previews, and template syntax.

## Seeder Generator

`--make-seeder` creates a seeder and registers it.

```bash
dart run flint_dart:flint --make-seeder UserSeeder
dart run flint_dart:flint --make-seeder User
```

Behavior:

- If the passed name does not end with `Seeder`, Flint appends `Seeder`.
- `User` becomes class `UserSeeder`.
- The file path becomes `lib/seeders/user_seeder.dart`.
- Existing seeder files are not overwritten.
- The generated class extends `Seeder`.
- `lib/config/seeder_registry.dart` is created when missing.
- The registry uses `AppSeederRegistry extends SeederRegistry`.
- The new seeder import and instance are inserted into the registry.
- A legacy `runSeeders([...])` registry can also be updated.

Run the seeders with:

```bash
dart run flint_dart:flint seed
```

Read `docs/seeders.md` for the full seeder lifecycle, including
`SeederRegistry`, `app.seed(...)`, and `autoSeed`.

## Isolate Generator

`--make-isolate` creates an isolate task.

Read `docs/isolate-tasks.md` before using isolates. Isolate tasks are for
CPU-heavy or blocking work that should not run on the main Dart server isolate.
They are not durable job records; use `QueueJob` when the work needs retries,
status, schedules, or a worker process.

```bash
dart run flint_dart:flint --make-isolate send_email
```

Behavior:

- Names may contain letters, numbers, underscores, and hyphens.
- The class name becomes `<Name>Task`.
- The file path becomes `lib/isolate/tasks/<name>_task.dart`.
- Existing isolate task files are not overwritten.
- The generated class extends `IsolateTask<void>`.
- The generated `performTask()` method is where heavy or blocking work belongs.
- Run the task with `YourTask().perform(...)`.
- Read task results from `onDone`.
- Handle task failures with `onError`.

Use isolate tasks for work that should not block the main server event loop.

## Docker Generator

`--make-docker` creates source-level Docker deployment files.

```bash
dart run flint_dart:flint --make-docker
dart run flint_dart:flint --make-docker docker
dart run flint_dart:flint --make-docker .
```

Behavior:

- The optional first argument is the output directory. The default is `docker`.
- The output directory is created if missing.
- If the output directory already exists, known Docker files are overwritten.
- The app name is read from `pubspec.yaml`; `flint_app` is used if missing.
- Environment defaults are read through `FlintEnv`.
- The command writes `Dockerfile`.
- The command writes `docker-compose.yml`.
- The command writes `deploy.sh`.
- The command writes `.dockerignore`.
- If root `.env` exists, it is copied into the output directory.
- If root `.env` is missing, `.env.template` is created.

The generated Dockerfile:

- Uses `dart:stable`.
- Copies `pubspec.*`.
- Removes local `dependency_overrides` from `pubspec.yaml` during Docker build
  so path overrides do not break container builds.
- Runs `dart pub get`.
- Copies app source.
- Runs `dart pub get --offline`.
- Sets `FLINT_HOT=0`.
- Uses `PORT` from the Docker build argument.
- Runs `dart run lib/main.dart`.

The generated compose file:

- Builds from the app root using the generated Dockerfile.
- Maps `PORT` to the same host port.
- Reads environment values from the copied `.env`.
- Sets restart policy to `unless-stopped`.

The generated `deploy.sh` expects Docker Compose, checks for `.env`, runs
`docker-compose down`, builds, starts, waits briefly, and prints log commands.

Read `docs/deployment.md` before using generated Docker files in production.

## Docs Generate

`--docs-generate` generates Swagger JSON from route comments.

```bash
dart run flint_dart:flint --docs-generate
```

Behavior:

- The command scans Dart files under `lib/routes`.
- If `lib/routes` does not exist, the command returns without writing docs.
- `RouteParser` reads supported route comments and route declarations.
- `SwaggerGenerator` builds the OpenAPI document.
- Output is written to `docs/swagger.json`.
- `docs/` is created when missing.

The source of truth is the route file comments, not the generated
`docs/swagger.json`. See `docs/swagger-and-api-docs.md` before documenting a
public API.

## Update

`update` updates direct Flint package dependencies only.

```bash
dart run flint_dart:flint update
```

Behavior:

- Runs `dart pub outdated --json`.
- Reads `pubspec.yaml` in the current directory.
- Only direct dependencies whose package names start with `flint_` are updated.
- Updated constraints are written as `^<latest>`.
- Transitive dependencies and unrelated packages are ignored.
- If anything changed, `dart pub get` runs.

Use `update` when you want a conservative Flint-only dependency bump.

## Upgrade

`upgrade` performs a broader upgrade.

```bash
dart run flint_dart:flint upgrade
```

Behavior:

- If `pubspec.yaml` exists, the command runs `dart pub upgrade`.
- Then it runs `dart pub global activate flint_dart`.
- If no `pubspec.yaml` exists, it skips the project upgrade and only activates
  the global CLI package.

Use `upgrade` when you want both app dependencies and the globally activated CLI
to move forward.

## Version

`version` prints the installed Flint Dart package version.

```bash
dart run flint_dart:flint version
dart run flint_dart:flint --version
dart run flint_dart:flint -v
```

Behavior:

- The command resolves `package:flint_dart/flint_dart.dart`.
- It reads the package `pubspec.yaml`.
- It prints the `version:` value.
- If the package or version cannot be found, it prints `unknown`.

## Usage Guidance

When using the CLI:

- Prefer the primary commands from this document.
- Use `--make-*` for generators.
- Treat `make:*` as deprecated compatibility syntax until it is removed in
  Flint Dart `1.5.0`.
- Do not describe Flint as a clone or port of another framework. Learn the
  actual Flint APIs from the local docs and source.
- Run generators from the app root so relative output paths are correct.
- Remember that generators skip existing files instead of overwriting them.
- Inspect generated files before editing them.
- Keep one class, component, section, page, middleware, seeder, mail class, or
  reusable helper per file.
- For controller-backed routes, use `Controller` subclasses and
  `app.controller(YourController.new)`.
- For middleware, use `Context ctx`; `ctx.res` can be null for WebSocket
  contexts.
- For Flint UI, source files belong under `lib/ui`, while compiled assets under
  `public/assets/js/flint-ui/` are generated output.

## Common Workflows

Create and run an app:

```bash
dart run flint_dart:flint create course_app
cd course_app
dart run flint_dart:flint run --port=3000
```

Create AI-readable framework docs in an app:

```bash
dart run flint_dart:flint agent
```

Create a resource:

```bash
dart run flint_dart:flint --make-model Course
dart run flint_dart:flint --make-controller CourseController
dart run flint_dart:flint --make-route Course
```

Or create the controller and route group together:

```bash
dart run flint_dart:flint --make-resource Course
```

Create frontend files:

```bash
dart run flint_dart:flint --make-ui --page Courses --with-root-design
dart run flint_dart:flint --make-ui --section CourseList
dart run flint_dart:flint --make-ui --component CourseCard
dart run flint_dart:flint web --build-only
```

Prepare database structure and seed data:

```bash
dart run flint_dart:flint migrate --create-db
dart run flint_dart:flint --make-seeder CourseSeeder
dart run flint_dart:flint seed
```

Generate API documentation and build:

```bash
dart run flint_dart:flint --docs-generate
dart run flint_dart:flint build --linux
```

## Important Limits

- The CLI is intentionally file-system based. Run commands from the app root
  unless a command explicitly supports another output directory.
- Generators do not overwrite existing source files.
- `--make-resource` only auto-registers routes when `lib/routes/app_routes.dart`
  exists and matches the expected shape.
- `--make-model` auto-registration depends on a compatible table registry.
- `migrate` can drop undeclared columns. Review model table definitions before
  running it.
- `--drop` drops all tables and does not recreate them in the same command.
- `web` needs a valid Flint UI entrypoint.
- `build` removes the existing `build/` directory before writing new output.
- `jobs-work` defaults to `bin/worker.dart` and exits if that file does not
  exist.
- `--db-export` and `--db-table-export` require `mysqldump` or `pg_dump` in
  `PATH`.
