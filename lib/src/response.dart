import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flint_dart/src/cli/web_ui_builder.dart';
import 'package:flint_dart/src/template_engine/template.dart';
import 'package:flint_dart/src/template_engine/template_engine.dart';
import 'package:path/path.dart' as p;

import '../flint_dart.dart';

/// Supported response types for automatic content handling.
enum RespondType {
  /// JSON data (application/json)
  json,

  /// HTML content (text/html)
  html,

  /// Plain text (text/plain)
  plain,
}

/// Renders a Flint page component to server-side HTML.
typedef FlintPageServerRenderer = String? Function(
  String component,
  Map<String, dynamic> props,
);

class _FlintPageScriptResolution {
  const _FlintPageScriptResolution(this.script, {this.isBuilding = false});

  final String script;
  final bool isBuilding;
}

class FlintPageMeta {
  final String? title;
  final String? description;
  final String? canonicalUrl;
  final String? imageUrl;
  final String? iconUrl;
  final String? appleTouchIconUrl;
  final String type;
  final String? siteName;
  final String? locale;
  final String twitterCard;
  final String? twitterSite;
  final bool noIndex;
  final Map<String, String> meta;
  final Map<String, String> openGraph;
  final Map<String, String> twitter;
  final Map<String, Object?>? structuredData;

  const FlintPageMeta({
    this.title,
    this.description,
    this.canonicalUrl,
    this.imageUrl,
    this.iconUrl,
    this.appleTouchIconUrl,
    this.type = 'website',
    this.siteName,
    this.locale,
    this.twitterCard = 'summary_large_image',
    this.twitterSite,
    this.noIndex = false,
    this.meta = const {},
    this.openGraph = const {},
    this.twitter = const {},
    this.structuredData,
  });
}

/// A wrapper around [HttpResponse] for sending HTTP responses in Flint Dart.
///
/// The [Response] class provides helper methods to:
/// - Send plain text, HTML, or JSON responses
/// - Stream files
/// - Set HTTP status codes
/// - Automatically determine response types
///
/// Example:
/// ```dart
/// app.get('/hello', (req, res) {
///   res.send('Hello World!');
/// });
///
/// app.get('/user', (req, res) {
///   res.json({'name': 'John'});
/// });
/// ```
class Response {
  static String? defaultIconUrl;
  static String? defaultAppleTouchIconUrl;

  /// The underlying raw [HttpResponse] object.
  final HttpResponse raw;
  final Request? request;
  final FlintPageServerRenderer? _flintPageServerRenderer;
  final bool _flintPageServerRenderingEnabled;
  bool _closed = false;

  /// Optional app-level renderer used by [flintPage] to send initial HTML.
  static FlintPageServerRenderer? flintPageServerRenderer;

  /// Enables app-level server rendering for Flint pages when a renderer exists.
  static bool flintPageServerRenderingEnabled = false;

  static final Set<String> _flintPageBundlesBuilding = {};
  static final Set<String> _flintPageBundlesUnavailable = {};

  /// Current HTTP status code for this response.
  int get statusCode => raw.statusCode;

  /// Creates a new [Response] instance with the given [HttpResponse].
  Response(
    this.raw, {
    this.request,
    FlintPageServerRenderer? flintPageServerRenderer,
    bool? serverRenderFlintPages,
  })  : _flintPageServerRenderer = flintPageServerRenderer,
        _flintPageServerRenderingEnabled = serverRenderFlintPages ?? false;
  bool get isClosed => _closed;

  Response header(String name, Object value) {
    raw.headers.set(name, value);
    return this;
  }

  Response cachePublic(
    Duration maxAge, {
    Duration? sharedMaxAge,
    bool immutable = false,
    bool mustRevalidate = false,
  }) {
    return _setCacheControl(
      public: true,
      maxAge: maxAge,
      sharedMaxAge: sharedMaxAge,
      immutable: immutable,
      mustRevalidate: mustRevalidate,
    );
  }

  Response cachePrivate(
    Duration maxAge, {
    bool mustRevalidate = false,
  }) {
    return _setCacheControl(
      public: false,
      maxAge: maxAge,
      mustRevalidate: mustRevalidate,
    );
  }

  Response revalidate() {
    raw.headers.set(
      HttpHeaders.cacheControlHeader,
      'no-cache, must-revalidate',
    );
    return this;
  }

  Response noStore() {
    raw.headers.set(
      HttpHeaders.cacheControlHeader,
      'no-store, no-cache, must-revalidate',
    );
    raw.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
    raw.headers.set(HttpHeaders.expiresHeader, '0');
    return this;
  }

  Response etag(String value, {bool weak = false}) {
    if (value.startsWith('W/')) {
      raw.headers.set(HttpHeaders.etagHeader, value);
      return this;
    }

    final tag = value.startsWith('"') ? value : '"$value"';
    raw.headers.set(HttpHeaders.etagHeader, weak ? 'W/$tag' : tag);
    return this;
  }

  Response lastModified(DateTime value) {
    raw.headers.set(
      HttpHeaders.lastModifiedHeader,
      HttpDate.format(value.toUtc()),
    );
    return this;
  }

  Response _setCacheControl({
    required bool public,
    required Duration maxAge,
    Duration? sharedMaxAge,
    bool immutable = false,
    bool mustRevalidate = false,
  }) {
    final directives = <String>[
      public ? 'public' : 'private',
      'max-age=${maxAge.inSeconds}',
      if (sharedMaxAge != null) 's-maxage=${sharedMaxAge.inSeconds}',
      if (immutable) 'immutable',
      if (mustRevalidate) 'must-revalidate',
    ];
    raw.headers.set(HttpHeaders.cacheControlHeader, directives.join(', '));
    return this;
  }

  Future<void> close() async {
    if (!_closed) {
      _closed = true;
      await raw.close();
    }
  }

  /// Sends a plain text or custom content response.
  ///
  /// [body] is the content to send.
  /// [status] is the optional HTTP status code.
  /// [contentType] defaults to `text/plain`.
  Response send(
    String body, {
    int? status,
    String contentType = 'text/plain',
  }) {
    try {
      raw.statusCode = status ?? raw.statusCode;
      raw.headers.contentType = ContentType.parse(contentType);
      raw.write(body);
    } catch (e) {
      raw.statusCode = 500;
      raw.headers.contentType = ContentType.text;
      raw.write('âŒ Failed to send response: Invalid content.');
    }
    close();
    return this; // âœ… return Response
  }

  /// Sends a JSON response with a [Map] or [List].
  ///
  /// Automatically sets the `Content-Type` header to `application/json`.
  /// [status] can be provided to override the HTTP status code.
  Future<Response> json(dynamic data, {int? status}) async {
    try {
      // Await top-level Future
      if (data is Future) {
        data = await data;
      }

      /// Recursively converts data into JSON-serializable form
      Future<dynamic> sanitize(dynamic value) async {
        // Await if value is Future
        if (value is Future) value = await value;

        if (value is DateTime) return value.toIso8601String();
        if (value is Model) return sanitize(value.toMap());
        if (value is List) {
          // Await each item
          final results = await Future.wait(value.map(sanitize));
          return results;
        }
        if (value is Map) {
          final entries = await Future.wait(value.entries.map((e) async {
            final sanitizedValue = await sanitize(e.value);
            return MapEntry(e.key, sanitizedValue);
          }));
          return Map.fromEntries(entries);
        }

        // For custom classes
        try {
          final toMapMethod = (value as dynamic).toMap;
          if (toMapMethod is Function) return await sanitize(toMapMethod());

          final toJsonMethod = (value as dynamic).toJson;
          if (toJsonMethod is Function) return await sanitize(toJsonMethod());
        } catch (_) {}

        return value; // primitives or unsupported objects
      }

      if (data is Exception) {
        data = {
          'error': data.runtimeType.toString(),
          'message': data.toString(),
        };
      }
      final safeData = await sanitize(data);
      final encoded = jsonEncode(safeData);

      raw.statusCode = status ?? raw.statusCode;
      raw.headers.contentType = ContentType.json;
      raw.write(encoded);
    } catch (e, stack) {
      raw.statusCode = 500;
      raw.headers.contentType = ContentType.text;
      raw.write('âŒ Failed to encode JSON response: ${e.runtimeType}');
      Log.debug('[Flint] JSON Error: $e\n$stack');
    }

    await close();
    return this;
  }

  /// Sends a response automatically based on [RespondType] or inferred type.
  ///
  /// - If [type] is provided, it is used directly.
  /// - If not, the type is inferred from [data] (Map/List â†’ JSON, HTML tags â†’ HTML, otherwise plain text).
  Future<Response> respond(
    dynamic data, {
    int? status,
    RespondType? type,
    bool? includePreview,
    String? title,
  }) async {
    try {
      // If data is a Future, await it first
      if (data is Future) {
        data = await data;
      }

      // Determine the type asynchronously
      type ??= await _inferRespondType(data);

      switch (type) {
        case RespondType.json:
          await json(data, status: status);
          break;

        case RespondType.html:
          send(data.toString(), status: status, contentType: 'text/html');
          break;

        case RespondType.plain:
          send(data.toString(), status: status, contentType: 'text/plain');
          break;
      }
    } catch (e, stack) {
      raw.statusCode = 500;
      raw.headers.contentType = ContentType.text;
      raw.write('âŒ Failed to send response: ${e.runtimeType}');
      Log.debug('[Flint] respond() Error: $e\n$stack');
    }

    await close();
    return this;
  }

  /// Attempts to guess the best [RespondType] based on [data].
  ///
  /// - Map/List â†’ JSON
  /// - HTML-like string â†’ HTML
  /// - Otherwise â†’ Plain text
  Future<RespondType> _inferRespondType(dynamic data) async {
    // Await if it's a Future
    if (data is Future) {
      data = await data;
    }
    if (data is Map || data is List) {
      return RespondType.json;
    } else if (data is Model) {
      return RespondType.json;
    } else if (data is String &&
        (data.contains('<html') || data.contains('<!DOCTYPE html'))) {
      return RespondType.html;
    } else {
      return RespondType.plain;
    }
  }

  Response flintPage(
    String component, {
    Map<String, dynamic> props = const {},
    String rootId = 'app',
    String? script,
    List<String>? stylesheets,
    bool preloadScript = true,
    String? title,
    FlintPageMeta? meta,
    String? serverHtml,
    bool? serverRender,
    int? status,
  }) {
    try {
      final page = {
        'component': component,
        'props': _jsonSafeValue(props),
        if (request != null) 'url': request!.uri.toString(),
      };
      final scriptResolution = script == null
          ? _flintPageScriptForComponent(component)
          : _FlintPageScriptResolution(script);
      final isBuildingPageBundle = scriptResolution.isBuilding;
      final resolvedScript = scriptResolution.script;
      final resolvedStylesheets = stylesheets ?? _defaultFlintPageStylesheets();
      final encodedPage = _escapeHtmlAttribute(jsonEncode(page));
      final safeRootId = _escapeHtmlAttribute(rootId);
      final renderedHtml = serverHtml ??
          _renderFlintPageOnServer(
            component,
            Map<String, dynamic>.from(page['props'] as Map),
            serverRender: serverRender,
          );
      final versionedScript = _versionedAssetUrl(resolvedScript);
      final safeScript = _escapeHtmlAttribute(versionedScript);
      final resolvedMeta =
          meta ?? (title == null ? null : FlintPageMeta(title: title));
      final headTags = _renderFlintPageHead(
        title: title ?? resolvedMeta?.title ?? component,
        stylesheets: resolvedStylesheets.map(_versionedAssetUrl).toList(),
        scriptPreloads: preloadScript && !isBuildingPageBundle
            ? [versionedScript]
            : const [],
        meta: resolvedMeta,
        requestUrl: request?.uri.toString(),
      );

      raw.statusCode = status ??
          (isBuildingPageBundle ? HttpStatus.accepted : raw.statusCode);
      raw.headers.contentType = ContentType.html;
      if (isBuildingPageBundle) {
        raw.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      }
      final hotReloadScript = _hotReloadScript();
      final serviceWorkerScript = _flintServiceWorkerScript();
      final buildOverlayScript =
          isBuildingPageBundle ? _lazyPageBuildOverlayScript(component) : '';
      final pageScriptTag = isBuildingPageBundle
          ? ''
          : '    <script defer src="$safeScript"></script>';
      raw.write('''
<!DOCTYPE html>
<html lang="en">
  <head>
$headTags
  </head>
  <body>
    <main id="$safeRootId" data-flint-page="$encodedPage">$renderedHtml</main>
$pageScriptTag
$buildOverlayScript
$serviceWorkerScript
$hotReloadScript
  </body>
</html>
''');
    } catch (e, stack) {
      raw.statusCode = 500;
      raw.headers.contentType = ContentType.text;
      raw.write('Failed to render Flint page: ${e.runtimeType}');
      Log.debug('[Flint] flintPage() Error: $e\n$stack');
    }

    close();
    return this;
  }

  dynamic _jsonSafeValue(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) return value.toIso8601String();
    if (value is Uri) return value.toString();
    if (value is Enum) return value.name;
    if (value is Model) return _jsonSafeValue(value.toMap());
    if (value is Map) {
      return value.map(
        (key, mapValue) => MapEntry(key.toString(), _jsonSafeValue(mapValue)),
      );
    }
    if (value is Iterable) {
      return value.map(_jsonSafeValue).toList(growable: false);
    }

    try {
      final jsonValue = (value as dynamic).toJson();
      if (!identical(jsonValue, value)) return _jsonSafeValue(jsonValue);
    } catch (_) {}

    try {
      final mapValue = (value as dynamic).toMap();
      if (!identical(mapValue, value)) return _jsonSafeValue(mapValue);
    } catch (_) {}

    return value.toString();
  }

  Response page(
    String component, {
    Map<String, dynamic> props = const {},
    String rootId = 'app',
    String? script,
    List<String>? stylesheets,
    bool preloadScript = true,
    String? title,
    FlintPageMeta? meta,
    String? serverHtml,
    bool? serverRender,
    int? status,
  }) =>
      flintPage(
        component,
        props: props,
        rootId: rootId,
        script: script,
        stylesheets: stylesheets,
        preloadScript: preloadScript,
        title: title,
        meta: meta,
        serverHtml: serverHtml,
        serverRender: serverRender,
        status: status,
      );

  String _renderFlintPageOnServer(
    String component,
    Map<String, dynamic> props, {
    bool? serverRender,
  }) {
    final shouldRender = serverRender ??
        (_flintPageServerRenderingEnabled ||
            Response.flintPageServerRenderingEnabled);
    final renderer =
        _flintPageServerRenderer ?? Response.flintPageServerRenderer;
    if (!shouldRender || renderer == null) return '';

    try {
      return renderer(component, props) ?? '';
    } catch (e, stack) {
      Log.debug('[Flint] Server render failed for "$component": $e\n$stack');
      return '';
    }
  }

  String _renderFlintPageHead({
    required String title,
    required List<String> stylesheets,
    List<String> scriptPreloads = const [],
    required FlintPageMeta? meta,
    required String? requestUrl,
  }) {
    final resolvedTitle = meta?.title ?? title;
    final description = meta?.description;
    final canonicalUrl = meta?.canonicalUrl ?? requestUrl;
    final imageUrl = meta?.imageUrl;
    final iconUrl = _resolveIconUrl(meta?.iconUrl ?? defaultIconUrl);
    final appleTouchIconUrl = _resolveIconUrl(
      meta?.appleTouchIconUrl ?? defaultAppleTouchIconUrl ?? defaultIconUrl,
      preferPng: true,
    );
    final tags = <String>[
      '    <meta charset="utf-8">',
      '    <meta name="viewport" content="width=device-width, initial-scale=1">',
      '    <title>${_escapeHtmlText(resolvedTitle)}</title>',
      if (description != null && description.trim().isNotEmpty)
        _metaName('description', description),
      if (meta?.noIndex == true) _metaName('robots', 'noindex, nofollow'),
      if (canonicalUrl != null && canonicalUrl.trim().isNotEmpty)
        _linkTag('canonical', canonicalUrl),
      if (iconUrl != null) _linkTag('icon', iconUrl),
      if (appleTouchIconUrl != null)
        _linkTag('apple-touch-icon', appleTouchIconUrl),
      _metaProperty('og:title', resolvedTitle),
      if (description != null && description.trim().isNotEmpty)
        _metaProperty('og:description', description),
      _metaProperty('og:type', meta?.type ?? 'website'),
      if (canonicalUrl != null && canonicalUrl.trim().isNotEmpty)
        _metaProperty('og:url', canonicalUrl),
      if (imageUrl != null && imageUrl.trim().isNotEmpty)
        _metaProperty('og:image', imageUrl),
      if (meta?.siteName != null && meta!.siteName!.trim().isNotEmpty)
        _metaProperty('og:site_name', meta.siteName!),
      if (meta?.locale != null && meta!.locale!.trim().isNotEmpty)
        _metaProperty('og:locale', meta.locale!),
      _metaName('twitter:card', meta?.twitterCard ?? 'summary_large_image'),
      _metaName('twitter:title', resolvedTitle),
      if (description != null && description.trim().isNotEmpty)
        _metaName('twitter:description', description),
      if (imageUrl != null && imageUrl.trim().isNotEmpty)
        _metaName('twitter:image', imageUrl),
      if (meta?.twitterSite != null && meta!.twitterSite!.trim().isNotEmpty)
        _metaName('twitter:site', meta.twitterSite!),
      if (meta != null) ...[
        for (final entry in meta.meta.entries)
          _metaName(entry.key, entry.value),
        for (final entry in meta.openGraph.entries)
          _metaProperty(entry.key, entry.value),
        for (final entry in meta.twitter.entries)
          _metaName(entry.key, entry.value),
      ],
      for (final href in stylesheets) _linkTag('stylesheet', href),
      for (final href in scriptPreloads) _preloadScriptTag(href),
      if (meta?.structuredData != null)
        _jsonLdTag(jsonEncode(meta!.structuredData)),
    ];

    return tags.join('\n');
  }

  String _metaName(String name, String content) {
    return '    <meta name="${_escapeHtmlAttribute(name)}" content="${_escapeHtmlAttribute(content)}">';
  }

  String _metaProperty(String property, String content) {
    return '    <meta property="${_escapeHtmlAttribute(property)}" content="${_escapeHtmlAttribute(content)}">';
  }

  String _linkTag(String rel, String href) {
    return '    <link rel="${_escapeHtmlAttribute(rel)}" href="${_escapeHtmlAttribute(href)}">';
  }

  String _preloadScriptTag(String href) {
    return '    <link rel="preload" as="script" href="${_escapeHtmlAttribute(href)}">';
  }

  String _jsonLdTag(String json) {
    final safeJson = json.replaceAll('</script', '<\\/script');
    return '    <script type="application/ld+json">$safeJson</script>';
  }

  String _versionedAssetUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('//') ||
        trimmed.startsWith('data:')) {
      return url;
    }

    final parsed = Uri.tryParse(trimmed);
    final pathOnly = parsed?.path ?? trimmed.split('?').first.split('#').first;
    if (!pathOnly.startsWith('/')) return url;
    if (_isHashedFlintAssetPath(pathOnly)) return url;

    final publicPath = p.joinAll([
      'public',
      ...pathOnly.split('/').where((part) => part.isNotEmpty),
    ]);
    final file = File(publicPath);
    if (!file.existsSync()) return url;

    final version = file.lastModifiedSync().millisecondsSinceEpoch.toString();
    final separator = trimmed.contains('?') ? '&' : '?';
    return '$trimmed${separator}v=$version';
  }

  String _lazyPageBuildOverlayScript(String component) {
    final safeJsonComponent = jsonEncode(component).replaceAll('</', '<\\/');
    return '''
    <script>
      (function () {
        window.__FLINT_BUILDING_PAGE__ = $safeJsonComponent;

        function ensureFlintLazyBuildIndicator() {
          var overlay = document.getElementById('flint-hot-reload-indicator');
          if (!overlay) {
            overlay = document.createElement('div');
            overlay.id = 'flint-hot-reload-indicator';
            overlay.setAttribute('role', 'status');
            overlay.setAttribute('aria-live', 'polite');
            overlay.innerHTML = '<span class="flint-hot-reload-spinner"></span><span class="flint-hot-reload-text">Building Flint UI...</span>';

            var style = document.createElement('style');
            style.textContent = `
              #flint-hot-reload-indicator {
                align-items: center;
                backdrop-filter: blur(14px);
                background: rgba(15, 23, 42, 0.86);
                border: 1px solid rgba(148, 163, 184, 0.28);
                border-radius: 12px;
                box-shadow: 0 18px 45px rgba(15, 23, 42, 0.32);
                color: #ffffff;
                display: none;
                font: 700 13px/1.2 system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
                gap: 10px;
                left: 50%;
                max-width: calc(100vw - 32px);
                padding: 12px 14px;
                position: fixed;
                top: 18px;
                transform: translateX(-50%);
                z-index: 2147483647;
              }

              #flint-hot-reload-indicator[data-visible="true"] {
                display: inline-flex;
              }

              .flint-hot-reload-spinner {
                animation: flint-hot-reload-spin 0.75s linear infinite;
                border: 2px solid rgba(255, 255, 255, 0.28);
                border-top-color: #38bdf8;
                border-radius: 999px;
                height: 16px;
                width: 16px;
              }

              @keyframes flint-hot-reload-spin {
                to { transform: rotate(360deg); }
              }
            `;
            document.head.appendChild(style);
            document.body.appendChild(overlay);
          }

          var text = overlay.querySelector('.flint-hot-reload-text');
          if (text) text.textContent = 'Building Flint UI...';
          overlay.dataset.visible = 'true';
          return overlay;
        }

        ensureFlintLazyBuildIndicator();
        window.setTimeout(function () {
          window.location.reload();
        }, 1500);
      })();
    </script>''';
  }

  _FlintPageScriptResolution _flintPageScriptForComponent(String component) {
    final pageScript = _scriptFromFlintUiManifest(
      component,
      includeFallback: false,
      requireExistingFile: true,
    );
    if (pageScript != null) return _FlintPageScriptResolution(pageScript);

    if (Platform.environment['FLINT_HOT'] == '1' &&
        !_flintPageBundlesUnavailable.contains(component)) {
      if (_buildFlintPageBundleOnDemand(component)) {
        return _FlintPageScriptResolution(
          _defaultFlintPageScript(),
          isBuilding: true,
        );
      }
    }

    return _FlintPageScriptResolution(
      _scriptFromFlintUiManifest(
            component,
            requireExistingFile: true,
          ) ??
          _defaultFlintPageScript(),
    );
  }

  bool _buildFlintPageBundleOnDemand(String component) {
    if (Platform.environment['FLINT_HOT'] != '1') return false;
    if (_flintPageBundlesBuilding.contains(component)) return true;
    if (_flintPageBundlesUnavailable.contains(component)) return false;

    final build = FlintWebUiBuilder.resolve();
    if (build == null) return false;

    _flintPageBundlesBuilding.add(component);
    unawaited(
      Future<void>(() async {
        try {
          Log.info('Building Flint UI page: $component...');
          await FlintWebUiBuilder.compilePageBundles(build,
              onlyPage: component);
          Log.info('Done building Flint UI page: $component.');
        } on StateError catch (e) {
          _flintPageBundlesUnavailable.add(component);
          Log.debug(
              'Flint UI page bundle skipped for "$component": ${e.message}');
        } catch (e, stack) {
          Log.debug('Flint UI page bundle failed for "$component": $e\n$stack');
        } finally {
          _flintPageBundlesBuilding.remove(component);
        }
      }),
    );
    return true;
  }

  String? _scriptFromFlintUiManifest(
    String component, {
    bool includeFallback = true,
    bool requireExistingFile = false,
  }) {
    final manifestFile =
        File(p.join('public', 'assets', 'js', 'flint-ui', 'manifest.json'));
    if (!manifestFile.existsSync()) return null;

    try {
      final decoded = jsonDecode(manifestFile.readAsStringSync());
      if (decoded is! Map) return null;

      if (decoded['mode'] == 'shared-runtime') {
        final runtime = decoded['runtime'];
        if (_isUsableManifestScript(
          runtime,
          requireExistingFile: requireExistingFile,
        )) {
          return runtime.toString().trim();
        }
      }

      final pages = decoded['pages'];
      if (pages is Map) {
        final script = pages[component];
        if (_isUsableManifestScript(
          script,
          requireExistingFile: requireExistingFile,
        )) {
          return script.toString().trim();
        }
      }

      if (includeFallback) {
        final fallback = decoded['fallback'];
        if (_isUsableManifestScript(
          fallback,
          requireExistingFile: requireExistingFile,
        )) {
          return fallback.toString().trim();
        }
      }
    } catch (e) {
      Log.debug('[Flint] Failed to read Flint UI manifest: $e');
    }

    return null;
  }

  bool _isUsableManifestScript(
    Object? value, {
    required bool requireExistingFile,
  }) {
    if (value is! String || value.trim().isEmpty) return false;
    if (!requireExistingFile) return true;
    return _publicAssetExists(value.trim());
  }

  bool _publicAssetExists(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('//') ||
        trimmed.startsWith('data:')) {
      return true;
    }

    final parsed = Uri.tryParse(trimmed);
    final pathOnly = parsed?.path ?? trimmed.split('?').first.split('#').first;
    if (!pathOnly.startsWith('/')) return true;

    final publicPath = p.joinAll([
      'public',
      ...pathOnly.split('/').where((part) => part.isNotEmpty),
    ]);
    return File(publicPath).existsSync();
  }

  String? _resolveIconUrl(String? explicitUrl, {bool preferPng = false}) {
    if (explicitUrl != null && explicitUrl.trim().isNotEmpty) {
      return explicitUrl;
    }

    final candidates = preferPng
        ? const ['favicon.png', 'apple-touch-icon.png', 'favicon.ico']
        : const ['favicon.ico', 'favicon.png', 'favicon.svg'];

    for (final candidate in candidates) {
      if (File(p.join('public', candidate)).existsSync()) {
        return '/$candidate';
      }
    }

    return null;
  }

  String _defaultFlintPageScript() {
    final appOwnedScript = _findFlintUiAsset(
      p.join('public', 'assets', 'js', 'flint-ui'),
      'main',
    );
    if (appOwnedScript != null) {
      return appOwnedScript;
    }
    if (File(p.join('flint_ui', 'web', 'main.dart.js')).existsSync()) {
      return '/web/main.dart.js';
    }
    if (File(p.join('web', 'main.dart.js')).existsSync()) {
      return '/web/main.dart.js';
    }
    if (File(p.join('public', 'main.dart.js')).existsSync()) {
      return '/main.dart.js';
    }
    return '/main.dart.js';
  }

  String? _findFlintUiAsset(String directoryPath, String stem) {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) return null;

    final exact = File(p.join(directory.path, '$stem.dart.js'));
    if (exact.existsSync()) {
      return '/${p.split(p.relative(exact.path, from: 'public')).join('/')}';
    }

    final hashedPattern = RegExp(
      '^${RegExp.escape(stem)}\\.[a-f0-9]{12}\\.dart\\.js\$',
    );
    final matches = directory
        .listSync()
        .whereType<File>()
        .where((file) => hashedPattern.hasMatch(p.basename(file.path)))
        .toList()
      ..sort((a, b) {
        return b.lastModifiedSync().compareTo(a.lastModifiedSync());
      });

    if (matches.isEmpty) return null;
    return '/${p.split(p.relative(matches.first.path, from: 'public')).join('/')}';
  }

  List<String> _defaultFlintPageStylesheets() {
    if (File(p.join('public', 'assets', 'css', 'flint-ui', 'style.css'))
        .existsSync()) {
      return const ['/assets/css/flint-ui/style.css'];
    }
    if (File(p.join('flint_ui', 'web', 'style.css')).existsSync()) {
      return const ['/web/style.css'];
    }
    if (File(p.join('web', 'style.css')).existsSync()) {
      return const ['/web/style.css'];
    }
    if (File(p.join('public', 'style.css')).existsSync()) {
      return const ['/style.css'];
    }
    return const [];
  }

  String _flintServiceWorkerScript() {
    if (Platform.environment['FLINT_HOT'] == '1') return '';
    final file = File(p.join('public', 'flint-sw.js'));
    if (!file.existsSync()) return '';
    final scriptUrl = _escapeHtmlAttribute(_versionedAssetUrl('/flint-sw.js'));
    return '''
    <script>
      if ('serviceWorker' in navigator) {
        window.addEventListener('load', () => {
          const startFlintServiceWorker = () => {
            navigator.serviceWorker.register('$scriptUrl', { scope: '/' }).then(registration => {
              const worker = registration.active || registration.waiting || registration.installing;
              if (worker) worker.postMessage({ type: 'FLINT_PREFETCH' });
            }).catch(() => {});
          };
          if ('requestIdleCallback' in window) {
            window.requestIdleCallback(startFlintServiceWorker, { timeout: 4000 });
          } else {
            window.setTimeout(startFlintServiceWorker, 2000);
          }
        });
      }
    </script>''';
  }

  bool _isHashedFlintAssetPath(String pathOnly) {
    if (!pathOnly.startsWith('/assets/js/flint-ui/') &&
        !pathOnly.startsWith('/assets/css/flint-ui/')) {
      return false;
    }

    return RegExp(r'\.[a-f0-9]{12}\.[^/]+$').hasMatch(pathOnly);
  }

  String _escapeHtmlAttribute(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  String _escapeHtmlText(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  /// Renders a Mailable email template to HTML preview.
  ///
  /// [mailable] is the Mailable instance to render.
  /// [includePreview] wraps the content in email preview interface if true.
  Response renderEmail(
    ViewMailable mailable, {
    bool includePreview = true,
  }) {
    try {
      raw.statusCode = 200;
      raw.headers.contentType = ContentType.html;

      final html = TemplateEngine().render(
        mailable.view,
        mailable.data,
      );

      raw.write(html);
    } catch (e) {
      raw.statusCode = 500;
      raw.headers.contentType = ContentType.text;
      raw.write('âŒ Failed to render email: ${e.runtimeType}');
      Log.debug('[Flint] Render Email Error: $e');
    }

    close();
    return this;
  }

  /// Sets the HTTP status code for the response without sending content.
  ///
  /// Can be chained with other calls:
  /// ```dart
  /// res.status(404).send('Not Found');
  /// ```
  Response status(int code) {
    raw.statusCode = code;
    return this;
  }

  /// Streams the contents of a [File] directly to the response body.
  ///
  /// Does not set the content type automatically â€” you should set it before calling.
  /// Streams a file to the response, optionally with byte range.
  Future<void> streamFile(File file, {int start = 0, int? end}) async {
    try {
      if (start == 0 && end == null) {
        // Full file stream
        await raw.addStream(file.openRead());
      } else {
        // Range request - read specific bytes
        final rangeStream = _createFileRangeStream(file, start, end);
        await raw.addStream(rangeStream);
      }
    } catch (e) {
      Log.debug('Error streaming file: $e');
      if (!isClosed) {
        raw.statusCode = HttpStatus.internalServerError;
        raw.write('Error serving file');
        await close();
      }
    }
  }

  /// Creates a stream for a specific byte range of a file.
  Stream<List<int>> _createFileRangeStream(
      File file, int start, int? end) async* {
    final raf = await file.open(mode: FileMode.read);
    try {
      await raf.setPosition(start);

      final chunkSize = 64 * 1024; // 64KB chunks
      final maxBytes = end != null ? (end - start + 1) : null;
      var bytesRead = 0;

      while (true) {
        // Calculate how many bytes to read in this chunk
        int bytesToRead;
        if (maxBytes != null) {
          final remaining = maxBytes - bytesRead;
          bytesToRead = remaining > chunkSize ? chunkSize : remaining;
          if (bytesToRead <= 0) break;
        } else {
          bytesToRead = chunkSize;
        }

        final buffer = List<int>.filled(bytesToRead, 0);
        final bytesReadNow = await raf.readInto(buffer, 0, bytesToRead);

        if (bytesReadNow == 0) break;

        // Yield only the portion that was actually read
        yield buffer.sublist(0, bytesReadNow);
        bytesRead += bytesReadNow;

        if (maxBytes != null && bytesRead >= maxBytes) break;
      }
    } finally {
      await raf.close();
    }
  }

  /// Redirects the client to a different [location] (URL or path).
  ///
  /// [status] defaults to `302` (Found). You can use:
  /// - `301` â†’ Permanent Redirect
  /// - `302` â†’ Temporary Redirect
  ///
  /// Example:
  /// ```dart
  /// res.redirect('/login');
  /// res.redirect('https://example.com', status: 301);
  /// ```
  Response redirect(String location, {int status = HttpStatus.found}) {
    try {
      raw.statusCode = status;
      raw.headers.set(HttpHeaders.locationHeader, location);
    } catch (e) {
      raw.statusCode = 500;
      raw.write('âŒ Redirect failed: ${e.runtimeType}');
      Log.debug('[Flint] Redirect Error: $e');
    }
    return this;
  }

  /// Redirects the user to the previous page using the Referer header.
  /// Falls back to [fallback] when Referer is missing.
  Response back({
    String fallback = '/',
    int status = HttpStatus.found,
  }) {
    final refererHeader =
        request?.headers['referer'] ?? request?.headers['Referer'];
    final location = (refererHeader != null && refererHeader.trim().isNotEmpty)
        ? refererHeader
        : fallback;
    return redirect(location, status: status);
  }

  /// Adds a flash message to the next view render.
  Response withFlash(
    String key,
    String message, {
    int maxAgeSeconds = 120,
  }) {
    final normalizedKey = key.trim().toLowerCase();
    if (normalizedKey.isEmpty) return this;
    final cookieName = _flashCookieName(normalizedKey);
    return setCookie(
      cookieName,
      Uri.encodeComponent(message),
      maxAge: maxAgeSeconds,
      path: '/',
      httpOnly: true,
    );
  }

  /// Shortcut for success flash.
  Response withSuccess(String message) => withFlash('success', message);

  /// Shortcut for error flash.
  Response withError(String message) => withFlash('error', message);

  /// Sends a predefined HTTP status message and closes the response.
  ///
  /// Example:
  /// ```dart
  /// res.sendStatus(404); // Sends "Not Found"
  /// ```
  Response sendStatus(int code) {
    final message = _statusMessages[code] ?? 'Status';
    raw.statusCode = code;
    return send(message);
  }

  /// Renders an HTML view from a file.
  ///
  /// [templateName] can be absolute or relative to your project's `views` directory.
  /// Optionally, you can pass [data] for simple variable replacement in the template.

  Future<Response> view(String templateName,
      {Map<String, dynamic>? data}) async {
    // Convert template name (e.g., "schools.register") to file path
    final filePath = templateName.replaceAll('.', Platform.pathSeparator);
    final flintPath = p.join('lib', 'views', '$filePath.flint.html');
    final htmlPath = p.join('lib', 'views', '$filePath.html');

    File? file;

    if (await File(flintPath).exists()) {
      file = File(flintPath);
    } else if (await File(htmlPath).exists()) {
      file = File(htmlPath);
    }

    if (file == null) {
      raw.statusCode = 404;
      raw.write('âŒ View not found: $templateName');
      await raw.close();
      return this;
    }

    String content;
    try {
      final flash = _readFlashFromCookies();
      final mergedData = <String, dynamic>{...(data ?? const {})};
      if (flash.isNotEmpty) {
        mergedData['flash'] = flash;
        for (final entry in flash.entries) {
          mergedData[entry.key] = entry.value;
        }
        TemplateEngine().sessions.addAll(flash);
      }

      // Render template using TemplateEngine
      content = TemplateEngine().render(templateName, mergedData);

      for (final key in flash.keys) {
        clearCookie(_flashCookieName(key));
      }
    } catch (e) {
      // Fallback to raw file content if template rendering fails
      content = await file.readAsString();
    }

    final trimmedContent = content.trimLeft();
    final isFullHtmlDocument =
        RegExp(r'^<!doctype\s+html', caseSensitive: false)
                .hasMatch(trimmedContent) ||
            (RegExp(r'<html[\s>]', caseSensitive: false).hasMatch(content) &&
                RegExp(r'<head[\s>]', caseSensitive: false).hasMatch(content) &&
                RegExp(r'<body[\s>]', caseSensitive: false).hasMatch(content));

    // For partial templates we keep the wrapper used by hot-reload updates.
    // For full HTML documents, do not wrap because it breaks <head>/<meta>.
    if (!isFullHtmlDocument) {
      content = '<div id="main-content">$content</div>';
    }

// Inject hot reload WebSocket script (only for development)
    if (Platform.environment['FLINT_HOT'] == '1') {
      final hotReloadScript = _hotReloadScript();
      if (hotReloadScript.isEmpty) {
        raw.statusCode = 200;
        raw.headers.contentType = ContentType.html;
        raw.write(content);
        await raw.close();
        return this;
      }
      if (isFullHtmlDocument &&
          RegExp(r'</body>', caseSensitive: false).hasMatch(content)) {
        content = content.replaceFirst(
          RegExp(r'</body>', caseSensitive: false),
          '$hotReloadScript</body>',
        );
      } else {
        content += hotReloadScript;
      }
    }

    raw.statusCode = 200;
    raw.headers.contentType = ContentType.html;
    raw.write(content);
    await raw.close();

    return this;
  }

  String _hotReloadScript() {
    if (Platform.environment['FLINT_HOT'] != '1') return '';

    return '''
<script>
let flintHotReloadAttempts = 0;
let flintHotReloadLoggedUnavailable = false;

function connectHotReload() {
  const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  const wsUrl = wsProtocol + '//' + window.location.host + '/flint_reload';
  const socket = new WebSocket(wsUrl);

  function ensureFlintReloadIndicator() {
    let overlay = document.getElementById('flint-hot-reload-indicator');
    if (overlay) return overlay;

    overlay = document.createElement('div');
    overlay.id = 'flint-hot-reload-indicator';
    overlay.setAttribute('role', 'status');
    overlay.setAttribute('aria-live', 'polite');
    overlay.innerHTML = '<span class="flint-hot-reload-spinner"></span><span class="flint-hot-reload-text">Rebuilding Flint UI...</span>';

    const style = document.createElement('style');
    style.textContent = `
      #flint-hot-reload-indicator {
        align-items: center;
        backdrop-filter: blur(14px);
        background: rgba(15, 23, 42, 0.86);
        border: 1px solid rgba(148, 163, 184, 0.28);
        border-radius: 12px;
        box-shadow: 0 18px 45px rgba(15, 23, 42, 0.32);
        color: #ffffff;
        display: none;
        font: 700 13px/1.2 system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        gap: 10px;
        left: 50%;
        max-width: calc(100vw - 32px);
        padding: 12px 14px;
        position: fixed;
        top: 18px;
        transform: translateX(-50%);
        z-index: 2147483647;
      }

      #flint-hot-reload-indicator[data-visible="true"] {
        display: inline-flex;
      }

      .flint-hot-reload-spinner {
        animation: flint-hot-reload-spin 0.75s linear infinite;
        border: 2px solid rgba(255, 255, 255, 0.28);
        border-top-color: #38bdf8;
        border-radius: 999px;
        height: 16px;
        width: 16px;
      }

      @keyframes flint-hot-reload-spin {
        to { transform: rotate(360deg); }
      }
    `;
    document.head.appendChild(style);
    document.body.appendChild(overlay);
    return overlay;
  }

  function showFlintReloadIndicator(message) {
    const overlay = ensureFlintReloadIndicator();
    const text = overlay.querySelector('.flint-hot-reload-text');
    if (text) text.textContent = message || 'Rebuilding Flint UI...';
    overlay.dataset.visible = 'true';
  }

  function normalizeFlintHotReloadMessage(raw) {
    const envelope = JSON.parse(raw);
    const payload = envelope && typeof envelope.data === 'object'
      ? envelope.data
      : {};

    return {
      event: envelope.event || payload.event,
      message: envelope.message || payload.message
    };
  }

  socket.addEventListener('open', () => {
    flintHotReloadAttempts = 0;
    flintHotReloadLoggedUnavailable = false;
    console.log('[FLINT] Hot reload WebSocket connected');
  });

  socket.addEventListener('message', event => {
    try {
      const data = normalizeFlintHotReloadMessage(event.data);
      if (data.event === 'flint:building') {
        console.log('[FLINT] Flint UI rebuild started');
        showFlintReloadIndicator(data.message);
      }
      if (data.event === 'flint:reload') {
        console.log('[FLINT] Hot reload triggered');
        showFlintReloadIndicator('Reloading...');
        window.location.reload();
      }
      if (data.event === 'flint:error') {
        console.error('[FLINT] Flint UI build failed');
        showFlintReloadIndicator(data.message || 'Flint UI build failed.');
      }
    } catch (_) {
      // Ignore non-JSON control frames.
    }
  });

  socket.addEventListener('close', () => {
    flintHotReloadAttempts += 1;
    const retryDelay = Math.min(1000 * flintHotReloadAttempts, 5000);
    if (!flintHotReloadLoggedUnavailable) {
      console.warn('[FLINT] Hot reload WebSocket unavailable, retrying...');
      flintHotReloadLoggedUnavailable = true;
    }
    setTimeout(connectHotReload, retryDelay);
  });

  socket.addEventListener('error', () => {
    socket.close();
  });
}

// start connection
connectHotReload();
</script>


''';
  }

  /// Convert absolute file path to template name relative to views directory

  /// ----------------------------------------
  /// COOKIE SUPPORT
  /// ----------------------------------------

  /// Set a cookie on the response
  Response setCookie(
    String name,
    String value, {
    DateTime? expires,
    int? maxAge,
    String path = '/',
    bool httpOnly = true,
    bool secure = false,
    String sameSite = 'Lax', // Lax, Strict, None
  }) {
    final cookie = StringBuffer()..write('$name=$value; Path=$path;');

    if (expires != null) {
      cookie.write(' Expires=${HttpDate.format(expires)};');
    }

    if (maxAge != null) {
      cookie.write(' Max-Age=$maxAge;');
    }

    if (httpOnly) cookie.write(' HttpOnly;');
    if (secure) cookie.write(' Secure;');
    if (sameSite.isNotEmpty) cookie.write(' SameSite=$sameSite;');

    raw.headers.add('Set-Cookie', cookie.toString());
    return this;
  }

  /// Remove a cookie
  Response clearCookie(
    String name, {
    String path = '/',
  }) {
    raw.headers.add(
      'Set-Cookie',
      '$name=; Path=$path; Expires=Thu, 01 Jan 1970 00:00:00 GMT;',
    );
    return this;
  }

  static String _flashCookieName(String key) => 'FLINT_FLASH_$key';

  Map<String, String> _readFlashFromCookies() {
    final cookies = request?.cookies ?? const <String, String>{};
    final flash = <String, String>{};
    for (final entry in cookies.entries) {
      const prefix = 'FLINT_FLASH_';
      if (!entry.key.startsWith(prefix)) continue;
      final key = entry.key.substring(prefix.length).trim().toLowerCase();
      if (key.isEmpty) continue;
      final value = Uri.decodeComponent(entry.value);
      flash[key] = value;
    }
    return flash;
  }
}

/// Common HTTP status codes and their default messages.
const Map<int, String> _statusMessages = {
  200: 'OK',
  201: 'Created',
  202: 'Accepted',
  204: 'No Content',
  301: 'Moved Permanently',
  302: 'Found',
  304: 'Not Modified',
  400: 'Bad Request',
  401: 'Unauthorized',
  403: 'Forbidden',
  404: 'Not Found',
  405: 'Method Not Allowed',
  409: 'Conflict',
  422: 'Unprocessable Entity',
  500: 'Internal Server Error',
  502: 'Bad Gateway',
  503: 'Service Unavailable',
};
