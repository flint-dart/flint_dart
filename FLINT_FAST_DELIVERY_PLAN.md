# Flint Fast Delivery Plan

Goal: make Flint UI pages feel fast on first load and repeat visits by sending useful HTML immediately, shipping smaller JavaScript, and caching static assets with confidence.

## 1. Server-Rendered HTML First

Today `res.page()` sends an empty mount point and the browser waits for JavaScript to paint the UI. The next major step is to let Flint render the page HTML on the server, then let the browser attach behavior after load.

### Target Behavior

`res.page('Home', props: {...})` should produce:

- Real HTML inside `<main id="app">...</main>`.
- The same `data-flint-page` payload used by the browser renderer.
- The current page bundle loaded with `defer`.
- A preload tag for the current page script.

### Design

Add a server renderer to `flint_ui`:

```dart
final html = FlintServerRenderer(componentRegistry).render(
  component: 'Home',
  props: props,
);
```

Then update `flint_dart` `Response.flintPage()` to optionally call that renderer before writing the page.

### API Shape

Start with an opt-in flag:

```dart
res.page(
  'Home',
  props: props,
  serverRender: true,
);
```

Once stable, make it the production default and allow apps to disable it:

```dart
res.page('Home', serverRender: false);
```

### Implementation Steps

1. Add a DOM-string renderer in `flint_ui` that can render existing component nodes to safe HTML.
2. Escape text and attributes in one shared utility so browser/server output stay consistent.
3. Add support for common primitives first: text, container, row/column/layout nodes, links, buttons, form fields, HTML content.
4. Mark browser-only widgets with a placeholder/fallback contract.
5. Update `Response.flintPage()` to accept an optional server-rendered body.
6. Add tests for HTML escaping, props serialization, and browser-only fallback behavior.
7. Use SSR on `flint-docs` first because docs/blog/marketing pages benefit most.

### Success Criteria

- View source shows meaningful page content.
- First paint happens before page JavaScript finishes.
- SEO crawlers can read docs content without running JavaScript.
- Existing browser hydration still receives the same component and props.

## 2. Hashed Asset Filenames

Today Flint uses query versions:

```text
/assets/js/flint-ui/pages/home.dart.js?v=1780335268500
```

The better long-term output is content-hashed filenames:

```text
/assets/js/flint-ui/pages/home.8f31c9.dart.js
```

### Target Behavior

`flint build` should write assets with hashes in their filenames and write those final URLs into `manifest.json`.

### Manifest Example

```json
{
  "mode": "page-bundles",
  "fallback": "/assets/js/flint-ui/main.a91e02.dart.js",
  "pages": {
    "Home": "/assets/js/flint-ui/pages/home.8f31c9.dart.js"
  }
}
```

### Implementation Steps

1. Compile assets to temporary filenames.
2. Compute a short content hash from each `.js`, `.css`, and `.map`.
3. Rename output files to include the hash.
4. Update source map references and `.deps` references if needed.
5. Generate `manifest.json` with hashed URLs.
6. Change `_versionedAssetUrl()` so hashed Flint assets do not need `?v=`.
7. Keep backward compatibility for non-hashed files.

### Success Criteria

- Changing a page changes only that page bundle filename.
- Static middleware can safely send `Cache-Control: public, max-age=31536000, immutable`.
- HTML no longer needs query versions for Flint build assets.

## 3. Brotli Compression

Gzip helps, but Brotli usually compresses JavaScript better. Flint should generate and serve `.br` files in production.

### Target Behavior

During `flint build`, generate:

```text
home.8f31c9.dart.js
home.8f31c9.dart.js.gz
home.8f31c9.dart.js.br
```

When the browser sends:

```http
Accept-Encoding: br, gzip
```

Flint should serve the `.br` file with:

```http
Content-Encoding: br
Vary: Accept-Encoding
```

### Implementation Steps

1. Add a build compression step after final hashed filenames are written.
2. Generate `.gz` and `.br` for JS, CSS, JSON, SVG, and maps.
3. Add Brotli support in `StaticFileMiddleware`.
4. Prefer Brotli over gzip when both are accepted.
5. Skip compression during `FLINT_HOT=1`.
6. Add tests for content encoding, content type, and cache headers.

### Success Criteria

- JS transfers are smaller than gzip when Brotli is accepted.
- Existing gzip behavior still works.
- Uncompressed fallback still works for old clients.

## 4. Shared Runtime Bundle

Page bundles reduce what each route loads, but each page still carries repeated runtime and shared component code. To get closer to Next.js/React-style delivery, Flint needs one shared runtime plus route chunks.

### Target Output

```text
/assets/js/flint-ui/runtime.4aa91c.dart.js
/assets/js/flint-ui/pages/home.8f31c9.dart.js
/assets/js/flint-ui/pages/blog.2ab44d.dart.js
```

The page HTML should load the shared runtime:

```html
<script defer src="/assets/js/flint-ui/runtime.4aa91c.dart.js"></script>
```

The runtime then loads the matching deferred chunk for the current page.

### Recommended Architecture

Dart `compile js` does not naturally split many independent entrypoints into one shared runtime bundle. The practical approach is to generate a single Flint browser shell that uses deferred imports for pages.

Generated shell:

```dart
import 'component_registry.dart';
import 'pages/home_page.dart' deferred as home;
import 'pages/blog_page.dart' deferred as blog;

Future<void> loadPage(String component) async {
  switch (component) {
    case 'Home':
      await home.loadLibrary();
      return mount(home.HomePage);
    case 'Blog':
      await blog.loadLibrary();
      return mount(blog.BlogPage);
  }
}
```

### Implementation Steps

1. Generate a deferred browser entrypoint from `component_registry.dart`.
2. Compile that one entrypoint with deferred loading enabled.
3. Emit runtime and deferred page chunks into `public/assets/js/flint-ui/`.
4. Generate a manifest that lists the runtime and deferred chunk URLs.
5. Update `Response.flintPage()` to inject the runtime script for shared-runtime manifests.
6. Update the service worker to cache the runtime immediately and prefetch route chunks in the background.
7. Keep the current independent page-bundle mode as a fallback while the deferred mode matures.

### Success Criteria

- First route loads runtime plus one page chunk.
- Navigating to another page reuses the runtime and only downloads that page chunk.
- Shared components are not duplicated in every page payload.
- Build still works for apps that do not use deferred bundle mode.

## 5. Rollout Order

### Shipped Foundation

1. Server-rendered HTML first.
   - Added Flint UI server rendering and wired `Response.flintPage()`/`res.page()` to render meaningful HTML before hydration.
   - Enabled SSR in `flint-docs` first.
2. Hashed asset filenames.
   - Build output now writes content-hashed Flint UI JS assets and keeps hashed assets free of `?v=` query versions.
3. Brotli-ready compression.
   - Build output generates gzip and can generate Brotli when `brotli` or `FLINT_BROTLI_BIN` is available.
   - Static middleware prefers Brotli, then gzip, then raw files.
4. Shared runtime bundle.
   - `flint build` now prefers a shared runtime generated from `component_registry.dart`.
   - `flint web --build-only --shared-runtime` is available for explicit local testing.
   - Deferred page chunks are content-hashed and listed in `manifest.json`.

### Production Rollout

1. Keep `flint-docs` on shared runtime first.
   - Watch `/`, `/ui`, `/guides`, and blog/detail routes for first paint, hydration, navigation, and console errors.
2. Run the same build mode in `eulogia`.
   - Confirm the generated manifest includes every component from `lib/ui/component_registry.dart`.
   - Smoke `/`, `/staff/login`, and authenticated staff/client pages.
3. Compare network behavior.
   - First visit should load SSR HTML, the runtime, and only the deferred chunks needed by the page.
   - Repeat visits should reuse cached hashed assets and service-worker-prefetched chunks.
4. Turn on Brotli in deployment images.
   - Install a Brotli binary or set `FLINT_BROTLI_BIN` so `.br` files are generated during Docker builds.
5. Keep page-bundles fallback for one release cycle.
   - If shared runtime auto-detection fails, `flint build` falls back to the older `main.dart.js` plus page-bundle flow.
6. After docs and eulogia are stable, make shared runtime the documented production path.

## 6. Compatibility Rules

- Keep `main.dart.js` fallback while page delivery evolves.
- Keep manifest versioning flexible so older apps can still load old manifests.
- Keep `FLINT_HOT=1` simple: no immutable caching, no generated compression requirement, and no service-worker registration.
- Make production defaults fast, but keep explicit flags for debugging and migration.

## 7. Validation

For every phase, test against:

- `flint_dart` unit tests.
- `flint_ui` browser rendering tests.
- `flint-docs` production build.
- `eulogia` production build.
- Live smoke checks for `/`, manifest, service worker, current page bundle, cache headers, gzip/Brotli headers, and first-load HTML.
