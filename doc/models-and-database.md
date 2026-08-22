# Models And Database

The database layer is split across `DB`, `QueryBuilder`, `Model`, schema definitions, migrations, and table registries.

## Connecting

`DB.autoConnect()` reads environment values through `FlintEnv`:

```text
DB_CONNECTION=mysql|postgres
DB_HOST
DB_PORT
DB_NAME
DB_USER
DB_PASSWORD
DB_SECURE
```

`Flint(autoConnectDb: true)` enables lazy auto-connect and also attempts background connection after the server binds. If `autoConnectDb: false`, database calls throw unless you call `DB.connect(...)` or `DB.autoConnect()`.

```dart
await DB.connect(database: 'my_app');
final rows = await DB.query(
  'SELECT * FROM users WHERE email = :email',
  namedParams: {'email': 'ada@example.com'},
);
```

`DB.normalizeQuery()` converts named or positional parameters for MySQL and PostgreSQL. PostgreSQL placeholders become `$1`, `$2`; MySQL uses `?`.

## Defining Models

Models extend `Model<T>` and provide a `Table`. The sample `example/lib/models/post_model.dart`:

```dart
class PostModel extends Model<PostModel> {
  PostModel() : super(() => PostModel());

  String? title;
  String? subTitle;

  @override
  PostModel fromMap(Map<dynamic, dynamic> map) => PostModel()
    ..title = map['title']?.toString()
    ..subTitle = map['subTitle']?.toString();

  @override
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subTitle': subTitle,
    };
  }

  @override
  Table get table => Table(
        name: 'post_models',
        columns: [
          Column(name: 'title', type: ColumnType.string),
          Column(name: 'subTitle', type: ColumnType.string, isNullable: true),
        ],
      );
}
```

The generated model template uses attribute getters instead:

```dart
String? get name => getAttribute("name");
```

Both patterns exist in this repo. Prefer `getAttribute`/`setAttribute` for new code when you want built-in type coercion and concealed fields.

## Schema

`Table` and `Column` are defined in `lib/src/database/orm/schema.dart`.

```dart
Table(
  name: 'users',
  columns: [
    Column(name: 'email', type: ColumnType.string, isUnique: true),
    Column(name: 'settings', type: ColumnType.json, isNullable: true),
  ],
  indexes: [
    Index(name: 'users_email_index', columns: ['email'], isUnique: true),
  ],
)
```

If a table has no primary key column, `Table` automatically inserts a string `id` primary key column.

Supported column types are `integer`, `string`, `text`, `boolean`, `double`, `datetime`, `timestamp`, `enumeration`, and `json`.

## CRUD And Queries

`Model` and its extensions provide:

```dart
final post = await PostModel().create({
  'title': 'Hello',
  'subTitle': 'World',
});

final first = await PostModel()
    .where('title', 'Hello')
    .orderBy('created_at', desc: true)
    .first();

final page = await PostModel().paginate(1, 15);

await PostModel().update(id: post?.id, data: {'title': 'Updated'});
await PostModel().delete(post?.id);
```

`QueryBuilder.update()` and `QueryBuilder.delete()` require a where clause. `Model.update()` requires either a primary key or an existing query where clause.

## Migrations

`DBMigrateCommand` loads table definitions from `lib/config/table_registry.dart` unless tables are passed directly. The sample registry:

```dart
void main(dynamic data, SendPort? sendPort) {
  runTableRegistry([
    ...flintAiTables,
    User().table,
    PostModel().table,
  ], data, sendPort);
}
```

The migration command:

- ensures the database exists when requested
- injects missing `created_at` and `updated_at`
- injects auth provider columns for the configured auth table
- creates missing tables
- adds missing columns
- supports explicit column renames through `Column(renamedFrom: ...)`
- drops columns that are no longer declared, except protected timestamp/auth columns
- syncs declared indexes
- creates PostgreSQL `updated_at` triggers

## Important Limits

- `belongsToMany` and `hasManyThrough` relation loaders currently set empty lists; they are not implemented.
- The migration system can drop columns missing from schema definitions. Be careful when editing `Table` definitions.
- `Table` auto-adds an `id` if no primary key exists, so generated SQL may include columns not listed in your model file.
- `Model.create()` auto-generates a UUID for non-auto-increment string primary keys.
