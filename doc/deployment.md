# Deployment

Use this guide when preparing a Flint app for production. Deployment is a
server concern, a static asset concern, and an operations concern: the HTTP
server must run with production environment values, the browser UI assets must
exist, the database must be migrated, and any durable queue jobs need a worker
process.

Globe deployment is no longer supported. Do not teach `deploy-globe`,
`globe.yaml`, or `globe_cli` as a supported path for new Flint apps. Use
Docker, `flint build`, or the deployment platform's normal Dart/server process
model.

## Files To Inspect First

Before changing deployment behavior, inspect:

- `lib/main.dart` for `Flint(...)`, `listen(...)`, static assets, database
  options, jobs registry, and SSR options.
- `lib/config/table_registry.dart` before migrating production schemas.
- `lib/config/jobs_registry.dart` and `bin/worker.dart` before deploying queue
  workers.
- `lib/config/ai.dart`, `lib/ai/`, and `docs/ai.md` before deploying AI
  providers, AI worker jobs, tool policy, or AI persistence tables.
- `public/` for static files, uploads, generated Flint UI bundles, CSS, and
  `flint-sw.js`.
- `.env`, `.env.example`, hosting secrets, or deployment environment settings.
- `docker/`, `Dockerfile`, `docker-compose.yml`, or platform deployment files
  when present.
- `docs/build-and-rendering.md` before changing `flint build`, `flint web`,
  generated bundles, or SSR.
- `docs/models-and-database.md` before migrations.
- `docs/jobs-and-workers.md` before worker process changes.
- `docs/ai.md` before deploying AI providers, `flintAiTables`, production tool
  policy, run/thread memory, or artifacts.
- `docs/logging.md` before changing production log levels, file logs, request
  logs, job logs, or error logs.
- `docs/testing.md` before changing deploy test commands, CI checks, or tests
  for routes, controllers, middleware, validators, storage, jobs, seeders, or
  UI components.
- `docs/storage.md` before deploying uploads or public files.

## Deployment Checklist

For a normal production deploy:

1. Set production environment variables in the hosting platform or server.
2. Run tests and analysis; read `docs/testing.md` when adding or changing app
   tests.
3. Build Flint UI assets with `flint web --build-only` or through
   `flint build`.
4. Run database migration against the production database before starting new
   code.
5. Start the production HTTP server with `FLINT_HOT=0`.
6. Start a separate jobs worker process when the app uses `QueueJob`.
7. Verify static files, generated UI assets, uploads, health routes, logs, and
   mail/database connectivity.

## Environment Variables

Flint reads `.env` through `FlintEnv` during local and server execution. In
production, prefer real environment variables or platform secrets over committing
a production `.env` file.

Core values:

```text
APP_ENV=production
APP_DEBUG=false
APP_KEY=<strong-random-app-key>
PORT=3000
FLINT_HOT=0
```

Database values:

```text
DB_CONNECTION=mysql|postgres
DB_HOST=<database-host>
DB_PORT=3306|5432
DB_NAME=<database-name>
DB_USER=<database-user>
DB_PASSWORD=<database-password>
DB_SECURE=true|false
```

Auth values:

```text
JWT_SECRET=<strong-random-jwt-secret>
AUTH_TABLE=users
AUTH_EMAIL_COLUMN=email
AUTH_PASSWORD_COLUMN=password
AUTH_ACCESS_TOKEN_MINUTES=1440
AUTH_ENABLE_REFRESH_TOKENS=false
AUTH_REFRESH_TOKEN_DAYS=30
AUTH_ENABLE_LOGIN_THROTTLE=true
AUTH_LOGIN_MAX_ATTEMPTS=5
AUTH_LOGIN_LOCK_MINUTES=15
REQUIRE_EMAIL_VERIFICATION=false
FLINT_AUTH_COOKIE=auth.token
```

Session and cookie values:

```text
SESSION_DRIVER=memory|file|database
SESSION_TTL=7d
SESSION_DB_TABLE=sessions
SESSION_FILE=sessions.json
SESSION_COOKIE_SECURE=true
SESSION_COOKIE_HTTP_ONLY=true
SESSION_COOKIE_SAMESITE=Lax
SESSION_COOKIE_PATH=/
```

Mail values:

```text
MAIL_PROVIDER=smtp
MAIL_HOST=<smtp-host>
MAIL_PORT=587
MAIL_USERNAME=<smtp-user>
MAIL_PASSWORD=<smtp-password>
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@example.com
MAIL_FROM_NAME=Your App
MAIL_REPLY_TO=support@example.com
```

Deployment/build helpers:

```text
FLINT_WEB_UI_VERBOSE=1
FLINT_BROTLI_BIN=brotli
FLINT_TAILWIND_BIN=tailwindcss
FLINT_SWAGGER_UI_DIR=/path/to/swagger-ui
FLINT_DEBUG_VM_SERVICE=0
```

Logging values:

```text
LOG_ENABLED=true
LOG_LEVEL=info
LOG_TO_CONSOLE=true
LOG_TO_FILE=false
LOG_DIR=logs
```

Production rules:

- Do not use placeholder secrets for `APP_KEY`, `JWT_SECRET`, database
  password, mail password, OAuth secrets, or provider private keys.
- Do not commit production secrets into Git.
- Use `APP_ENV=production` and `APP_DEBUG=false`.
- Use `SESSION_COOKIE_SECURE=true` when the app is served over HTTPS.
- Set `FLINT_HOT=0` for production processes.
- Use `DB_SECURE=true` when the database provider requires TLS.
- Keep `LOG_TO_CONSOLE=true` for container platforms so the host can collect
  stdout logs.
- Enable `LOG_TO_FILE=true` only when the server has persistent storage and a
  retention plan for `LOG_DIR`.

## Static Files

Flint serves public files through `StaticFileMiddleware` when default middleware
is enabled, and through explicit static route registrations:

```dart
app.static('/assets', 'public/assets');
```

The important production static paths are:

```text
public/
  assets/js/flint-ui/    # generated Flint UI JavaScript and manifest
  assets/css/flint-ui/   # generated Flint UI CSS
  flint-sw.js            # generated Flint UI service worker
  uploads/               # public uploaded files, when the app stores uploads
```

Generate browser assets before deploy:

```bash
dart run flint_dart:flint web --build-only
```

`flint build` also builds Flint UI assets when a browser entrypoint exists and
copies non-Dart resources into `build/`.

Do not hand-edit generated files under `public/assets/js/flint-ui/`,
`public/assets/css/flint-ui/`, or `public/flint-sw.js`. Change source files
under `lib/ui` and rebuild.

Uploads under `public/uploads` are runtime data. Plan persistent storage for
that directory if the app accepts uploads. A container filesystem can be
temporary, so bind-mount or persist the uploads directory when users need saved
files after redeploys.

## Database Migration Before Deploy

Run migrations before the new production server starts handling traffic:

```bash
dart run flint_dart:flint migrate --no-interaction
```

Use `--create-db` only when the deploy environment intentionally allows the app
to create the database:

```bash
dart run flint_dart:flint migrate --create-db --no-interaction
```

Production migration rules:

- Read `docs/models-and-database.md` before changing model `Table` definitions.
- Confirm `lib/config/table_registry.dart` registers every table needed by the
  app.
- Avoid `--force` and `--drop` in production unless you intentionally want a
  destructive operation.
- Check for removed columns before deploy. Flint migrations may drop columns
  missing from the declared schema.
- Include Flint job tables when queue jobs are used. `Flint(...)` includes job
  tables in migrations by default through `includeJobTablesInMigrations: true`.
- Include `...flintAiTables` when the app needs durable AI runs, traces,
  artifacts, or thread messages. Read `docs/ai.md` before changing AI
  persistence.
- Back up the production database before risky schema changes.

## Running The Production Server

For direct source execution, run the app with hot reload disabled:

```bash
FLINT_HOT=0 dart run lib/main.dart
```

On Windows PowerShell:

```powershell
$env:FLINT_HOT = '0'
dart run lib/main.dart
```

If the app reads `PORT`, set it in the environment:

```bash
PORT=3000 FLINT_HOT=0 dart run lib/main.dart
```

For a production executable, use `flint build`:

```bash
dart run flint_dart:flint build --linux
```

This creates output under `build/`, compiles the server entrypoint with
`dart compile exe`, copies resources, precompresses public assets, writes
`start.sh`, and writes a Dockerfile when a Linux executable exists.

Run the built output:

```bash
cd build
./start.sh
```

On Windows builds:

```bat
cd build
start.bat
```

The default server entrypoint resolution for `flint build` is
`bin/server.dart`, then `bin/main.dart`, then `lib/main.dart`. Pass
`--entry <path>` when the app uses a different file.

## Docker Generation

Use the Docker generator when the app needs source-level Docker files:

```bash
dart run flint_dart:flint --make-docker
dart run flint_dart:flint --make-docker docker
dart run flint_dart:flint --make-docker .
```

The generator writes:

```text
docker/
  Dockerfile
  docker-compose.yml
  deploy.sh
  .dockerignore
  .env or .env.template
```

Behavior:

- The optional argument is the output directory. The default is `docker`.
- The app name is read from `pubspec.yaml`.
- Existing environment values are read through `FlintEnv`.
- Root `.env` is copied into the output directory when present.
- `.env.template` is created when root `.env` is missing.
- The generated Dockerfile uses `dart:stable`.
- It removes local `dependency_overrides` during Docker build so local path
  overrides do not break the container build.
- It sets `FLINT_HOT=0`.
- It runs `dart run lib/main.dart`.
- The generated compose file maps `PORT`, reads the generated `.env`, and uses
  `restart: unless-stopped`.
- The generated `deploy.sh` runs Docker Compose commands to rebuild and start
  the service.

This Docker generator is different from the Dockerfile written by
`flint build --linux`. The generator creates a source-level container that runs
`dart run lib/main.dart`. The production build Dockerfile runs the compiled
Linux executable from `build/`.

Before using the generated Docker files in production:

- Replace placeholder secrets in `.env` or `.env.template`.
- Confirm the app's `PORT` matches the exposed port.
- Add database, Redis, mail, or reverse-proxy services to compose when needed.
- Add a volume for `public/uploads` if uploads must persist.
- Run migration before starting the new app container.
- Run a worker container/process separately when the app uses queue jobs.

## Jobs Worker Process

The HTTP server does not replace the queue worker. If the app dispatches
`QueueJob` work, deploy a separate worker process:

```bash
dart run flint_dart:flint jobs-work
```

The default worker entrypoint is:

```text
bin/worker.dart
```

Use a custom worker entrypoint when needed:

```bash
dart run flint_dart:flint jobs-work --entrypoint tool/jobs_worker.dart
```

The worker entrypoint should create or import the app and call the jobs worker
setup, for example:

```dart
import 'package:flint_dart/flint_dart.dart';

import 'package:my_app/config/jobs_registry.dart';

Future<void> main() async {
  final app = Flint(
    jobsRegistry: const AppJobsRegistry(),
    autoConnectDb: true,
  );

  await app.runJobsWorker();
}
```

Worker deployment rules:

- Run at least one worker process for durable background jobs.
- Use the same production environment values as the HTTP server.
- Make sure the worker can connect to the same database and mail provider.
- Configure AI providers, tool policy, tools, and workflows in the worker
  process too when jobs execute AI runs.
- Keep `QueueJob` definitions registered in `lib/config/jobs_registry.dart`.
- Restart workers on deploy so they load new job code.
- Read `docs/jobs-and-workers.md` before changing job types, retry settings,
  queue names, or schedules.

## Production Order

A practical deploy order:

1. Build and test the release candidate.
2. Build browser assets with `flint web --build-only` or package through
   `flint build --linux`.
3. Publish files or image to the server.
4. Set environment variables.
5. Run `dart run flint_dart:flint migrate --no-interaction`.
6. Start or restart the HTTP server with `FLINT_HOT=0`.
7. Start or restart the jobs worker.
8. Verify `/docs` or `/swagger.json` only if Swagger is enabled.
9. Verify a route that returns `res.page(...)` loads generated UI assets.
10. Verify AI provider credentials, `AI_ALLOWED_*` policy values, and AI table
    migrations if the app uses AI.
11. Check HTTP server logs, worker logs, request logs, and error logs. Read
    `docs/logging.md` if the app needs log-level or file-log changes.

## Unsupported: Globe

`deploy-globe` is no longer supported and has been removed from the CLI because
Globe is no longer an active deployment target for Flint apps.

Do not add `globe.yaml`, do not ask users to install `globe_cli`, and do not use
Globe examples in new docs or generated guidance. If an existing app still has a
`globe.yaml`, treat it as old deployment configuration and move the app to
Docker, `flint build`, or the hosting provider's standard Dart process.

## Common Mistakes

- Running production with hot reload enabled.
- Forgetting to build Flint UI assets before deploy.
- Hand-editing generated JavaScript or CSS under `public/assets`.
- Running the HTTP server but forgetting the jobs worker.
- Running destructive migrations in production without a backup.
- Committing `.env` with production secrets.
- Losing uploaded files because `public/uploads` was stored only inside an
  ephemeral container.
- Returning `res.page(...)` for a page that was not registered in
  `PageRegistry`.
