import 'package:flint_dart/flint_ui_server.dart'
    show
        Canvas,
        CanvasController,
        FlintElement,
        MediaPreview,
        MediaStreamResult;
import 'package:test/test.dart';

void main() {
  test('server entrypoint exports server-safe media and canvas widgets', () {
    final canvas = Canvas(controller: CanvasController());
    final preview = MediaPreview(
      result: const MediaStreamResult(granted: false),
    );

    final previewNode = preview.build();

    expect(canvas.tag, 'canvas');
    expect(previewNode, isA<FlintElement>());
    expect((previewNode as FlintElement).tag, 'video');
  });
}
