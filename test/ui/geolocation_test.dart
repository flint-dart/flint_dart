import 'package:flint_dart/flint_ui_server.dart';
import 'package:test/test.dart';

void main() {
  group('GeoLocationController stub', () {
    test('reports unsupported outside browser builds', () {
      const controller = GeoLocationController();

      expect(controller.isSupported, isFalse);
    });

    test('currentPosition fails with a typed unsupported error', () async {
      const controller = GeoLocationController();

      await expectLater(
        controller.currentPosition(),
        throwsA(
          isA<GeoLocationError>().having(
            (error) => error.code,
            'code',
            GeoLocationErrorCode.unsupported,
          ),
        ),
      );
    });

    test('watchPosition reports unsupported and clearWatch is a no-op', () {
      const controller = GeoLocationController();
      GeoLocationError? receivedError;

      final watch = controller.watchPosition(
        (_) {},
        onError: (error) => receivedError = error,
      );

      expect(watch.id, -1);
      expect(receivedError?.code, GeoLocationErrorCode.unsupported);

      controller.clearWatch(watch);
    });

    test('GeoPosition exposes latitude, longitude, and accuracy shortcuts', () {
      final position = GeoPosition(
        coords: const GeoCoordinates(
          latitude: 6.5244,
          longitude: 3.3792,
          accuracy: 12,
        ),
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      );

      expect(position.latitude, 6.5244);
      expect(position.longitude, 3.3792);
      expect(position.accuracy, 12);
    });
  });
}
