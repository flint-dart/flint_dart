import 'package:flint_dart/flint_ui.dart';
import 'package:test/test.dart';

void main() {
  group('FlintEvent', () {
    test('is exported from the public Flint UI API', () {
      expect(FlintEvent.isBrowserEvent(null), isFalse);
      expect(FlintEvent.target(null), isNull);
      expect(FlintEvent.value(null), '');
      expect(FlintEvent.checked(null), isFalse);

      FlintEvent.preventDefault(null);
      FlintEvent.stopPropagation(null);
    });

    test('legacy helper functions delegate safely', () {
      expect(isFlintBrowserEvent(null), isFalse);
      expect(flintEventTarget(null), isNull);
      expect(flintEventTargetValue(null), '');
      expect(flintEventTargetChecked(null), isFalse);

      flintPreventDefault(null);
      flintStopPropagation(null);
    });
  });
}
