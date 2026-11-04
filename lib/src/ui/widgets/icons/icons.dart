import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// A reusable SVG icon definition for Flint UI.
class IconData {
  /// Stable icon name.
  final String name;

  /// SVG view box used by this icon.
  final String viewBox;

  /// SVG child shapes that draw this icon.
  final List<IconShape> shapes;

  /// Creates an icon definition.
  const IconData(this.name, {this.viewBox = '0 0 24 24', required this.shapes});
}

/// A low-level SVG shape used by [IconData].
class IconShape {
  /// SVG tag name, such as `path`, `circle`, or `line`.
  final String tag;

  /// SVG attributes for the shape.
  final Map<String, Object?> props;

  /// Creates a shape with [tag] and [props].
  const IconShape(this.tag, this.props);

  FlintElement toNode() => FlintElement(tag, props: props);
}

/// Inline SVG icon component.
///
/// Icons inherit text color by default through `currentColor`, so they can sit
/// inside buttons, badges, links, and headings without extra styling.
class Icon extends FlintElement {
  /// Creates an inline SVG icon from a [IconData] definition.
  Icon(
    IconData icon, {
    Object? size = 20,
    Object? color,
    double strokeWidth = 2,
    String? label,
    String? title,
    bool? decorative,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
          'svg',
          props: mergeComponentProps(
            {
              ...props,
              'xmlns': 'http://www.w3.org/2000/svg',
              'viewBox': icon.viewBox,
              'fill': 'none',
              'stroke': 'currentColor',
              'stroke-width': strokeWidth,
              'stroke-linecap': 'round',
              'stroke-linejoin': 'round',
              'focusable': 'false',
              if (decorative ?? (label == null && title == null))
                'aria-hidden': 'true'
              else ...{
                'role': 'img',
                'aria-label': label ?? title ?? icon.name,
              },
            },
            className: className,
            defaultStyle: {
              'display': 'inline-block',
              'width': _iconCssSize(size),
              'height': _iconCssSize(size),
              'color': color ?? 'currentColor',
              'vertical-align': 'middle',
              'flex-shrink': 0,
            },
            dartStyle: dartStyle,
            style: style,
          ),
          children: [
            if (title != null)
              FlintElement('title', children: [FlintText(title)]),
            ...icon.shapes.map((shape) => shape.toNode()),
          ],
        );
}

/// Curated HugeIcons outline icons built into Flint UI by default.
class Icons {
  const Icons._();

  static const activity = IconData(
    'activity',
    shapes: [
      IconShape('path', {'d': 'M4.31802 19.682C3 18.364 3 16.2426 3 12C3 7.75736 3 5.63604 4.31802 4.31802C5.63604 3 7.75736 3 12 3C16.2426 3 18.364 3 19.682 4.31802C21 5.63604 21 7.75736 21 12C21 16.2426 21 18.364 19.682 19.682C18.364 21 16.2426 21 12 21C7.75736 21 5.63604 21 4.31802 19.682Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M7 14L9.79289 11.2071C10.1834 10.8166 10.8166 10.8166 11.2071 11.2071L12.7929 12.7929C13.1834 13.1834 13.8166 13.1834 14.2071 12.7929L17 10', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const alarm = IconData(
    'alarm',
    shapes: [
      IconShape('path', {'d': 'M20.5 12.5C20.5 17.1944 16.6944 21 12 21C7.30558 21 3.5 17.1944 3.5 12.5C3.5 7.80558 7.30558 4 12 4C16.6944 4 20.5 7.80558 20.5 12.5Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M5.88 18.7031L3.5 21.0031', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M18.14 18.668L20.5 20.998', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M5 3L2 6', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M22 6L19 3', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12 8V12.5L14 14.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const alertCircle = IconData(
    'alertCircle',
    shapes: [
      IconShape('circle', {'cx': '12', 'cy': '12', 'r': '10', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12 8V12', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12.125 15.75H12M12.25 15.75C12.25 15.8881 12.1381 16 12 16C11.8619 16 11.75 15.8881 11.75 15.75C11.75 15.6119 11.8619 15.5 12 15.5C12.1381 15.5 12.25 15.6119 12.25 15.75Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const archive = IconData(
    'archive',
    shapes: [
      IconShape('path', {'d': 'M13 2H11C7.22876 2 5.34315 2 4.17157 3.17157C3 4.34315 3 6.22876 3 10V14C3 17.7712 3 19.6569 4.17157 20.8284C5.34315 22 7.22876 22 11 22H13C16.7712 22 18.6569 22 19.8284 20.8284C21 19.6569 21 17.7712 21 14V10C21 6.22876 21 4.34315 19.8284 3.17157C18.6569 2 16.7712 2 13 2Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M21 12H3', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M15 7H9', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M15 17H9', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
    ],
  );
  static const arrowDown = IconData(
    'arrowDown',
    shapes: [
      IconShape('path', {'d': 'M12 18.502V5.00195', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M18 13.002C18 13.002 13.5811 19.0019 12 19.002C10.4188 19.002 6 13.002 6 13.002', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const arrowLeft = IconData(
    'arrowLeft',
    shapes: [
      IconShape('path', {'d': 'M5.5 12.002H19', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M10.9999 18.002C10.9999 18.002 4.99998 13.583 4.99997 12.0019C4.99996 10.4208 11 6.00195 11 6.00195', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const arrowRight = IconData(
    'arrowRight',
    shapes: [
      IconShape('path', {'d': 'M18.5 12L4.99997 12', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M13 18C13 18 19 13.5811 19 12C19 10.4188 13 6 13 6', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const arrowUp = IconData(
    'arrowUp',
    shapes: [
      IconShape('path', {'d': 'M12 5.5V19', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M18 11C18 11 13.5811 5.00001 12 5C10.4188 4.99999 6 11 6 11', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const atSign = IconData(
    'atSign',
    shapes: [
      IconShape('path', {'d': 'M15.6 8.40033V12.9003C15.6 14.3915 16.8088 15.6003 18.3 15.6003C19.7912 15.6003 21 14.3915 21 12.9003V12C21 7.02944 16.9706 3 12 3C7.02944 3 3 7.02944 3 12C3 16.9706 7.02944 21 12 21C14.0265 21 15.8965 20.3302 17.4009 19.2M15.6 12.0003C15.6 13.9886 13.9882 15.6003 12 15.6003C10.0118 15.6003 8.4 13.9886 8.4 12.0003C8.4 10.0121 10.0118 8.40033 12 8.40033C13.9882 8.40033 15.6 10.0121 15.6 12.0003Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
    ],
  );
  static const award = IconData(
    'award',
    shapes: [
      IconShape('path', {'d': 'M15.9349 21.033C16.1789 21.5331 15.699 22 15.1239 22H8.87606C8.30096 22 7.82107 21.5331 8.06509 21.033C8.63149 19.8722 10.1793 19 12 19C13.8207 19 15.3685 19.8722 15.9349 21.033Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12 16L11.9883 19', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M17.9866 4.49139C17.992 4.30176 17.9963 4.11477 17.9997 3.93095C18.0194 2.86463 17.1162 2.00002 16.0093 2.00002L7.99052 2C6.88381 2 5.98074 2.86438 6.00031 3.93054C6.00358 4.10833 6.00768 4.28907 6.01283 4.47231C6.05734 6.05627 6.18024 7.82593 6.51875 9.47415C7.18043 12.6958 8.66606 16 12.0001 16C15.3341 16 16.8193 12.6958 17.481 9.47415C17.8181 7.83255 17.9415 6.07048 17.9866 4.49139Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M18 4.5L19.4447 4.68748C20.9062 4.87714 22 6.122 22 7.59578C22 8.99373 21.0133 10.1973 19.6425 10.4715L17.5 11', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M6 4.5L4.55527 4.68748C3.09375 4.87714 2 6.122 2 7.59578C2 8.99373 2.98673 10.1973 4.35754 10.4715L6.5 11', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const bank = IconData(
    'bank',
    shapes: [
      IconShape('path', {'d': 'M12.125 5.75H12M12.25 5.75C12.25 5.88807 12.1381 6 12 6C11.8619 6 11.75 5.88807 11.75 5.75C11.75 5.61193 11.8619 5.5 12 5.5C12.1381 5.5 12.25 5.61193 12.25 5.75Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M5 9V19M9 9V19', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M15 9V19M19 9V19', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M21.3518 9H2.64822C2.29022 9 2 8.70651 2 8.34447C2 8.12259 2.11099 7.91577 2.29495 7.79485L8.73007 3.56485C10.3171 2.52162 11.1107 2 12 2C12.8893 2 13.6829 2.52162 15.2699 3.56485L21.7051 7.79485C21.889 7.91577 22 8.12259 22 8.34447C22 8.70651 21.7098 9 21.3518 9Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M21.0397 20.2929L20.3519 19.5858C20.0707 19.2968 19.9301 19.1522 19.7514 19.0761C19.5726 19 19.3738 19 18.9762 19H5.02382C4.62621 19 4.4274 19 4.24863 19.0761C4.06987 19.1522 3.92929 19.2968 3.64814 19.5858L2.9603 20.2929C2.25356 21.0194 1.9002 21.3827 2.02456 21.6913C2.14893 22 2.64867 22 3.64814 22H20.3519C21.3513 22 21.8511 22 21.9754 21.6913C22.0998 21.3827 21.7464 21.0194 21.0397 20.2929Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const bell = IconData(
    'bell',
    shapes: [
      IconShape('path', {'d': 'M19 18V9.5C19 5.63401 15.866 2.5 12 2.5C8.13401 2.5 5 5.63401 5 9.5V18', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M20.5 18H3.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M13.5 20C13.5 20.8284 12.8284 21.5 12 21.5M10.5 20C10.5 20.8284 11.1716 21.5 12 21.5M12 21.5V20', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
    ],
  );
  static const bold = IconData(
    'bold',
    shapes: [
      IconShape('path', {'fill-rule': 'evenodd', 'clip-rule': 'evenodd', 'd': 'M5 6C5 4.58579 5 3.87868 5.43934 3.43934C5.87868 3 6.58579 3 8 3H12.5789C15.0206 3 17 5.01472 17 7.5C17 9.98528 15.0206 12 12.5789 12H5V6Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12.4286 12H13.6667C16.0599 12 18 14.0147 18 16.5C18 18.9853 16.0599 21 13.6667 21H8C6.58579 21 5.87868 21 5.43934 20.5607C5 20.1213 5 19.4142 5 18V12', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const book = IconData(
    'book',
    shapes: [
      IconShape('path', {'d': 'M15.5 7H8.5M12.499 11H8.49902', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M20 22H6C4.89543 22 4 21.1046 4 20M4 20C4 18.8954 4.89543 18 6 18H20V6C20 4.11438 20 3.17157 19.4142 2.58579C18.8284 2 17.8856 2 16 2H10C7.17157 2 5.75736 2 4.87868 2.87868C4 3.75736 4 5.17157 4 8V20Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M19.5 18C19.5 18 18.5 18.7628 18.5 20C18.5 21.2372 19.5 22 19.5 22', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const bookmark = IconData(
    'bookmark',
    shapes: [
      IconShape('path', {'d': 'M4 17.9808V9.70753C4 6.07416 4 4.25748 5.17157 3.12874C6.34315 2 8.22876 2 12 2C15.7712 2 17.6569 2 18.8284 3.12874C20 4.25748 20 6.07416 20 9.70753V17.9808C20 20.2867 20 21.4396 19.2272 21.8523C17.7305 22.6514 14.9232 19.9852 13.59 19.1824C12.8168 18.7168 12.4302 18.484 12 18.484C11.5698 18.484 11.1832 18.7168 10.41 19.1824C9.0768 19.9852 6.26947 22.6514 4.77285 21.8523C4 21.4396 4 20.2867 4 17.9808Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const box = IconData(
    'box',
    shapes: [
      IconShape('path', {'d': 'M12 22C11.1818 22 10.4002 21.6698 8.83693 21.0095C4.94564 19.3657 3 18.5438 3 17.1613C3 16.7742 3 10.0645 3 7M12 22C12.8182 22 13.5998 21.6698 15.1631 21.0095C19.0544 19.3657 21 18.5438 21 17.1613V7M12 22L12 11.3548', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M8.32592 9.69138L5.40472 8.27785C3.80157 7.5021 3 7.11423 3 6.5C3 5.88577 3.80157 5.4979 5.40472 4.72215L8.32592 3.30862C10.1288 2.43621 11.0303 2 12 2C12.9697 2 13.8712 2.4362 15.6741 3.30862L18.5953 4.72215C20.1984 5.4979 21 5.88577 21 6.5C21 7.11423 20.1984 7.5021 18.5953 8.27785L15.6741 9.69138C13.8712 10.5638 12.9697 11 12 11C11.0303 11 10.1288 10.5638 8.32592 9.69138Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M6 12L8 13', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M17 4L7 9', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const briefcase = IconData(
    'briefcase',
    shapes: [
      IconShape('path', {'d': 'M2.00127 8.5L1.99911 13.997C1.99782 17.2979 1.99717 18.9484 3.02235 19.974C4.04754 20.9996 5.69801 20.9996 8.99895 20.9997L15 20.9998C18.2994 20.9999 19.949 21 20.9741 19.9751C21.9992 18.9502 21.9996 17.3005 22.0002 14.0012L22.0013 8.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M8.49857 6.5C8.49857 5.09554 8.49857 4.39331 8.83563 3.88886C8.98154 3.67048 9.16904 3.48298 9.38743 3.33706C9.89187 3 10.5941 3 11.9986 3C13.403 3 14.1053 3 14.6097 3.33706C14.8281 3.48298 15.0156 3.67048 15.1615 3.88886C15.4986 4.39331 15.4986 5.09554 15.4986 6.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M19.998 6.50016L3.99885 6.5C2.8944 6.50007 1.99876 7.39568 1.99866 8.50013C1.99876 10.7091 3.79005 12.5004 5.99901 12.5006H17.9978C20.2068 12.5005 21.998 10.7093 21.9981 8.5003C21.998 7.39582 21.1024 6.50023 19.998 6.50016Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M9.99857 12.5V13.5C9.99857 13.965 9.99857 14.1975 10.0497 14.3882C10.1884 14.9059 10.5927 15.3102 11.1103 15.4489C11.3011 15.5 11.5336 15.5 11.9986 15.5C12.4636 15.5 12.696 15.5 12.8868 15.4489C13.4044 15.3102 13.8088 14.9059 13.9475 14.3882C13.9986 14.1975 13.9986 13.965 13.9986 13.5V12.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const calendar = IconData(
    'calendar',
    shapes: [
      IconShape('path', {'d': 'M16 2V6M8 2V6', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M13 4H11C7.22876 4 5.34315 4 4.17157 5.17157C3 6.34315 3 8.22876 3 12V14C3 17.7712 3 19.6569 4.17157 20.8284C5.34315 22 7.22876 22 11 22H13C16.7712 22 18.6569 22 19.8284 20.8284C21 19.6569 21 17.7712 21 14V12C21 8.22876 21 6.34315 19.8284 5.17157C18.6569 4 16.7712 4 13 4Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M3 10H21', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12.1258 14H12.0008M12.1258 18H12.0008M7.625 14H7.5M7.625 18H7.5M16.625 14H16.5M12.2508 14C12.2508 14.1381 12.1389 14.25 12.0008 14.25C11.8628 14.25 11.7508 14.1381 11.7508 14C11.7508 13.8619 11.8628 13.75 12.0008 13.75C12.1389 13.75 12.2508 13.8619 12.2508 14ZM12.2508 18C12.2508 18.1381 12.1389 18.25 12.0008 18.25C11.8628 18.25 11.7508 18.1381 11.7508 18C11.7508 17.8619 11.8628 17.75 12.0008 17.75C12.1389 17.75 12.2508 17.8619 12.2508 18ZM7.75 14C7.75 14.1381 7.63807 14.25 7.5 14.25C7.36193 14.25 7.25 14.1381 7.25 14C7.25 13.8619 7.36193 13.75 7.5 13.75C7.63807 13.75 7.75 13.8619 7.75 14ZM7.75 18C7.75 18.1381 7.63807 18.25 7.5 18.25C7.36193 18.25 7.25 18.1381 7.25 18C7.25 17.8619 7.36193 17.75 7.5 17.75C7.63807 17.75 7.75 17.8619 7.75 18ZM16.75 14C16.75 14.1381 16.6381 14.25 16.5 14.25C16.3619 14.25 16.25 14.1381 16.25 14C16.25 13.8619 16.3619 13.75 16.5 13.75C16.6381 13.75 16.75 13.8619 16.75 14Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const camera = IconData(
    'camera',
    shapes: [
      IconShape('path', {'d': 'M12.6974 3.5H11.303C10.5884 3.5 10.2311 3.5 9.91067 3.612C9.71499 3.68039 9.53113 3.77879 9.36568 3.90367C9.09474 4.10816 8.89655 4.40544 8.50018 5L8.50017 5.00001C8.29717 5.30453 7.99794 5.75337 7.87867 5.87871C7.58314 6.18927 7.19563 6.39666 6.77329 6.47029C6.60284 6.5 6.41985 6.5 6.05387 6.5C5.07379 6.5 4.58376 6.5 4.18307 6.61342C3.18074 6.89716 2.39734 7.68055 2.1136 8.68289C2.00018 9.08357 2.00018 9.57361 2.00018 10.5537V14.5C2.00018 17.3284 2.00018 18.7426 2.87886 19.6213C3.75754 20.5 5.17176 20.5 8.00018 20.5H16.0002C18.8286 20.5 20.2428 20.5 21.1215 19.6213C22.0002 18.7426 22.0002 17.3284 22.0002 14.5V10.5537C22.0002 9.57361 22.0002 9.08357 21.8868 8.68289C21.603 7.68055 20.8196 6.89716 19.8173 6.61342C19.4166 6.5 18.9266 6.5 17.9465 6.5C17.5805 6.5 17.3975 6.5 17.2271 6.47029C16.8047 6.39666 16.4172 6.18927 16.1217 5.87871C16.0024 5.75336 15.7032 5.30451 15.5002 5C15.1038 4.40544 14.9056 4.10816 14.6347 3.90367C14.4692 3.77879 14.2854 3.68039 14.0897 3.612C13.7693 3.5 13.412 3.5 12.6974 3.5Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M16.0002 13C16.0002 15.2091 14.2093 17 12.0002 17C9.79104 17 8.00018 15.2091 8.00018 13C8.00018 10.7909 9.79104 9 12.0002 9C14.2093 9 16.0002 10.7909 16.0002 13Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M19.1252 9.5H19.0002M19.2502 9.5C19.2502 9.63807 19.1383 9.75 19.0002 9.75C18.8621 9.75 18.7502 9.63807 18.7502 9.5C18.7502 9.36193 18.8621 9.25 19.0002 9.25C19.1383 9.25 19.2502 9.36193 19.2502 9.5Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
    ],
  );
  static const chartBar = IconData(
    'chartBar',
    shapes: [
      IconShape('path', {'d': 'M4 15L4 19', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12 9L12 19', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M22 22L2 22', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M20 13L20 19', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M5.60009 8.79993C5.23521 8.31419 4.6543 8 4 8C2.89543 8 2 8.89543 2 10C2 11.1046 2.89543 12 4 12C5.10457 12 6 11.1046 6 10C6 9.54973 5.8512 9.13421 5.60009 8.79993ZM5.60009 8.79993L10.3999 5.20007M10.3999 5.20007C10.7648 5.68581 11.3457 6 12 6C12.783 6 13.4609 5.55006 13.7892 4.89462M10.3999 5.20007C10.1488 4.86579 10 4.45027 10 4C10 2.89543 10.8954 2 12 2C13.1046 2 14 2.89543 14 4C14 4.32158 13.9241 4.62543 13.7892 4.89462M13.7892 4.89462L18.2108 7.10538M18.2108 7.10538C18.0759 7.37457 18 7.67842 18 8C18 9.10457 18.8954 10 20 10C21.1046 10 22 9.10457 22 8C22 6.89543 21.1046 6 20 6C19.217 6 18.5391 6.44994 18.2108 7.10538Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
    ],
  );
  static const chartLine = IconData(
    'chartLine',
    shapes: [
      IconShape('path', {'d': 'M21 21H10C6.70017 21 5.05025 21 4.02513 19.9749C3 18.9497 3 17.2998 3 14V3', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M5 20C5.43938 16.8438 7.67642 8.7643 10.4282 8.7643C12.3301 8.7643 12.8226 12.6353 14.6864 12.6353C17.8931 12.6353 17.4282 4 21 4', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const check = IconData(
    'check',
    shapes: [
      IconShape('path', {'d': 'M5 14L8.5 17.5L19 6.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const checkCircle = IconData(
    'checkCircle',
    shapes: [
      IconShape('path', {'d': 'M22 12C22 6.47715 17.5228 2 12 2C6.47715 2 2 6.47715 2 12C2 17.5228 6.47715 22 12 22C17.5228 22 22 17.5228 22 12Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('path', {'d': 'M8 12.5L10.5 15L16 9', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const chevronDown = IconData(
    'chevronDown',
    shapes: [
      IconShape('path', {'d': 'M18 9.00005C18 9.00005 13.5811 15 12 15C10.4188 15 6 9 6 9', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const chevronLeft = IconData(
    'chevronLeft',
    shapes: [
      IconShape('path', {'d': 'M15 6C15 6 9.00001 10.4189 9 12C8.99999 13.5812 15 18 15 18', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const chevronRight = IconData(
    'chevronRight',
    shapes: [
      IconShape('path', {'d': 'M9.00005 6C9.00005 6 15 10.4189 15 12C15 13.5812 9 18 9 18', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const chevronUp = IconData(
    'chevronUp',
    shapes: [
      IconShape('path', {'d': 'M17.9998 15C17.9998 15 13.5809 9.00001 11.9998 9C10.4187 8.99999 5.99985 15 5.99985 15', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const circle = IconData(
    'circle',
    shapes: [
      IconShape('circle', {'cx': '12', 'cy': '12', 'r': '10', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
    ],
  );
  static const clipboard = IconData(
    'clipboard',
    shapes: [
      IconShape('path', {'d': 'M17.0235 3.03358L16.0689 2.77924C13.369 2.05986 12.019 1.70018 10.9555 2.31074C9.89196 2.9213 9.53023 4.26367 8.80678 6.94841L7.78366 10.7452C7.0602 13.4299 6.69848 14.7723 7.3125 15.8298C7.92652 16.8874 9.27651 17.247 11.9765 17.9664L12.9311 18.2208C15.631 18.9401 16.981 19.2998 18.0445 18.6893C19.108 18.0787 19.4698 16.7363 20.1932 14.0516L21.2163 10.2548C21.9398 7.57005 22.3015 6.22768 21.6875 5.17016C21.0735 4.11264 19.7235 3.75295 17.0235 3.03358Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('path', {'d': 'M16.8538 7.43306C16.8538 8.24714 16.1901 8.90709 15.3714 8.90709C14.5527 8.90709 13.889 8.24714 13.889 7.43306C13.889 6.61898 14.5527 5.95904 15.3714 5.95904C16.1901 5.95904 16.8538 6.61898 16.8538 7.43306Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('path', {'d': 'M12 20.9463L11.0477 21.2056C8.35403 21.9391 7.00722 22.3059 5.94619 21.6833C4.88517 21.0608 4.52429 19.6921 3.80253 16.9547L2.78182 13.0834C2.06006 10.346 1.69918 8.97731 2.31177 7.89904C2.84167 6.96631 4 7.00027 5.5 7.00015', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
    ],
  );
  static const clock = IconData(
    'clock',
    shapes: [
      IconShape('circle', {'cx': '12', 'cy': '12', 'r': '10', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('path', {'d': 'M12 8V12L14 14', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const close = IconData(
    'close',
    shapes: [
      IconShape('path', {'d': 'M18 6L6.00081 17.9992M17.9992 18L6 6.00085', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const cloud = IconData(
    'cloud',
    shapes: [
      IconShape('path', {'d': 'M17.4776 10.0001C17.485 10 17.4925 10 17.5 10C19.9853 10 22 12.0147 22 14.5C22 16.9853 19.9853 19 17.5 19H7C4.23858 19 2 16.7614 2 14C2 11.4003 3.98398 9.26407 6.52042 9.0227M17.4776 10.0001C17.4924 9.83536 17.5 9.66856 17.5 9.5C17.5 6.46243 15.0376 4 12 4C9.12324 4 6.76233 6.20862 6.52042 9.0227M17.4776 10.0001C17.3753 11.1345 16.9286 12.1696 16.2428 13M6.52042 9.0227C6.67826 9.00768 6.83823 9 7 9C8.12582 9 9.16474 9.37209 10.0005 10', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const code = IconData(
    'code',
    shapes: [
      IconShape('path', {'d': 'M17 8L18.8398 9.85008C19.6133 10.6279 20 11.0168 20 11.5C20 11.9832 19.6133 12.3721 18.8398 13.1499L17 15', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M7 8L5.16019 9.85008C4.38673 10.6279 4 11.0168 4 11.5C4 11.9832 4.38673 12.3721 5.16019 13.1499L7 15', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M14.5 4L9.5 20', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const cog = IconData(
    'cog',
    shapes: [
      IconShape('path', {'d': 'M15.5 12C15.5 13.933 13.933 15.5 12 15.5C10.067 15.5 8.5 13.933 8.5 12C8.5 10.067 10.067 8.5 12 8.5C13.933 8.5 15.5 10.067 15.5 12Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('path', {'d': 'M21.011 14.0965C21.5329 13.9558 21.7939 13.8854 21.8969 13.7508C22 13.6163 22 13.3998 22 12.9669V11.0332C22 10.6003 22 10.3838 21.8969 10.2493C21.7938 10.1147 21.5329 10.0443 21.011 9.90358C19.0606 9.37759 17.8399 7.33851 18.3433 5.40087C18.4817 4.86799 18.5509 4.60156 18.4848 4.44529C18.4187 4.28902 18.2291 4.18134 17.8497 3.96596L16.125 2.98673C15.7528 2.77539 15.5667 2.66972 15.3997 2.69222C15.2326 2.71472 15.0442 2.90273 14.6672 3.27873C13.208 4.73448 10.7936 4.73442 9.33434 3.27864C8.95743 2.90263 8.76898 2.71463 8.60193 2.69212C8.43489 2.66962 8.24877 2.77529 7.87653 2.98663L6.15184 3.96587C5.77253 4.18123 5.58287 4.28891 5.51678 4.44515C5.45068 4.6014 5.51987 4.86787 5.65825 5.4008C6.16137 7.3385 4.93972 9.37763 2.98902 9.9036C2.46712 10.0443 2.20617 10.1147 2.10308 10.2492C2 10.3838 2 10.6003 2 11.0332V12.9669C2 13.3998 2 13.6163 2.10308 13.7508C2.20615 13.8854 2.46711 13.9558 2.98902 14.0965C4.9394 14.6225 6.16008 16.6616 5.65672 18.5992C5.51829 19.1321 5.44907 19.3985 5.51516 19.5548C5.58126 19.7111 5.77092 19.8188 6.15025 20.0341L7.87495 21.0134C8.24721 21.2247 8.43334 21.3304 8.6004 21.3079C8.76746 21.2854 8.95588 21.0973 9.33271 20.7213C10.7927 19.2644 13.2088 19.2643 14.6689 20.7212C15.0457 21.0973 15.2341 21.2853 15.4012 21.3078C15.5682 21.3303 15.7544 21.2246 16.1266 21.0133L17.8513 20.034C18.2307 19.8187 18.4204 19.711 18.4864 19.5547C18.5525 19.3984 18.4833 19.132 18.3448 18.5991C17.8412 16.6616 19.0609 14.6226 21.011 14.0965Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
    ],
  );
  static const component = IconData(
    'component',
    shapes: [
      IconShape('path', {'d': 'M13.6903 19.4567C13.5 18.9973 13.5 18.4149 13.5 17.25C13.5 16.0851 13.5 15.5027 13.6903 15.0433C13.944 14.4307 14.4307 13.944 15.0433 13.6903C15.5027 13.5 16.0851 13.5 17.25 13.5C18.4149 13.5 18.9973 13.5 19.4567 13.6903C20.0693 13.944 20.556 14.4307 20.8097 15.0433C21 15.5027 21 16.0851 21 17.25C21 18.4149 21 18.9973 20.8097 19.4567C20.556 20.0693 20.0693 20.556 19.4567 20.8097C18.9973 21 18.4149 21 17.25 21C16.0851 21 15.5027 21 15.0433 20.8097C14.4307 20.556 13.944 20.0693 13.6903 19.4567Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'square', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M13.6903 8.95671C13.5 8.49728 13.5 7.91485 13.5 6.75C13.5 5.58515 13.5 5.00272 13.6903 4.54329C13.944 3.93072 14.4307 3.44404 15.0433 3.1903C15.5027 3 16.0851 3 17.25 3C18.4149 3 18.9973 3 19.4567 3.1903C20.0693 3.44404 20.556 3.93072 20.8097 4.54329C21 5.00272 21 5.58515 21 6.75C21 7.91485 21 8.49728 20.8097 8.95671C20.556 9.56928 20.0693 10.056 19.4567 10.3097C18.9973 10.5 18.4149 10.5 17.25 10.5C16.0851 10.5 15.5027 10.5 15.0433 10.3097C14.4307 10.056 13.944 9.56928 13.6903 8.95671Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'square', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M3.1903 19.4567C3 18.9973 3 18.4149 3 17.25C3 16.0851 3 15.5027 3.1903 15.0433C3.44404 14.4307 3.93072 13.944 4.54329 13.6903C5.00272 13.5 5.58515 13.5 6.75 13.5C7.91485 13.5 8.49728 13.5 8.95671 13.6903C9.56928 13.944 10.056 14.4307 10.3097 15.0433C10.5 15.5027 10.5 16.0851 10.5 17.25C10.5 18.4149 10.5 18.9973 10.3097 19.4567C10.056 20.0693 9.56928 20.556 8.95671 20.8097C8.49728 21 7.91485 21 6.75 21C5.58515 21 5.00272 21 4.54329 20.8097C3.93072 20.556 3.44404 20.0693 3.1903 19.4567Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'square', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M3.1903 8.95671C3 8.49728 3 7.91485 3 6.75C3 5.58515 3 5.00272 3.1903 4.54329C3.44404 3.93072 3.93072 3.44404 4.54329 3.1903C5.00272 3 5.58515 3 6.75 3C7.91485 3 8.49728 3 8.95671 3.1903C9.56928 3.44404 10.056 3.93072 10.3097 4.54329C10.5 5.00272 10.5 5.58515 10.5 6.75C10.5 7.91485 10.5 8.49728 10.3097 8.95671C10.056 9.56928 9.56928 10.056 8.95671 10.3097C8.49728 10.5 7.91485 10.5 6.75 10.5C5.58515 10.5 5.00272 10.5 4.54329 10.3097C3.93072 10.056 3.44404 9.56928 3.1903 8.95671Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'square', 'stroke-linejoin': 'round'}),
    ],
  );
  static const copy = IconData(
    'copy',
    shapes: [
      IconShape('path', {'d': 'M7.5 14.5C7.5 11.2002 7.5 9.55025 8.52513 8.52513C9.55025 7.5 11.2002 7.5 14.5 7.5C17.7998 7.5 19.4497 7.5 20.4749 8.52513C21.5 9.55025 21.5 11.2002 21.5 14.5C21.5 17.7998 21.5 19.4497 20.4749 20.4749C19.4497 21.5 17.7998 21.5 14.5 21.5C11.2002 21.5 9.55025 21.5 8.52513 20.4749C7.5 19.4497 7.5 17.7998 7.5 14.5Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M7.5 16.5C6.10355 16.5 5.40533 16.5 4.84402 16.3036C3.83866 15.9518 3.0482 15.1613 2.69641 14.156C2.5 13.5947 2.5 12.8964 2.5 11.5V9.5C2.5 6.20017 2.5 4.55025 3.52513 3.52513C4.55025 2.5 6.20017 2.5 9.5 2.5H11.5C12.8964 2.5 13.5947 2.5 14.156 2.69641C15.1613 3.0482 15.9518 3.83866 16.3036 4.84402C16.5 5.40533 16.5 6.10355 16.5 7.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const cpu = IconData(
    'cpu',
    shapes: [
      IconShape('path', {'d': 'M4 12C4 8.22876 4 6.34315 5.17157 5.17157C6.34315 4 8.22876 4 12 4C15.7712 4 17.6569 4 18.8284 5.17157C20 6.34315 20 8.22876 20 12C20 15.7712 20 17.6569 18.8284 18.8284C17.6569 20 15.7712 20 12 20C8.22876 20 6.34315 20 5.17157 18.8284C4 17.6569 4 15.7712 4 12Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M9.5 2V4', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M14.5 2V4', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M9.5 20V22', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M14.5 20V22', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M13 9L9 13', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M15 13L13 15', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M22 14.5L20 14.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M4 9.5L2 9.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M4 14.5L2 14.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M22 9.5L20 9.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const creditCard = IconData(
    'creditCard',
    shapes: [
      IconShape('path', {'d': 'M2 12C2 8.46252 2 6.69377 3.0528 5.5129C3.22119 5.32403 3.40678 5.14935 3.60746 4.99087C4.86213 4 6.74142 4 10.5 4H13.5C17.2586 4 19.1379 4 20.3925 4.99087C20.5932 5.14935 20.7788 5.32403 20.9472 5.5129C22 6.69377 22 8.46252 22 12C22 15.5375 22 17.3062 20.9472 18.4871C20.7788 18.676 20.5932 18.8506 20.3925 19.0091C19.1379 20 17.2586 20 13.5 20H10.5C6.74142 20 4.86213 20 3.60746 19.0091C3.40678 18.8506 3.22119 18.676 3.0528 18.4871C2 17.3062 2 15.5375 2 12Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M10 16H11.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-miterlimit': '10', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M14.5 16L18 16', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-miterlimit': '10', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M2 9H22', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
    ],
  );
  static const database = IconData(
    'database',
    shapes: [
      IconShape('ellipse', {'cx': '12', 'cy': '5', 'rx': '8', 'ry': '3', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('path', {'d': 'M7 10.842C7.60158 11.0229 8.27434 11.1718 9 11.282', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M20 12C20 13.6569 16.4183 15 12 15C7.58172 15 4 13.6569 4 12', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('path', {'d': 'M7 17.842C7.60158 18.0229 8.27434 18.1718 9 18.282', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M20 5V19C20 20.6569 16.4183 22 12 22C7.58172 22 4 20.6569 4 19V5', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
    ],
  );
  static const document = IconData(
    'document',
    shapes: [
      IconShape('path', {'d': 'M8 17H16', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M8 13H12', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M13 2.5V3C13 5.82843 13 7.24264 13.8787 8.12132C14.7574 9 16.1716 9 19 9H19.5M20 10.6569V14C20 17.7712 20 19.6569 18.8284 20.8284C17.6569 22 15.7712 22 12 22C8.22876 22 6.34315 22 5.17157 20.8284C4 19.6569 4 17.7712 4 14V9.45584C4 6.21082 4 4.58831 4.88607 3.48933C5.06508 3.26731 5.26731 3.06508 5.48933 2.88607C6.58831 2 8.21082 2 11.4558 2C12.1614 2 12.5141 2 12.8372 2.11401C12.9044 2.13772 12.9702 2.165 13.0345 2.19575C13.3436 2.34355 13.593 2.593 14.0919 3.09188L18.8284 7.82843C19.4065 8.40649 19.6955 8.69552 19.8478 9.06306C20 9.4306 20 9.83935 20 10.6569Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const download = IconData(
    'download',
    shapes: [
      IconShape('path', {'d': 'M2.99969 17.0002C2.99969 17.9302 2.99969 18.3952 3.10192 18.7767C3.37932 19.8119 4.18796 20.6206 5.22324 20.898C5.60474 21.0002 6.06972 21.0002 6.99969 21.0002L16.9997 21.0002C17.9297 21.0002 18.3947 21.0002 18.7762 20.898C19.8114 20.6206 20.6201 19.8119 20.8975 18.7767C20.9997 18.3952 20.9997 17.9302 20.9997 17.0002', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M16.4998 11.5002C16.4998 11.5002 13.1856 16.0002 11.9997 16.0002C10.8139 16.0002 7.49976 11.5002 7.49976 11.5002M11.9997 15.0002V3.00016', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const edit = IconData(
    'edit',
    shapes: [
      IconShape('path', {'d': 'M14.0737 3.88545C14.8189 3.07808 15.1915 2.6744 15.5874 2.43893C16.5427 1.87076 17.7191 1.85309 18.6904 2.39232C19.0929 2.6158 19.4769 3.00812 20.245 3.79276C21.0131 4.5774 21.3972 4.96972 21.6159 5.38093C22.1438 6.37312 22.1265 7.57479 21.5703 8.5507C21.3398 8.95516 20.9446 9.33578 20.1543 10.097L10.7506 19.1543C9.25288 20.5969 8.504 21.3182 7.56806 21.6837C6.63212 22.0493 5.6032 22.0224 3.54536 21.9686L3.26538 21.9613C2.63891 21.9449 2.32567 21.9367 2.14359 21.73C1.9615 21.5234 1.98636 21.2043 2.03608 20.5662L2.06308 20.2197C2.20301 18.4235 2.27297 17.5255 2.62371 16.7182C2.97444 15.9109 3.57944 15.2555 4.78943 13.9445L14.0737 3.88545Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M13 4L20 11', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M14 22L22 22', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const externalLink = IconData(
    'externalLink',
    shapes: [
      IconShape('path', {'d': 'M11.0991 3.00012C7.45013 3.00669 5.53932 3.09629 4.31817 4.31764C3.00034 5.63568 3.00034 7.75704 3.00034 11.9997C3.00034 16.2424 3.00034 18.3638 4.31817 19.6818C5.63599 20.9999 7.75701 20.9999 11.9991 20.9999C16.241 20.9999 18.3621 20.9999 19.6799 19.6818C20.901 18.4605 20.9906 16.5493 20.9972 12.8998', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M20.556 3.49612L11.0487 13.0586M20.556 3.49612C20.062 3.00151 16.7343 3.04761 16.0308 3.05762M20.556 3.49612C21.05 3.99074 21.0039 7.32273 20.9939 8.02714', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const eye = IconData(
    'eye',
    shapes: [
      IconShape('path', {'d': 'M21.544 11.045C21.848 11.4713 22 11.6845 22 12C22 12.3155 21.848 12.5287 21.544 12.955C20.1779 14.8706 16.6892 19 12 19C7.31078 19 3.8221 14.8706 2.45604 12.955C2.15201 12.5287 2 12.3155 2 12C2 11.6845 2.15201 11.4713 2.45604 11.045C3.8221 9.12944 7.31078 5 12 5C16.6892 5 20.1779 9.12944 21.544 11.045Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('path', {'d': 'M15 12C15 10.3431 13.6569 9 12 9C10.3431 9 9 10.3431 9 12C9 13.6569 10.3431 15 12 15C13.6569 15 15 13.6569 15 12Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
    ],
  );
  static const eyeOff = IconData(
    'eyeOff',
    shapes: [
      IconShape('path', {'d': 'M22 8C22 8 18 14 12 14C6 14 2 8 2 8', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M15 13.5L16.5 16', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M20 11L22 13', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M2 13L4 11', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M9 13.5L7.5 16', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const file = IconData(
    'file',
    shapes: [
      IconShape('path', {'d': 'M8 7L16 7', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M8 11L12 11', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M13 21.5V21C13 18.1716 13 16.7574 13.8787 15.8787C14.7574 15 16.1716 15 19 15H19.5M20 13.3431V10C20 6.22876 20 4.34315 18.8284 3.17157C17.6569 2 15.7712 2 12 2C8.22877 2 6.34315 2 5.17157 3.17157C4 4.34314 4 6.22876 4 10L4 14.5442C4 17.7892 4 19.4117 4.88607 20.5107C5.06508 20.7327 5.26731 20.9349 5.48933 21.1139C6.58831 22 8.21082 22 11.4558 22C12.1614 22 12.5141 22 12.8372 21.886C12.9044 21.8623 12.9702 21.835 13.0345 21.8043C13.3436 21.6564 13.593 21.407 14.0919 20.9081L18.8284 16.1716C19.4065 15.5935 19.6955 15.3045 19.8478 14.9369C20 14.5694 20 14.1606 20 13.3431Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const filter = IconData(
    'filter',
    shapes: [
      IconShape('path', {'d': 'M8.85746 12.5061C6.36901 10.6456 4.59564 8.59915 3.62734 7.44867C3.3276 7.09253 3.22938 6.8319 3.17033 6.3728C2.96811 4.8008 2.86701 4.0148 3.32795 3.5074C3.7889 3 4.60404 3 6.23433 3H17.7657C19.396 3 20.2111 3 20.672 3.5074C21.133 4.0148 21.0319 4.8008 20.8297 6.37281C20.7706 6.83191 20.6724 7.09254 20.3726 7.44867C19.403 8.60062 17.6261 10.6507 15.1326 12.5135C14.907 12.6821 14.7583 12.9567 14.7307 13.2614C14.4837 15.992 14.2559 17.4876 14.1141 18.2442C13.8853 19.4657 12.1532 20.2006 11.226 20.8563C10.6741 21.2466 10.0043 20.782 9.93278 20.1778C9.79643 19.0261 9.53961 16.6864 9.25927 13.2614C9.23409 12.9539 9.08486 12.6761 8.85746 12.5061Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const folder = IconData(
    'folder',
    shapes: [
      IconShape('path', {'d': 'M8 7H16.75C18.8567 7 19.91 7 20.6667 7.50559C20.9943 7.72447 21.2755 8.00572 21.4944 8.33329C22 9.08996 22 10.1433 22 12.25C22 15.7612 22 17.5167 21.1573 18.7779C20.7926 19.3238 20.3238 19.7926 19.7779 20.1573C18.5167 21 16.7612 21 13.25 21H12C7.28595 21 4.92893 21 3.46447 19.5355C2 18.0711 2 15.714 2 11V7.94427C2 6.1278 2 5.21956 2.38032 4.53806C2.65142 4.05227 3.05227 3.65142 3.53806 3.38032C4.21956 3 5.1278 3 6.94427 3C8.10802 3 8.6899 3 9.19926 3.19101C10.3622 3.62712 10.8418 4.68358 11.3666 5.73313L12 7', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
    ],
  );
  static const gauge = IconData(
    'gauge',
    shapes: [
      IconShape('path', {'d': 'M13.5 13L17 9M14 15C14 16.1046 13.1046 17 12 17C10.8954 17 10 16.1046 10 15C10 13.8954 10.8954 13 12 13C13.1046 13 14 13.8954 14 15Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M6 12C6 8.68629 8.68629 6 12 6C13.0929 6 14.1175 6.29218 15 6.80269', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M2.50006 12.0001C2.50006 7.52172 2.50006 5.28255 3.8913 3.8913C5.28255 2.50006 7.52172 2.50006 12.0001 2.50006C16.4784 2.50006 18.7176 2.50006 20.1088 3.8913C21.5001 5.28255 21.5001 7.52172 21.5001 12.0001C21.5001 16.4784 21.5001 18.7176 20.1088 20.1088C18.7176 21.5001 16.4784 21.5001 12.0001 21.5001C7.52172 21.5001 5.28255 21.5001 3.8913 20.1088C2.50006 18.7176 2.50006 16.4784 2.50006 12.0001Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
    ],
  );
  static const gitBranch = IconData(
    'gitBranch',
    shapes: [
      IconShape('path', {'d': 'M7 19H13C15.8284 19 17.2426 19 18.1213 18.1213C19 17.2426 19 15.8284 19 13V10M19 10C19.7002 10 21.0085 11.9943 21.5 12.5M19 10C18.2998 10 16.9915 11.9943 16.5 12.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M5 7L5 17', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('circle', {'cx': '5', 'cy': '5', 'r': '2', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('circle', {'cx': '19', 'cy': '5', 'r': '2', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('circle', {'cx': '5', 'cy': '19', 'r': '2', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
    ],
  );
  static const globe = IconData(
    'globe',
    shapes: [
      IconShape('circle', {'cx': '12', 'cy': '12', 'r': '10', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('path', {'d': 'M8 12C8 18 12 22 12 22C12 22 16 18 16 12C16 6 12 2 12 2C12 2 8 6 8 12Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M21 15H3', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M21 9H3', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const grid = IconData(
    'grid',
    shapes: [
      IconShape('path', {'d': 'M3.88884 9.66294C4.39329 10 5.09552 10 6.49998 10C7.90445 10 8.60668 10 9.11113 9.66294C9.32951 9.51702 9.51701 9.32952 9.66292 9.11114C9.99998 8.60669 9.99998 7.90446 9.99998 6.5C9.99998 5.09554 9.99998 4.39331 9.66292 3.88886C9.51701 3.67048 9.32951 3.48298 9.11113 3.33706C8.60668 3 7.90445 3 6.49998 3C5.09552 3 4.39329 3 3.88884 3.33706C3.67046 3.48298 3.48296 3.67048 3.33705 3.88886C2.99998 4.39331 2.99998 5.09554 2.99998 6.5C2.99998 7.90446 2.99998 8.60669 3.33705 9.11114C3.48296 9.32952 3.67046 9.51702 3.88884 9.66294Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M14.8888 9.66294C15.3933 10 16.0955 10 17.5 10C18.9044 10 19.6067 10 20.1111 9.66294C20.3295 9.51702 20.517 9.32952 20.6629 9.11114C21 8.60669 21 7.90446 21 6.5C21 5.09554 21 4.39331 20.6629 3.88886C20.517 3.67048 20.3295 3.48298 20.1111 3.33706C19.6067 3 18.9044 3 17.5 3C16.0955 3 15.3933 3 14.8888 3.33706C14.6705 3.48298 14.483 3.67048 14.337 3.88886C14 4.39331 14 5.09554 14 6.5C14 7.90446 14 8.60669 14.337 9.11114C14.483 9.32952 14.6705 9.51702 14.8888 9.66294Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M3.88884 20.6629C4.39329 21 5.09552 21 6.49998 21C7.90445 21 8.60668 21 9.11113 20.6629C9.32951 20.517 9.51701 20.3295 9.66292 20.1111C9.99998 19.6067 9.99998 18.9045 9.99998 17.5C9.99998 16.0955 9.99998 15.3933 9.66292 14.8889C9.51701 14.6705 9.32951 14.483 9.11113 14.3371C8.60668 14 7.90445 14 6.49998 14C5.09552 14 4.39329 14 3.88884 14.3371C3.67046 14.483 3.48296 14.6705 3.33705 14.8889C2.99998 15.3933 2.99998 16.0955 2.99998 17.5C2.99998 18.9045 2.99998 19.6067 3.33705 20.1111C3.48296 20.3295 3.67046 20.517 3.88884 20.6629Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M14.8888 20.6629C15.3933 21 16.0955 21 17.5 21C18.9044 21 19.6067 21 20.1111 20.6629C20.3295 20.517 20.517 20.3295 20.6629 20.1111C21 19.6067 21 18.9045 21 17.5C21 16.0955 21 15.3933 20.6629 14.8889C20.517 14.6705 20.3295 14.483 20.1111 14.3371C19.6067 14 18.9044 14 17.5 14C16.0955 14 15.3933 14 14.8888 14.3371C14.6705 14.483 14.483 14.6705 14.337 14.8889C14 15.3933 14 16.0955 14 17.5C14 18.9045 14 19.6067 14.337 20.1111C14.483 20.3295 14.6705 20.517 14.8888 20.6629Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
    ],
  );
  static const hardDrive = IconData(
    'hardDrive',
    shapes: [
      IconShape('path', {'d': 'M20.7104 8.70122L21.9186 12.7288C21.9578 12.8592 21.9773 12.9244 21.9879 12.9914L21.9908 13.0118C22 13.079 22 13.147 22 13.2831C22 16.7797 22 18.528 20.9812 19.6669C20.8824 19.7774 20.7774 19.8824 20.6669 19.9812C19.528 21 17.7797 21 14.2831 21H9.71685C6.22026 21 4.47197 21 3.33311 19.9812C3.22259 19.8824 3.11765 19.7774 3.01877 19.6669C2 18.528 2 16.7797 2 13.2831C2 13.147 2 13.079 2.00915 13.0118L2.01215 12.9914C2.02269 12.9244 2.04225 12.8592 2.08136 12.7288L3.28963 8.70122C4.11355 5.95484 4.5255 4.58166 5.5884 3.79083C6.6513 3 8.08495 3 10.9522 3H13.0478C15.9151 3 17.3487 3 18.4116 3.79083C19.4745 4.58166 19.8865 5.95484 20.7104 8.70122Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M2 13H22', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M18.125 17H18M14.125 17H14M18.25 17C18.25 17.1381 18.1381 17.25 18 17.25C17.8619 17.25 17.75 17.1381 17.75 17C17.75 16.8619 17.8619 16.75 18 16.75C18.1381 16.75 18.25 16.8619 18.25 17ZM14.25 17C14.25 17.1381 14.1381 17.25 14 17.25C13.8619 17.25 13.75 17.1381 13.75 17C13.75 16.8619 13.8619 16.75 14 16.75C14.1381 16.75 14.25 16.8619 14.25 17Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const headphones = IconData(
    'headphones',
    shapes: [
      IconShape('path', {'d': 'M20.0849 17C20.5849 15.5 21 13.4368 21 12C21 7.02944 16.9706 3 12 3C7.02944 3 3 7.02944 3 12C3 13.4368 3.41512 15.5 3.91512 17', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M8.97651 19.6043L7.23857 14.6127C7.05341 14.1466 6.4617 13.9131 5.97493 14.0297C4.46441 14.5333 3.6462 16.1718 4.14742 17.6895L4.58543 19.0158C5.08664 20.5334 6.71747 21.3555 8.22799 20.8519C8.68896 20.6556 9.10449 20.0897 8.97651 19.6043Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M15.0235 19.6043L16.7614 14.6127C16.9466 14.1466 17.5383 13.9131 18.0251 14.0297C19.5356 14.5333 20.3538 16.1718 19.8526 17.6895L19.4146 19.0158C18.9134 20.5334 17.2825 21.3555 15.772 20.8519C15.311 20.6556 14.8955 20.0897 15.0235 19.6043Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const heart = IconData(
    'heart',
    shapes: [
      IconShape('path', {'d': 'M10.4107 19.9677C7.58942 17.858 2 13.0348 2 8.69444C2 5.82563 4.10526 3.5 7 3.5C8.5 3.5 10 4 12 6C14 4 15.5 3.5 17 3.5C19.8947 3.5 22 5.82563 22 8.69444C22 13.0348 16.4106 17.858 13.5893 19.9677C12.6399 20.6776 11.3601 20.6776 10.4107 19.9677Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const helpCircle = IconData(
    'helpCircle',
    shapes: [
      IconShape('circle', {'cx': '12', 'cy': '12', 'r': '10', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M9.5 9.5C9.5 8.11929 10.6193 7 12 7C13.3807 7 14.5 8.11929 14.5 9.5C14.5 10.3569 14.0689 11.1131 13.4117 11.5636C12.7283 12.0319 12 12.6716 12 13.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12.125 16.75H12M12.25 16.75C12.25 16.8881 12.1381 17 12 17C11.8619 17 11.75 16.8881 11.75 16.75C11.75 16.6119 11.8619 16.5 12 16.5C12.1381 16.5 12.25 16.6119 12.25 16.75Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const home = IconData(
    'home',
    shapes: [
      IconShape('path', {'d': 'M3 11.9896V14.5C3 17.7998 3 19.4497 4.02513 20.4749C5.05025 21.5 6.70017 21.5 10 21.5H14C17.2998 21.5 18.9497 21.5 19.9749 20.4749C21 19.4497 21 17.7998 21 14.5V11.9896C21 10.3083 21 9.46773 20.6441 8.74005C20.2882 8.01237 19.6247 7.49628 18.2976 6.46411L16.2976 4.90855C14.2331 3.30285 13.2009 2.5 12 2.5C10.7991 2.5 9.76689 3.30285 7.70242 4.90855L5.70241 6.46411C4.37533 7.49628 3.71179 8.01237 3.3559 8.74005C3 9.46773 3 10.3083 3 11.9896Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const image = IconData(
    'image',
    shapes: [
      IconShape('circle', {'cx': '7.5', 'cy': '7.5', 'r': '1.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M2.5 12C2.5 7.52166 2.5 5.28249 3.89124 3.89124C5.28249 2.5 7.52166 2.5 12 2.5C16.4783 2.5 18.7175 2.5 20.1088 3.89124C21.5 5.28249 21.5 7.52166 21.5 12C21.5 16.4783 21.5 18.7175 20.1088 20.1088C18.7175 21.5 16.4783 21.5 12 21.5C7.52166 21.5 5.28249 21.5 3.89124 20.1088C2.5 18.7175 2.5 16.4783 2.5 12Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('path', {'d': 'M5 21C9.37246 15.775 14.2741 8.88406 21.4975 13.5424', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
    ],
  );
  static const inbox = IconData(
    'inbox',
    shapes: [
      IconShape('path', {'d': 'M2.5 12C2.5 7.52166 2.5 5.28249 3.89124 3.89124C5.28249 2.5 7.52166 2.5 12 2.5C16.4783 2.5 18.7175 2.5 20.1088 3.89124C21.5 5.28249 21.5 7.52166 21.5 12C21.5 16.4783 21.5 18.7175 20.1088 20.1088C18.7175 21.5 16.4783 21.5 12 21.5C7.52166 21.5 5.28249 21.5 3.89124 20.1088C2.5 18.7175 2.5 16.4783 2.5 12Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M21.5 13.5H16.5743C15.7322 13.5 15.0706 14.2036 14.6995 14.9472C14.2963 15.7551 13.4889 16.5 12 16.5C10.5111 16.5 9.70373 15.7551 9.30054 14.9472C8.92942 14.2036 8.26777 13.5 7.42566 13.5H2.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
    ],
  );
  static const info = IconData(
    'info',
    shapes: [
      IconShape('circle', {'cx': '12', 'cy': '12', 'r': '10', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12 16V12', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12.125 8.25H12M12.25 8.25C12.25 8.11193 12.1381 8 12 8C11.8619 8 11.75 8.11193 11.75 8.25C11.75 8.38807 11.8619 8.5 12 8.5C12.1381 8.5 12.25 8.38807 12.25 8.25Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const key = IconData(
    'key',
    shapes: [
      IconShape('path', {'d': 'M15.5 14.5C18.8137 14.5 21.5 11.8137 21.5 8.5C21.5 5.18629 18.8137 2.5 15.5 2.5C12.1863 2.5 9.5 5.18629 9.5 8.5C9.5 9.38041 9.68962 10.2165 10.0303 10.9697L2.5 18.5V21.5H5.5V19.5H7.5V17.5H9.5L13.0303 13.9697C13.7835 14.3104 14.6196 14.5 15.5 14.5Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M17.5 6.5L16.5 7.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const laptop = IconData(
    'laptop',
    shapes: [
      IconShape('path', {'d': 'M20.4999 16.5V8.5C20.4999 6.14298 20.4999 4.96447 19.7676 4.23223C19.0354 3.5 17.8569 3.5 15.4999 3.5H8.49988C6.14286 3.5 4.96434 3.5 4.23211 4.23223C3.49988 4.96447 3.49988 6.14298 3.49988 8.5V16.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M21.9841 20.5H2.01567C1.63273 20.5 1.38367 20.1088 1.55493 19.7764L3.49988 16.5H20.4999L22.4448 19.7764C22.6161 20.1088 22.367 20.5 21.9841 20.5Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const layers = IconData(
    'layers',
    shapes: [
      IconShape('path', {'d': 'M8.64298 3.14559L6.93816 3.93362C4.31272 5.14719 3 5.75397 3 6.75C3 7.74603 4.31272 8.35281 6.93817 9.56638L8.64298 10.3544C10.2952 11.1181 11.1214 11.5 12 11.5C12.8786 11.5 13.7048 11.1181 15.357 10.3544L17.0618 9.56638C19.6873 8.35281 21 7.74603 21 6.75C21 5.75397 19.6873 5.14719 17.0618 3.93362L15.357 3.14559C13.7048 2.38186 12.8786 2 12 2C11.1214 2 10.2952 2.38186 8.64298 3.14559Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M20.788 11.0972C20.9293 11.2959 21 11.5031 21 11.7309C21 12.7127 19.6873 13.3109 17.0618 14.5072L15.357 15.284C13.7048 16.0368 12.8786 16.4133 12 16.4133C11.1214 16.4133 10.2952 16.0368 8.64298 15.284L6.93817 14.5072C4.31272 13.3109 3 12.7127 3 11.7309C3 11.5031 3.07067 11.2959 3.212 11.0972', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M20.3767 16.2661C20.7922 16.5971 21 16.927 21 17.3176C21 18.2995 19.6873 18.8976 17.0618 20.0939L15.357 20.8707C13.7048 21.6236 12.8786 22 12 22C11.1214 22 10.2952 21.6236 8.64298 20.8707L6.93817 20.0939C4.31272 18.8976 3 18.2995 3 17.3176C3 16.927 3.20778 16.5971 3.62334 16.2661', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const layout = IconData(
    'layout',
    shapes: [
      IconShape('path', {'d': 'M3.89124 20.1088C2.5 18.7175 2.5 16.4783 2.5 12C2.5 7.52166 2.5 5.28249 3.89124 3.89124C5.28248 2.5 7.52166 2.5 12 2.5C16.4783 2.5 18.7175 2.5 20.1088 3.89124C21.5 5.28248 21.5 7.52166 21.5 12C21.5 16.4783 21.5 18.7175 20.1088 20.1088C18.7175 21.5 16.4783 21.5 12 21.5C7.52166 21.5 5.28249 21.5 3.89124 20.1088Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M2.5 9L21.5 9', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('path', {'d': 'M8 21.5L8 9', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
    ],
  );
  static const lifeBuoy = IconData(
    'lifeBuoy',
    shapes: [
      IconShape('path', {'d': 'M21 12C21 16.9706 16.9706 21 12 21C7.02944 21 3 16.9706 3 12C3 7.02944 7.02944 3 12 3C16.9706 3 21 7.02944 21 12Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M17 12C17 14.7614 14.7614 17 12 17C9.23858 17 7 14.7614 7 12C7 9.23858 9.23858 7 12 7C14.7614 7 17 9.23858 17 12Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12 7V3M12 17V21M17 12H21M7 12H3', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M14.8965 3.47625C15.63 2.57541 16.7478 2 18 2C20.2091 2 22 3.79086 22 6C22 7.25222 21.4246 8.37005 20.5238 9.1035M20.5238 14.8965C21.4246 15.63 22 16.7478 22 18C22 20.2091 20.2091 22 18 22C16.7478 22 15.63 21.4246 14.8965 20.5238M9.1035 20.5238C8.37005 21.4246 7.25222 22 6 22C3.79086 22 2 20.2091 2 18C2 16.7478 2.57541 15.63 3.47625 14.8965M3.47625 9.1035C2.57541 8.37005 2 7.25222 2 6C2 3.79086 3.79086 2 6 2C7.25222 2 8.37005 2.57541 9.1035 3.47625', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const link = IconData(
    'link',
    shapes: [
      IconShape('path', {'d': 'M9.14339 10.691L9.35031 10.4841C11.329 8.50532 14.5372 8.50532 16.5159 10.4841C18.4947 12.4628 18.4947 15.671 16.5159 17.6497L13.6497 20.5159C11.671 22.4947 8.46279 22.4947 6.48405 20.5159C4.50532 18.5372 4.50532 15.329 6.48405 13.3503L6.9484 12.886', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M17.0516 11.114L17.5159 10.6497C19.4947 8.67095 19.4947 5.46279 17.5159 3.48405C15.5372 1.50532 12.329 1.50532 10.3503 3.48405L7.48405 6.35031C5.50532 8.32904 5.50532 11.5372 7.48405 13.5159C9.46279 15.4947 12.671 15.4947 14.6497 13.5159L14.8566 13.309', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
    ],
  );
  static const list = IconData(
    'list',
    shapes: [
      IconShape('path', {'d': 'M2 11.4C2 10.2417 2.24173 10 3.4 10H20.6C21.7583 10 22 10.2417 22 11.4V12.6C22 13.7583 21.7583 14 20.6 14H3.4C2.24173 14 2 13.7583 2 12.6V11.4Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M2 3.4C2 2.24173 2.24173 2 3.4 2H20.6C21.7583 2 22 2.24173 22 3.4V4.6C22 5.75827 21.7583 6 20.6 6H3.4C2.24173 6 2 5.75827 2 4.6V3.4Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M2 19.4C2 18.2417 2.24173 18 3.4 18H20.6C21.7583 18 22 18.2417 22 19.4V20.6C22 21.7583 21.7583 22 20.6 22H3.4C2.24173 22 2 21.7583 2 20.6V19.4Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
    ],
  );
  static const loader = IconData(
    'loader',
    shapes: [
      IconShape('path', {'d': 'M12 3V6', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M12 18V21', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M21 12L18 12', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M6 12L3 12', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M18.3635 5.63672L16.2422 7.75804', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M7.75804 16.2422L5.63672 18.3635', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M18.3635 18.3635L16.2422 16.2422', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M7.75804 7.75804L5.63672 5.63672', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
    ],
  );
  static const lock = IconData(
    'lock',
    shapes: [
      IconShape('path', {'d': 'M22 12C22 17.5228 17.5228 22 12 22C6.47715 22 2 17.5228 2 12C2 6.47715 6.47715 2 12 2C17.5228 2 22 6.47715 22 12Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('path', {'d': 'M12 13C13.1046 13 14 12.1046 14 11C14 9.89543 13.1046 9 12 9C10.8954 9 10 9.89543 10 11C10 12.1046 10.8954 13 12 13ZM12 13L12 16', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
    ],
  );
  static const logIn = IconData(
    'logIn',
    shapes: [
      IconShape('path', {'d': 'M8.00002 8C8.00002 7.42459 8.00002 7.17765 8.04465 6.92457C8.21993 5.93047 8.89355 5.09255 9.83302 4.70001C10.0723 4.60003 10.3559 4.53526 10.9232 4.40573L13.6508 3.78286C17.0405 3.00882 18.7353 2.6218 19.8677 3.51317C21 4.40454 21 6.1257 21 9.56803L21 14.432C21 17.8743 21 19.5955 19.8676 20.4868C18.7353 21.3782 17.0405 20.9912 13.6508 20.2171L10.9232 19.5943C10.3559 19.4647 10.0723 19.4 9.833 19.3C8.89353 18.9074 8.21991 18.0695 8.04462 17.0754C8 16.8224 8 16.5754 8 16', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M13 9C13 9 16 11.2095 16 12C16 12.7906 13 15 13 15M15.5 12H3', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const logOut = IconData(
    'logOut',
    shapes: [
      IconShape('path', {'d': 'M15.5 8.04045C15.4588 6.87972 15.3216 6.15451 14.8645 5.58671C14.2114 4.77536 13.0944 4.52064 10.8605 4.01121L9.85915 3.78286C6.4649 3.00882 4.76777 2.6218 3.63388 3.51317C2.5 4.40454 2.5 6.1257 2.5 9.56803V14.432C2.5 17.8743 2.5 19.5955 3.63388 20.4868C4.76777 21.3782 6.4649 20.9912 9.85915 20.2171L10.8605 19.9888C13.0944 19.4794 14.2114 19.2246 14.8645 18.4133C15.3216 17.8455 15.4588 17.1203 15.5 15.9595', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M18.5 9.01172C18.5 9.01172 21.5 11.2212 21.5 12.0117C21.5 12.8023 18.5 15.0117 18.5 15.0117M21 12.0117H8.49998', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const mail = IconData(
    'mail',
    shapes: [
      IconShape('path', {'d': 'M2 6L8.91302 9.91697C11.4616 11.361 12.5384 11.361 15.087 9.91697L22 6', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M2.01577 13.4756C2.08114 16.5412 2.11383 18.0739 3.24496 19.2094C4.37608 20.3448 5.95033 20.3843 9.09883 20.4634C11.0393 20.5122 12.9607 20.5122 14.9012 20.4634C18.0497 20.3843 19.6239 20.3448 20.7551 19.2094C21.8862 18.0739 21.9189 16.5412 21.9842 13.4756C22.0053 12.4899 22.0053 11.5101 21.9842 10.5244C21.9189 7.45886 21.8862 5.92609 20.7551 4.79066C19.6239 3.65523 18.0497 3.61568 14.9012 3.53657C12.9607 3.48781 11.0393 3.48781 9.09882 3.53656C5.95033 3.61566 4.37608 3.65521 3.24495 4.79065C2.11382 5.92608 2.08114 7.45885 2.01576 10.5244C1.99474 11.5101 1.99475 12.4899 2.01577 13.4756Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
    ],
  );
  static const mapPin = IconData(
    'mapPin',
    shapes: [
      IconShape('path', {'d': 'M13.6177 21.367C13.1841 21.773 12.6044 22 12.0011 22C11.3978 22 10.8182 21.773 10.3845 21.367C6.41302 17.626 1.09076 13.4469 3.68627 7.37966C5.08963 4.09916 8.45834 2 12.0011 2C15.5439 2 18.9126 4.09916 20.316 7.37966C22.9082 13.4393 17.599 17.6389 13.6177 21.367Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('path', {'d': 'M15.5 11C15.5 12.933 13.933 14.5 12 14.5C10.067 14.5 8.5 12.933 8.5 11C8.5 9.067 10.067 7.5 12 7.5C13.933 7.5 15.5 9.067 15.5 11Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
    ],
  );
  static const menu = IconData(
    'menu',
    shapes: [
      IconShape('path', {'d': 'M4 5L20 5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M4 12L20 12', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M4 19L20 19', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const message = IconData(
    'message',
    shapes: [
      IconShape('path', {'d': 'M8.5 14.5H15.5M8.5 9.5H12', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M14.1706 20.8905C18.3536 20.6125 21.6856 17.2332 21.9598 12.9909C22.0134 12.1607 22.0134 11.3009 21.9598 10.4707C21.6856 6.22838 18.3536 2.84913 14.1706 2.57107C12.7435 2.47621 11.2536 2.47641 9.8294 2.57107C5.64639 2.84913 2.31441 6.22838 2.04024 10.4707C1.98659 11.3009 1.98659 12.1607 2.04024 12.9909C2.1401 14.536 2.82343 15.9666 3.62791 17.1746C4.09501 18.0203 3.78674 19.0758 3.30021 19.9978C2.94941 20.6626 2.77401 20.995 2.91484 21.2351C3.05568 21.4752 3.37026 21.4829 3.99943 21.4982C5.24367 21.5285 6.08268 21.1757 6.74868 20.6846C7.1264 20.4061 7.31527 20.2668 7.44544 20.2508C7.5756 20.2348 7.83177 20.3403 8.34401 20.5513C8.8044 20.7409 9.33896 20.8579 9.8294 20.8905C11.2536 20.9852 12.7435 20.9854 14.1706 20.8905Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
    ],
  );
  static const minus = IconData(
    'minus',
    shapes: [
      IconShape('path', {'d': 'M20 12L4 12', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const monitor = IconData(
    'monitor',
    shapes: [
      IconShape('path', {'d': 'M14 21H16M14 21C13.1716 21 12.5 20.3284 12.5 19.5V17L12 17M14 21H10M10 21H8M10 21C10.8284 21 11.5 20.3284 11.5 19.5V17L12 17M12 17V21', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M16 3H8C5.17157 3 3.75736 3 2.87868 3.87868C2 4.75736 2 6.17157 2 9V11C2 13.8284 2 15.2426 2.87868 16.1213C3.75736 17 5.17157 17 8 17H16C18.8284 17 20.2426 17 21.1213 16.1213C22 15.2426 22 13.8284 22 11V9C22 6.17157 22 4.75736 21.1213 3.87868C20.2426 3 18.8284 3 16 3Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const moon = IconData(
    'moon',
    shapes: [
      IconShape('path', {'d': 'M21.5 14.0784C20.3003 14.7189 18.9301 15.0821 17.4751 15.0821C12.7491 15.0821 8.91792 11.2509 8.91792 6.52485C8.91792 5.06986 9.28105 3.69968 9.92163 2.5C5.66765 3.49698 2.5 7.31513 2.5 11.8731C2.5 17.1899 6.8101 21.5 12.1269 21.5C16.6849 21.5 20.503 18.3324 21.5 14.0784Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const moreHorizontal = IconData(
    'moreHorizontal',
    shapes: [
      IconShape('path', {'d': 'M6.00449 12.5V12M18.0045 12.5V12M12.0045 12.5V12M7.00449 12.5C7.00449 11.9477 6.55677 11.5 6.00449 11.5C5.4522 11.5 5.00449 11.9477 5.00449 12.5C5.00449 13.0523 5.4522 13.5 6.00449 13.5C6.55677 13.5 7.00449 13.0523 7.00449 12.5ZM19.0045 12.5C19.0045 11.9477 18.5568 11.5 18.0045 11.5C17.4522 11.5 17.0045 11.9477 17.0045 12.5C17.0045 13.0523 17.4522 13.5 18.0045 13.5C18.5568 13.5 19.0045 13.0523 19.0045 12.5ZM13.0045 12.5C13.0045 11.9477 12.5568 11.5 12.0045 11.5C11.4522 11.5 11.0045 11.9477 11.0045 12.5C11.0045 13.0523 11.4522 13.5 12.0045 13.5C12.5568 13.5 13.0045 13.0523 13.0045 12.5Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const moreVertical = IconData(
    'moreVertical',
    shapes: [
      IconShape('path', {'d': 'M11.9967 12.5V12M11.9967 6.5V6M11.9967 18.5V18M12.9967 12.5C12.9967 11.9477 12.549 11.5 11.9967 11.5C11.4444 11.5 10.9967 11.9477 10.9967 12.5C10.9967 13.0523 11.4444 13.5 11.9967 13.5C12.549 13.5 12.9967 13.0523 12.9967 12.5ZM12.9967 6.5C12.9967 5.94772 12.549 5.5 11.9967 5.5C11.4444 5.5 10.9967 5.94772 10.9967 6.5C10.9967 7.05228 11.4444 7.5 11.9967 7.5C12.549 7.5 12.9967 7.05228 12.9967 6.5ZM12.9967 18.5C12.9967 17.9477 12.549 17.5 11.9967 17.5C11.4444 17.5 10.9967 17.9477 10.9967 18.5C10.9967 19.0523 11.4444 19.5 11.9967 19.5C12.549 19.5 12.9967 19.0523 12.9967 18.5Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const package = IconData(
    'package',
    shapes: [
      IconShape('path', {'d': 'M12 22C11.1818 22 10.4002 21.6698 8.83693 21.0095C4.94564 19.3657 3 18.5438 3 17.1613C3 16.7742 3 10.0645 3 7M12 22C12.8182 22 13.5998 21.6698 15.1631 21.0095C19.0544 19.3657 21 18.5438 21 17.1613V7M12 22L12 11.3548', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M8.32592 9.69138L5.40472 8.27785C3.80157 7.5021 3 7.11423 3 6.5C3 5.88577 3.80157 5.4979 5.40472 4.72215L8.32592 3.30862C10.1288 2.43621 11.0303 2 12 2C12.9697 2 13.8712 2.4362 15.6741 3.30862L18.5953 4.72215C20.1984 5.4979 21 5.88577 21 6.5C21 7.11423 20.1984 7.5021 18.5953 8.27785L15.6741 9.69138C13.8712 10.5638 12.9697 11 12 11C11.0303 11 10.1288 10.5638 8.32592 9.69138Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M6 12L8 13', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M17 4L7 9', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const palette = IconData(
    'palette',
    shapes: [
      IconShape('path', {'d': 'M22 12C22 6.47715 17.5228 2 12 2C6.47715 2 2 6.47715 2 12C2 17.5228 6.47715 22 12 22C12.8417 22 14 22.1163 14 21C14 20.391 13.6832 19.9212 13.3686 19.4544C12.9082 18.7715 12.4523 18.0953 13 17C13.6667 15.6667 14.7778 15.6667 16.4815 15.6667C17.3334 15.6667 18.3334 15.6667 19.5 15.5C21.601 15.1999 22 13.9084 22 12Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('circle', {'cx': '9.5', 'cy': '8.5', 'r': '1.5', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('circle', {'cx': '16.5', 'cy': '9.5', 'r': '1.5', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('path', {'d': 'M7.125 15H7M7.25 15C7.25 15.1381 7.13807 15.25 7 15.25C6.86193 15.25 6.75 15.1381 6.75 15C6.75 14.8619 6.86193 14.75 7 14.75C7.13807 14.75 7.25 14.8619 7.25 15Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const pause = IconData(
    'pause',
    shapes: [
      IconShape('path', {'d': 'M4 7C4 5.58579 4 4.87868 4.43934 4.43934C4.87868 4 5.58579 4 7 4C8.41421 4 9.12132 4 9.56066 4.43934C10 4.87868 10 5.58579 10 7V17C10 18.4142 10 19.1213 9.56066 19.5607C9.12132 20 8.41421 20 7 20C5.58579 20 4.87868 20 4.43934 19.5607C4 19.1213 4 18.4142 4 17V7Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('path', {'d': 'M14 7C14 5.58579 14 4.87868 14.4393 4.43934C14.8787 4 15.5858 4 17 4C18.4142 4 19.1213 4 19.5607 4.43934C20 4.87868 20 5.58579 20 7V17C20 18.4142 20 19.1213 19.5607 19.5607C19.1213 20 18.4142 20 17 20C15.5858 20 14.8787 20 14.4393 19.5607C14 19.1213 14 18.4142 14 17V7Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
    ],
  );
  static const phone = IconData(
    'phone',
    shapes: [
      IconShape('path', {'d': 'M4.91186 10.5413L7.55229 7.90088C8.09091 7.36227 8.27728 6.56642 8.05944 5.83652C7.8891 5.26577 7.69718 4.57964 7.56961 3.99292C7.45162 3.45027 6.97545 3 6.42012 3H4.91186C3.8012 3 2.88911 3.90384 3.01094 5.0078C3.93709 13.3996 10.6004 20.0629 18.9922 20.9891C20.0962 21.1109 21 20.1988 21 19.0881V17.5799C21 17.0246 20.5479 16.569 20.0015 16.4696C19.3988 16.36 18.7611 16.1804 18.2276 16.0103C17.4611 15.7659 16.6091 15.9377 16.0403 16.5065L13.4587 19.0881', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const play = IconData(
    'play',
    shapes: [
      IconShape('path', {'d': 'M18.8906 12.846C18.5371 14.189 16.8667 15.138 13.5257 17.0361C10.296 18.8709 8.6812 19.7884 7.37983 19.4196C6.8418 19.2671 6.35159 18.9776 5.95624 18.5787C5 17.6139 5 15.7426 5 12C5 8.2574 5 6.3861 5.95624 5.42132C6.35159 5.02245 6.8418 4.73288 7.37983 4.58042C8.6812 4.21165 10.296 5.12907 13.5257 6.96393C16.8667 8.86197 18.5371 9.811 18.8906 11.154C19.0365 11.7084 19.0365 12.2916 18.8906 12.846Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
    ],
  );
  static const plus = IconData(
    'plus',
    shapes: [
      IconShape('path', {'d': 'M12 4V20M20 12H4', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const power = IconData(
    'power',
    shapes: [
      IconShape('path', {'d': 'M7.86907 4C4.97674 5.49689 3 8.51664 3 11.9981C3 16.9686 7.02944 20.9981 12 20.9981C16.9706 20.9981 21 16.9686 21 11.9981C21 8.51664 19.0233 5.49689 16.1309 4', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12 3V10', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const printer = IconData(
    'printer',
    shapes: [
      IconShape('path', {'d': 'M17 17H18.6667C19.9128 17 20.5359 17 21 16.7321C21.304 16.5565 21.5565 16.304 21.732 16C22 15.5359 22 14.9128 22 13.6667C22 11.1744 22 9.9282 21.4641 9C21.113 8.39192 20.6081 7.88697 20 7.5359C19.0718 7 17.8256 7 15.3333 7H8.66667C6.17436 7 4.9282 7 4 7.5359C3.39192 7.88697 2.88697 8.39192 2.5359 9C2 9.9282 2 11.1744 2 13.6667C2 14.9128 2 15.5359 2.26795 16C2.44349 16.304 2.69596 16.5565 3 16.7321C3.4641 17 4.08718 17 5.33333 17H7', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M17 7V5C17 3.58579 17 2.87868 16.5607 2.43934C16.1213 2 15.4142 2 14 2H10C8.58579 2 7.87868 2 7.43934 2.43934C7 2.87868 7 3.58579 7 5V7', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M17 14V19C17 20.4142 17 21.1213 16.5607 21.5607C16.1213 22 15.4142 22 14 22H10C8.58579 22 7.87868 22 7.43934 21.5607C7 21.1213 7 20.4142 7 19V14H17Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M18.8748 10.25H18.7498M18.9998 10.25C18.9998 10.3881 18.8879 10.5 18.7498 10.5C18.6117 10.5 18.4998 10.3881 18.4998 10.25C18.4998 10.1119 18.6117 10 18.7498 10C18.8879 10 18.9998 10.1119 18.9998 10.25Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const redo = IconData(
    'redo',
    shapes: [
      IconShape('path', {'d': 'M21 12C21 16.9706 16.9706 21 12 21C7.02944 21 3 16.9706 3 12C3 7.02944 7.02944 3 12 3C15.2073 3 18.0227 4.67765 19.6166 7.20327M20.7066 3.00076L20.5344 5.05452C20.4104 6.53384 20.3484 7.27349 19.8664 7.68914C19.3844 8.10479 18.6733 8.03185 17.251 7.88595L15.2066 7.67625', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const refresh = IconData(
    'refresh',
    shapes: [
      IconShape('path', {'d': 'M20.0092 2V5.13219C20.0092 5.42605 19.6418 5.55908 19.4537 5.33333C17.6226 3.2875 14.9617 2 12 2C6.47715 2 2 6.47715 2 12C2 17.5228 6.47715 22 12 22C17.5228 22 22 17.5228 22 12', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const rocket = IconData(
    'rocket',
    shapes: [
      IconShape('path', {'d': 'M8 10.1667L12.1232 6.04344C13.2481 4.91858 13.8105 4.35614 14.4312 3.90314C15.7047 2.9737 17.1818 2.36187 18.7395 2.11858C19.4988 2 20.2942 2 21.885 2C21.9681 2 22 2.03812 22 2.11504C22 3.70584 22 4.50125 21.8814 5.26046C21.6381 6.81818 21.0263 8.29527 20.0969 9.56878C19.6439 10.1895 19.0814 10.7519 17.9566 11.8768L13.8333 16', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M10.341 8.09838C8.63808 8.09838 6.49778 7.73765 4.9043 8.39769C3.73671 8.88132 2.87754 10.0012 2 10.8787L5.30597 12.2955C6.18208 12.671 5.64651 13.7766 5.50147 14.5018C5.33985 15.3099 5.34886 15.3397 5.93158 15.9224L8.07758 18.0684C8.6603 18.6511 8.69008 18.6602 9.49816 18.4985C10.2234 18.3535 11.329 17.8179 11.7044 18.694L13.1213 22C13.9988 21.1225 15.1187 20.2633 15.6023 19.0957C16.2624 17.5022 15.9016 15.3619 15.9016 13.659', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12 20L11 21', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M4 12L3 13', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M15 4.07996C16.2 4.25996 17.46 4.73996 18.1614 5.45996C19.0576 6.25211 19.68 7.31996 19.92 8.99996', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'square'}),
      IconShape('path', {'d': 'M17.94 6.06006L16.5 7.50006', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
    ],
  );
  static const route = IconData(
    'route',
    shapes: [
      IconShape('circle', {'cx': '18', 'cy': '5', 'r': '3', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('circle', {'cx': '6', 'cy': '19', 'r': '3', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12 5H8.5C6.567 5 5 6.567 5 8.5C5 10.433 6.567 12 8.5 12H15.5C17.433 12 19 13.567 19 15.5C19 17.433 17.433 19 15.5 19H12', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const save = IconData(
    'save',
    shapes: [
      IconShape('path', {'d': 'M8 22V19C8 17.1144 8 16.1716 8.58579 15.5858C9.17157 15 10.1144 15 12 15C13.8856 15 14.8284 15 15.4142 15.5858C16 16.1716 16 17.1144 16 19V22', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M10 7H14', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M3 11.8584C3 7.28199 3 4.99376 4.38674 3.54394C4.43797 3.49038 4.49038 3.43797 4.54394 3.38674C5.99376 2 8.28199 2 12.8584 2C13.943 2 14.4655 2.00376 14.9628 2.18936C15.4417 2.3681 15.8429 2.70239 16.6452 3.37099L18.8411 5.20092C19.9027 6.08561 20.4335 6.52795 20.7168 7.13266C21 7.73737 21 8.42833 21 9.81025V13C21 16.7497 21 18.6246 20.0451 19.9389C19.7367 20.3634 19.3634 20.7367 18.9389 21.0451C17.6246 22 15.7497 22 12 22C8.25027 22 6.3754 22 5.06107 21.0451C4.6366 20.7367 4.26331 20.3634 3.95491 19.9389C3 18.6246 3 16.7497 3 13V11.8584Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
    ],
  );
  static const search = IconData(
    'search',
    shapes: [
      IconShape('path', {'d': 'M17 17L21 21', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M19 11C19 6.58172 15.4183 3 11 3C6.58172 3 3 6.58172 3 11C3 15.4183 6.58172 19 11 19C15.4183 19 19 15.4183 19 11Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const send = IconData(
    'send',
    shapes: [
      IconShape('path', {'d': 'M21.0477 3.05293C18.8697 0.707363 2.48648 6.4532 2.50001 8.551C2.51535 10.9299 8.89809 11.6617 10.6672 12.1581C11.7311 12.4565 12.016 12.7625 12.2613 13.8781C13.3723 18.9305 13.9301 21.4435 15.2014 21.4996C17.2278 21.5892 23.1733 5.342 21.0477 3.05293Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('path', {'d': 'M11.4999 12.5L14.9999 9', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const server = IconData(
    'server',
    shapes: [
      IconShape('path', {'d': 'M19 4H5C4.06812 4 3.60218 4 3.23463 4.15224C2.74458 4.35523 2.35523 4.74458 2.15224 5.23463C2 5.60218 2 6.06812 2 7C2 7.93188 2 8.39782 2.15224 8.76537C2.35523 9.25542 2.74458 9.64477 3.23463 9.84776C3.60218 10 4.06812 10 5 10H19C19.9319 10 20.3978 10 20.7654 9.84776C21.2554 9.64477 21.6448 9.25542 21.8478 8.76537C22 8.39782 22 7.93188 22 7C22 6.06812 22 5.60218 21.8478 5.23463C21.6448 4.74458 21.2554 4.35523 20.7654 4.15224C20.3978 4 19.9319 4 19 4Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M19 14H5C4.06812 14 3.60218 14 3.23463 14.1522C2.74458 14.3552 2.35523 14.7446 2.15224 15.2346C2 15.6022 2 16.0681 2 17C2 17.9319 2 18.3978 2.15224 18.7654C2.35523 19.2554 2.74458 19.6448 3.23463 19.8478C3.60218 20 4.06812 20 5 20H19C19.9319 20 20.3978 20 20.7654 19.8478C21.2554 19.6448 21.6448 19.2554 21.8478 18.7654C22 18.3978 22 17.9319 22 17C22 16.0681 22 15.6022 21.8478 15.2346C21.6448 14.7446 21.2554 14.3552 20.7654 14.1522C20.3978 14 19.9319 14 19 14Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M6.125 7H6M6.25 7C6.25 7.13807 6.13807 7.25 6 7.25C5.86193 7.25 5.75 7.13807 5.75 7C5.75 6.86193 5.86193 6.75 6 6.75C6.13807 6.75 6.25 6.86193 6.25 7Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M10.125 7H10M10.25 7C10.25 7.13807 10.1381 7.25 10 7.25C9.86193 7.25 9.75 7.13807 9.75 7C9.75 6.86193 9.86193 6.75 10 6.75C10.1381 6.75 10.25 6.86193 10.25 7Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M6.125 17H6M6.25 17C6.25 17.1381 6.13807 17.25 6 17.25C5.86193 17.25 5.75 17.1381 5.75 17C5.75 16.8619 5.86193 16.75 6 16.75C6.13807 16.75 6.25 16.8619 6.25 17Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M10.125 17H10M10.25 17C10.25 17.1381 10.1381 17.25 10 17.25C9.86193 17.25 9.75 17.1381 9.75 17C9.75 16.8619 9.86193 16.75 10 16.75C10.1381 16.75 10.25 16.8619 10.25 17Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const settings = IconData(
    'settings',
    shapes: [
      IconShape('path', {'d': 'M21.3175 7.14139L20.8239 6.28479C20.4506 5.63696 20.264 5.31305 19.9464 5.18388C19.6288 5.05472 19.2696 5.15664 18.5513 5.36048L17.3311 5.70418C16.8725 5.80994 16.3913 5.74994 15.9726 5.53479L15.6357 5.34042C15.2766 5.11043 15.0004 4.77133 14.8475 4.37274L14.5136 3.37536C14.294 2.71534 14.1842 2.38533 13.9228 2.19657C13.6615 2.00781 13.3143 2.00781 12.6199 2.00781H11.5051C10.8108 2.00781 10.4636 2.00781 10.2022 2.19657C9.94085 2.38533 9.83106 2.71534 9.61149 3.37536L9.27753 4.37274C9.12465 4.77133 8.84845 5.11043 8.48937 5.34042L8.15249 5.53479C7.73374 5.74994 7.25259 5.80994 6.79398 5.70418L5.57375 5.36048C4.85541 5.15664 4.49625 5.05472 4.17867 5.18388C3.86109 5.31305 3.67445 5.63696 3.30115 6.28479L2.80757 7.14139C2.45766 7.74864 2.2827 8.05227 2.31666 8.37549C2.35061 8.69871 2.58483 8.95918 3.05326 9.48012L4.0843 10.6328C4.3363 10.9518 4.51521 11.5078 4.51521 12.0077C4.51521 12.5078 4.33636 13.0636 4.08433 13.3827L3.05326 14.5354C2.58483 15.0564 2.35062 15.3168 2.31666 15.6401C2.2827 15.9633 2.45766 16.2669 2.80757 16.8741L3.30114 17.7307C3.67443 18.3785 3.86109 18.7025 4.17867 18.8316C4.49625 18.9608 4.85542 18.8589 5.57377 18.655L6.79394 18.3113C7.25263 18.2055 7.73387 18.2656 8.15267 18.4808L8.4895 18.6752C8.84851 18.9052 9.12464 19.2442 9.2775 19.6428L9.61149 20.6403C9.83106 21.3003 9.94085 21.6303 10.2022 21.8191C10.4636 22.0078 10.8108 22.0078 11.5051 22.0078H12.6199C13.3143 22.0078 13.6615 22.0078 13.9228 21.8191C14.1842 21.6303 14.294 21.3003 14.5136 20.6403L14.8476 19.6428C15.0004 19.2442 15.2765 18.9052 15.6356 18.6752L15.9724 18.4808C16.3912 18.2656 16.8724 18.2055 17.3311 18.3113L18.5513 18.655C19.2696 18.8589 19.6288 18.9608 19.9464 18.8316C20.264 18.7025 20.4506 18.3785 20.8239 17.7307L21.3175 16.8741C21.6674 16.2669 21.8423 15.9633 21.8084 15.6401C21.7744 15.3168 21.5402 15.0564 21.0718 14.5354L20.0407 13.3827C19.7887 13.0636 19.6098 12.5078 19.6098 12.0077C19.6098 11.5078 19.7888 10.9518 20.0407 10.6328L21.0718 9.48012C21.5402 8.95918 21.7744 8.69871 21.8084 8.37549C21.8423 8.05227 21.6674 7.74864 21.3175 7.14139Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M15.5195 12C15.5195 13.933 13.9525 15.5 12.0195 15.5C10.0865 15.5 8.51953 13.933 8.51953 12C8.51953 10.067 10.0865 8.5 12.0195 8.5C13.9525 8.5 15.5195 10.067 15.5195 12Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
    ],
  );
  static const shield = IconData(
    'shield',
    shapes: [
      IconShape('path', {'d': 'M18.7088 3.49534C16.8165 2.55382 14.5009 2 12 2C9.4991 2 7.1835 2.55382 5.29116 3.49534C4.36318 3.95706 3.89919 4.18792 3.4496 4.91378C3 5.63965 3 6.34248 3 7.74814V11.2371C3 16.9205 7.54236 20.0804 10.173 21.4338C10.9067 21.8113 11.2735 22 12 22C12.7265 22 13.0933 21.8113 13.8269 21.4338C16.4576 20.0804 21 16.9205 21 11.2371L21 7.74814C21 6.34249 21 5.63966 20.5504 4.91378C20.1008 4.18791 19.6368 3.95706 18.7088 3.49534Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const shoppingCart = IconData(
    'shoppingCart',
    shapes: [
      IconShape('path', {'d': 'M10.5 20.25C10.5 20.6642 10.1642 21 9.75 21C9.33579 21 9 20.6642 9 20.25C9 19.8358 9.33579 19.5 9.75 19.5C10.1642 19.5 10.5 19.8358 10.5 20.25Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M19 20.25C19 20.6642 18.6642 21 18.25 21C17.8358 21 17.5 20.6642 17.5 20.25C17.5 19.8358 17.8358 19.5 18.25 19.5C18.6642 19.5 19 19.8358 19 20.25Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M2 3H2.20664C3.53124 3 4.19354 3 4.6255 3.40221C5.05746 3.80441 5.10464 4.46503 5.19902 5.78626L5.45035 9.30496C5.5924 11.2936 5.66342 12.2879 5.96476 13.0961C6.62531 14.8677 8.08229 16.2244 9.89648 16.757C10.7241 17 11.7267 17 13.7317 17C15.8373 17 16.89 17 17.7417 16.7416C19.6593 16.1599 21.1599 14.6593 21.7416 12.7417C22 11.89 22 10.8433 22 8.75C22 8.05222 22 7.70333 21.9139 7.41943C21.72 6.78023 21.2198 6.28002 20.5806 6.08612C20.2967 6 19.9478 6 19.25 6H5.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M16 10V13M11 10V13', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const sliders = IconData(
    'sliders',
    shapes: [
      IconShape('path', {'d': 'M3.99963 5.00055L9.99963 5.00031', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M12.9996 5.00031L19.9996 5.00031', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M15.9996 9.00031L15.9996 15.0003', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M9.99963 2.00031L9.99963 8.00031', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M11.9996 16.0003L11.9996 22.0003', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M15.9996 12.0001L19.9996 12.0003', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M3.99963 12.0005L12.9996 12.0003', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M11.9996 19.0003L19.9996 19.0003', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M3.99963 19.0005L8.99963 19.0003', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
    ],
  );
  static const smartphone = IconData(
    'smartphone',
    shapes: [
      IconShape('path', {'d': 'M13.5 2H10.5C8.14298 2 6.96447 2 6.23223 2.73223C5.5 3.46447 5.5 4.64298 5.5 7V17C5.5 19.357 5.5 20.5355 6.23223 21.2678C6.96447 22 8.14298 22 10.5 22H13.5C15.857 22 17.0355 22 17.7678 21.2678C18.5 20.5355 18.5 19.357 18.5 17V7C18.5 4.64298 18.5 3.46447 17.7678 2.73223C17.0355 2 15.857 2 13.5 2Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12.125 19H12M12.25 19C12.25 19.1381 12.1381 19.25 12 19.25C11.8619 19.25 11.75 19.1381 11.75 19C11.75 18.8619 11.8619 18.75 12 18.75C12.1381 18.75 12.25 18.8619 12.25 19Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const sparkles = IconData(
    'sparkles',
    shapes: [
      IconShape('path', {'d': 'M15 2L15.5387 4.39157C15.9957 6.42015 17.5798 8.00431 19.6084 8.46127L22 9L19.6084 9.53873C17.5798 9.99569 15.9957 11.5798 15.5387 13.6084L15 16L14.4613 13.6084C14.0043 11.5798 12.4202 9.99569 10.3916 9.53873L8 9L10.3916 8.46127C12.4201 8.00431 14.0043 6.42015 14.4613 4.39158L15 2Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M7 12L7.38481 13.7083C7.71121 15.1572 8.84275 16.2888 10.2917 16.6152L12 17L10.2917 17.3848C8.84275 17.7112 7.71121 18.8427 7.38481 20.2917L7 22L6.61519 20.2917C6.28879 18.8427 5.15725 17.7112 3.70827 17.3848L2 17L3.70827 16.6152C5.15725 16.2888 6.28879 15.1573 6.61519 13.7083L7 12Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linejoin': 'round'}),
    ],
  );
  static const square = IconData(
    'square',
    shapes: [
      IconShape('path', {'d': 'M2.5 12C2.5 7.52166 2.5 5.28249 3.89124 3.89124C5.28249 2.5 7.52166 2.5 12 2.5C16.4783 2.5 18.7175 2.5 20.1088 3.89124C21.5 5.28249 21.5 7.52166 21.5 12C21.5 16.4783 21.5 18.7175 20.1088 20.1088C18.7175 21.5 16.4783 21.5 12 21.5C7.52166 21.5 5.28249 21.5 3.89124 20.1088C2.5 18.7175 2.5 16.4783 2.5 12Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
    ],
  );
  static const star = IconData(
    'star',
    shapes: [
      IconShape('path', {'d': 'M13.7276 3.44418L15.4874 6.99288C15.7274 7.48687 16.3673 7.9607 16.9073 8.05143L20.0969 8.58575C22.1367 8.92853 22.6167 10.4206 21.1468 11.8925L18.6671 14.3927C18.2471 14.8161 18.0172 15.6327 18.1471 16.2175L18.8571 19.3125C19.417 21.7623 18.1271 22.71 15.9774 21.4296L12.9877 19.6452C12.4478 19.3226 11.5579 19.3226 11.0079 19.6452L8.01827 21.4296C5.8785 22.71 4.57865 21.7522 5.13859 19.3125L5.84851 16.2175C5.97849 15.6327 5.74852 14.8161 5.32856 14.3927L2.84884 11.8925C1.389 10.4206 1.85895 8.92853 3.89872 8.58575L7.08837 8.05143C7.61831 7.9607 8.25824 7.48687 8.49821 6.99288L10.258 3.44418C11.2179 1.51861 12.7777 1.51861 13.7276 3.44418Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const stop = IconData(
    'stop',
    shapes: [
      IconShape('path', {'d': 'M4 12C4 8.72077 4 7.08116 4.81382 5.91891C5.1149 5.48891 5.48891 5.1149 5.91891 4.81382C7.08116 4 8.72077 4 12 4C15.2792 4 16.9188 4 18.0811 4.81382C18.5111 5.1149 18.8851 5.48891 19.1862 5.91891C20 7.08116 20 8.72077 20 12C20 15.2792 20 16.9188 19.1862 18.0811C18.8851 18.5111 18.5111 18.8851 18.0811 19.1862C16.9188 20 15.2792 20 12 20C8.72077 20 7.08116 20 5.91891 19.1862C5.48891 18.8851 5.1149 18.5111 4.81382 18.0811C4 16.9188 4 15.2792 4 12Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
    ],
  );
  static const sun = IconData(
    'sun',
    shapes: [
      IconShape('path', {'d': 'M17 12C17 14.7614 14.7614 17 12 17C9.23858 17 7 14.7614 7 12C7 9.23858 9.23858 7 12 7C14.7614 7 17 9.23858 17 12Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('path', {'d': 'M12 2V3.5M12 20.5V22M19.0708 19.0713L18.0101 18.0106M5.98926 5.98926L4.9286 4.9286M22 12H20.5M3.5 12H2M19.0713 4.92871L18.0106 5.98937M5.98975 18.0107L4.92909 19.0714', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
    ],
  );
  static const tag = IconData(
    'tag',
    shapes: [
      IconShape('circle', {'cx': '1.5', 'cy': '1.5', 'r': '1.5', 'transform': 'matrix(1 0 0 -1 16 8.00024)', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M2.77423 11.1439C1.77108 12.2643 1.7495 13.9546 2.67016 15.1437C4.49711 17.5033 6.49674 19.5029 8.85633 21.3298C10.0454 22.2505 11.7357 22.2289 12.8561 21.2258C15.8979 18.5022 18.6835 15.6559 21.3719 12.5279C21.6377 12.2187 21.8039 11.8397 21.8412 11.4336C22.0062 9.63798 22.3452 4.46467 20.9403 3.05974C19.5353 1.65481 14.362 1.99377 12.5664 2.15876C12.1603 2.19608 11.7813 2.36233 11.472 2.62811C8.34412 5.31646 5.49781 8.10211 2.77423 11.1439Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('path', {'d': 'M7.00002 14.0002L10 17.0002', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const terminal = IconData(
    'terminal',
    shapes: [
      IconShape('path', {'d': 'M4.00004 17C4.00004 17 9.99999 12.5811 10 11C10 9.41884 4 5 4 5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12 19H20', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const trash = IconData(
    'trash',
    shapes: [
      IconShape('path', {'d': 'M19.5 5.5L18.8803 15.5251C18.7219 18.0864 18.6428 19.3671 18.0008 20.2879C17.6833 20.7431 17.2747 21.1273 16.8007 21.416C15.8421 22 14.559 22 11.9927 22C9.42312 22 8.1383 22 7.17905 21.4149C6.7048 21.1257 6.296 20.7408 5.97868 20.2848C5.33688 19.3626 5.25945 18.0801 5.10461 15.5152L4.5 5.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M3 5.5H21M16.0557 5.5L15.3731 4.09173C14.9196 3.15626 14.6928 2.68852 14.3017 2.39681C14.215 2.3321 14.1231 2.27454 14.027 2.2247C13.5939 2 13.0741 2 12.0345 2C10.9688 2 10.436 2 9.99568 2.23412C9.8981 2.28601 9.80498 2.3459 9.71729 2.41317C9.32164 2.7167 9.10063 3.20155 8.65861 4.17126L8.05292 5.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M9.5 16.5L9.5 10.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M14.5 16.5L14.5 10.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
    ],
  );
  static const trendingUp = IconData(
    'trendingUp',
    shapes: [
      IconShape('path', {'d': 'M20 13V8H15', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M20 8L15 13C14.1174 13.8826 13.6762 14.3238 13.1346 14.3726C13.045 14.3807 12.955 14.3807 12.8654 14.3726C12.3238 14.3238 11.8826 13.8826 11 13C10.1174 12.1174 9.67615 11.6762 9.13457 11.6274C9.04504 11.6193 8.95496 11.6193 8.86543 11.6274C8.32385 11.6762 7.88256 12.1174 7 13L4 16', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const tv = IconData(
    'tv',
    shapes: [
      IconShape('path', {'d': 'M2 14C2 10.2288 2 8.34315 3.17157 7.17157C4.34315 6 6.22876 6 10 6H14C17.7712 6 19.6569 6 20.8284 7.17157C22 8.34315 22 10.2288 22 14C22 17.7712 22 19.6569 20.8284 20.8284C19.6569 22 17.7712 22 14 22H10C6.22876 22 4.34315 22 3.17157 20.8284C2 19.6569 2 17.7712 2 14Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('path', {'d': 'M9 3L12 6L16 2', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const type = IconData(
    'type',
    shapes: [
      IconShape('path', {'d': 'M15 21.001H9', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12 3.00001V21.0008M12 3.00001C13.3874 3.00001 15.1695 3.03055 16.5884 3.17649C17.1885 3.2382 17.4886 3.26906 17.7541 3.37791C18.3066 3.60429 18.7518 4.10063 18.9194 4.67681C19 4.95382 19 5.26992 19 5.90215M12 3.00001C10.6126 3.00001 8.83047 3.03055 7.41161 3.17649C6.8115 3.2382 6.51144 3.26906 6.24586 3.37791C5.69344 3.60429 5.24816 4.10063 5.08057 4.67681C5 4.95382 5 5.26992 5 5.90215', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
    ],
  );
  static const undo = IconData(
    'undo',
    shapes: [
      IconShape('path', {'d': 'M3 12C3 16.9706 7.02944 21 12 21C16.9706 21 21 16.9706 21 12C21 7.02944 16.9706 3 12 3C8.79275 3 5.97733 4.67765 4.38341 7.20327M3.29339 3.00076L3.46556 5.05452C3.58958 6.53384 3.65159 7.27349 4.13359 7.68914C4.61559 8.10479 5.32673 8.03185 6.74899 7.88595L8.79339 7.67625', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const unlock = IconData(
    'unlock',
    shapes: [
      IconShape('path', {'d': 'M12 14.5V17.5M13 14.5C13 15.0523 12.5523 15.5 12 15.5C11.4477 15.5 11 15.0523 11 14.5C11 13.9477 11.4477 13.5 12 13.5C12.5523 13.5 13 13.9477 13 14.5Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M7.5 9V6.5C7.5 4.01472 9.51472 2 12 2C13.9593 2 15.8664 3.25221 16.5 5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M4.26781 18.8447C4.49269 20.515 5.87613 21.8235 7.55966 21.9009C8.97627 21.966 10.4153 22 12 22C13.5847 22 15.0237 21.966 16.4403 21.9009C18.1239 21.8235 19.5073 20.515 19.7322 18.8447C19.879 17.7547 20 16.6376 20 15.5C20 14.3624 19.879 13.2453 19.7322 12.1553C19.5073 10.485 18.1239 9.17649 16.4403 9.09909C15.0237 9.03397 13.5847 9 12 9C10.4153 9 8.97627 9.03397 7.55966 9.09909C5.87613 9.17649 4.49269 10.485 4.26781 12.1553C4.12104 13.2453 4 14.3624 4 15.5C4 16.6376 4.12104 17.7547 4.26781 18.8447Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const upload = IconData(
    'upload',
    shapes: [
      IconShape('path', {'d': 'M2.99994 17C2.99994 17.93 2.99994 18.395 3.10216 18.7765C3.37956 19.8117 4.18821 20.6204 5.22348 20.8978C5.60498 21 6.06997 21 6.99994 21L16.9999 21C17.9299 21 18.3949 21 18.7764 20.8978C19.8117 20.6204 20.6203 19.8117 20.8977 18.7765C20.9999 18.395 20.9999 17.93 20.9999 17', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M16.5 7.49993C16.5 7.49993 13.1858 2.99997 12 2.99996C10.8141 2.99995 7.50002 7.49996 7.50002 7.49996M12 3.99996V16', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const user = IconData(
    'user',
    shapes: [
      IconShape('path', {'d': 'M20 21.0001C19.713 17.269 16.7289 14.3151 12.995 14.0662L12 13.9999C11.6446 14.0096 11.3134 14.0225 11.0008 14.0378C7.3 14.2192 4.28417 17.3057 4 21.0001', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('circle', {'cx': '12', 'cy': '6.99988', 'r': '4', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const userPlus = IconData(
    'userPlus',
    shapes: [
      IconShape('path', {'d': 'M3 20.5002C3.28417 16.8058 6.3 13.7193 10.0008 13.5379C10.3134 13.5226 10.6446 13.5097 11 13.5L11.995 13.5663C12.6939 13.6129 13.3665 13.7543 14 13.9777', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M18 15.5V21.5M21 18.5L15 18.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('circle', {'cx': '11', 'cy': '6.5', 'r': '4', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const users = IconData(
    'users',
    shapes: [
      IconShape('path', {'d': 'M16 21C15.7668 18.0685 13.3422 15.7477 10.3085 15.5521L9.49999 15.5C9.21121 15.5076 8.94209 15.5178 8.68816 15.5298C5.68124 15.6723 3.23089 18.0974 3 21', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12.75 9.75C12.75 11.5449 11.2949 13 9.5 13C7.70508 13 6.25 11.5449 6.25 9.75C6.25 7.95507 7.70508 6.5 9.5 6.5C11.2949 6.5 12.75 7.95507 12.75 9.75Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M21 17.501C20.7709 14.6314 18.4541 12.2748 15.5 11.9961', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M15.9877 9C16.8965 8.42434 17.5001 7.40788 17.5001 6.25C17.5001 4.45507 16.0496 3 14.2602 3C13.3811 3 12.5838 3.35121 12.0001 3.92139', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const video = IconData(
    'video',
    shapes: [
      IconShape('path', {'d': 'M2 11C2 7.70017 2 6.05025 3.02513 5.02513C4.05025 4 5.70017 4 9 4H10C13.2998 4 14.9497 4 15.9749 5.02513C17 6.05025 17 7.70017 17 11V13C17 16.2998 17 17.9497 15.9749 18.9749C14.9497 20 13.2998 20 10 20H9C5.70017 20 4.05025 20 3.02513 18.9749C2 17.9497 2 16.2998 2 13V11Z', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
      IconShape('path', {'d': 'M17 8.90585L17.1259 8.80196C19.2417 7.05623 20.2996 6.18336 21.1498 6.60482C22 7.02628 22 8.42355 22 11.2181V12.7819C22 15.5765 22 16.9737 21.1498 17.3952C20.2996 17.8166 19.2417 16.9438 17.1259 15.198L17 15.0941', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round'}),
      IconShape('circle', {'cx': '11.5', 'cy': '9.5', 'r': '1.5', 'stroke': 'currentColor', 'stroke-width': '1.5'}),
    ],
  );
  static const wallet = IconData(
    'wallet',
    shapes: [
      IconShape('path', {'d': 'M14 3H5C3.89543 3 3 3.89543 3 5C3 6.10457 3.89543 7 5 7H18C18 6.07003 18 5.60504 17.8978 5.22354C17.6204 4.18827 16.8117 3.37962 15.7765 3.10222C15.395 3 14.93 3 14 3Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M3 5V15C3 17.8284 3 19.2426 3.87868 20.1213C4.75736 21 6.17157 21 9 21H15C17.8284 21 19.2426 21 20.1213 20.1213C21 19.2426 21 17.8284 21 15V13C21 10.1716 21 8.75736 20.1213 7.87868C19.2426 7 17.8284 7 15 7H7', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M21 12H19C18.535 12 18.3025 12 18.1118 12.0511C17.5941 12.1898 17.1898 12.5941 17.0511 13.1118C17 13.3025 17 13.535 17 14C17 14.465 17 14.6975 17.0511 14.8882C17.1898 15.4059 17.5941 15.8102 18.1118 15.9489C18.3025 16 18.535 16 19 16H21', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const warning = IconData(
    'warning',
    shapes: [
      IconShape('path', {'d': 'M13.9248 21H10.0752C5.44476 21 3.12955 21 2.27636 19.4939C1.42317 17.9879 2.60736 15.9914 4.97574 11.9985L6.90057 8.75333C9.17559 4.91778 10.3131 3 12 3C13.6869 3 14.8244 4.91777 17.0994 8.75332L19.0243 11.9985C21.3926 15.9914 22.5768 17.9879 21.7236 19.4939C20.8704 21 18.5552 21 13.9248 21Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12 9V13', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M12.125 16.75H12M12.25 16.75C12.25 16.8881 12.1381 17 12 17C11.8619 17 11.75 16.8881 11.75 16.75C11.75 16.6119 11.8619 16.5 12 16.5C12.1381 16.5 12.25 16.6119 12.25 16.75Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const wifi = IconData(
    'wifi',
    shapes: [
      IconShape('path', {'d': 'M8.25 14.5C10.25 12.5 13.75 12.5 15.75 14.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M18.5 11.5C14.7324 8.16667 9.5 8.16667 5.5 11.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('path', {'d': 'M2 8.5C8.31579 3.16669 15.6842 3.16668 22 8.49989', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
      IconShape('circle', {'cx': '12', 'cy': '18', 'r': '1.5', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const x = IconData(
    'x',
    shapes: [
      IconShape('path', {'d': 'M18 6L6.00081 17.9992M17.9992 18L6 6.00085', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );
  static const zap = IconData(
    'zap',
    shapes: [
      IconShape('path', {'d': 'M5.22576 11.3294L12.224 2.34651C12.7713 1.64397 13.7972 2.08124 13.7972 3.01707V9.96994C13.7972 10.5305 14.1995 10.985 14.6958 10.985H18.0996C18.8729 10.985 19.2851 12.0149 18.7742 12.6706L11.776 21.6535C11.2287 22.356 10.2028 21.9188 10.2028 20.9829V14.0301C10.2028 13.4695 9.80048 13.015 9.3042 13.015H5.90035C5.12711 13.015 4.71494 11.9851 5.22576 11.3294Z', 'stroke': 'currentColor', 'stroke-width': '1.5', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}),
    ],
  );

  /// All built-in Flint UI icons in alphabetical order.
  static const all = <IconData>[
    activity,
    alarm,
    alertCircle,
    archive,
    arrowDown,
    arrowLeft,
    arrowRight,
    arrowUp,
    atSign,
    award,
    bank,
    bell,
    bold,
    book,
    bookmark,
    box,
    briefcase,
    calendar,
    camera,
    chartBar,
    chartLine,
    check,
    checkCircle,
    chevronDown,
    chevronLeft,
    chevronRight,
    chevronUp,
    circle,
    clipboard,
    clock,
    close,
    cloud,
    code,
    cog,
    component,
    copy,
    cpu,
    creditCard,
    database,
    document,
    download,
    edit,
    externalLink,
    eye,
    eyeOff,
    file,
    filter,
    folder,
    gauge,
    gitBranch,
    globe,
    grid,
    hardDrive,
    headphones,
    heart,
    helpCircle,
    home,
    image,
    inbox,
    info,
    key,
    laptop,
    layers,
    layout,
    lifeBuoy,
    link,
    list,
    loader,
    lock,
    logIn,
    logOut,
    mail,
    mapPin,
    menu,
    message,
    minus,
    monitor,
    moon,
    moreHorizontal,
    moreVertical,
    package,
    palette,
    pause,
    phone,
    play,
    plus,
    power,
    printer,
    redo,
    refresh,
    rocket,
    route,
    save,
    search,
    send,
    server,
    settings,
    shield,
    shoppingCart,
    sliders,
    smartphone,
    sparkles,
    square,
    star,
    stop,
    sun,
    tag,
    terminal,
    trash,
    trendingUp,
    tv,
    type,
    undo,
    unlock,
    upload,
    user,
    userPlus,
    users,
    video,
    wallet,
    warning,
    wifi,
    x,
    zap,
  ];
}

String _iconCssSize(Object? size) {
  if (size == null) return '1em';
  if (size is num) return '${size}px';
  return size.toString();
}
