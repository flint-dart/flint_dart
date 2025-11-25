import 'package:flint_dart/flint_ui.dart';

class Text extends FlintWidget {
  final String data;
  final TextStyle? style;
  final TextAlign align;
  final int? maxLines;
  final TextOverflow? overflow;

  Text(
    this.data, {
    super.id,
    this.style,
    this.align = TextAlign.left,
    this.maxLines,
    this.overflow,
    super.xData,
    super.xInit,
    super.xShow,
    super.xBind,
    super.xOn,
    super.xText,
    super.xHtml,
    super.xModel,
    super.xModelable,
    super.xFor,
    super.xTransition,
    super.xEffect,
    super.xIgnore,
    super.xRef,
    super.xCloak,
    super.xTeleport,
    super.xIf,
    super.xId,
  });

  @override
  String toHtml() {
    final styleStr = _buildStyle();
    final tag = _getHtmlTag();
    final attrs = directives;

    // Convert directives map → HTML attributes
    final attrStr = attrs.entries
        .map((e) => e.value.isEmpty ? e.key : '${e.key}="${e.value}"')
        .join(' ');

    return '<$tag $attrStr style="$styleStr">${_escapeHtml(data)}</$tag>';
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
        'directives': directives,
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
    s.add('text-align: ${align.toCss()}; line-height: 1.2;');
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
