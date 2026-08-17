# Building A Feature

This walkthrough uses the repository's actual patterns: model, table registry, controller, route group, validation, and optional docs.

## 1. Create The Model

Use the model pattern from `example/lib/models/post_model.dart`:

```dart
import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

class Course extends Model<Course> {
  Course() : super(() => Course());

  String? get title => getAttribute<String>('title');
  String? get status => getAttribute<String>('status');

  @override
  Table get table => Table(
        name: 'courses',
        columns: [
          Column(name: 'title', type: ColumnType.string),
          Column(
            name: 'status',
            type: ColumnType.enumeration,
            options: ['draft', 'published'],
            defaultValue: 'draft',
          ),
        ],
      );
}
```

The `Table` constructor adds a string primary key `id` if none is declared.

## 2. Register The Table

Add the table to `lib/config/table_registry.dart`:

```dart
void main(dynamic data, SendPort? sendPort) {
  runTableRegistry([
    Course().table,
  ], data, sendPort);
}
```

Then run:

```bash
dart run flint_dart:flint migrate --no-interaction
```

## 3. Create The Controller

Use `(Request, Response)` methods, matching the generated controller and sample controllers:

```dart
import 'package:flint_dart/flint_dart.dart';
import '../models/course.dart';

class CourseController {
  Future<Response> index(Request req, Response res) async {
    final courses = await Course().orderBy('created_at', desc: true).get();
    return res.json({'data': courses});
  }

  Future<Response> store(Request req, Response res) async {
    final data = await req.validate({
      'title': 'required|string|min:3',
      'status': 'in:draft,published',
    });

    final course = await Course().create(data);
    return res.status(201).json({'data': course});
  }

  Future<Response> show(Request req, Response res) async {
    final course = await Course().find(req.params['id']);
    if (course == null) {
      return res.status(404).json({'message': 'Course not found'});
    }
    return res.json({'data': course});
  }
}
```

`Response.json()` sanitizes `Model` instances through `toMap()`.

## 4. Create The Route Group

```dart
import 'package:flint_dart/flint_dart.dart';
import '../controllers/course_controller.dart';

class CourseRoutes extends RouteGroup {
  @override
  String get prefix => '/courses';

  @override
  String get tag => 'Courses';

  @override
  void register(Flint app) {
    final controller = CourseController();

    /// @summary List courses
    /// @response 200 OK
    app.get('/', controller.index);

    /// @summary Create course
    /// @body {"title": "string", "status": "string"}
    app.post('/', controller.store);

    /// @summary Show course
    app.get('/:id', controller.show);
  }
}
```

Register it in `lib/main.dart`:

```dart
app.routes(CourseRoutes());
```

## 5. Add Middleware Where Needed

Use route-specific middleware for authorization:

```dart
app.post('/', controller.store).useMiddleware(AuthMiddleware());
```

Or group middleware:

```dart
class CourseRoutes extends RouteGroup {
  @override
  List<Middleware> get middlewares => [AuthMiddleware()];
}
```

## 6. Generate API Docs

```bash
dart run flint_dart:flint docs:generate
```

Start with `enableSwaggerDocs: true` to serve `/docs` and `/swagger.json`.

## Important Limits

- Add only real columns to `Table`; migration may drop columns not declared.
- Validate request data before passing maps into `create()` or `update()`.
- Avoid keeping mutable query chains around. Use `Course().resetQuery()` if reusing a model instance after a query chain.
- Do not assume many-to-many relation loading works; it currently returns empty lists.
