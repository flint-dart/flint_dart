import 'package:flint_dart/flint_ui_core.dart';
import 'package:test/test.dart';

void main() {
  group('StyleSheet', () {
    test('generates namespaced class names and css rules', () {
      final sheet = StyleSheet('dashboard', {
        '.shell': const StyleRule({
          'display': 'grid',
          'grid-template-columns': '260px minmax(0, 1fr)',
        }),
      });

      expect(sheet.className('shell'), 'dashboard-shell');
      expect(sheet.className('.shell'), 'dashboard-shell');
      expect(sheet.cssText, contains('.dashboard-shell'));
      expect(sheet.cssText, contains('display: grid;'));
      expect(
        sheet.cssText,
        contains('grid-template-columns: 260px minmax(0, 1fr);'),
      );
    });

    test('resolves tokens and iterable css values', () {
      final sheet = StyleSheet(
        'button',
        {
          '.primary': StyleRule({
            'background': token('color.primary'),
            'border-radius': token('radius.sm'),
            'padding': [token('space.2'), 12],
          }),
        },
        tokens: const ThemeTokens({
          'color.primary': '#155eef',
          'radius.sm': '6px',
          'space.2': '8px',
        }),
      );

      expect(sheet.cssText, contains('background: #155eef;'));
      expect(sheet.cssText, contains('border-radius: 6px;'));
      expect(sheet.cssText, contains('padding: 8px 12px;'));
    });

    test('generates state and media rules', () {
      final sheet = StyleSheet('nav', {
        '.link': const StyleRule(
          {'color': '#344054'},
          hover: {'color': '#155eef'},
          selected: {'font-weight': 700},
        ),
        '@media (max-width: 760px)': const StyleRule.nested({
          '.link': {'display': 'none'},
        }),
      });

      expect(sheet.cssText, contains('.nav-link:hover'));
      expect(sheet.cssText, contains('.nav-link[aria-selected="true"]'));
      expect(sheet.cssText, contains('@media (max-width: 760px)'));
      expect(sheet.cssText, contains('display: none;'));
    });

    test('FlintThemes includes semantic tone tokens and generates aliases', () {
      final lightVars = FlintThemes.light.cssVariables;
      final darkVars = FlintThemes.dark.cssVariables;

      expect(lightVars.containsKey('--color-infoSoft'), true);
      expect(lightVars.containsKey('--color-infoSolid'), true);
      expect(lightVars.containsKey('--color-successSoft'), true);
      expect(lightVars.containsKey('--color-warningSoft'), true);
      expect(lightVars.containsKey('--color-dangerSoft'), true);

      expect(darkVars.containsKey('--color-infoSoft'), true);
      expect(darkVars.containsKey('--color-infoSolid'), true);
      expect(darkVars.containsKey('--color-successSoft'), true);
      expect(darkVars.containsKey('--color-warningSoft'), true);
      expect(darkVars.containsKey('--color-dangerSoft'), true);

      // Verify backwards-compatible flint-color aliases
      expect(darkVars.containsKey('--flint-color-surface'), true);
      expect(darkVars.containsKey('--flint-color-panel'), true);
      expect(darkVars.containsKey('--flint-color-surfaceBorder'), true);
      expect(darkVars.containsKey('--flint-color-line'), true);
      expect(darkVars.containsKey('--flint-color-text'), true);
      expect(darkVars.containsKey('--flint-color-ink'), true);
    });
  });
}
