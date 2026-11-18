import 'package:flint_dart/ui.dart';
import 'package:test/test.dart';

void main() {
  group('Theme Consistency & Default Token Audit', () {
    test('Drawer resolves surface tokens instead of hardcoded white', () {
      final drawer = Drawer(open: true, title: 'Settings', child: 'Content');
      final element = drawer.build() as FlintElement;
      final style = element.props['style'] as Map<String, Object?>?;
      expect(style?['background'], contains('var(--color-surface'));
      expect(style?['color'], contains('var(--color-text'));

      final header = element.children.first as FlintElement;
      final headerStyle = header.props['style'] as Map<String, Object?>?;
      expect(headerStyle?['border-bottom'], contains('var(--color-surfaceBorder'));
    });

    test('Popover floating panel resolves surface tokens and supports panelStyle', () {
      final popover = Popover(
        open: true,
        trigger: 'Open',
        panelStyle: {'z-index': 99},
        child: 'Menu',
      );
      final built = popover.build() as FlintElement;
      final panel = built.children[1] as FlintElement;
      final panelStyle = panel.props['style'] as Map<String, Object?>?;
      expect(panelStyle?['background'], contains('var(--color-surface'));
      expect(panelStyle?['color'], contains('var(--color-text'));
      expect(panelStyle?['border'], contains('var(--color-surfaceBorder'));
      expect(panelStyle?['z-index'], 99);
    });

    test('Toast resolves surface tokens instead of hardcoded white', () {
      final toast = Toast(title: 'Saved');
      final style = toast.props['style'] as Map<String, Object?>?;
      expect(style?['background'], contains('var(--color-surface'));
    });

    test('Skeleton uses surfaceMuted token instead of hardcoded grey', () {
      final skeleton = Skeleton();
      final span = skeleton.children.first as FlintElement;
      final spanStyle = span.props['style'] as Map<String, Object?>?;
      expect(spanStyle?['background'], contains('var(--color-surfaceMuted'));
    });

    test('AppShell resolves page and surface tokens', () {
      final shell = AppShell(
        sidebar: 'Sidebar',
        brand: 'Flint',
        child: 'Page',
      );
      final shellStyle = shell.props['style'] as Map<String, Object?>?;
      expect(shellStyle?['background'], contains('var(--color-page'));
      expect(shellStyle?['color'], contains('var(--color-pageText'));

      final aside = shell.children.first as FlintElement;
      final asideStyle = aside.props['style'] as Map<String, Object?>?;
      expect(asideStyle?['background'], contains('var(--color-surface'));
      expect(asideStyle?['border-right'], contains('var(--color-surfaceBorder'));
    });

    test('Topbar resolves surface, text, and muted tokens', () {
      final topbar = Topbar(title: 'Dashboard', subtitle: 'Overview');
      final style = topbar.props['style'] as Map<String, Object?>?;
      expect(style?['background'], contains('var(--color-surface'));
      expect(style?['border-bottom'], contains('var(--color-surfaceBorder'));
      expect(style?['color'], contains('var(--color-text'));
    });

    test('Sidebar resolves text and primarySoft tokens for active and inactive links', () {
      final sidebar = Sidebar(
        items: const [
          SidebarItem(label: 'Home', href: '/', active: true),
          SidebarItem(label: 'Settings', href: '/settings', active: false),
        ],
      );
      final activeLink = sidebar.children[0] as FlintElement;
      final inactiveLink = sidebar.children[1] as FlintElement;

      final activeStyle = activeLink.props['style'] as Map<String, Object?>?;
      final inactiveStyle = inactiveLink.props['style'] as Map<String, Object?>?;

      expect(activeStyle?['color'], contains('var(--color-primaryText'));
      expect(activeStyle?['background'], contains('var(--color-primarySoft'));
      expect(inactiveStyle?['color'], contains('var(--color-text'));
    });

    test('Divider defaults to surfaceBorder token', () {
      final divider = Divider();
      final style = divider.props['style'] as Map<String, Object?>?;
      expect(style?['background'], contains('var(--color-surfaceBorder'));
    });

    test('StatCard resolves muted and text tokens', () {
      final card = StatCard(label: 'Users', value: 120);
      final headerSpan = (card.children[0] as FlintElement).children[0] as FlintElement;
      final headerStyle = headerSpan.props['style'] as Map<String, Object?>?;
      expect(headerStyle?['color'], contains('var(--color-muted'));
    });

    test('Section resolves text and muted tokens for header and description', () {
      final section = Section(title: 'Account', description: 'Manage profile');
      final header = section.children.first as FlintElement;
      final div = header.children.first as FlintElement;
      final h2 = div.children[0] as FlintElement;
      final p = div.children[1] as FlintElement;

      expect(h2.props['style']?.toString(), contains('var(--color-text'));
      expect(p.props['style']?.toString(), contains('var(--color-muted'));
    });

    test('DescriptionList resolves muted and text tokens', () {
      final dl = DescriptionList(
        items: const [DescriptionItem(label: 'Status', value: 'Active')],
      );
      final dt = dl.children[0] as FlintElement;
      final dd = dl.children[1] as FlintElement;

      expect(dt.props['style']?.toString(), contains('var(--color-muted'));
      expect(dd.props['style']?.toString(), contains('var(--color-text'));
    });

    test('SearchBox input resolves inputBorder, inputSurface, and inputText tokens', () {
      final search = SearchBox(label: 'Search');
      final input = search.children[1] as FlintElement;
      final inputStyle = input.props['style'] as Map<String, Object?>?;

      expect(inputStyle?['border'], contains('var(--color-inputBorder'));
      expect(inputStyle?['background'], contains('var(--color-inputSurface'));
      expect(inputStyle?['color'], contains('var(--color-inputText'));
    });

    test('Breadcrumbs resolves muted, text, and primaryText tokens', () {
      final breadcrumbs = Breadcrumbs(
        items: const [
          BreadcrumbItem(label: 'Home', href: '/'),
          BreadcrumbItem(label: 'Current', current: true),
        ],
      );
      final ol = breadcrumbs.children.first as FlintElement;
      final separator = ol.children[1] as FlintElement;
      expect(separator.props['style']?.toString(), contains('var(--color-muted'));
    });

    test('Tabs resolves surfaceBorder and muted tokens', () {
      final tabs = Tabs(
        tabs: const [TabItem(key: 'a', label: 'Tab A')],
      );
      final style = tabs.props['style'] as Map<String, Object?>?;
      expect(style?['border-bottom'], contains('var(--color-surfaceBorder'));
    });

    test('Avatar initials resolve primarySoft and primaryText tokens', () {
      final avatar = Avatar(name: 'Ada Lovelace');
      final style = avatar.props['style'] as Map<String, Object?>?;
      expect(style?['background'], contains('var(--color-primarySoft'));
      expect(style?['color'], contains('var(--color-primaryText'));
    });

    test('ProgressBar resolves surfaceMuted token', () {
      final bar = ProgressBar(value: 50);
      final track = bar.children.first as FlintElement;
      final trackStyle = track.props['style'] as Map<String, Object?>?;
      expect(trackStyle?['background'], contains('var(--color-surfaceMuted'));
    });

    test('Switch resolves text, primarySolid, and surfaceMuted tokens', () {
      expect(switchRowStyle['color'], contains('var(--color-text'));
      expect(switchTrackOnStyle['background'], contains('var(--color-primarySolid'));
      expect(switchTrackOffStyle['background'], contains('var(--color-surfaceMuted'));
    });

    test('FlintThemes includes infoSoftHover and backwards-compatible aliases', () {
      final light = FlintThemes.light.cssVariables;
      final dark = FlintThemes.dark.cssVariables;

      expect(light.containsKey('--color-infoSoftHover'), true);
      expect(dark.containsKey('--color-infoSoftHover'), true);
      expect(dark.containsKey('--color-mutedText'), true);
      expect(dark.containsKey('--color-navText'), true);
      expect(dark.containsKey('--color-docsText'), true);
    });
  });
}
