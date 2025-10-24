import 'package:flint_dart/flint_ui.dart';

class FlintText extends FlintWidget {
  final String data;
  final TextStyle? style;
  final TextAlign align;
  final int? maxLines;
  final TextOverflow? overflow;

  FlintText(
    this.data, {
    super.id, // <— inherit from FlintWidget
    this.style,
    this.align = TextAlign.left,
    this.maxLines,
    this.overflow,
  });

  @override
  String toHtml() {
    final style = _buildStyle();
    final tag = _getHtmlTag();
    // Include ID attribute
    return '<$tag id="$id" style="$style">${_escapeHtml(data)}</$tag>';
  }

  @override
  String toText() => _applyOverflow(data);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'text',
        'data': data,
        'style': style?.toJson(),
        'align': align.name,
        'maxLines': maxLines,
        'overflow': overflow?.name,
      };

  @override
  FlintWidget buildTemplate() => this;

  String _applyOverflow(String text) {
    var t = text;
    if (maxLines != null) {
      final lines = t.split('\n');
      if (lines.length > maxLines!) {
        t = lines.take(maxLines!).join('\n');
        if (overflow == TextOverflow.ellipsis) t += '...';
      }
    }
    return t;
  }

  String _buildStyle() {
    final s = <String>[];
    if (style != null) {
      if (style!.fontSize != null) s.add('font-size: ${style!.fontSize}px;');
      if (style!.color != null) s.add('color: ${style!.color};');
      if (style!.fontWeight != null) {
        s.add('font-weight: ${style!.fontWeight!.value};');
      }
    }
    s.add('text-align: ${align.toCss()}; line-height: 1.6;');
    return s.join(' ');
  }

  String _getHtmlTag() {
    if (style?.fontSize != null) {
      if (style!.fontSize! >= 24) return 'h1';
      if (style!.fontSize! >= 20) return 'h2';
      if (style!.fontSize! >= 18) return 'h3';
    }
    return 'span';
  }

  String _escapeHtml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
