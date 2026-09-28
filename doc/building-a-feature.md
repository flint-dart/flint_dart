# Building A Feature

This walkthrough uses the repository's actual patterns: model, table registry, controller, route group, validation, and optional docs.

## One Reusable Thing Per File

In developer apps, every class must live in its own Dart file. This rule applies
to backend and frontend code. Do this for models, controllers, routes,
middleware, services, actions, mail classes, DTOs, policies, validators,
exceptions, queue jobs, isolate tasks, Flint UI pages, UI components, sections,
state holders, and small helper classes.

The file name should match the class responsibility in snake_case:

- `Course` -> `lib/models/course.dart`
- `CourseController` -> `lib/controllers/course_controller.dart`
- `CourseRoutes` -> `lib/routes/course_routes.dart`
- `CreateCourseAction` -> `lib/services/courses/create_course_action.dart`
- `PublishCourseJob` -> `lib/jobs/publish_course_job.dart`
- `GenerateCourseReportTask` -> `lib/isolate/tasks/generate_course_report_task.dart`
- `CourseCreatedMail` -> `lib/mail/course_created_mail.dart`
- `CoursesPage` -> `lib/ui/pages/courses_page.dart`
- `CourseCard` -> `lib/ui/components/course_card.dart`
- `CourseListSection` -> `lib/ui/sections/course_list_section.dart`
- `CourseStatusBadge` -> `lib/ui/components/course_status_badge.dart`
- `courseEmptyState` -> `lib/ui/helpers/course_empty_state.dart`

Do not add a second class, component, section, or reusable helper to an existing
file because it feels small. Create a new file with the class or helper name
instead.

Do not hide feature behavior inside private helper methods such as:

```dart
void _sendOtp() {}
Future<void> _createInvoice() async {}
Map<String, dynamic> _buildPayload() => {};
View _courseCard(Course course) => Card(child: Text(course.title ?? ''));
FlintNode _emptyState() => EmptyState(title: 'No courses');
```

If a controller, route, model, middleware, mail class, queue job, isolate task,
service, page, component, or section starts needing `_someThing()` helpers,
extract that behavior into a named class, component, or top-level function in
its own file. Controllers should validate the request and shape the response.
Service/action classes should own business workflows. Queue jobs should own
durable background work. Isolate tasks should own CPU-heavy or blocking work.
Mail classes should own email rendering and delivery data. Middleware classes
should own request guards. Models should own persistence shape and light model
behavior. Flint UI pages should compose components. Components and sections
should own reusable UI blocks.

The component's own `build()` method stays in its component file. Any additional
method or function that returns `FlintComponent`, `FlintNode`, `Node`, or `View`
should become a standalone component or helper file when it represents a UI
piece.

Prefer this shape:

```dart
class CreateCourseAction {
  Future<Course> call(Map<String, dynamic> data) async {
    final course = await Course().create(data);
    if (course == null) {
      throw Exception('Course could not be created');
    }
    return course;
  }
}
```

Then the controller stays small:

```dart
final course = await CreateCourseAction().call(data);
return res.status(201).json({'data': course});
```

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

For app features, create a request-scoped controller by extending `Controller`.
Flint binds the current `Context` before each action runs, so controller methods
do not receive legacy two-argument HTTP parameters. Use `context` directly
when you need the full request context, or use the `req` and `res` shortcuts for
HTTP actions.

```dart
import 'package:flint_dart/flint_dart.dart';
import '../models/course.dart';

class CourseController extends Controller {
  Future<Response> index() async {
    final courses = await Course().orderBy('created_at', desc: true).get();
    return res.json({'data': courses});
  }

  Future<Response> store() async {
    final data = await req.validate({
      'title': 'required|string|min:3',
      'status': 'in:draft,published',
    });

    final course = await Course().create(data);
    return res.status(201).json({'data': course});
  }

  Future<Response> show() async {
    final course = await Course().find(req.params['id']);
    if (course == null) {
      return res.status(404).json({'message': 'Course not found'});
    }
    return res.json({'data': course});
  }
}
```

The response instance method `res.json(...)` sanitizes `Model` instances through `toMap()`.

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
    final courses = app.controller(CourseController.new);

    /// @summary List courses
    /// @response 200 OK
    courses.get('/', (controller) => controller.index());

    /// @summary Create course
    /// @body {"title": "string", "status": "string"}
    courses.post('/', (controller) => controller.store());

    /// @summary Show course
    courses.get('/:id', (controller) => controller.show());
  }
}
```

`app.controller(CourseController.new)` creates a route builder that instantiates,
binds, and unbinds a fresh controller for each request. Use this style for
advanced apps because controller state remains request-scoped and the route file
stays explicit about which controller owns each action.

Register it in `lib/main.dart`:

```dart
app.routes(CourseRoutes());
```

## 5. Add Middleware Where Needed

Use route-specific middleware for authorization:

```dart
courses
    .post('/', (controller) => controller.store())
    .useMiddleware(AuthMiddleware());
```

Or group middleware:

```dart
class CourseRoutes extends RouteGroup {
  @override
  List<Middleware> get middlewares => [AuthMiddleware()];
}
```

## 6. Add Frontend UI When Needed

If the feature has a screen, add Flint UI source under `lib/ui`. Keep the page
thin and extract each reusable UI piece into its own file.

```text
lib/ui/pages/courses_page.dart
lib/ui/sections/course_list_section.dart
lib/ui/components/course_card.dart
lib/ui/helpers/course_empty_state.dart
```

Page:

```dart
import 'package:flint_dart/ui.dart';

import '../sections/course_list_section.dart';

class CoursesPage extends StatelessComponent {
  CoursesPage(this.props);

  final Map<String, dynamic> props;

  @override
  View build() {
    return PageShell(
      header: PageHeader(title: props['title']?.toString() ?? 'Courses'),
      child: CourseListSection(),
    );
  }
}
```

Section:

```dart
import 'package:flint_dart/ui.dart';

import '../components/course_card.dart';

class CourseListSection extends StatelessComponent {
  @override
  View build() {
    return ResponsiveGrid(
      minItemWidth: 240,
      gap: 16,
      children: [
        CourseCard(title: 'Intro to Dart', status: 'published'),
        CourseCard(title: 'Advanced APIs', status: 'draft'),
      ],
    );
  }
}
```

Do not add `_courseCard()`, `_courseList()`, or `_statusBadge()` methods inside
`CoursesPage`. If a method or function returns `FlintComponent`, `FlintNode`,
`Node`, or `View` and represents a UI piece, create a standalone file for it.

## 7. Generate API Docs

```bash
dart run flint_dart:flint --docs-generate
```

Start with `enableSwaggerDocs: true` to serve `/docs` and `/swagger.json`.

## Important Limits

- Add only real columns to `Table`; migration may drop columns not declared.
- Validate request data before passing maps into `create()` or `update()`.
- Avoid keeping mutable query chains around. Use `Course().resetQuery()` if reusing a model instance after a query chain.
- Do not assume many-to-many relation loading works; it currently returns empty lists.
