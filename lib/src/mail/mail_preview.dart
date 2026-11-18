import 'dart:io';

import 'package:flint_dart/mail.dart';
import 'package:flint_dart/src/request.dart';
import 'package:flint_dart/src/response.dart';
import 'package:path/path.dart' as p;

/// Registry contract for application mailables used in live email previews.
///
/// Optional: Flint automatically discovers `.flint.html` templates and
/// `ViewMailable` classes in `lib/mail`, or you can register mailables
/// explicitly via [MailRegistry] or [MailPreviewRegistry].
abstract class MailRegistry {
  const MailRegistry();

  Iterable<ViewMailable> get mailables;

  void registerMailables() {
    MailPreviewRegistry.registerAll(mailables);
  }
}

/// Manages registered and auto-discovered [ViewMailable] previews.
class MailPreviewRegistry {
  static final Map<String, ViewMailable> _registered = {};

  /// Registers a [ViewMailable] instance for `/mail/preview/:name`.
  static void register(ViewMailable mailable, {String? name}) {
    final primarySlug = normalizeSlug(name ?? mailable.previewName ?? mailable.view);
    if (primarySlug.isNotEmpty) {
      _registered[primarySlug] = mailable;
      final reversed = _reverseTwoPartSlug(primarySlug);
      if (reversed != null) {
        _registered.putIfAbsent(reversed, () => mailable);
      }
    }

    final viewSlug = normalizeSlug(mailable.view);
    if (viewSlug.isNotEmpty) {
      _registered.putIfAbsent(viewSlug, () => mailable);
      final reversed = _reverseTwoPartSlug(viewSlug);
      if (reversed != null) {
        _registered.putIfAbsent(reversed, () => mailable);
      }
    }

    final typeSlug = normalizeSlug(
      mailable.runtimeType.toString().replaceAll(RegExp(r'Mail$'), ''),
    );
    if (typeSlug.isNotEmpty && !typeSlug.startsWith('-')) {
      _registered.putIfAbsent(typeSlug, () => mailable);
    }
  }

  /// Registers multiple [ViewMailable] instances.
  static void registerAll(Iterable<ViewMailable> mailables) {
    for (final mailable in mailables) {
      register(mailable);
    }
  }

  /// Clears explicitly registered mailables.
  static void clear() {
    _registered.clear();
  }

  /// Normalizes a view path, class name, or URL segment to a kebab-case slug.
  static String normalizeSlug(String raw) {
    var value = raw.trim().replaceAll('\\', '/');
    if (value.contains('/')) {
      value = value.split('/').last;
    }
    if (value.endsWith('.flint.html')) {
      value = value.substring(0, value.length - '.flint.html'.length);
    } else if (value.endsWith('.html')) {
      value = value.substring(0, value.length - '.html'.length);
    } else if (value.endsWith('_mail.dart')) {
      value = value.substring(0, value.length - '_mail.dart'.length);
    } else if (value.endsWith('.dart')) {
      value = value.substring(0, value.length - '.dart'.length);
    }

    value = value.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m[1]}-${m[2]}',
    );
    value = value
        .toLowerCase()
        .replaceAll(RegExp(r'[_\s]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return value;
  }

  static String? _reverseTwoPartSlug(String slug) {
    final parts = slug.split('-');
    if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[1]}-${parts[0]}';
    }
    return null;
  }

  /// Resolves a [ViewMailable] for `:name` by checking registered instances
  /// first, then auto-discovering `lib/mail` classes and `.flint.html` views.
  static ViewMailable? resolve(
    String rawName, {
    String rootPath = 'lib',
    Map<String, dynamic>? queryOverrides,
  }) {
    final slug = normalizeSlug(rawName);
    if (slug.isEmpty) return null;

    // 1. Check explicitly registered ViewMailable instances
    final registered = _registered[slug] ??
        (_reverseTwoPartSlug(slug) != null
            ? _registered[_reverseTwoPartSlug(slug)!]
            : null);
    if (registered != null) {
      // Also check if the corresponding dart source file has updated previewData
      final discovered = _discoverEntries(rootPath: rootPath)[slug] ??
          (_reverseTwoPartSlug(slug) != null
              ? _discoverEntries(rootPath: rootPath)[_reverseTwoPartSlug(slug)!]
              : null);
      final mergedData = <String, dynamic>{
        ...registered.resolvePreviewData(),
        if (discovered != null) ...discovered.previewData,
        if (queryOverrides != null) ...queryOverrides,
      };
      return _DynamicPreviewMail(
        subjectLine: registered.subject,
        templateViewPath: registered.view,
        payload: mergedData,
        previewSlug: slug,
      );
    }

    // 2. Auto-discover from disk (lib/mail/*.dart and lib/mail/views/*.flint.html)
    final entries = _discoverEntries(rootPath: rootPath);
    final entry = entries[slug] ??
        (_reverseTwoPartSlug(slug) != null
            ? entries[_reverseTwoPartSlug(slug)!]
            : null);
    if (entry == null) return null;

    final mergedData = <String, dynamic>{
      ...entry.previewData,
      if (queryOverrides != null) ...queryOverrides,
    };

    return _DynamicPreviewMail(
      subjectLine: _interpolateSubject(entry.subject, mergedData),
      templateViewPath: entry.viewPath,
      payload: mergedData,
      previewSlug: entry.slug,
    );
  }

  /// Handles `GET /mail/preview` (lists all available mail previews).
  static Future<Response> handleIndex(
    Request req,
    Response res, {
    String rootPath = 'lib',
  }) async {
    final entries = _discoverAllUniqueEntries(rootPath: rootPath);
    if (entries.isEmpty) {
      return res.status(404).send(
        '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Flint Mail Previews</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f8fafc; color: #0f172a; padding: 40px 20px; margin: 0; }
    .card { max-width: 640px; margin: 0 auto; background: #fff; border: 1px solid #e2e8f0; border-radius: 10px; padding: 32px; }
    code { background: #f1f5f9; padding: 2px 6px; border-radius: 4px; font-size: 13px; }
  </style>
</head>
<body>
  <div class="card">
    <h2>No Email Templates Found</h2>
    <p>Create a mail template in <code>lib/mail/views/*.flint.html</code> or run:</p>
    <p><code>flint --make-mail reset_password</code></p>
  </div>
</body>
</html>
''',
        contentType: 'text/html',
      );
    }

    final itemsHtml = entries.map((e) {
      final classBadge = e.className != null
          ? '<span class="badge">${_escapeHtml(e.className!)}</span>'
          : '';
      final keysList = e.previewData.keys.isEmpty
          ? '<em>No previewData variables</em>'
          : e.previewData.keys.map((k) => '<code>${_escapeHtml(k)}</code>').join(' ');
      return '''
      <li class="item">
        <div class="item-main">
          <a class="item-title" href="/mail/preview/${e.slug}">/mail/preview/${e.slug}</a>
          $classBadge
          <div class="item-meta">View: <code>${_escapeHtml(e.viewPath)}</code></div>
          <div class="item-vars">Preview data: $keysList</div>
        </div>
        <a class="btn" href="/mail/preview/${e.slug}">Open Preview &rarr;</a>
      </li>
      ''';
    }).join('\n');

    final html = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Flint Mail Previews</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f8fafc; color: #0f172a; padding: 40px 20px; margin: 0; }
    .container { max-width: 760px; margin: 0 auto; }
    .header { margin-bottom: 24px; }
    .header h1 { margin: 0 0 8px; font-size: 24px; }
    .header p { margin: 0; color: #475569; font-size: 14px; }
    .list { list-style: none; padding: 0; margin: 0; display: grid; gap: 12px; }
    .item { background: #fff; border: 1px solid #e2e8f0; border-radius: 10px; padding: 18px 20px; display: flex; align-items: center; justify-content: space-between; gap: 16px; }
    .item-title { font-weight: 700; font-size: 16px; color: #0284c7; text-decoration: none; margin-right: 8px; }
    .item-title:hover { text-decoration: underline; }
    .badge { display: inline-block; background: #e0f2fe; color: #0369a1; font-size: 12px; font-weight: 600; padding: 2px 8px; border-radius: 999px; }
    .item-meta { font-size: 13px; color: #64748b; margin-top: 6px; }
    .item-vars { font-size: 12px; color: #64748b; margin-top: 6px; }
    code { background: #f1f5f9; padding: 2px 6px; border-radius: 4px; font-size: 12px; color: #334155; }
    .btn { background: #0f172a; color: #fff; text-decoration: none; font-size: 13px; font-weight: 600; padding: 8px 14px; border-radius: 6px; white-space: nowrap; }
    .btn:hover { background: #1e293b; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Flint Mail Previews</h1>
      <p>Select any template below to preview it live. Edit <code>previewData</code> in your <code>ViewMailable</code> class or edit the <code>.flint.html</code> template and refresh.</p>
    </div>
    <ul class="list">
      $itemsHtml
    </ul>
  </div>
</body>
</html>
''';

    return res.send(html, contentType: 'text/html');
  }

  /// Handles `GET /mail/preview/:name`.
  static Future<Response> handlePreview(
    Request req,
    Response res, {
    String rootPath = 'lib',
  }) async {
    final name = req.params['name']?.trim() ?? '';
    if (name.isEmpty) {
      return handleIndex(req, res, rootPath: rootPath);
    }

    final mailable = resolve(
      name,
      rootPath: rootPath,
    );

    if (mailable == null) {
      final available = _discoverAllUniqueEntries(rootPath: rootPath)
          .map((e) => '/mail/preview/${e.slug}')
          .toList();
      return res.status(404).json({
        'message': 'Mail preview "$name" not found.',
        'availablePreviews': available,
      });
    }

    return res.renderEmail(mailable, includePreview: true);
  }

  static List<_DiscoveredMailEntry> _discoverAllUniqueEntries({
    String rootPath = 'lib',
  }) {
    final map = _discoverEntries(rootPath: rootPath);
    final uniqueBySlug = <String, _DiscoveredMailEntry>{};
    for (final entry in map.values) {
      uniqueBySlug.putIfAbsent(entry.slug, () => entry);
    }
    for (final entry in _registered.entries) {
      final mailable = entry.value;
      final primarySlug =
          normalizeSlug(mailable.previewName ?? mailable.view);
      uniqueBySlug.putIfAbsent(
        primarySlug,
        () => _DiscoveredMailEntry(
          slug: primarySlug,
          viewPath: mailable.view,
          className: mailable.runtimeType.toString(),
          subject: mailable.subject,
          previewData: mailable.resolvePreviewData(),
        ),
      );
    }
    final list = uniqueBySlug.values.toList()
      ..sort((a, b) => a.slug.compareTo(b.slug));
    return list;
  }

  static Map<String, _DiscoveredMailEntry> _discoverEntries({
    String rootPath = 'lib',
  }) {
    final cwd = Directory.current.path;
    final viewRoots = <String>{
      p.join(cwd, rootPath, 'mail', 'views'),
      p.join(cwd, 'lib', 'mail', 'views'),
      if (FlintViewPathLookup.customViewPath.isNotEmpty)
        FlintViewPathLookup.customViewPath,
    };

    final mailClassRoots = <String>{
      p.join(cwd, rootPath, 'mail'),
      p.join(cwd, 'lib', 'mail'),
    };

    // 1. Parse all *_mail.dart / ViewMailable files in lib/mail
    final parsedClasses = <_ParsedMailClass>[];
    for (final dirPath in mailClassRoots) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final parsed = _parseMailDartFile(entity);
        if (parsed != null) {
          parsedClasses.add(parsed);
        }
      }
    }

    final result = <String, _DiscoveredMailEntry>{};

    // 2. Discover all .flint.html / .html files in lib/mail/views
    for (final dirPath in viewRoots) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;

      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File) continue;
        final normalizedPath = entity.path.replaceAll('\\', '/');
        if (!normalizedPath.endsWith('.flint.html') &&
            !normalizedPath.endsWith('.html')) {
          continue;
        }

        final slug = normalizeSlug(normalizedPath);
        if (slug.isEmpty) continue;

        // Match with parsed ViewMailable class if present
        _ParsedMailClass? matchedClass;
        for (final candidate in parsedClasses) {
          if (candidate.viewSlug == slug || candidate.fileSlug == slug) {
            matchedClass = candidate;
            break;
          }
        }

        // Compute relative view path (e.g. mail/views/password_reset.flint.html)
        final viewPath = matchedClass?.viewPath ??
            _relativeViewPath(entity.path, cwd, rootPath);

        final templateContent = entity.readAsStringSync();
        final defaultVars = _extractDefaultTemplateVariables(
          templateContent,
          slug: slug,
        );

        final previewData = <String, dynamic>{
          ...defaultVars,
          if (matchedClass != null) ...matchedClass.previewData,
        };

        final entry = _DiscoveredMailEntry(
          slug: slug,
          viewPath: viewPath,
          className: matchedClass?.className,
          subject: matchedClass?.subject ?? 'Preview: $slug',
          previewData: previewData,
        );

        result[slug] = entry;
        final reversed = _reverseTwoPartSlug(slug);
        if (reversed != null) {
          result.putIfAbsent(reversed, () => entry);
        }
        if (matchedClass != null && matchedClass.previewName != null) {
          final customSlug = normalizeSlug(matchedClass.previewName!);
          if (customSlug.isNotEmpty) {
            result[customSlug] = entry;
          }
        }
      }
    }

    return result;
  }

  static String _relativeViewPath(
      String fullPath, String cwd, String rootPath) {
    final libPath = p.join(cwd, rootPath);
    if (p.isWithin(libPath, fullPath)) {
      return p.relative(fullPath, from: libPath).replaceAll('\\', '/');
    }
    final defaultLib = p.join(cwd, 'lib');
    if (p.isWithin(defaultLib, fullPath)) {
      return p.relative(fullPath, from: defaultLib).replaceAll('\\', '/');
    }
    return fullPath.replaceAll('\\', '/');
  }

  /// Extracts `view`, `subject`, `previewName`, and `previewData` (with `data`
  /// literal fallback) from a `ViewMailable` Dart source file.
  static _ParsedMailClass? _parseMailDartFile(File file) {
    String source;
    try {
      source = file.readAsStringSync();
    } catch (_) {
      return null;
    }

    if (!source.contains('ViewMailable')) return null;

    final classMatch =
        RegExp(r'class\s+(\w+)\s+extends\s+ViewMailable').firstMatch(source);
    final className = classMatch?.group(1);

    final viewMatch = RegExp(
      r'''String\s+get\s+view\s*=>\s*(['"])([^'"]+)\1''',
    ).firstMatch(source);
    final viewPath = viewMatch?.group(2);

    final previewNameMatch = RegExp(
      r'''String\??\s+get\s+previewName\s*=>\s*(['"])([^'"]+)\1''',
    ).firstMatch(source);
    final previewName = previewNameMatch?.group(2);

    final subjectMatch = RegExp(
      r'''String\s+get\s+subject\s*=>\s*(['"])([^'"]+)\1''',
    ).firstMatch(source);
    final subject = subjectMatch?.group(2) ?? className ?? 'Email Preview';

    final fieldDefaults = _extractConstructorFieldDefaults(source);
    final dataMap = _extractGetterMap(source, 'data', fieldDefaults);
    final previewDataMap =
        _extractGetterMap(source, 'previewData', fieldDefaults);

    final merged = <String, dynamic>{
      ...fieldDefaults,
      ...dataMap,
      ...previewDataMap,
    };

    return _ParsedMailClass(
      className: className,
      fileSlug: normalizeSlug(file.path),
      viewPath: viewPath,
      viewSlug: viewPath != null ? normalizeSlug(viewPath) : null,
      previewName: previewName,
      subject: subject,
      previewData: merged,
    );
  }

  /// Extracts default values assigned in a constructor parameter list, e.g.
  /// `this.recipientName = 'Abubakar Ibrahim'`.
  static Map<String, dynamic> _extractConstructorFieldDefaults(String source) {
    final result = <String, dynamic>{};
    final paramDefaultRegex = RegExp(
      r'''this\.(\w+)\s*=\s*(['"][^'"]*['"]|\d+(?:\.\d+)?|true|false)''',
    );
    for (final match in paramDefaultRegex.allMatches(source)) {
      final key = match.group(1);
      final rawVal = match.group(2);
      if (key != null && rawVal != null) {
        final parsed = _parseDartExpression(rawVal, result);
        if (parsed != null) {
          result[key] = parsed;
        }
      }
    }
    return result;
  }

  /// Extracts a `Map<String, dynamic> get <getterName> => { ... }` or
  /// `Map<String, dynamic> get <getterName> { return { ... }; }` block.
  static Map<String, dynamic> _extractGetterMap(
    String source,
    String getterName,
    Map<String, dynamic> contextVars,
  ) {
    final getterPattern = RegExp(
      'Map\\s*<[^>]+>\\s+get\\s+$getterName\\b[^{]*\\{',
      multiLine: true,
    );
    final match = getterPattern.firstMatch(source);
    if (match == null) return const {};

    var openBraceIndex = match.end - 1;
    // Check if it's a block body `{ return { ... }; }` vs expression `=> { ... };`
    final headerText = source.substring(match.start, match.end);
    if (!headerText.contains('=>')) {
      final returnBrace = source.indexOf('{', match.end);
      if (returnBrace == -1) return const {};
      openBraceIndex = returnBrace;
    }

    final mapBody = _extractBalancedBraces(source, openBraceIndex);
    if (mapBody == null) return const {};

    return _parseMapLiteralBody(mapBody, contextVars);
  }

  static String? _extractBalancedBraces(String source, int openBraceIndex) {
    if (openBraceIndex < 0 ||
        openBraceIndex >= source.length ||
        source[openBraceIndex] != '{') {
      return null;
    }
    var depth = 0;
    String? activeQuote;
    var escaped = false;

    for (var i = openBraceIndex; i < source.length; i++) {
      final ch = source[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch == '\\') {
        escaped = true;
        continue;
      }
      if (activeQuote != null) {
        if (ch == activeQuote) {
          activeQuote = null;
        }
        continue;
      }
      if (ch == "'" || ch == '"') {
        activeQuote = ch;
        continue;
      }
      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) {
          return source.substring(openBraceIndex + 1, i);
        }
      }
    }
    return null;
  }

  static Map<String, dynamic> _parseMapLiteralBody(
    String body,
    Map<String, dynamic> contextVars,
  ) {
    final result = <String, dynamic>{};
    final entries = _splitTopLevelCommaEntries(body);
    final combinedContext = <String, dynamic>{...contextVars};

    for (final rawEntry in entries) {
      final entry = rawEntry.trim();
      if (entry.isEmpty || entry.startsWith('//')) continue;

      final colonIndex = _findTopLevelColon(entry);
      if (colonIndex <= 0) continue;

      final rawKey = entry.substring(0, colonIndex).trim();
      final rawValue = entry.substring(colonIndex + 1).trim();

      final key = _unquoteString(rawKey);
      if (key == null || key.isEmpty) continue;

      final value = _parseDartExpression(rawValue, combinedContext);
      if (value != null) {
        result[key] = value;
        combinedContext[key] = value;
      }
    }

    return result;
  }

  static List<String> _splitTopLevelCommaEntries(String body) {
    final cleanedLines = body
        .split('\n')
        .map((line) {
          var inQuote = '';
          for (var i = 0; i < line.length - 1; i++) {
            final c = line[i];
            if ((c == "'" || c == '"') && (i == 0 || line[i - 1] != '\\')) {
              if (inQuote.isEmpty) {
                inQuote = c;
              } else if (inQuote == c) {
                inQuote = '';
              }
            }
            if (inQuote.isEmpty && line[i] == '/' && line[i + 1] == '/') {
              return line.substring(0, i);
            }
          }
          return line;
        })
        .join('\n');

    final parts = <String>[];
    var start = 0;
    var braceDepth = 0;
    var bracketDepth = 0;
    var parenDepth = 0;
    String? quote;
    var escaped = false;

    for (var i = 0; i < cleanedLines.length; i++) {
      final ch = cleanedLines[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch == '\\') {
        escaped = true;
        continue;
      }
      if (quote != null) {
        if (ch == quote) quote = null;
        continue;
      }
      if (ch == "'" || ch == '"') {
        quote = ch;
        continue;
      }
      if (ch == '{') braceDepth++;
      if (ch == '}') braceDepth--;
      if (ch == '[') bracketDepth++;
      if (ch == ']') bracketDepth--;
      if (ch == '(') parenDepth++;
      if (ch == ')') parenDepth--;

      if (ch == ',' &&
          braceDepth == 0 &&
          bracketDepth == 0 &&
          parenDepth == 0) {
        parts.add(cleanedLines.substring(start, i));
        start = i + 1;
      }
    }
    if (start < cleanedLines.length) {
      parts.add(cleanedLines.substring(start));
    }
    return parts;
  }

  static int _findTopLevelColon(String entry) {
    String? quote;
    var escaped = false;
    for (var i = 0; i < entry.length; i++) {
      final ch = entry[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch == '\\') {
        escaped = true;
        continue;
      }
      if (quote != null) {
        if (ch == quote) quote = null;
        continue;
      }
      if (ch == "'" || ch == '"') {
        quote = ch;
        continue;
      }
      if (ch == ':') return i;
    }
    return -1;
  }

  static String? _unquoteString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length >= 2) {
      final first = trimmed[0];
      final last = trimmed[trimmed.length - 1];
      if ((first == "'" && last == "'") || (first == '"' && last == '"')) {
        return trimmed
            .substring(1, trimmed.length - 1)
            .replaceAll(r"\'", "'")
            .replaceAll(r'\"', '"')
            .replaceAll(r'\$', r'$');
      }
    }
    return null;
  }

  static dynamic _parseDartExpression(
    String expr,
    Map<String, dynamic> contextVars,
  ) {
    final trimmed = expr.trim();
    if (trimmed.isEmpty) return null;

    // String literal (including adjacent string literals)
    final unquoted = _unquoteString(trimmed);
    if (unquoted != null) {
      return _interpolateString(unquoted, contextVars);
    }

    if (trimmed == 'DateTime.now().year') {
      return DateTime.now().year;
    }
    if (trimmed == 'DateTime.now().toIso8601String()') {
      return DateTime.now().toIso8601String();
    }
    if (trimmed == 'true') return true;
    if (trimmed == 'false') return false;

    final intVal = int.tryParse(trimmed);
    if (intVal != null) return intVal;

    final doubleVal = double.tryParse(trimmed);
    if (doubleVal != null) return doubleVal;

    // Nested map literal
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return _parseMapLiteralBody(
        trimmed.substring(1, trimmed.length - 1),
        contextVars,
      );
    }

    // List literal
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      final inner = trimmed.substring(1, trimmed.length - 1);
      return _splitTopLevelCommaEntries(inner)
          .map((e) => _parseDartExpression(e, contextVars))
          .where((e) => e != null)
          .toList();
    }

    // Variable reference to known context variable
    if (contextVars.containsKey(trimmed)) {
      return contextVars[trimmed];
    }

    return null;
  }

  static String _interpolateString(
    String input,
    Map<String, dynamic> vars,
  ) {
    return input.replaceAllMapped(
      RegExp(r'\$\{?([a-zA-Z_]\w*)\}?'),
      (match) {
        final key = match.group(1);
        if (key == 'DateTime') return match.group(0)!;
        if (key != null && vars.containsKey(key)) {
          return '${vars[key]}';
        }
        return match.group(0)!;
      },
    );
  }

  static String _interpolateSubject(
    String subject,
    Map<String, dynamic> vars,
  ) {
    return _interpolateString(subject, vars);
  }

  /// Scans `.flint.html` for `{{ variableName }}` placeholders and generates
  /// sensible fallback values for any variable not explicitly set in `previewData`.
  static Map<String, dynamic> _extractDefaultTemplateVariables(
    String templateContent, {
    required String slug,
  }) {
    final defaults = <String, dynamic>{
      'currentYear': DateTime.now().year,
      'recipientName': 'Preview User',
      'recipientEmail': 'preview@example.com',
    };

    final varMatches = RegExp(r'\{\{\s*([a-zA-Z_][\w.]*)\s*\}\}')
        .allMatches(templateContent);

    for (final match in varMatches) {
      final key = match.group(1);
      if (key == null || defaults.containsKey(key)) continue;
      final lower = key.toLowerCase();
      if (lower.contains('code') || lower.contains('otp')) {
        defaults[key] = '849201';
      } else if (lower.contains('link') || lower.contains('url')) {
        defaults[key] = 'http://localhost:8080/$slug?code=849201';
      } else if (lower.contains('email')) {
        defaults[key] = 'preview@example.com';
      } else if (lower.contains('name')) {
        defaults[key] = 'Preview User';
      } else if (lower.contains('year')) {
        defaults[key] = DateTime.now().year;
      } else {
        defaults[key] = 'Sample $key';
      }
    }

    return defaults;
  }

  static String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}

/// Internal lookup helper so [MailPreviewRegistry] can check `Flint.viewPath`
/// without creating a circular import.
class FlintViewPathLookup {
  static String customViewPath = '';
}

class _DiscoveredMailEntry {
  final String slug;
  final String viewPath;
  final String? className;
  final String subject;
  final Map<String, dynamic> previewData;

  const _DiscoveredMailEntry({
    required this.slug,
    required this.viewPath,
    required this.className,
    required this.subject,
    required this.previewData,
  });
}

class _ParsedMailClass {
  final String? className;
  final String fileSlug;
  final String? viewPath;
  final String? viewSlug;
  final String? previewName;
  final String subject;
  final Map<String, dynamic> previewData;

  const _ParsedMailClass({
    required this.className,
    required this.fileSlug,
    required this.viewPath,
    required this.viewSlug,
    required this.previewName,
    required this.subject,
    required this.previewData,
  });
}

class _DynamicPreviewMail extends ViewMailable {
  final String subjectLine;
  final String templateViewPath;
  final Map<String, dynamic> payload;
  final String previewSlug;

  _DynamicPreviewMail({
    required this.subjectLine,
    required this.templateViewPath,
    required this.payload,
    required this.previewSlug,
  });

  @override
  String get subject => subjectLine;

  @override
  String get view => templateViewPath;

  @override
  String? get previewName => previewSlug;

  @override
  Map<String, dynamic> get data => payload;

  @override
  Map<String, dynamic> get previewData => payload;

  @override
  List<String> get to =>
      [payload['recipientEmail']?.toString() ?? 'preview@example.com'];
}

