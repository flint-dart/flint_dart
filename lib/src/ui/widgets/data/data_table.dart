import '../../node.dart';
import '../feedback/spinner.dart';
import '../layout/empty_state.dart';
import 'table.dart';

/// Opinionated [Table] with default loading and empty states.
class DataTable extends Table {
  /// Creates a data table with Flint UI defaults.
  DataTable({
    required super.columns,
    super.rows = const [],
    super.loading = false,
    Object? emptyState,
    Object? loadingState,
    super.className,
    super.props = const {},
    super.style = const {},
    super.dartStyle,
    super.tableClassName,
    super.tableProps = const {},
    super.tableStyle = const {},
    super.tableDartStyle,
    super.headerClassName,
    super.headerStyle = const {},
    super.headerDartStyle,
    super.rowClassName,
    super.selectedRowClassName,
    super.rowStyle = const {},
    super.selectedRowStyle = const {},
    super.rowDartStyle,
    super.selectedRowDartStyle,
    super.cellClassName,
    super.cellStyle = const {},
    super.cellDartStyle,
    super.onRowClick,
  }) : super(
          emptyState: emptyState ??
              EmptyState(
                title: 'No data',
                message: 'There are no records to show yet.',
              ),
          loadingState: loadingState ??
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
        );
}
