# Flint Dart — Framework Improvement Tracker

> Track what has been implemented, what's in progress, and what's pending.
> Each item links to the exact source file and line range it targets.

---

## Legend
- ⬜ **Pending** — Not started
- 🔄 **In Progress** — Being worked on
- ✅ **Done** — Implemented and tested

---

## Improvements

### 🔴 High Impact

#### 1. ✅ Full DOM Wipe on Every Root Render
- **File:** `lib/src/ui/browser_renderer.dart` — `FlintRoot._paint()`
- **Status:** **Completed & Verified**
- **Problem:** `host.textContent = ''` was nuking the entire DOM tree on every root render, then rebuilding from scratch.
- **Fix Applied:** Replaced full DOM wipe with `host.replaceChild(nextDom, firstChild)` if existing root DOM exists, or `host.appendChild(nextDom)` on initial mount. Preserves browser-managed state (scroll position, selections, inputs) outside changed subtrees.

```dart
// Implemented in FlintRoot._paint:
final nextDom = _createDom(node, '0', previousSlots, nextSlots);
final firstChild =
    host.childNodes.length > 0 ? host.childNodes.item(0) : null;
if (firstChild != null) {
  host.replaceChild(nextDom, firstChild);
} else {
  host.appendChild(nextDom);
}
_restoreActiveControl(activeControl, host);
```

---

#### 2. ✅ Serial Page Bundle Compilation (No Parallelism)
- **File:** `lib/src/cli/web_ui_builder.dart` — `compilePageBundles()`
- **Status:** **Completed & Verified**
- **Problem:** Each page bundle was compiled sequentially via `await` inside a `for` loop, causing builds to scale linearly and leaving multi-core CPUs idle.
- **Fix Applied:** Extracted single-page compilation into `_compileOnePage` and used `Future.wait(...)` to compile all requested page bundles concurrently.

```dart
// Implemented in compilePageBundles:
final pageEntries = await Future.wait([
  for (final entry in requestedPages.entries)
    _compileOnePage(
      component: entry.key,
      slug: entry.value,
      config: config,
      build: build,
      generatedDir: generatedDir,
      pagesOutDir: pagesOutDir,
      compress: onlyPage == null,
    ),
]);
manifestPages.addEntries(pageEntries);
```

---

### 🟡 Medium Impact

#### 3. ✅ Serial Asset Compression Within Each Family
- **File:** `lib/src/cli/web_ui_builder.dart` — `_compressAssetFamily()`
- **Status:** **Completed & Verified**
- **Problem:** Gzip and Brotli compression ran sequentially for each file (`.js`, `.map`, `.deps`) in an asset family.
- **Fix Applied:** Converted to `await Future.wait(files.map(_compressAssetIfUseful))` to compress all bundle artifacts simultaneously.

```dart
// Implemented:
static Future<void> _compressAssetFamily(String jsPath) async {
  final files = [
    File(jsPath),
    File('$jsPath.map'),
    File('$jsPath.deps'),
  ];
  await Future.wait(files.map(_compressAssetIfUseful));
}
```

---

#### 4. ✅ JS Bundle Read Twice During Hash + Source Map Rewrite
- **File:** `lib/src/cli/web_ui_builder.dart` — `_hashDartJsAssetFamily()`
- **Status:** **Completed & Verified**
- **Problem:** The compiled JavaScript file was read twice: once via `readAsBytesSync()` for SHA-256 calculation and again via `readAsStringSync()` for source-map rewriting.
- **Fix Applied:** Now reads once via `readAsBytesSync()`, derives the SHA-256 checksum, and decodes the in-memory bytes using `utf8.decode(bytes)` for source map rewriting.

```dart
// Implemented:
final bytes = jsFile.readAsBytesSync();
final hash = sha256.convert(bytes).toString().substring(0, 12);
// ...
var js = utf8.decode(bytes);
js = _rewriteSourceMapUrl(js, sourceMapName);
```

---

#### 5. ✅ DOM Query for Scoped Style Deduplication on Every Render
- **File:** `lib/src/ui/browser_renderer.dart` — `_registerScopedStyle()`
- **Status:** **Completed & Verified**
- **Problem:** Every component with scoped styling queried the document DOM using `querySelector('style[data-flint-style-id="..."]')` to prevent duplicate tags.
- **Fix Applied:** Added `final _registeredStyleIds = <String>{};` to `FlintRoot`. The check is now an $O(1)$ memory lookup, completely removing redundant DOM queries during UI rendering.

```dart
// Implemented in FlintRoot:
final _registeredStyleIds = <String>{};

void _registerScopedStyle(String cssText) {
  if (cssText.trim().isEmpty) return;
  final id = 'flint-style-${cssText.hashCode}';
  if (_registeredStyleIds.contains(id)) return;
  _registeredStyleIds.add(id);
  // ... inject <style> into head
}
```

---

#### 6. ✅ CSS Extraction Spawns a Separate Dart VM Process
- **File:** `lib/src/cli/web_ui_builder.dart` — `_compileRootDesignCss()`
- **Status:** **Completed & Verified**
- **Problem:** Spawning `dart run` to extract root design CSS on every build added a cold VM startup penalty even if styling hadn't changed.
- **Fix Applied:** Added `_latestMtimeInDir(build.uiDir)`. If the target CSS file already exists and is newer than all `.dart` and `.yaml` files in the UI directory, extraction is skipped.

```dart
// Implemented:
final cssOutput = File(build.cssOut!);
if (cssOutput.existsSync()) {
  final cssModified = cssOutput.lastModifiedSync();
  final sourceModified = _latestMtimeInDir(build.uiDir);
  if (sourceModified != null && cssModified.isAfter(sourceModified)) {
    _logVerbose('Root design CSS is up-to-date; skipping extraction.');
    return;
  }
}
```

---

#### 7. ✅ Focus Restored 3× Per Render Cycle
- **File:** `lib/src/ui/browser_renderer.dart` — `_restoreActiveControl()`
- **Status:** **Completed & Verified**
- **Problem:** Every render triggered synchronous restore, microtask restore, and `Timer.run()` restore unconditionally, causing layout queries.
- **Fix Applied:** `_ActiveControl.restore()` now returns `bool`. If the immediate synchronous restore succeeds, no extra microtasks or timers are scheduled.

```dart
// Implemented:
void _restoreActiveControl(_ActiveControl? activeControl, web.Element scope) {
  if (activeControl == null) return;
  final restored = activeControl.restore(scope);
  if (!restored) {
    scheduleMicrotask(() => activeControl.restore(scope));
  }
}
```

---

### 🟢 Low Impact / DX

#### 8. ✅ `StyleSheet.cssText` Not Memoized
- **File:** `lib/src/ui/style/stylesheet.dart` — `StyleSheet.cssText`
- **Status:** **Completed & Verified**
- **Problem:** `cssText` dynamically recalculated all CSS rule mappings and state selectors every time it was accessed on an immutable `StyleSheet`.
- **Fix Applied:** Created `final _stylesheetCssTextCache = Expando<String>();` to memoize the compiled CSS string per instance without breaking `const StyleSheet` constructors.

```dart
// Implemented:
final _stylesheetCssTextCache = Expando<String>();

class StyleSheet {
  // ...
  String get cssText => _stylesheetCssTextCache[this] ??= _compileCssText();
```

---

#### 9. ✅ Service Worker Prefetch Uses a Fixed 12-Second Delay
- **File:** `lib/src/cli/web_ui_builder.dart` — `_serviceWorkerSource()`
- **Status:** **Completed & Verified**
- **Problem:** Hardcoded `setTimeout(resolve, 12000)` caused the service worker to delay cache prefetching by 12 seconds, resulting in cache misses on early navigation.
- **Fix Applied:** Removed the artificial 12s delay so page prefetching begins immediately upon receiving `FLINT_PREFETCH`.

```javascript
// Implemented in SW template:
if (event.data && event.data.type === 'FLINT_PREFETCH') {
  event.waitUntil((async () => {
    await flintCacheUrls(await flintManifestAssets());
  })());
}
```

---

#### 10. ✅ Incremental Watch Mode for `flint web`
- **File:** `lib/src/cli/web_ui_command.dart`
- **Status:** **Completed & Verified**
- **Problem:** Developing UI required running a full build on every edit with no watch or incremental compilation support.
- **Fix Applied:** Added `--watch` mode to `flint web`. It watches `lib/ui/` for changes, identifies the modified page via component registry targets, and triggers `compilePageBundles(build, onlyPage: changedPage)` with debouncing, rebuilding only what changed in seconds.

```bash
# Usage:
flint web --watch
```

---

## Phase 2 — Architectural & Performance Backlog

### 🔴 High Impact

#### 11. ✅ Component Subtree Wiped on Every `setState()` (VDOM Diffing & In-Place Reconciliation)
- **File:** `lib/src/ui/browser_renderer.dart` — `_renderComponent()`, `_reconcileNode()`, `_reconcileChildren()`
- **Status:** **Completed & Verified**
- **Problem:** When any component updated state, `mount.boundary.textContent = '';` completely nuked the DOM subtree and rebuilt from scratch. This caused modals to flash/blink from `opacity: 0` by restarting CSS animations, reset scroll positions, and dropped input focus/caret.
- **Fix Applied:** Implemented in-place virtual DOM reconciliation (`_reconcileNode`, `_reconcileChildren`, `_patchProps`). Existing DOM nodes are preserved across `setState()` calls; only modified attributes, text values, and child list deltas are patched in place.

```dart
// Implemented in _renderComponent:
if (oldNode is FlintFragment && nextNode is FlintFragment && mount.mounted) {
  _reconcileChildren(mount.boundary, oldNode.children, nextNode.children, 'c', previousSlots, nextSlots);
} else if (oldNode != null && firstChild != null && mount.mounted) {
  _reconcileNode(
    parentDom: mount.boundary,
    existingDom: firstChild,
    oldNode: oldNode,
    newNode: nextNode,
    path: 'c',
    previousSlots: previousSlots,
    nextSlots: nextSlots,
  );
}
```

---

#### 12. ✅ MySQL Connection Pooling & Parallel Execution
- **File:** `lib/src/database/mysql_connection.dart` — `MySqlConnectionWrapper`
- **Status:** **Completed & Verified**
- **Problem:** MySQL ran on a single socket connection, serializing all queries across the entire server through `_queueTail`. Under concurrent requests, one slow query stalled the entire backend.
- **Fix Applied:** Integrated `MySQLConnectionPool` from `package:mysql_dart/mysql_dart.dart`. Queries and commands now execute across a managed pool of connections concurrently, configurable via `DB_POOL_SIZE` or `DB_MAX_CONNECTIONS` (defaulting to 10). Single connection fallback and transactional boundaries are fully preserved.

---

#### 13. ✅ Static Schema & Relation Metadata Caching on Model
- **File:** `lib/src/database/model/model.dart` — `_initSchema()`, `_registerRelationLoaders()`
- **Status:** **Completed & Verified**
- **Problem:** Every hydrated model row invoked `_registerRelationLoaders()` and `_initSchema()`. A query returning 1,000 rows built 1,000 separate `_schemaColumns` lists and iterated `relations.entries` 1,000 times.
- **Fix Applied:** Added `_schemaCache` and `_relationsDefCache` static maps, and `_relationsRegisteredTypes` set on `Model`. Schema definitions and relation loader registration now run exactly once per concrete model class, eliminating massive redundant heap allocations when hydrating result sets.

---

#### 14. ✅ Path Traversal Vulnerability in Static File Serving
- **File:** `lib/src/middleware/static_file_middleware.dart` — `handle()`
- **Status:** **Completed & Verified**
- **Problem:** `path.join(publicFolder, relativePath)` did not verify that the canonical path stayed inside `publicFolder`. Requests with `../` sequences could potentially escape the public folder.
- **Fix Applied:** Added canonical containment check using `path.canonicalize` and `path.isWithin`. Any request attempting to resolve outside the public root is safely bypassed.

```dart
final canonicalPublic = path.canonicalize(publicFolder);
final canonicalTarget = path.canonicalize(path.join(publicFolder, relativePath));

if (!path.isWithin(canonicalPublic, canonicalTarget) &&
    canonicalTarget != canonicalPublic) {
  return await next(ctx);
}
```

---

### 🟡 Medium Impact

#### 15. ✅ `preserveState` Defaults & `StateSignalListener` Lifecycle
- **Files:** `lib/src/ui/component.dart`, `lib/src/ui/state/state_signal.dart`
- **Status:** **Completed & Verified**
- **Problem:** `StateSignalListener` implemented `updateFrom()` to receive new props on parent re-renders, but did not override `preserveState => true`, causing it to be torn down and recreated every time its parent rebuilt.
- **Fix Applied:** Overrode `bool get preserveState => true;` on `StateSignalListener` so it survives parent re-renders and rebinds signals in-place via `updateFrom`.

```dart
class StateSignalListener<T> extends StatefulComponent {
  @override
  bool get preserveState => true;
  ...
}
```

---

#### 16. ✅ Pre-compiled Route Matching & Middleware Pipeline Caching
- **File:** `lib/src/routing/router.dart` — `Router`, `Route`
- **Status:** **Completed & Verified**
- **Problem:** `Router.match()` performed sequential passes over all routes for each request. It called `pathToMatch.split('/')` repeatedly and compiled `RegExp('^${parsed.pattern}\$')` on every evaluation. It also ran `.fold()` to allocate new middleware closures on every hit.
- **Fix Applied:** 
  1. Static routes are indexed in a hash map `_staticRoutesByMethod` for instant $O(1)$ lookups with zero string splitting.
  2. Route segments and custom parameter regex patterns are parsed and pre-compiled at registration.
  3. Middleware pipelines are cached lazily per route, completely eliminating runtime `.fold()` closure churn on every request.

---

#### 17. ✅ Nested Eager Loading via Dot Notation in ORM
- **Files:** `lib/src/database/model/model.dart`, `lib/src/database/orm/query_builder.dart`
- **Status:** **Completed & Verified**
- **Problem:** Eager loading only supported 1-level relations (`withRelations(['user', 'class'])`). Nested graphs like `schoolClass.department` or `user.posts` could not be loaded in a batch.
- **Fix Applied:** Implemented recursive relation tree eager loading (`_loadRelationTree`) supporting dot notation (e.g. `withRelations(['user.posts'])` and `load('user.posts')`). Related model instances are collected and batched efficiently without duplicate queries.

---

### 🟢 Low Impact / DX

#### 18. ✅ Cleaned Up Dead/Broken Code in `model_relations.dart`
- **File:** `lib/src/database/model/model_relations.dart`
- **Status:** **Completed & Verified**
- **Problem:** Contained commented-out `load()`, a no-op `loadMany()`, and an incomplete comment for `withRelations`.
- **Fix Applied:** Rewrote `ModelRelations` to cleanly delegate to the active implementations on `Model` (`load`, `loadMany`, `getRelation`, `withRelation`, `withRelations`).

---

#### 19. ✅ Unified `where()` Syntax, Named `filter()`, & Non-Deprecated Legacy API
- **Files:** `lib/src/database/model/model.dart`, `lib/src/database/orm/query_builder.dart`, `lib/src/database/orm/query_condition.dart`
- **Status:** **Completed & Verified**
- **Problem:** `QueryBuilder.where(col, op, val)` required 3 arguments, whereas `Model.where(col, val)` required 2 arguments. Developers and AI code generators also needed compile-time safety and autocomplete instead of raw SQL operator strings (`'='`, `'>'`, `'!='`) that could cause runtime SQL syntax errors.
- **Fix Applied:**
  1. **Legacy API 100% Preserved & Non-Deprecated:** Both 2-argument (`where('status', 'active')`) and 3-argument (`where('age', '>=', 21)`) syntax continue to work without any changes or deprecation warnings.
  2. **Named Operator Parameters via `filter()`:** Developers and AIs get IDE autocomplete and compile-time error prevention:
     - `filter('role', equals: 'admin')`
     - `filter('age', greaterThan: 18, lessThan: 65)`
     - `filter('status', notEquals: 'banned')`
  3. **Typed Matchers via `Op`:**
     - `where('role', Op.equals('admin'))`
     - `where('age', Op.greaterThan(18))`
  4. **Fluent Helper Methods:**
     - `whereEqual(col, val)` / `orWhereEqual(col, val)`
     - `whereNotEqual(col, val)` / `orWhereNotEqual(col, val)`
     - `whereTrue(col)` / `whereFalse(col)`
     - `whereGreaterThan(col, val)` (`whereGt`) / `whereLessThan(col, val)` (`whereLt`)

```dart
// 1. Named autocomplete filter (ideal for developers & AI):
await User()
    .filter('role', equals: 'admin')
    .filter('age', greaterThan: 18, lessThan: 65)
    .get();

// 2. Typed matcher helpers:
await User()
    .where('role', Op.equals('admin'))
    .where('age', Op.greaterThan(18))
    .get();

// 3. Fully preserved legacy syntax (no deprecation):
await User()
    .where('status', 'active')
    .where('age', '>=', 18)
    .get();
```

---

#### 20. ✅ Zero-Argument Event Handlers in Browser Renderer
- **File:** `lib/src/ui/browser_renderer.dart` — `_listen()`
- **Status:** **Completed & Verified**
- **Problem:** `_listen` executed `handler(event)`. If a developer passed a 0-argument callback `() => doSomething()`, Dart threw a runtime type exception (`type '() => void' is not a subtype of '(dynamic) => dynamic'`).
- **Fix Applied:** Updated `_listen` to inspect whether `handler is void Function()`, invoking it without arguments when no event parameter is declared. Also added event listener multiplexing via `Expando` to eliminate DOM listener churn.

```dart
element.addEventListener(
  eventName,
  ((web.Event event) {
    final current = _elementListeners[element]?[eventName];
    if (current != null) {
      if (current is void Function()) {
        current();
      } else {
        current(event);
      }
    }
  }).toJS,
);
```

---

## Progress Summary

### Phase 1 — Quick Optimizations (Completed)
| # | Description | Status | Priority |
|---|-------------|--------|----------|
| 1 | Full DOM wipe on root render | ✅ Done | 🔴 High |
| 2 | Serial page bundle compilation | ✅ Done | 🔴 High |
| 3 | Serial asset compression | ✅ Done | 🟡 Medium |
| 4 | JS file read twice for hash | ✅ Done | 🟡 Medium |
| 5 | DOM query for style deduplication | ✅ Done | 🟡 Medium |
| 6 | CSS extraction subprocess | ✅ Done | 🟡 Medium |
| 7 | Focus restored 3× per render | ✅ Done | 🟡 Medium |
| 8 | `cssText` not memoized | ✅ Done | 🟢 Low |
| 9 | 12s SW prefetch delay | ✅ Done | 🟢 Low |
| 10 | `--watch` incremental rebuild | ✅ Done | 🟢 Low |

### Phase 2 — Architecture & Performance (Completed)
| # | Description | Status | Priority |
|---|-------------|--------|----------|
| 11 | Component subtree wiped on `setState` (VDOM diffing) | ✅ Done | 🔴 High |
| 12 | Missing MySQL connection pool (single socket queue) | ✅ Done | 🔴 High |
| 13 | Redundant schema/relation allocation per row | ✅ Done | 🔴 High |
| 14 | Path traversal defense in static file middleware | ✅ Done | 🔴 High |
| 15 | `preserveState` defaults & `StateSignalListener` bug | ✅ Done | 🟡 Medium |
| 16 | Linear $O(N)$ routing & uncached regexes | ✅ Done | 🟡 Medium |
| 17 | Nested eager loading in ORM (`dot.notation`) | ✅ Done | 🟡 Medium |
| 18 | Clean up dead/broken code in `model_relations.dart` | ✅ Done | 🟢 Low |
| 19 | Unify `where()` overloads & fluent SQL-free helpers | ✅ Done | 🟢 Low |
| 20 | Zero-argument event handlers in browser renderer | ✅ Done | 🟢 Low |

### Phase 3 — Compiler & Hot Reload Velocity (Completed for v1.6.0)
| # | Description | Status | Priority |
|---|-------------|--------|----------|
| 21 | Fast Dev-Mode Web UI Compilation (`-O0 --no-minify`) | ✅ Done | 🔴 High |
| 22 | Transitive Dependency Graph for Hot Reload (Instant sub-component edits) | ✅ Done | 🔴 High |
| 23 | Dynamic CPU Concurrency for Page Bundle Compilation | ✅ Done | 🔴 High |
| 24 | Redundant Single-Bundle (`main.dart.js`) Build Elimination | ✅ Done | 🟡 Medium |
| 25 | Watcher Debounce & Port Polling Latency Reduction | ✅ Done | 🟡 Medium |
