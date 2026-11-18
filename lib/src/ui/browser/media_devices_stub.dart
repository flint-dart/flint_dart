/// Media capture error categories normalized for Flint UI apps.
///
/// Browsers report camera, microphone, and screen-share failures with
/// different DOM exception names. Flint UI maps those browser-specific names
/// into these stable categories so app code can show consistent messages.
enum MediaPermissionErrorCode {
  /// The current runtime cannot access browser media APIs.
  ///
  /// This is the normal result during server rendering, tests that run on the
  /// Dart VM, or unsupported browser environments.
  unsupported,

  /// The page is not running in a secure browser context.
  ///
  /// Camera, microphone, and screen sharing generally require HTTPS or
  /// localhost. Normal `http://` production domains are blocked by browsers.
  insecureContext,

  /// The user or browser denied access to the requested device.
  permissionDenied,

  /// No camera, microphone, or matching device ID was available.
  deviceNotFound,

  /// The user cancelled the picker, commonly with screen sharing.
  cancelled,

  /// The browser returned an error Flint UI could not classify.
  unknown,
}

/// A normalized media permission or capture error.
///
/// Use [code] for app logic and [message] for a short human-readable fallback.
/// The optional [name] keeps the original browser error text when available,
/// which is useful for logging or support diagnostics.
class MediaPermissionError {
  const MediaPermissionError({
    required this.code,
    required this.message,
    this.name,
  });

  /// Stable error category that app code can switch on.
  final MediaPermissionErrorCode code;

  /// Short user-facing explanation of the failure.
  final String message;

  /// Original browser error name or text when available.
  final String? name;

  @override
  String toString() => 'MediaPermissionError($code, $message)';
}

/// Result returned by media capture requests.
///
/// A granted result contains the raw browser stream in [stream]. Flint UI keeps
/// this as [Object] so the public API stays usable from server-safe imports.
/// Browser-only helpers and preview widgets can cast the stream internally.
class MediaStreamResult {
  const MediaStreamResult({required this.granted, this.stream, this.error});

  /// Whether the browser granted the requested camera, microphone, or screen.
  final bool granted;

  /// Raw browser `MediaStream` when [granted] is true.
  final Object? stream;

  /// Normalized failure details when [granted] is false.
  final MediaPermissionError? error;

  /// Convenience inverse of [granted].
  bool get denied => !granted;
}

/// A browser media input or output device.
///
/// Device labels may be empty until the user grants media permission, matching
/// normal browser privacy behavior.
class FlintMediaDevice {
  const FlintMediaDevice({
    required this.deviceId,
    required this.kind,
    required this.label,
    required this.groupId,
  });

  /// Browser-provided device identifier scoped to the current origin.
  final String deviceId;

  /// Browser media kind, such as `videoinput`, `audioinput`, or `audiooutput`.
  final String kind;

  /// Human-readable device label, when the browser is allowed to reveal it.
  final String label;

  /// Browser group identifier for related devices on the same physical unit.
  final String groupId;

  /// Whether this device can provide video input.
  bool get isVideoInput => kind == 'videoinput';

  /// Whether this device can provide audio input.
  bool get isAudioInput => kind == 'audioinput';

  /// Whether this device can play audio output.
  bool get isAudioOutput => kind == 'audiooutput';
}

/// Server-safe media devices controller.
///
/// Browser APIs are only available from browser builds. These stubs keep
/// server rendering and tests from touching `navigator`.
class MediaDevicesController {
  /// Creates a media controller.
  ///
  /// This stub implementation is used outside browser builds.
  const MediaDevicesController();

  /// Whether media device APIs are available in this runtime.
  bool get isSupported => false;

  /// Whether camera requests are available in this runtime.
  bool get isCameraSupported => false;

  /// Whether microphone requests are available in this runtime.
  bool get isMicrophoneSupported => false;

  /// Whether screen-share requests are available in this runtime.
  bool get isScreenShareSupported => false;

  /// Requests access to a camera.
  ///
  /// In browser builds this prompts the user. In this server-safe stub it
  /// returns an unsupported [MediaStreamResult].
  Future<MediaStreamResult> requestCamera({String? deviceId}) {
    return Future.value(_unsupportedResult);
  }

  /// Requests access to a microphone.
  ///
  /// In browser builds this prompts the user. In this server-safe stub it
  /// returns an unsupported [MediaStreamResult].
  Future<MediaStreamResult> requestMicrophone({String? deviceId}) {
    return Future.value(_unsupportedResult);
  }

  /// Requests camera and microphone access with a single browser prompt.
  ///
  /// In browser builds optional device IDs constrain the selected devices. In
  /// this server-safe stub it returns an unsupported [MediaStreamResult].
  Future<MediaStreamResult> requestCameraAndMicrophone({
    String? cameraDeviceId,
    String? microphoneDeviceId,
  }) {
    return Future.value(_unsupportedResult);
  }

  /// Requests browser screen sharing.
  ///
  /// Screen sharing must always be started by a user gesture in real browsers.
  /// In this server-safe stub it returns an unsupported [MediaStreamResult].
  Future<MediaStreamResult> requestScreenShare({bool audio = false}) {
    return Future.value(_unsupportedResult);
  }

  /// Lists known media devices.
  ///
  /// This returns an empty list outside browser builds.
  Future<List<FlintMediaDevice>> devices() => Future.value(const []);

  /// Stops tracks in a granted media result.
  ///
  /// This is a no-op outside browser builds.
  void stop(MediaStreamResult result) {}
}

const _unsupportedResult = MediaStreamResult(
  granted: false,
  error: MediaPermissionError(
    code: MediaPermissionErrorCode.unsupported,
    message: 'Media devices are only available in a browser.',
  ),
);
