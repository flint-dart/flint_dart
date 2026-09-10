# Build And Rendering

Flint has two build surfaces:

- The server app, built by `flint build` into a production executable.
- The Flint UI browser app, built by `flint web` into JavaScript, CSS, a page
  manifest, and optional page bundles under the static web directory.

Keep those two surfaces connected but separate. Server routes decide what page
to send. Flint UI source under `lib/ui` decides how that page renders in the
browser and, when SSR is enabled, how the first HTML is rendered on the server.

## Files To Inspect First

Before changing build, browser UI, SSR, or page rendering behavior, inspect:

- `lib/main.dart` for `Flint(...)`, `serverRenderFlintPages`,
  `flintPageServerRenderer`, static asset setup, route registration, and
  `listen(...)`.
- `lib/routes/` and `lib/controllers/` for routes that return `res.page(...)`.
- `lib/ui/main.dart` for `createFlintApp(...)`, the page registry, root design,
  stylesheets, app theme, and page middleware.
- `lib/ui/component_registry.dart`, `lib/ui/registry.dart`, or
  `lib/ui/page_registry.dart` for `PageRegistry`.
- `lib/ui/pages/` for routable page components.
- `lib/ui/components/`, `lib/ui/sections/`, `lib/ui/helpers/`,
  `lib/ui/styles/`, and `lib/ui/state/` for shared frontend pieces.
- `flint_ui.yaml` when the app uses explicit page bundle config.
- `public/assets/js/flint-ui/`, `public/assets/css/flint-ui/`, and
  `public/flint-sw.js` only as generated output.

## Source And Output

The normal fullstack layout is:

```text
lib/
  main.dart
  routes/
  controllers/
  ui/
    main.dart
    component_registry.dart
    pages/
    components/
    sections/
    helpers/
    styles/
    state/
public/
  assets/
    js/
      flint-ui/
    css/
      flint-ui/
```

The source is under `lib/ui`. The generated browser output is under
`public/assets/js/flint-ui/` and `public/assets/css/flint-ui/`. Do not edit the
generated output by hand. Change source files and run `flint web` or
`flint build`.

The one-file rule applies here too. Every page, component, section, state holder,
root design, and reusable function that returns `View`, `Node`, `FlintNode`, or
`FlintComponent` belongs in its own file.

## Import Choices

Use the entrypoint that matches the code you are writing:

```dart
import 'package:flint_dart/flint_dart.dart';
```

Use this in backend app code: `lib/main.dart`, routes, controllers, middleware,
models, jobs, services, and other server-side files.

```dart
import 'package:flint_dart/ui.dart';
```

Use this in normal app frontend files under `lib/ui`. It is the concise Flint UI
entrypoint and exports the browser app APIs.

```dart
import 'package:flint_dart/flint_ui.dart';
```

Use this when a file is explicitly a browser mounting entrypoint and you want
the longer, descriptive name. It exports the core UI APIs plus
`createFlintApp(...)`, browser rendering, page registry helpers, and browser
stylesheet registration.

```dart
import 'package:flint_dart/flint_ui_core.dart';
```

Use this for shared component packages, tests, and lower-level code that needs
Flint UI primitives without directly mounting a browser app. It exports
components, nodes, styles, state signals, navigation/storage abstractions, data
resources, and widgets.

```dart
import 'package:flint_dart/flint_ui_server.dart';
```

Use this from server-only rendering code. It exports `FlintServerRenderer` and
the UI primitives needed to render Flint components to HTML strings without
browser DOM mounting behavior.

Do not use the deprecated `flint_web_ui.dart` or `flint_web_core.dart`
entrypoints in new code. Use `ui.dart`, `flint_ui.dart`,
`flint_ui_core.dart`, or `flint_ui_server.dart`.

## Browser Entrypoint

The main browser entrypoint is usually `lib/ui/main.dart`:

```dart
import 'package:flint_dart/ui.dart';

import 'component_registry.dart';
import 'styles/app_root_design.dart';

void main() {
  createFlintApp(
    '#app',
    registry: componentRegistry,
    rootDesign: appRootDesign,
  );
}
```

`createFlintApp(...)` mounts into the element selected by `#app`. Flint server
page responses create that element as:

```html
<main id="app" data-flint-page="..."></main>
```

The browser entrypoint reads the `data-flint-page` payload, looks up the named
page in the registry, and renders that page into the host element.

`createFlintApp(...)` can receive:

- `registry`: a `PageRegistry` containing normal page mappings.
- `pages`: an inline page map, mainly useful for generated page bundles.
- `resolvePage`: an async resolver, used by shared-runtime builds with deferred
  page imports.
- `middlewares`: page middleware that can inspect or stop browser page mounting.
- `stylesheets`: `StyleSheet` objects to register before render.
- `theme`, `themeProvider`, or `themeMode`: global theme setup.
- `rootDesign`: a `RootDesign` containing app-level styles, theme, and
  keyframes.
- `missingPage`: fallback component for an unknown page name.

## Page Registry

Routable Flint UI pages are registered by name:

```dart
import 'package:flint_dart/ui.dart';

import 'pages/dashboard_page.dart';
import 'pages/course_show_page.dart';

final componentRegistry = PageRegistry({
  'Dashboard': (props) => DashboardPage(props),
  'CourseShow': (props) => CourseShowPage(props),
});
```

The registry key is the server-to-browser contract. If the server sends
`res.page('Dashboard')`, the browser registry must contain `Dashboard`.

Keep each page in its own file:

```text
lib/ui/pages/dashboard_page.dart
lib/ui/pages/course_show_page.dart
```

A page component usually accepts `Map<String, dynamic> props` from the server:

```dart
import 'package:flint_dart/ui.dart';

class CourseShowPage extends StatelessComponent {
  CourseShowPage(this.props);

  final Map<String, dynamic> props;

  @override
  View build() {
    final course = props['course'] as Map<String, dynamic>? ?? const {};

    return Column(
      children: [
        Text.h1(course['title']?.toString() ?? 'Course'),
      ],
    );
  }
}
```

Do not put page class implementations inside the registry file. The registry
file maps names; the page classes live in `lib/ui/pages`.

## Returning Pages From Routes

Server routes return Flint UI pages with the response object:

```dart
import 'package:flint_dart/flint_dart.dart';

class DashboardRoutes extends RouteGroup {
  @override
  void register(Flint app) {
    app.get('/dashboard', (Context ctx) async {
      final res = ctx.res!;

      return res.page(
        'Dashboard',
        props: {
          'title': 'Dashboard',
          'stats': {'courses': 12, 'students': 240},
        },
        title: 'Dashboard',
      );
    });
  }
}
```

`res.page(...)` is the preferred page response helper. It delegates to Flint's
page response renderer, writes an HTML document, embeds the page payload,
resolves the JavaScript asset, includes stylesheets, and closes the response.

Useful options:

- `props`: JSON-safe data passed to the page constructor.
- `rootId`: host element ID. The default is `app`, matching `#app`.
- `script`: explicit browser script URL. If omitted, Flint resolves it from the
  generated manifest or default asset paths.
- `stylesheets`: explicit stylesheet URLs. If omitted, Flint uses generated
  Flint UI CSS when it exists.
- `preloadScript`: whether to add a script preload link. Defaults to `true`.
- `title`: simple page title.
- `meta`: `FlintPageMeta` for description, canonical URL, Open Graph, Twitter,
  icons, robots, and structured data.
- `serverHtml`: explicit initial HTML string for the page body.
- `serverRender`: per-response override for server rendering.
- `status`: status code for the HTML response.

Pass data that can be serialized safely. Flint page responses normalize common
values such as `DateTime`, `Uri`, enums, `Model` objects, maps, lists, and
objects with `toJson()` or `toMap()`.

## Server Rendering

Server rendering is optional. By default, `res.page(...)` sends a host element
with the page payload and lets the browser bundle render the UI. When SSR is
enabled, Flint inserts initial HTML into the host element before the browser
bundle loads.

A server renderer is a function with this shape:

```dart
String? Function(String component, Map<String, dynamic> props)
```

Use `FlintServerRenderer` from `flint_ui_server.dart` to render registered pages:

```dart
import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/flint_ui_server.dart';

import 'ui/component_registry.dart';

final flintServerRenderer = const FlintServerRenderer();

String? renderFlintPage(String component, Map<String, dynamic> props) {
  return flintServerRenderer.renderPage(
    componentRegistry,
    component,
    props: props,
  );
}

void main(List<String> args) {
  final app = Flint(
    flintPageServerRenderer: renderFlintPage,
    serverRenderFlintPages: true,
  );

  app.get('/dashboard', (Context ctx) {
    return ctx.res!.page('Dashboard', props: {'title': 'Dashboard'});
  });

  app.listen(port: 3000);
}
```

When `serverRenderFlintPages` is `true`, `res.page(...)` calls the renderer for
each page response unless the response overrides it with `serverRender: false`.
When it is `false`, a response can still opt in with `serverRender: true`.

```dart
return res.page(
  'MarketingHome',
  props: {'headline': 'Start today'},
  serverRender: true,
);
```

Use `serverHtml` when a route already has trusted initial HTML and should bypass
the configured page renderer for that response:

```dart
return res.page(
  'InvoicePreview',
  serverHtml: invoiceHtml,
  props: {'invoiceId': invoiceId},
);
```

SSR should render deterministic HTML from props. Avoid reading browser-only
state during server render. Event handlers are for the browser mount; the server
renderer skips function event props and renders HTML attributes, text, elements,
fragments, and components.

## Browser Navigation

The browser app is still backed by server routes. When navigation helpers emit a
Flint navigation event or the user moves through browser history, the browser
entrypoint fetches the current URL, parses the next HTML response, reads the new
`data-flint-page` payload, updates the document title, and renders the next
registered page without a full document replacement.

That means each navigable page still needs a server route that returns
`res.page(...)`. Do not build frontend-only routes that the server cannot answer
unless the app intentionally serves a separate static SPA.

## `flint web`

`flint web` builds Flint UI browser assets. Unless `--build-only` is passed, it
also serves the static web directory locally.

```bash
dart run flint_dart:flint web
dart run flint_dart:flint web --port 3000
dart run flint_dart:flint web --entry lib/ui/main.dart --web-dir public
dart run flint_dart:flint web --out public/assets/js/flint-ui/main.dart.js
dart run flint_dart:flint web --build-only
dart run flint_dart:flint web --build-only --page-bundles
dart run flint_dart:flint web --build-only --no-page-bundles
dart run flint_dart:flint web --build-only --shared-runtime
dart run flint_dart:flint web --build-only --page Dashboard
```

Important options:

- `--entry <path>` chooses the Dart browser entry file.
- `--web-dir <path>` chooses the static web root.
- `--out <path>` chooses the JavaScript output file.
- `--page-bundles` builds one bundle per registered page. This is the default.
- `--no-page-bundles` builds only one global JavaScript bundle.
- `--shared-runtime` builds one shared runtime and deferred page chunks.
- `--no-shared-runtime` disables shared runtime mode.
- `--pages-config <path>` chooses an explicit page bundle config file.
- `--page <name>` builds one page bundle by component name.
- `--port <number>` chooses the local static server port. The default is
  `8080`.
- `--build-only` compiles without starting the static server.

`flint web` compiles Dart to JavaScript with `dart compile js`.

## Entrypoint And Static Directory Detection

When `--entry` is not passed, Flint looks for browser entrypoints in this order:

```text
lib/ui/main.dart
flint_ui/main.dart
flint_ui/flint_ui/main.dart
lib/flint_ui/main.dart
example/flint_ui/flint_ui/main.dart
web/main.dart
flint_ui/web/main.dart
lib/web/main.dart
example/flint_ui/web/main.dart
```

When `--web-dir` is not passed, Flint resolves the static directory like this:

- For `lib/ui/main.dart`, prefer `public/` when it exists.
- For an entry inside a `flint_ui` directory, try sibling `web/`, then sibling
  `public/`.
- Otherwise try root `web/`, then root `public/`.
- If no static directory exists, use the entrypoint's directory.

For the normal fullstack layout, the default JavaScript output is:

```text
public/assets/js/flint-ui/main.dart.js
```

The build hashes the final JavaScript filename, so production output looks like:

```text
public/assets/js/flint-ui/main.abcdef123456.dart.js
```

Generated CSS goes to:

```text
public/assets/css/flint-ui/style.css
```

CSS may be created from a root design, from Tailwind input, or both. Tailwind
input is auto-detected at `lib/ui/tailwind.css` or
`lib/ui/styles/tailwind.css`. If Tailwind input exists, Flint looks for the
Tailwind standalone binary on `PATH` or at `FLINT_TAILWIND_BIN`.

Set `FLINT_WEB_UI_VERBOSE=1`, `true`, or `yes` for verbose web build logs.

## Page Bundles

Page bundles are the default because they let each route load the smallest page
script Flint can resolve.

Flint discovers page bundle config from:

- `flint_ui.yaml`, when present or when passed through `--pages-config`.
- `lib/ui/component_registry.dart`.
- `lib/ui/registry.dart`.
- `lib/ui/page_registry.dart`.

Auto-discovery works best when registry entries directly construct page classes:

```dart
final componentRegistry = PageRegistry({
  'Dashboard': (props) => DashboardPage(props),
  'CourseShow': (props) => CourseShowPage(props),
});
```

Flint reads the page imports, class names, registry variable name, and root
design from `lib/ui/main.dart` when possible. It then generates temporary
entrypoints under `.dart_tool/flint_ui/page_bundles/` and compiles each page to:

```text
public/assets/js/flint-ui/pages/dashboard.<hash>.dart.js
public/assets/js/flint-ui/pages/course_show.<hash>.dart.js
```

The generated manifest maps page names to scripts:

```json
{
  "mode": "page-bundles",
  "fallback": "/assets/js/flint-ui/main.abcdef123456.dart.js",
  "pages": {
    "Dashboard": "/assets/js/flint-ui/pages/dashboard.123456abcdef.dart.js"
  }
}
```

Use `--page Dashboard` during development when one page bundle needs to be
rebuilt quickly.

## Explicit `flint_ui.yaml`

Use `flint_ui.yaml` when auto-discovery cannot understand the registry shape or
when the app wants stable page bundle slugs:

```yaml
flint_ui:
  registry_import: package:my_app/ui/component_registry.dart
  registry: componentRegistry
  root_design_import: package:my_app/ui/styles/app_root_design.dart
  root_design: appRootDesign
pages:
  Dashboard: dashboard
  CourseShow: course_show
```

Fields:

- `registry_import`: package import for the registry file.
- `registry`: registry variable name. Defaults to `componentRegistry`.
- `root_design_import`: package import for the root design file.
- `root_design`: root design variable name.
- `pages`: map of page component names to output slugs.

The `pages` keys must match the names sent by `res.page(...)`.

## Shared Runtime

`--shared-runtime` builds one runtime script with deferred page imports instead
of one independent bundle per page:

```bash
dart run flint_dart:flint web --build-only --shared-runtime
```

The output includes:

```text
public/assets/js/flint-ui/runtime.<hash>.dart.js
public/assets/js/flint-ui/runtime.dart.js_*.part.js
public/assets/js/flint-ui/manifest.json
```

The shared-runtime manifest uses the runtime script for every page and lists the
deferred chunks:

```json
{
  "mode": "shared-runtime",
  "runtime": "/assets/js/flint-ui/runtime.abcdef123456.dart.js",
  "fallback": "/assets/js/flint-ui/runtime.abcdef123456.dart.js",
  "chunks": ["/assets/js/flint-ui/runtime.dart.js_1.part.js"],
  "pages": {
    "Dashboard": "/assets/js/flint-ui/runtime.abcdef123456.dart.js"
  }
}
```

Use shared runtime when many pages share a lot of code and deferred loading is a
better fit than fully separate page scripts. Use page bundles when the app wants
route-level script isolation and simple per-page cache behavior.

## Single Bundle

`--no-page-bundles` builds only the main browser bundle:

```bash
dart run flint_dart:flint web --build-only --no-page-bundles
```

Use this for small apps, prototypes, or apps where one global script is simpler
than page-level bundle management.

Without a manifest page match, `res.page(...)` falls back to the default script
resolution and loads the main bundle.

## Generated Assets

A normal production web build may write:

```text
public/assets/js/flint-ui/main.<hash>.dart.js
public/assets/js/flint-ui/main.<hash>.dart.js.map
public/assets/js/flint-ui/main.<hash>.dart.js.deps
public/assets/js/flint-ui/main.<hash>.dart.js.gz
public/assets/js/flint-ui/main.<hash>.dart.js.br
public/assets/js/flint-ui/pages/<page>.<hash>.dart.js
public/assets/js/flint-ui/manifest.json
public/assets/js/flint-ui/manifest.json.gz
public/assets/js/flint-ui/manifest.json.br
public/assets/css/flint-ui/style.css
public/assets/css/flint-ui/style.css.gz
public/assets/css/flint-ui/style.css.br
public/flint-sw.js
public/flint-sw.js.gz
public/flint-sw.js.br
```

`.br` files are only created when a Brotli binary is available. Flint always
tries gzip for useful asset types unless `FLINT_HOT=1`.

`public/flint-sw.js` registers a cache named for the build time. It cache-first
serves Flint UI JS/CSS assets and the manifest, and it prefetches manifest
assets after the page asks it to handle `FLINT_PREFETCH`. Service worker output
is skipped from the page response while `FLINT_HOT=1`.

## Script Resolution In Page Responses

When a route returns `res.page(...)`, Flint resolves the browser script in this
order:

1. Use the explicit `script:` option when provided.
2. Read `public/assets/js/flint-ui/manifest.json` and use the script mapped to
   the requested page when the file exists.
3. During hot reload with `FLINT_HOT=1`, try to build the missing page bundle on
   demand. The response uses a temporary build overlay and reloads shortly after.
4. Use the manifest fallback script when it exists.
5. Use the newest app-owned `public/assets/js/flint-ui/main.<hash>.dart.js` or
   `main.dart.js` when found.
6. Fall back to older layouts such as `/web/main.dart.js` or `/main.dart.js`.

Hashed Flint UI asset URLs are not query-versioned. Unhashed local asset URLs
can receive a `?v=<modified-time>` query so browsers refresh after rebuilds.

## `flint build`

`flint build` prepares the production server output in `build/`:

```bash
dart run flint_dart:flint build
dart run flint_dart:flint build --entry lib/main.dart
dart run flint_dart:flint build --platform linux
dart run flint_dart:flint build --linux
dart run flint_dart:flint build --windows
dart run flint_dart:flint build --macos
dart run flint_dart:flint build --both
```

Behavior:

- Remove the previous `build/` directory.
- Build Flint UI assets when a browser entrypoint exists.
- Read the app name from `pubspec.yaml`.
- Copy non-Dart app resources into `build/`.
- Copy `docs/swagger.json` or root `swagger.json` into
  `build/public/swagger.json` and `build/public/docs/swagger.json` when present.
- Copy Swagger UI assets when they are available.
- Precompress files under `build/public`.
- Compile the server entrypoint with `dart compile exe`.
- Create `start.sh` for Linux/macOS outputs and `start.bat` for Windows output.
- Create a Dockerfile only when a Linux executable was built.

Entrypoint resolution:

- `--entry <path>` uses the given server entrypoint.
- Without `--entry`, Flint checks `bin/server.dart`, `bin/main.dart`, then
  `lib/main.dart`.

Platform resolution:

- Without a platform option, Flint builds for the current host OS.
- `--platform linux`, `--platform windows`, and `--platform macos` choose one
  target.
- `--both` builds Linux and Windows outputs.
- `--linux`, `--windows`, and `--macos` are shortcuts.

Use `flint web --build-only` when you only need browser assets. Use
`flint build` when you need the production server executable and copied static
assets. Read `docs/deployment.md` before wiring the built output into Docker,
process managers, migrations, static file hosting, or jobs workers.

## Development Flow

For normal backend and fullstack development:

```bash
dart run flint_dart:flint run --port=3000
```

`flint run` starts the hot reload worker by default. If hot reload is disabled
with `FLINT_HOT=0` or `FLINT_HOT=false`, it builds Flint UI assets first unless
`--no-web-build` is passed.

For only browser UI assets:

```bash
dart run flint_dart:flint web --build-only
```

For production:

```bash
dart run flint_dart:flint build --linux
```

## Metadata And Styles

Use `FlintPageMeta` when the HTML page needs SEO or preview metadata:

```dart
return res.page(
  'CourseShow',
  props: {'course': course},
  meta: const FlintPageMeta(
    title: 'Course Details',
    description: 'View course lessons, progress, and enrollment options.',
    canonicalUrl: 'https://example.com/courses/intro',
    imageUrl: 'https://example.com/images/course-preview.png',
    siteName: 'Course App',
  ),
);
```

`res.page(...)` includes default viewport and charset tags, page title, optional
description, canonical link, icons, Open Graph tags, Twitter tags, custom meta
maps, JSON-LD structured data, stylesheet links, and script preloads.

Generated Flint UI CSS is included automatically when
`public/assets/css/flint-ui/style.css` exists. Pass `stylesheets:` when a route
needs extra CSS or a custom asset path.

## What Not To Do

- Do not edit files under `public/assets/js/flint-ui/` by hand.
- Do not let the server send `res.page('Dashboard')` unless the browser registry
  has a `Dashboard` page.
- Do not keep browser-only APIs in code that must SSR on the server.
- Do not put several pages or components in one file just because they are
  small.
- Do not create private reusable UI methods like `_buildHeader()` inside page
  classes. Make a component, section, or helper file.
- Do not use deprecated `flint_web_ui.dart` or `flint_web_core.dart` imports in
  new code.
- Do not assume `flint web` watches files. It builds and optionally serves the
  static directory.

## Review Checklist

Before finishing a build, UI, or SSR change:

1. The server route returns `res.page(...)` with the correct page name.
2. The page name exists in `PageRegistry`.
3. `lib/ui/main.dart` imports the registry and calls `createFlintApp('#app',
   ...)`.
4. UI source files use `package:flint_dart/ui.dart`.
5. Server-only renderer files use `package:flint_dart/flint_ui_server.dart`.
6. Reusable pages, components, sections, root designs, and UI helpers each have
   their own file.
7. Generated assets under `public/assets/js/flint-ui/` are not hand-edited.
8. `flint web --build-only` succeeds after frontend changes.
9. `flint build` succeeds before production packaging.
10. SSR pages do not depend on browser-only state during initial render.
