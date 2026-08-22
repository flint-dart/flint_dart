import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import '../shared/theme.dart';

/// Pagination controls with page summary and sibling page buttons.
class Pagination extends FlintElement {
  /// Creates pagination for [total] items.
  Pagination({
    required int page,
    required int pageSize,
    required int total,
    int siblingCount = 1,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
    void Function(Object event, int page)? onChanged,
  }) : super(
         'nav',
         props: mergeComponentProps(
           {...props, 'aria-label': props['aria-label'] ?? 'Pagination'},
           className: className,
           defaultStyle: const {
             'display': 'flex',
             'align-items': 'center',
             'justify-content': 'space-between',
             'gap': '12px',
           },
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           FlintElement(
             'span',
             props: const {
               'style': {'font-size': '13px', 'color': '#667085'},
             },
             children: normalizeChildren(
               _summary(page: page, pageSize: pageSize, total: total),
               const [],
             ),
           ),
           FlintElement(
             'div',
             props: const {
               'style': {
                 'display': 'flex',
                 'align-items': 'center',
                 'gap': '6px',
               },
             },
             children: [
               _button(
                 'Previous',
                 page - 1,
                 disabled: page <= 1,
                 onChanged: onChanged,
               ),
               for (final pageNumber in _pages(
                 page,
                 pageSize,
                 total,
                 siblingCount,
               ))
                 _button(
                   pageNumber.toString(),
                   pageNumber,
                   current: pageNumber == page,
                   onChanged: onChanged,
                 ),
               _button(
                 'Next',
                 page + 1,
                 disabled: page >= _pageCount(pageSize, total),
                 onChanged: onChanged,
               ),
             ],
           ),
         ],
       );

  static FlintElement _button(
    String label,
    int targetPage, {
    bool current = false,
    bool disabled = false,
    void Function(Object event, int page)? onChanged,
  }) {
    return FlintElement(
      'button',
      props: mergeComponentProps(
        {
          'type': 'button',
          if (current) 'aria-current': 'page',
          if (disabled) 'disabled': true,
          if (onChanged != null && !disabled)
            'onClick': (Object event) => onChanged(event, targetPage),
        },
        dartStyle:
            buttonComponentStyle(
              variant: current ? ButtonVariant.soft : ButtonVariant.outline,
              tone: current ? Tone.primary : Tone.neutral,
              size: ComponentSize.sm,
              disabled: disabled,
              loading: false,
            ).merge(
              const DartStyle(
                minWidth: 34,
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
      ),
      children: normalizeChildren(label, const []),
    );
  }

  static List<int> _pages(int page, int pageSize, int total, int siblingCount) {
    final count = _pageCount(pageSize, total);
    final start = (page - siblingCount).clamp(1, count);
    final end = (page + siblingCount).clamp(1, count);
    return [for (var i = start; i <= end; i++) i];
  }

  static int _pageCount(int pageSize, int total) {
    if (pageSize <= 0) return 1;
    final count = (total / pageSize).ceil();
    return count < 1 ? 1 : count;
  }

  static String _summary({
    required int page,
    required int pageSize,
    required int total,
  }) {
    if (total <= 0) return '0 results';
    final start = ((page - 1) * pageSize) + 1;
    final end = (start + pageSize - 1).clamp(1, total);
    return '$start-$end of $total';
  }
}
