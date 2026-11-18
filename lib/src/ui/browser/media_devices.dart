import 'dart:js_interop';

import 'package:universal_web/web.dart' as web;

export 'media_devices_stub.dart'
    show
        FlintMediaDevice,
        MediaPermissionError,
        MediaPermissionErrorCode,
        MediaStreamResult;

import 'media_devices_stub.dart';

/// Browser media devices controller for camera, microphone, and screen share.
///
/// Call these methods from browser event handlers, such as a button `onClick`,
/// because browsers require a user gesture for permission prompts. Camera,
/// microphone, and screen sharing generally require HTTPS or localhost.
class MediaDevicesController {
  /// Creates a browser media controller.
  const MediaDevicesController();

  web.MediaDevices get _mediaDevices => web.window.navigator.mediaDevices;

  /// Whether browser media APIs are available in this build.
  ///
  /// This browser implementation reports true after the `dart.library.js_interop`
  /// conditional export selects it.
  bool get isSupported => true;

  /// Whether camera requests can be attempted.
  bool get isCameraSupported => true;

  /// Whether microphone requests can be attempted.
  bool get isMicrophoneSupported => true;

  /// Whether screen-share requests can be attempted.
  bool get isScreenShareSupported => true;

  /// Requests access to a camera and returns a raw browser media stream.
  ///
  /// Pass [deviceId] to request a specific camera returned by [devices].
  Future<MediaStreamResult> requestCamera({String? deviceId}) {
    return _requestUserMedia(
      web.MediaStreamConstraints(video: _trackConstraint(deviceId)),
    );
  }

  /// Requests access to a microphone and returns a raw browser media stream.
  ///
  /// Pass [deviceId] to request a specific microphone returned by [devices].
  Future<MediaStreamResult> requestMicrophone({String? deviceId}) {
    return _requestUserMedia(
      web.MediaStreamConstraints(audio: _trackConstraint(deviceId)),
    );
  }

  /// Requests camera and microphone access together.
  ///
  /// This is useful for video calls and recording flows where the browser
  /// should show one permission request for both media types.
  Future<MediaStreamResult> requestCameraAndMicrophone({
    String? cameraDeviceId,
    String? microphoneDeviceId,
  }) {
    return _requestUserMedia(
      web.MediaStreamConstraints(
        video: _trackConstraint(cameraDeviceId),
        audio: _trackConstraint(microphoneDeviceId),
      ),
    );
  }

  /// Requests browser screen sharing.
  ///
  /// The browser will show its own picker for a screen, window, or tab. Apps
  /// cannot choose or start screen sharing silently. Set [audio] to true to ask
  /// for shared audio when the browser supports it.
  Future<MediaStreamResult> requestScreenShare({bool audio = false}) async {
    if (!web.window.isSecureContext) {
      return const MediaStreamResult(
        granted: false,
        error: MediaPermissionError(
          code: MediaPermissionErrorCode.insecureContext,
          message: 'Screen sharing requires HTTPS or localhost.',
        ),
      );
    }

    try {
      final stream = await _mediaDevices
          .getDisplayMedia(web.DisplayMediaStreamOptions(audio: audio.toJS))
          .toDart;
      return MediaStreamResult(granted: true, stream: stream);
    } catch (error) {
      return MediaStreamResult(
        granted: false,
        error: _mediaError(error, fallbackMessage: 'Unable to share screen.'),
      );
    }
  }

  /// Lists media devices known to the browser.
  ///
  /// Browsers may hide labels until the user has granted camera or microphone
  /// permission for the current site.
  Future<List<FlintMediaDevice>> devices() async {
    try {
      final items = await _mediaDevices.enumerateDevices().toDart;
      return items.toDart
          .map(
            (device) => FlintMediaDevice(
              deviceId: device.deviceId,
              kind: device.kind,
              label: device.label,
              groupId: device.groupId,
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Stops all tracks in [result] when it contains a browser `MediaStream`.
  ///
  /// Call this when leaving a page, closing a preview, or ending a recording so
  /// the browser can release camera, microphone, and screen-share indicators.
  void stop(MediaStreamResult result) {
    final stream = result.stream;
    if (stream is! web.MediaStream) return;

    final tracks = stream.getTracks().toDart;
    for (final track in tracks) {
      track.stop();
    }
  }

  Future<MediaStreamResult> _requestUserMedia(
    web.MediaStreamConstraints constraints,
  ) async {
    if (!web.window.isSecureContext) {
      return const MediaStreamResult(
        granted: false,
        error: MediaPermissionError(
          code: MediaPermissionErrorCode.insecureContext,
          message: 'Camera and microphone access require HTTPS or localhost.',
        ),
      );
    }

    try {
      final stream = await _mediaDevices.getUserMedia(constraints).toDart;
      return MediaStreamResult(granted: true, stream: stream);
    } catch (error) {
      return MediaStreamResult(
        granted: false,
        error: _mediaError(error, fallbackMessage: 'Unable to access media.'),
      );
    }
  }
}

JSAny _trackConstraint(String? deviceId) {
  if (deviceId == null || deviceId.isEmpty) return true.toJS;
  return web.MediaTrackConstraints(deviceId: deviceId.toJS);
}

MediaPermissionError _mediaError(
  Object error, {
  required String fallbackMessage,
}) {
  final text = error.toString();
  final normalized = text.toLowerCase();

  if (normalized.contains('notallowed') ||
      normalized.contains('permission') ||
      normalized.contains('denied')) {
    return MediaPermissionError(
      code: MediaPermissionErrorCode.permissionDenied,
      message: 'Media permission was denied.',
      name: text,
    );
  }

  if (normalized.contains('notfound') ||
      normalized.contains('not found') ||
      normalized.contains('devicesnotfound')) {
    return MediaPermissionError(
      code: MediaPermissionErrorCode.deviceNotFound,
      message: 'No matching media device was found.',
      name: text,
    );
  }

  if (normalized.contains('abort') || normalized.contains('cancel')) {
    return MediaPermissionError(
      code: MediaPermissionErrorCode.cancelled,
      message: 'Media selection was cancelled.',
      name: text,
    );
  }

  return MediaPermissionError(
    code: MediaPermissionErrorCode.unknown,
    message: fallbackMessage,
    name: text,
  );
}
