import 'dart:js_interop';

import 'package:universal_web/web.dart' as web;

import 'media_preview_stub.dart' as stub;
import '../../browser/media_devices.dart';

export 'media_preview_stub.dart'
    show Audio, MediaPreload, MediaPreviewType, Video;

/// Browser controller for Flint [Video], [Audio], and [MediaPreview] elements.
class MediaElementController extends stub.MediaElementController {
  web.HTMLMediaElement? _element;

  @override
  bool get isAttached => _element != null;

  @override
  bool get isPlaying => _element?.paused == false;

  @override
  bool get isPaused => _element?.paused ?? true;

  @override
  bool get ended => _element?.ended ?? false;

  @override
  Duration get currentTime {
    final seconds = _element?.currentTime ?? 0;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  @override
  Duration? get duration {
    final seconds = _element?.duration;
    if (seconds == null || seconds.isNaN || seconds.isInfinite) return null;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  @override
  double get volume => _element?.volume ?? 1;

  @override
  bool get muted => _element?.muted ?? false;

  @override
  double get playbackRate => _element?.playbackRate ?? 1;

  @override
  Future<void> play() async {
    await _element?.play().toDart;
  }

  @override
  void pause() {
    _element?.pause();
  }

  @override
  void seekTo(Duration position) {
    _element?.currentTime = position.inMilliseconds / 1000;
  }

  @override
  void setVolume(double value) {
    _element?.volume = value.clamp(0, 1);
  }

  @override
  void mute() {
    final element = _element;
    if (element != null) element.muted = true;
  }

  @override
  void unmute() {
    final element = _element;
    if (element != null) element.muted = false;
  }

  @override
  void setPlaybackRate(double value) {
    _element?.playbackRate = value;
  }

  @override
  void detach() {
    _element = null;
  }

  /// Binds this controller to a browser media element.
  void attachTo(Object? element) {
    if (element is web.HTMLMediaElement) {
      _element = element;
    }
  }
}

/// Browser live media preview for a [MediaStreamResult].
///
/// The component renders a native `video` or `audio` element, then attaches the
/// browser `MediaStream` to `srcObject` after mount. It clears the element on
/// unmount so the DOM does not keep stale stream references.
class MediaPreview extends stub.MediaPreview {
  /// Creates a live media preview for camera, microphone, or screen streams.
  MediaPreview({
    required super.result,
    super.type,
    super.id,
    super.controls,
    super.autoplay,
    super.muted,
    super.loop,
    super.playsInline,
    super.poster,
    super.controller,
    super.fallback,
    super.className,
    super.props,
    super.style,
    super.dartStyle,
  });

  @override
  void didMount() {
    _attachStream();
  }

  @override
  void didUpdate() {
    _attachStream();
  }

  @override
  void willUnmount() {
    _clearStream();
  }

  void _attachStream() {
    final element = web.document.getElementById(elementId);
    if (element is! web.HTMLMediaElement) return;

    final stream = result.stream;
    if (result.granted && stream is web.MediaStream) {
      element.srcObject = stream;
      if (autoplay) {
        element.play().toDart.catchError((_) => null);
      }
    } else {
      element.srcObject = null;
    }
  }

  void _clearStream() {
    final element = web.document.getElementById(elementId);
    if (element is web.HTMLMediaElement) {
      element.pause();
      element.srcObject = null;
    }
    final controller = this.controller;
    if (controller is MediaElementController) {
      controller.detach();
    }
  }
}
