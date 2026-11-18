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

## Progress Summary

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
