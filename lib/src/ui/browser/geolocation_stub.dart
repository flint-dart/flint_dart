/// Geolocation error categories normalized for Flint UI apps.
///
/// Browser geolocation failures use numeric codes. Flint UI maps those codes
/// into named categories so app code can make readable decisions.
enum GeoLocationErrorCode {
  /// The current runtime cannot access browser geolocation APIs.
  unsupported,

  /// The user or browser denied location access.
  permissionDenied,

  /// The browser could not determine a position.
  positionUnavailable,

  /// The browser could not return a position before the configured timeout.
  timeout,

  /// The browser returned an error Flint UI could not classify.
  unknown,
}

/// A normalized geolocation error.
///
/// Use [code] for app logic. [browserCode] keeps the original browser numeric
/// error when available.
class GeoLocationError {
  const GeoLocationError({
    required this.code,
    required this.message,
    this.browserCode,
  });

  /// Stable error category that app code can switch on.
  final GeoLocationErrorCode code;

  /// Short user-facing explanation of the failure.
  final String message;

  /// Original browser geolocation error code when available.
  final int? browserCode;

  @override
  String toString() => 'GeoLocationError($code, $message)';
}

/// Position coordinates returned by browser geolocation.
///
/// Coordinates use the browser Geolocation API values. Latitude and longitude
/// are decimal degrees; accuracy values are meters.
class GeoCoordinates {
  const GeoCoordinates({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.altitude,
    this.altitudeAccuracy,
    this.heading,
    this.speed,
  });

  /// Latitude in decimal degrees.
  final double latitude;

  /// Longitude in decimal degrees.
  final double longitude;

  /// Estimated horizontal accuracy in meters.
  final double accuracy;

  /// Altitude in meters, when provided by the browser.
  final double? altitude;

  /// Estimated altitude accuracy in meters, when provided by the browser.
  final double? altitudeAccuracy;

  /// Travel direction in degrees, when provided by the browser.
  final double? heading;

  /// Travel speed in meters per second, when provided by the browser.
  final double? speed;
}

/// A browser geolocation position.
class GeoPosition {
  const GeoPosition({required this.coords, required this.timestamp});

  /// Coordinates reported by the browser.
  final GeoCoordinates coords;

  /// Time the browser captured the position.
  final DateTime timestamp;

  /// Shortcut for `coords.latitude`.
  double get latitude => coords.latitude;

  /// Shortcut for `coords.longitude`.
  double get longitude => coords.longitude;

  /// Shortcut for `coords.accuracy`.
  double get accuracy => coords.accuracy;
}

/// Active geolocation watch handle.
///
/// Pass this value to [GeoLocationController.clearWatch] to stop live location
/// updates.
class GeoWatch {
  const GeoWatch(this.id);

  /// Browser watch identifier.
  final int id;
}

/// Server-safe geolocation controller.
///
/// Browser geolocation is only available from browser builds. This stub keeps
/// server rendering and tests from touching `navigator`.
class GeoLocationController {
  /// Creates a geolocation controller.
  ///
  /// This stub implementation is used outside browser builds.
  const GeoLocationController();

  /// Whether geolocation APIs are available in this runtime.
  bool get isSupported => false;

  /// Requests the current location once.
  ///
  /// In browser builds this prompts the user when permission is needed. In this
  /// server-safe stub it completes with an unsupported [GeoLocationError].
  Future<GeoPosition> currentPosition({
    bool enableHighAccuracy = false,
    Duration? timeout,
    Duration? maximumAge,
  }) {
    return Future.error(_unsupportedError);
  }

  /// Watches the user's location until [clearWatch] is called.
  ///
  /// In browser builds [onChange] receives each position update. In this
  /// server-safe stub [onError] receives an unsupported [GeoLocationError] and
  /// the returned watch has id `-1`.
  GeoWatch watchPosition(
    void Function(GeoPosition position) onChange, {
    void Function(GeoLocationError error)? onError,
    bool enableHighAccuracy = false,
    Duration? timeout,
    Duration? maximumAge,
  }) {
    onError?.call(_unsupportedError);
    return const GeoWatch(-1);
  }

  /// Stops a live location watch.
  ///
  /// This is a no-op outside browser builds.
  void clearWatch(GeoWatch watch) {}
}

const _unsupportedError = GeoLocationError(
  code: GeoLocationErrorCode.unsupported,
  message: 'Geolocation is only available in a browser.',
);
