import 'package:flint_dart/flint_ui_core.dart';
import 'package:test/test.dart';

void main() {
  group('data display components', () {
    test('Table renders headers, rows, actions, and selected state', () {
      final table = Table(
        columns: const [
          TableColumn(key: 'name', label: 'Name'),
          TableColumn(key: 'status', label: 'Status'),
        ],
        rows: [
          TableRowData(
            key: '1',
            selected: true,
            cells: {
              'name': 'Ada',
              'status': StatusBadge(label: 'Active', tone: Tone.success),
            },
            actions: Button(child: 'Edit'),
          ),
        ],
      );

      final tableNode = table.children.single as FlintElement;
      expect(tableNode.tag, 'table');
      final tbody = tableNode.children.last as FlintElement;
      final row = tbody.children.single as FlintElement;
      expect(row.props['data-row-key'], '1');
      expect(row.props['aria-selected'], 'true');
      expect(row.children, hasLength(3));
    });

    test('DataTable renders loading and empty states', () {
      final columns = const [TableColumn(key: 'name', label: 'Name')];

      final loading = DataTable(columns: columns, loading: true);
      expect(loading.children.single, isA<FlintElement>());

      final empty = DataTable(columns: columns);
      expect(empty.children.single, isA<EmptyState>());
    });

    test('Avatar renders initials or image', () {
      final initials = Avatar(name: 'Ada Lovelace');
      expect(initials.tag, 'span');
      expect((initials.children.single as FlintText).value, 'AL');

      final image = Avatar(name: 'Ada Lovelace', imageUrl: '/ada.png');
      expect(image.tag, 'img');
      expect(image.props['src'], '/ada.png');
      expect(image.props['alt'], 'Ada Lovelace');
    });

    test('DescriptionList renders dt/dd pairs', () {
      final list = DescriptionList(
        items: const [
          DescriptionItem(label: 'Plan', value: 'Pro'),
          DescriptionItem(label: 'Users', value: 12),
        ],
      );

      expect(list.tag, 'dl');
      expect(list.children, hasLength(4));
      expect((list.children.first as FlintElement).tag, 'dt');
      expect((list.children[1] as FlintElement).tag, 'dd');
    });

    test('ProgressBar and UsageMeter expose progress semantics', () {
      final progress = ProgressBar(value: 40, max: 80, label: 'Disk');
      expect(progress.props['role'], 'progressbar');
      expect(progress.props['aria-valuenow'], 40);
      expect(progress.props['aria-valuemax'], 80);

      final usage = UsageMeter(
        label: 'Storage',
        used: 25,
        limit: 100,
        unit: 'GB',
      );
      expect(usage.children.last, isA<ProgressBar>());
    });

    test('Timeline renders ordered activity items', () {
      final timeline = Timeline(
        items: const [
          TimelineItem(
            title: 'Provisioned',
            description: 'Server was created.',
            time: '10:30',
            tone: Tone.success,
          ),
        ],
      );

      expect(timeline.tag, 'ol');
      expect(timeline.children.single, isA<FlintElement>());
    });
  });
}
