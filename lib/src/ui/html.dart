import 'component.dart';
import 'component_props.dart' as component_props;
import 'node.dart';

/// Creates a raw element node with [tag], [props], and normalized [children].
FlintElement h(
  String tag, {
  Map<String, Object?> props = const {},
  List<Object?> children = const [],
}) {
  return FlintElement(
    tag,
    props: props,
    children: children.map(component_props.toFlintNode).toList(growable: false),
  );
}

/// Creates a text node from [value].
FlintText text(Object? value) => FlintText(value?.toString() ?? '');

/// Creates a fragment node from normalized [children].
FlintFragment fragment(List<Object?> children) {
  return FlintFragment(
    children.map(component_props.toFlintNode).toList(growable: false),
  );
}

/// Creates a node that renders [component].
FlintComponentNode component(FlintComponent component) {
  return FlintComponentNode(component);
}

/// Converts common values into a renderable Flint node.
FlintNode toFlintNode(Object? value) {
  return component_props.toFlintNode(value);
}

/// Creates a raw `div` element.
FlintElement div({
  Map<String, Object?> props = const {},
  List<Object?> children = const [],
}) => h('div', props: props, children: children);

/// Creates a raw `span` element.
FlintElement span({
  Map<String, Object?> props = const {},
  List<Object?> children = const [],
}) => h('span', props: props, children: children);

/// Creates a raw `button` element.
FlintElement button({
  Map<String, Object?> props = const {},
  List<Object?> children = const [],
}) => h('button', props: props, children: children);

/// Creates a raw `input` element.
FlintElement input({Map<String, Object?> props = const {}}) =>
    h('input', props: props);
