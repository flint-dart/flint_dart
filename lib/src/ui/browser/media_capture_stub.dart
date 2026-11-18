/// Type of media captured by Flint UI browser helpers.
enum CapturedMediaKind {
  /// Still image captured from a video/camera preview.
  photo,

  /// Recorded audio.
  audio,

  /// Recorded video or screen content.
  video,
}

/// Captured media ready for preview, upload, or storage.
class CapturedMedia {
  /// Creates a captured media value.
  const CapturedMedia({
    required this.kind,
    required this.filename,
    required this.mimeType,
    required this.size,
    required this.dataUrl,
    required this.base64,
    this.blob,
  });

  /// Captured media category.
  final CapturedMediaKind kind;

  /// Suggested filename for upload or download.
  final String filename;

  /// Browser MIME type such as `image/png`, `audio/webm`, or `video/webm`.
  final String mimeType;

  /// Size in bytes when known.
  final int size;

  /// Data URL containing the media payload.
  final String dataUrl;

  /// Base64 payload without the `data:mime/type;base64,` prefix.
  final String base64;

  /// Raw browser Blob in browser builds.
  final Object? blob;

  /// JSON-friendly upload body for Flint backend endpoints.
  Map<String, Object?> toUploadBody({
    String filenameField = 'filename',
    String mimeTypeField = 'mime_type',
    String base64Field = 'base64',
    String typeField = 'type',
  }) {
    return {
      filenameField: filename,
      mimeTypeField: mimeType,
      base64Field: base64,
      typeField: kind.name,
    };
  }
}

/// Options for browser media recording.
class MediaRecordingOptions {
  /// Creates recording options.
  const MediaRecordingOptions({
    this.mimeType,
    this.audioBitsPerSecond,
    this.videoBitsPerSecond,
    this.bitsPerSecond,
    this.timeslice,
    this.filename,
  });

  /// Requested recording MIME type.
  final String? mimeType;

  /// Requested audio bit rate.
  final int? audioBitsPerSecond;

  /// Requested video bit rate.
  final int? videoBitsPerSecond;

  /// Requested combined bit rate.
  final int? bitsPerSecond;

  /// Optional chunk interval for `dataavailable` events.
  final Duration? timeslice;

  /// Suggested output filename.
  final String? filename;
}

/// Server-safe recording controller.
class MediaRecorderController {
  /// Creates a media recorder controller.
  MediaRecorderController();

  /// Whether MediaRecorder is available in this runtime.
  bool get isSupported => false;

  /// Whether a recording is active.
  bool get isRecording => false;

  /// Whether an active recording is paused.
  bool get isPaused => false;

  /// Starts recording a browser media stream.
  Future<void> start(
    Object? stream, {
    CapturedMediaKind kind = CapturedMediaKind.video,
    MediaRecordingOptions options = const MediaRecordingOptions(),
  }) {
    return Future.error(
      UnsupportedError('Media recording is only available in a browser.'),
    );
  }

  /// Pauses recording.
  void pause() {}

  /// Resumes recording.
  void resume() {}

  /// Requests the current data chunk from the browser recorder.
  void requestData() {}

  /// Stops recording and returns captured media.
  Future<CapturedMedia> stop() {
    return Future.error(
      UnsupportedError('Media recording is only available in a browser.'),
    );
  }
}

/// Server-safe photo capture controller.
class PhotoCaptureController {
  /// Creates a photo capture controller.
  const PhotoCaptureController();

  /// Whether photo capture is available in this runtime.
  bool get isSupported => false;

  /// Captures a still image from a rendered video element.
  Future<CapturedMedia> takePhotoFromElement(
    String elementId, {
    String mimeType = 'image/png',
    double? quality,
    String? filename,
  }) {
    return Future.error(
      UnsupportedError('Photo capture is only available in a browser.'),
    );
  }
}
