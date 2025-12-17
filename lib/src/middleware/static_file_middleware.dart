import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flint_dart/src/request.dart';
import 'package:flint_dart/src/response.dart' show Response;
import 'package:flint_dart/src/routing/router.dart' show Handler;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

import 'middleware.dart';

class StaticFileMiddleware extends Middleware {
  final String publicFolder;
  final Duration cacheDuration;
  final int maxFileSize; // in bytes
  final bool enableCompression;
  final bool enableRangeRequests;

  StaticFileMiddleware({
    this.publicFolder = 'public',
    this.cacheDuration = const Duration(days: 30),
    this.maxFileSize = 100 * 1024 * 1024, // 100MB default
    this.enableCompression = true,
    this.enableRangeRequests = true,
  });

  @override
  Handler handle(Handler next) {
    return (Request req, Response res) async {
      // Only handle GET/HEAD requests
      if (req.method != 'GET' && req.method != 'HEAD') {
        return await next(req, res);
      }

      // Ignore known non-static routes
      if (_shouldSkip(req.path)) {
        return await next(req, res);
      }

      // Only static files have extensions
      if (!req.path.contains('.') && req.path != '/') {
        return await next(req, res);
      }

      // Handle root path
      String relativePath = req.path;
      if (relativePath == '/') {
        relativePath = '/index.html';
      }
      if (relativePath.startsWith('/')) {
        relativePath = relativePath.substring(1);
      }

      final filePath = path.join(publicFolder, relativePath);
      final file = File(filePath);

      if (!await file.exists()) {
        return await next(req, res);
      }

      // Get file stats
      final fileStat = await file.stat();

      // Check file size limit
      if (fileStat.size > maxFileSize) {
        res.status(413).send('File too large');
        return res;
      }

      // Cache headers
      final lastModified = await file.lastModified();
      final eTag = _generateETag(fileStat);

      // Check conditional requests
      if (_isCacheValid(req, eTag, lastModified)) {
        res.raw.statusCode = HttpStatus.notModified;
        return res;
      }

      // Set cache headers
      _setCacheHeaders(res, eTag, lastModified, cacheDuration, req.path);

      // Security headers
      _setSecurityHeaders(res);

      // MIME type with charset for text files
      final mime = lookupMimeType(file.path) ?? 'application/octet-stream';
      _setContentType(res, mime, file.path);

      // Handle HEAD request
      if (req.method == 'HEAD') {
        res.raw.headers.contentLength = fileStat.size;
        return res;
      }

      // Handle range requests
      if (enableRangeRequests) {
        final rangeResponse =
            await _handleRangeRequest(req, res, file, fileStat.size, mime);
        if (rangeResponse != null) {
          return rangeResponse;
        }
      }

      // Send full file
      await res.streamFile(file);
      return res;
    };
  }

  bool _shouldSkip(String path) {
    final skipPrefixes = [
      '/api',
      '/ws',
      '/docs',
      '/swagger',
      '/.well-known',
      '/admin',
      '/graphql',
      '/graphiql',
    ];
    return skipPrefixes.any((prefix) => path.startsWith(prefix));
  }

  String _generateETag(FileStat stat) {
    final tag = '${stat.modified.millisecondsSinceEpoch}-${stat.size}';
    return base64Encode(utf8.encode(tag)).replaceAll('/', '_');
  }

  bool _isCacheValid(Request req, String eTag, DateTime lastModified) {
    final ifNoneMatch = req.raw.headers.value(HttpHeaders.ifNoneMatchHeader);
    if (ifNoneMatch == eTag) return true;

    final ifModifiedSince =
        req.raw.headers.value(HttpHeaders.ifModifiedSinceHeader);
    if (ifModifiedSince != null) {
      try {
        final clientDate = HttpDate.parse(ifModifiedSince);
        return !lastModified.isAfter(clientDate);
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  void _setCacheHeaders(Response res, String eTag, DateTime lastModified,
      Duration duration, String filePath) {
    // Files you want to bypass caching (e.g., for dev)
    final bypassCacheExtensions = ['.css', '.js', '.map'];

    // Check if file should bypass caching
    final shouldBypass =
        bypassCacheExtensions.any((ext) => filePath.endsWith(ext));

    final cacheDuration = shouldBypass ? Duration(seconds: 0) : duration;

    res.raw.headers.set(HttpHeaders.etagHeader, eTag);
    res.raw.headers
        .set(HttpHeaders.lastModifiedHeader, HttpDate.format(lastModified));
    res.raw.headers.set(
        HttpHeaders.cacheControlHeader,
        shouldBypass
            ? 'no-cache, no-store, must-revalidate'
            : 'public, max-age=${cacheDuration.inSeconds}, immutable');
  }

  void _setSecurityHeaders(Response res) {
    res.raw.headers.set('X-Content-Type-Options', 'nosniff');
    res.raw.headers.set('X-Frame-Options', 'DENY');
    res.raw.headers.set('X-XSS-Protection', '1; mode=block');
    res.raw.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  }

  void _setContentType(Response res, String mime, String filePath) {
    if (filePath.endsWith('.css')) {
      res.raw.headers.contentType =
          ContentType('text', 'css', charset: 'utf-8');
      return;
    }
    if (mime.startsWith('text/') ||
        mime.contains('javascript') ||
        mime.contains('json') ||
        mime.contains('xml')) {
      res.raw.headers.contentType = ContentType.parse('$mime; charset=utf-8');
    } else {
      res.raw.headers.contentType = ContentType.parse(mime);
    }
  }

  Future<Response?> _handleRangeRequest(
      Request req, Response res, File file, int fileSize, String mime) async {
    final rangeHeader = req.raw.headers.value(HttpHeaders.rangeHeader);
    if (rangeHeader == null || fileSize == 0) return null;

    final ranges = _parseRanges(rangeHeader, fileSize);
    if (ranges.isEmpty) return null;

    // For simplicity, handle single range only
    if (ranges.length == 1) {
      final range = ranges.first;
      res.raw.statusCode = HttpStatus.partialContent;
      res.raw.headers.set(HttpHeaders.contentRangeHeader,
          'bytes ${range.start}-${range.end}/$fileSize');
      res.raw.headers.contentLength = range.end - range.start + 1;

      await res.streamFile(file, start: range.start, end: range.end);
      return res;
    }

    // Multiple ranges require multipart/byteranges - skip for simplicity
    return null;
  }

  List<FileRange> _parseRanges(String rangeHeader, int fileSize) {
    if (!rangeHeader.startsWith('bytes=')) return [];

    final ranges = <FileRange>[];
    final rangeParts = rangeHeader.substring(6).split(',');

    for (final part in rangeParts) {
      final trimmed = part.trim();
      final dashIndex = trimmed.indexOf('-');

      if (dashIndex == -1) continue;

      try {
        final startStr = trimmed.substring(0, dashIndex);
        final endStr = trimmed.substring(dashIndex + 1);

        if (startStr.isEmpty && endStr.isNotEmpty) {
          // Format: "-500" (last 500 bytes)
          final suffix = int.parse(endStr);
          final start = max(0, fileSize - suffix);
          final end = fileSize - 1;
          if (start < fileSize) {
            ranges.add(FileRange(start, end));
          }
        } else if (startStr.isNotEmpty && endStr.isEmpty) {
          // Format: "500-" (from byte 500 to end)
          final start = int.parse(startStr);
          if (start < fileSize) {
            ranges.add(FileRange(start, fileSize - 1));
          }
        } else if (startStr.isNotEmpty && endStr.isNotEmpty) {
          // Format: "500-999"
          final start = int.parse(startStr);
          final end = int.parse(endStr);
          if (start <= end && end < fileSize) {
            ranges.add(FileRange(start, end));
          }
        }
      } catch (_) {
        continue;
      }
    }

    return ranges;
  }
}

class FileRange {
  final int start;
  final int end;

  FileRange(this.start, this.end);
}
