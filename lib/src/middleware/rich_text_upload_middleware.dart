import 'dart:convert';
import 'dart:io';
import 'package:flint_dart/flint_dart.dart';

class RichTextUpload extends Middleware {
  final String uploadPath;
  final String urlPrefix;
  final bool requireAuth;

  RichTextUpload({
    this.uploadPath = 'public/uploads/content',
    this.urlPrefix = '/uploads/content',
    this.requireAuth = true,
  });

  @override
  Handler handle(Handler next) {
    return (ctx) async {
      final req = ctx.req;
      final res = ctx.res;

      if (res == null) return await next(ctx);

      if (req.method == 'POST' && req.path == '/api/content-media/upload') {
        if (requireAuth) {
          final user = await req.user;
          if (user == null) {
            return await res.json(
              {'status': false, 'message': 'Unauthorized'},
              status: 401,
            );
          }
        }

        try {
          final body = await req.json();
          final filename = body['filename']?.toString().trim();
          final base64Data = body['base64']?.toString();

          if (filename == null ||
              filename.isEmpty ||
              base64Data == null ||
              base64Data.isEmpty) {
            return await res.json(
              {'status': false, 'message': 'Missing required fields'},
              status: 400,
            );
          }

          final dir = Directory(uploadPath);
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }

          final rawSafeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
          final lastDot = rawSafeName.lastIndexOf('.');
          if (lastDot == -1 || lastDot == 0 || lastDot == rawSafeName.length - 1) {
            return await res.json(
              {'status': false, 'message': 'Invalid file name or extension'},
              status: 400,
            );
          }

          final ext = rawSafeName.substring(lastDot).toLowerCase();
          const allowedExtensions = {
            // Images
            '.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg',
            // Videos
            '.mp4', '.webm', '.ogg', '.mov', '.avi', '.mkv',
            // Audio
            '.mp3', '.wav', '.m4a',
            // Documents
            '.pdf', '.txt', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
          };
          if (!allowedExtensions.contains(ext)) {
            return await res.json(
              {'status': false, 'message': 'Forbidden file type: $ext'},
              status: 400,
            );
          }

          final baseName = rawSafeName.substring(0, lastDot).replaceAll('.', '_');
          final safeName = '$baseName$ext';

          final bytes = base64Decode(base64Data);
          final targetFile = File('${dir.path}/$safeName');
          await targetFile.writeAsBytes(bytes);

          return await res.json({
            'status': true,
            'asset': {
              'url': '$urlPrefix/$safeName',
            },
          });
        } catch (e) {
          return await res.json({
            'status': false,
            'message': 'Failed to process image upload: $e',
          }, status: 500);
        }
      }

      return await next(ctx);
    };
  }
}
