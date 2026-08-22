import 'component.dart';

/// Short public alias for [FlintNode] in app code and examples.
///
/// Prefer returning [View] in [Component] build methods instead of [Node]
/// to support returning raw text, lists, or other components.
typedef Node = FlintNode;

/// Base type for all renderable Flint UI nodes.
///
/// Prefer returning [View] in [Component] build methods instead of [FlintNode]
/// to support returning raw text, lists, or other components.
abstract class FlintNode {
  /// Creates a Flint UI node.
  const FlintNode();
}

/// Text node rendered into the browser DOM.
class FlintText extends FlintNode {
  /// Text content for this node.
  final String value;

  /// Creates a text node containing [value].
  const FlintText(this.value);
}

/// Groups multiple child nodes without adding an element wrapper.
class FlintFragment extends FlintNode {
  /// Child nodes rendered in order.
  final List<FlintNode> children;

  /// Creates a fragment from [children].
  const FlintFragment(this.children);
}

/// Raw HTML node used by server rendering for trusted HTML fragments.
class FlintRawHtml extends FlintNode {
  /// HTML content to render without escaping when trusted.
  final String value;

  /// Whether [value] should be rendered as HTML instead of text.
  final bool trusted;

  /// Creates a raw HTML node.
  const FlintRawHtml(this.value, {this.trusted = true});
}

/// DOM element node with a tag, properties, and children.
class FlintElement extends FlintNode {
  /// HTML tag name for this element.
  final String tag;

  /// Element attributes, event handlers, classes, and styles.
  final Map<String, Object?> props;

  /// Child nodes rendered inside the element.
  final List<FlintNode> children;

  /// Creates an element with [tag], optional [props], and [children].
  const FlintElement(
    this.tag, {
    this.props = const {},
    this.children = const [],
  });
}

/// Node wrapper that lets a [FlintComponent] render in the node tree.
class FlintComponentNode extends FlintNode {
  /// Component rendered by this node.
  final FlintComponent component;

  /// Creates a node for [component].
  const FlintComponentNode(this.component);
}
