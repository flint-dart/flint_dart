import '../../component.dart';
import '../../node.dart';
import '../../style.dart';
import '../primitives/container.dart';
import 'doc_viewer_controller.dart';

/// Native Word document viewer stub for non-web / server rendering.
class DocxViewer extends StatelessComponent {
  DocxViewer({
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
      children: [
        if (fallback != null) fallback!,
      ],
    );
  }
}
