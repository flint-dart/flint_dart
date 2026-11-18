import '../../component.dart';
import '../../node.dart';
import '../../style.dart';
import '../primitives/container.dart';
import 'doc_viewer_controller.dart';

/// Native PDF document viewer stub for non-web / server rendering.
class PdfViewer extends StatelessComponent {
  PdfViewer({
    required this.src,
    this.title,
    this.controller,
    this.showToolbar = true,
    this.className,
    this.dartStyle,
    this.fallback,
    this.loadingWidget,
  });

  final String src;
  final String? title;
  final DocViewerController? controller;
  final bool showToolbar;
  final String? className;
  final DartStyle? dartStyle;
  final FlintNode? fallback;
  final FlintNode? loadingWidget;

  @override
  View build() {
    return Container(
      className: className,
      dartStyle: dartStyle,
    );
  }
}
