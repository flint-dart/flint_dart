# Frontend UI

Flint is fullstack. Backend app code usually lives in `lib/controllers`,
`lib/routes`, `lib/models`, and services. Frontend app code lives in `lib/ui`.

Use Flint UI from:

```dart
import 'package:flint_dart/ui.dart';
```

## Files To Inspect First

Before changing frontend code, inspect:

- `lib/ui/main.dart` for `createFlintApp(...)`, the page registry, and optional root design.
- `lib/ui/component_registry.dart` for routable pages.
- `lib/ui/pages/` for page components.
- `lib/ui/components/` for shared UI components.
- `lib/ui/sections/` for larger page sections.
- `lib/ui/styles/` or `lib/ui/theme/` if the app has local style helpers.
- `docs/ui-widgets.md` before changing `FlintComponent`, `StatefulComponent`,
  `StatelessComponent`, `FlintNode`, `View`, forms, buttons, state, overlays,
  tables, charts, browser storage, or navigation.
- `docs/sessions-and-cookies.md` before changing browser auth session storage or JavaScript-visible cookies.
- `docs/build-and-rendering.md` before changing browser entrypoints, `PageRegistry`, generated bundles, or SSR.
- `public/assets/js/flint-ui/` only as generated output.

## One UI Thing Per File

The one-class-per-file rule applies to frontend code too. Every `FlintComponent`,
`StatefulComponent`, `StatelessComponent`, page, section, layout, state holder,
controller-like UI helper, and reusable view helper belongs in its own Dart file.

The component's own `build()` method stays in that component file. Any other
method or function that returns `FlintComponent`, `FlintNode`, `Node`, or `View`
should be extracted into a standalone file when it represents a reusable piece
of UI.

Do not grow a page with private UI builders like this:

```dart
class CoursesPage extends StatelessComponent {
  @override
  View build() {
    return PageShell(
      header: _header(),
      child: _courseList(),
    );
  }

  View _header() => PageHeader(title: 'Courses');

  View _courseList() => Column(children: [
        _courseCard('Intro to Dart'),
        _courseCard('Advanced APIs'),
      ]);

  View _courseCard(String title) => Card(child: Text(title));
}
```

Instead, create focused files:

```text
lib/ui/pages/courses_page.dart
lib/ui/components/course_header.dart
lib/ui/sections/course_list_section.dart
lib/ui/components/course_card.dart
lib/ui/components/course_status_badge.dart
```

Then compose them:

```dart
class CoursesPage extends StatelessComponent {
  @override
  View build() {
    return PageShell(
      header: CourseHeader(),
      child: CourseListSection(),
    );
  }
}
```

## Components

Read `docs/ui-widgets.md` for the full widget and state reference: core UI
types, `DartStyle`, layouts, forms, buttons, overlays, tables, charts, browser
storage, and navigation.

Use `StatelessComponent` when the component only renders constructor-provided
values:

```dart
class CourseCard extends StatelessComponent {
  CourseCard({required this.title, required this.status});

  final String title;
  final String status;

  @override
  View build() {
    return Card(
      child: Column(
        children: [
          Text.strong(title),
          CourseStatusBadge(status),
        ],
      ),
    );
  }
}
```

Use `StatefulComponent` only when the component owns local state, lifecycle,
subscriptions, controllers, sockets, timers, or browser-only behavior.

## UI Helper Functions

Prefer components for anything with layout, props, state, or repeated behavior.
For very small pure helpers, use a top-level function in its own file:

```dart
View courseEmptyState() {
  return EmptyState(
    title: 'No courses',
    description: 'Create a course to get started.',
  );
}
```

Do not leave reusable `View`, `Node`, or `FlintNode` helper functions buried
inside a page or component file. If it can be named, reused, tested, or changed
independently, give it a file.

## Page Registry

Routable pages are registered in `lib/ui/component_registry.dart`:

```dart
final componentRegistry = PageRegistry({
  'Courses': (props) => CoursesPage(props),
});
```

Keep each page class in `lib/ui/pages/<name>_page.dart`. Put shared pieces under
`lib/ui/components/` or `lib/ui/sections/` and import them into the page.
Read `docs/build-and-rendering.md` before changing the browser entrypoint,
bundle mode, `flint_ui.yaml`, page response script resolution, or SSR.

## Browser Session State

Flint UI exposes `authSession` for simple browser-side auth state. It stores a
token and user payload in browser storage, not in the server `FLINTSESSID`
session.

```dart
authSession.save(
  token: token,
  user: {'id': userId, 'role': role},
);

final loggedIn = authSession.isLoggedIn;
final role = authSession.role;

authSession.clear();
```

Read `docs/sessions-and-cookies.md` before deciding whether auth state belongs
in server sessions, HTTP-only cookies, `localStorage`, `sessionStorage`, or
JavaScript-visible browser cookies.

## Commands

Use the UI generators when starting new frontend files:

```bash
dart run flint_dart:flint --make-ui --page Courses
dart run flint_dart:flint --make-ui --component CourseCard
dart run flint_dart:flint --make-ui --section CourseList
dart run flint_dart:flint --make-ui --root-design
dart run flint_dart:flint web
```

The older `make:ui` alias is deprecated and will be removed in Flint Dart
`1.5.0`; use `--make-ui` in new examples and generated guidance.

## Frontend Checklist

When working on frontend code:

1. Read `docs/frontend-ui.md`, `docs/ui-widgets.md`, `docs/build-and-rendering.md`, `docs/project-structure.md`, and any local design notes.
2. Inspect `lib/ui/main.dart` and `lib/ui/component_registry.dart`.
3. Find the page in `lib/ui/pages/`.
4. Move repeated UI into `lib/ui/components/`, `lib/ui/sections/`, or a focused helper file.
5. Do not add private `_buildSomething()` methods for UI blocks.
6. Do not edit generated files under `public/assets/js/flint-ui/` by hand.

## Important Limits

- `public/assets/js/flint-ui/` is generated output. Change source files under `lib/ui`.
- Keep one component, one page, one section, or one reusable UI helper per file.
- `build()` returns `View`; extracted helpers that also return `View`, `Node`, `FlintNode`, or `FlintComponent` should live in their own file.
- Use `docs/ui-widgets.md` for `StateSignal`, `FormController`, buttons,
  layouts, overlays, tables, charts, storage, and navigation.
- Use `package:flint_dart/ui.dart` for frontend code, not the server-only entrypoint.
