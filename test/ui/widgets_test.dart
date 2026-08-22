import 'package:flint_dart/flint_ui_core.dart';
import 'package:test/test.dart';

void main() {
  group('Button', () {
    test('renders variant, size, tone, and loading state', () {
      final button = Button(
        child: Text('Save'),
        variant: ButtonVariant.solid,
        tone: Tone.success,
        size: ComponentSize.sm,
        loading: true,
        onPressed: (_) {},
      );

      expect(button.props['disabled'], true);
      expect(button.props['aria-busy'], 'true');
      expect(button.props.containsKey('onClick'), isFalse);
      expect(
        button.props['style'],
        containsPair('background', 'var(--color-successSolid, #079455)'),
      );
      expect(button.props['style'], containsPair('min-height', '34px'));
      expect(button.children.first, isA<Spinner>());
      expect(button.children.last, isA<Text>());
    });

    test('renders scoped variant interaction states', () {
      final button = Button(
        child: 'Save',
        variant: ButtonVariant.outline,
        tone: Tone.primary,
      );

      expect(button.props['className'], contains('flint-s-'));
      expect(
        button.props['style'],
        containsPair('color', 'var(--color-primaryText, #1849a9)'),
      );
      expect(button.props['_flintStyleCss'], contains(':hover'));
      expect(
        button.props['_flintStyleCss'],
        contains('background: var(--color-primarySoft, #eff4ff) !important'),
      );
      expect(button.props['_flintStyleCss'], contains(':focus-visible'));
      expect(button.props['_flintStyleCss'], contains(':active'));
    });

    test('keeps explicit styles as the final override', () {
      final button = Button(
        child: 'Delete',
        tone: Tone.danger,
        style: {'background': '#000', 'padding': '2px'},
      );

      expect(button.props['style'], containsPair('background', '#000'));
      expect(button.props['style'], containsPair('padding', '2px'));
    });
  });

  group('IconButton', () {
    test('renders accessible icon-only button', () {
      final button = IconButton(
        icon: Text('X'),
        label: 'Close',
        tooltip: 'Close panel',
      );

      expect(button.props['aria-label'], 'Close');
      expect(button.props['title'], 'Close panel');
      expect(button.children.single, isA<Text>());
    });
  });

  group('Icon', () {
    test('renders decorative inline SVG icons from the built-in catalog', () {
      final icon = Icon(Icons.home, size: 24, color: '#155eef');

      expect(icon.tag, 'svg');
      expect(icon.props['aria-hidden'], 'true');
      expect(icon.props['viewBox'], '0 0 24 24');
      expect(icon.props['stroke'], 'currentColor');
      expect(icon.props['style'], containsPair('width', '24px'));
      expect(icon.props['style'], containsPair('height', '24px'));
      expect(icon.props['style'], containsPair('color', '#155eef'));
      expect(icon.children, isNotEmpty);
      expect((icon.children.first as FlintElement).tag, 'path');
    });

    test('renders accessible labelled icons', () {
      final icon = Icon(Icons.search, title: 'Search');

      expect(icon.props['role'], 'img');
      expect(icon.props['aria-label'], 'Search');
      expect(icon.props.containsKey('aria-hidden'), isFalse);
      expect((icon.children.first as FlintElement).tag, 'title');
      expect(
        (icon.children.first as FlintElement).children.single,
        isA<FlintText>(),
      );
    });

    test('accepts DartStyle with explicit style as final override', () {
      final icon = Icon(
        Icons.user,
        size: 24,
        dartStyle: const DartStyle(color: '#155eef', margin: EdgeInsets.all(4)),
        style: const {'color': '#111827'},
      );

      expect(icon.props['style'], containsPair('width', '24px'));
      expect(icon.props['style'], containsPair('height', '24px'));
      expect(icon.props['style'], containsPair('margin', '4px'));
      expect(icon.props['style'], containsPair('color', '#111827'));
    });

    test('supports scoped DartStyle states', () {
      final icon = Icon(
        Icons.settings,
        dartStyle: const DartStyle(hover: DartStyle(color: '#0f766e')),
      );

      expect(icon.props['className'], contains('flint-s-'));
      expect(icon.props['_flintStyleCss'], contains(':hover'));
      expect(
        icon.props['_flintStyleCss'],
        contains('color: #0f766e !important'),
      );
    });

    test('ships a broad app icon catalog', () {
      expect(Icons.all.length, greaterThanOrEqualTo(80));
      expect(Icons.all.map((icon) => icon.name), contains('code'));
      expect(Icons.all.map((icon) => icon.name), contains('gitBranch'));
      expect(Icons.all.map((icon) => icon.name), contains('server'));
      expect(Icons.all.map((icon) => icon.name), contains('settings'));
      expect(Icons.all.map((icon) => icon.name), contains('route'));
      expect(Icons.all.map((icon) => icon.name), contains('shoppingCart'));
      expect(Icons.all.map((icon) => icon.name), contains('sparkles'));
    });

    test('does not put path commands inside polyline points', () {
      final invalidPolylines = <String>[];
      final numberList = RegExp(
        r'^\s*-?\d+(?:\.\d+)?(?:[,\s]+-?\d+(?:\.\d+)?)*\s*$',
      );

      for (final icon in Icons.all) {
        for (final shape in icon.shapes) {
          if (shape.tag != 'polyline' && shape.tag != 'polygon') continue;
          final points = shape.props['points']?.toString() ?? '';
          if (!numberList.hasMatch(points)) {
            invalidPolylines.add('${icon.name}: $points');
          }
        }
      }

      expect(invalidPolylines, isEmpty);
    });
  });

  group('ButtonGroup', () {
    test('renders inline action grouping', () {
      final group = ButtonGroup(
        children: [
          Button(child: 'Save'),
          Button(child: 'Cancel', variant: ButtonVariant.outline),
        ],
      );

      expect(group.tag, 'div');
      expect(group.props['style'], containsPair('display', 'inline-flex'));
      expect(group.children, hasLength(2));
    });
  });

  group('text and link primitives', () {
    test('Text helpers render semantic text elements with DartStyle', () {
      final title = Text.h1(
        'Dashboard',
        className: 'page-title',
        dartStyle: const DartStyle(fontSize: 28),
      );

      expect(title.tag, 'h1');
      expect(title.props['className'], 'page-title');
      expect(title.props['style'], containsPair('font-size', '28px'));
      expect((title.children.single as FlintText).value, 'Dashboard');
    });

    test('Link renders anchor props and children', () {
      final link = Link(
        href: '/dashboard',
        className: 'text-link',
        child: 'Open dashboard',
      );

      expect(link.tag, 'a');
      expect(link.props['href'], '/dashboard');
      expect(link.props['className'], 'text-link');
      expect((link.children.single as FlintText).value, 'Open dashboard');
    });

    test('Link supports action variants', () {
      final link = Link(
        href: '/contact',
        variant: ButtonVariant.solid,
        tone: Tone.primary,
        size: ComponentSize.lg,
        child: 'Contact',
      );

      expect(link.tag, 'a');
      expect(link.props['href'], '/contact');
      expect(link.props['className'], contains('flint-s-'));
      expect(
        link.props['style'],
        containsPair('background', 'var(--color-primarySolid, #155eef)'),
      );
      expect(link.props['style'], containsPair('min-height', '46px'));
      expect(link.props['_flintStyleCss'], contains(':hover'));
    });
  });

  group('media primitives', () {
    test('Image renders responsive image attributes and styles', () {
      final image = Image(
        src: '/assets/logo.png',
        alt: 'EuPanel logo',
        width: 96,
        height: 96,
        loading: ImageLoading.eager,
        dartStyle: const DartStyle(radius: 12),
      );

      expect(image.tag, 'img');
      expect(image.props['src'], '/assets/logo.png');
      expect(image.props['alt'], 'EuPanel logo');
      expect(image.props['width'], '96px');
      expect(image.props['height'], '96px');
      expect(image.props['loading'], 'eager');
      expect(image.props['decoding'], 'async');
      expect(image.props['style'], containsPair('max-width', '100%'));
      expect(image.props['style'], containsPair('border-radius', '12px'));
    });

    test('Figure renders image content and caption', () {
      final figure = Figure(
        image: Image(src: '/screens/dashboard.png', alt: 'Dashboard'),
        caption: 'Dashboard preview',
      );

      expect(figure.tag, 'figure');
      expect(figure.children.first, isA<Image>());
      expect(figure.children.last, isA<FlintElement>());
      expect((figure.children.last as FlintElement).tag, 'figcaption');
    });

    test('Video renders native media controls and playback attributes', () {
      final controller = MediaElementController();
      final video = Video(
        controller: controller,
        src: '/media/demo.mp4',
        poster: '/media/poster.jpg',
        width: 640,
        height: 360,
        autoplay: true,
        muted: true,
        loop: true,
        fallback: 'Video is not supported.',
      );

      expect(video.tag, 'video');
      expect(video.props['src'], '/media/demo.mp4');
      expect(video.props['poster'], '/media/poster.jpg');
      expect(video.props['width'], '640px');
      expect(video.props['height'], '360px');
      expect(video.props['controls'], isTrue);
      expect(video.props['autoplay'], isTrue);
      expect(video.props['muted'], isTrue);
      expect(video.props['loop'], isTrue);
      expect(video.props['playsinline'], isTrue);
      expect(video.props['preload'], 'metadata');
      expect(video.props['_flintMediaController'], controller);
      expect(video.children.single, isA<FlintText>());
    });

    test('Audio renders native media controls and playback attributes', () {
      final controller = MediaElementController();
      final audio = Audio(
        controller: controller,
        src: '/media/demo.mp3',
        preload: MediaPreload.none,
        controls: false,
        fallback: 'Audio is not supported.',
      );

      expect(audio.tag, 'audio');
      expect(audio.props['src'], '/media/demo.mp3');
      expect(audio.props.containsKey('controls'), isFalse);
      expect(audio.props['_flintMediaController'], controller);
      expect(audio.props['preload'], 'none');
      expect(audio.props['style'], containsPair('width', '100%'));
      expect(audio.children.single, isA<FlintText>());
    });

    test(
      'MediaPreview renders a stream target without touching browser APIs',
      () {
        final controller = MediaElementController();
        final preview = MediaPreview(
          id: 'camera-preview',
          controller: controller,
          result: const MediaStreamResult(granted: true),
          fallback: 'Waiting for camera.',
        ).build();

        expect(preview, isA<Video>());
        final video = preview as Video;
        expect(video.props['id'], 'camera-preview');
        expect(video.props['autoplay'], isTrue);
        expect(video.props['muted'], isTrue);
        expect(video.props['controls'], isTrue);
        expect(video.props['_flintMediaController'], controller);
        expect(video.children.single, isA<FlintText>());
      },
    );

    test('MediaElementController is server-safe before browser binding', () {
      final controller = MediaElementController();

      expect(controller.isAttached, isFalse);
      expect(controller.isPaused, isTrue);
      expect(controller.isPlaying, isFalse);
      expect(controller.currentTime, Duration.zero);
      expect(controller.duration, isNull);
      expect(controller.volume, 1);
      expect(controller.playbackRate, 1);

      controller.pause();
      controller.stop();
      controller.seekTo(const Duration(seconds: 3));
      controller.setVolume(0.5);
      controller.mute();
      controller.unmute();
      controller.toggleMuted();
      controller.setPlaybackRate(1.25);
      controller.detach();
    });

    test('Canvas renders with controller, dimensions, and styles', () {
      final controller = CanvasController();
      final canvas = Canvas(
        controller: controller,
        width: 640,
        height: 360,
        dartStyle: const DartStyle(radius: 8),
      );

      expect(canvas.tag, 'canvas');
      expect(canvas.props['width'], 640);
      expect(canvas.props['height'], 360);
      expect(canvas.props['_flintCanvasController'], controller);
      expect(canvas.props['style'], containsPair('max-width', '100%'));
      expect(canvas.props['style'], containsPair('border-radius', '8px'));
    });

    test('ThreeScene renders with controller, dimensions, and styles', () {
      final controller = ThreeSceneController(autoStart: false);
      final scene = ThreeScene(
        controller: controller,
        width: 800,
        height: 450,
        label: 'Product preview',
        dartStyle: const DartStyle(radius: 8),
      );

      expect(scene.tag, 'canvas');
      expect(scene.props['width'], 800);
      expect(scene.props['height'], 450);
      expect(scene.props['aria-label'], 'Product preview');
      expect(scene.props.containsKey('aria-hidden'), isFalse);
      expect(scene.props['_flintThreeSceneController'], controller);
      expect(scene.props['style'], containsPair('width', '100%'));
      expect(scene.props['style'], containsPair('border-radius', '8px'));
    });

    test('ThreeSceneController is server-safe before browser binding', () {
      final events = <String>[];
      final controller = ThreeSceneController(
        autoStart: false,
        onFrame: (_, timestamp) => events.add('frame:$timestamp'),
        onDispose: (_) => events.add('dispose'),
      );

      expect(controller.isSupported, isFalse);
      expect(controller.isAttached, isFalse);
      expect(controller.isThreeAvailable, isFalse);
      expect(controller.canvas, isNull);
      expect(controller.three, isNull);
      expect(controller.width, 0);
      expect(controller.height, 0);

      controller.attachTo(null);
      expect(controller.getThreeProperty('Scene'), isNull);
      expect(controller.create('Scene'), isNull);
      expect(controller.callMethod(null, 'render'), isNull);
      expect(controller.getProperty(null, 'rotation'), isNull);
      controller.setProperty(null, 'x', 1);
      controller.disposeObject(null);
      controller.start();
      controller.render(12);
      controller.resize(width: 100, height: 50);
      controller.stop();
      controller.detach();
      controller.dispose();

      expect(events, ['frame:12.0', 'dispose']);
    });

    test('CanvasController stores, finds, removes, and clears objects', () {
      final controller = CanvasController();
      const rect = CanvasRect(
        id: 'box',
        x: 10,
        y: 12,
        width: 100,
        height: 60,
        borderRadius: 10,
        paint: CanvasPaint(fill: '#fff', stroke: '#111827', lineWidth: 2),
      );
      const text = CanvasTextObject(
        id: 'label',
        text: 'Hello',
        x: 16,
        y: 32,
        paint: CanvasPaint(fill: '#111827', stroke: null),
      );

      controller.addRect(rect);
      controller.addText(text);

      expect(controller.objects, [rect, text]);
      expect(controller.objectById('box'), rect);
      expect(rect.borderRadius, 10);
      expect(controller.remove('box'), isTrue);
      expect(controller.remove('missing'), isFalse);
      expect(controller.objects, [text]);

      controller.drawRect(rect);
      controller.drawLine(const CanvasLine(x1: 0, y1: 0, x2: 10, y2: 10));
      controller.drawCircle(const CanvasCircle(x: 20, y: 20, radius: 8));
      controller.drawText(text);
      controller.drawImage(
        const CanvasImageObject(
          src: '/assets/logo.png',
          x: 0,
          y: 0,
          width: 16,
          height: 16,
        ),
      );
      expect(controller.toDataUrl(), '');

      controller.clear();
      expect(controller.objects, isEmpty);
    });

    test('CanvasPaint supports image patterns and border removal', () {
      const pattern = CanvasImagePattern(
        src: '/assets/pattern.png',
        repetition: CanvasPatternRepetition.repeatX,
        crossOrigin: 'anonymous',
      );
      const rect = CanvasRect(
        x: 0,
        y: 0,
        width: 120,
        height: 80,
        borderRadius: 16,
        paint: CanvasPaint(
          pattern: pattern,
          fill: '#f8fafc',
          stroke: null,
          lineWidth: 0,
        ),
      );

      expect(rect.paint.pattern, pattern);
      expect(rect.paint.stroke, isNull);
      expect(rect.paint.lineWidth, 0);
      expect(rect.paint.pattern?.repetition.value, 'repeat-x');
    });

    test(
      'CanvasController updates, orders, selects, moves, and serializes',
      () {
        final controller = CanvasController();
        const rect = CanvasRect(id: 'rect', x: 0, y: 0, width: 100, height: 80);
        const circle = CanvasCircle(
          id: 'circle',
          x: 40,
          y: 40,
          radius: 20,
          paint: CanvasPaint(fill: '#00ff00', stroke: null),
        );
        const text = CanvasTextObject(
          id: 'text',
          text: 'Hi',
          x: 12,
          y: 24,
          paint: CanvasPaint(fill: '#111827', stroke: null),
        );
        const image = CanvasImageObject(
          id: 'image',
          src: '/assets/logo.png',
          x: 70,
          y: 12,
          width: 24,
          height: 18,
          rotation: 5,
          crossOrigin: 'anonymous',
        );

        controller.addRect(rect);
        controller.addCircle(circle);
        controller.addText(text);
        controller.addImage(image);

        expect(controller.hitTest(72, 14), image);
        expect(controller.hitTest(40, 40), circle);
        expect(controller.selectAt(40, 40), circle);
        expect(controller.selectedObjectId, 'circle');

        expect(controller.moveSelectedBy(10, 5), isTrue);
        expect((controller.objectById('circle') as CanvasCircle).x, 50);
        expect((controller.objectById('circle') as CanvasCircle).y, 45);

        expect(controller.sendBackward('text'), isTrue);
        expect(controller.objects.map((object) => object.id), [
          'rect',
          'text',
          'circle',
          'image',
        ]);
        expect(controller.bringToFront('rect'), isTrue);
        expect(controller.objects.last.id, 'rect');

        expect(
          controller.update(
            'rect',
            rect.copyWith(
              width: 120,
              rotation: 15,
              paint: const CanvasPaint(fill: '#fff'),
            ),
          ),
          isTrue,
        );
        expect((controller.objectById('rect') as CanvasRect).width, 120);
        expect((controller.objectById('rect') as CanvasRect).rotation, 15);

        expect(controller.resizeBy('rect', 10, 20), isTrue);
        expect((controller.objectById('rect') as CanvasRect).width, 130);
        expect((controller.objectById('rect') as CanvasRect).height, 100);
        expect(controller.select('rect'), isTrue);
        expect(
          controller.resizeSelectedFromHandle(
            CanvasSelectionHandle.resizeNorthWest,
            10,
            10,
          ),
          isTrue,
        );
        expect((controller.objectById('rect') as CanvasRect).x, 10);
        expect(controller.setRotation('rect', 45), isTrue);
        expect((controller.objectById('rect') as CanvasRect).rotation, 45);

        expect(controller.select('circle'), isTrue);
        expect(controller.selectedBounds?.width, 40);
        expect(controller.resizeSelectedBy(5, 2), isTrue);
        expect((controller.objectById('circle') as CanvasCircle).radius, 25);
        expect(controller.rotateSelectedBy(30), isTrue);
        expect((controller.objectById('circle') as CanvasCircle).rotation, 30);

        final json = controller.toJson();
        final restored = CanvasController()..loadJson(json);
        expect(restored.objects, hasLength(4));
        expect(restored.objectById('circle'), isA<CanvasCircle>());
        expect(restored.objectById('image'), isA<CanvasImageObject>());
        expect(restored.selectedObjectId, 'circle');
        expect((restored.objectById('rect') as CanvasRect).rotation, 45);
        expect(
          (restored.objectById('image') as CanvasImageObject).crossOrigin,
          'anonymous',
        );

        final parsed = canvasObjectFromJson({
          'type': 'line',
          'id': 'line',
          'rotation': 12,
          'x1': 1,
          'y1': 2,
          'x2': 3,
          'y2': 4,
          'paint': {'stroke': '#333', 'lineWidth': 2},
        });
        expect(parsed, isA<CanvasLine>());
        expect(parsed.rotation, 12);
      },
    );

    test('CanvasController supports undo and redo history', () {
      final controller = CanvasController();
      const image = CanvasImageObject(
        id: 'image',
        src: '/photo.png',
        x: 0,
        y: 0,
        width: 20,
        height: 10,
      );

      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);

      controller.addImage(image);
      expect(controller.canUndo, isTrue);
      expect(controller.objectById('image'), image);

      expect(controller.resizeBy('image', 5, 3), isTrue);
      expect((controller.objectById('image') as CanvasImageObject).width, 25);
      expect(controller.rotateBy('image', 15), isTrue);
      expect(
        (controller.objectById('image') as CanvasImageObject).rotation,
        15,
      );

      expect(controller.undo(), isTrue);
      expect((controller.objectById('image') as CanvasImageObject).rotation, 0);
      expect(controller.undo(), isTrue);
      expect((controller.objectById('image') as CanvasImageObject).width, 20);
      expect(controller.undo(), isTrue);
      expect(controller.objects, isEmpty);
      expect(controller.canRedo, isTrue);

      expect(controller.redo(), isTrue);
      expect(controller.objectById('image'), isA<CanvasImageObject>());
      expect(controller.redo(), isTrue);
      expect((controller.objectById('image') as CanvasImageObject).width, 25);
    });

    test('CanvasController batches history and supports marquee selection', () {
      final events = <String>[];
      final controller = CanvasController(
        maxHistoryEntries: 2,
        onUndo: (_) => events.add('undo'),
        onRedo: (_) => events.add('redo'),
      );
      controller.addRect(
        const CanvasRect(id: 'a', x: 0, y: 0, width: 10, height: 10),
      );
      controller.addRect(
        const CanvasRect(id: 'b', x: 30, y: 0, width: 10, height: 10),
      );
      controller.addRect(
        const CanvasRect(id: 'c', x: 80, y: 0, width: 10, height: 10),
      );

      expect(
        controller.selectInBounds(
          const CanvasBounds(x: -1, y: -1, width: 50, height: 20),
        ),
        isTrue,
      );
      expect(controller.selectedObjectIds, ['a', 'b']);

      controller.beginHistoryBatch();
      expect(controller.moveSelectedBy(5, 0), isTrue);
      expect(controller.moveSelectedBy(5, 0), isTrue);
      controller.endHistoryBatch();
      expect((controller.objectById('a') as CanvasRect).x, 10);

      expect(controller.undo(), isTrue);
      expect((controller.objectById('a') as CanvasRect).x, 0);
      expect(controller.redo(), isTrue);
      expect((controller.objectById('a') as CanvasRect).x, 10);
      expect(events, ['undo', 'redo']);

      controller.clearHistory();
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);
    });

    test(
      'CanvasController supports keyboard delete, move, copy, and paste',
      () {
        final controller = CanvasController();
        const rect = CanvasRect(id: 'rect', x: 4, y: 6, width: 20, height: 12);

        controller.addRect(rect);
        expect(controller.select('rect'), isTrue);
        expect(controller.handleKeyboardCommand('ArrowRight'), isTrue);
        expect((controller.objectById('rect') as CanvasRect).x, 5);
        expect(
          controller.handleKeyboardCommand('ArrowDown', shift: true),
          isTrue,
        );
        expect((controller.objectById('rect') as CanvasRect).y, 16);

        expect(controller.handleKeyboardCommand('c', control: true), isTrue);
        expect(controller.handleKeyboardCommand('v', control: true), isTrue);
        expect(controller.objects, hasLength(2));
        expect(controller.selectedObjectId, 'rect_copy_1');
        expect((controller.selectedObject as CanvasRect).x, 17);

        expect(controller.handleKeyboardCommand('Delete'), isTrue);
        expect(controller.objectById('rect_copy_1'), isNull);
        expect(controller.objectById('rect'), isA<CanvasRect>());
      },
    );

    test('CanvasController groups selected objects and fires events', () {
      final events = <String>[];
      final controller = CanvasController(
        onSelect: (selected) => events.add('select:${selected.length}'),
        onChange: (_) => events.add('change'),
        onMove: (objects) => events.add('move:${objects.length}'),
        onResize: (objects) => events.add('resize:${objects.length}'),
        onRotate: (objects) => events.add('rotate:${objects.length}'),
      );
      const left = CanvasRect(id: 'left', x: 0, y: 0, width: 20, height: 10);
      const right = CanvasRect(id: 'right', x: 40, y: 0, width: 20, height: 10);

      controller.addRect(left);
      controller.addRect(right);
      expect(controller.selectMany(['left', 'right']), isTrue);
      expect(controller.selectedObjectIds, ['left', 'right']);
      expect(controller.selectedBounds?.width, 60);

      expect(controller.moveSelectedBy(5, 4), isTrue);
      expect((controller.objectById('left') as CanvasRect).x, 5);
      expect((controller.objectById('right') as CanvasRect).x, 45);

      expect(
        controller.resizeSelectedFromHandle(
          CanvasSelectionHandle.resizeSouthEast,
          60,
          10,
        ),
        isTrue,
      );
      expect((controller.objectById('left') as CanvasRect).width, 40);
      expect((controller.objectById('right') as CanvasRect).x, 85);

      expect(controller.rotateSelectedBy(15), isTrue);
      expect((controller.objectById('left') as CanvasRect).rotation, 15);
      expect((controller.objectById('right') as CanvasRect).rotation, 15);

      expect(controller.copySelected(), isTrue);
      final pasted = controller.pasteCopied();
      expect(pasted, hasLength(2));
      expect(controller.selectedObjectIds, ['left_copy_1', 'right_copy_1']);
      expect(controller.objects, hasLength(4));

      expect(events, contains('select:2'));
      expect(events, contains('move:2'));
      expect(events, contains('resize:2'));
      expect(events, contains('rotate:2'));
      expect(events.where((event) => event == 'change'), isNotEmpty);
    });

    test('CanvasController supports styling and layer panel helpers', () {
      final controller = CanvasController();
      const rect = CanvasRect(
        id: 'rect',
        name: 'Hero box',
        x: 0,
        y: 0,
        width: 30,
        height: 20,
      );
      const text = CanvasTextObject(id: 'text', text: 'Title', x: 8, y: 16);

      controller.addRect(rect);
      controller.addText(text);
      expect(controller.layerItems.first.id, 'text');
      expect(controller.layerItems.last.name, 'Hero box');

      expect(controller.selectMany(['rect', 'text']), isTrue);
      expect(
        controller.styleSelected(
          fill: '#ffffff',
          stroke: '#111827',
          lineWidth: 3,
          font: '20px Inter',
        ),
        isTrue,
      );
      expect(
        (controller.objectById('rect') as CanvasRect).paint.fill,
        '#ffffff',
      );
      expect(
        (controller.objectById('text') as CanvasTextObject).paint.font,
        '20px Inter',
      );

      expect(controller.setObjectName('rect', 'Card'), isTrue);
      expect((controller.objectById('rect') as CanvasRect).name, 'Card');
      expect(controller.renameObjectId('rect', 'card'), isTrue);
      expect(controller.objectById('rect'), isNull);
      expect(controller.objectById('card'), isA<CanvasRect>());
      expect(controller.selectedObjectIds, contains('card'));

      expect(controller.setObjectLocked('card', true), isTrue);
      expect(controller.moveBy('card', 10, 0), isFalse);
      expect(
        controller.updateObjectPaint('card', const CanvasPaint(fill: '#000')),
        isFalse,
      );

      expect(controller.setObjectHidden('text', true), isTrue);
      expect(controller.hitTest(8, 16)?.id, isNot('text'));
      expect(controller.select('text'), isTrue);
      expect(controller.selectedObjectId, 'text');
      expect(controller.layerItems.first.hidden, isTrue);
      expect(controller.layerItems.last.locked, isTrue);

      final restored = CanvasController()..loadJson(controller.toJson());
      expect((restored.objectById('card') as CanvasRect).name, 'Card');
      expect((restored.objectById('card') as CanvasRect).locked, isTrue);
      expect((restored.objectById('text') as CanvasTextObject).hidden, isTrue);
    });

    test('CanvasController supports snapping and alignment helpers', () {
      final controller = CanvasController();
      controller.addRect(
        const CanvasRect(id: 'a', x: 13, y: 17, width: 10, height: 10),
      );
      controller.addRect(
        const CanvasRect(id: 'b', x: 100, y: 20, width: 20, height: 20),
      );

      expect(controller.select('a'), isTrue);
      expect(controller.snapSelectedToGrid(10), isTrue);
      expect((controller.objectById('a') as CanvasRect).x, 10);
      expect((controller.objectById('a') as CanvasRect).y, 20);

      expect(controller.moveBy('a', 78, 0), isTrue);
      expect(controller.snapSelectedToObjects(threshold: 3), isTrue);
      expect((controller.objectById('a') as CanvasRect).x, 90);

      expect(controller.selectMany(['a', 'b']), isTrue);
      expect(controller.alignSelected(CanvasAlignment.right), isTrue);
      expect((controller.objectById('a') as CanvasRect).x, 110);
      expect((controller.objectById('b') as CanvasRect).x, 100);

      expect(controller.alignSelected(CanvasAlignment.top), isTrue);
      expect((controller.objectById('a') as CanvasRect).y, 20);
      expect((controller.objectById('b') as CanvasRect).y, 20);
    });

    test(
      'CanvasController supports guides, grid snapping, and constraints',
      () {
        final controller = CanvasController(
          snapToGrid: true,
          gridSize: 10,
          showGrid: true,
          showRulers: true,
          constraints: const CanvasObjectConstraints(
            minWidth: 20,
            minHeight: 10,
            maxWidth: 40,
            maxHeight: 30,
            keepAspectRatio: true,
            lockMovementX: true,
          ),
        );
        controller
          ..setCanvasSize(100, 100)
          ..addRect(
            const CanvasRect(id: 'rect', x: 13, y: 17, width: 20, height: 10),
          );

        expect(controller.select('rect'), isTrue);
        expect(controller.moveSelectedBy(50, 5), isTrue);
        final moved = controller.objectById('rect') as CanvasRect;
        expect(moved.x, 13);
        expect(moved.y, 20);
        expect(controller.snapGuides, isNotEmpty);
        expect(
          controller.snapGuides.map((guide) => guide.orientation),
          contains(CanvasGuideOrientation.horizontal),
        );

        expect(controller.resizeSelectedBy(100, 100), isTrue);
        final resized = controller.objectById('rect') as CanvasRect;
        expect(resized.width, 40);
        expect(resized.height, 20);

        final bounded = CanvasController(
          constraints: const CanvasObjectConstraints(
            preventOutsideCanvas: true,
          ),
        );
        bounded
          ..setCanvasSize(60, 60)
          ..addRect(
            const CanvasRect(
              id: 'outside',
              x: 40,
              y: 40,
              width: 30,
              height: 30,
            ),
          );
        expect(bounded.select('outside'), isTrue);
        expect(bounded.moveSelectedBy(10, 10), isTrue);
        final inside = bounded.objectById('outside') as CanvasRect;
        expect(inside.x, 30);
        expect(inside.y, 30);
      },
    );

    test('CanvasController supports text editing and font controls', () {
      final controller = CanvasController(
        onTextEdit: (text) => '${text.text} edited',
      );
      controller.addText(
        const CanvasTextObject(
          id: 'title',
          text: 'Title',
          x: 10,
          y: 20,
          paint: CanvasPaint(font: '16px Arial'),
        ),
      );

      expect(controller.updateText('title', 'Heading'), isTrue);
      expect(
        (controller.objectById('title') as CanvasTextObject).text,
        'Heading',
      );

      expect(controller.select('title'), isTrue);
      expect(controller.updateSelectedText('Hero'), isTrue);
      expect((controller.selectedObject as CanvasTextObject).text, 'Hero');

      expect(controller.setSelectedFont(family: 'Inter', size: 24), isTrue);
      expect(
        (controller.selectedObject as CanvasTextObject).paint.font,
        '24px Inter',
      );

      expect(controller.setObjectLocked('title', true), isTrue);
      expect(controller.updateSelectedText('Locked'), isFalse);
      expect((controller.selectedObject as CanvasTextObject).text, 'Hero');
    });

    test(
      'CanvasController exports selected objects and imports backend JSON',
      () {
        final controller = CanvasController();
        controller.addRect(
          const CanvasRect(id: 'rect', x: 0, y: 0, width: 20, height: 10),
        );
        controller.addText(
          const CanvasTextObject(id: 'text', text: 'Label', x: 4, y: 8),
        );
        expect(controller.select('text'), isTrue);

        final selected = controller.selectedToJson();
        expect(selected['objects'], isA<List<Object?>>());
        expect((selected['objects'] as List<Object?>), hasLength(1));
        expect(
          ((selected['objects'] as List<Object?>).single as Map)['type'],
          'text',
        );

        final duplicate = controller.duplicateSceneJson();
        (duplicate['objects'] as List<Object?>).clear();
        expect(controller.objects, hasLength(2));

        final restored = CanvasController()
          ..importBackendJson({
            'scene': controller.toJson(),
            'updatedAt': '2026-07-06T00:00:00Z',
          });
        expect(restored.objects, hasLength(2));
        expect(restored.selectedObjectId, 'text');

        final direct = CanvasController()
          ..importBackendJson(controller.toJson());
        expect(direct.objectById('rect'), isA<CanvasRect>());
      },
    );
  });

  group('navigation components', () {
    test('Tabs support nav variants and interaction states', () {
      final tabs = Tabs(
        activeKey: 'profile',
        variant: NavVariant.pill,
        tone: Tone.info,
        size: ComponentSize.sm,
        tabs: const [
          TabItem(key: 'home', label: 'Home'),
          TabItem(key: 'profile', label: 'Profile'),
        ],
      );

      final selected = tabs.children[1] as FlintElement;
      expect(selected.props['aria-selected'], 'true');
      expect(selected.props['className'], contains('flint-s-'));
      expect(
        selected.props['style'],
        containsPair('background', 'var(--color-infoSoft, #eff8ff)'),
      );
      expect(selected.props['style'], containsPair('min-height', '34px'));
      expect(selected.props['_flintStyleCss'], contains(':hover'));
      expect(selected.props['_flintStyleCss'], contains(':focus-visible'));
    });

    test('Pagination uses button variants for current and disabled states', () {
      final pagination = Pagination(page: 2, pageSize: 10, total: 24);
      final controls = pagination.children[1] as FlintElement;
      final current = controls.children[2] as FlintElement;
      final next = controls.children[4] as FlintElement;

      expect(current.props['aria-current'], 'page');
      expect(
        current.props['style'],
        containsPair('background', 'var(--color-primarySoft, #eff4ff)'),
      );
      expect(next.props['style'], containsPair('min-width', '34px'));
      expect(next.props['_flintStyleCss'], contains(':hover'));
    });
  });

  group('feedback components', () {
    test('Spinner renders status semantics', () {
      final spinner = Spinner(label: 'Loading users', tone: Tone.info);

      expect(spinner.props['role'], 'status');
      expect(
        spinner.props['style'],
        containsPair('border-top-color', 'var(--color-infoSolid, #1570ef)'),
      );
      expect(
        spinner.props['style'],
        containsPair(
          'animation',
          'flint-spin 800ms linear infinite normal none running',
        ),
      );
      expect(spinner.props['style'], containsPair('will-change', 'transform'));
      expect(spinner.children.single, isA<FlintText>());
    });

    test('Alert renders title, message, tone, and actions', () {
      final alert = Alert(
        title: 'Saved',
        message: 'The user was updated.',
        tone: Tone.success,
        actions: Button(child: 'Undo', variant: ButtonVariant.ghost),
      );

      expect(alert.props['role'], 'alert');
      expect(
        alert.props['style'],
        containsPair('background', 'var(--color-successSoft, #ecfdf3)'),
      );
      expect(alert.children, hasLength(3));
      expect(alert.children.first, isA<FlintElement>());
      expect(alert.children.last, isA<Button>());
    });

    test('StatusBadge renders label and tone style', () {
      final badge = StatusBadge(label: 'Active', tone: Tone.success);

      expect(badge.tag, 'span');
      expect(
        badge.props['style'],
        containsPair('background', 'var(--color-successSoft, #ecfdf3)'),
      );
      expect((badge.children.single as FlintText).value, 'Active');
    });

    test('StatusBadge supports outline and solid variants', () {
      final outline = StatusBadge(
        label: 'Review',
        tone: Tone.warning,
        variant: BadgeVariant.outline,
      );
      final solid = StatusBadge(
        label: 'Live',
        tone: Tone.success,
        variant: BadgeVariant.solid,
      );

      expect(outline.props['style'], containsPair('background', 'transparent'));
      expect(
        outline.props['style'],
        containsPair('color', 'var(--color-warningText, #b54708)'),
      );
      expect(
        solid.props['style'],
        containsPair('background', 'var(--color-successSolid, #079455)'),
      );
      expect(
        solid.props['style'],
        containsPair('color', 'var(--color-onSolid, #ffffff)'),
      );
    });
  });

  group('LineChart & BarChart', () {
    test('LineChart renders single series successfully', () {
      final chart = LineChart(
        data: const [10, 20, 15],
        labels: const ['A', 'B', 'C'],
        height: 200,
      );

      final svg = chart.children.first as FlintElement;
      expect(svg.tag, 'svg');
      expect(svg.props['viewBox'], '0 0 600.0 200.0');

      // Check grid lines and paths
      final gridLines = svg.children.where((c) => c is FlintElement && c.tag == 'line').toList();
      expect(gridLines.length, 4); // 4 grid lines

      final paths = svg.children.where((c) => c is FlintElement && (c.tag == 'polygon' || c.tag == 'polyline')).toList();
      expect(paths.length, 2); // 1 fill polygon + 1 stroke polyline
    });

    test('LineChart renders multi series successfully', () {
      final chart = LineChart(
        labels: const ['A', 'B', 'C'],
        series: const [
          LineChartSeries(
            data: [10, 20, 15],
            strokeColor: '#ff0000',
            fillColor: '#00ff00',
          ),
          LineChartSeries(
            data: [30, 40, 25],
            strokeColor: '#0000ff',
            fillColor: '#00ffff',
          ),
        ],
        height: 200,
      );

      final svg = chart.children.first as FlintElement;
      expect(svg.tag, 'svg');

      // 4 grid lines (common)
      final gridLines = svg.children.where((c) => c is FlintElement && c.tag == 'line').toList();
      expect(gridLines.length, 4);

      // We expect 2 polygon fills + 2 polyline strokes
      final polygons = svg.children.where((c) => c is FlintElement && c.tag == 'polygon').toList();
      expect(polygons.length, 2);
      expect((polygons[0] as FlintElement).props['fill'], '#00ff00');
      expect((polygons[1] as FlintElement).props['fill'], '#00ffff');

      final polylines = svg.children.where((c) => c is FlintElement && c.tag == 'polyline').toList();
      expect(polylines.length, 2);
      expect((polylines[0] as FlintElement).props['stroke'], '#ff0000');
      expect((polylines[1] as FlintElement).props['stroke'], '#0000ff');
    });

    test('BarChart renders data bars successfully', () {
      final chart = BarChart(
        data: const [10, 20, 15],
        labels: const ['A', 'B', 'C'],
        height: 200,
        barColor: '#ff0000',
      );

      final svg = chart.children.first as FlintElement;
      expect(svg.tag, 'svg');

      final bars = svg.children.where((c) => c is FlintElement && c.tag == 'rect').toList();
      expect(bars.length, 3);
      expect((bars[0] as FlintElement).props['fill'], '#ff0000');
    });

    test('BarChart renders multi series successfully', () {
      final chart = BarChart(
        labels: const ['A', 'B', 'C'],
        series: const [
          BarChartSeries(
            data: [10, 20, 15],
            barColor: '#ff0000',
          ),
          BarChartSeries(
            data: [30, 40, 25],
            barColor: '#0000ff',
          ),
        ],
        height: 200,
      );

      final svg = chart.children.first as FlintElement;
      expect(svg.tag, 'svg');

      final bars = svg.children.where((c) => c is FlintElement && c.tag == 'rect').toList();
      expect(bars.length, 6);
      expect((bars[0] as FlintElement).props['fill'], '#ff0000');
      expect((bars[1] as FlintElement).props['fill'], '#0000ff');
      expect((bars[2] as FlintElement).props['fill'], '#ff0000');
      expect((bars[3] as FlintElement).props['fill'], '#0000ff');
    });
  });
}
