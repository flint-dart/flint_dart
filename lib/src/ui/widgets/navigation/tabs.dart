import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../shared/theme.dart';

/// Tab option rendered by [Tabs].
class TabItem {
  /// Stable key used to identify the tab.
  final String key;

  /// Visible tab label.
  final String label;

  /// Optional leading icon or element.
  final Object? icon;

  /// Whether this tab should be unavailable.
  final bool disabled;

  /// Creates a tab item.
  const TabItem({
    required this.key,
    required this.label,
    this.icon,
    this.disabled = false,
  });
}

/// Tablist control for switching between keyed tabs.
class Tabs extends FlintElement {
  /// Creates a tablist from [tabs].
  Tabs({
    List<TabItem> tabs = const [],
    String? activeKey,
    NavVariant variant = NavVariant.underline,
    Tone tone = Tone.primary,
    ComponentSize size = ComponentSize.md,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
    void Function(Object event, TabItem tab)? onChanged,
  }) : super(
         'div',
         props: mergeComponentProps(
           {...props, 'role': props['role'] ?? 'tablist'},
           className: className,
           defaultStyle: const {
             'display': 'flex',
             'align-items': 'center',
             'gap': '4px',
             'border-bottom': '1px solid #e4e7ec',
           },
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           for (final tab in tabs)
             _tabButton(
               tab,
               selected: tab.key == activeKey,
               variant: variant,
               tone: tone,
               size: size,
               onChanged: onChanged,
             ),
         ],
       );

  static FlintElement _tabButton(
    TabItem tab, {
    required bool selected,
    required NavVariant variant,
    required Tone tone,
    required ComponentSize size,
    required void Function(Object event, TabItem tab)? onChanged,
  }) {
    return FlintElement(
      'button',
      props: mergeComponentProps(
        {
          'type': 'button',
          'role': 'tab',
          'aria-selected': selected.toString(),
          if (tab.disabled) 'disabled': true,
          if (onChanged != null && !tab.disabled)
            'onClick': (Object event) => onChanged(event, tab),
        },
        dartStyle: navItemComponentStyle(
          variant: variant,
          tone: tone,
          size: size,
          selected: selected,
          disabled: tab.disabled,
        ),
      ),
      children: [
        if (tab.icon != null) toFlintNode(tab.icon),
        FlintText(tab.label),
      ],
    );
  }
}
