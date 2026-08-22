@TestOn('browser')
library;

import 'package:flint_dart/flint_ui.dart';
import 'package:test/test.dart';
import 'package:universal_web/web.dart' as web;

void main() {
  group('device controllers browser exports', () {
    test('compile and expose browser support flags', () {
      const media = MediaDevicesController();
      const location = GeoLocationController();

      expect(media.isSupported, isTrue);
      expect(media.isCameraSupported, isTrue);
      expect(media.isMicrophoneSupported, isTrue);
      expect(media.isScreenShareSupported, isTrue);
      expect(location.isSupported, isTrue);
    });

    test('MediaPreview compiles in browser builds', () {
      final preview = MediaPreview(
        result: const MediaStreamResult(granted: false),
        type: MediaPreviewType.audio,
      ).build();

      expect(preview, isA<Audio>());
    });

    test('MediaElementController binds to rendered video elements', () async {
      final host = web.document.createElement('div');
      web.document.body?.appendChild(host);
      addTearDown(() {
        host.remove();
      });

      final controller = MediaElementController();
      createRootForElement(
        host,
      ).render(Video(controller: controller, controls: false, muted: true));

      await Future<void>.delayed(Duration.zero);

      expect(controller.isAttached, isTrue);
      expect(controller.isPaused, isTrue);
      expect(controller.muted, isTrue);

      controller.setVolume(0.25);
      controller.unmute();
      controller.setPlaybackRate(1.5);

      expect(controller.volume, closeTo(0.25, 0.001));
      expect(controller.muted, isFalse);
      expect(controller.playbackRate, closeTo(1.5, 0.001));

      controller.detach();
      expect(controller.isAttached, isFalse);
    });

    test('capture and recorder controllers compile in browser builds', () {
      final recorder = MediaRecorderController();
      const capture = PhotoCaptureController();

      expect(recorder.isSupported, isTrue);
      expect(recorder.isRecording, isFalse);
      expect(capture.isSupported, isTrue);
      expect(
        const CapturedMedia(
          kind: CapturedMediaKind.audio,
          filename: 'voice.webm',
          mimeType: 'audio/webm',
          size: 0,
          dataUrl: 'data:audio/webm;base64,',
          base64: '',
        ).toUploadBody()['type'],
        'audio',
      );
    });

    test('CanvasController binds and exports a data URL', () async {
      final host = web.document.createElement('div');
      web.document.body?.appendChild(host);
      addTearDown(() {
        host.remove();
      });

      final events = <String>[];
      final controller = CanvasController(
        onPointerDown: (event) => events.add('down:${event.object?.id}'),
        onPointerUp: (event) => events.add('up:${event.object?.id}'),
        onHover: (event) => events.add('hover:${event.object?.id}'),
        onDragStart: (event) => events.add('dragStart:${event.object?.id}'),
        onDragEnd: (event) => events.add('dragEnd:${event.object?.id}'),
        onResizeStart: (event) => events.add('resizeStart:${event.handle}'),
        onResizeEnd: (event) => events.add('resizeEnd:${event.handle}'),
        onRotateStart: (event) => events.add('rotateStart:${event.handle}'),
        onRotateEnd: (event) => events.add('rotateEnd:${event.handle}'),
        gridSize: 8,
        showGrid: true,
        showRulers: true,
        showSnapGuides: true,
        constraints: const CanvasObjectConstraints(preventOutsideCanvas: true),
      );
      createRootForElement(
        host,
      ).render(Canvas(controller: controller, width: 80, height: 40));

      await Future<void>.delayed(Duration.zero);

      expect(controller.isAttached, isTrue);
      controller.addRect(
        const CanvasRect(
          id: 'rect',
          x: 4,
          y: 4,
          width: 24,
          height: 16,
          borderRadius: 4,
          rotation: 12,
          paint: CanvasPaint(fill: '#ff0000', stroke: '#111827'),
        ),
      );
      controller.addRect(
        const CanvasRect(
          id: 'pattern',
          x: 4,
          y: 24,
          width: 24,
          height: 8,
          paint: CanvasPaint(
            fill: '#0000ff',
            pattern: CanvasImagePattern(
              src:
                  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/luzjYwAAAABJRU5ErkJggg==',
            ),
            stroke: null,
            lineWidth: 0,
          ),
        ),
      );
      controller.addCircle(
        const CanvasCircle(
          id: 'dot',
          x: 48,
          y: 20,
          radius: 8,
          paint: CanvasPaint(fill: '#00ff00', stroke: null),
        ),
      );
      controller.addText(
        const CanvasTextObject(
          id: 'text',
          text: 'A',
          x: 62,
          y: 24,
          paint: CanvasPaint(fill: '#111827', stroke: null),
        ),
      );
      controller.addImage(
        const CanvasImageObject(
          id: 'image',
          src:
              'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/luzjYwAAAABJRU5ErkJggg==',
          x: 68,
          y: 4,
          width: 8,
          height: 8,
        ),
      );

      expect(controller.objectById('rect'), isA<CanvasRect>());
      expect(controller.objectById('image'), isA<CanvasImageObject>());
      expect(controller.select('rect'), isTrue);
      final canvas = host.querySelector('canvas');
      canvas?.dispatchEvent(
        web.MouseEvent('mousedown', web.MouseEventInit(clientX: 8, clientY: 8)),
      );
      canvas?.dispatchEvent(
        web.MouseEvent('mouseup', web.MouseEventInit(clientX: 8, clientY: 8)),
      );
      expect(controller.selectAt(8, 8)?.id, 'rect');
      expect(controller.moveSelectedBy(2, 2), isTrue);
      expect((controller.objectById('rect') as CanvasRect).x, 6);
      expect(controller.resizeSelectedBy(4, 3), isTrue);
      expect((controller.objectById('rect') as CanvasRect).width, 28);
      expect(controller.rotateSelectedBy(18), isTrue);
      expect((controller.objectById('rect') as CanvasRect).rotation, 30);
      expect(controller.toDataUrl(), startsWith('data:image/png'));
      expect(controller.undo(), isTrue);
      expect(controller.redo(), isTrue);
      expect(controller.remove('dot'), isTrue);
      final restored = CanvasController()..loadJson(controller.toJson());
      expect(restored.objects, hasLength(controller.objects.length));
      expect(events, contains('down:rect'));
      expect(events, contains('up:rect'));
      expect(
        events,
        contains('resizeStart:CanvasSelectionHandle.resizeNorthWest'),
      );
      expect(
        events,
        contains('resizeEnd:CanvasSelectionHandle.resizeNorthWest'),
      );
      controller.detach();
      expect(controller.isAttached, isFalse);
    });

    test('ThreeSceneController binds to rendered scene canvas', () async {
      final host = web.document.createElement('div');
      web.document.body?.appendChild(host);
      addTearDown(() {
        host.remove();
      });

      final events = <String>[];
      final controller = ThreeSceneController(
        autoStart: false,
        onAttach: (controller) {
          events.add('attach:${controller.width}x${controller.height}');
        },
        onFrame: (_, timestamp) {
          events.add('frame:${timestamp.round()}');
        },
        onDispose: (_) {
          events.add('dispose');
        },
      );

      createRootForElement(
        host,
      ).render(ThreeScene(controller: controller, width: 96, height: 54));

      await Future<void>.delayed(Duration.zero);

      expect(controller.isSupported, isTrue);
      expect(controller.isAttached, isTrue);
      expect(controller.width, 96);
      expect(controller.height, 54);
      expect(controller.canvas, isA<web.HTMLCanvasElement>());
      expect(events, contains('attach:96x54'));
      expect(controller.getThreeProperty('Scene'), isNull);

      controller.resize(width: 120, height: 80);
      expect(controller.width, 120);
      expect(controller.height, 80);

      controller.render(16);
      expect(events, contains('frame:16'));

      controller.dispose();
      expect(controller.isAttached, isFalse);
      expect(events, contains('dispose'));
    });
  });
}
