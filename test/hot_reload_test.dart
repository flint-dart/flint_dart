import 'package:test/test.dart';

import '../bin/hot_reload.dart' as hot_reload;

void main() {
  test('extractServerWorkerPortFromLog reads worker port', () {
    expect(
      hot_reload.extractServerWorkerPortFromLog(
        '[FLINT] Server Worker running on http://localhost:3030 (PID: 8324)',
      ),
      3030,
    );
  });

  test('extractServerWorkerPortFromLog ignores unrelated lines', () {
    expect(
      hot_reload.extractServerWorkerPortFromLog('[HOT-RELOAD] Starting server'),
      isNull,
    );
  });
}
