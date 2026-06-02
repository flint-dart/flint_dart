import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flint_dart/src/context.dart';
import 'package:flint_dart/src/request.dart';
import 'package:flint_dart/src/response.dart' show Response;
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
    return (ctx) async {
      final res = ctx.res;
      if (res == null) {
        return await next(ctx);
      }
      final req = ctx.req;
      // Only handle GET/HEAD requests
      if (req.method != 'GET' && req.method != 'HEAD') {
        return await next(ctx);
      }

      // Ignore known non-static routes
      if (_shouldSkip(req.path)) {
        return await next(ctx);
      }

      // Only static files have extensions
      if (!req.path.contains('.') && req.path != '/') {
        return await next(ctx);
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
        return await next(ctx);
      }

      // Get file stats
      final fileStat = await file.stat();

      // Check file size limit
      if (fileStat.size > maxFileSize) {
        return res.status(413).send('File too large');
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
      final precompressed =
          enableCompression ? _selectPrecompressedFile(req, file, mime) : null;

      // Handle HEAD request
      if (req.method == 'HEAD') {
        if (precompressed != null) {
          final compressedStat = await precompressed.file.stat();
          _setEncodedResponseHeaders(
            res,
            precompressed.encoding,
            compressedStat.size,
          );
        } else {
          res.raw.headers.contentLength = fileStat.size;
        }
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

      if (enableCompression && _canCompress(file.path, mime)) {
        if (precompressed != null) {
          _setEncodedResponseHeaders(
            res,
            precompressed.encoding,
            await precompressed.file.length(),
          );
          await res.streamFile(precompressed.file);
          return res;
        }

        final acceptEncoding =
            req.raw.headers.value(HttpHeaders.acceptEncodingHeader) ?? '';
        if (_acceptsEncoding(acceptEncoding, 'gzip')) {
          final bytes = await file.readAsBytes();
          final compressed = gzip.encode(bytes);
          _setEncodedResponseHeaders(res, 'gzip', compressed.length);
          res.raw.add(compressed);
          await res.close();
          return res;
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

  bool _canCompress(String filePath, String mime) {
    return filePath.endsWith('.js') ||
        filePath.endsWith('.css') ||
        filePath.endsWith('.json') ||
        filePath.endsWith('.svg') ||
        filePath.endsWith('.map') ||
        filePath.endsWith('.deps') ||
        mime.startsWith('text/') ||
        mime.contains('json') ||
        mime.contains('javascript') ||
        mime.contains('xml');
  }

  _EncodedStaticFile? _selectPrecompressedFile(
    Request req,
    File file,
    String mime,
  ) {
    if (!_canCompress(file.path, mime)) return null;
    final acceptEncoding =
        req.raw.headers.value(HttpHeaders.acceptEncodingHeader) ?? '';

    if (_acceptsEncoding(acceptEncoding, 'br')) {
      final brFile = File('${file.path}.br');
      if (brFile.existsSync()) {
        return _EncodedStaticFile(brFile, 'br');
      }
    }

    if (_acceptsEncoding(acceptEncoding, 'gzip')) {
      final gzFile = File('${file.path}.gz');
      if (gzFile.existsSync()) {
        return _EncodedStaticFile(gzFile, 'gzip');
      }
    }

    return null;
  }

  bool _acceptsEncoding(String acceptEncoding, String encoding) {
    final expected = encoding.toLowerCase();
    return acceptEncoding.split(',').any((part) {
      final pieces = part.trim().split(';');
      if (pieces.isEmpty || pieces.first.trim().toLowerCase() != expected) {
        return false;
      }
      for (final parameter in pieces.skip(1)) {
        final trimmed = parameter.trim();
        if (trimmed.startsWith('q=')) {
          final quality = double.tryParse(trimmed.substring(2));
          if (quality != null && quality <= 0) return false;
        }
      }
      return true;
    });
  }

  void _setEncodedResponseHeaders(
    Response res,
    String encoding,
    int contentLength,
  ) {
    res.raw.headers.set(HttpHeaders.varyHeader, 'Accept-Encoding');
    res.raw.headers.set(HttpHeaders.contentEncodingHeader, encoding);
    res.raw.headers.contentLength = contentLength;
  }

  void _setCacheHeaders(Response res, String eTag, DateTime lastModified,
      Duration duration, String filePath) {
    final shouldBypass =
        Platform.environment['FLINT_HOT'] == '1' || filePath.endsWith('-sw.js');
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

class _EncodedStaticFile {
  final File file;
  final String encoding;

  _EncodedStaticFile(this.file, this.encoding);
}
