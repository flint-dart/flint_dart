import 'package:flint_dart/flint_ui_server.dart';
import 'package:test/test.dart';

void main() {
  group('CapturedMedia', () {
    test('creates JSON-friendly upload bodies', () {
      const media = CapturedMedia(
        kind: CapturedMediaKind.photo,
        filename: 'profile.png',
        mimeType: 'image/png',
        size: 12,
        dataUrl: 'data:image/png;base64,abc',
        base64: 'abc',
      );

      expect(media.toUploadBody(), {
        'filename': 'profile.png',
        'mime_type': 'image/png',
        'base64': 'abc',
        'type': 'photo',
      });
    });
  });

  group('MediaRecorderController stub', () {
    test('reports unsupported outside browser builds', () {
      final recorder = MediaRecorderController();

      expect(recorder.isSupported, isFalse);
      expect(recorder.isRecording, isFalse);
      expect(recorder.isPaused, isFalse);
    });

    test('start and stop fail with unsupported errors', () async {
      final recorder = MediaRecorderController();

      await expectLater(recorder.start(null), throwsUnsupportedError);
      await expectLater(recorder.stop(), throwsUnsupportedError);

      recorder.pause();
      recorder.resume();
      recorder.requestData();
    });
  });

  group('PhotoCaptureController stub', () {
    test('reports unsupported and fails outside browser builds', () async {
      const capture = PhotoCaptureController();

      expect(capture.isSupported, isFalse);
      await expectLater(
        capture.takePhotoFromElement('preview'),
        throwsUnsupportedError,
      );
    });
  });
}
