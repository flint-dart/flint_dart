import '../../component.dart';
import '../../style.dart';
import '../primitives/container.dart';

/// Provides a Flint UI theme mode to a subtree through `data-theme`.
///
/// Pair this with [RootDesign.themeProvider] to emit light and dark CSS tokens.
class ThemeProvider extends StatelessComponent {
  /// Creates a theme provider for [child] or [children].
  ThemeProvider({
    this.mode = FlintThemeMode.light,
    Object? child,
    this.children = const [],
    this.dartStyle,
    this.className,
    this.props = const {},
  }) : child = child;

  /// Active theme mode for this subtree.
  final FlintThemeMode mode;

  /// Optional single child.
  final Object? child;

  /// Optional child list.
  final List<Object?> children;

  /// Optional provider element style.
  final DartStyle? dartStyle;

  /// Optional provider element class.
  final String? className;

  /// Additional props merged onto the provider element.
  final Map<String, Object?> props;

  @override
  View build() {
    return Container(
      className: className,
      props: {...props, 'data-theme': mode.value},
      dartStyle: dartStyle,
      child: child,
      children: children,
    );
  }
}
