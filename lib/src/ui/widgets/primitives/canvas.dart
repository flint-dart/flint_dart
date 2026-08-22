import 'dart:js_interop';
import 'dart:math' as math;

import 'package:universal_web/web.dart' as web;

import 'canvas_stub.dart' as stub;

export 'canvas_stub.dart'
    show
        Canvas,
        CanvasAlignment,
        CanvasBounds,
        CanvasChangeCallback,
        CanvasCircle,
        CanvasGuide,
        CanvasGuideOrientation,
        CanvasImageObject,
        CanvasImagePattern,
        CanvasLayerItem,
        CanvasLine,
        CanvasObject,
        CanvasObjectConstraints,
        CanvasObjectsCallback,
        CanvasPaint,
        CanvasPatternRepetition,
        CanvasHistoryCallback,
        CanvasPointerCallback,
        CanvasPointerEvent,
        CanvasRect,
        CanvasSelectionHandle,
        CanvasSelectCallback,
        CanvasTextEditCallback,
        CanvasTextObject,
        canvasObjectFromJson;

/// Browser controller for Flint canvas drawing.
class CanvasController extends stub.CanvasController {
  /// Creates a browser canvas controller.
  CanvasController({
    super.onSelect,
    super.onChange,
    super.onMove,
    super.onResize,
    super.onRotate,
    super.onTextEdit,
    super.onPointerDown,
    super.onPointerUp,
    super.onHover,
    super.onDragStart,
    super.onDragEnd,
    super.onResizeStart,
    super.onResizeEnd,
    super.onRotateStart,
    super.onRotateEnd,
    super.onUndo,
    super.onRedo,
    super.snapToGrid,
    super.gridSize,
    super.snapToObjects,
    super.snapThreshold,
    super.maxHistoryEntries,
    super.constraints,
    super.showGrid,
    super.showRulers,
    super.showSnapGuides,
  });

  web.HTMLCanvasElement? _canvas;
  web.CanvasRenderingContext2D? _context;
  final Map<String, web.HTMLImageElement> _patternImages = {};
  final Map<String, web.HTMLImageElement> _objectImages = {};
  final Set<String> _loadingPatterns = {};
  final Set<String> _loadingObjects = {};
  bool _listenersAttached = false;
  bool _dragging = false;
  _CanvasOperation _activeOperation = _CanvasOperation.none;
  String? _hoveredObjectId;
  stub.CanvasSelectionHandle? _activeHandle;
  double? _selectionStartX;
  double? _selectionStartY;
  double? _selectionCurrentX;
  double? _selectionCurrentY;
  double _lastX = 0;
  double _lastY = 0;

  @override
  bool get isAttached => _canvas != null && _context != null;

  /// Binds this controller to a browser canvas element.
  void attachTo(Object? element) {
    if (element is! web.HTMLCanvasElement) return;
    _canvas = element;
    final context = element.getContext('2d');
    if (context is web.CanvasRenderingContext2D) {
      _context = context;
      setCanvasSize(element.width.toDouble(), element.height.toDouble());
      _attachPointerListeners(element);
      render();
    }
  }

  @override
  void clear() {
    super.clear();
    final canvas = _canvas;
    final context = _context;
    if (canvas != null && context != null) {
      context.clearRect(0, 0, canvas.width, canvas.height);
    }
  }

  @override
  void render() {
    final canvas = _canvas;
    final context = _context;
    if (canvas == null || context == null) return;

    context.clearRect(0, 0, canvas.width, canvas.height);
    _drawGrid(context, canvas);
    _drawRulers(context, canvas);
    for (final object in objects) {
      if (object.hidden) continue;
      switch (object) {
        case stub.CanvasRect rect:
          drawRect(rect);
        case stub.CanvasLine line:
          drawLine(line);
        case stub.CanvasCircle circle:
          drawCircle(circle);
        case stub.CanvasTextObject text:
          drawText(text);
        case stub.CanvasImageObject image:
          drawImage(image);
        default:
          break;
      }
    }
    _drawSnapGuides(context, canvas);
    _drawSelection();
    _drawSelectionBox(context);
  }

  @override
  void drawRect(stub.CanvasRect rect) {
    final context = _context;
    if (context == null) return;
    _activeCanvasController = this;
    context.save();
    _rotateAround(
      context,
      rect.x + rect.width / 2,
      rect.y + rect.height / 2,
      rect.rotation,
    );
    _applyPaint(context, rect.paint);

    if (rect.borderRadius > 0) {
      context.beginPath();
      context.roundRect(
        rect.x,
        rect.y,
        rect.width,
        rect.height,
        rect.borderRadius.toJS,
      );
      if (_hasFill(rect.paint)) context.fill();
      if (_hasStroke(rect.paint)) context.stroke();
      context.restore();
      return;
    }

    if (_hasFill(rect.paint)) {
      context.fillRect(rect.x, rect.y, rect.width, rect.height);
    }
    if (_hasStroke(rect.paint)) {
      context.strokeRect(rect.x, rect.y, rect.width, rect.height);
    }
    context.restore();
  }

  @override
  void drawLine(stub.CanvasLine line) {
    final context = _context;
    if (context == null) return;
    if (!_hasStroke(line.paint)) return;
    _activeCanvasController = this;
    context.save();
    _rotateAround(
      context,
      (line.x1 + line.x2) / 2,
      (line.y1 + line.y2) / 2,
      line.rotation,
    );
    _applyPaint(context, line.paint);
    context.beginPath();
    context.moveTo(line.x1, line.y1);
    context.lineTo(line.x2, line.y2);
    context.stroke();
    context.restore();
  }

  @override
  void drawCircle(stub.CanvasCircle circle) {
    final context = _context;
    if (context == null) return;
    _activeCanvasController = this;
    context.save();
    _rotateAround(context, circle.x, circle.y, circle.rotation);
    _applyPaint(context, circle.paint);
    context.beginPath();
    context.arc(circle.x, circle.y, circle.radius, 0, 6.283185307179586);
    if (_hasFill(circle.paint)) context.fill();
    if (_hasStroke(circle.paint)) context.stroke();
    context.restore();
  }

  @override
  void drawText(stub.CanvasTextObject text) {
    final context = _context;
    if (context == null) return;
    _activeCanvasController = this;
    context.save();
    _rotateAround(
      context,
      text.x + (text.text.length * 5),
      text.y - 8,
      text.rotation,
    );
    _applyPaint(context, text.paint);
    if (_hasFill(text.paint)) {
      context.fillText(text.text, text.x, text.y);
    }
    if (_hasStroke(text.paint)) {
      context.strokeText(text.text, text.x, text.y);
    }
    context.restore();
  }

  @override
  void drawImage(stub.CanvasImageObject image) {
    final context = _context;
    if (context == null) return;
    _activeCanvasController = this;
    final element = _imageFor(image);
    if (element == null || !element.complete) return;

    context.save();
    _rotateAround(
      context,
      image.x + image.width / 2,
      image.y + image.height / 2,
      image.rotation,
    );
    context.drawImage(element, image.x, image.y, image.width, image.height);
    if (_hasStroke(image.paint)) {
      _applyPaint(context, image.paint);
      context.strokeRect(image.x, image.y, image.width, image.height);
    }
    context.restore();
  }

  @override
  String toDataUrl({String type = 'image/png', double? quality}) {
    final canvas = _canvas;
    if (canvas == null) return '';
    return canvas.toDataURL(type, quality?.toJS);
  }

  @override
  void detach() {
    _canvas = null;
    _context = null;
    _dragging = false;
  }

  void _attachPointerListeners(web.HTMLCanvasElement canvas) {
    if (_listenersAttached) return;
    _listenersAttached = true;

    canvas.addEventListener(
      'mousedown',
      ((web.Event event) {
        if (event is! web.MouseEvent) return;
        canvas.focus();
        final x = event.offsetX;
        final y = event.offsetY;
        final handle = _hitSelectionHandle(x, y);
        final hitObject = hitTest(x, y);
        onPointerDown?.call(
          _pointerEvent(x, y, object: hitObject, handle: handle),
        );
        if (handle == null) {
          if (event.shiftKey) {
            toggleSelectionAt(x, y);
          } else {
            final object = hitObject;
            final id = object?.id;
            if (id == null || !selectedObjectIds.contains(id)) {
              selectAt(x, y);
            }
          }
        }
        _activeHandle = handle;
        final emptySelectionDrag = handle == null && hitObject == null;
        _dragging =
            _activeHandle != null ||
            selectedObjectIds.isNotEmpty ||
            emptySelectionDrag;
        _activeOperation = switch (handle) {
          stub.CanvasSelectionHandle.rotate => _CanvasOperation.rotate,
          null =>
            emptySelectionDrag
                ? _CanvasOperation.selectBox
                : selectedObjectIds.isNotEmpty
                ? _CanvasOperation.drag
                : _CanvasOperation.none,
          _ => _CanvasOperation.resize,
        };
        if (_activeOperation == _CanvasOperation.selectBox) {
          _selectionStartX = x;
          _selectionStartY = y;
          _selectionCurrentX = x;
          _selectionCurrentY = y;
          select(null);
        } else if (_activeOperation != _CanvasOperation.none) {
          beginHistoryBatch();
        }
        _emitOperationStart(x, y, handle);
        _lastX = x;
        _lastY = y;
        event.preventDefault();
      }).toJS,
    );

    canvas.addEventListener(
      'mousemove',
      ((web.Event event) {
        if (!_dragging || event is! web.MouseEvent) return;
        final x = event.offsetX;
        final y = event.offsetY;
        final handle = _activeHandle;
        if (handle == stub.CanvasSelectionHandle.rotate) {
          _rotateSelectedToPointer(x, y);
        } else if (handle != null) {
          resizeSelectedFromHandle(handle, x - _lastX, y - _lastY);
        } else if (_activeOperation == _CanvasOperation.selectBox) {
          _selectionCurrentX = x;
          _selectionCurrentY = y;
          render();
        } else {
          moveSelectedBy(x - _lastX, y - _lastY);
        }
        _lastX = x;
        _lastY = y;
        event.preventDefault();
      }).toJS,
    );

    void stopDrag(web.Event event) {
      final pointer = event is web.MouseEvent
          ? _pointerEvent(event.offsetX, event.offsetY, handle: _activeHandle)
          : _pointerEvent(_lastX, _lastY, handle: _activeHandle);
      if (_activeOperation == _CanvasOperation.selectBox) {
        _selectionCurrentX = pointer.x;
        _selectionCurrentY = pointer.y;
        final bounds = _selectionBounds;
        if (bounds != null) selectInBounds(bounds);
        _clearSelectionBox();
      } else if (_activeOperation != _CanvasOperation.none) {
        endHistoryBatch();
      }
      onPointerUp?.call(pointer);
      _emitOperationEnd(pointer);
      _dragging = false;
      _activeHandle = null;
      _activeOperation = _CanvasOperation.none;
    }

    canvas.addEventListener('mouseup', stopDrag.toJS);
    canvas.addEventListener('mouseleave', stopDrag.toJS);

    canvas.addEventListener(
      'mousemove',
      ((web.Event event) {
        if (_dragging || event is! web.MouseEvent) return;
        final object = hitTest(event.offsetX, event.offsetY);
        if (object?.id == _hoveredObjectId) return;
        _hoveredObjectId = object?.id;
        onHover?.call(
          _pointerEvent(event.offsetX, event.offsetY, object: object),
        );
      }).toJS,
    );

    canvas.addEventListener(
      'keydown',
      ((web.Event event) {
        if (event is! web.KeyboardEvent) return;
        final handled = handleKeyboardCommand(
          event.key,
          control: event.ctrlKey,
          meta: event.metaKey,
          shift: event.shiftKey,
        );
        if (handled) event.preventDefault();
      }).toJS,
    );

    canvas.addEventListener(
      'dblclick',
      ((web.Event event) {
        if (event is! web.MouseEvent) return;
        final object = hitTest(event.offsetX, event.offsetY);
        if (object is! stub.CanvasTextObject ||
            object.id == null ||
            object.locked) {
          return;
        }
        select(object.id);
        final edited =
            onTextEdit?.call(object) ??
            web.window.prompt('Edit text', object.text);
        if (edited != null) updateText(object.id!, edited);
        event.preventDefault();
      }).toJS,
    );
  }

  void _drawSelection() {
    final context = _context;
    final selected = selectedObjects;
    if (context == null || selected.isEmpty) return;

    context.save();
    context.strokeStyle = '#2563eb'.toJS;
    context.lineWidth = 1.5;
    for (final object in selected) {
      if (object.hidden) continue;
      _drawObjectSelection(context, object);
    }
    _drawSelectionHandles(context);
    context.restore();
  }

  void _drawGrid(
    web.CanvasRenderingContext2D context,
    web.HTMLCanvasElement canvas,
  ) {
    if (!showGrid || gridSize <= 0) return;
    context.save();
    context.strokeStyle = 'rgba(148, 163, 184, 0.35)'.toJS;
    context.lineWidth = 1;
    context.beginPath();
    for (var x = 0.0; x <= canvas.width; x += gridSize) {
      context.moveTo(x, 0);
      context.lineTo(x, canvas.height.toDouble());
    }
    for (var y = 0.0; y <= canvas.height; y += gridSize) {
      context.moveTo(0, y);
      context.lineTo(canvas.width.toDouble(), y);
    }
    context.stroke();
    context.restore();
  }

  void _drawRulers(
    web.CanvasRenderingContext2D context,
    web.HTMLCanvasElement canvas,
  ) {
    if (!showRulers) return;
    final step = gridSize > 0 ? gridSize : 25.0;
    context.save();
    context.fillStyle = 'rgba(248, 250, 252, 0.94)'.toJS;
    context.fillRect(0, 0, canvas.width.toDouble(), 20);
    context.fillRect(0, 0, 20, canvas.height.toDouble());
    context.strokeStyle = 'rgba(100, 116, 139, 0.7)'.toJS;
    context.fillStyle = '#475569'.toJS;
    context.lineWidth = 1;
    context.font = '10px sans-serif';
    context.beginPath();
    for (var x = 0.0; x <= canvas.width; x += step) {
      context.moveTo(x, 20);
      context.lineTo(x, x == 0 ? 0 : 12);
      if (x > 0) context.fillText(x.round().toString(), x + 2, 10);
    }
    for (var y = 0.0; y <= canvas.height; y += step) {
      context.moveTo(20, y);
      context.lineTo(y == 0 ? 0 : 12, y);
      if (y > 0) context.fillText(y.round().toString(), 2, y - 2);
    }
    context.stroke();
    context.restore();
  }

  void _drawSnapGuides(
    web.CanvasRenderingContext2D context,
    web.HTMLCanvasElement canvas,
  ) {
    if (!showSnapGuides || snapGuides.isEmpty) return;
    context.save();
    context.strokeStyle = '#f97316'.toJS;
    context.lineWidth = 1;
    context.beginPath();
    for (final guide in snapGuides) {
      switch (guide.orientation) {
        case stub.CanvasGuideOrientation.vertical:
          context.moveTo(guide.position, 0);
          context.lineTo(guide.position, canvas.height.toDouble());
        case stub.CanvasGuideOrientation.horizontal:
          context.moveTo(0, guide.position);
          context.lineTo(canvas.width.toDouble(), guide.position);
      }
    }
    context.stroke();
    context.restore();
  }

  void _drawObjectSelection(
    web.CanvasRenderingContext2D context,
    stub.CanvasObject selected,
  ) {
    switch (selected) {
      case stub.CanvasRect rect:
        context.save();
        _rotateAround(
          context,
          rect.x + rect.width / 2,
          rect.y + rect.height / 2,
          rect.rotation,
        );
        context.strokeRect(
          rect.x - 3,
          rect.y - 3,
          rect.width + 6,
          rect.height + 6,
        );
        context.restore();
      case stub.CanvasCircle circle:
        context.save();
        _rotateAround(context, circle.x, circle.y, circle.rotation);
        context.beginPath();
        context.arc(
          circle.x,
          circle.y,
          circle.radius + 4,
          0,
          6.283185307179586,
        );
        context.stroke();
        context.restore();
      case stub.CanvasLine line:
        context.save();
        _rotateAround(
          context,
          (line.x1 + line.x2) / 2,
          (line.y1 + line.y2) / 2,
          line.rotation,
        );
        context.beginPath();
        context.moveTo(line.x1, line.y1);
        context.lineTo(line.x2, line.y2);
        context.stroke();
        context.restore();
      case stub.CanvasTextObject text:
        context.save();
        _rotateAround(
          context,
          text.x + (text.text.length * 5),
          text.y - 8,
          text.rotation,
        );
        context.strokeRect(
          text.x - 3,
          text.y - 22,
          text.text.length * 10 + 6,
          28,
        );
        context.restore();
      case stub.CanvasImageObject image:
        context.save();
        _rotateAround(
          context,
          image.x + image.width / 2,
          image.y + image.height / 2,
          image.rotation,
        );
        context.strokeRect(
          image.x - 3,
          image.y - 3,
          image.width + 6,
          image.height + 6,
        );
        context.restore();
      default:
        break;
    }
  }

  void _drawSelectionHandles(web.CanvasRenderingContext2D context) {
    final bounds = selectedBounds;
    if (bounds == null) return;
    final selected = selectedObject;
    final rotation = selectedObjects.length == 1 && selected != null
        ? selected.rotation
        : 0.0;
    context.save();
    _rotateAround(context, bounds.centerX, bounds.centerY, rotation);
    context.strokeStyle = '#2563eb'.toJS;
    context.fillStyle = '#ffffff'.toJS;
    context.lineWidth = 1.5;
    context.beginPath();
    context.moveTo(bounds.centerX, bounds.top - 4);
    context.lineTo(bounds.centerX, bounds.top - 24);
    context.stroke();
    for (final point in _handlePoints(bounds).entries) {
      if (point.key == stub.CanvasSelectionHandle.rotate) {
        context.beginPath();
        context.arc(point.value.$1, point.value.$2, 5, 0, 6.283185307179586);
        context.fill();
        context.stroke();
      } else {
        context.fillRect(point.value.$1 - 4, point.value.$2 - 4, 8, 8);
        context.strokeRect(point.value.$1 - 4, point.value.$2 - 4, 8, 8);
      }
    }
    context.restore();
  }

  void _drawSelectionBox(web.CanvasRenderingContext2D context) {
    final bounds = _selectionBounds;
    if (bounds == null) return;
    context.save();
    context.strokeStyle = '#2563eb'.toJS;
    context.fillStyle = 'rgba(37, 99, 235, 0.12)'.toJS;
    context.lineWidth = 1;
    context.fillRect(bounds.x, bounds.y, bounds.width, bounds.height);
    context.strokeRect(bounds.x, bounds.y, bounds.width, bounds.height);
    context.restore();
  }

  stub.CanvasSelectionHandle? _hitSelectionHandle(double x, double y) {
    final bounds = selectedBounds;
    if (bounds == null) return null;
    final selected = selectedObject;
    final rotation = selectedObjects.length == 1 && selected != null
        ? selected.rotation
        : 0.0;
    final point = _unrotatePoint(
      x,
      y,
      bounds.centerX,
      bounds.centerY,
      rotation,
    );
    for (final entry in _handlePoints(bounds).entries) {
      final dx = point.$1 - entry.value.$1;
      final dy = point.$2 - entry.value.$2;
      if ((dx * dx) + (dy * dy) <= 64) return entry.key;
    }
    return null;
  }

  void _rotateSelectedToPointer(double x, double y) {
    final bounds = selectedBounds;
    if (bounds == null) return;
    final radians = math.atan2(y - bounds.centerY, x - bounds.centerX);
    setSelectedRotation(radians * 180 / math.pi + 90);
  }

  stub.CanvasPointerEvent _pointerEvent(
    double x,
    double y, {
    stub.CanvasObject? object,
    stub.CanvasSelectionHandle? handle,
  }) {
    return stub.CanvasPointerEvent(
      x: x,
      y: y,
      object: object ?? selectedObject,
      handle: handle,
    );
  }

  void _emitOperationStart(
    double x,
    double y,
    stub.CanvasSelectionHandle? handle,
  ) {
    final event = _pointerEvent(x, y, handle: handle);
    switch (_activeOperation) {
      case _CanvasOperation.drag:
        onDragStart?.call(event);
      case _CanvasOperation.resize:
        onResizeStart?.call(event);
      case _CanvasOperation.rotate:
        onRotateStart?.call(event);
      case _CanvasOperation.none:
        break;
      case _CanvasOperation.selectBox:
        break;
    }
  }

  void _emitOperationEnd(stub.CanvasPointerEvent event) {
    switch (_activeOperation) {
      case _CanvasOperation.drag:
        onDragEnd?.call(event);
      case _CanvasOperation.resize:
        onResizeEnd?.call(event);
      case _CanvasOperation.rotate:
        onRotateEnd?.call(event);
      case _CanvasOperation.none:
        break;
      case _CanvasOperation.selectBox:
        break;
    }
  }

  stub.CanvasBounds? get _selectionBounds {
    final startX = _selectionStartX;
    final startY = _selectionStartY;
    final currentX = _selectionCurrentX;
    final currentY = _selectionCurrentY;
    if (startX == null ||
        startY == null ||
        currentX == null ||
        currentY == null) {
      return null;
    }
    final left = math.min(startX, currentX);
    final top = math.min(startY, currentY);
    return stub.CanvasBounds(
      x: left,
      y: top,
      width: (currentX - startX).abs(),
      height: (currentY - startY).abs(),
    );
  }

  void _clearSelectionBox() {
    _selectionStartX = null;
    _selectionStartY = null;
    _selectionCurrentX = null;
    _selectionCurrentY = null;
  }
}

enum _CanvasOperation { none, drag, resize, rotate, selectBox }

Map<stub.CanvasSelectionHandle, (double, double)> _handlePoints(
  stub.CanvasBounds bounds,
) {
  return {
    stub.CanvasSelectionHandle.resizeNorthWest: (bounds.left, bounds.top),
    stub.CanvasSelectionHandle.resizeNorthEast: (bounds.right, bounds.top),
    stub.CanvasSelectionHandle.resizeSouthEast: (bounds.right, bounds.bottom),
    stub.CanvasSelectionHandle.resizeSouthWest: (bounds.left, bounds.bottom),
    stub.CanvasSelectionHandle.rotate: (bounds.centerX, bounds.top - 28),
  };
}

(double, double) _unrotatePoint(
  double x,
  double y,
  double centerX,
  double centerY,
  double degrees,
) {
  if (degrees == 0) return (x, y);
  final radians = -degrees * math.pi / 180;
  final dx = x - centerX;
  final dy = y - centerY;
  return (
    centerX + dx * math.cos(radians) - dy * math.sin(radians),
    centerY + dx * math.sin(radians) + dy * math.cos(radians),
  );
}

web.HTMLImageElement? _imageFor(stub.CanvasImageObject object) {
  final controller = _activeCanvasController;
  if (controller == null) return null;

  final cached = controller._objectImages[object.src];
  if (cached != null) return cached;

  if (!controller._loadingObjects.contains(object.src)) {
    controller._loadingObjects.add(object.src);
    final image = web.HTMLImageElement();
    if (object.crossOrigin != null) image.crossOrigin = object.crossOrigin;
    image.onload = ((web.Event _) {
      controller._objectImages[object.src] = image;
      controller._loadingObjects.remove(object.src);
      controller.render();
    }).toJS;
    image.onerror = ((web.Event _) {
      controller._loadingObjects.remove(object.src);
    }).toJS;
    image.src = object.src;
  }

  return null;
}

void _rotateAround(
  web.CanvasRenderingContext2D context,
  double x,
  double y,
  double degrees,
) {
  if (degrees == 0) return;
  context.translate(x, y);
  context.rotate(degrees * 3.141592653589793 / 180);
  context.translate(-x, -y);
}

void _applyPaint(web.CanvasRenderingContext2D context, stub.CanvasPaint paint) {
  context.lineWidth = paint.lineWidth;
  context.font = paint.font;
  final pattern = paint.pattern;
  if (pattern != null) {
    final fillPattern = _patternFor(context, pattern);
    if (fillPattern != null) {
      context.fillStyle = fillPattern;
    } else if (paint.fill != null) {
      context.fillStyle = paint.fill!.toJS;
    }
  } else if (paint.fill != null) {
    context.fillStyle = paint.fill!.toJS;
  }
  if (_hasStroke(paint)) context.strokeStyle = paint.stroke!.toJS;
}

web.CanvasPattern? _patternFor(
  web.CanvasRenderingContext2D context,
  stub.CanvasImagePattern pattern,
) {
  final controller = _activeCanvasController;
  if (controller == null) return null;

  final cached = controller._patternImages[pattern.src];
  if (cached != null && cached.complete) {
    return context.createPattern(cached, pattern.repetition.value);
  }

  if (!controller._loadingPatterns.contains(pattern.src)) {
    controller._loadingPatterns.add(pattern.src);
    final image = web.HTMLImageElement();
    if (pattern.crossOrigin != null) image.crossOrigin = pattern.crossOrigin;
    image.onload = ((web.Event _) {
      controller._patternImages[pattern.src] = image;
      controller._loadingPatterns.remove(pattern.src);
      controller.render();
    }).toJS;
    image.onerror = ((web.Event _) {
      controller._loadingPatterns.remove(pattern.src);
    }).toJS;
    image.src = pattern.src;
  }

  return null;
}

CanvasController? _activeCanvasController;

bool _hasFill(stub.CanvasPaint paint) =>
    paint.fill != null || paint.pattern != null;

bool _hasStroke(stub.CanvasPaint paint) =>
    paint.stroke != null && paint.lineWidth > 0;
