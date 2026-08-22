import '../../component.dart';
import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../../browser/media_devices_stub.dart';

/// Controls a Flint [Video], [Audio], or [MediaPreview] element.
///
/// The server-safe implementation is intentionally a no-op. In browser builds
/// Flint binds the controller to the rendered media element so app code can
/// call [play], [pause], [seekTo], [setVolume], and related methods.
class MediaElementController {
  /// Creates a media element controller.
  MediaElementController();

  /// Whether this controller is currently attached to a browser media element.
  bool get isAttached => false;

  /// Whether playback is currently active.
  bool get isPlaying => false;

  /// Whether playback is currently paused.
  bool get isPaused => true;

  /// Whether playback has reached the end of the media.
  bool get ended => false;

  /// Current playback position.
  Duration get currentTime => Duration.zero;

  /// Media duration, when known.
  Duration? get duration => null;

  /// Current volume from `0.0` to `1.0`.
  double get volume => 1;

  /// Whether the media element is muted.
  bool get muted => false;

  /// Current playback rate where `1.0` is normal speed.
  double get playbackRate => 1;

  /// Starts playback.
  Future<void> play() async {}

  /// Pauses playback.
  void pause() {}

  /// Pauses playback and seeks back to the beginning.
  void stop() {
    pause();
    seekTo(Duration.zero);
  }

  /// Seeks playback to [position].
  void seekTo(Duration position) {}

  /// Sets volume from `0.0` to `1.0`.
  void setVolume(double value) {}

  /// Mutes the media element.
  void mute() {}

  /// Unmutes the media element.
  void unmute() {}

  /// Toggles muted state.
  void toggleMuted() {
    if (muted) {
      unmute();
    } else {
      mute();
    }
  }

  /// Sets playback rate where `1.0` is normal speed.
  void setPlaybackRate(double value) {}

  /// Detaches this controller from its media element.
  void detach() {}
}

/// Browser media preload strategy for `audio` and `video` elements.
enum MediaPreload {
  /// Let the browser choose how much media to preload.
  auto('auto'),

  /// Load only metadata such as duration and dimensions.
  metadata('metadata'),

  /// Do not preload media until the user starts playback.
  none('none');

  /// HTML `preload` attribute value.
  final String value;

  /// Creates a media preload option.
  const MediaPreload(this.value);
}

/// Native HTML `video` element with Flint styling and media controls.
class Video extends FlintElement {
  /// Creates a video element for URL/file-based video playback.
  ///
  /// Use [MediaPreview] when the source is a live browser `MediaStream` from
  /// [MediaDevicesController].
  Video({
    MediaElementController? controller,
    String? src,
    Object? width,
    Object? height,
    String? poster,
    bool controls = true,
    bool autoplay = false,
    bool muted = false,
    bool loop = false,
    bool playsInline = true,
    MediaPreload preload = MediaPreload.metadata,
    String? crossOrigin,
    String? className,
    Object? fallback,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'video',
         props: _mediaProps(
           props: props,
           controller: controller,
           src: src,
           width: width,
           height: height,
           poster: poster,
           controls: controls,
           autoplay: autoplay,
           muted: muted,
           loop: loop,
           playsInline: playsInline,
           preload: preload,
           crossOrigin: crossOrigin,
           className: className,
           defaultStyle: const {
             'display': 'block',
             'max-width': '100%',
             'background': '#000',
           },
           dartStyle: dartStyle,
           style: style,
         ),
         children: normalizeChildren(fallback, const []),
       );
}

/// Native HTML `audio` element with Flint styling and media controls.
class Audio extends FlintElement {
  /// Creates an audio element for URL/file-based audio playback.
  ///
  /// Use [MediaPreview] when the source is a live browser `MediaStream` from
  /// [MediaDevicesController].
  Audio({
    MediaElementController? controller,
    String? src,
    bool controls = true,
    bool autoplay = false,
    bool muted = false,
    bool loop = false,
    MediaPreload preload = MediaPreload.metadata,
    String? crossOrigin,
    String? className,
    Object? fallback,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'audio',
         props: _mediaProps(
           props: props,
           controller: controller,
           src: src,
           controls: controls,
           autoplay: autoplay,
           muted: muted,
           loop: loop,
           preload: preload,
           crossOrigin: crossOrigin,
           className: className,
           defaultStyle: const {'display': 'block', 'width': '100%'},
           dartStyle: dartStyle,
           style: style,
         ),
         children: normalizeChildren(fallback, const []),
       );
}

/// Media element type rendered by [MediaPreview].
enum MediaPreviewType {
  /// Render a `video` preview.
  video,

  /// Render an `audio` preview.
  audio,
}

/// Server-safe live media preview for a [MediaStreamResult].
///
/// In browser builds this component attaches `result.stream` to the rendered
/// media element's `srcObject`. On the server it renders the same HTML shape
/// without touching browser APIs, so SSR and SEO remain safe.
class MediaPreview extends StatefulComponent {
  /// Creates a live media preview for camera, microphone, or screen streams.
  MediaPreview({
    required this.result,
    this.type = MediaPreviewType.video,
    this.id,
    this.controls = true,
    this.autoplay = true,
    this.muted = true,
    this.loop = false,
    this.playsInline = true,
    this.poster,
    this.controller,
    this.fallback,
    this.className,
    this.props = const {},
    this.style = const {},
    this.dartStyle,
  });

  /// Capture result returned by [MediaDevicesController].
  final MediaStreamResult result;

  /// Whether to render a video or audio media element.
  final MediaPreviewType type;

  /// Optional DOM id. A generated id is used when omitted.
  final String? id;

  /// Whether native browser playback controls are shown.
  final bool controls;

  /// Whether playback should start automatically when the stream is attached.
  final bool autoplay;

  /// Whether the preview starts muted.
  ///
  /// Camera previews usually need this to avoid local audio feedback.
  final bool muted;

  /// Whether playback should loop.
  final bool loop;

  /// Whether video should play inline on mobile browsers.
  final bool playsInline;

  /// Poster image for video previews before playback starts.
  final String? poster;

  /// Optional controller for imperative playback controls.
  final MediaElementController? controller;

  /// Fallback content rendered inside the media element.
  final Object? fallback;

  /// Optional CSS class.
  final String? className;

  /// Additional element props.
  final Map<String, Object?> props;

  /// Additional inline styles.
  final Map<String, Object?> style;

  /// Typed Flint style.
  final DartStyle? dartStyle;

  static int _nextId = 0;
  late final String _elementId = id ?? 'flint-media-preview-${_nextId++}';

  /// DOM id used by the rendered media element.
  String get elementId => _elementId;

  @override
  View build() {
    if (type == MediaPreviewType.audio) {
      return Audio(
        controller: controller,
        controls: controls,
        autoplay: autoplay,
        muted: muted,
        loop: loop,
        fallback: fallback,
        className: className,
        props: {...props, 'id': _elementId},
        style: style,
        dartStyle: dartStyle,
      );
    }

    return Video(
      controller: controller,
      poster: poster,
      controls: controls,
      autoplay: autoplay,
      muted: muted,
      loop: loop,
      playsInline: playsInline,
      fallback: fallback,
      className: className,
      props: {...props, 'id': _elementId},
      style: style,
      dartStyle: dartStyle,
    );
  }
}

Map<String, Object?> _mediaProps({
  required Map<String, Object?> props,
  required MediaElementController? controller,
  String? src,
  Object? width,
  Object? height,
  String? poster,
  required bool controls,
  required bool autoplay,
  required bool muted,
  required bool loop,
  bool playsInline = false,
  required MediaPreload preload,
  String? crossOrigin,
  String? className,
  required Map<String, Object?> defaultStyle,
  required DartStyle? dartStyle,
  required Map<String, Object?> style,
}) {
  return mergeComponentProps(
    {
      ...props,
      if (controller != null) '_flintMediaController': controller,
      if (src != null) 'src': src,
      if (width != null) 'width': cssValue(width),
      if (height != null) 'height': cssValue(height),
      if (poster != null) 'poster': poster,
      if (controls) 'controls': true,
      if (autoplay) 'autoplay': true,
      if (muted) 'muted': true,
      if (loop) 'loop': true,
      if (playsInline) 'playsinline': true,
      'preload': preload.value,
      if (crossOrigin != null) 'crossorigin': crossOrigin,
    },
    className: className,
    defaultStyle: defaultStyle,
    dartStyle: dartStyle,
    style: style,
  );
}
