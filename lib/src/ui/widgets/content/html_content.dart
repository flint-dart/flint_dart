import 'dart:js_interop';

import 'package:universal_web/web.dart' as web;

import '../../component.dart';
import '../../style.dart';
import '../primitives/container.dart';

/// Renders an HTML string into a DOM element after the component mounts.
///
/// This is useful for trusted server-rendered Markdown, CMS content, docs
/// pages, and other HTML fragments that should not be escaped as text.
class HtmlContent extends StatefulComponent {
  /// Creates an HTML content mount.
  HtmlContent({
    required this.html,
    this.id,
    this.selector,
    this.className,
    this.dartStyle,
    this.props = const {},
    this.trusted = true,
  });

  static int _nextId = 0;

  /// HTML string to render into the element.
  String html;

  /// Optional DOM id. If omitted, Flint UI creates a stable component id.
  String? id;

  /// Optional CSS selector for an existing element to receive the HTML.
  ///
  /// When omitted, [HtmlContent] writes into its own rendered wrapper element.
  String? selector;

  /// Optional class name for the wrapper element.
  String? className;

  /// Optional typed style for the wrapper element.
  DartStyle? dartStyle;

  /// Extra props for the wrapper element.
  Map<String, Object?> props;

  /// When true, writes [html] as HTML. When false, writes it as text content.
  bool trusted;

  late final String _generatedId = 'flint-html-content-${_nextId++}';
  String get _mountId => id ?? _generatedId;

  @override
  void updateFrom(covariant HtmlContent next) {
    html = next.html;
    id = next.id;
    selector = next.selector;
    className = next.className;
    dartStyle = next.dartStyle;
    props = next.props;
    trusted = next.trusted;
  }

  @override
  void didMount() {
    _writeHtml();
  }

  @override
  void didUpdate() {
    _writeHtml();
  }

  void _writeHtml() {
    final el = selector == null
        ? web.document.getElementById(_mountId)
        : web.document.querySelector(selector!);
    if (el == null) return;

    if (trusted) {
      el.innerHTML = html.toJS;
    } else {
      el.textContent = html;
    }
  }

  @override
  View build() {
    return Container(
      props: {...props, 'id': _mountId},
      className: className,
      dartStyle: dartStyle,
      children: const [],
    );
  }
}
