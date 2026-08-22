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

/// Curated outline icons for Flint UI apps.
///
/// The set focuses on dashboard, CRUD, auth, commerce, content, hosting, and
/// navigation interfaces so common app screens can be built without importing a
/// separate icon package.
class Icons {
  const Icons._();

  static final activity = IconData(
    'activity',
    shapes: [_polyline('22 12 18 12 15 21 9 3 6 12 2 12')],
  );
  static final alarm = IconData(
    'alarm',
    shapes: [
      _circle(12, 13, 7),
      _path('M12 10v4l3 2'),
      _path('M5 3 2 6'),
      _path('M19 3l3 3'),
    ],
  );
  static final alertCircle = IconData(
    'alertCircle',
    shapes: [_circle(12, 12, 10), _line(12, 8, 12, 13), _line(12, 17, 12, 17)],
  );
  static final archive = IconData(
    'archive',
    shapes: [_rect(3, 4, 18, 4), _path('M5 8v12h14V8'), _path('M10 12h4')],
  );
  static final arrowDown = IconData(
    'arrowDown',
    shapes: [_path('M12 5v14'), _polyline('19 12 12 19 5 12')],
  );
  static final arrowLeft = IconData(
    'arrowLeft',
    shapes: [_path('M19 12H5'), _polyline('12 19 5 12 12 5')],
  );
  static final arrowRight = IconData(
    'arrowRight',
    shapes: [_path('M5 12h14'), _polyline('12 5 19 12 12 19')],
  );
  static final arrowUp = IconData(
    'arrowUp',
    shapes: [_path('M12 19V5'), _polyline('5 12 12 5 19 12')],
  );
  static final atSign = IconData(
    'atSign',
    shapes: [
      _circle(12, 12, 4),
      _path('M16 8v5a3 3 0 0 0 6 0v-1a10 10 0 1 0-4 8'),
    ],
  );
  static final award = IconData(
    'award',
    shapes: [_circle(12, 8, 5), _path('M8.5 12.5 7 22l5-3 5 3-1.5-9.5')],
  );
  static final bank = IconData(
    'bank',
    shapes: [
      _path('M3 10h18'),
      _path('M5 10v8'),
      _path('M9 10v8'),
      _path('M15 10v8'),
      _path('M19 10v8'),
      _path('M2 18h20'),
      _path('M12 3 3 8h18l-9-5z'),
    ],
  );
  static final bell = IconData(
    'bell',
    shapes: [
      _path('M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9'),
      _path('M10 21h4'),
    ],
  );
  static final book = IconData(
    'book',
    shapes: [
      _path('M4 19.5A2.5 2.5 0 0 1 6.5 17H20'),
      _path('M4 4.5A2.5 2.5 0 0 1 6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15z'),
    ],
  );
  static final bookmark = IconData(
    'bookmark',
    shapes: [_path('M6 3h12v18l-6-4-6 4V3z')],
  );
  static final box = IconData(
    'box',
    shapes: [
      _path('M21 8 12 3 3 8l9 5 9-5z'),
      _path('M3 8v8l9 5 9-5V8'),
      _path('M12 13v8'),
    ],
  );
  static final briefcase = IconData(
    'briefcase',
    shapes: [
      _rect(3, 7, 18, 13, rx: 2),
      _path('M9 7V5h6v2'),
      _path('M3 13h18'),
    ],
  );
  static final calendar = IconData(
    'calendar',
    shapes: [
      _rect(3, 4, 18, 17, rx: 2),
      _line(16, 2, 16, 6),
      _line(8, 2, 8, 6),
      _line(3, 10, 21, 10),
    ],
  );
  static final camera = IconData(
    'camera',
    shapes: [_path('M4 7h3l2-3h6l2 3h3v13H4V7z'), _circle(12, 13, 4)],
  );
  static final chartBar = IconData(
    'chartBar',
    shapes: [
      _path('M4 20V10'),
      _path('M10 20V4'),
      _path('M16 20v-7'),
      _path('M22 20H2'),
    ],
  );
  static final chartLine = IconData(
    'chartLine',
    shapes: [_path('M3 19h18'), _polyline('4 15 9 10 13 13 20 6')],
  );
  static final check = IconData('check', shapes: [_polyline('20 6 9 17 4 12')]);
  static final checkCircle = IconData(
    'checkCircle',
    shapes: [_circle(12, 12, 10), _polyline('16 9 11 14 8 11')],
  );
  static final chevronDown = IconData(
    'chevronDown',
    shapes: [_polyline('6 9 12 15 18 9')],
  );
  static final chevronLeft = IconData(
    'chevronLeft',
    shapes: [_polyline('15 18 9 12 15 6')],
  );
  static final chevronRight = IconData(
    'chevronRight',
    shapes: [_polyline('9 18 15 12 9 6')],
  );
  static final chevronUp = IconData(
    'chevronUp',
    shapes: [_polyline('18 15 12 9 6 15')],
  );
  static final clipboard = IconData(
    'clipboard',
    shapes: [
      _rect(5, 4, 14, 18, rx: 2),
      _path('M9 4a3 3 0 0 1 6 0'),
      _path('M9 4h6'),
    ],
  );
  static final clock = IconData(
    'clock',
    shapes: [_circle(12, 12, 10), _path('M12 6v6l4 2')],
  );
  static final cloud = IconData(
    'cloud',
    shapes: [
      _path(
        'M17.5 19H7a5 5 0 1 1 1.1-9.9A7 7 0 0 1 21 12.5 3.5 3.5 0 0 1 17.5 19z',
      ),
    ],
  );
  static final code = IconData(
    'code',
    shapes: [
      _polyline('8 9 4 12 8 15'),
      _polyline('16 9 20 12 16 15'),
      _path('M14 5l-4 14'),
    ],
  );
  static final component = IconData(
    'component',
    shapes: [
      _rect(3, 3, 7, 7, rx: 1),
      _rect(14, 3, 7, 7, rx: 1),
      _rect(3, 14, 7, 7, rx: 1),
      _rect(14, 14, 7, 7, rx: 1),
    ],
  );
  static final cog = IconData(
    'cog',
    shapes: [
      _circle(12, 12, 3),
      _path(
        'M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2 3-.2-.1a1.7 1.7 0 0 0-2 .1 7.8 7.8 0 0 1-1.6.7 1.7 1.7 0 0 0-1.1 1.5V22H9v-.2a1.7 1.7 0 0 0-1.1-1.5 7.8 7.8 0 0 1-1.6-.7 1.7 1.7 0 0 0-2-.1l-.2.1-2-3 .1-.1a1.7 1.7 0 0 0 .3-1.9 8 8 0 0 1 0-1.8 1.7 1.7 0 0 0-.3-1.9l-.1-.1 2-3 .2.1a1.7 1.7 0 0 0 2-.1 7.8 7.8 0 0 1 1.6-.7A1.7 1.7 0 0 0 9 5.6V5h4v.6a1.7 1.7 0 0 0 1.1 1.5 7.8 7.8 0 0 1 1.6.7 1.7 1.7 0 0 0 2 .1l.2-.1 2 3-.1.1a1.7 1.7 0 0 0-.3 1.9 8 8 0 0 1-.1 2.2z',
      ),
    ],
  );
  static final copy = IconData(
    'copy',
    shapes: [_rect(8, 8, 12, 12, rx: 2), _path('M16 8V4H4v12h4')],
  );
  static final creditCard = IconData(
    'creditCard',
    shapes: [
      _rect(2, 5, 20, 14, rx: 2),
      _line(2, 10, 22, 10),
      _path('M6 15h2'),
    ],
  );
  static final database = IconData(
    'database',
    shapes: [
      _ellipse(12, 5, 8, 3),
      _path('M4 5v6c0 1.7 3.6 3 8 3s8-1.3 8-3V5'),
      _path('M4 11v6c0 1.7 3.6 3 8 3s8-1.3 8-3v-6'),
    ],
  );
  static final document = IconData(
    'document',
    shapes: [
      _path('M6 2h8l4 4v16H6V2z'),
      _path('M14 2v5h5'),
      _path('M9 13h6'),
      _path('M9 17h6'),
    ],
  );
  static final download = IconData(
    'download',
    shapes: [
      _path('M12 3v12'),
      _polyline('7 10 12 15 17 10'),
      _path('M5 21h14'),
    ],
  );
  static final edit = IconData(
    'edit',
    shapes: [_path('M4 20h4L19 9l-4-4L4 16v4z'), _path('M13 7l4 4')],
  );
  static final eye = IconData(
    'eye',
    shapes: [
      _path('M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z'),
      _circle(12, 12, 3),
    ],
  );
  static final eyeOff = IconData(
    'eyeOff',
    shapes: [
      _path('M3 3l18 18'),
      _path('M10.6 10.6A2 2 0 0 0 13.4 13.4'),
      _path(
        'M9.9 4.2A10.8 10.8 0 0 1 12 4c6 0 10 8 10 8a18.6 18.6 0 0 1-3.1 4.2',
      ),
      _path('M6.2 6.2C3.6 8 2 12 2 12s4 8 10 8a10.6 10.6 0 0 0 4.1-.9'),
    ],
  );
  static final file = IconData(
    'file',
    shapes: [_path('M14 2H6v20h12V6l-4-4z'), _path('M14 2v5h5')],
  );
  static final filter = IconData(
    'filter',
    shapes: [_path('M3 5h18l-7 8v5l-4 2v-7L3 5z')],
  );
  static final folder = IconData(
    'folder',
    shapes: [_path('M3 6h7l2 2h9v11H3V6z')],
  );
  static final globe = IconData(
    'globe',
    shapes: [
      _circle(12, 12, 10),
      _path('M2 12h20'),
      _path('M12 2a15 15 0 0 1 0 20'),
      _path('M12 2a15 15 0 0 0 0 20'),
    ],
  );
  static final gauge = IconData(
    'gauge',
    shapes: [
      _path('M12 14l4-4'),
      _path('M3.34 19a10 10 0 1 1 17.32 0'),
      _path('M5 19h14'),
    ],
  );
  static final gitBranch = IconData(
    'gitBranch',
    shapes: [
      _circle(6, 3, 3),
      _circle(18, 6, 3),
      _circle(6, 21, 3),
      _path('M6 6v12'),
      _path('M9 18h3a6 6 0 0 0 6-6V9'),
    ],
  );
  static final grid = IconData(
    'grid',
    shapes: [
      _rect(3, 3, 7, 7),
      _rect(14, 3, 7, 7),
      _rect(14, 14, 7, 7),
      _rect(3, 14, 7, 7),
    ],
  );
  static final heart = IconData(
    'heart',
    shapes: [
      _path(
        'M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.6l-1-1a5.5 5.5 0 1 0-7.8 7.8l1 1L12 21l7.8-7.6 1-1a5.5 5.5 0 0 0 0-7.8z',
      ),
    ],
  );
  static final headphones = IconData(
    'headphones',
    shapes: [
      _path('M3 18v-6a9 9 0 0 1 18 0v6'),
      _path('M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3v5z'),
      _path('M3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3v5z'),
    ],
  );
  static final home = IconData(
    'home',
    shapes: [
      _path('M3 11 12 3l9 8'),
      _path('M5 10v11h14V10'),
      _path('M9 21v-7h6v7'),
    ],
  );
  static final inbox = IconData(
    'inbox',
    shapes: [_path('M4 4h16l2 10v6H2v-6L4 4z'), _path('M2 14h6l2 3h4l2-3h6')],
  );
  static final key = IconData(
    'key',
    shapes: [_circle(7, 17, 3), _path('M10 17h11v-3h-3v-3h-3v-3h-3l-4 4')],
  );
  static final laptop = IconData(
    'laptop',
    shapes: [_rect(4, 5, 16, 11, rx: 1), _path('M2 20h20l-2-4H4l-2 4z')],
  );
  static final layers = IconData(
    'layers',
    shapes: [
      _polygon('12 2 2 7 12 12 22 7 12 2'),
      _polyline('2 12 12 17 22 12'),
      _polyline('2 17 12 22 22 17'),
    ],
  );
  static final link = IconData(
    'link',
    shapes: [
      _path('M10 13a5 5 0 0 0 7 0l2-2a5 5 0 0 0-7-7l-1 1'),
      _path('M14 11a5 5 0 0 0-7 0l-2 2a5 5 0 0 0 7 7l1-1'),
    ],
  );
  static final list = IconData(
    'list',
    shapes: [
      _line(8, 6, 21, 6),
      _line(8, 12, 21, 12),
      _line(8, 18, 21, 18),
      _line(3, 6, 3, 6),
      _line(3, 12, 3, 12),
      _line(3, 18, 3, 18),
    ],
  );
  static final lifeBuoy = IconData(
    'lifeBuoy',
    shapes: [
      _circle(12, 12, 10),
      _circle(12, 12, 4),
      _line(4.93, 4.93, 9.17, 9.17),
      _line(14.83, 14.83, 19.07, 19.07),
      _line(14.83, 9.17, 19.07, 4.93),
      _line(4.93, 19.07, 9.17, 14.83),
    ],
  );
  static final lock = IconData(
    'lock',
    shapes: [_rect(5, 11, 14, 10, rx: 2), _path('M8 11V7a4 4 0 0 1 8 0v4')],
  );
  static final logIn = IconData(
    'logIn',
    shapes: [
      _path('M15 3h4v18h-4'),
      _path('M10 17l5-5-5-5'),
      _path('M15 12H3'),
    ],
  );
  static final logOut = IconData(
    'logOut',
    shapes: [_path('M9 21H5V3h4'), _path('M16 17l5-5-5-5'), _path('M21 12H9')],
  );
  static final mail = IconData(
    'mail',
    shapes: [_rect(3, 5, 18, 14, rx: 2), _path('M3 7l9 6 9-6')],
  );
  static final mapPin = IconData(
    'mapPin',
    shapes: [
      _path('M20 10c0 6-8 12-8 12S4 16 4 10a8 8 0 1 1 16 0z'),
      _circle(12, 10, 3),
    ],
  );
  static final menu = IconData(
    'menu',
    shapes: [_line(4, 6, 20, 6), _line(4, 12, 20, 12), _line(4, 18, 20, 18)],
  );
  static final message = IconData(
    'message',
    shapes: [
      _path('M21 15a4 4 0 0 1-4 4H8l-5 3V7a4 4 0 0 1 4-4h10a4 4 0 0 1 4 4v8z'),
    ],
  );
  static final minus = IconData('minus', shapes: [_line(5, 12, 19, 12)]);
  static final monitor = IconData(
    'monitor',
    shapes: [_rect(3, 4, 18, 12, rx: 2), _path('M8 20h8'), _path('M12 16v4')],
  );
  static final moon = IconData(
    'moon',
    shapes: [_path('M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z')],
  );
  static final moreHorizontal = IconData(
    'moreHorizontal',
    shapes: [_circle(5, 12, 1), _circle(12, 12, 1), _circle(19, 12, 1)],
  );
  static final package = IconData(
    'package',
    shapes: [
      _path('M21 16V8l-9-5-9 5v8l9 5 9-5z'),
      _path('M3.5 8.5 12 13l8.5-4.5'),
      _path('M12 22v-9'),
    ],
  );
  static final palette = IconData(
    'palette',
    shapes: [
      _path(
        'M12 3a9 9 0 0 0 0 18h1.5a2 2 0 0 0 1.3-3.5 1.8 1.8 0 0 1 1.2-3.2H18a6 6 0 0 0 0-12h-6z',
      ),
      _circle(7.5, 10, 1),
      _circle(10, 7, 1),
      _circle(14, 7, 1),
    ],
  );
  static final phone = IconData(
    'phone',
    shapes: [
      _path(
        'M22 16.9v3a2 2 0 0 1-2.2 2A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7l.4 2.6a2 2 0 0 1-.6 1.8L7.6 9.4a16 16 0 0 0 7 7l1.3-1.3a2 2 0 0 1 1.8-.6l2.6.4a2 2 0 0 1 1.7 2z',
      ),
    ],
  );
  static final play = IconData(
    'play',
    shapes: [_polygon('8 5 19 12 8 19 8 5')],
  );
  static final plus = IconData(
    'plus',
    shapes: [_line(12, 5, 12, 19), _line(5, 12, 19, 12)],
  );
  static final printer = IconData(
    'printer',
    shapes: [
      _path('M6 9V3h12v6'),
      _rect(6, 14, 12, 7),
      _path('M6 18H4a2 2 0 0 1-2-2v-5h20v5a2 2 0 0 1-2 2h-2'),
    ],
  );
  static final refresh = IconData(
    'refresh',
    shapes: [
      _path('M21 12a9 9 0 0 1-15.5 6.2'),
      _path('M3 18v-6h6'),
      _path('M3 12A9 9 0 0 1 18.5 5.8'),
      _path('M21 6v6h-6'),
    ],
  );
  static final rocket = IconData(
    'rocket',
    shapes: [
      _path('M5 15c-1 1-2 4-2 6 2 0 5-1 6-2'),
      _path('M9 15 4 10l5-1 6-6c2-2 5-1 6-1 0 1 1 4-1 6l-6 6-1 5-4-4z'),
      _circle(15, 9, 1.5),
    ],
  );
  static final route = IconData(
    'route',
    shapes: [
      _circle(6, 18, 3),
      _circle(18, 6, 3),
      _path('M9 18h4a5 5 0 0 0 0-10H9'),
    ],
  );
  static final save = IconData(
    'save',
    shapes: [
      _path('M5 3h12l2 2v16H5V3z'),
      _path('M8 3v6h8'),
      _path('M8 21v-7h8v7'),
    ],
  );
  static final search = IconData(
    'search',
    shapes: [_circle(11, 11, 7), _path('M21 21l-5-5')],
  );
  static final send = IconData(
    'send',
    shapes: [_path('M22 2 11 13'), _path('M22 2 15 22l-4-9-9-4 20-7z')],
  );
  static final server = IconData(
    'server',
    shapes: [
      _rect(3, 4, 18, 6, rx: 2),
      _rect(3, 14, 18, 6, rx: 2),
      _line(7, 7, 7, 7),
      _line(7, 17, 7, 17),
    ],
  );
  static final settings = IconData(
    'settings',
    shapes: [
      _circle(12, 12, 3),
      _path(
        'M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2 3-.2-.1a1.7 1.7 0 0 0-2 .1 7.8 7.8 0 0 1-1.6.7 1.7 1.7 0 0 0-1.1 1.5V22H9v-.2a1.7 1.7 0 0 0-1.1-1.5 7.8 7.8 0 0 1-1.6-.7 1.7 1.7 0 0 0-2-.1l-.2.1-2-3 .1-.1a1.7 1.7 0 0 0 .3-1.9 8 8 0 0 1 0-1.8 1.7 1.7 0 0 0-.3-1.9l-.1-.1 2-3 .2.1a1.7 1.7 0 0 0 2-.1 7.8 7.8 0 0 1 1.6-.7A1.7 1.7 0 0 0 9 5.6V5h4v.6a1.7 1.7 0 0 0 1.1 1.5 7.8 7.8 0 0 1 1.6.7 1.7 1.7 0 0 0 2 .1l.2-.1 2 3-.1.1a1.7 1.7 0 0 0-.3 1.9 8 8 0 0 1-.1 2.2z',
      ),
    ],
  );
  static final shield = IconData(
    'shield',
    shapes: [_path('M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z')],
  );
  static final shoppingCart = IconData(
    'shoppingCart',
    shapes: [
      _circle(9, 21, 1),
      _circle(20, 21, 1),
      _path('M1 1h4l2.6 13.4a2 2 0 0 0 2 1.6h8.8a2 2 0 0 0 2-1.6L23 6H6'),
    ],
  );
  static final sparkles = IconData(
    'sparkles',
    shapes: [
      _path('M12 3l1.8 4.2L18 9l-4.2 1.8L12 15l-1.8-4.2L6 9l4.2-1.8L12 3z'),
      _path('M5 14l1 2.2L8 17l-2 .8L5 20l-1-2.2L2 17l2-.8L5 14z'),
      _path('M19 13l1 2.2 2 .8-2 .8L19 19l-1-2.2-2-.8 2-.8L19 13z'),
    ],
  );
  static final star = IconData(
    'star',
    shapes: [
      _polygon(
        '12 2 15 8.5 22 9.3 17 14.2 18.2 21 12 17.6 5.8 21 7 14.2 2 9.3 9 8.5 12 2',
      ),
    ],
  );
  static final sun = IconData(
    'sun',
    shapes: [
      _circle(12, 12, 4),
      _line(12, 2, 12, 4),
      _line(12, 20, 12, 22),
      _line(4.9, 4.9, 6.3, 6.3),
      _line(17.7, 17.7, 19.1, 19.1),
      _line(2, 12, 4, 12),
      _line(20, 12, 22, 12),
      _line(4.9, 19.1, 6.3, 17.7),
      _line(17.7, 6.3, 19.1, 4.9),
    ],
  );
  static final tag = IconData(
    'tag',
    shapes: [_path('M20 13 13 20 4 11V4h7l9 9z'), _circle(8, 8, 1)],
  );
  static final terminal = IconData(
    'terminal',
    shapes: [_polyline('4 17 10 12 4 7'), _line(12, 19, 20, 19)],
  );
  static final trash = IconData(
    'trash',
    shapes: [
      _path('M3 6h18'),
      _path('M8 6V4h8v2'),
      _path('M6 6l1 16h10l1-16'),
      _line(10, 11, 10, 18),
      _line(14, 11, 14, 18),
    ],
  );
  static final trendingUp = IconData(
    'trendingUp',
    shapes: [
      _polyline('23 6 13.5 15.5 8.5 10.5 1 18'),
      _polyline('17 6 23 6 23 12'),
    ],
  );
  static final upload = IconData(
    'upload',
    shapes: [_path('M12 21V9'), _polyline('17 14 12 9 7 14'), _path('M5 3h14')],
  );
  static final user = IconData(
    'user',
    shapes: [_circle(12, 8, 4), _path('M4 22a8 8 0 0 1 16 0')],
  );
  static final userPlus = IconData(
    'userPlus',
    shapes: [
      _path('M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2'),
      _circle(9, 7, 4),
      _line(19, 8, 19, 14),
      _line(22, 11, 16, 11),
    ],
  );
  static final users = IconData(
    'users',
    shapes: [
      _path('M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2'),
      _circle(9, 7, 4),
      _path('M22 21v-2a4 4 0 0 0-3-3.9'),
      _path('M16 3.1a4 4 0 0 1 0 7.8'),
    ],
  );
  static final wallet = IconData(
    'wallet',
    shapes: [
      _path('M3 7h16a2 2 0 0 1 2 2v10H3V7z'),
      _path('M3 7l14-4v4'),
      _path('M16 13h5'),
    ],
  );
  static final wifi = IconData(
    'wifi',
    shapes: [
      _path('M5 13a10 10 0 0 1 14 0'),
      _path('M8.5 16.5a5 5 0 0 1 7 0'),
      _line(12, 20, 12, 20),
      _path('M2 9a14 14 0 0 1 20 0'),
    ],
  );
  static final x = IconData(
    'x',
    shapes: [_line(18, 6, 6, 18), _line(6, 6, 18, 18)],
  );
  static final zap = IconData(
    'zap',
    shapes: [_path('M13 2 3 14h8l-1 8 11-14h-8l0-6z')],
  );

  /// All built-in Flint UI icons in alphabetical order.
  static final all = <IconData>[
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
    clipboard,
    clock,
    cloud,
    code,
    component,
    cog,
    copy,
    creditCard,
    database,
    document,
    download,
    edit,
    eye,
    eyeOff,
    file,
    filter,
    folder,
    gauge,
    gitBranch,
    globe,
    grid,
    heart,
    headphones,
    home,
    inbox,
    key,
    laptop,
    layers,
    lifeBuoy,
    link,
    list,
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
    package,
    palette,
    phone,
    play,
    plus,
    printer,
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
    sparkles,
    star,
    sun,
    tag,
    terminal,
    trash,
    trendingUp,
    upload,
    user,
    userPlus,
    users,
    wallet,
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

IconShape _path(String d) => IconShape('path', {'d': d});

IconShape _polyline(String points) => IconShape('polyline', {'points': points});

IconShape _polygon(String points) => IconShape('polygon', {'points': points});

IconShape _line(num x1, num y1, num x2, num y2) =>
    IconShape('line', {'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2});

IconShape _circle(num cx, num cy, num r) =>
    IconShape('circle', {'cx': cx, 'cy': cy, 'r': r});

IconShape _ellipse(num cx, num cy, num rx, num ry) =>
    IconShape('ellipse', {'cx': cx, 'cy': cy, 'rx': rx, 'ry': ry});

IconShape _rect(num x, num y, num width, num height, {num? rx}) => IconShape(
  'rect',
  {'x': x, 'y': y, 'width': width, 'height': height, if (rx != null) 'rx': rx},
);
