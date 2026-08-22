import '../../component.dart';
import '../../node.dart';
import '../../style.dart';
import '../primitives/container.dart';

/// Server-safe HTML content component.
class HtmlContent extends StatefulComponent {
  HtmlContent({
    required this.html,
    this.id,
    this.selector,
    this.className,
    this.dartStyle,
    this.props = const {},
    this.trusted = true,
  });

  String html;
  String? id;
  String? selector;
  String? className;
  DartStyle? dartStyle;
  Map<String, Object?> props;
  bool trusted;

  @override
  View build() {
    return Container(
      props: {...props, if (id != null) 'id': id},
      className: className,
      dartStyle: dartStyle,
      children: [FlintRawHtml(html, trusted: trusted)],
    );
  }
}
