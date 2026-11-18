import 'package:flint_dart/flint_ui_server.dart';
import 'package:test/test.dart';

void main() {
  group('MediaDevicesController stub', () {
    test('reports unsupported outside browser builds', () async {
      const controller = MediaDevicesController();

      expect(controller.isSupported, isFalse);
      expect(controller.isCameraSupported, isFalse);
      expect(controller.isMicrophoneSupported, isFalse);
      expect(controller.isScreenShareSupported, isFalse);
      expect(await controller.devices(), isEmpty);
    });

    test('returns typed unsupported results for capture requests', () async {
      const controller = MediaDevicesController();

      final camera = await controller.requestCamera();
      final microphone = await controller.requestMicrophone();
      final both = await controller.requestCameraAndMicrophone();
      final screen = await controller.requestScreenShare(audio: true);

      for (final result in [camera, microphone, both, screen]) {
        expect(result.granted, isFalse);
        expect(result.denied, isTrue);
        expect(result.stream, isNull);
        expect(result.error?.code, MediaPermissionErrorCode.unsupported);
      }
    });

    test('stop is safe for unsupported and empty results', () {
      const controller = MediaDevicesController();

      controller.stop(
        const MediaStreamResult(
          granted: false,
          error: MediaPermissionError(
            code: MediaPermissionErrorCode.unsupported,
            message: 'No browser.',
          ),
        ),
      );
    });
  });
}
