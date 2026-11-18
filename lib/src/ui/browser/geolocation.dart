import 'dart:async';
import 'dart:js_interop';

import 'package:universal_web/web.dart' as web;

export 'geolocation_stub.dart'
    show
        GeoCoordinates,
        GeoLocationError,
        GeoLocationErrorCode,
        GeoPosition,
        GeoWatch;

import 'geolocation_stub.dart';

/// Browser geolocation controller for current position and live tracking.
///
/// Call these methods from browser event handlers when you want the user to
/// intentionally share location. Browsers control the permission prompt and may
/// require HTTPS or localhost.
class GeoLocationController {
  /// Creates a browser geolocation controller.
  const GeoLocationController();

  web.Geolocation get _geolocation => web.window.navigator.geolocation;

  /// Whether browser geolocation APIs are available in this build.
  bool get isSupported => true;

  /// Requests the current browser location once.
  ///
  /// Set [enableHighAccuracy] when the app needs the most precise reading the
  /// device can provide. Use [timeout] to limit how long the browser may wait,
  /// and [maximumAge] to allow cached positions.
  Future<GeoPosition> currentPosition({
    bool enableHighAccuracy = false,
    Duration? timeout,
    Duration? maximumAge,
  }) {
    final completer = Completer<GeoPosition>();

    _geolocation.getCurrentPosition(
      ((web.GeolocationPosition position) {
        if (!completer.isCompleted) {
          completer.complete(_toGeoPosition(position));
        }
      }).toJS,
      ((web.GeolocationPositionError error) {
        if (!completer.isCompleted) {
          completer.completeError(_toGeoLocationError(error));
        }
      }).toJS,
      _positionOptions(
        enableHighAccuracy: enableHighAccuracy,
        timeout: timeout,
        maximumAge: maximumAge,
      ),
    );

    return completer.future;
  }

  /// Watches location changes until [clearWatch] is called.
  ///
  /// [onChange] receives each new [GeoPosition]. [onError] receives normalized
  /// permission, timeout, or availability errors when the browser reports them.
  GeoWatch watchPosition(
    void Function(GeoPosition position) onChange, {
    void Function(GeoLocationError error)? onError,
    bool enableHighAccuracy = false,
    Duration? timeout,
    Duration? maximumAge,
  }) {
    final id = _geolocation.watchPosition(
      ((web.GeolocationPosition position) {
        onChange(_toGeoPosition(position));
      }).toJS,
      ((web.GeolocationPositionError error) {
        onError?.call(_toGeoLocationError(error));
      }).toJS,
      _positionOptions(
        enableHighAccuracy: enableHighAccuracy,
        timeout: timeout,
        maximumAge: maximumAge,
      ),
    );

    return GeoWatch(id);
  }

  /// Stops a live location watch created by [watchPosition].
  void clearWatch(GeoWatch watch) {
    if (watch.id >= 0) _geolocation.clearWatch(watch.id);
  }
}

web.PositionOptions _positionOptions({
  required bool enableHighAccuracy,
  Duration? timeout,
  Duration? maximumAge,
}) {
  final options = web.PositionOptions(enableHighAccuracy: enableHighAccuracy);
  if (timeout != null) options.timeout = timeout.inMilliseconds;
  if (maximumAge != null) options.maximumAge = maximumAge.inMilliseconds;
  return options;
}

GeoPosition _toGeoPosition(web.GeolocationPosition position) {
  final coords = position.coords;
  return GeoPosition(
    coords: GeoCoordinates(
      latitude: coords.latitude,
      longitude: coords.longitude,
      accuracy: coords.accuracy,
      altitude: coords.altitude,
      altitudeAccuracy: coords.altitudeAccuracy,
      heading: coords.heading,
      speed: coords.speed,
    ),
    timestamp: DateTime.fromMillisecondsSinceEpoch(position.timestamp.toInt()),
  );
}

GeoLocationError _toGeoLocationError(web.GeolocationPositionError error) {
  return GeoLocationError(
    code: switch (error.code) {
      web.GeolocationPositionError.PERMISSION_DENIED =>
        GeoLocationErrorCode.permissionDenied,
      web.GeolocationPositionError.POSITION_UNAVAILABLE =>
        GeoLocationErrorCode.positionUnavailable,
      web.GeolocationPositionError.TIMEOUT => GeoLocationErrorCode.timeout,
      _ => GeoLocationErrorCode.unknown,
    },
    message: error.message,
    browserCode: error.code,
  );
}
