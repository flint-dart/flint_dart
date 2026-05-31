# Page-Level Flint UI Bundles Plan

## Goal

Make Flint UI pages load fast by compiling and serving only the JavaScript needed for the requested page.

Today, a Flint full-stack app usually ships one browser bundle:

```text
public/assets/js/flint-ui/main.dart.js
```

That means a public landing page can download staff dashboards, mail workspaces, admin tools, support panels, and every other registered page before anything appears. The server HTML responds quickly, but the browser waits for a large app bundle before Flint UI can paint.

The framework should make this automatic:

```dart
return res.page('Home');
```

should prefer:

```html
<script defer src="/assets/js/flint-ui/pages/home.dart.js"></script>
```

while still falling back to the existing global bundle when a page bundle is not available.

## Desired Developer Experience

App code should stay simple.

```dart
app.get('/', (req, res) {
  return res.page('Home');
});
```

No route should need to manually know the script path. Flint should discover the best bundle from build metadata.

The CLI should support:

```bash
flint web --build-only
```

and produce:

```text
public/assets/js/flint-ui/main.dart.js
public/assets/js/flint-ui/manifest.json
public/assets/js/flint-ui/pages/home.dart.js
public/assets/js/flint-ui/pages/products.dart.js
public/assets/js/flint-ui/pages/staff_dashboard.dart.js
```

The manifest maps component names to assets:

```json
{
  "mode": "page-bundles",
  "fallback": "/assets/js/flint-ui/main.dart.js",
  "pages": {
    "Home": "/assets/js/flint-ui/pages/home.dart.js",
    "Products": "/assets/js/flint-ui/pages/products.dart.js",
    "StaffDashboard": "/assets/js/flint-ui/pages/staff_dashboard.dart.js"
  }
}
```

## Architecture

### Flint Dart Responsibilities

Flint Dart owns the CLI and HTML response path.

- Extend `flint web --build-only` to build page-level bundles.
- Generate a `manifest.json` beside the browser assets.
- Teach `Response.flintPage()` / `Response.page()` to look up the component in the manifest.
- Keep compatibility with the existing `script:` override.
- Keep compatibility with the existing global bundle.
- Add production-friendly static asset headers for generated JS bundles.

### Flint UI Responsibilities

Flint UI owns browser runtime bootstrapping.

- Allow generated entrypoints to mount one known component.
- Keep the existing registry-based `main.dart` flow.
- Provide a tiny page-entry bootstrap API that accepts:
  - root selector
  - component name
  - component factory or filtered registry
  - root design
- Ensure page bundles still read the same `data-flint-page` payload.

## Build Strategy

### Phase 1: Manifest-Based Script Selection

Add manifest support first without changing compilation.

`Response.flintPage()` checks:

```text
public/assets/js/flint-ui/manifest.json
```

If the manifest contains the requested component, use that script. Otherwise use:

```text
/assets/js/flint-ui/main.dart.js
```

Rules:

- If `script:` is passed explicitly, use it and skip manifest lookup.
- If manifest is missing, use the existing default script behavior.
- If component is missing from manifest, use the manifest fallback or the existing default script.
- Version the selected script with the current asset versioning helper.

This phase is safe because it does not require page bundle compilation yet.

### Phase 2: Page Entrypoint Generation

Generate temporary Dart entry files for each registered page.

Example generated file:

```dart
import 'package:flint_ui/flint_ui.dart';
import 'package:my_app/ui/component_registry.dart';
import 'package:my_app/ui/components/root_design.dart';

void main() {
  createFlintApp(
    '#app',
    registry: componentRegistry.only(['Home']),
    rootDesign: appRootDesign,
  );
}
```

Output:

```text
.dart_tool/flint_ui/pages/home.dart
public/assets/js/flint-ui/pages/home.dart.js
```

The first implementation can compile each page independently with:

```bash
dart compile js .dart_tool/flint_ui/pages/home.dart -O2 -o public/assets/js/flint-ui/pages/home.dart.js
```

This is simple and reliable, though repeated shared runtime code may exist in each page bundle.

### Phase 3: Registry Metadata

The CLI needs to know which pages exist.

Preferred approach:

```dart
final componentRegistry = FlintComponentRegistry({
  'Home': (props) => HomePage(props),
  'Products': (props) => ProductsPage(props),
});
```

Add a build-time metadata helper so the CLI can discover page names without fragile source parsing.

Options:

- Add a `flint_ui.yaml` config file listing public pages.
- Add a generated `component_registry.manifest.json`.
- Add an optional `pages:` list to the registry declaration.
- Start with explicit config, then later automate discovery.

Recommended first version:

```yaml
flint_ui:
  entry: lib/ui/main.dart
  registry: lib/ui/component_registry.dart
  root_design: lib/ui/components/root_design.dart
  pages:
    Home: home
    Products: products
    ProductDetail: product_detail
    StaffDashboard: staff_dashboard
```

This avoids brittle Dart parsing and gives developers control over which pages are public bundle targets.

### Phase 4: Production Asset Middleware

Generated assets should be served with the right headers.

For hashed or versioned JS assets:

```http
Cache-Control: public, max-age=31536000, immutable
Content-Encoding: gzip
Vary: Accept-Encoding
```

The current default static middleware bypasses cache for `.js`, `.css`, and `.map`. That is good for development but expensive in production.

Add one of these:

- `StaticFileMiddleware.production()`
- `StaticFileMiddleware(cacheJs: true, gzip: true)`
- A dedicated `FlintAssetMiddleware` for `/assets/js/flint-ui/*`

Recommended:

```dart
app.use(FlintAssetMiddleware.production());
```

Then `Flint(withDefaultMiddleware: true)` can use production headers when:

```text
FLINT_ENV=production
```

## Backward Compatibility

Do not break existing apps.

Existing apps using:

```dart
return res.page('Home', script: '/custom/main.dart.js');
```

must keep working.

Existing apps with only:

```text
public/assets/js/flint-ui/main.dart.js
```

must keep working.

Apps can adopt page bundles gradually:

```bash
flint web --build-only --page-bundles
```

Later, page bundles can become the production default.

## CLI Shape

Initial commands:

```bash
flint web --build-only
flint web --build-only --page-bundles
flint web --build-only --page Home
```

Future commands:

```bash
flint web manifest
flint web analyze-bundles
```

Useful output:

```text
Flint UI bundles generated:
- Home              184 KB raw, 42 KB gzip
- Products          238 KB raw, 55 KB gzip
- StaffDashboard    510 KB raw, 118 KB gzip
- fallback main     1.4 MB raw, 211 KB gzip
```

## Server Runtime Lookup

Pseudo-code for `Response.flintPage()`:

```dart
final resolvedScript = script ??
    _scriptForFlintComponent(component) ??
    _defaultFlintPageScript();
```

Pseudo-code for manifest lookup:

```dart
String? _scriptForFlintComponent(String component) {
  final manifest = _loadFlintUiManifest();
  if (manifest == null) return null;
  final pages = manifest['pages'];
  if (pages is Map && pages[component] is String) {
    return pages[component] as String;
  }
  final fallback = manifest['fallback'];
  return fallback is String ? fallback : null;
}
```

Manifest loading should be cached in memory and invalidated when the manifest file modified time changes.

## Risks

### Repeated Runtime Code

Independent page compilation may duplicate shared Flint UI runtime code across bundles.

This is acceptable for phase 1 because first-page load improves dramatically. Later we can explore shared chunks if Dart JS tooling gives us a stable path.

### Registry Discovery

Automatic discovery from Dart source can become fragile. Start with an explicit config file or generated manifest.

### Route-To-Component Mismatch

The server knows component names, not route names. That is good. The page bundle lookup should key by component name because `res.page('Home')` is the stable contract.

### Development Ergonomics

Compiling every page during development may be slow. Development should keep the single global bundle by default unless `--page-bundles` is requested.

## Implementation Checklist

1. Add manifest lookup to `Response.flintPage()`.
2. Add tests for:
   - explicit `script:` wins
   - manifest component script is used
   - manifest fallback is used
   - old global bundle fallback still works
3. Add `flint_ui.yaml` support for page bundle config.
4. Add CLI page entrypoint generation.
5. Add `--page-bundles` to `flint web --build-only`.
6. Generate `manifest.json`.
7. Add production asset middleware or production mode to static middleware.
8. Update Flint docs.
9. Test on Eulogia:
   - Home page loads only `home.dart.js`
   - Staff pages load their own bundles
   - cache headers are production-safe
   - gzip is enabled
10. Publish as a Flint Dart and Flint UI minor release.

## Success Metrics

For Eulogia home page:

- JS transfer size should drop from about `1.41 MB` raw to a much smaller page bundle.
- Gzip transfer should be under `100 KB` for the public home page target if possible.
- Repeat visits should reuse cached assets.
- HTML response should remain fast.
- First visible paint should no longer wait on the whole staff/admin application bundle.

## Recommended Release Path

Ship this as an opt-in minor release first:

```bash
flint web --build-only --page-bundles
```

Then, after Eulogia and Flint Docs prove it in production, make page bundles the default for production builds while keeping the single bundle as the development default.
