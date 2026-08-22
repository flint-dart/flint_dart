import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Called when a [ThreeSceneController] attaches to a rendered canvas.
typedef ThreeSceneAttachCallback =
    void Function(ThreeSceneController controller);

/// Called for each requested animation frame.
typedef ThreeSceneFrameCallback =
    void Function(ThreeSceneController controller, double timestamp);

/// Called when a [ThreeSceneController] is disposed.
typedef ThreeSceneDisposeCallback =
    void Function(ThreeSceneController controller);

/// Server-safe controller for a browser Three.js scene canvas.
///
/// Browser builds attach this controller to a canvas and expose the global
/// `THREE` object when an app has loaded Three.js. Server and VM builds keep
/// the same API without touching browser globals.
class ThreeSceneController {
  /// Creates a Three.js scene controller.
  ThreeSceneController({
    this.onAttach,
    this.onFrame,
    this.onDispose,
    this.autoStart = true,
  });

  /// Runs after the controller attaches to a canvas in browser builds.
  final ThreeSceneAttachCallback? onAttach;

  /// Runs during the animation loop in browser builds.
  final ThreeSceneFrameCallback? onFrame;

  /// Runs when [dispose] is called.
  final ThreeSceneDisposeCallback? onDispose;

  /// Whether the browser controller should start animation on attach.
  final bool autoStart;

  /// Whether this build can access browser APIs.
  bool get isSupported => false;

  /// Whether this controller is attached to a canvas.
  bool get isAttached => false;

  /// Whether a global `THREE` object is available.
  bool get isThreeAvailable => false;

  /// The attached canvas element in browser builds.
  Object? get canvas => null;

  /// The global `THREE` object in browser builds.
  Object? get three => null;

  /// The canvas width in pixels.
  int get width => 0;

  /// The canvas height in pixels.
  int get height => 0;

  /// Attaches this controller to [element] in browser builds.
  void attachTo(Object? element) {}

  /// Reads a property from the global `THREE` object in browser builds.
  Object? getThreeProperty(String name) => null;

  /// Creates a Three.js object from a constructor on the global `THREE` object.
  Object? create(String constructor, [List<Object?> args = const []]) => null;

  /// Calls [method] on a JavaScript [target] object in browser builds.
  Object? callMethod(
    Object? target,
    String method, [
    List<Object?> args = const [],
  ]) => null;

  /// Reads a JavaScript property from [target] in browser builds.
  Object? getProperty(Object? target, String property) => null;

  /// Writes a JavaScript property on [target] in browser builds.
  void setProperty(Object? target, String property, Object? value) {}

  /// Calls `dispose()` on [target] when that method exists in browser builds.
  void disposeObject(Object? target) {}

  /// Starts the animation loop in browser builds.
  void start() {}

  /// Stops the animation loop in browser builds.
  void stop() {}

  /// Requests one render/update frame.
  void render([double timestamp = 0]) {
    onFrame?.call(this, timestamp);
  }

  /// Updates the backing canvas dimensions in browser builds.
  void resize({int? width, int? height}) {}

  /// Detaches this controller from its canvas.
  void detach() {}

  /// Stops animation, releases browser resources, and calls [onDispose].
  void dispose() {
    onDispose?.call(this);
  }
}

/// Canvas element intended for a browser Three.js renderer.
class ThreeScene extends FlintElement {
  /// Creates a Three.js scene canvas.
  ThreeScene({
    this.controller,
    int width = 640,
    int height = 360,
    String? className,
    String? label,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'canvas',
         props: mergeComponentProps(
           {
             ...props,
             'width': width,
             'height': height,
             if (controller != null) '_flintThreeSceneController': controller,
             if (label != null) 'aria-label': label,
             if (label == null) 'aria-hidden': true,
             'tabIndex': props['tabIndex'] ?? 0,
           },
           className: className,
           defaultStyle: const {
             'display': 'block',
             'width': '100%',
             'max-width': '100%',
             'height': 'auto',
             'touch-action': 'none',
           },
           dartStyle: dartStyle,
           style: style,
         ),
       );

  /// Optional scene controller.
  final ThreeSceneController? controller;
}
