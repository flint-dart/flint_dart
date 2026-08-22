import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Shared style for Flint canvas drawing operations.
class CanvasPaint {
  /// Creates canvas paint settings.
  const CanvasPaint({
    this.fill,
    this.pattern,
    this.stroke = '#111827',
    this.lineWidth = 1,
    this.font = '16px sans-serif',
  });

  /// Fill color. When null, fill operations are skipped.
  final String? fill;

  /// Image pattern fill. When provided, browser builds use it before [fill].
  final CanvasImagePattern? pattern;

  /// Stroke color. When null, stroke operations are skipped.
  final String? stroke;

  /// Stroke width in canvas pixels.
  final double lineWidth;

  /// CSS canvas font string used for text operations.
  final String font;

  /// Creates a copy with selected paint values replaced.
  CanvasPaint copyWith({
    String? fill,
    CanvasImagePattern? pattern,
    String? stroke,
    double? lineWidth,
    String? font,
    bool clearFill = false,
    bool clearPattern = false,
    bool clearStroke = false,
  }) {
    return CanvasPaint(
      fill: clearFill ? null : fill ?? this.fill,
      pattern: clearPattern ? null : pattern ?? this.pattern,
      stroke: clearStroke ? null : stroke ?? this.stroke,
      lineWidth: lineWidth ?? this.lineWidth,
      font: font ?? this.font,
    );
  }

  /// Converts paint settings to a JSON-friendly map.
  Map<String, Object?> toJson() => {
    if (fill != null) 'fill': fill,
    if (pattern != null) 'pattern': pattern!.toJson(),
    if (stroke != null) 'stroke': stroke,
    'lineWidth': lineWidth,
    'font': font,
  };

  /// Creates paint settings from [json].
  factory CanvasPaint.fromJson(Map<String, Object?> json) {
    return CanvasPaint(
      fill: json['fill']?.toString(),
      pattern: json['pattern'] is Map
          ? CanvasImagePattern.fromJson(
              Map<String, Object?>.from(json['pattern'] as Map),
            )
          : null,
      stroke: json.containsKey('stroke')
          ? json['stroke']?.toString()
          : '#111827',
      lineWidth: _toDouble(json['lineWidth'], fallback: 1),
      font: json['font']?.toString() ?? '16px sans-serif',
    );
  }
}

/// Image pattern fill for canvas shapes.
///
/// This is similar to using `createPattern(image, repetition)` in the browser
/// Canvas API. Browser builds load [src], create a canvas pattern, and redraw
/// the retained scene when the image is ready.
class CanvasImagePattern {
  /// Creates an image pattern fill.
  const CanvasImagePattern({
    required this.src,
    this.repetition = CanvasPatternRepetition.repeat,
    this.crossOrigin,
  });

  /// Image URL used for the pattern.
  final String src;

  /// Pattern repeat behavior.
  final CanvasPatternRepetition repetition;

  /// Optional browser CORS setting for the image.
  final String? crossOrigin;

  /// Converts this pattern to a JSON-friendly map.
  Map<String, Object?> toJson() => {
    'src': src,
    'repetition': repetition.value,
    if (crossOrigin != null) 'crossOrigin': crossOrigin,
  };

  /// Creates an image pattern from [json].
  factory CanvasImagePattern.fromJson(Map<String, Object?> json) {
    return CanvasImagePattern(
      src: json['src']?.toString() ?? '',
      repetition: CanvasPatternRepetition.fromValue(
        json['repetition']?.toString(),
      ),
      crossOrigin: json['crossOrigin']?.toString(),
    );
  }
}

/// Browser canvas pattern repetition options.
enum CanvasPatternRepetition {
  /// Repeat horizontally and vertically.
  repeat('repeat'),

  /// Repeat horizontally only.
  repeatX('repeat-x'),

  /// Repeat vertically only.
  repeatY('repeat-y'),

  /// Do not repeat the image.
  noRepeat('no-repeat');

  /// Browser `createPattern` repetition value.
  final String value;

  /// Creates a pattern repetition option.
  const CanvasPatternRepetition(this.value);

  /// Resolves a browser repetition value.
  static CanvasPatternRepetition fromValue(String? value) {
    for (final option in values) {
      if (option.value == value) return option;
    }
    return CanvasPatternRepetition.repeat;
  }
}

/// Selection handles shown around a selected canvas object.
enum CanvasSelectionHandle {
  /// Top-left resize handle.
  resizeNorthWest,

  /// Top-right resize handle.
  resizeNorthEast,

  /// Bottom-right resize handle.
  resizeSouthEast,

  /// Bottom-left resize handle.
  resizeSouthWest,

  /// Rotation handle above the selected object.
  rotate,
}

/// Alignment commands for selected canvas objects.
enum CanvasAlignment {
  /// Align selected objects to the left edge of the selection bounds.
  left,

  /// Align selected objects to the horizontal center of the selection bounds.
  center,

  /// Align selected objects to the right edge of the selection bounds.
  right,

  /// Align selected objects to the top edge of the selection bounds.
  top,

  /// Align selected objects to the vertical middle of the selection bounds.
  middle,

  /// Align selected objects to the bottom edge of the selection bounds.
  bottom,
}

/// Snap guide orientation.
enum CanvasGuideOrientation {
  /// Vertical guide at an x position.
  vertical,

  /// Horizontal guide at a y position.
  horizontal,
}

/// Axis-aligned bounds for a retained canvas object.
class CanvasBounds {
  /// Creates canvas bounds.
  const CanvasBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Left coordinate in canvas space.
  final double x;

  /// Top coordinate in canvas space.
  final double y;

  /// Bounds width in canvas units.
  final double width;

  /// Bounds height in canvas units.
  final double height;

  /// Left edge in canvas space.
  double get left => x;

  /// Top edge in canvas space.
  double get top => y;

  /// Right edge in canvas space.
  double get right => x + width;

  /// Bottom edge in canvas space.
  double get bottom => y + height;

  /// Horizontal center in canvas space.
  double get centerX => x + width / 2;

  /// Vertical center in canvas space.
  double get centerY => y + height / 2;
}

/// Visual snap guide.
class CanvasGuide {
  /// Creates a visual snap guide.
  const CanvasGuide({required this.orientation, required this.position});

  /// Guide orientation.
  final CanvasGuideOrientation orientation;

  /// Guide position in canvas space.
  final double position;
}

/// Canvas object editing constraints.
///
/// Constraints are enforced by controller resize and move operations. Browser
/// controllers automatically know the mounted canvas size; server-safe stubs
/// can call [CanvasController.setCanvasSize] when `preventOutsideCanvas` is
/// needed during tests or SSR-compatible logic.
class CanvasObjectConstraints {
  /// Creates object editing constraints.
  const CanvasObjectConstraints({
    this.minWidth = 1,
    this.minHeight = 1,
    this.maxWidth,
    this.maxHeight,
    this.keepAspectRatio = false,
    this.lockMovementX = false,
    this.lockMovementY = false,
    this.preventOutsideCanvas = false,
  });

  /// Minimum object width.
  final double minWidth;

  /// Minimum object height.
  final double minHeight;

  /// Optional maximum object width.
  final double? maxWidth;

  /// Optional maximum object height.
  final double? maxHeight;

  /// Whether resize operations should preserve aspect ratio.
  final bool keepAspectRatio;

  /// Whether horizontal movement is locked.
  final bool lockMovementX;

  /// Whether vertical movement is locked.
  final bool lockMovementY;

  /// Whether objects should stay inside the canvas viewport.
  final bool preventOutsideCanvas;
}

/// Layer-panel metadata for a retained canvas object.
class CanvasLayerItem {
  /// Creates a layer item.
  const CanvasLayerItem({
    required this.id,
    required this.name,
    required this.type,
    required this.zIndex,
    required this.selected,
    required this.locked,
    required this.hidden,
  });

  /// Object id, when the retained object has one.
  final String? id;

  /// Human-friendly layer name.
  final String name;

  /// Retained object type, such as `rect`, `text`, or `image`.
  final String type;

  /// Zero-based object index in the retained scene.
  final int zIndex;

  /// Whether this layer is currently selected.
  final bool selected;

  /// Whether this layer is locked against editing.
  final bool locked;

  /// Whether this layer is hidden from drawing and hit testing.
  final bool hidden;
}

/// Pointer event payload for browser canvas interactions.
class CanvasPointerEvent {
  /// Creates a canvas pointer event payload.
  const CanvasPointerEvent({
    required this.x,
    required this.y,
    this.object,
    this.handle,
  });

  /// Pointer x coordinate in canvas space.
  final double x;

  /// Pointer y coordinate in canvas space.
  final double y;

  /// Topmost object under the pointer, when available.
  final CanvasObject? object;

  /// Selection handle under the pointer, when available.
  final CanvasSelectionHandle? handle;
}

/// Called when canvas selection changes.
typedef CanvasSelectCallback = void Function(List<CanvasObject> selected);

/// Called when retained canvas objects change.
typedef CanvasChangeCallback = void Function(CanvasController controller);

/// Called after selected canvas objects move, resize, or rotate.
typedef CanvasObjectsCallback = void Function(List<CanvasObject> objects);

/// Called when browser text editing starts for a text object.
typedef CanvasTextEditCallback = String? Function(CanvasTextObject text);

/// Called for pointer-level canvas events.
typedef CanvasPointerCallback = void Function(CanvasPointerEvent event);

/// Called after undo or redo changes the scene.
typedef CanvasHistoryCallback = void Function(CanvasController controller);

/// Base class for retained canvas objects.
abstract class CanvasObject {
  /// Creates a retained canvas object.
  const CanvasObject({
    this.id,
    this.name,
    this.paint = const CanvasPaint(),
    this.rotation = 0,
    this.locked = false,
    this.hidden = false,
  });

  /// Optional app-level object identifier.
  final String? id;

  /// Optional display name for layer panels.
  final String? name;

  /// Paint settings for this object.
  final CanvasPaint paint;

  /// Clockwise rotation in degrees.
  final double rotation;

  /// Whether this object can be selected but not edited.
  final bool locked;

  /// Whether this object is hidden from drawing and pointer hit testing.
  final bool hidden;

  /// Object type name used for JSON serialization.
  String get type;

  /// Converts this object to a JSON-friendly map.
  Map<String, Object?> toJson();
}

/// Retained rectangle object.
class CanvasRect extends CanvasObject {
  /// Creates a rectangle.
  const CanvasRect({
    super.id,
    super.name,
    super.paint,
    super.rotation,
    super.locked,
    super.hidden,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.borderRadius = 0,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  /// Corner radius in canvas pixels.
  ///
  /// Set to `0` for square corners.
  final double borderRadius;

  @override
  String get type => 'rect';

  /// Creates a copy with selected values replaced.
  CanvasRect copyWith({
    String? id,
    String? name,
    CanvasPaint? paint,
    double? rotation,
    bool? locked,
    bool? hidden,
    double? x,
    double? y,
    double? width,
    double? height,
    double? borderRadius,
  }) {
    return CanvasRect(
      id: id ?? this.id,
      name: name ?? this.name,
      paint: paint ?? this.paint,
      rotation: rotation ?? this.rotation,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    if (id != null) 'id': id,
    if (name != null) 'name': name,
    'paint': paint.toJson(),
    'rotation': rotation,
    'locked': locked,
    'hidden': hidden,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'borderRadius': borderRadius,
  };
}

/// Retained line object.
class CanvasLine extends CanvasObject {
  /// Creates a line.
  const CanvasLine({
    super.id,
    super.name,
    super.paint,
    super.rotation,
    super.locked,
    super.hidden,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;

  @override
  String get type => 'line';

  /// Creates a copy with selected values replaced.
  CanvasLine copyWith({
    String? id,
    String? name,
    CanvasPaint? paint,
    double? rotation,
    bool? locked,
    bool? hidden,
    double? x1,
    double? y1,
    double? x2,
    double? y2,
  }) {
    return CanvasLine(
      id: id ?? this.id,
      name: name ?? this.name,
      paint: paint ?? this.paint,
      rotation: rotation ?? this.rotation,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      x1: x1 ?? this.x1,
      y1: y1 ?? this.y1,
      x2: x2 ?? this.x2,
      y2: y2 ?? this.y2,
    );
  }

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    if (id != null) 'id': id,
    if (name != null) 'name': name,
    'paint': paint.toJson(),
    'rotation': rotation,
    'locked': locked,
    'hidden': hidden,
    'x1': x1,
    'y1': y1,
    'x2': x2,
    'y2': y2,
  };
}

/// Retained circle object.
class CanvasCircle extends CanvasObject {
  /// Creates a circle.
  const CanvasCircle({
    super.id,
    super.name,
    super.paint,
    super.rotation,
    super.locked,
    super.hidden,
    required this.x,
    required this.y,
    required this.radius,
  });

  final double x;
  final double y;
  final double radius;

  @override
  String get type => 'circle';

  /// Creates a copy with selected values replaced.
  CanvasCircle copyWith({
    String? id,
    String? name,
    CanvasPaint? paint,
    double? rotation,
    bool? locked,
    bool? hidden,
    double? x,
    double? y,
    double? radius,
  }) {
    return CanvasCircle(
      id: id ?? this.id,
      name: name ?? this.name,
      paint: paint ?? this.paint,
      rotation: rotation ?? this.rotation,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      x: x ?? this.x,
      y: y ?? this.y,
      radius: radius ?? this.radius,
    );
  }

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    if (id != null) 'id': id,
    if (name != null) 'name': name,
    'paint': paint.toJson(),
    'rotation': rotation,
    'locked': locked,
    'hidden': hidden,
    'x': x,
    'y': y,
    'radius': radius,
  };
}

/// Retained text object.
class CanvasTextObject extends CanvasObject {
  /// Creates text.
  const CanvasTextObject({
    super.id,
    super.name,
    super.paint,
    super.rotation,
    super.locked,
    super.hidden,
    required this.text,
    required this.x,
    required this.y,
  });

  final String text;
  final double x;
  final double y;

  @override
  String get type => 'text';

  /// Creates a copy with selected values replaced.
  CanvasTextObject copyWith({
    String? id,
    String? name,
    CanvasPaint? paint,
    double? rotation,
    bool? locked,
    bool? hidden,
    String? text,
    double? x,
    double? y,
  }) {
    return CanvasTextObject(
      id: id ?? this.id,
      name: name ?? this.name,
      paint: paint ?? this.paint,
      rotation: rotation ?? this.rotation,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    if (id != null) 'id': id,
    if (name != null) 'name': name,
    'paint': paint.toJson(),
    'rotation': rotation,
    'locked': locked,
    'hidden': hidden,
    'text': text,
    'x': x,
    'y': y,
  };
}

/// Retained image object.
class CanvasImageObject extends CanvasObject {
  /// Creates an image object.
  const CanvasImageObject({
    super.id,
    super.name,
    super.paint,
    super.rotation,
    super.locked,
    super.hidden,
    required this.src,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.crossOrigin,
  });

  /// Image URL.
  final String src;

  final double x;
  final double y;
  final double width;
  final double height;

  /// Optional browser CORS setting.
  final String? crossOrigin;

  @override
  String get type => 'image';

  /// Creates a copy with selected values replaced.
  CanvasImageObject copyWith({
    String? id,
    String? name,
    CanvasPaint? paint,
    double? rotation,
    bool? locked,
    bool? hidden,
    String? src,
    double? x,
    double? y,
    double? width,
    double? height,
    String? crossOrigin,
  }) {
    return CanvasImageObject(
      id: id ?? this.id,
      name: name ?? this.name,
      paint: paint ?? this.paint,
      rotation: rotation ?? this.rotation,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      src: src ?? this.src,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      crossOrigin: crossOrigin ?? this.crossOrigin,
    );
  }

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    if (id != null) 'id': id,
    if (name != null) 'name': name,
    'paint': paint.toJson(),
    'rotation': rotation,
    'locked': locked,
    'hidden': hidden,
    'src': src,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    if (crossOrigin != null) 'crossOrigin': crossOrigin,
  };
}

/// Creates a retained canvas object from JSON.
CanvasObject canvasObjectFromJson(Map<String, Object?> json) {
  final paint = json['paint'] is Map
      ? CanvasPaint.fromJson(Map<String, Object?>.from(json['paint'] as Map))
      : const CanvasPaint();
  final id = json['id']?.toString();
  final name = json['name']?.toString();
  final locked = json['locked'] == true;
  final hidden = json['hidden'] == true;
  return switch (json['type']?.toString()) {
    'rect' => CanvasRect(
      id: id,
      name: name,
      paint: paint,
      rotation: _toDouble(json['rotation']),
      locked: locked,
      hidden: hidden,
      x: _toDouble(json['x']),
      y: _toDouble(json['y']),
      width: _toDouble(json['width']),
      height: _toDouble(json['height']),
      borderRadius: _toDouble(json['borderRadius']),
    ),
    'line' => CanvasLine(
      id: id,
      name: name,
      paint: paint,
      rotation: _toDouble(json['rotation']),
      locked: locked,
      hidden: hidden,
      x1: _toDouble(json['x1']),
      y1: _toDouble(json['y1']),
      x2: _toDouble(json['x2']),
      y2: _toDouble(json['y2']),
    ),
    'circle' => CanvasCircle(
      id: id,
      name: name,
      paint: paint,
      rotation: _toDouble(json['rotation']),
      locked: locked,
      hidden: hidden,
      x: _toDouble(json['x']),
      y: _toDouble(json['y']),
      radius: _toDouble(json['radius']),
    ),
    'text' => CanvasTextObject(
      id: id,
      name: name,
      paint: paint,
      rotation: _toDouble(json['rotation']),
      locked: locked,
      hidden: hidden,
      text: json['text']?.toString() ?? '',
      x: _toDouble(json['x']),
      y: _toDouble(json['y']),
    ),
    'image' => CanvasImageObject(
      id: id,
      name: name,
      paint: paint,
      rotation: _toDouble(json['rotation']),
      locked: locked,
      hidden: hidden,
      src: json['src']?.toString() ?? '',
      x: _toDouble(json['x']),
      y: _toDouble(json['y']),
      width: _toDouble(json['width']),
      height: _toDouble(json['height']),
      crossOrigin: json['crossOrigin']?.toString(),
    ),
    _ => throw ArgumentError('Unknown canvas object type: ${json['type']}'),
  };
}

/// Controller for Flint [Canvas] drawing.
///
/// This server-safe implementation stores retained objects but does not draw.
/// Browser builds bind the controller to the rendered canvas element.
class CanvasController {
  /// Creates a canvas controller.
  CanvasController({
    this.onSelect,
    this.onChange,
    this.onMove,
    this.onResize,
    this.onRotate,
    this.onTextEdit,
    this.onPointerDown,
    this.onPointerUp,
    this.onHover,
    this.onDragStart,
    this.onDragEnd,
    this.onResizeStart,
    this.onResizeEnd,
    this.onRotateStart,
    this.onRotateEnd,
    this.onUndo,
    this.onRedo,
    this.snapToGrid = false,
    this.gridSize = 8,
    this.snapToObjects = false,
    this.snapThreshold = 6,
    this.maxHistoryEntries = 100,
    this.constraints = const CanvasObjectConstraints(),
    this.showGrid = false,
    this.showRulers = false,
    this.showSnapGuides = true,
  });

  /// Fires when selected objects change.
  final CanvasSelectCallback? onSelect;

  /// Fires after retained canvas scene data changes.
  final CanvasChangeCallback? onChange;

  /// Fires after selected objects move.
  final CanvasObjectsCallback? onMove;

  /// Fires after selected objects resize.
  final CanvasObjectsCallback? onResize;

  /// Fires after selected objects rotate.
  final CanvasObjectsCallback? onRotate;

  /// Optional text edit provider used by browser double-click editing.
  final CanvasTextEditCallback? onTextEdit;

  /// Fires on browser pointer down.
  final CanvasPointerCallback? onPointerDown;

  /// Fires on browser pointer up.
  final CanvasPointerCallback? onPointerUp;

  /// Fires when the hovered object changes.
  final CanvasPointerCallback? onHover;

  /// Fires when object dragging starts.
  final CanvasPointerCallback? onDragStart;

  /// Fires when object dragging ends.
  final CanvasPointerCallback? onDragEnd;

  /// Fires when selection-handle resizing starts.
  final CanvasPointerCallback? onResizeStart;

  /// Fires when selection-handle resizing ends.
  final CanvasPointerCallback? onResizeEnd;

  /// Fires when selection-handle rotation starts.
  final CanvasPointerCallback? onRotateStart;

  /// Fires when selection-handle rotation ends.
  final CanvasPointerCallback? onRotateEnd;

  /// Fires after [undo] succeeds.
  final CanvasHistoryCallback? onUndo;

  /// Fires after [redo] succeeds.
  final CanvasHistoryCallback? onRedo;

  /// Whether movement should snap selected objects to [gridSize].
  final bool snapToGrid;

  /// Grid size used by [snapSelectedToGrid] and drag snapping.
  final double gridSize;

  /// Whether movement should snap selected objects to other object edges/centers.
  final bool snapToObjects;

  /// Distance threshold for object edge/center snapping.
  final double snapThreshold;

  /// Maximum undo or redo entries to keep.
  final int maxHistoryEntries;

  /// Object editing constraints.
  final CanvasObjectConstraints constraints;

  /// Whether browser canvas builds should draw a grid.
  final bool showGrid;

  /// Whether browser canvas builds should draw rulers.
  final bool showRulers;

  /// Whether browser canvas builds should draw snap guides.
  final bool showSnapGuides;

  final List<CanvasObject> _objects = [];
  final List<Map<String, Object?>> _undoStack = [];
  final List<Map<String, Object?>> _redoStack = [];
  final List<String> _selectedObjectIds = [];
  final List<CanvasGuide> _snapGuides = [];
  int _historyBatchDepth = 0;
  Map<String, Object?>? _historyBatchSnapshot;
  List<CanvasObject> _clipboard = const [];
  int _copyCount = 0;
  double? _canvasWidth;
  double? _canvasHeight;

  /// Whether the controller is attached to a browser canvas.
  bool get isAttached => false;

  /// Retained canvas objects.
  List<CanvasObject> get objects => List.unmodifiable(_objects);

  /// Whether undo history is available.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether redo history is available.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Active snap guides from the latest snap operation.
  List<CanvasGuide> get snapGuides => List.unmodifiable(_snapGuides);

  /// Currently selected object id.
  String? get selectedObjectId =>
      _selectedObjectIds.isEmpty ? null : _selectedObjectIds.last;

  /// Currently selected object ids.
  List<String> get selectedObjectIds => List.unmodifiable(_selectedObjectIds);

  /// Currently selected object.
  CanvasObject? get selectedObject {
    final id = selectedObjectId;
    return id == null ? null : objectById(id);
  }

  /// Currently selected objects.
  List<CanvasObject> get selectedObjects => [
    for (final id in _selectedObjectIds)
      if (objectById(id) case final object?) object,
  ];

  /// Layer-panel view of retained objects, ordered from front to back.
  List<CanvasLayerItem> get layerItems => [
    for (var index = _objects.length - 1; index >= 0; index -= 1)
      CanvasLayerItem(
        id: _objects[index].id,
        name:
            _objects[index].name ?? _objects[index].id ?? _objects[index].type,
        type: _objects[index].type,
        zIndex: index,
        selected:
            _objects[index].id != null &&
            _selectedObjectIds.contains(_objects[index].id),
        locked: _objects[index].locked,
        hidden: _objects[index].hidden,
      ),
  ];

  /// Bounds for the currently selected object.
  CanvasBounds? get selectedBounds {
    final selected = selectedObjects;
    if (selected.isEmpty) return null;
    return _unionBounds(selected.map(_boundsFor));
  }

  /// Finds a retained object by id.
  CanvasObject? objectById(String id) {
    for (final object in _objects) {
      if (object.id == id) return object;
    }
    return null;
  }

  /// Updates viewport dimensions for canvas-bound constraints.
  void setCanvasSize(double width, double height) {
    _canvasWidth = width;
    _canvasHeight = height;
  }

  /// Adds an object to the retained canvas scene.
  void add(CanvasObject object) {
    _remember();
    _objects.add(object);
    render();
    _emitChange();
  }

  /// Replaces the object with [id].
  bool update(String id, CanvasObject object) {
    final index = _objects.indexWhere((item) => item.id == id);
    if (index < 0) return false;
    _remember();
    _objects[index] = object;
    render();
    _emitChange();
    return true;
  }

  /// Removes a retained object by id.
  ///
  /// Returns true when an object was removed.
  bool remove(String id) {
    final index = _objects.indexWhere((object) => object.id == id);
    if (index < 0) return false;
    _remember();
    _objects.removeAt(index);
    final changedSelection = _selectedObjectIds.remove(id);
    render();
    if (changedSelection) _emitSelect();
    _emitChange();
    return true;
  }

  /// Renames an object's id for layer panels and app-level references.
  bool renameObjectId(String currentId, String nextId) {
    if (currentId == nextId) return objectById(currentId) != null;
    if (objectById(nextId) != null) return false;
    final object = objectById(currentId);
    if (object == null) return false;
    final renamed = _copyObjectWithMeta(object, id: nextId);
    final changed = update(currentId, renamed);
    if (!changed) return false;
    final selectedIndex = _selectedObjectIds.indexOf(currentId);
    if (selectedIndex >= 0) _selectedObjectIds[selectedIndex] = nextId;
    render();
    _emitSelect();
    return true;
  }

  /// Sets a display name for an object.
  bool setObjectName(String id, String? name) {
    final object = objectById(id);
    if (object == null) return false;
    return update(id, _copyObjectWithMeta(object, name: name));
  }

  /// Locks or unlocks an object.
  bool setObjectLocked(String id, bool locked) {
    final object = objectById(id);
    if (object == null) return false;
    return update(id, _copyObjectWithMeta(object, locked: locked));
  }

  /// Hides or shows an object.
  bool setObjectHidden(String id, bool hidden) {
    final object = objectById(id);
    if (object == null) return false;
    return update(id, _copyObjectWithMeta(object, hidden: hidden));
  }

  /// Locks or unlocks selected objects.
  bool setSelectedLocked(bool locked) => _updateSelectedObjects(
    (object) => _copyObjectWithMeta(object, locked: locked),
  );

  /// Hides or shows selected objects.
  bool setSelectedHidden(bool hidden) => _updateSelectedObjects(
    (object) => _copyObjectWithMeta(object, hidden: hidden),
  );

  /// Updates paint on one object.
  bool updateObjectPaint(String id, CanvasPaint paint) {
    final object = objectById(id);
    if (object == null || object.locked) return false;
    return update(id, _copyObjectWithPaint(object, paint));
  }

  /// Updates paint on selected, unlocked objects.
  bool updateSelectedPaint(CanvasPaint paint) {
    return _updateSelectedObjects(
      (object) => object.locked ? object : _copyObjectWithPaint(object, paint),
      skipLocked: true,
    );
  }

  /// Updates selected object style fields while preserving unspecified paint.
  bool styleSelected({
    String? fill,
    CanvasImagePattern? pattern,
    String? stroke,
    double? lineWidth,
    String? font,
    bool clearFill = false,
    bool clearPattern = false,
    bool clearStroke = false,
  }) {
    return _updateSelectedObjects(
      (object) => _copyObjectWithPaint(
        object,
        object.paint.copyWith(
          fill: fill,
          pattern: pattern,
          stroke: stroke,
          lineWidth: lineWidth,
          font: font,
          clearFill: clearFill,
          clearPattern: clearPattern,
          clearStroke: clearStroke,
        ),
      ),
      skipLocked: true,
    );
  }

  /// Updates one text object's text.
  bool updateText(String id, String text) {
    final object = objectById(id);
    if (object is! CanvasTextObject || object.locked) return false;
    return update(id, object.copyWith(text: text));
  }

  /// Updates the selected text object when exactly one text object is selected.
  bool updateSelectedText(String text) {
    final object = selectedObject;
    final id = selectedObjectId;
    if (id == null || object is! CanvasTextObject) return false;
    return updateText(id, text);
  }

  /// Updates font family/size for selected text objects.
  bool setSelectedFont({String? family, double? size, String? cssFont}) {
    return _updateSelectedObjects((object) {
      if (object is! CanvasTextObject) return object;
      final font = cssFont ?? _fontString(object.paint.font, family, size);
      return object.copyWith(paint: object.paint.copyWith(font: font));
    }, skipLocked: true);
  }

  /// Moves an object one step forward in z order.
  bool bringForward(String id) {
    final index = _objects.indexWhere((object) => object.id == id);
    if (index < 0 || index == _objects.length - 1) return false;
    _remember();
    final object = _objects.removeAt(index);
    _objects.insert(index + 1, object);
    render();
    _emitChange();
    return true;
  }

  /// Moves an object one step backward in z order.
  bool sendBackward(String id) {
    final index = _objects.indexWhere((object) => object.id == id);
    if (index <= 0) return false;
    _remember();
    final object = _objects.removeAt(index);
    _objects.insert(index - 1, object);
    render();
    _emitChange();
    return true;
  }

  /// Moves an object to the front of z order.
  bool bringToFront(String id) {
    final index = _objects.indexWhere((object) => object.id == id);
    if (index < 0 || index == _objects.length - 1) return false;
    _remember();
    final object = _objects.removeAt(index);
    _objects.add(object);
    render();
    _emitChange();
    return true;
  }

  /// Moves an object to the back of z order.
  bool sendToBack(String id) {
    final index = _objects.indexWhere((object) => object.id == id);
    if (index <= 0) return false;
    _remember();
    final object = _objects.removeAt(index);
    _objects.insert(0, object);
    render();
    _emitChange();
    return true;
  }

  /// Adds a rectangle object.
  void addRect(CanvasRect rect) => add(rect);

  /// Adds a line object.
  void addLine(CanvasLine line) => add(line);

  /// Adds a circle object.
  void addCircle(CanvasCircle circle) => add(circle);

  /// Adds a text object.
  void addText(CanvasTextObject text) => add(text);

  /// Adds an image object.
  void addImage(CanvasImageObject image) => add(image);

  /// Removes all retained objects and clears the canvas.
  void clear() {
    if (_objects.isEmpty && _selectedObjectIds.isEmpty) return;
    _remember();
    _objects.clear();
    final hadSelection = _selectedObjectIds.isNotEmpty;
    _selectedObjectIds.clear();
    render();
    if (hadSelection) _emitSelect();
    _emitChange();
  }

  /// Selects an object by id.
  bool select(String? id) {
    if (id == null) {
      final changed = _selectedObjectIds.isNotEmpty;
      _selectedObjectIds.clear();
      render();
      if (changed) _emitSelect();
      return true;
    }
    if (objectById(id) == null) return false;
    final changed =
        _selectedObjectIds.length != 1 || _selectedObjectIds.single != id;
    _selectedObjectIds
      ..clear()
      ..add(id);
    render();
    if (changed) _emitSelect();
    return true;
  }

  /// Selects multiple objects by id.
  bool selectMany(Iterable<String> ids) {
    final next = <String>[];
    for (final id in ids) {
      if (objectById(id) != null && !next.contains(id)) next.add(id);
    }
    final changed = !_sameIds(_selectedObjectIds, next);
    _selectedObjectIds
      ..clear()
      ..addAll(next);
    render();
    if (changed) _emitSelect();
    return next.isNotEmpty;
  }

  /// Adds or removes [id] from the current selection.
  bool toggleSelection(String id) {
    if (objectById(id) == null) return false;
    if (_selectedObjectIds.contains(id)) {
      _selectedObjectIds.remove(id);
    } else {
      _selectedObjectIds.add(id);
    }
    render();
    _emitSelect();
    return true;
  }

  /// Selects the topmost object at [x], [y].
  CanvasObject? selectAt(double x, double y) {
    final object = hitTest(x, y);
    final id = object?.id;
    final changed = id == null
        ? _selectedObjectIds.isNotEmpty
        : (_selectedObjectIds.length != 1 || _selectedObjectIds.single != id);
    _selectedObjectIds
      ..clear()
      ..addAll(id == null ? const [] : [id]);
    render();
    if (changed) _emitSelect();
    return object;
  }

  /// Toggles the topmost object at [x], [y] in the current selection.
  CanvasObject? toggleSelectionAt(double x, double y) {
    final object = hitTest(x, y);
    final id = object?.id;
    if (id != null) toggleSelection(id);
    return object;
  }

  /// Selects all visible objects fully contained in [bounds].
  bool selectInBounds(CanvasBounds bounds) {
    final ids = <String>[];
    for (final object in _objects) {
      if (object.id == null || object.hidden) continue;
      final objectBounds = _boundsFor(object);
      if (objectBounds.left >= bounds.left &&
          objectBounds.right <= bounds.right &&
          objectBounds.top >= bounds.top &&
          objectBounds.bottom <= bounds.bottom) {
        ids.add(object.id!);
      }
    }
    return selectMany(ids);
  }

  /// Returns the topmost object at [x], [y].
  CanvasObject? hitTest(double x, double y) {
    for (final object in _objects.reversed) {
      if (object.hidden) continue;
      if (_containsPoint(object, x, y)) return object;
    }
    return null;
  }

  /// Moves an object by [dx], [dy].
  bool moveBy(String id, double dx, double dy) {
    final object = objectById(id);
    if (object == null) return false;
    if (object.locked) return false;
    final moved = _constrainObject(
      object,
      _snapObjectIfNeeded(_moveObject(object, dx, dy), id),
      moving: true,
    );
    final changed = update(id, moved);
    if (changed) onMove?.call(List.unmodifiable([moved]));
    return changed;
  }

  /// Moves the selected object by [dx], [dy].
  bool moveSelectedBy(double dx, double dy) {
    if (_selectedObjectIds.isEmpty) return false;
    _remember();
    final changed = <CanvasObject>[];
    for (final id in _selectedObjectIds) {
      final index = _objects.indexWhere((object) => object.id == id);
      if (index < 0) continue;
      if (_objects[index].locked) continue;
      final moved = _constrainObject(
        _objects[index],
        _moveObject(_objects[index], dx, dy),
        moving: true,
      );
      _objects[index] = moved;
      changed.add(moved);
    }
    if (changed.isEmpty) return false;
    _snapSelectionIfNeeded();
    changed
      ..clear()
      ..addAll(selectedObjects);
    render();
    onMove?.call(List.unmodifiable(changed));
    _emitChange();
    return true;
  }

  /// Moves the selected object with keyboard-style step sizes.
  bool nudgeSelected({double dx = 0, double dy = 0, bool largeStep = false}) {
    final step = largeStep ? 10.0 : 1.0;
    return moveSelectedBy(dx * step, dy * step);
  }

  /// Snaps selected objects to the nearest grid coordinates.
  bool snapSelectedToGrid([double? size]) {
    final grid = size ?? gridSize;
    if (grid <= 0 || _selectedObjectIds.isEmpty) return false;
    _remember();
    final changed = <CanvasObject>[];
    for (final id in _selectedObjectIds) {
      final index = _objects.indexWhere((object) => object.id == id);
      if (index < 0 || _objects[index].locked) continue;
      final bounds = _boundsFor(_objects[index]);
      final dx = _roundTo(bounds.x, grid) - bounds.x;
      final dy = _roundTo(bounds.y, grid) - bounds.y;
      final moved = _moveObject(_objects[index], dx, dy);
      _objects[index] = moved;
      changed.add(moved);
    }
    if (changed.isEmpty) return false;
    render();
    onMove?.call(List.unmodifiable(changed));
    _emitChange();
    return true;
  }

  /// Snaps selected objects to nearby visible object edges or centers.
  bool snapSelectedToObjects({double? threshold}) {
    if (_selectedObjectIds.isEmpty) return false;
    final delta = _objectSnapDelta(threshold ?? snapThreshold);
    if (delta == null) return false;
    return moveSelectedBy(delta.$1, delta.$2);
  }

  /// Aligns selected objects inside the selection bounds.
  bool alignSelected(CanvasAlignment alignment) {
    if (_selectedObjectIds.length < 2) return false;
    final bounds = selectedBounds;
    if (bounds == null) return false;
    _remember();
    final changed = <CanvasObject>[];
    for (final id in _selectedObjectIds) {
      final index = _objects.indexWhere((object) => object.id == id);
      if (index < 0 || _objects[index].locked) continue;
      final objectBounds = _boundsFor(_objects[index]);
      final (dx, dy) = switch (alignment) {
        CanvasAlignment.left => (bounds.left - objectBounds.left, 0.0),
        CanvasAlignment.center => (bounds.centerX - objectBounds.centerX, 0.0),
        CanvasAlignment.right => (bounds.right - objectBounds.right, 0.0),
        CanvasAlignment.top => (0.0, bounds.top - objectBounds.top),
        CanvasAlignment.middle => (0.0, bounds.centerY - objectBounds.centerY),
        CanvasAlignment.bottom => (0.0, bounds.bottom - objectBounds.bottom),
      };
      final moved = _constrainObject(
        _objects[index],
        _moveObject(_objects[index], dx, dy),
        moving: true,
      );
      _objects[index] = moved;
      changed.add(moved);
    }
    if (changed.isEmpty) return false;
    render();
    onMove?.call(List.unmodifiable(changed));
    _emitChange();
    return true;
  }

  /// Resizes an object by [dw], [dh].
  ///
  /// Rectangles update width and height, circles update radius using the
  /// larger delta, lines move their end point, and text keeps position because
  /// text sizing is controlled by [CanvasPaint.font].
  bool resizeBy(String id, double dw, double dh) {
    final object = objectById(id);
    if (object == null) return false;
    if (object.locked) return false;
    final resized = _constrainObject(
      object,
      _resizeObject(object, dw, dh, constraints: constraints),
    );
    final changed = update(id, resized);
    if (changed) onResize?.call(List.unmodifiable([resized]));
    return changed;
  }

  /// Resizes the selected object by [dw], [dh].
  bool resizeSelectedBy(double dw, double dh) {
    if (_selectedObjectIds.isEmpty) return false;
    _remember();
    final changed = <CanvasObject>[];
    for (final id in _selectedObjectIds) {
      final index = _objects.indexWhere((object) => object.id == id);
      if (index < 0) continue;
      if (_objects[index].locked) continue;
      final resized = _constrainObject(
        _objects[index],
        _resizeObject(_objects[index], dw, dh, constraints: constraints),
      );
      _objects[index] = resized;
      changed.add(resized);
    }
    if (changed.isEmpty) return false;
    render();
    onResize?.call(List.unmodifiable(changed));
    _emitChange();
    return true;
  }

  /// Resizes the selected object from a visible selection [handle].
  bool resizeSelectedFromHandle(
    CanvasSelectionHandle handle,
    double dx,
    double dy,
  ) {
    if (_selectedObjectIds.isEmpty) return false;
    if (_selectedObjectIds.length == 1) {
      final id = selectedObjectId;
      final object = selectedObject;
      if (id == null || object == null) return false;
      if (object.locked) return false;
      _remember();
      final resized = _constrainObject(
        object,
        _resizeObjectFromHandle(
          object,
          handle,
          dx,
          dy,
          constraints: constraints,
        ),
      );
      final index = _objects.indexWhere((item) => item.id == id);
      if (index < 0) return false;
      _objects[index] = resized;
      render();
      onResize?.call(List.unmodifiable([resized]));
      _emitChange();
      return true;
    }

    final bounds = selectedBounds;
    if (bounds == null) return false;
    final nextBounds = _boundsFromHandle(bounds, handle, dx, dy);
    final scaleX = bounds.width == 0 ? 1.0 : nextBounds.width / bounds.width;
    final scaleY = bounds.height == 0 ? 1.0 : nextBounds.height / bounds.height;
    _remember();
    final changed = <CanvasObject>[];
    for (final id in _selectedObjectIds) {
      final index = _objects.indexWhere((object) => object.id == id);
      if (index < 0) continue;
      if (_objects[index].locked) continue;
      final resized = _constrainObject(
        _objects[index],
        _scaleObjectInBounds(
          _objects[index],
          bounds,
          nextBounds,
          scaleX,
          scaleY,
          constraints: constraints,
        ),
      );
      _objects[index] = resized;
      changed.add(resized);
    }
    if (changed.isEmpty) return false;
    render();
    onResize?.call(List.unmodifiable(changed));
    _emitChange();
    return true;
  }

  /// Sets an object's rotation in degrees.
  bool setRotation(String id, double degrees) {
    final object = objectById(id);
    if (object == null) return false;
    if (object.locked) return false;
    final rotated = _rotateObject(object, degrees);
    final changed = update(id, rotated);
    if (changed) onRotate?.call(List.unmodifiable([rotated]));
    return changed;
  }

  /// Rotates an object by [degrees].
  bool rotateBy(String id, double degrees) {
    final object = objectById(id);
    if (object == null) return false;
    return setRotation(id, object.rotation + degrees);
  }

  /// Rotates the selected object by [degrees].
  bool rotateSelectedBy(double degrees) {
    if (_selectedObjectIds.isEmpty) return false;
    _remember();
    final changed = <CanvasObject>[];
    for (final id in _selectedObjectIds) {
      final index = _objects.indexWhere((object) => object.id == id);
      if (index < 0) continue;
      if (_objects[index].locked) continue;
      final rotated = _rotateObject(
        _objects[index],
        _objects[index].rotation + degrees,
      );
      _objects[index] = rotated;
      changed.add(rotated);
    }
    if (changed.isEmpty) return false;
    render();
    onRotate?.call(List.unmodifiable(changed));
    _emitChange();
    return true;
  }

  /// Sets all selected objects to [degrees] rotation.
  bool setSelectedRotation(double degrees) {
    if (_selectedObjectIds.isEmpty) return false;
    _remember();
    final changed = <CanvasObject>[];
    for (final id in _selectedObjectIds) {
      final index = _objects.indexWhere((object) => object.id == id);
      if (index < 0) continue;
      if (_objects[index].locked) continue;
      final rotated = _rotateObject(_objects[index], degrees);
      _objects[index] = rotated;
      changed.add(rotated);
    }
    if (changed.isEmpty) return false;
    render();
    onRotate?.call(List.unmodifiable(changed));
    _emitChange();
    return true;
  }

  /// Deletes the selected object.
  bool deleteSelected() {
    if (_selectedObjectIds.isEmpty) return false;
    _remember();
    final ids = Set<String>.from(_selectedObjectIds);
    final before = _objects.length;
    _objects.removeWhere(
      (object) =>
          object.id != null && ids.contains(object.id) && !object.locked,
    );
    final removed = before != _objects.length;
    if (!removed) {
      _undoStack.removeLast();
      return false;
    }
    _selectedObjectIds.removeWhere((id) => objectById(id) == null);
    render();
    _emitSelect();
    _emitChange();
    return true;
  }

  /// Copies the selected object into the controller clipboard.
  bool copySelected() {
    final selected = selectedObjects;
    if (selected.isEmpty) return false;
    _clipboard = List.unmodifiable(selected);
    return true;
  }

  /// Pastes copied objects and selects the pasted objects.
  List<CanvasObject> pasteCopied({double dx = 12, double dy = 12}) {
    final copied = _clipboard;
    if (copied.isEmpty) return const [];
    _copyCount += 1;
    _remember();
    final pasted = <CanvasObject>[];
    for (final object in copied) {
      final next = _copyObject(
        object,
        dx: dx * _copyCount,
        dy: dy * _copyCount,
        id: _nextCopyId(object.id),
      );
      _objects.add(next);
      pasted.add(next);
    }
    _selectedObjectIds
      ..clear()
      ..addAll([
        for (final object in pasted)
          if (object.id != null) object.id!,
      ]);
    render();
    _emitSelect();
    _emitChange();
    return pasted;
  }

  /// Handles a keyboard command for the selected canvas object.
  bool handleKeyboardCommand(
    String key, {
    bool control = false,
    bool meta = false,
    bool shift = false,
  }) {
    final shortcut = control || meta;
    final normalized = key.toLowerCase();
    if (shortcut && normalized == 'c') return copySelected();
    if (shortcut && normalized == 'v') return pasteCopied().isNotEmpty;
    if (key == 'Delete' || key == 'Backspace') return deleteSelected();
    if (key == 'ArrowLeft') return nudgeSelected(dx: -1, largeStep: shift);
    if (key == 'ArrowRight') return nudgeSelected(dx: 1, largeStep: shift);
    if (key == 'ArrowUp') return nudgeSelected(dy: -1, largeStep: shift);
    if (key == 'ArrowDown') return nudgeSelected(dy: 1, largeStep: shift);
    return false;
  }

  /// Redraws the retained scene.
  void render() {}

  /// Draws a rectangle immediately.
  void drawRect(CanvasRect rect) {}

  /// Draws a line immediately.
  void drawLine(CanvasLine line) {}

  /// Draws a circle immediately.
  void drawCircle(CanvasCircle circle) {}

  /// Draws text immediately.
  void drawText(CanvasTextObject text) {}

  /// Draws an image immediately.
  void drawImage(CanvasImageObject image) {}

  /// Exports the canvas to a data URL.
  String toDataUrl({String type = 'image/png', double? quality}) => '';

  /// Exports retained objects as JSON-friendly scene data.
  Map<String, Object?> toJson() => {
    'objects': _objects.map((object) => object.toJson()).toList(),
    if (selectedObjectId != null) 'selectedObjectId': selectedObjectId,
    if (_selectedObjectIds.isNotEmpty)
      'selectedObjectIds': List<String>.from(_selectedObjectIds),
  };

  /// Exports selected retained objects as JSON-friendly scene data.
  Map<String, Object?> selectedToJson() => {
    'objects': selectedObjects.map((object) => object.toJson()).toList(),
    if (_selectedObjectIds.isNotEmpty)
      'selectedObjectIds': List<String>.from(_selectedObjectIds),
  };

  /// Creates a duplicate JSON snapshot of the current scene.
  Map<String, Object?> duplicateSceneJson() => _cloneJson(toJson());

  /// Loads retained objects from JSON-friendly scene data.
  void loadJson(Map<String, Object?> json) {
    _remember();
    _loadJson(json);
    _redoStack.clear();
    render();
  }

  /// Loads scene JSON from a saved backend payload.
  ///
  /// Accepts either the scene map directly or a wrapper with `scene`, `canvas`,
  /// or `data` keys.
  void importBackendJson(Map<String, Object?> json) {
    final scene = _sceneFromBackendJson(json);
    loadJson(scene);
  }

  /// Starts batching subsequent changes into one undo entry.
  void beginHistoryBatch() {
    _historyBatchDepth += 1;
  }

  /// Finishes a history batch.
  void endHistoryBatch() {
    if (_historyBatchDepth == 0) return;
    _historyBatchDepth -= 1;
    if (_historyBatchDepth > 0) return;
    final snapshot = _historyBatchSnapshot;
    _historyBatchSnapshot = null;
    if (snapshot == null) return;
    _pushUndo(snapshot);
    _redoStack.clear();
  }

  /// Cancels an active history batch without adding an undo entry.
  void cancelHistoryBatch() {
    _historyBatchDepth = 0;
    _historyBatchSnapshot = null;
  }

  /// Clears undo and redo history.
  void clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
    _historyBatchSnapshot = null;
    _historyBatchDepth = 0;
  }

  /// Restores the previous scene state.
  bool undo() {
    if (_undoStack.isEmpty) return false;
    _pushRedo(toJson());
    _loadJson(_undoStack.removeLast());
    render();
    onUndo?.call(this);
    return true;
  }

  /// Restores the next scene state after [undo].
  bool redo() {
    if (_redoStack.isEmpty) return false;
    _pushUndo(toJson());
    _loadJson(_redoStack.removeLast());
    render();
    onRedo?.call(this);
    return true;
  }

  void _loadJson(Map<String, Object?> json) {
    _objects
      ..clear()
      ..addAll(
        (json['objects'] as Iterable? ?? const []).whereType<Map>().map(
          (item) => canvasObjectFromJson(Map<String, Object?>.from(item)),
        ),
      );
    final selectedIds = (json['selectedObjectIds'] as Iterable? ?? const [])
        .map((id) => id.toString())
        .where((id) => objectById(id) != null);
    _selectedObjectIds
      ..clear()
      ..addAll(selectedIds);
    if (_selectedObjectIds.isEmpty) {
      final selected = json['selectedObjectId']?.toString();
      if (selected != null && objectById(selected) != null) {
        _selectedObjectIds.add(selected);
      }
    }
  }

  void _remember() {
    if (_historyBatchDepth > 0) {
      _historyBatchSnapshot ??= toJson();
      return;
    }
    _pushUndo(toJson());
    _redoStack.clear();
  }

  void _pushUndo(Map<String, Object?> snapshot) {
    _undoStack.add(snapshot);
    _trimHistory(_undoStack);
  }

  void _pushRedo(Map<String, Object?> snapshot) {
    _redoStack.add(snapshot);
    _trimHistory(_redoStack);
  }

  void _trimHistory(List<Map<String, Object?>> stack) {
    if (maxHistoryEntries <= 0) {
      stack.clear();
      return;
    }
    while (stack.length > maxHistoryEntries) {
      stack.removeAt(0);
    }
  }

  /// Detaches from the browser canvas.
  void detach() {}

  String _nextCopyId(String? sourceId) {
    final base = sourceId == null || sourceId.isEmpty ? 'object' : sourceId;
    var candidate = '${base}_copy_$_copyCount';
    while (objectById(candidate) != null) {
      _copyCount += 1;
      candidate = '${base}_copy_$_copyCount';
    }
    return candidate;
  }

  void _emitSelect() => onSelect?.call(selectedObjects);

  void _emitChange() => onChange?.call(this);

  CanvasObject _snapObjectIfNeeded(CanvasObject object, String id) {
    _snapGuides.clear();
    if (!snapToGrid && !snapToObjects) return object;
    final original = objectById(id);
    if (original == null) return object;
    final index = _objects.indexWhere((item) => item.id == id);
    if (index < 0) return object;
    _objects[index] = object;
    var dx = 0.0;
    var dy = 0.0;
    if (snapToGrid && gridSize > 0) {
      final bounds = _boundsFor(object);
      dx += _roundTo(bounds.x, gridSize) - bounds.x;
      dy += _roundTo(bounds.y, gridSize) - bounds.y;
      if (dx != 0) {
        _snapGuides.add(
          CanvasGuide(
            orientation: CanvasGuideOrientation.vertical,
            position: bounds.x + dx,
          ),
        );
      }
      if (dy != 0) {
        _snapGuides.add(
          CanvasGuide(
            orientation: CanvasGuideOrientation.horizontal,
            position: bounds.y + dy,
          ),
        );
      }
    }
    if (snapToObjects) {
      final delta = _objectSnapDelta(snapThreshold, selectedIds: [id]);
      if (delta != null) {
        dx += delta.$1;
        dy += delta.$2;
      }
    }
    _objects[index] = original;
    return dx == 0 && dy == 0 ? object : _moveObject(object, dx, dy);
  }

  void _snapSelectionIfNeeded() {
    _snapGuides.clear();
    if (!snapToGrid && !snapToObjects) return;
    var dx = 0.0;
    var dy = 0.0;
    final bounds = selectedBounds;
    if (snapToGrid && gridSize > 0 && bounds != null) {
      dx += _roundTo(bounds.x, gridSize) - bounds.x;
      dy += _roundTo(bounds.y, gridSize) - bounds.y;
      if (dx != 0) {
        _snapGuides.add(
          CanvasGuide(
            orientation: CanvasGuideOrientation.vertical,
            position: bounds.x + dx,
          ),
        );
      }
      if (dy != 0) {
        _snapGuides.add(
          CanvasGuide(
            orientation: CanvasGuideOrientation.horizontal,
            position: bounds.y + dy,
          ),
        );
      }
    }
    if (snapToObjects) {
      final delta = _objectSnapDelta(snapThreshold);
      if (delta != null) {
        dx += delta.$1;
        dy += delta.$2;
      }
    }
    if (dx == 0 && dy == 0) return;
    for (final id in _selectedObjectIds) {
      final index = _objects.indexWhere((object) => object.id == id);
      if (index < 0 || _objects[index].locked) continue;
      final original = _objects[index];
      _objects[index] = _constrainObject(
        original,
        _moveObject(original, dx, dy),
        moving: true,
      );
    }
  }

  (double, double)? _objectSnapDelta(
    double threshold, {
    Iterable<String>? selectedIds,
  }) {
    final ids = Set<String>.from(selectedIds ?? _selectedObjectIds);
    if (ids.isEmpty || threshold < 0) return null;
    final selected = [
      for (final id in ids)
        if (objectById(id) case final object?) object,
    ];
    if (selected.isEmpty) return null;
    final movingBounds = _unionBounds(selected.map(_boundsFor));
    final movingX = [
      movingBounds.left,
      movingBounds.centerX,
      movingBounds.right,
    ];
    final movingY = [
      movingBounds.top,
      movingBounds.centerY,
      movingBounds.bottom,
    ];
    double? bestDx;
    double? bestDy;
    double? guideX;
    double? guideY;
    var bestXDistance = threshold;
    var bestYDistance = threshold;

    for (final object in _objects) {
      if (object.id != null && ids.contains(object.id)) continue;
      if (object.hidden) continue;
      final bounds = _boundsFor(object);
      final targetX = [bounds.left, bounds.centerX, bounds.right];
      final targetY = [bounds.top, bounds.centerY, bounds.bottom];
      for (final source in movingX) {
        for (final target in targetX) {
          final distance = (target - source).abs();
          if (distance <= bestXDistance) {
            bestXDistance = distance;
            bestDx = target - source;
            guideX = target;
          }
        }
      }
      for (final source in movingY) {
        for (final target in targetY) {
          final distance = (target - source).abs();
          if (distance <= bestYDistance) {
            bestYDistance = distance;
            bestDy = target - source;
            guideY = target;
          }
        }
      }
    }

    if (bestDx == null && bestDy == null) return null;
    if (guideX != null) {
      _snapGuides.add(
        CanvasGuide(
          orientation: CanvasGuideOrientation.vertical,
          position: guideX,
        ),
      );
    }
    if (guideY != null) {
      _snapGuides.add(
        CanvasGuide(
          orientation: CanvasGuideOrientation.horizontal,
          position: guideY,
        ),
      );
    }
    return (bestDx ?? 0, bestDy ?? 0);
  }

  CanvasObject _constrainObject(
    CanvasObject original,
    CanvasObject next, {
    bool moving = false,
  }) {
    var constrained = next;
    if (moving) {
      constrained = _applyMovementLocks(original, constrained, constraints);
    }
    constrained = _applySizeConstraints(original, constrained, constraints);
    if (constraints.preventOutsideCanvas) {
      constrained = _keepInsideCanvas(constrained);
    }
    return constrained;
  }

  CanvasObject _keepInsideCanvas(CanvasObject object) {
    final width = _canvasWidth;
    final height = _canvasHeight;
    if (width == null || height == null) return object;
    final bounds = _boundsFor(object);
    var dx = 0.0;
    var dy = 0.0;
    if (bounds.left < 0) dx = -bounds.left;
    if (bounds.right > width) dx = width - bounds.right;
    if (bounds.top < 0) dy = -bounds.top;
    if (bounds.bottom > height) dy = height - bounds.bottom;
    return dx == 0 && dy == 0 ? object : _moveObject(object, dx, dy);
  }

  bool _updateSelectedObjects(
    CanvasObject Function(CanvasObject object) transform, {
    bool skipLocked = false,
  }) {
    if (_selectedObjectIds.isEmpty) return false;
    _remember();
    final changed = <CanvasObject>[];
    for (final id in _selectedObjectIds) {
      final index = _objects.indexWhere((object) => object.id == id);
      if (index < 0) continue;
      if (skipLocked && _objects[index].locked) continue;
      final next = transform(_objects[index]);
      _objects[index] = next;
      changed.add(next);
    }
    if (changed.isEmpty) return false;
    render();
    _emitChange();
    return true;
  }
}

CanvasBounds _boundsFor(CanvasObject object) {
  return switch (object) {
    CanvasRect rect => CanvasBounds(
      x: rect.x,
      y: rect.y,
      width: rect.width,
      height: rect.height,
    ),
    CanvasCircle circle => CanvasBounds(
      x: circle.x - circle.radius,
      y: circle.y - circle.radius,
      width: circle.radius * 2,
      height: circle.radius * 2,
    ),
    CanvasLine line => CanvasBounds(
      x: _min(line.x1, line.x2),
      y: _min(line.y1, line.y2),
      width: (line.x2 - line.x1).abs(),
      height: (line.y2 - line.y1).abs(),
    ),
    CanvasTextObject text => CanvasBounds(
      x: text.x,
      y: text.y - 20,
      width: _max(1, text.text.length * 10),
      height: 26,
    ),
    CanvasImageObject image => CanvasBounds(
      x: image.x,
      y: image.y,
      width: image.width,
      height: image.height,
    ),
    _ => const CanvasBounds(x: 0, y: 0, width: 0, height: 0),
  };
}

CanvasBounds _unionBounds(Iterable<CanvasBounds> bounds) {
  final iterator = bounds.iterator;
  if (!iterator.moveNext()) {
    return const CanvasBounds(x: 0, y: 0, width: 0, height: 0);
  }
  var left = iterator.current.left;
  var top = iterator.current.top;
  var right = iterator.current.right;
  var bottom = iterator.current.bottom;
  while (iterator.moveNext()) {
    left = _min(left, iterator.current.left);
    top = _min(top, iterator.current.top);
    right = _max(right, iterator.current.right);
    bottom = _max(bottom, iterator.current.bottom);
  }
  return CanvasBounds(
    x: left,
    y: top,
    width: _max(1, right - left),
    height: _max(1, bottom - top),
  );
}

CanvasBounds _boundsFromHandle(
  CanvasBounds bounds,
  CanvasSelectionHandle handle,
  double dx,
  double dy,
) {
  if (handle == CanvasSelectionHandle.rotate) return bounds;
  return switch (handle) {
    CanvasSelectionHandle.resizeNorthWest => CanvasBounds(
      x: bounds.x + dx,
      y: bounds.y + dy,
      width: _max(1, bounds.width - dx),
      height: _max(1, bounds.height - dy),
    ),
    CanvasSelectionHandle.resizeNorthEast => CanvasBounds(
      x: bounds.x,
      y: bounds.y + dy,
      width: _max(1, bounds.width + dx),
      height: _max(1, bounds.height - dy),
    ),
    CanvasSelectionHandle.resizeSouthWest => CanvasBounds(
      x: bounds.x + dx,
      y: bounds.y,
      width: _max(1, bounds.width - dx),
      height: _max(1, bounds.height + dy),
    ),
    _ => CanvasBounds(
      x: bounds.x,
      y: bounds.y,
      width: _max(1, bounds.width + dx),
      height: _max(1, bounds.height + dy),
    ),
  };
}

CanvasObject _scaleObjectInBounds(
  CanvasObject object,
  CanvasBounds oldBounds,
  CanvasBounds newBounds,
  double scaleX,
  double scaleY, {
  CanvasObjectConstraints constraints = const CanvasObjectConstraints(),
}) {
  double scaleXValue(double value) =>
      newBounds.x + ((value - oldBounds.x) * scaleX);
  double scaleYValue(double value) =>
      newBounds.y + ((value - oldBounds.y) * scaleY);

  return switch (object) {
    CanvasRect rect => rect.copyWith(
      x: scaleXValue(rect.x),
      y: scaleYValue(rect.y),
      width: _clampSize(
        rect.width * scaleX,
        constraints.minWidth,
        constraints.maxWidth,
      ),
      height: _clampSize(
        rect.height * scaleY,
        constraints.minHeight,
        constraints.maxHeight,
      ),
    ),
    CanvasImageObject image => image.copyWith(
      x: scaleXValue(image.x),
      y: scaleYValue(image.y),
      width: _clampSize(
        image.width * scaleX,
        constraints.minWidth,
        constraints.maxWidth,
      ),
      height: _clampSize(
        image.height * scaleY,
        constraints.minHeight,
        constraints.maxHeight,
      ),
    ),
    CanvasCircle circle => circle.copyWith(
      x: scaleXValue(circle.x),
      y: scaleYValue(circle.y),
      radius: _max(1, circle.radius * ((scaleX + scaleY) / 2)),
    ),
    CanvasLine line => line.copyWith(
      x1: scaleXValue(line.x1),
      y1: scaleYValue(line.y1),
      x2: scaleXValue(line.x2),
      y2: scaleYValue(line.y2),
    ),
    CanvasTextObject text => text.copyWith(
      x: scaleXValue(text.x),
      y: scaleYValue(text.y),
    ),
    _ => object,
  };
}

bool _sameIds(List<String> current, List<String> next) {
  if (current.length != next.length) return false;
  for (var i = 0; i < current.length; i++) {
    if (current[i] != next[i]) return false;
  }
  return true;
}

bool _containsPoint(CanvasObject object, double x, double y) {
  return switch (object) {
    CanvasRect rect =>
      x >= rect.x &&
          x <= rect.x + rect.width &&
          y >= rect.y &&
          y <= rect.y + rect.height,
    CanvasCircle circle =>
      ((x - circle.x) * (x - circle.x)) + ((y - circle.y) * (y - circle.y)) <=
          circle.radius * circle.radius,
    CanvasLine line =>
      _distanceToLine(x, y, line.x1, line.y1, line.x2, line.y2) <=
          (line.paint.lineWidth <= 0 ? 4 : line.paint.lineWidth + 4),
    CanvasTextObject text =>
      x >= text.x &&
          x <= text.x + (text.text.length * 10) &&
          y >= text.y - 20 &&
          y <= text.y + 6,
    CanvasImageObject image =>
      x >= image.x &&
          x <= image.x + image.width &&
          y >= image.y &&
          y <= image.y + image.height,
    _ => false,
  };
}

CanvasObject _moveObject(CanvasObject object, double dx, double dy) {
  return switch (object) {
    CanvasRect rect => rect.copyWith(x: rect.x + dx, y: rect.y + dy),
    CanvasCircle circle => circle.copyWith(x: circle.x + dx, y: circle.y + dy),
    CanvasLine line => line.copyWith(
      x1: line.x1 + dx,
      y1: line.y1 + dy,
      x2: line.x2 + dx,
      y2: line.y2 + dy,
    ),
    CanvasTextObject text => text.copyWith(x: text.x + dx, y: text.y + dy),
    CanvasImageObject image => image.copyWith(x: image.x + dx, y: image.y + dy),
    _ => object,
  };
}

CanvasObject _copyObjectWithPaint(CanvasObject object, CanvasPaint paint) {
  return switch (object) {
    CanvasRect rect => rect.copyWith(paint: paint),
    CanvasCircle circle => circle.copyWith(paint: paint),
    CanvasLine line => line.copyWith(paint: paint),
    CanvasTextObject text => text.copyWith(paint: paint),
    CanvasImageObject image => image.copyWith(paint: paint),
    _ => object,
  };
}

CanvasObject _copyObjectWithMeta(
  CanvasObject object, {
  String? id,
  String? name,
  bool? locked,
  bool? hidden,
}) {
  return switch (object) {
    CanvasRect rect => rect.copyWith(
      id: id,
      name: name,
      locked: locked,
      hidden: hidden,
    ),
    CanvasCircle circle => circle.copyWith(
      id: id,
      name: name,
      locked: locked,
      hidden: hidden,
    ),
    CanvasLine line => line.copyWith(
      id: id,
      name: name,
      locked: locked,
      hidden: hidden,
    ),
    CanvasTextObject text => text.copyWith(
      id: id,
      name: name,
      locked: locked,
      hidden: hidden,
    ),
    CanvasImageObject image => image.copyWith(
      id: id,
      name: name,
      locked: locked,
      hidden: hidden,
    ),
    _ => object,
  };
}

CanvasObject _resizeObject(
  CanvasObject object,
  double dw,
  double dh, {
  CanvasObjectConstraints constraints = const CanvasObjectConstraints(),
}) {
  return switch (object) {
    CanvasRect rect => _resizeRect(
      rect,
      rect.width + dw,
      rect.height + dh,
      constraints: constraints,
    ),
    CanvasCircle circle => circle.copyWith(
      radius: _clampSize(
        circle.radius + _max(dw, dh),
        constraints.minWidth / 2,
        constraints.maxWidth == null ? null : constraints.maxWidth! / 2,
      ),
    ),
    CanvasLine line => line.copyWith(x2: line.x2 + dw, y2: line.y2 + dh),
    CanvasTextObject text => text,
    CanvasImageObject image => _resizeImage(
      image,
      image.width + dw,
      image.height + dh,
      constraints: constraints,
    ),
    _ => object,
  };
}

CanvasObject _resizeObjectFromHandle(
  CanvasObject object,
  CanvasSelectionHandle handle,
  double dx,
  double dy, {
  CanvasObjectConstraints constraints = const CanvasObjectConstraints(),
}) {
  if (handle == CanvasSelectionHandle.rotate) return object;
  return switch (object) {
    CanvasRect rect => switch (handle) {
      CanvasSelectionHandle.resizeNorthWest => _applySizeConstraints(
        rect,
        rect.copyWith(
          x: rect.x + dx,
          y: rect.y + dy,
          width: _max(1, rect.width - dx),
          height: _max(1, rect.height - dy),
        ),
        constraints,
      ),
      CanvasSelectionHandle.resizeNorthEast => _applySizeConstraints(
        rect,
        rect.copyWith(
          y: rect.y + dy,
          width: _max(1, rect.width + dx),
          height: _max(1, rect.height - dy),
        ),
        constraints,
      ),
      CanvasSelectionHandle.resizeSouthWest => _applySizeConstraints(
        rect,
        rect.copyWith(
          x: rect.x + dx,
          width: _max(1, rect.width - dx),
          height: _max(1, rect.height + dy),
        ),
        constraints,
      ),
      _ => _applySizeConstraints(
        rect,
        rect.copyWith(
          width: _max(1, rect.width + dx),
          height: _max(1, rect.height + dy),
        ),
        constraints,
      ),
    },
    CanvasImageObject image => switch (handle) {
      CanvasSelectionHandle.resizeNorthWest => _applySizeConstraints(
        image,
        image.copyWith(
          x: image.x + dx,
          y: image.y + dy,
          width: _max(1, image.width - dx),
          height: _max(1, image.height - dy),
        ),
        constraints,
      ),
      CanvasSelectionHandle.resizeNorthEast => _applySizeConstraints(
        image,
        image.copyWith(
          y: image.y + dy,
          width: _max(1, image.width + dx),
          height: _max(1, image.height - dy),
        ),
        constraints,
      ),
      CanvasSelectionHandle.resizeSouthWest => _applySizeConstraints(
        image,
        image.copyWith(
          x: image.x + dx,
          width: _max(1, image.width - dx),
          height: _max(1, image.height + dy),
        ),
        constraints,
      ),
      _ => _applySizeConstraints(
        image,
        image.copyWith(
          width: _max(1, image.width + dx),
          height: _max(1, image.height + dy),
        ),
        constraints,
      ),
    },
    CanvasCircle circle => circle.copyWith(
      radius: _clampSize(
        circle.radius + _max(dx.abs(), dy.abs()),
        constraints.minWidth / 2,
        constraints.maxWidth == null ? null : constraints.maxWidth! / 2,
      ),
    ),
    CanvasLine line => switch (handle) {
      CanvasSelectionHandle.resizeNorthWest ||
      CanvasSelectionHandle.resizeSouthWest => line.copyWith(
        x1: line.x1 + dx,
        y1: line.y1 + dy,
      ),
      _ => line.copyWith(x2: line.x2 + dx, y2: line.y2 + dy),
    },
    _ => object,
  };
}

CanvasObject _applyMovementLocks(
  CanvasObject original,
  CanvasObject next,
  CanvasObjectConstraints constraints,
) {
  if (!constraints.lockMovementX && !constraints.lockMovementY) return next;
  final originalBounds = _boundsFor(original);
  final nextBounds = _boundsFor(next);
  final dx = constraints.lockMovementX
      ? originalBounds.left - nextBounds.left
      : 0.0;
  final dy = constraints.lockMovementY
      ? originalBounds.top - nextBounds.top
      : 0.0;
  return dx == 0 && dy == 0 ? next : _moveObject(next, dx, dy);
}

CanvasObject _applySizeConstraints(
  CanvasObject original,
  CanvasObject next,
  CanvasObjectConstraints constraints,
) {
  return switch (next) {
    CanvasRect rect => _resizeRect(
      rect,
      rect.width,
      rect.height,
      originalWidth: original is CanvasRect ? original.width : rect.width,
      originalHeight: original is CanvasRect ? original.height : rect.height,
      constraints: constraints,
    ),
    CanvasImageObject image => _resizeImage(
      image,
      image.width,
      image.height,
      originalWidth: original is CanvasImageObject
          ? original.width
          : image.width,
      originalHeight: original is CanvasImageObject
          ? original.height
          : image.height,
      constraints: constraints,
    ),
    CanvasCircle circle => circle.copyWith(
      radius: _clampSize(
        circle.radius,
        constraints.minWidth / 2,
        constraints.maxWidth == null ? null : constraints.maxWidth! / 2,
      ),
    ),
    _ => next,
  };
}

CanvasRect _resizeRect(
  CanvasRect rect,
  double width,
  double height, {
  double? originalWidth,
  double? originalHeight,
  CanvasObjectConstraints constraints = const CanvasObjectConstraints(),
}) {
  final size = _constrainedSize(
    width,
    height,
    originalWidth ?? rect.width,
    originalHeight ?? rect.height,
    constraints,
  );
  return rect.copyWith(width: size.$1, height: size.$2);
}

CanvasImageObject _resizeImage(
  CanvasImageObject image,
  double width,
  double height, {
  double? originalWidth,
  double? originalHeight,
  CanvasObjectConstraints constraints = const CanvasObjectConstraints(),
}) {
  final size = _constrainedSize(
    width,
    height,
    originalWidth ?? image.width,
    originalHeight ?? image.height,
    constraints,
  );
  return image.copyWith(width: size.$1, height: size.$2);
}

(double, double) _constrainedSize(
  double width,
  double height,
  double originalWidth,
  double originalHeight,
  CanvasObjectConstraints constraints,
) {
  var nextWidth = _clampSize(width, constraints.minWidth, constraints.maxWidth);
  var nextHeight = _clampSize(
    height,
    constraints.minHeight,
    constraints.maxHeight,
  );
  if (constraints.keepAspectRatio && originalWidth > 0 && originalHeight > 0) {
    final ratio = originalWidth / originalHeight;
    if ((nextWidth - originalWidth).abs() >=
        (nextHeight - originalHeight).abs()) {
      nextHeight = nextWidth / ratio;
    } else {
      nextWidth = nextHeight * ratio;
    }
    nextWidth = _clampSize(
      nextWidth,
      constraints.minWidth,
      constraints.maxWidth,
    );
    nextHeight = _clampSize(
      nextHeight,
      constraints.minHeight,
      constraints.maxHeight,
    );
  }
  return (nextWidth, nextHeight);
}

CanvasObject _rotateObject(CanvasObject object, double degrees) {
  return switch (object) {
    CanvasRect rect => rect.copyWith(rotation: degrees),
    CanvasCircle circle => circle.copyWith(rotation: degrees),
    CanvasLine line => line.copyWith(rotation: degrees),
    CanvasTextObject text => text.copyWith(rotation: degrees),
    CanvasImageObject image => image.copyWith(rotation: degrees),
    _ => object,
  };
}

double _max(double a, double b) => a > b ? a : b;

double _min(double a, double b) => a < b ? a : b;

double _clampSize(double value, double min, double? max) {
  var result = value < min ? min : value;
  if (max != null && result > max) result = max;
  return result;
}

double _roundTo(double value, double step) => (value / step).round() * step;

Map<String, Object?> _cloneJson(Map<String, Object?> json) {
  return {
    for (final entry in json.entries) entry.key: _cloneJsonValue(entry.value),
  };
}

Object? _cloneJsonValue(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key.toString(): _cloneJsonValue(entry.value),
    };
  }
  if (value is Iterable) {
    return value.map(_cloneJsonValue).toList();
  }
  return value;
}

Map<String, Object?> _sceneFromBackendJson(Map<String, Object?> json) {
  for (final key in const ['scene', 'canvas', 'data']) {
    final value = json[key];
    if (value is Map) return Map<String, Object?>.from(value);
  }
  return json;
}

String _fontString(String current, String? family, double? size) {
  final currentSize = RegExp(r'(\d+(?:\.\d+)?)px').firstMatch(current);
  final resolvedSize =
      size ?? double.tryParse(currentSize?.group(1) ?? '') ?? 16;
  final parts = current.split(' ');
  final resolvedFamily =
      family ?? (parts.length > 1 ? parts.sublist(1).join(' ') : 'sans-serif');
  final sizeText = resolvedSize == resolvedSize.roundToDouble()
      ? resolvedSize.toInt().toString()
      : resolvedSize.toString();
  return '${sizeText}px $resolvedFamily';
}

CanvasObject _copyObject(
  CanvasObject object, {
  required String id,
  required double dx,
  required double dy,
}) {
  return switch (object) {
    CanvasRect rect => rect.copyWith(id: id, x: rect.x + dx, y: rect.y + dy),
    CanvasCircle circle => circle.copyWith(
      id: id,
      x: circle.x + dx,
      y: circle.y + dy,
    ),
    CanvasLine line => line.copyWith(
      id: id,
      x1: line.x1 + dx,
      y1: line.y1 + dy,
      x2: line.x2 + dx,
      y2: line.y2 + dy,
    ),
    CanvasTextObject text => text.copyWith(
      id: id,
      x: text.x + dx,
      y: text.y + dy,
    ),
    CanvasImageObject image => image.copyWith(
      id: id,
      x: image.x + dx,
      y: image.y + dy,
    ),
    _ => object,
  };
}

double _distanceToLine(
  double px,
  double py,
  double x1,
  double y1,
  double x2,
  double y2,
) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  if (dx == 0 && dy == 0) {
    final x = px - x1;
    final y = py - y1;
    return (x * x + y * y);
  }
  final t = (((px - x1) * dx) + ((py - y1) * dy)) / ((dx * dx) + (dy * dy));
  final clamped = t.clamp(0, 1).toDouble();
  final lx = x1 + clamped * dx;
  final ly = y1 + clamped * dy;
  final x = px - lx;
  final y = py - ly;
  return _sqrt((x * x) + (y * y));
}

double _sqrt(double value) {
  if (value <= 0) return 0;
  var estimate = value;
  for (var i = 0; i < 8; i++) {
    estimate = 0.5 * (estimate + value / estimate);
  }
  return estimate;
}

double _toDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

/// Native HTML canvas element with a Flint drawing controller.
class Canvas extends FlintElement {
  /// Creates a canvas element.
  Canvas({
    this.controller,
    int width = 300,
    int height = 150,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'canvas',
         props: mergeComponentProps(
           {
             ...props,
             if (controller != null) '_flintCanvasController': controller,
             'width': width,
             'height': height,
             'tabIndex': props['tabIndex'] ?? 0,
           },
           className: className,
           defaultStyle: const {
             'display': 'block',
             'max-width': '100%',
             'touch-action': 'none',
           },
           dartStyle: dartStyle,
           style: style,
         ),
       );

  /// Optional drawing controller.
  final CanvasController? controller;
}
