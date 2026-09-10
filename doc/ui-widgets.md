# UI Widgets And State

Use this guide when building Flint UI components, pages, forms, navigation,
browser state, overlays, tables, charts, or reusable frontend helpers. Flint is
fullstack, and frontend source belongs under `lib/ui`.

The most important app rule is the same on the frontend as the backend: one
meaningful reusable thing per file. A page, component, section, state holder,
form, table, chart, overlay, or helper that returns UI should have its own Dart
file.

## Files To Inspect First

Before changing UI widgets or state, inspect:

- `lib/ui/main.dart` for `createFlintApp(...)`, root design, stylesheets, and
  page registry wiring.
- `lib/ui/component_registry.dart` for `PageRegistry` entries.
- `lib/ui/pages/` for routable page components.
- `lib/ui/components/` for reusable leaf and mid-level components.
- `lib/ui/sections/` for larger page sections.
- `lib/ui/helpers/` for top-level helpers that return `View`, `Node`,
  `FlintNode`, or `FlintComponent`.
- `lib/ui/styles/` or `lib/ui/theme/` for `DartStyle`, `StyleSheet`, themes, and
  design tokens.
- `lib/ui/state/` for `StateSignal` objects, controllers, and browser-only state
  holders.
- `docs/frontend-ui.md` for the app-level frontend structure.
- `docs/build-and-rendering.md` before changing browser entrypoints, generated
  bundles, `PageRegistry`, or server rendering.
- `docs/sessions-and-cookies.md` before changing browser auth session storage or
  JavaScript-visible cookies.

## Imports

For normal browser UI files under `lib/ui`, import:

```dart
import 'package:flint_dart/ui.dart';
```

Use `flint_ui_core.dart` for tests, shared component packages, and code that
needs component primitives without browser mounting:

```dart
import 'package:flint_dart/flint_ui_core.dart';
```

Use `flint_ui_server.dart` only from server-side rendering code that needs to
render components to HTML without browser DOM helpers:

```dart
import 'package:flint_dart/flint_ui_server.dart';
```

Do not import server `Model` classes into browser UI. Use DTOs,
`FlintModelRecord`, `FlintModelApi`, `ResourceController`, or JSON maps instead.

## Core Types

`View` is the return type for component `build()` methods:

```dart
typedef View = Object?;
```

A `View` can be:

- a `FlintNode`
- a `FlintComponent`
- text, number, or another value that can become text
- an iterable of renderable values
- `null`

Flint normalizes a `View` into `FlintNode` objects before rendering.

`FlintNode` is the base render tree type. Important node classes are:

- `FlintText`: text node.
- `FlintFragment`: multiple nodes without a wrapper element.
- `FlintRawHtml`: trusted raw HTML for server rendering.
- `FlintElement`: DOM element with a tag, props, and children.
- `FlintComponentNode`: wrapper used when a component is placed in the node
  tree.

Use `View` for component returns because it lets components return raw text,
lists, fragments, elements, and other components naturally.

```dart
class WelcomeTitle extends StatelessComponent {
  WelcomeTitle(this.name);

  final String name;

  @override
  View build() {
    return Text('Welcome, $name');
  }
}
```

Use `Node` or `FlintNode` when a helper must return a normalized node.

## Components

All reusable UI classes extend `FlintComponent`. Most app components should
extend one of these:

- `StatelessComponent`: renders constructor-provided values and does not own
  lifecycle state.
- `StatefulComponent`: owns local state, a controller, a subscription, a timer,
  socket behavior, or browser-only lifecycle.

`Component` is a backwards-compatible alias for `StatefulComponent`. Use
`StatefulComponent` or `StatelessComponent` in new code so the state choice is
clear.

### Stateless Components

Use a stateless component when all inputs arrive through the constructor.

File: `lib/ui/components/course_card.dart`

```dart
import 'package:flint_dart/ui.dart';

class CourseCard extends StatelessComponent {
  CourseCard({
    required this.title,
    required this.status,
  });

  final String title;
  final String status;

  @override
  View build() {
    return Panel(
      title: title,
      child: StatusBadge(
        label: status,
        tone: status == 'published' ? Tone.success : Tone.warning,
      ),
    );
  }
}
```

### Stateful Components

Use a stateful component when the component owns values that change after the
first render.

File: `lib/ui/components/counter_button.dart`

```dart
import 'package:flint_dart/ui.dart';

class CounterButton extends StatefulComponent {
  int count = 0;

  @override
  View build() {
    return Button(
      child: 'Clicked $count times',
      onPressed: (_) {
        setState(() {
          count++;
        });
      },
    );
  }
}
```

Important lifecycle methods:

- `didMount()`: called after the component first mounts in the browser.
- `didUpdate()`: called after the component updates.
- `willUnmount()`: called before the component is removed.
- `setState(() { ... })`: mutates local state and schedules a rerender.
- `setState(() { ... }, render: false)`: mutates local state without repainting.

Use `preserveState`, `updateFrom(...)`, and `shouldUpdate(...)` only when a child
component must survive parent rerenders. If a preserved component receives
constructor values, implement `updateFrom(...)` so fields do not go stale.

```dart
class LiveCourseCounter extends StatefulComponent {
  LiveCourseCounter({required this.initialCount});

  int initialCount;
  late int count = initialCount;

  @override
  bool get preserveState => true;

  @override
  void updateFrom(covariant LiveCourseCounter next) {
    initialCount = next.initialCount;
  }

  @override
  View build() {
    return Text('Courses: $count');
  }
}
```

## One Component Per File

Do not hide reusable UI inside private page methods:

```dart
class CoursesPage extends StatelessComponent {
  @override
  View build() {
    return Column(
      children: [
        CourseHeader(),
        CourseListSection(),
      ],
    );
  }
}
```

Use this layout:

```text
lib/ui/pages/courses_page.dart
lib/ui/sections/course_list_section.dart
lib/ui/components/course_card.dart
lib/ui/components/course_status_badge.dart
lib/ui/state/course_filters.dart
```

If a method or function returns `View`, `Node`, `FlintNode`, or
`FlintComponent`, and it is not the component's own `build()` method, extract it
when it represents a named, reusable piece of UI.

Good frontend files are small and named after what they render or own. Do not
put a page, a modal, a table, and a state controller in one file just because
they are used together.

## Props, Children, And Events

Most Flint UI widgets follow the same shape:

- `child`: one child.
- `children`: many children.
- `props`: raw element attributes and event handlers.
- `className`: CSS class string.
- `style`: raw CSS-like map.
- `dartStyle`: typed `DartStyle`.

```dart
Button(
  child: 'Save',
  props: {'data-test-id': 'save-course'},
  style: {'min-width': '120px'},
  dartStyle: const DartStyle(
    margin: EdgeInsets.only(top: 12),
  ),
  onPressed: (_) {
    // Handle click.
  },
);
```

Event callbacks receive the browser event as `Object`. Use the high-level widget
callback when one exists. Use raw event access only when the component really
needs DOM-specific behavior.

## Primitive Nodes

Use the widget classes first. Use raw HTML helpers when no widget fits:

```dart
View build() {
  return div(
    props: {'className': 'course-summary'},
    children: [
      span(children: ['Total courses']),
      text('42'),
    ],
  );
}
```

Primitive helpers:

- `h(tag, props: ..., children: ...)`: creates a raw `FlintElement`.
- `text(value)`: creates `FlintText`.
- `fragment([...])`: creates `FlintFragment`.
- `component(MyComponent())`: wraps a component as a node.
- `toFlintNode(value)`: normalizes one renderable value.
- `div(...)`, `span(...)`, `button(...)`, `input(...)`: common raw element
  helpers.

Use `FlintRawHtml` only for trusted HTML. Do not render untrusted user content
as raw HTML.

## Style

Flint UI supports raw style maps and typed `DartStyle`.
When people say "Style" in Flint UI, they usually mean either the `style` map
or the typed `DartStyle`; there is no separate app component base class named
`Style` to extend.

Use `style` for direct CSS property maps:

```dart
Container(
  style: {
    'padding': '16px',
    'background': '#ffffff',
  },
  child: 'Profile',
);
```

Use `DartStyle` when you want typed values, breakpoints, state styles, theme
tokens, or reusable style composition:

```dart
Container(
  dartStyle: DartStyle(
    padding: const EdgeInsets.all(16),
    radius: 8,
    background: ThemeToken.color('surface', fallback: '#ffffff'),
    border: const Border(color: '#e4e7ec'),
    hover: DartStyle(
      shadow: Shadow(
        y: 12,
        blur: 24,
        color: Color.rgba(16, 24, 40, 0.12),
      ),
    ),
    md: const DartStyle(
      padding: EdgeInsets.all(24),
    ),
  ),
  child: 'Profile',
);
```

Useful typed style values:

- `EdgeInsets.all(...)`, `EdgeInsets.only(...)`, and
  `EdgeInsets.symmetric(...)` for spacing.
- `Px`, `Percent`, `Rem`, `Em`, `Vh`, `Vw`, `Fr`, and `SizeValue` for explicit
  CSS units.
- `GridTemplateColumns` and `GridTrack` for grid layouts.
- `Color`, `Colors`, `Gradient`, `Background`, `Border`, and `Shadow`.
- `StyleTransform`, `StyleFilter`, `StyleTransition`, and `StyleAnimation`.
- enums such as `Display`, `FlexDirection`, `AlignItems`, `JustifyContent`,
  `Position`, and `TextAlign`.

`DartStyle.merge(...)` creates a new style where non-null values from the
override replace the original. This is how widgets combine defaults, variants,
and app overrides.

## Themes, Root Design, And StyleSheets

Use `RootDesign` for app-wide document styles, tokens, themes, and keyframes.
Register it through `createFlintApp(...)`:

```dart
void main() {
  createFlintApp(
    '#app',
    registry: componentRegistry,
    rootDesign: RootDesign(
      themeProvider: const FlintThemeProvider(
        light: FlintThemes.light,
        dark: FlintThemes.dark,
        initialMode: FlintThemeMode.light,
      ),
      body: DartStyle(
        margin: EdgeInsets.zero,
        fontFamily: FontFamily.systemSans,
        background: ThemeToken.color('page', fallback: '#f8fafc'),
        color: ThemeToken.color('pageText', fallback: '#0f172a'),
      ),
    ),
  );
}
```

Use `StyleSheet` when many components need stable class names:

```dart
final courseStyles = StyleSheet('courses', {
  'card': StyleRule(
    styles: {
      'padding': 16,
      'border-radius': 8,
      'background': ThemeToken.color('surface', fallback: '#ffffff'),
    },
    hover: {'transform': 'translateY(-1px)'},
  ),
});

class CourseCard extends StatelessComponent {
  CourseCard(this.title);

  final String title;

  @override
  View build() {
    return Container(
      className: courseStyles.className('card'),
      child: Text(title),
    );
  }
}
```

Then pass the stylesheet to `createFlintApp(stylesheets: [courseStyles])`.

## Layout Widgets

Use layout widgets to describe page structure before reaching for raw
`FlintElement`.

Common primitives:

- `Text`: text content.
- `Container`: generic `div` wrapper.
- `Row`: horizontal flex.
- `Column`: vertical flex.
- `Flex`: configurable flex container.
- `Box`: low-level element with size, spacing, background, radius, and border
  shortcuts.
- `Image`, `Figure`, `Iframe`, `Link`, `Video`, `Audio`, and `MediaPreview` for
  media.
- `Canvas` and `ThreeScene` for rich interactive surfaces.

Page and layout surfaces:

- `PageShell`: centered page shell with optional nav, header, main content, and
  footer.
- `AppShell`: app layout with sidebar/topbar/main content.
- `DashboardShell`, `AuthShell`, `DocsShell`, `MarketingShell`, and
  `PortfolioShell`: opinionated page shells.
- `Section`: section with optional title, description, actions, and content.
- `Panel`: bordered content panel with optional heading.
- `PageHeader`, `Topbar`, `Sidebar`, `SidebarItem`, and `StatCard`.
- `Grid`, `ResponsiveGrid`, `Wrap`, `Stack`, `Center`, `SafeArea`,
  `ConstrainedBox`, `AspectRatioBox`, `Spacer`, `Divider`, and layout `Slider`.

Example:

```dart
class DashboardPage extends StatelessComponent {
  @override
  View build() {
    return AppShell(
      brand: 'Acme Admin',
      sidebar: Sidebar(
        items: const [
          SidebarItem(label: 'Overview', href: '/dashboard'),
          SidebarItem(label: 'Courses', href: '/courses'),
        ],
      ),
      topbar: Topbar(title: 'Dashboard'),
      child: Column(
        dartStyle: const DartStyle(gap: 20),
        children: [
          PageHeader(
            title: 'Dashboard',
            description: 'Operational overview',
            actions: Button(child: 'Refresh'),
          ),
          ResponsiveGrid(
            minItemWidth: 220,
            gap: 16,
            children: [
              StatCard(label: 'Courses', value: '42'),
              StatCard(label: 'Students', value: '1,204'),
            ],
          ),
        ],
      ),
    );
  }
}
```

## Buttons And Actions

Use `Button` for text or icon-plus-text actions:

```dart
Button(
  child: 'Create course',
  variant: ButtonVariant.solid,
  tone: Tone.primary,
  size: ComponentSize.md,
  loading: false,
  disabled: false,
  onPressed: (_) {},
);
```

Use `IconButton` for icon-only actions and always provide `label`:

```dart
IconButton(
  icon: Icons.trash,
  label: 'Delete course',
  tooltip: 'Delete course',
  tone: Tone.danger,
  onPressed: (_) {},
);
```

Use `ButtonGroup` for related actions:

```dart
ButtonGroup(
  children: [
    Button(child: 'Save'),
    Button(child: 'Cancel', variant: ButtonVariant.outline),
  ],
);
```

Shared visual enums:

- `ButtonVariant`: `solid`, `soft`, `outline`, `ghost`, and related variants.
- `Tone`: semantic color intent such as `primary`, `neutral`, `success`,
  `warning`, `danger`, and `info`.
- `ComponentSize`: `xs`, `sm`, `md`, `lg`.

Use loading and disabled states instead of manually hiding buttons during async
work.

## StateSignal

`StateSignal<T>` is a tiny reactive value. Use it when a value can change after
the first render and more than one widget or callback needs to observe it.

```dart
final activeTab = StateSignal<String>('overview');

class CourseTabs extends StatelessComponent {
  @override
  View build() {
    return StateSignalListener<String>(activeTab, (value) {
      return Tabs(
        activeKey: value,
        tabs: const [
          TabItem(key: 'overview', label: 'Overview'),
          TabItem(key: 'lessons', label: 'Lessons'),
        ],
        onChanged: (_, tab) {
          activeTab.value = tab.key;
        },
      );
    });
  }
}
```

Core operations:

- `signal.value`: read or replace the value.
- `signal.set(next)`: replace the value.
- `signal.update((current) => next)`: derive a new value from the current value.
- `signal.listen((value) { ... })`: subscribe manually.
- `signal.notify()` or `signal.notifyListeners()`: notify after mutating the
  existing object.
- `signal.dispose()`: clear listeners owned by the signal.

Prefer immutable updates for lists and maps:

```dart
messages.update((items) => [...items, newMessage]);
```

If you mutate the existing object, call `notify()`:

```dart
messages.value.add(newMessage);
messages.notify();
```

Use `StateSignalListener` around the smallest UI area that depends on the
signal. Do not rerender a full page if only one counter, table, or overlay needs
to change.

## Local Component State

Use `setState(...)` when the state is owned by one component:

```dart
class CourseFilterToggle extends StatefulComponent {
  bool open = false;

  @override
  View build() {
    return Column(
      children: [
        Button(
          child: open ? 'Hide filters' : 'Show filters',
          onPressed: (_) {
            setState(() {
              open = !open;
            });
          },
        ),
        if (open) CourseFiltersPanel(),
      ],
    );
  }
}
```

Use `StateSignal` when state is shared across components, comes from a socket or
timer, or should live outside one component instance.

## Resource State

Use `ResourceController<T>` for API-backed state. It stores a
`ResourceSnapshot<T>` inside a `StateSignal`, including status, data, error, and
updated time.

File: `lib/ui/state/courses_resource.dart`

```dart
import 'package:flint_dart/ui.dart';

final coursesResource = ResourceController<List<FlintModelRecord>>(
  loader: () {
    return FlintModelApi<FlintModelRecord>.records('/api/courses').list();
  },
);
```

File: `lib/ui/sections/course_table_section.dart`

```dart
import 'package:flint_dart/ui.dart';

import '../state/courses_resource.dart';

class CourseTableSection extends StatelessComponent {
  @override
  View build() {
    return ResourceView<List<FlintModelRecord>>(
      coursesResource,
      (snapshot) {
        if (snapshot.isLoading) return Spinner(label: 'Loading courses');
        if (snapshot.isError) return Alert(message: 'Could not load courses');

        final courses = snapshot.data ?? const <FlintModelRecord>[];
        return CoursesTable(courses: courses);
      },
    );
  }
}
```

Useful resource methods:

- `load()`: fetch fresh data and set loading state.
- `refresh(silent: true)`: refresh while keeping existing data visible.
- `setData(data)`: replace data directly.
- `mutate((current) => next)`: optimistic local update.
- `setError(error)`: move to error state.
- `dispose()`: clear listeners for owned resources.

## Forms

Use the form widgets and controllers instead of raw inputs for normal app forms.

Important pieces:

- `useForm(initialValues)`: creates a `FormController`.
- `FormController`: tracks data, errors, submit lifecycle, and text controllers.
- `TextEditingController`: mutable text value for controlled text inputs.
- `FormErrors`: normalizes validation error payloads and field messages.
- `Form`: semantic form container with submit handling.
- `TextField`, `TextArea`, `Select`, `Checkbox`, `Switch`, `SwitchRow`,
  `RadioGroup`, `FileInput`, `DatePicker`, `DateRangePicker`, `CodeEditor`, and
  `RichTextEditor`.

File: `lib/ui/components/signup_form.dart`

```dart
import 'package:flint_dart/ui.dart';

import '../services/signup_action.dart';

class SignupForm extends StatefulComponent {
  final form = useForm({
    'email': '',
    'password': '',
    'role': 'student',
    'terms': false,
  });

  late final FlintVoidCallback refresh = () {
    setState(() {});
  };

  @override
  void didMount() {
    form.addListener(refresh);
  }

  @override
  void willUnmount() {
    form.removeListener(refresh);
  }

  @override
  View build() {
    return Form(
      loading: form.processing,
      onSubmit: (event) {
        (event as dynamic).preventDefault();
        form.submit(
          SignupAction().call,
          resetOnSuccess: true,
          onSuccess: (_) {
            toast.success('Account created');
          },
        );
      },
      children: [
        TextField(
          label: 'Email',
          name: 'email',
          controller: form.controller('email'),
          errors: form.errors,
          required: true,
        ),
        TextField(
          label: 'Password',
          name: 'password',
          type: 'password',
          controller: form.controller('password'),
          errors: form.errors,
          required: true,
        ),
        Select(
          label: 'Role',
          name: 'role',
          value: form['role'],
          options: const [
            SelectOption(label: 'Student', value: 'student'),
            SelectOption(label: 'Instructor', value: 'instructor'),
          ],
          onChanged: (event) {
            final value = (event as dynamic).target.value;
            form.setField('role', value);
          },
        ),
        Checkbox(
          label: 'I accept the terms',
          name: 'terms',
          checked: form['terms'] == true,
          errors: form.errors,
          onChanged: (event) {
            final checked = (event as dynamic).target.checked == true;
            form.setField('terms', checked);
          },
        ),
        Button(
          child: 'Create account',
          props: {'type': 'submit'},
          loading: form.processing,
        ),
      ],
    );
  }
}
```

`FormController.submit(...)` sets `processing`, clears previous errors, runs the
action, updates success flags, captures validation error payloads, and notifies
listeners.

Use `errors: form.errors` on fields so backend validation maps back to the
correct input by `name`.

## Navigation

Use browser navigation helpers from `package:flint_dart/ui.dart`:

```dart
navigate('/courses');
replace('/courses?page=2');
back();
forward();
go(-2);
reload();
```

Current location helpers:

```dart
final path = currentPath;
final queryString = currentQuery;
final hash = currentHash;
final uri = currentUri;
```

Use `query` for current URL query string state:

```dart
final page = int.tryParse(query.get('page') ?? '1') ?? 1;

query.update({
  'page': page + 1,
  'status': 'published',
});

query.remove('status');
query.clear();
```

Use `push: true` when the change should create a new browser history entry:

```dart
query.set('tab', 'lessons', push: true);
```

Navigation widgets:

- `Tabs` and `TabItem` for local tab selection.
- `Pagination` for paged datasets.
- `Breadcrumbs` and `BreadcrumbItem` for hierarchy.
- `SearchBox` for search forms.
- `Link` for normal anchors.
- `Sidebar`, `SidebarItem`, and `Topbar` for app navigation surfaces.

Example:

```dart
Tabs(
  activeKey: query.get('tab') ?? 'overview',
  tabs: const [
    TabItem(key: 'overview', label: 'Overview'),
    TabItem(key: 'lessons', label: 'Lessons'),
  ],
  onChanged: (_, tab) {
    query.set('tab', tab.key, push: true);
  },
);
```

## Browser Storage

Flint UI browser storage is different from backend `Storage` for uploaded files.
In `lib/ui`, storage means browser key/value storage and cookies.

Use `localStorage` for persistent browser values:

```dart
localStorage.write('courses.view', 'grid');
final view = localStorage.read('courses.view');

localStorage.writeJson('courses.filters', {'status': 'published'});
final filters = localStorage.readMap('courses.filters');
```

Use `sessionStorage` for values that should disappear when the browser session
ends:

```dart
sessionStorage.write('wizard.step', 'billing');
sessionStorage.remove('wizard.step');
```

Shared storage methods:

- `read(key)`
- `write(key, value)`
- `has(key)`
- `readJson(key)`
- `readMap(key)`
- `writeJson(key, value)`
- `remove(key)`
- `clear()`

Use `cookies` for JavaScript-visible browser cookies:

```dart
cookies.write(
  'theme',
  'dark',
  maxAge: const Duration(days: 30),
  sameSite: CookieSameSite.lax,
  secure: true,
);

final theme = cookies.read('theme');
cookies.remove('theme');
```

Use `authSession` only for simple browser-side auth state:

```dart
authSession.save(
  token: token,
  user: {'id': userId, 'role': role},
);

final loggedIn = authSession.isLoggedIn;
final role = authSession.role;
final current = authSession.current;

authSession.updateUser({'id': userId, 'role': 'admin'});
authSession.clear();
```

Security rule: JavaScript-visible browser storage can be read by JavaScript. Do
not store secrets there when the app requires HTTP-only cookie protection. Read
`docs/sessions-and-cookies.md` before deciding where auth state belongs.

## Overlays

Use controlled overlay widgets for UI that appears above the page:

- `Modal`: centered dialog.
- `Drawer`: side panel.
- `Popover`: floating panel attached to a trigger.
- `Tooltip`: hover/focus hint around a child.
- `Toast`: renderable notification surface.
- `toast`: browser toast service with `info`, `success`, `warning`, and `error`.
- `Skeleton`: loading placeholder.
- `ConfirmAction`: confirmation modal with action buttons.

Closed `Modal`, `Drawer`, and `Popover` instances unmount their content instead
of leaving hidden interactive DOM around.

```dart
class DeleteCourseButton extends StatefulComponent {
  bool confirming = false;

  @override
  View build() {
    return fragment([
      Button(
        child: 'Delete',
        tone: Tone.danger,
        onPressed: (_) {
          setState(() {
            confirming = true;
          });
        },
      ),
      ConfirmAction(
        open: confirming,
        title: 'Delete course',
        message: 'This action cannot be undone.',
        danger: true,
        onCancel: (_) {
          setState(() {
            confirming = false;
          });
        },
        onConfirm: (_) {
          setState(() {
            confirming = false;
          });
          toast.success('Course deleted');
        },
      ),
    ]);
  }
}
```

Use `Modal` or `Drawer` for interaction, `Popover` for lightweight contextual
panels, `Tooltip` for labels and hints, and `toast` for short-lived feedback.

## Tables And Data Display

Use `Table` for explicit table rows and custom cells:

```dart
Table(
  columns: const [
    TableColumn(key: 'title', label: 'Title'),
    TableColumn(key: 'status', label: 'Status'),
  ],
  rows: [
    TableRowData(
      key: course.id.toString(),
      cells: {
        'title': course['title'],
        'status': StatusBadge(label: course['status'].toString()),
      },
      actions: Button(child: 'Edit'),
    ),
  ],
  onRowClick: (_, row) {
    navigate('/courses/${row.key}');
  },
);
```

Use `DataTable` when you want default loading and empty states:

```dart
DataTable(
  columns: const [
    TableColumn(key: 'name', label: 'Name'),
    TableColumn(key: 'role', label: 'Role'),
  ],
  rows: userRows,
  loading: usersResource.snapshot.isLoading,
);
```

Other data display widgets:

- `Avatar`: image or initials.
- `DescriptionList` and `DescriptionItem`: `dt`/`dd` details.
- `ProgressBar`: accessible progress value.
- `UsageMeter`: label, numeric usage, and progress bar.
- `Timeline` and `TimelineItem`: ordered activity events.
- `StatusBadge`: compact status label.
- `Alert`: important feedback block.
- `Spinner`: accessible loading indicator.

Keep table row mapping in its own file when it becomes reusable.

File: `lib/ui/helpers/course_table_rows.dart`

```dart
import 'package:flint_dart/ui.dart';

List<TableRowData> courseTableRows(List<FlintModelRecord> courses) {
  return [
    for (final course in courses)
      TableRowData(
        key: course.id?.toString(),
        cells: {
          'title': course.string('title') ?? '',
          'status': StatusBadge(label: course.string('status') ?? 'draft'),
        },
      ),
  ];
}
```

## Charts

Use `LineChart` for trends over an ordered label series:

```dart
LineChart(
  labels: const ['Jan', 'Feb', 'Mar'],
  series: const [
    LineChartSeries(
      label: 'Revenue',
      data: [1200, 1800, 1500],
      strokeColor: '#2563eb',
      fillColor: 'rgba(37, 99, 235, 0.10)',
    ),
  ],
  height: 220,
);
```

Use `BarChart` for category comparisons:

```dart
BarChart(
  labels: const ['Draft', 'Published', 'Archived'],
  series: const [
    BarChartSeries(
      label: 'Courses',
      data: [8, 32, 4],
      barColor: '#079455',
    ),
  ],
  height: 220,
);
```

Both chart widgets render SVG nodes. Keep chart data preparation in a separate
state, service, or helper file when the mapping is more than a couple of lines.

## Forms, Data, And Tables Together

A normal searchable table feature should be split by responsibility:

```text
lib/ui/pages/courses_page.dart
lib/ui/sections/course_filters_section.dart
lib/ui/sections/course_table_section.dart
lib/ui/components/course_status_badge.dart
lib/ui/helpers/course_table_rows.dart
lib/ui/state/course_filters.dart
lib/ui/state/courses_resource.dart
```

The page composes sections. The filters own filter input state. The resource
loads data. The table section renders `DataTable`. Reusable badges and row
mapping are separate files.

## Browser-Only APIs And SSR

Some UI APIs are browser-specific:

- `createFlintApp(...)`
- `navigate`, `replace`, `back`, `forward`, `go`, `reload`
- `query`
- `localStorage`, `sessionStorage`, and `cookies`
- `toast`
- browser-backed rich components such as canvas, media preview, terminal, and
  rich text editor

Flint provides stubs for many browser APIs so shared code can compile in server
or test environments, but app behavior that depends on DOM, history, or browser
storage should still live in browser UI files under `lib/ui`.

Read `docs/build-and-rendering.md` before changing `flint build`, `flint web`,
browser entrypoints, generated bundles, page-level bundles, `PageRegistry`, or
SSR.

## Common Mistakes

- Putting multiple components, pages, sections, state holders, or reusable UI
  helpers in one Dart file.
- Adding private `_buildHeader()`, `_buildCard()`, or `_tableRows()` methods
  instead of extracting named components or helpers into their own files.
- Importing server `Model` classes into browser UI.
- Using `StatefulComponent` when `StatelessComponent` is enough.
- Using `setState(...)` for shared state that should be a `StateSignal`.
- Making a whole page listen to a signal when only one small section needs to
  rerender.
- Storing sensitive auth data in JavaScript-visible browser storage without
  checking the session/cookie docs.
- Using raw `FlintElement` for common controls that already exist as widgets.
- Forgetting accessible labels on `IconButton`, `SearchBox`, overlays, and form
  fields.
- Editing generated files under `public/assets/js/flint-ui/` instead of source
  files under `lib/ui`.

## Review Checklist

When reviewing a Flint UI change:

1. Read `docs/frontend-ui.md`, `docs/ui-widgets.md`, and
   `docs/build-and-rendering.md`.
2. Confirm every reusable component, page, section, state holder, and UI helper
   has its own file.
3. Confirm `build()` returns `View`.
4. Confirm `StatelessComponent` is used for presentational widgets and
   `StatefulComponent` only where state or lifecycle is needed.
5. Confirm forms use `FormController`, `TextEditingController`, and
   `FormErrors` when validation and submit state matter.
6. Confirm buttons use `Button`, `IconButton`, and `ButtonGroup` instead of raw
   button elements unless a lower-level element is needed.
7. Confirm tables use `Table`, `DataTable`, `TableColumn`, and `TableRowData`
   for tabular data.
8. Confirm navigation uses `navigate(...)`, `replace(...)`, `query`, and the
   navigation widgets where appropriate.
9. Confirm browser storage is intentional and does not hold secrets that should
   be HTTP-only.
10. Confirm generated browser bundles are rebuilt through `flint web` or
    `flint build` after source changes.
