import 'package:flint_dart/flint_ui.dart';
import 'package:test/test.dart';

void main() {
  group('DartStyle', () {
    test('compiles spacing, layout, and visual styles to css map', () {
      final style = DartStyle(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        width: 320,
        display: Display.flex,
        gap: 12,
        alignItems: AlignItems.center,
        justifyContent: JustifyContent.between,
        flex: const FlexValue.fill(),
        flexGrow: 1,
        flexShrink: 0,
        flexBasis: 12,
        background: '#fff',
        radius: 8,
        border: const Border.all(color: '#d0d5dd'),
        shadow: const Shadow(y: 4, blur: 12, color: 'rgba(16, 24, 40, 0.12)'),
      );

      expect(style.toMap(), {
        'padding': '16px',
        'margin': '0px 0px 12px',
        'width': '320px',
        'display': 'flex',
        'gap': '12px',
        'align-items': 'center',
        'justify-content': 'space-between',
        'flex': '1 1 auto',
        'flex-grow': '1',
        'flex-shrink': '0',
        'flex-basis': '12px',
        'background': '#fff',
        'border-radius': '8px',
        'border': '1px solid #d0d5dd',
        'box-shadow': '0px 4px 12px 0px rgba(16, 24, 40, 0.12)',
      });
    });

    test('supports flex value helpers', () {
      expect(const DartStyle(flex: FlexValue.grow()).toMap(), {'flex': '1 1 0%'});
      expect(const DartStyle(flex: FlexValue.auto()).toMap(), {'flex': '1 1 auto'});
      expect(const DartStyle(flex: FlexValue.none()).toMap(), {'flex': '0 0 auto'});
      expect(const DartStyle(flex: FlexValue(2, 0, SizeValue.auto)).toMap(), {
        'flex': '2 0 auto',
      });
    });

    test('supports size values without forcing pixels', () {
      final style = DartStyle(
        width: SizeValue.full,
        maxWidth: const SizeValue.rem(48),
        height: SizeValue.auto,
      );

      expect(style.toMap(), {
        'width': '100%',
        'height': 'auto',
        'max-width': '48rem',
      });
    });

    test('supports named gradients', () {
      const style = DartStyle(gradient: Gradients.ocean);

      expect(style.toMap(), {
        'background':
            'linear-gradient(135deg, #0ea5e9 0%, #2563eb 58%, #1d4ed8 100%)',
      });
    });

    test('supports color objects in gradient helpers', () {
      final style = DartStyle(
        gradient: Gradient.linear(135, const [
          GradientStop(Colors.sky500, 0),
          GradientStop(Colors.blue600, 58),
          GradientStop(Colors.blue700, 100),
        ]),
      );

      expect(style.toMap(), {
        'background':
            'linear-gradient(135deg, #0ea5e9 0%, #2563eb 58%, #1d4ed8 100%)',
      });
    });

    test('supports evenly distributed color gradients', () {
      final style = DartStyle(
        gradient: Gradient.linearColors(135, const [
          Colors.blue600,
          Colors.sky500,
        ]),
      );

      expect(style.toMap(), {
        'background': 'linear-gradient(135deg, #2563eb 0%, #0ea5e9 100%)',
      });
    });

    test('supports named colors and custom css colors', () {
      final style = DartStyle(
        color: Colors.slate900,
        background: Color.rgba(14, 165, 233, 0.12),
        border: Border.all(color: Colors.blue600),
        shadow: Shadow(y: 8, blur: 20, color: Color.rgba(15, 23, 42, 0.18)),
      );

      expect(style.toMap(), {
        'color': '#0f172a',
        'background': 'rgba(14, 165, 233, 0.12)',
        'border': '1px solid #2563eb',
        'box-shadow': '0px 8px 20px 0px rgba(15, 23, 42, 0.18)',
      });
    });

    test('supports advanced visual and media properties', () {
      final style = DartStyle(
        aspectRatio: 1,
        objectFit: ObjectFit.cover,
        overflow: Overflow.hidden,
        cursor: Cursor.pointer,
        resize: Resize.vertical,
        flexWrap: FlexWrap.wrap,
        transform: StyleTransform.translateX(SizeValue.percent(-50)),
        backdropFilter: StyleFilter.combine([
          StyleFilter.blur(16),
          StyleFilter.saturate(140),
        ]),
        maskImage: Gradient.linearTo(GradientDirection.bottom, const [
          GradientStop(Colors.transparent, 0),
          GradientStop(Colors.black, 15),
          GradientStop(Colors.black, 82),
          GradientStop(Colors.transparent, 100),
        ]),
        justifyItems: 'center',
        letterSpacing: const SizeValue('-0.02em'),
        textTransform: TextTransform.uppercase,
        borderTop: Border.all(color: Colors.slate200),
        borderBottom: Border.all(color: Colors.blue600),
        transition: StyleTransition.all(
          milliseconds: 220,
          timing: TransitionTiming.easeOut,
        ),
        animation: StyleAnimation.fadeIn(milliseconds: 240),
        willChange: WillChange.properties([
          WillChange.transform,
          WillChange.opacity,
        ]),
      );

      expect(style.toMap(), {
        'justify-items': 'center',
        'flex-wrap': 'wrap',
        'overflow': 'hidden',
        'aspect-ratio': '1',
        'object-fit': 'cover',
        'transform': 'translateX(-50%)',
        'backdrop-filter': 'blur(16px) saturate(140%)',
        'mask-image':
            'linear-gradient(to bottom, transparent 0%, #000000 15%, #000000 82%, transparent 100%)',
        'letter-spacing': '-0.02em',
        'text-transform': 'uppercase',
        'cursor': 'pointer',
        'resize': 'vertical',
        'border-top': '1px solid #e2e8f0',
        'border-bottom': '1px solid #2563eb',
        'transition': 'all 220ms ease-out',
        'animation': 'flint-fade-in 240ms ease-out 1 normal both running',
        'will-change': 'transform, opacity',
      });
    });

    test('supports typed background layers and gradients', () {
      final style = DartStyle(
        background: Background.layers([
          Gradient.radialCircle(
            at: const GradientPosition.percent(20, 0),
            stops: const [
              GradientStop(Color.rgba(79, 140, 255, 0.24)),
              GradientStop(Colors.transparent, 34),
            ],
          ),
          Gradient.linear(180, const [
            GradientStop(Color.rgba(18, 23, 34, 0.88)),
            GradientStop(Color.rgba(9, 11, 16, 0.76)),
          ]),
        ]),
      );

      expect(style.toMap(), {
        'background':
            'radial-gradient(circle at 20% 0%, rgba(79, 140, 255, 0.24), transparent 34%), linear-gradient(180deg, rgba(18, 23, 34, 0.88), rgba(9, 11, 16, 0.76))',
      });
    });

    test('supports root design globals', () {
      final design = RootDesign(
        name: 'app',
        all: const DartStyle(boxSizing: BoxSizing.borderBox),
        html: const DartStyle(scrollBehavior: ScrollBehavior.smooth),
        body: DartStyle(
          margin: const EdgeInsets.all(0),
          fontFamily: FontFamily.systemSans,
          letterSpacing: const SizeValue('-0.01em'),
          background: Background.layers([
            const Color('#090b10'),
            Gradient.linearColors(135, const [Colors.blue600, Colors.sky500]),
          ]),
        ),
        links: const DartStyle(
          color: Color('inherit'),
          textDecoration: TextDecorationStyle.none,
        ),
        keyframes: [
          StyleKeyframes.spin(),
          StyleKeyframes.fadeIn(),
          StyleKeyframes('flint-rise', [
            KeyframeStep.from(
              DartStyle(opacity: 0, transform: StyleTransform.translateY(8)),
            ),
            KeyframeStep.percent(
              70,
              DartStyle(opacity: 1, transform: StyleTransform.translateY(-1)),
            ),
            KeyframeStep.to(const DartStyle(opacity: 1)),
          ]),
        ],
      );

      expect(design.cssText, contains('* { box-sizing: border-box; }'));
      expect(design.cssText, contains('html { scroll-behavior: smooth; }'));
      expect(design.cssText, contains('body {'));
      expect(design.cssText, contains('margin: 0px'));
      expect(design.cssText, contains('font-family: Inter'));
      expect(design.cssText, contains('letter-spacing: -0.01em'));
      expect(design.cssText, contains('a { color: inherit'));
      expect(design.cssText, contains('text-decoration: none'));
      expect(design.cssText, contains('@keyframes flint-spin'));
      expect(design.cssText, contains('transform: rotate(360deg)'));
      expect(design.cssText, contains('@keyframes flint-fade-in'));
      expect(design.cssText, contains('@keyframes flint-rise'));
      expect(
        design.cssText,
        contains('70% { transform: translateY(-1px); opacity: 1'),
      );
    });

    test('supports typed grid template helpers', () {
      final heroColumns = GridTemplateColumns.tracks([
        GridTrack.minmax(SizeValue.zero, const SizeValue.fr(0.96)),
        GridTrack.minmax(420, GridTrack.oneFr),
      ]);
      final cardColumns = GridTemplateColumns.repeat(3, GridTrack.fluid);
      final autoFit = GridTemplateColumns.autoFit(220);

      expect(DartStyle(gridTemplateColumns: heroColumns).toMap(), {
        'grid-template-columns': 'minmax(0, 0.96fr) minmax(420px, 1fr)',
      });
      expect(DartStyle(gridTemplateColumns: cardColumns).toMap(), {
        'grid-template-columns': 'repeat(3, minmax(0, 1fr))',
      });
      expect(DartStyle(gridTemplateColumns: autoFit).toMap(), {
        'grid-template-columns': 'repeat(auto-fit, minmax(220px, 1fr))',
      });
    });

    test('createFlintApp collects root css on the VM', () {
      resetCollectedStyleCss();

      createFlintApp(
        '#app',
        rootDesign: RootDesign(
          name: 'test-root',
          theme: const FlintTheme(colors: {'ink': Color('#101828')}),
          body: DartStyle(color: ThemeToken.color('ink')),
        ),
        stylesheets: const [
          StyleSheet('test-sheet', {
            '.shell': StyleRule({'display': Display.flex}),
          }),
        ],
      );

      final css = consumeCollectedStyleCss();

      expect(css, contains('--color-ink: #101828'));
      expect(css, contains('body {'));
      expect(css, contains('.test-sheet-shell'));
      expect(consumeCollectedStyleCss(), isEmpty);
    });

    test('createFlintApp can configure a global built-in theme', () {
      resetCollectedStyleCss();

      createFlintApp('#app', themeMode: FlintThemeMode.dark);

      final css = consumeCollectedStyleCss();

      expect(css, contains('--color-page: #020617'));
      expect(css, contains(':root[data-theme="light"], [data-theme="light"]'));
      expect(css, contains(':root[data-theme="dark"], [data-theme="dark"]'));
    });

    test('createFlintApp can configure a global custom theme', () {
      resetCollectedStyleCss();

      createFlintApp(
        '#app',
        theme: const FlintTheme(colors: {'brand': Color('#7c3aed')}),
      );

      final css = consumeCollectedStyleCss();

      expect(css, contains('--color-brand: #7c3aed'));
    });

    test('createFlintApp does not apply theme when no theme is configured', () {
      resetCollectedStyleCss();
      localStorage.write(defaultFlintThemeStorageKey, 'dark');

      createFlintApp('#app');

      final css = consumeCollectedStyleCss();

      expect(css, isNot(contains('[data-theme="dark"]')));
      expect(css, isNot(contains('--color-page')));
      localStorage.clear();
    });

    test('supports theme tokens in root design and DartStyle', () {
      final theme = FlintTheme(
        colors: const {'primary': Colors.blue600, 'surface': Color('#121722')},
        spacing: const {'4': SizeValue.rem(1)},
        radii: const {'md': 8},
        shadows: const {
          'focus': Shadow(
            y: 0,
            blur: 0,
            spread: 3,
            color: Color.rgba(37, 99, 235, 0.28),
          ),
        },
        fonts: const {'sans': FontFamily.systemSans},
      );

      final design = RootDesign(theme: theme);
      final style = DartStyle(
        padding: EdgeInsets.all(ThemeToken.space('4')),
        background: ThemeToken.color('surface'),
        color: ThemeToken.color('primary'),
        radius: ThemeToken.radius('md'),
        shadow: Shadow(color: ThemeToken.color('primary')),
        fontFamily: ThemeToken.font('sans'),
        hover: DartStyle(color: ThemeToken.color('primary')),
      );

      expect(design.cssText, contains('--color-primary: #2563eb'));
      expect(design.cssText, contains('--color-surface: #121722'));
      expect(design.cssText, contains('--space-4: 1rem'));
      expect(design.cssText, contains('--radius-md: 8px'));
      expect(
        design.cssText,
        contains('--shadow-focus: 0px 0px 0px 3px rgba(37, 99, 235, 0.28)'),
      );
      expect(design.cssText, contains('--font-sans: Inter'));
      expect(style.toMap(), {
        'padding': 'var(--space-4)',
        'font-family': 'var(--font-sans)',
        'color': 'var(--color-primary)',
        'background': 'var(--color-surface)',
        'border-radius': 'var(--radius-md)',
        'box-shadow': '0px 1px 2px 0px var(--color-primary)',
      });
      expect(style.stateStyles[':hover']!.toMap(), {
        'color': 'var(--color-primary)',
      });
    });

    test('supports built-in light and dark theme provider tokens', () {
      const provider = FlintThemeProvider(initialMode: FlintThemeMode.dark);
      final design = RootDesign(themeProvider: provider);

      expect(design.cssText, contains(':root {'));
      expect(design.cssText, contains('--color-page: #020617'));
      expect(
        design.cssText,
        contains(':root[data-theme="light"], [data-theme="light"]'),
      );
      expect(
        design.cssText,
        contains(':root[data-theme="dark"], [data-theme="dark"]'),
      );
      expect(design.cssText, contains('--color-surface: #ffffff'));
      expect(design.cssText, contains('--color-surface: #0f172a'));
    });

    test('supports light and dark scoped DartStyle overrides', () {
      final style = DartStyle(
        color: ThemeToken.color('text'),
        background: ThemeToken.color('surface'),
        light: DartStyle(border: Border.all(color: Colors.slate200)),
        dark: DartStyle(
          border: Border.all(color: Color.rgba(148, 163, 184, 0.24)),
          shadow: const Shadow(
            y: 18,
            blur: 48,
            spread: -32,
            color: Color.rgba(0, 0, 0, 0.44),
          ),
        ),
      );

      expect(style.toMap(), {
        'color': 'var(--color-text)',
        'background': 'var(--color-surface)',
      });
      expect(style.hasScopedStyles, isTrue);
      expect(style.themeStyles[FlintThemeMode.light]!.toMap(), {
        'border': '1px solid #e2e8f0',
      });
      expect(style.themeStyles[FlintThemeMode.dark]!.toMap(), {
        'border': '1px solid rgba(148, 163, 184, 0.24)',
        'box-shadow': '0px 18px 48px -32px rgba(0, 0, 0, 0.44)',
      });
    });

    test('keeps breakpoint styles out of inline base styles', () {
      final style = DartStyle(
        width: 44,
        md: DartStyle(width: 52),
        lg: DartStyle(width: 64),
      );

      expect(style.toMap(), {'width': '44px'});
      expect(style.hasBreakpoints, isTrue);
      expect(style.hasScopedStyles, isTrue);
      expect(style.breakpointStyles[Breakpoint.md]!.toMap(), {'width': '52px'});
    });

    test('keeps state styles out of inline base styles', () {
      final style = DartStyle(
        color: Colors.slate900,
        hover: DartStyle(color: Colors.blue600),
        focusVisible: DartStyle(shadow: Shadow(color: Colors.blue600)),
        active: DartStyle(transform: StyleTransform.scale(0.98)),
        disabled: DartStyle(opacity: 0.5),
        selected: DartStyle(background: Colors.blue50),
        expanded: DartStyle(border: Border.all(color: Colors.blue600)),
        invalid: DartStyle(color: Colors.rose700),
      );

      expect(style.toMap(), {'color': '#0f172a'});
      expect(style.hasStateStyles, isTrue);
      expect(style.hasScopedStyles, isTrue);
      expect(style.stateStyles[':hover']!.toMap(), {'color': '#2563eb'});
      expect(style.stateStyles[':focus-visible']!.toMap(), {
        'box-shadow': '0px 1px 2px 0px #2563eb',
      });
      expect(style.stateStyles[':active']!.toMap(), {
        'transform': 'scale(0.98)',
      });
      expect(style.stateStyles[':disabled']!.toMap(), {'opacity': 0.5});
      expect(style.stateStyles['[aria-disabled="true"]']!.toMap(), {
        'opacity': 0.5,
      });
      expect(style.stateStyles['[aria-selected="true"]']!.toMap(), {
        'background': '#eff6ff',
      });
      expect(style.stateStyles['[aria-expanded="true"]']!.toMap(), {
        'border': '1px solid #2563eb',
      });
      expect(style.stateStyles['[aria-invalid="true"]']!.toMap(), {
        'color': '#be123c',
      });
    });
  });

  group('component prop helpers', () {
    test('mergeComponentProps merges classes and style in the right order', () {
      final props = mergeComponentProps(
        {
          'id': 'panel',
          'className': 'from-props',
          'style': {'padding': '24px', 'color': 'red'},
        },
        className: 'from-arg',
        defaultStyle: {'display': 'block', 'padding': '8px'},
        variantStyle: {'padding': '12px', 'background': '#f8fafc'},
        dartStyle: DartStyle(padding: EdgeInsets.all(16), color: '#111827'),
        style: {'background': '#fff'},
      );

      expect(props['id'], 'panel');
      expect(props['className'], 'from-props from-arg');
      expect(props['style'], {
        'display': 'block',
        'padding': '24px',
        'background': '#fff',
        'color': 'red',
      });
    });

    test('widgets accept className and dartStyle', () {
      final node = Column(
        className: 'stack',
        dartStyle: const DartStyle(gap: 10),
        style: {'padding': '12px'},
        children: [
          Container(child: 'Hello'),
          Button(child: Text('Save')),
        ],
      );

      expect(node.props['className'], 'stack');
      expect(node.props['style'], {
        'display': 'flex',
        'flex-direction': 'column',
        'gap': '10px',
        'padding': '12px',
      });
      expect(node.children.first, isA<Container>());
      expect(node.children.last, isA<Button>());
    });

    test('mergeComponentProps adds scoped responsive css', () {
      final props = mergeComponentProps(
        const {},
        dartStyle: DartStyle(
          width: 44,
          md: DartStyle(width: 52),
          lg: DartStyle(width: 64),
        ),
      );

      expect(props['className'], contains('flint-s-'));
      expect(props['style'], {'width': '44px'});
      expect(props['_flintStyleCss'], contains('@media (min-width: 768px)'));
      expect(props['_flintStyleCss'], contains('width: 52px !important'));
      expect(props['_flintStyleCss'], contains('@media (min-width: 1024px)'));
      expect(props['_flintStyleCss'], contains('width: 64px !important'));
    });

    test('mergeComponentProps adds scoped state css', () {
      final props = mergeComponentProps(
        const {},
        dartStyle: DartStyle(
          color: Colors.slate900,
          transition: StyleTransition.all(),
          hover: DartStyle(
            color: Colors.blue600,
            transform: StyleTransform.translateY(-2),
          ),
          focusVisible: DartStyle(
            shadow: Shadow(
              y: 0,
              blur: 0,
              spread: 3,
              color: Color.rgba(37, 99, 235, 0.28),
            ),
          ),
          active: DartStyle(transform: StyleTransform.scale(0.98)),
          disabled: DartStyle(opacity: 0.48),
        ),
      );

      expect(props['className'], contains('flint-s-'));
      expect(props['style'], {
        'color': '#0f172a',
        'transition': 'all 180ms ease',
      });
      expect(props['_flintStyleCss'], contains(':hover'));
      expect(props['_flintStyleCss'], contains('color: #2563eb !important'));
      expect(
        props['_flintStyleCss'],
        contains('transform: translateY(-2px) !important'),
      );
      expect(props['_flintStyleCss'], contains(':focus-visible'));
      expect(props['_flintStyleCss'], contains(':active'));
      expect(props['_flintStyleCss'], contains(':disabled'));
      expect(props['_flintStyleCss'], contains('[aria-disabled="true"]'));
      expect(props['_flintStyleCss'], contains('opacity: 0.48 !important'));
    });

    test('mergeComponentProps adds scoped light and dark css', () {
      final props = mergeComponentProps(
        const {},
        dartStyle: DartStyle(
          color: ThemeToken.color('text'),
          light: DartStyle(background: ThemeToken.color('surface')),
          dark: DartStyle(background: ThemeToken.color('surfaceMuted')),
        ),
      );

      expect(props['className'], contains('flint-s-'));
      expect(props['style'], {'color': 'var(--color-text)'});
      expect(props['_flintStyleCss'], contains('[data-theme="light"]'));
      expect(props['_flintStyleCss'], contains('[data-theme="dark"]'));
      expect(
        props['_flintStyleCss'],
        contains('background: var(--color-surface) !important'),
      );
      expect(
        props['_flintStyleCss'],
        contains('background: var(--color-surfaceMuted) !important'),
      );
    });
  });

  group('ThemeProvider', () {
    test('sets data-theme on its wrapper', () {
      final node =
          ThemeProvider(
                mode: FlintThemeMode.dark,
                child: Text('Dark mode'),
              ).build()
              as Container;

      expect(node.props['data-theme'], 'dark');
      expect(node.children.single, isA<Text>());
    });
  });
}
