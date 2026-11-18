import 'package:test/test.dart';
import 'dart:io';

import 'package:flint_dart/src/cli/web_ui_builder.dart';
import 'package:path/path.dart' as p;

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

  test('template hot reload names regular view templates from lib/views', () {
    expect(
      hot_reload.templateNameForHotReload(
        p.join('lib', 'views', 'admin', 'dashboard.flint.html'),
      ),
      'admin.dashboard',
    );
  });

  test('template hot reload supports mail templates outside lib/views', () {
    final name = hot_reload.templateNameForHotReload(
      p.join('lib', 'mail', 'views', 'service_cancellation_notice.flint.html'),
    );

    expect(name, 'mail.views.service_cancellation_notice');
    expect(name, isNot(contains('..')));
  });

  test('generated Flint UI JS is not treated as a web asset change', () {
    final build = FlintWebUiBuild(
      entry: File(p.join('lib', 'ui', 'main.dart')),
      uiDir: Directory(p.join('lib', 'ui')),
      webDir: Directory('public'),
      jsOut: p.join(
        'public',
        'assets',
        'js',
        'flint-ui',
        'main.dart.js',
      ),
    );

    expect(
      hot_reload.isHotReloadWebAsset(
        build,
        p.join(
          'public',
          'assets',
          'js',
          'flint-ui',
          'pages',
          'domain_pricing.dart.js',
        ),
      ),
      isFalse,
    );
    expect(
      hot_reload.isHotReloadWebAsset(
        build,
        p.join('public', 'flint-sw.js.gz'),
      ),
      isFalse,
    );
    expect(
      hot_reload.isHotReloadWebAsset(
        build,
        p.join('public', 'assets', 'js', 'site.js'),
      ),
      isTrue,
    );
  });
}
