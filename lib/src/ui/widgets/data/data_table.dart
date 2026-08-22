import '../../node.dart';
import '../../style.dart';
import '../feedback/spinner.dart';
import '../layout/empty_state.dart';
import 'table.dart';

/// Opinionated [Table] with default loading and empty states.
class DataTable extends Table {
  /// Creates a data table with Flint UI defaults.
  DataTable({
    required List<TableColumn> columns,
    List<TableRowData> rows = const [],
    bool loading = false,
    Object? emptyState,
    Object? loadingState,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
    String? tableClassName,
    Map<String, Object?> tableProps = const {},
    Map<String, Object?> tableStyle = const {},
    DartStyle? tableDartStyle,
    String? headerClassName,
    Map<String, Object?> headerStyle = const {},
    DartStyle? headerDartStyle,
    String? rowClassName,
    String? selectedRowClassName,
    Map<String, Object?> rowStyle = const {},
    Map<String, Object?> selectedRowStyle = const {},
    DartStyle? rowDartStyle,
    DartStyle? selectedRowDartStyle,
    String? cellClassName,
    Map<String, Object?> cellStyle = const {},
    DartStyle? cellDartStyle,
    void Function(Object event, TableRowData row)? onRowClick,
  }) : super(
         columns: columns,
         rows: rows,
         loading: loading,
         emptyState:
             emptyState ??
             EmptyState(
               title: 'No data',
               message: 'There are no records to show yet.',
             ),
         loadingState:
             loadingState ??
             FlintElement(
               'div',
               props: const {
                 'style': {
                   'display': 'flex',
                   'align-items': 'center',
                   'gap': '8px',
                   'padding': '16px',
                 },
               },
               children: [Spinner(), const FlintText('Loading data...')],
             ),
         className: className,
         props: props,
         style: style,
         dartStyle: dartStyle,
         tableClassName: tableClassName,
         tableProps: tableProps,
         tableStyle: tableStyle,
         tableDartStyle: tableDartStyle,
         headerClassName: headerClassName,
         headerStyle: headerStyle,
         headerDartStyle: headerDartStyle,
         rowClassName: rowClassName,
         selectedRowClassName: selectedRowClassName,
         rowStyle: rowStyle,
         selectedRowStyle: selectedRowStyle,
         rowDartStyle: rowDartStyle,
         selectedRowDartStyle: selectedRowDartStyle,
         cellClassName: cellClassName,
         cellStyle: cellStyle,
         cellDartStyle: cellDartStyle,
         onRowClick: onRowClick,
       );
}
