import 'component.dart';
import 'component_props.dart' as component_props;
import 'component_registry.dart';
import 'node.dart';

/// Renders Flint UI nodes and components to an HTML string on the server.
class FlintServerRenderer {
  /// Creates a server renderer.
  const FlintServerRenderer({this.includeScopedStyles = true});

  /// Whether collected scoped styles should be prepended to the rendered HTML.
  final bool includeScopedStyles;

  /// Renders a registered page component to HTML.
  String renderPage(
    PageRegistry registry,
    String component, {
    Map<String, dynamic> props = const {},
    FlintComponent Function(String component)? missingPage,
  }) {
    final builder = registry[component];
    final page =
        builder?.call(props) ??
        missingPage?.call(component) ??
        _MissingServerPage(component);
    return render(page);
  }

  /// Renders any Flint renderable value to HTML.
  String render(Object? value) {
    final context = _ServerRenderContext();
    final html = _renderNode(_normalize(value), context);
    if (!includeScopedStyles || context.scopedStyles.isEmpty) return html;

    final css = context.scopedStyles.join('\n');
    return '<style data-flint-ssr-style>${_escapeHtmlText(css)}</style>$html';
  }

  FlintNode _normalize(Object? value) {
    if (value is FlintNode) return value;
    if (value is FlintComponent) return FlintComponentNode(value);
    if (value is Iterable<Object?>) {
      return FlintFragment(value.map(_normalize).toList(growable: false));
    }
    return FlintText(value?.toString() ?? '');
  }

  String _renderNode(FlintNode node, _ServerRenderContext context) {
    return switch (node) {
      FlintText(:final value) => _escapeHtmlText(value),
      FlintRawHtml(:final value, :final trusted) =>
        trusted ? value : _escapeHtmlText(value),
      FlintFragment(:final children) =>
        children.map((child) => _renderNode(child, context)).join(),
      FlintElement(:final tag, :final props, :final children) => _renderElement(
        tag,
        props,
        children,
        context,
      ),
      FlintComponent() => _renderNode(_normalize(node.build()), context),
      FlintComponentNode(:final component) => _renderNode(
        _normalize(component.build()),
        context,
      ),
      _ => '',
    };
  }

  String _renderElement(
    String tag,
    Map<String, Object?> props,
    List<FlintNode> children,
    _ServerRenderContext context,
  ) {
    final safeTag = _safeTagName(tag);
    if (safeTag == null) return '';

    final attributes = _renderAttributes(props, context);
    if (_voidTags.contains(safeTag)) {
      return '<$safeTag$attributes>';
    }

    final body = children.map((child) => _renderNode(child, context)).join();
    return '<$safeTag$attributes>$body</$safeTag>';
  }

  String _renderAttributes(
    Map<String, Object?> props,
    _ServerRenderContext context,
  ) {
    final attributes = <String>[];

    for (final entry in props.entries) {
      final name = entry.key;
      final value = entry.value;
      if (value == null || value == false) continue;
      if (name.startsWith('on') && value is Function) continue;
      if (name.startsWith('_flint') && name != '_flintStyleCss') continue;

      if (name == '_flintStyleCss') {
        final css = value.toString().trim();
        if (css.isNotEmpty) context.scopedStyles.add(css);
        continue;
      }

      if (name == 'className') {
        attributes.add('class="${_escapeHtmlAttribute(value.toString())}"');
        continue;
      }

      if (name == 'style') {
        final style = _styleToAttribute(value);
        if (style.isNotEmpty) {
          attributes.add('style="${_escapeHtmlAttribute(style)}"');
        }
        continue;
      }

      final safeName = _safeAttributeName(name);
      if (safeName == null) continue;

      if (value == true) {
        attributes.add(safeName);
        continue;
      }

      attributes.add('$safeName="${_escapeHtmlAttribute(value.toString())}"');
    }

    return attributes.isEmpty ? '' : ' ${attributes.join(' ')}';
  }

  String _styleToAttribute(Object? value) {
    if (value is String) return value.trim();
    if (value is Map<String, Object?>) {
      return component_props.styleToCss(value);
    }
    return '';
  }
}

class _ServerRenderContext {
  final Set<String> scopedStyles = {};
}

class _MissingServerPage extends StatelessComponent {
  _MissingServerPage(this.component);

  final String component;

  @override
  View build() {
    return FlintElement(
      'div',
      props: const {
        'style': {'padding': '24px', 'font-family': 'system-ui, sans-serif'},
      },
      children: [FlintText('Flint page "$component" was not registered.')],
    );
  }
}

String? _safeTagName(String tag) {
  final normalized = tag.trim().toLowerCase();
  if (RegExp(r'^[a-z][a-z0-9:-]*$').hasMatch(normalized)) {
    return normalized;
  }
  return null;
}

String? _safeAttributeName(String name) {
  final normalized = name.trim();
  if (RegExp(r'^[a-zA-Z_:][a-zA-Z0-9:_.-]*$').hasMatch(normalized)) {
    return normalized;
  }
  return null;
}

String _escapeHtmlText(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

String _escapeHtmlAttribute(String value) {
  return _escapeHtmlText(
    value,
  ).replaceAll('"', '&quot;').replaceAll("'", '&#39;');
}

const _voidTags = {
  'area',
  'base',
  'br',
  'col',
  'embed',
  'hr',
  'img',
  'input',
  'link',
  'meta',
  'param',
  'source',
  'track',
  'wbr',
};
