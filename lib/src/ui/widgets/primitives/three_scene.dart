import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:universal_web/web.dart' as web;

import 'three_scene_stub.dart' as stub;

export 'three_scene_stub.dart'
    show
        ThreeScene,
        ThreeSceneAttachCallback,
        ThreeSceneDisposeCallback,
        ThreeSceneFrameCallback;

/// Browser controller for a Three.js scene canvas.
class ThreeSceneController extends stub.ThreeSceneController {
  /// Creates a browser Three.js scene controller.
  ThreeSceneController({
    super.onAttach,
    super.onFrame,
    super.onDispose,
    super.autoStart,
  });

  web.HTMLCanvasElement? _canvas;
  JSObject? _three;
  int? _animationFrame;
  bool _running = false;

  @override
  bool get isSupported => true;

  @override
  bool get isAttached => _canvas != null;

  @override
  bool get isThreeAvailable => _three != null;

  @override
  Object? get canvas => _canvas;

  @override
  Object? get three => _three;

  @override
  int get width => _canvas?.width ?? 0;

  @override
  int get height => _canvas?.height ?? 0;

  /// Binds this controller to a browser canvas element.
  @override
  void attachTo(Object? element) {
    if (element is! web.HTMLCanvasElement) return;
    if (_canvas == element) return;

    stop();
    _canvas = element;
    final three = globalContext.getProperty<JSAny?>('THREE'.toJS);
    _three = three is JSObject ? three : null;
    onAttach?.call(this);
    if (autoStart) start();
  }

  @override
  Object? getThreeProperty(String name) =>
      _three?.getProperty<JSAny?>(name.toJS);

  @override
  Object? create(String constructor, [List<Object?> args = const []]) {
    final ctor = getThreeProperty(constructor);
    if (ctor is! JSFunction) return null;
    return ctor.callAsConstructorVarArgs<JSObject>(_jsArgs(args));
  }

  @override
  Object? callMethod(
    Object? target,
    String method, [
    List<Object?> args = const [],
  ]) {
    if (target is! JSObject) return null;
    return target.callMethodVarArgs<JSAny?>(method.toJS, _jsArgs(args));
  }

  @override
  Object? getProperty(Object? target, String property) {
    if (target is! JSObject) return null;
    return target.getProperty<JSAny?>(property.toJS);
  }

  @override
  void setProperty(Object? target, String property, Object? value) {
    if (target is! JSObject) return;
    target.setProperty(property.toJS, _toJs(value));
  }

  @override
  void disposeObject(Object? target) {
    if (target is! JSObject) return;
    final dispose = target.getProperty<JSAny?>('dispose'.toJS);
    if (dispose is JSFunction) {
      dispose.callAsFunction(target);
    }
  }

  @override
  void start() {
    if (_running || _canvas == null) return;
    _running = true;
    _scheduleFrame();
  }

  @override
  void stop() {
    _running = false;
    final frame = _animationFrame;
    if (frame != null) {
      web.window.cancelAnimationFrame(frame);
      _animationFrame = null;
    }
  }

  @override
  void render([double timestamp = 0]) {
    onFrame?.call(this, timestamp);
  }

  @override
  void resize({int? width, int? height}) {
    final canvas = _canvas;
    if (canvas == null) return;
    if (width != null) canvas.width = width;
    if (height != null) canvas.height = height;
  }

  @override
  void detach() {
    stop();
    _canvas = null;
  }

  @override
  void dispose() {
    stop();
    onDispose?.call(this);
    _canvas = null;
  }

  void _scheduleFrame() {
    if (!_running || _canvas == null) return;
    _animationFrame = web.window.requestAnimationFrame(
      ((JSNumber timestamp) {
        _animationFrame = null;
        if (!_running || _canvas == null) return;
        render(timestamp.toDartDouble);
        _scheduleFrame();
      }).toJS,
    );
  }
}

List<JSAny?> _jsArgs(List<Object?> args) =>
    args.map(_toJs).toList(growable: false);

JSAny? _toJs(Object? value) {
  if (value == null) return null;
  if (value is JSAny) return value;
  return value.jsify();
}
