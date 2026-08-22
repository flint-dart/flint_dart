import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../shared/theme.dart';

/// Circular user avatar that renders an image or initials.
class Avatar extends FlintElement {
  /// Creates an avatar for [name].
  Avatar({
    required String name,
    String? imageUrl,
    ComponentSize size = ComponentSize.md,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         imageUrl == null ? 'span' : 'img',
         props: mergeComponentProps(
           {
             ...props,
             if (imageUrl != null) ...{
               'src': imageUrl,
               'alt': name,
             } else
               'aria-label': name,
           },
           className: className,
           defaultStyle: {
             'display': 'inline-flex',
             'align-items': 'center',
             'justify-content': 'center',
             'width': _avatarSize(size),
             'height': _avatarSize(size),
             'border-radius': '999px',
             'background': '#eff4ff',
             'color': '#1849a9',
             'font-weight': 700,
             'object-fit': 'cover',
           },
           dartStyle: dartStyle,
           style: style,
         ),
         children: imageUrl == null ? [FlintText(_initials(name))] : const [],
       );
}

String _avatarSize(ComponentSize size) {
  return switch (size) {
    ComponentSize.xs => '24px',
    ComponentSize.sm => '32px',
    ComponentSize.md => '40px',
    ComponentSize.lg => '48px',
  };
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return initials.isEmpty ? '?' : initials;
}
