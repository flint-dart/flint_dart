# CLI

The CLI entrypoint is `bin/flint_dart.dart`. It imports `lib/src/cli/commands.dart`, where commands and aliases are registered.

## Command Dispatch

The CLI uses the first argument as a command, resolves aliases, then calls `FlintCommand.execute(args.sublist(1))`.

```bash
dart run flint_dart:flint <command> [options]
```

If no command is given, it prints usage. Unknown commands print usage and exit with code `1`.

## Available Commands

Registered commands include:

```text
create
agent / agents / docs:agent
start / run / serve / server
stop / port:stop / kill-port
jobs-work / worker / jobs
build
web
migrate / db:migrate
seed / db:seed
db:create
db:user:create
db:export
db:table:export
make:model
make:controller
make:resource
make:middleware
make:docker
make:isolate
make:seeder
make:route
make:page
make:ui
make:mail
docs:generate
update
upgrade
version
```

The actual keys include older `--make-model` style names; aliases map friendly names such as `make:model` to those keys.

## Running The Server

`RunServerCommand` resolves the port from `--port=3000`, `--port 3000`, a positional number, or `PORT` with default `8080`.

```bash
dart run flint_dart:flint run --port=3000
```

Unless `FLINT_HOT=0` or `FLINT_HOT=false`, it starts `dart run flint_dart:hot_reload lib --port=<port>`.

## Agent Docs

`AgentDocsCommand` creates AI/developer guidance in an existing Flint app:

```bash
dart run flint_dart:flint agent
dart run flint_dart:flint agent --force
```

It writes `AGENTS.md` and the standard docs files under `docs/`. Existing files are skipped by default; `--force` or `-f` overwrites them.

## Generators

`MakeModelCommand` creates `lib/models/<snake_name>.dart` and tries to register the model's table in `lib/config/table_registry.dart`.

```bash
dart run flint_dart:flint make:model BlogPost
```

Generated model shape:

```dart
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

`MakeControllerCommand` creates methods named `index`, `show`, `create`, `update`, and `delete`.

`MakeRouteCommand` creates a `RouteGroup` with CRUD-style routes and Swagger comments.

## Database Commands

`migrate` runs `DBMigrateCommand`, reads `lib/config/table_registry.dart`, and applies table changes. Useful options from the implementation include:

```bash
dart run flint_dart:flint migrate --no-interaction
dart run flint_dart:flint migrate --create-db --no-interaction
dart run flint_dart:flint migrate --force
dart run flint_dart:flint migrate --drop
dart run flint_dart:flint migrate --verbose
```

`--drop` drops all tables and returns without recreating them.

## Important Limits

- Generators do not overwrite existing files.
- `make:model` auto-registration depends on a matching `runTableRegistry([...], _, sendPort)` or compatible registry call.
- `run` starts a child process and forwards SIGINT.
- `jobs-work` defaults to `bin/worker.dart` and exits if that file does not exist.
