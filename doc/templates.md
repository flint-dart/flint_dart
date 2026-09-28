# Template Engine

Flint templates are HTML files rendered by the Flint template engine. Use them
for server-rendered HTML views, email bodies, auth pages, OTP messages, invoices,
admin pages, and any server-side HTML that is not a Flint UI component.

The template engine reads `.flint.html` and `.html` files, receives a
`Map<String, dynamic>` data context, and replaces Flint template expressions
such as `{{ title }}`, `{{ if ... }}`, `{{ for ... }}`, and
`{{ include(...) }}` with rendered HTML.

Use templates when:

- the server should return normal HTML through `res.view(...)`
- a `ViewMailable` should render an email body
- a shared layout, partial, or email footer should be reused
- simple loops and conditionals are enough for the page

Use Flint UI in `lib/ui` when the page is a full frontend component experience.
Read `docs/frontend-ui.md`, `docs/ui-widgets.md`, and
`docs/build-and-rendering.md` before changing Flint UI pages.

## Files To Inspect First

Before changing templates, inspect:

- `lib/views/` for app HTML views rendered by `res.view(...)`.
- `lib/views/layouts/` for base layouts, when present.
- `lib/views/partials/` for shared HTML fragments, when present.
- `lib/mail/` for `ViewMailable` classes.
- `lib/mail/views/` for mail templates.
- `lib/routes/` and `lib/controllers/` for the data passed to `res.view(...)`.
- `lib/services/` or `lib/actions/` for data prepared before rendering.
- `docs/sessions-and-cookies.md` before using flash messages or session
  helpers.
- `docs/mail.md` before changing transactional email templates.
- `docs/testing.md` before adding template, view, or mail preview tests.

Framework source to inspect when behavior is unclear:

- `lib/src/template_engine/template.dart`
- `lib/src/template_engine/template_reader.dart`
- `lib/src/template_engine/all_expression/variables.dart`
- `lib/src/template_engine/all_expression/include.dart`
- `lib/src/template_engine/all_expression/extends.dart`
- `lib/src/template_engine/all_expression/section.dart`
- `lib/src/template_engine/all_expression/if_statement.dart`
- `lib/src/template_engine/all_expression/for_loop.dart`
- `lib/src/template_engine/all_expression/switch_cases.dart`
- `lib/src/template_engine/all_expression/assets.dart`
- `lib/src/template_engine/all_expression/session.dart`
- `lib/src/template_engine/all_expression/comment.dart`
- `lib/src/response.dart`
- `lib/src/mail/view_mailable.dart`

## Where Templates Live

Normal app views belong under `lib/views`:

```text
lib/views/
  dashboard.flint.html
  courses/
    index.flint.html
    show.flint.html
  layouts/
    app.flint.html
  partials/
    flash.flint.html
```

Mail templates belong under `lib/mail/views`:

```text
lib/mail/
  welcome_mail.dart
  otp_verification_mail.dart
  views/
    welcome.flint.html
    otp_verification.flint.html
    partials/
      footer.flint.html
```

Prefer `.flint.html` for files that use Flint syntax. Plain `.html` files can
also be rendered, but `.flint.html` makes the template language visible in the
file name.

## Rendering Views

Use `res.view(...)` from a route or controller.

File: `lib/controllers/dashboard_controller.dart`

```dart
import 'package:flint_dart/flint_dart.dart';

class DashboardController extends Controller {
  Future<Response> index() async {
    final user = req.requireUser();

    return res.view('dashboard.index', data: {
      'title': 'Dashboard',
      'user': user,
      'stats': {
        'courses': 12,
        'students': 240,
      },
    });
  }
}
```

`res.view('dashboard.index')` looks for:

```text
lib/views/dashboard/index.flint.html
lib/views/dashboard/index.html
```

If the rendered content is a partial instead of a full HTML document, Flint
wraps it in:

```html
<div id="main-content">...</div>
```

If the template is a full HTML document with `<!DOCTYPE html>` or a complete
`<html>`, `<head>`, and `<body>` structure, Flint sends it without that wrapper.

## Rendering Mail

Use `ViewMailable` for email templates. The mailable class owns the subject,
recipients, template path, and data.

File: `lib/mail/welcome_mail.dart`

```dart
import 'package:flint_dart/mail.dart';

class WelcomeMail extends ViewMailable {
  WelcomeMail({
    required this.recipientName,
    required this.recipientEmail,
  });

  final String recipientName;
  final String recipientEmail;

  @override
  String get subject => 'Welcome';

  @override
  List<String> get to => [recipientEmail];

  @override
  String get view => 'mail/views/welcome.flint.html';

  @override
  Map<String, dynamic> get data => {
        'mailTitle': subject,
        'recipientName': recipientName,
        'currentYear': DateTime.now().year,
      };
}
```

File: `lib/mail/views/welcome.flint.html`

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>{{ mailTitle }}</title>
</head>
<body>
  <h1>Hello {{ recipientName }}</h1>
  <p>Your account is ready.</p>
  <p>Copyright {{ currentYear }}</p>
</body>
</html>
```

Send it:

```dart
await WelcomeMail(
  recipientName: user.firstName,
  recipientEmail: user.email,
).send();
```

Preview it in a development route with safe demo data:

```dart
app.get('/preview/mail/welcome', (Context ctx) {
  return ctx.res?.renderEmail(
    WelcomeMail(
      recipientName: 'Preview User',
      recipientEmail: 'preview@example.com',
    ),
  );
});
```

Do not put real OTPs, tokens, passwords, customer records, or private account
data in preview routes, docs, tests, or screenshots.

## Template Path Resolution

`TemplateEngine().render(template, data)` reads a template from disk. Normal app
code usually calls it indirectly through `res.view(...)`, `ViewMailable.send()`,
`ViewMailable.queue()`, or `res.renderEmail(...)`.

The template reader tries paths in this order:

1. An absolute path, if the template name is absolute.
2. A direct path relative to the current working directory.
3. A path relative to `lib/`.
4. A logical view path under `lib/views`.
5. A logical mail view path under `lib/mail/views`.

Logical names replace dots with path separators:

```text
dashboard.index -> lib/views/dashboard/index.flint.html
emails.welcome  -> lib/views/emails/welcome.flint.html
```

For mail, the clearest path is explicit:

```dart
String get view => 'mail/views/welcome.flint.html';
```

## Rendering Pipeline

When `TemplateEngine().render(...)` runs, Flint:

1. Reads the template file.
2. Merges the provided data with `templateName`.
3. Parses child sections from the template.
4. Runs processors for extends, sections, sessions, loops, switch blocks,
   conditionals, variables, old form values, comments, assets, and includes.
5. Clears template-engine session/form state after the file render.

`renderString(...)` renders a raw string and does not read a file. Framework and
low-level tests can use it when they need to test template syntax directly.
Normal app routes should prefer `res.view(...)`.

## Interpolation With `{{ }}`

`{{ ... }}` evaluates a variable or expression and inserts the result into the
output.

Given this data:

```dart
final data = {
  'title': 'Course Dashboard',
  'user': {
    'name': 'Ada',
    'email': 'ada@example.com',
  },
  'stats': {
    'courses': 12,
    'students': 240,
  },
  'displayName': '',
  'tags': ['dart', 'backend', 'fullstack'],
};
```

Use simple variables:

```html
<h1>{{ title }}</h1>
<p>Hello {{ user.name }}</p>
<p>Email: {{ user.email }}</p>
```

Use nested map paths with dots:

```html
<p>Courses: {{ stats.courses }}</p>
<p>Students: {{ stats.students }}</p>
```

Use list indexes:

```html
<p>First tag: {{ tags[0] }}</p>
```

The template engine can also evaluate simple expressions:

```html
<p>Total: {{ stats.courses + stats.students }}</p>
<p>Has courses: {{ stats.courses > 0 }}</p>
<p>{{ user.name ?? "Guest" }}</p>
<p>{{ stats.courses > 0 ? "Ready" : "Empty" }}</p>
```

Missing variables are not a presentation strategy. Simple missing variables can
render the expression text. For customer-facing fallbacks, pass a key with an
empty string or null value, then use `default`.

```html
<p>Hello {{ displayName | default:"there" }}</p>
```

## Escaping And Safety

`{{ value }}` is interpolation, not an automatic HTML-escaping helper. If the
value came from a user, an admin form, an uploaded file name, an external API,
or any untrusted source, sanitize it before passing it to the template.

Do not do this with raw user input:

```html
<div>{{ profileHtml }}</div>
```

Instead, prefer plain text values that your server has already normalized, or
sanitize trusted HTML with an app-owned sanitizer before rendering it.

For JavaScript values, use `| json`:

```html
<script>
  const courseTags = {{ tags | json }};
</script>
```

Do not use `| raw` unless the value is trusted and intentionally safe HTML or
JavaScript.

## Filters

Filters are added with `|` after a variable or expression.

```html
<p>{{ user.name | uppercase }}</p>
<p>{{ user.email | lowercase }}</p>
<p>{{ displayName | default:"Guest" }}</p>
<p>{{ tags | join:", " }}</p>
<script>
  const stats = {{ stats | json }};
</script>
```

Supported filters:

| Filter | Use |
| --- | --- |
| `default:"value"` | Use a fallback when the value is null or empty. |
| `uppercase` | Convert the value to uppercase text. |
| `lowercase` | Convert the value to lowercase text. |
| `capitalize` | Uppercase the first character and lowercase the rest. |
| `length` | Return the length of a string, list, or map. |
| `string` | Convert the value to a string. |
| `bool` or `boolean` | Convert the value to `true` or `false`. |
| `json` | Format maps, lists, strings, numbers, booleans, and null for JavaScript/JSON contexts. |
| `join:"separator"` | Join a list into text with the separator. |
| `first` | Return the first item in a list. |
| `flatten` | Flatten nested lists. |
| `raw` | Return a string without extra formatting. Use only with trusted data. |

Filters can be chained:

```html
<p>{{ displayName | default:"guest" | capitalize }}</p>
```

## Includes

Use includes for reusable fragments such as headers, footers, flash messages,
buttons, email legal copy, and repeated cards.

```html
{{ include('partials.flash') }}
{{ include('partials.course_card', {"title": "Intro to Flint"}) }}
```

Mail example:

```html
{{ include('mail/views/partials/footer.flint.html') }}
{{ include('mail/views/partials/button.flint.html', {"label": "Open dashboard"}) }}
```

For app views under `lib/views`, prefer logical include names such as
`partials.flash`; Flint resolves that to `lib/views/partials/flash.flint.html`.
You can also use explicit paths relative to `lib`, such as
`views/partials/flash.flint.html`.

Include paths can be single-quoted or double-quoted. Include data must be valid
JSON because Flint parses it with `jsonDecode(...)`. Use double quotes around
JSON keys and string values:

```html
{{ include('partials.button', {"label": "Save", "href": "/courses"}) }}
```

The included template receives the parent data plus the JSON data passed to the
include. Include data overrides parent data with the same key.

## Extends And Layouts

Use `extends` when a page should render inside a shared layout.

File: `lib/views/layouts/app.flint.html`

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>{{ yield('title') }}</title>
  <link rel="stylesheet" href="{{ assets('assets/app.css') }}" />
</head>
<body>
  {{ include('partials.flash') }}
  <main>
    {{ yield('content') }}
  </main>
</body>
</html>
```

File: `lib/views/dashboard/index.flint.html`

```html
{{ extends('layouts.app') }}

{{ section('title', 'Dashboard') }}

{{ section('content') }}
  <h1>Welcome {{ user.name }}</h1>
  <p>You have {{ stats.courses }} courses.</p>
{{ endsection }}
```

Important layout rules:

- `extends` currently uses single quotes in the template tag.
- Put child page content inside `section(...)` blocks.
- Free HTML outside sections in a child template is not the content that the
  parent layout receives.
- Use `yield('name')` in the parent layout to place child section content.

Parent layouts can also define a default section with `show`:

```html
{{ section('sidebar') }}
  <aside>No sidebar content.</aside>
{{ show }}
```

If the child defines `section('sidebar')`, the child value is used. Otherwise,
the default content inside the parent section is used.

## Sections

Use inline sections for short values:

```html
{{ section('title', 'Course Details') }}
```

Use block sections for HTML:

```html
{{ section('content') }}
  <h1>{{ course.title }}</h1>
  <p>{{ course.description }}</p>
{{ endsection }}
```

Use `yield(...)` in the parent:

```html
<main>
  {{ yield('content') }}
</main>
```

Sections are most useful together with `extends`. Do not create many anonymous
template fragments inside one file when they should become includes.

## If, Elseif, And Else

Use `if` for conditional HTML.

```html
{{ if user.isAdmin }}
  <a href="/admin">Admin</a>
{{ endif }}
```

Use `else`:

```html
{{ if stats.courses > 0 }}
  <p>{{ stats.courses }} courses are available.</p>
{{ else }}
  <p>No courses are available yet.</p>
{{ endif }}
```

Use `elseif` for multiple conditions:

```html
{{ if status == "published" }}
  <span>Published</span>
{{ elseif status == "draft" }}
  <span>Draft</span>
{{ else }}
  <span>{{ status | default:"Unknown" }}</span>
{{ endif }}
```

Condition expressions support booleans, dot paths, numbers, arithmetic, and
comparisons:

```html
{{ if isAuthenticated }}
{{ if user.role == "admin" }}
{{ if stats.courses >= 10 }}
{{ if stats.courses + stats.students > 0 }}
```

Nested `if` blocks are supported:

```html
{{ if isAuthenticated }}
  {{ if user.isAdmin }}
    <p>Admin user</p>
  {{ endif }}
{{ endif }}
```

## For Loops

Use `for item in items` to iterate over a top-level list from the data map.

```html
<ul>
  {{ for course in courses }}
    <li>
      <a href="/courses/{{ course.id }}">{{ course.title }}</a>
      <span>{{ index }}</span>
    </li>
  {{ endfor }}
</ul>
```

Inside the loop:

- `course` is the current item.
- `index` is the zero-based index.
- Parent template data remains available.

The `item in list` loop expects the list name to be a simple top-level data key.
If the source data is nested, prepare a top-level value before rendering:

```dart
return res.view('courses.index', data: {
  'courses': courseData['items'],
});
```

Use a C-style loop when index access is clearer:

```html
{{ for i=0; i<courses.length; i++ }}
  <p>{{ i }}. {{ courses[i].title }}</p>
{{ endfor }}
```

Supported increment styles include:

```html
{{ for i=0; i<10; i++ }}
{{ for i=10; i>0; i-- }}
{{ for i=0; i<10; i+=2 }}
{{ for i=0; i<10; i=i+2 }}
```

Nested loops are supported. Keep deeply nested rendering in a controller,
presenter, or partial include when the template becomes hard to read.

## Switch

Use `switch` when one value selects one of several blocks.

```html
{{ switch status }}
  {{ case published }}
    <span class="badge badge-success">Published</span>
  {{ endcase }}

  {{ case draft,pending }}
    <span class="badge badge-warning">Draft</span>
  {{ endcase }}

  {{ default }}
    <span class="badge">Unknown</span>
  {{ enddefault }}
{{ endswitch }}
```

Switch rules:

- The switch value is read from the data map by key.
- Case values are comma-separated.
- Numeric cases are supported, such as `{{ case 1,2,3 }}`.
- For string cases, use simple unquoted values such as `published`.
- Use `default` when no case matches.

## Assets

Use `assets(...)` to create an absolute URL from `APP_URL`.

```html
<link rel="stylesheet" href="{{ assets('assets/app.css') }}" />
<script src="{{ assets('assets/app.js') }}"></script>
<img src="{{ assets('images/logo.png') }}" alt="Logo" />
```

`assets('assets/app.css')` calls Flint's `url(...)` helper and returns:

```text
<APP_URL>/assets/app.css
```

Use paths without a leading slash inside `assets(...)` to avoid double slashes
when `APP_URL` already has no trailing slash.

For generated Flint UI assets, do not hand-edit files under
`public/assets/js/flint-ui/`, `public/assets/css/flint-ui/`, or
`public/flint-sw.js`. Change `lib/ui` source and rebuild with `flint web` or
`flint build`.

## Sessions And Flash Messages

Template session helpers read `TemplateEngine().sessions`, not the full server
session from `req.session`.

Flash messages are the normal way template sessions are populated. For example:

```dart
return res.withSuccess('Course saved').redirect('/courses');
```

When the next route renders a view with `res.view(...)`, Flint reads flash
cookies, adds them to template data, adds them to template sessions, renders the
view, and clears the flash cookies.

Template usage:

```html
{{ if hasSession('success') }}
  <div class="alert alert-success">{{ session('success') }}</div>
{{ endif }}

{{ if hasSession('error') }}
  <div class="alert alert-danger">{{ session('error') }}</div>
{{ endif }}
```

`hasSession('key')` becomes `true` or `false` before `if` conditions are
evaluated. `{{ session('key') }}` renders the session value or an empty string.

For normal server session data, pass values explicitly from the controller:

```dart
final session = await req.session;

return res.view('account.index', data: {
  'displayName': session?['displayName'] ?? 'Guest',
});
```

Template:

```html
<h1>Hello {{ displayName }}</h1>
```

This keeps private server session data from being exposed to HTML by accident.

## Old Form Values

The engine supports `old('field')`, which reads from
`TemplateEngine().formData`.

```html
<input name="email" value="{{ old('email') }}" />
```

Only use this when app code intentionally places safe form values into the
template engine before rendering. It is not the same as `req.input(...)`, and it
does not automatically expose every submitted field.

For most forms, passing explicit data is clearer:

```dart
return res.view('auth.login', data: {
  'email': safeEmailValue,
});
```

```html
<input name="email" value="{{ email | default:"" }}" />
```

## Comments

Use template comments for notes that should not appear in rendered HTML.

```html
{{! Removed during variable processing }}

{{# Removed during comment processing #}}
```

Do not put secrets in comments. A template comment should still be treated like
source code because it lives in the repository.

## Template Data Shape

Keep template data simple. Prefer strings, numbers, booleans, lists, and maps
that are already safe for display.

Good data shape:

```dart
return res.view('courses.show', data: {
  'title': course.title,
  'course': {
    'id': course.id,
    'title': course.title,
    'status': course.status,
  },
  'lessons': lessons
      .map((lesson) => {
            'id': lesson.id,
            'title': lesson.title,
          })
      .toList(),
});
```

Avoid passing large model objects with private fields, tokens, password hashes,
or nested data the template does not need.

When data preparation becomes reusable, move it into a named presenter or view
model in its own file:

```text
lib/presenters/course_template_presenter.dart
```

File: `lib/presenters/course_template_presenter.dart`

```dart
class CourseTemplatePresenter {
  CourseTemplatePresenter({
    required this.course,
    required this.lessons,
  });

  final Course course;
  final List<Lesson> lessons;

  Map<String, dynamic> toMap() {
    return {
      'course': {
        'id': course.id,
        'title': course.title,
        'status': course.status,
      },
      'lessons': lessons
          .map((lesson) => {
                'id': lesson.id,
                'title': lesson.title,
              })
          .toList(),
    };
  }
}
```

The one-class-per-file rule applies here too. Do not hide reusable template data
builders inside private controller methods.

## Mail Template Patterns

Mail templates use the same engine as normal views, but email HTML has stricter
client behavior.

For mail:

- keep layout simple
- use tables or simple blocks when broad email-client support matters
- keep CSS inline or inside a small `<style>` block
- pass every dynamic value through `ViewMailable.data`
- include shared footers with `include(...)`
- use safe preview routes with fixed demo values
- never log OTPs, reset tokens, magic links, or private mail data

OTP mail should be a `ViewMailable` with data such as:

```dart
Map<String, dynamic> get data => {
      'recipientName': recipientName,
      'otp': otp,
      'expiresInMinutes': 10,
      'currentYear': DateTime.now().year,
    };
```

Template:

```html
<h1>Hello {{ recipientName }}</h1>
<p>Use this code to verify your email address.</p>
<div style="font-size:28px;font-weight:bold;">{{ otp }}</div>
<p>This code expires in {{ expiresInMinutes }} minutes.</p>
```

The OTP should come from the auth layer, be sent immediately, and not be reused
as a long-lived secret.

## Testing Templates

Read `docs/testing.md` before adding tests. Useful template tests include:

- `res.view(...)` renders the expected response body
- missing view paths return the expected status
- flash cookies become `session(...)` values
- includes render parent and child data correctly
- mail preview routes call `res.renderEmail(...)` with safe demo data
- `ViewMailable.data` contains only fields the template needs
- unsafe values are sanitized before rendering

Low-level template syntax can be tested with `TemplateEngine().renderString(...)`
from framework or package-level tests. App tests usually get better coverage
through `res.view(...)` and `res.renderEmail(...)` because those paths include
response behavior.

## Common Mistakes

- Treating `{{ value }}` as automatic HTML escaping.
- Passing an entire user, session, or model object when the template only needs
  three fields.
- Expecting `req.session` values to appear automatically through
  `session('key')`.
- Forgetting that `for item in items` expects `items` to be a top-level list.
- Using quoted string values in `switch` cases.
- Putting reusable partials inside one large template instead of extracting an
  include file.
- Editing generated Flint UI assets instead of source files under `lib/ui`.
- Putting real OTPs, customer emails, tokens, or provider secrets into preview
  routes, tests, or docs.

## Review Checklist

Before finishing template work, check:

- Views live under `lib/views` and mail templates live under `lib/mail/views`.
- `res.view(...)` uses logical view names for app pages.
- `ViewMailable.view` points to the intended mail template.
- Template data contains only safe, needed values.
- User/admin/external input is sanitized before interpolation.
- JavaScript data uses `| json`.
- Layouts use `extends`, `section`, and `yield` correctly.
- Includes receive valid JSON data when extra values are passed.
- Flash/session helpers are only used for short display messages.
- Mail preview routes use safe demo data.
- Tests cover route rendering, mail rendering, includes, sessions, and safety
  behavior when the feature depends on them.
