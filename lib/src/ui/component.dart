import 'node.dart';

/// Callback used to mutate component state before a rerender is scheduled.
typedef FlintStateUpdater = void Function();

/// Backwards-compatible alias for [StatefulComponent].
///
/// Prefer extending [StatefulComponent] or [StatelessComponent] in new code so
/// state preservation is explicit at the class declaration.
typedef Component = StatefulComponent;

/// Return type for component build methods.
///
/// A view can be a node, another component, text, or an iterable of renderable
/// values. Flint normalizes it before rendering.
typedef View = Object?;

/// Base class for reusable Flint UI components.
///
/// Prefer extending [StatelessComponent] for presentation widgets, or
/// [StatefulComponent] for components that manage local state or lifecycle.
/// Extending [StatelessComponent] or [StatefulComponent] directly makes state
/// preservation explicit and helps developer tools (and AI assistants) reason
/// about the component structure.
abstract class FlintComponent extends FlintNode {
  /// Creates a reusable Flint UI component.
  FlintComponent();

  void Function()? _scheduleRender;

  /// Builds this component's renderable output.
  ///
  /// App code can return a node, another component, text, or an iterable of
  /// renderable values. The renderer normalizes the value internally.
  View build();

  /// Whether Flint should preserve this component instance across parent
  /// rerenders when the runtime type and tree position match.
  ///
  /// Components are replaced by default when their parent rebuilds so
  /// constructor values always stay fresh. A component still keeps its local
  /// fields when it calls [setState] itself, because that rerenders the same
  /// mounted instance directly.
  ///
  /// Override this to `true` only for child components that must survive parent
  /// rerenders. Preserved components that also receive constructor values must
  /// override [updateFrom] to copy those values from the next instance.
  bool get preserveState => false;

  /// Applies [update] and schedules this component to render again.
  ///
  /// Pass `render: false` when the state change is intentionally internal and
  /// should not repaint the DOM, such as mirroring raw input text that is
  /// already visible in the focused control.
  void setState(FlintStateUpdater update, {bool render = true}) {
    update();
    if (!render) return;
    _scheduleRender?.call();
  }

  /// Called after the component is first mounted in the browser.
  void didMount() {}

  /// Called after the component updates following a rerender.
  void didUpdate() {}

  /// Receives the next component instance when Flint preserves this instance.
  ///
  /// Override this in stateful components that also accept constructor values.
  /// Flint keeps the existing instance so local state survives, then gives it
  /// the newly-created component so props-like fields can be copied in.
  void updateFrom(covariant FlintComponent next) {}

  /// Whether this component should rerender when it is updated from a new
  /// instance in the parent tree.
  ///
  /// Defaults to `true`. Override this to return `false` to prevent the component
  /// from clearing and rebuilding its DOM nodes during parent rerenders.
  bool shouldUpdate(covariant FlintComponent next) => true;

  /// Called before the component is removed from the tree.
  void willUnmount() {}

  /// Attaches the render scheduler used by [setState].
  void attach(void Function() scheduleRender) {
    _scheduleRender = scheduleRender;
  }
}

/// Base class for components that own local state or lifecycle resources.
///
/// Use this for pages, controllers, sockets, subscriptions, text editing
/// controllers, and other local state. A stateful component keeps its fields
/// when it calls [setState] itself. When its parent rebuilds, Flint creates a
/// fresh child instance by default so constructor values cannot go stale.
abstract class StatefulComponent extends FlintComponent {}

/// Base class for components that only render constructor-provided values.
///
/// Flint replaces stateless component instances during parent rerenders, so
/// final fields naturally receive the newest values.
abstract class StatelessComponent extends FlintComponent {}

/// Component wrapper for a function that returns renderable output.
class FunctionalComponent extends StatelessComponent {
  /// Builds the node tree for this functional component.
  final View Function() builder;

  /// Creates a component backed by [builder].
  FunctionalComponent(this.builder);

  /// Builds this component by calling [builder].
  @override
  View build() => builder();
}
