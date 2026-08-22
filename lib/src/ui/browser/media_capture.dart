import 'dart:async';
import 'dart:js_interop';

import 'package:universal_web/web.dart' as web;

export 'media_capture_stub.dart'
    show CapturedMedia, CapturedMediaKind, MediaRecordingOptions;

import 'media_capture_stub.dart';

/// Browser recording controller backed by `MediaRecorder`.
class MediaRecorderController {
  /// Creates a browser media recorder controller.
  MediaRecorderController();

  web.MediaRecorder? _recorder;
  final List<web.Blob> _chunks = [];
  Completer<CapturedMedia>? _stopCompleter;
  CapturedMediaKind _kind = CapturedMediaKind.video;
  String? _filename;

  /// Whether MediaRecorder is available in this browser build.
  bool get isSupported => true;

  /// Whether a recording is active.
  bool get isRecording => _recorder?.state == 'recording';

  /// Whether an active recording is paused.
  bool get isPaused => _recorder?.state == 'paused';

  /// Starts recording [stream].
  ///
  /// [stream] may be a raw browser `MediaStream` or a `MediaStreamResult.stream`
  /// value from `MediaDevicesController`.
  Future<void> start(
    Object? stream, {
    CapturedMediaKind kind = CapturedMediaKind.video,
    MediaRecordingOptions options = const MediaRecordingOptions(),
  }) async {
    if (stream is! web.MediaStream) {
      throw ArgumentError('MediaRecorderController.start needs a MediaStream.');
    }
    if (_recorder != null && _recorder?.state != 'inactive') {
      throw StateError('A recording is already active.');
    }

    _chunks.clear();
    _kind = kind;
    _filename = options.filename;

    final recorder = web.MediaRecorder(stream, _recorderOptions(options));
    _recorder = recorder;

    recorder.ondataavailable = ((web.Event event) {
      if (event is web.BlobEvent && event.data.size > 0) {
        _chunks.add(event.data);
      }
    }).toJS;

    recorder.onstop = ((web.Event event) {
      _completeStop(recorder.mimeType);
    }).toJS;

    recorder.onerror = ((web.Event event) {
      _stopCompleter?.completeError(
        StateError('Media recording failed: $event'),
      );
      _stopCompleter = null;
    }).toJS;

    final timeslice = options.timeslice;
    if (timeslice == null) {
      recorder.start();
    } else {
      recorder.start(timeslice.inMilliseconds);
    }
  }

  /// Pauses the active recording.
  void pause() {
    final recorder = _recorder;
    if (recorder != null && recorder.state == 'recording') recorder.pause();
  }

  /// Resumes a paused recording.
  void resume() {
    final recorder = _recorder;
    if (recorder != null && recorder.state == 'paused') recorder.resume();
  }

  /// Requests the current data chunk from the browser recorder.
  void requestData() {
    final recorder = _recorder;
    if (recorder != null && recorder.state != 'inactive') {
      recorder.requestData();
    }
  }

  /// Stops recording and returns captured media.
  Future<CapturedMedia> stop() {
    final recorder = _recorder;
    if (recorder == null || recorder.state == 'inactive') {
      return Future.error(StateError('No active recording to stop.'));
    }

    final completer = Completer<CapturedMedia>();
    _stopCompleter = completer;
    recorder.stop();
    return completer.future;
  }

  Future<void> _completeStop(String mimeType) async {
    final completer = _stopCompleter;
    if (completer == null || completer.isCompleted) return;

    try {
      final type = mimeType.isEmpty ? _defaultMimeType(_kind) : mimeType;
      final blob = web.Blob(
        _chunks.cast<JSAny>().toJS,
        web.BlobPropertyBag(type: type),
      );
      completer.complete(
        await _capturedFromBlob(
          blob,
          kind: _kind,
          filename: _filename ?? _defaultFilename(_kind, type),
          fallbackMimeType: type,
        ),
      );
    } catch (error) {
      completer.completeError(error);
    } finally {
      _stopCompleter = null;
      _recorder = null;
      _chunks.clear();
    }
  }
}

web.MediaRecorderOptions _recorderOptions(MediaRecordingOptions options) {
  final browserOptions = web.MediaRecorderOptions();
  if (options.mimeType != null) browserOptions.mimeType = options.mimeType!;
  if (options.audioBitsPerSecond != null) {
    browserOptions.audioBitsPerSecond = options.audioBitsPerSecond!;
  }
  if (options.videoBitsPerSecond != null) {
    browserOptions.videoBitsPerSecond = options.videoBitsPerSecond!;
  }
  if (options.bitsPerSecond != null) {
    browserOptions.bitsPerSecond = options.bitsPerSecond!;
  }
  return browserOptions;
}

/// Browser still-photo capture controller backed by a canvas.
class PhotoCaptureController {
  /// Creates a browser photo capture controller.
  const PhotoCaptureController();

  /// Whether photo capture is available in this browser build.
  bool get isSupported => true;

  /// Captures a still image from a rendered video element.
  Future<CapturedMedia> takePhotoFromElement(
    String elementId, {
    String mimeType = 'image/png',
    double? quality,
    String? filename,
  }) async {
    final element = web.document.getElementById(elementId);
    if (element is! web.HTMLVideoElement) {
      throw ArgumentError('No video element found for id "$elementId".');
    }

    final width = element.videoWidth > 0
        ? element.videoWidth
        : element.clientWidth;
    final height = element.videoHeight > 0
        ? element.videoHeight
        : element.clientHeight;
    if (width <= 0 || height <= 0) {
      throw StateError('The video element is not ready for photo capture.');
    }

    final canvas = web.HTMLCanvasElement()
      ..width = width
      ..height = height;
    final context = canvas.getContext('2d');
    if (context is! web.CanvasRenderingContext2D) {
      throw StateError('Canvas 2D context is not available.');
    }

    context.drawImage(element, 0, 0, width, height);
    final blob = await _canvasToBlob(
      canvas,
      mimeType: mimeType,
      quality: quality,
    );
    return _capturedFromBlob(
      blob,
      kind: CapturedMediaKind.photo,
      filename: filename ?? _defaultFilename(CapturedMediaKind.photo, mimeType),
      fallbackMimeType: mimeType,
    );
  }
}

Future<web.Blob> _canvasToBlob(
  web.HTMLCanvasElement canvas, {
  required String mimeType,
  double? quality,
}) {
  final completer = Completer<web.Blob>();
  canvas.toBlob(
    ((web.Blob? blob) {
      if (blob == null) {
        completer.completeError(StateError('Canvas photo capture failed.'));
      } else {
        completer.complete(blob);
      }
    }).toJS,
    mimeType,
    quality?.toJS,
  );
  return completer.future;
}

Future<CapturedMedia> _capturedFromBlob(
  web.Blob blob, {
  required CapturedMediaKind kind,
  required String filename,
  required String fallbackMimeType,
}) async {
  final dataUrl = await _blobToDataUrl(blob);
  final comma = dataUrl.indexOf(',');
  return CapturedMedia(
    kind: kind,
    filename: filename,
    mimeType: blob.type.isEmpty ? fallbackMimeType : blob.type,
    size: blob.size,
    dataUrl: dataUrl,
    base64: comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl,
    blob: blob,
  );
}

Future<String> _blobToDataUrl(web.Blob blob) {
  final completer = Completer<String>();
  final reader = web.FileReader();
  reader.onload = ((web.Event _) {
    final result = reader.result;
    completer.complete(result == null ? '' : (result as JSString).toDart);
  }).toJS;
  reader.onerror = ((web.Event _) {
    completer.completeError(StateError('Unable to read captured media.'));
  }).toJS;
  reader.readAsDataURL(blob);
  return completer.future;
}

String _defaultMimeType(CapturedMediaKind kind) {
  return switch (kind) {
    CapturedMediaKind.photo => 'image/png',
    CapturedMediaKind.audio => 'audio/webm',
    CapturedMediaKind.video => 'video/webm',
  };
}

String _defaultFilename(CapturedMediaKind kind, String mimeType) {
  final extension = switch (mimeType) {
    'image/jpeg' => 'jpg',
    'image/webp' => 'webp',
    'audio/ogg' => 'ogg',
    'audio/mpeg' => 'mp3',
    'video/mp4' => 'mp4',
    _ => kind == CapturedMediaKind.photo ? 'png' : 'webm',
  };
  return 'flint-${kind.name}-${DateTime.now().millisecondsSinceEpoch}.$extension';
}
