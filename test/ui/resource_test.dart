import 'package:flint_dart/flint_ui_core.dart';
import 'package:test/test.dart';

void main() {
  group('ResourceController', () {
    test('loads data into a success snapshot', () async {
      var calls = 0;
      final resource = ResourceController<List<String>>(
        loader: () async {
          calls++;
          return ['starter', 'pro'];
        },
      );

      expect(resource.snapshot.status, ResourceStatus.idle);

      final data = await resource.load();

      expect(calls, 1);
      expect(data, ['starter', 'pro']);
      expect(resource.snapshot.status, ResourceStatus.success);
      expect(resource.snapshot.data, ['starter', 'pro']);
      expect(resource.snapshot.error, isNull);
    });

    test('keeps previous data when a refresh fails', () async {
      var shouldFail = false;
      final resource = ResourceController<int>(
        initialData: 1,
        loader: () async {
          if (shouldFail) throw StateError('offline');
          return 2;
        },
      );

      await resource.load();
      shouldFail = true;
      await resource.refresh(silent: true);

      expect(resource.snapshot.status, ResourceStatus.error);
      expect(resource.snapshot.data, 2);
      expect(resource.snapshot.error, isA<StateError>());
    });

    test('mutates local data', () {
      final resource = ResourceController<List<String>>(
        initialData: const ['starter'],
        loader: () async => const [],
      );

      resource.mutate((items) => [...items ?? const [], 'business']);

      expect(resource.snapshot.data, ['starter', 'business']);
    });
  });

  group('FlintModelRecord', () {
    test('reads typed model attributes', () {
      const record = FlintModelRecord({
        'id': '42',
        'name': 'Business',
        'disk_limit': '100',
        'price': '12.5',
      });

      expect(record.id, '42');
      expect(record.string('name'), 'Business');
      expect(record.integer('disk_limit'), 100);
      expect(record.decimal('price'), 12.5);
    });
  });
}
