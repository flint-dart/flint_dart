import '../../style.dart';

/// Semantic tone used by shared widget theme helpers.
enum Tone {
  /// Neutral tone for default UI surfaces and actions.
  neutral,

  /// Primary brand/action tone.
  primary,

  /// Success or positive status tone.
  success,

  /// Warning or caution status tone.
  warning,

  /// Danger or destructive status tone.
  danger,

  /// Informational status tone.
  info,
}

/// Shared component size scale.
enum ComponentSize {
  /// Extra-small component size.
  xs,

  /// Small component size.
  sm,

  /// Medium component size.
  md,

  /// Large component size.
  lg,
}

/// Visual variants for button-like actions.
enum ButtonVariant {
  /// Filled button with solid tone color.
  solid,

  /// Soft button with tinted background.
  soft,

  /// Outlined button with transparent background.
  outline,

  /// Minimal button with transparent background and border.
  ghost,
}

/// Visual variants for badges and status pills.
enum BadgeVariant {
  /// Soft badge with tinted background.
  soft,

  /// Outlined badge with transparent background.
  outline,

  /// Solid badge with filled tone color.
  solid,
}

/// Visual variants for card-like surfaces.
enum CardVariant {
  /// Outlined card surface.
  outline,

  /// Elevated card surface with shadow.
  elevated,

  /// Soft tinted card surface.
  soft,

  /// Ghost card with transparent surface.
  ghost,
}

/// Visual variants for form inputs.
enum InputVariant {
  /// Outlined input surface.
  outline,

  /// Soft input surface.
  soft,

  /// Ghost input with transparent surface.
  ghost,
}

/// Visual variants for navigation items.
enum NavVariant {
  /// Underlined navigation item.
  underline,

  /// Pill-shaped navigation item.
  pill,

  /// Ghost navigation item.
  ghost,
}

/// Base style shared by button-like components.
final buttonBaseStyle = DartStyle(
  display: Display.inlineFlex,
  alignItems: AlignItems.center,
  justifyContent: JustifyContent.center,
  gap: 8,
  radius: 8,
  border: Border.all(color: Colors.transparent),
  fontWeight: 600,
  textDecoration: TextDecorationStyle.none,
  cursor: Cursor.pointer,
  transition: StyleTransition.colors(milliseconds: 120),
);

/// Resolves a complete button style from variant, tone, size, and state.
DartStyle buttonComponentStyle({
  required ButtonVariant variant,
  required Tone tone,
  required ComponentSize size,
  required bool disabled,
  required bool loading,
}) {
  final base = buttonBaseStyle
      .merge(buttonSizeStyle(size))
      .merge(buttonVariantStyle(variant, tone))
      .merge(
        disabled || loading
            ? const DartStyle(opacity: 0.55, cursor: Cursor.notAllowed)
            : DartStyle(
                hover: buttonHoverStyle(variant, tone),
                active: DartStyle(transform: StyleTransform.scale(0.98)),
                focusVisible: DartStyle(
                  shadow: Shadow(
                    y: 0,
                    blur: 0,
                    spread: 3,
                    color: toneFocus(tone),
                  ),
                ),
              ),
      );

  return base;
}

/// Resolves button sizing styles for [size].
DartStyle buttonSizeStyle(ComponentSize size) {
  return switch (size) {
    ComponentSize.xs => const DartStyle(
      minHeight: 28,
      padding: EdgeInsets.symmetric(horizontal: 8),
      fontSize: 12,
    ),
    ComponentSize.sm => const DartStyle(
      minHeight: 34,
      padding: EdgeInsets.symmetric(horizontal: 12),
      fontSize: 13,
    ),
    ComponentSize.md => const DartStyle(
      minHeight: 40,
      padding: EdgeInsets.symmetric(horizontal: 14),
      fontSize: 14,
    ),
    ComponentSize.lg => const DartStyle(
      minHeight: 46,
      padding: EdgeInsets.symmetric(horizontal: 18),
      fontSize: 15,
    ),
  };
}

/// Resolves badge sizing styles for [size].
DartStyle badgeSizeStyle(ComponentSize size) {
  return switch (size) {
    ComponentSize.xs => const DartStyle(
      minHeight: 20,
      padding: EdgeInsets.symmetric(horizontal: 7),
      fontSize: 11,
    ),
    ComponentSize.sm => const DartStyle(
      minHeight: 24,
      padding: EdgeInsets.symmetric(horizontal: 9),
      fontSize: 12,
    ),
    ComponentSize.md => const DartStyle(
      minHeight: 28,
      padding: EdgeInsets.symmetric(horizontal: 10),
      fontSize: 13,
    ),
    ComponentSize.lg => const DartStyle(
      minHeight: 32,
      padding: EdgeInsets.symmetric(horizontal: 12),
      fontSize: 14,
    ),
  };
}

/// Resolves button variant styles for [variant] and [tone].
DartStyle buttonVariantStyle(ButtonVariant variant, Tone tone) {
  return switch (variant) {
    ButtonVariant.solid => DartStyle(
      background: toneSolid(tone),
      border: Border.all(color: toneSolid(tone)),
      color: toneOnSolid(tone),
    ),
    ButtonVariant.soft => DartStyle(
      background: toneSoft(tone),
      border: Border.all(color: toneSoft(tone)),
      color: toneText(tone),
    ),
    ButtonVariant.outline => DartStyle(
      background: Colors.transparent,
      border: Border.all(color: toneBorder(tone)),
      color: toneText(tone),
    ),
    ButtonVariant.ghost => DartStyle(
      background: Colors.transparent,
      border: const Border.all(color: Colors.transparent),
      color: toneText(tone),
    ),
  };
}

/// Resolves button hover styles for [variant] and [tone].
DartStyle buttonHoverStyle(ButtonVariant variant, Tone tone) {
  return switch (variant) {
    ButtonVariant.solid => DartStyle(
      background: toneSolidHover(tone),
      border: Border.all(color: toneSolidHover(tone)),
    ),
    ButtonVariant.soft => DartStyle(
      background: toneSoftHover(tone),
      border: Border.all(color: toneSoftHover(tone)),
    ),
    ButtonVariant.outline => DartStyle(background: toneSoft(tone)),
    ButtonVariant.ghost => DartStyle(background: toneSoft(tone)),
  };
}

/// Resolves a complete badge style from variant, tone, and size.
DartStyle badgeComponentStyle({
  required BadgeVariant variant,
  required Tone tone,
  required ComponentSize size,
}) {
  return const DartStyle(
    display: Display.inlineFlex,
    alignItems: AlignItems.center,
    gap: 6,
    radius: SizeValue('999px'),
    fontWeight: 600,
  ).merge(badgeSizeStyle(size)).merge(switch (variant) {
    BadgeVariant.soft => DartStyle(
      border: Border.all(color: toneBorder(tone)),
      background: toneSoft(tone),
      color: toneText(tone),
    ),
    BadgeVariant.outline => DartStyle(
      border: Border.all(color: toneBorder(tone)),
      background: Colors.transparent,
      color: toneText(tone),
    ),
    BadgeVariant.solid => DartStyle(
      border: Border.all(color: toneSolid(tone)),
      background: toneSolid(tone),
      color: toneOnSolid(tone),
    ),
  });
}

/// Resolves a complete card style from variant and tone.
DartStyle cardComponentStyle({
  required CardVariant variant,
  required Tone tone,
}) {
  final base = DartStyle(
    display: Display.grid,
    gap: 12,
    radius: ThemeToken.radius('md', fallback: '8px').toCss(),
    padding: EdgeInsets.all(
      ThemeToken.space('cardPadding', fallback: '16px').toCss(),
    ),
    transition: StyleTransition.colors(milliseconds: 120),
  );

  return base.merge(switch (variant) {
    CardVariant.outline => DartStyle(
      border: Border.all(color: toneBorder(tone)),
      background: ThemeToken.color('surface', fallback: '#ffffff').toCss(),
    ),
    CardVariant.elevated => DartStyle(
      border: Border.all(
        color: ThemeToken.color('surfaceBorder', fallback: '#e4e7ec').toCss(),
      ),
      background: ThemeToken.color('surface', fallback: '#ffffff').toCss(),
      shadow: Shadow(
        y: 8,
        blur: 24,
        spread: -8,
        color: ThemeToken.shadow(
          'card',
          fallback: 'rgba(16, 24, 40, 0.18)',
        ).toCss(),
      ),
    ),
    CardVariant.soft => DartStyle(
      border: Border.all(color: toneBorder(tone)),
      background: toneSoft(tone),
    ),
    CardVariant.ghost => DartStyle(
      border: const Border.all(color: Colors.transparent),
      background: Colors.transparent,
    ),
  });
}

/// Resolves a complete input style from variant, size, and state.
DartStyle inputComponentStyle({
  required InputVariant variant,
  required ComponentSize size,
  required bool disabled,
  required bool invalid,
}) {
  final base = DartStyle(
    width: SizeValue.full,
    border: Border.all(
      color: ThemeToken.color('inputBorder', fallback: '#d0d5dd').toCss(),
    ),
    radius: ThemeToken.radius('md', fallback: '8px').toCss(),
    fontFamily: FontFamily.systemSans,
    color: ThemeToken.color('inputText', fallback: '#101828').toCss(),
    background: ThemeToken.color('inputSurface', fallback: '#ffffff').toCss(),
    transition: StyleTransition.colors(milliseconds: 120),
    focusVisible: DartStyle(
      border: Border.all(
        color: ThemeToken.color('primarySolid', fallback: '#155eef').toCss(),
      ),
      shadow: Shadow(
        y: 0,
        blur: 0,
        spread: 3,
        color: ThemeToken.color('primaryFocus', fallback: '#155eef').toCss(),
      ),
    ),
    invalid: DartStyle(
      border: Border.all(
        color: ThemeToken.color('dangerSolid', fallback: '#d92d20').toCss(),
      ),
      shadow: Shadow(
        y: 0,
        blur: 0,
        spread: 3,
        color: ThemeToken.color('dangerFocus', fallback: '#d92d20').toCss(),
      ),
    ),
    disabled: DartStyle(
      background: ThemeToken.color(
        'disabledSurface',
        fallback: '#f3f4f6',
      ).toCss(),
      color: ThemeToken.color('disabledText', fallback: '#98a2b3').toCss(),
      cursor: Cursor.notAllowed,
    ),
  ).merge(inputSizeStyle(size));

  return base
      .merge(switch (variant) {
        InputVariant.outline => const DartStyle(),
        InputVariant.soft => DartStyle(
          border: Border.all(color: Colors.transparent),
          background: ThemeToken.color(
            'inputSoft',
            fallback: '#f9fafb',
          ).toCss(),
        ),
        InputVariant.ghost => DartStyle(
          border: const Border.all(color: Colors.transparent),
          background: Colors.transparent,
        ),
      })
      .merge(
        disabled
            ? DartStyle(
                opacity: 0.7,
                background: ThemeToken.color(
                  'disabledSurface',
                  fallback: '#f3f4f6',
                ).toCss(),
                color: ThemeToken.color(
                  'disabledText',
                  fallback: '#98a2b3',
                ).toCss(),
                cursor: 'not-allowed',
              )
            : null,
      )
      .merge(
        invalid
            ? DartStyle(
                border: Border.all(
                  color: ThemeToken.color(
                    'dangerSolid',
                    fallback: '#d92d20',
                  ).toCss(),
                ),
              )
            : null,
      );
}

/// Resolves input sizing styles for [size].
DartStyle inputSizeStyle(ComponentSize size) {
  return switch (size) {
    ComponentSize.xs => const DartStyle(
      minHeight: 32,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      fontSize: 12,
    ),
    ComponentSize.sm => const DartStyle(
      minHeight: 36,
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      fontSize: 13,
    ),
    ComponentSize.md => const DartStyle(
      minHeight: 40,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      fontSize: 14,
    ),
    ComponentSize.lg => const DartStyle(
      minHeight: 46,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      fontSize: 15,
    ),
  };
}

/// Resolves a complete navigation item style from variant, tone, size, and state.
DartStyle navItemComponentStyle({
  required NavVariant variant,
  required Tone tone,
  required ComponentSize size,
  required bool selected,
  required bool disabled,
}) {
  final base = DartStyle(
    display: Display.inlineFlex,
    alignItems: AlignItems.center,
    gap: 8,
    border: const Border.all(color: Colors.transparent),
    background: Colors.transparent,
    color: selected
        ? toneText(tone)
        : ThemeToken.color('navText', fallback: '#475467').toCss(),
    fontWeight: selected ? 700 : 600,
    textDecoration: TextDecorationStyle.none,
    cursor: disabled ? Cursor.notAllowed : Cursor.pointer,
    opacity: disabled ? 0.55 : 1,
    transition: StyleTransition.colors(milliseconds: 120),
  ).merge(navItemSizeStyle(size));

  return base
      .merge(switch (variant) {
        NavVariant.underline => DartStyle(
          radius: 0,
          borderBottom: Border.all(
            width: 2,
            color: selected ? toneSolid(tone) : Colors.transparent,
          ),
          hover: disabled
              ? null
              : DartStyle(background: toneSoft(tone), color: toneText(tone)),
        ),
        NavVariant.pill => DartStyle(
          radius: SizeValue('999px'),
          background: selected ? toneSoft(tone) : Colors.transparent,
          border: Border.all(
            color: selected ? toneBorder(tone) : Colors.transparent,
          ),
          hover: disabled
              ? null
              : DartStyle(background: toneSoft(tone), color: toneText(tone)),
        ),
        NavVariant.ghost => DartStyle(
          radius: ThemeToken.radius('md', fallback: '8px').toCss(),
          background: selected ? toneSoft(tone) : Colors.transparent,
          hover: disabled
              ? null
              : DartStyle(background: toneSoft(tone), color: toneText(tone)),
        ),
      })
      .merge(
        disabled
            ? null
            : DartStyle(
                focusVisible: DartStyle(
                  shadow: Shadow(
                    y: 0,
                    blur: 0,
                    spread: 3,
                    color: toneFocus(tone),
                  ),
                ),
              ),
      );
}

/// Resolves navigation item sizing styles for [size].
DartStyle navItemSizeStyle(ComponentSize size) {
  return switch (size) {
    ComponentSize.xs => const DartStyle(
      minHeight: 30,
      padding: EdgeInsets.symmetric(horizontal: 8),
      fontSize: 12,
    ),
    ComponentSize.sm => const DartStyle(
      minHeight: 34,
      padding: EdgeInsets.symmetric(horizontal: 10),
      fontSize: 13,
    ),
    ComponentSize.md => const DartStyle(
      minHeight: 40,
      padding: EdgeInsets.symmetric(horizontal: 12),
      fontSize: 14,
    ),
    ComponentSize.lg => const DartStyle(
      minHeight: 46,
      padding: EdgeInsets.symmetric(horizontal: 14),
      fontSize: 15,
    ),
  };
}

/// Returns a square icon button size for [size].
String iconButtonSize(ComponentSize size) {
  return switch (size) {
    ComponentSize.xs => '28px',
    ComponentSize.sm => '34px',
    ComponentSize.md => '40px',
    ComponentSize.lg => '46px',
  };
}

/// Returns a spinner size for [size].
String spinnerSize(ComponentSize size) {
  return switch (size) {
    ComponentSize.xs => '14px',
    ComponentSize.sm => '16px',
    ComponentSize.md => '20px',
    ComponentSize.lg => '24px',
  };
}

/// Resolves the solid color for [tone].
Object toneSolid(Tone tone) {
  return switch (tone) {
    Tone.neutral => ThemeToken.color(
      'neutralSolid',
      fallback: '#111827',
    ).toCss(),
    Tone.primary => ThemeToken.color(
      'primarySolid',
      fallback: '#155eef',
    ).toCss(),
    Tone.success => ThemeToken.color(
      'successSolid',
      fallback: '#079455',
    ).toCss(),
    Tone.warning => ThemeToken.color(
      'warningSolid',
      fallback: '#dc6803',
    ).toCss(),
    Tone.danger => ThemeToken.color('dangerSolid', fallback: '#d92d20').toCss(),
    Tone.info => ThemeToken.color('infoSolid', fallback: '#1570ef').toCss(),
  };
}

/// Resolves the solid hover color for [tone].
Object toneSolidHover(Tone tone) {
  return switch (tone) {
    Tone.neutral => ThemeToken.color(
      'neutralSolidHover',
      fallback: '#1f2937',
    ).toCss(),
    Tone.primary => ThemeToken.color(
      'primarySolidHover',
      fallback: '#004eeb',
    ).toCss(),
    Tone.success => ThemeToken.color(
      'successSolidHover',
      fallback: '#067647',
    ).toCss(),
    Tone.warning => ThemeToken.color(
      'warningSolidHover',
      fallback: '#b54708',
    ).toCss(),
    Tone.danger => ThemeToken.color(
      'dangerSolidHover',
      fallback: '#b42318',
    ).toCss(),
    Tone.info => ThemeToken.color(
      'infoSolidHover',
      fallback: '#175cd3',
    ).toCss(),
  };
}

/// Resolves the soft background color for [tone].
Object toneSoft(Tone tone) {
  return switch (tone) {
    Tone.neutral => ThemeToken.color(
      'neutralSoft',
      fallback: '#f3f4f6',
    ).toCss(),
    Tone.primary => ThemeToken.color(
      'primarySoft',
      fallback: '#eff4ff',
    ).toCss(),
    Tone.success => ThemeToken.color(
      'successSoft',
      fallback: '#ecfdf3',
    ).toCss(),
    Tone.warning => ThemeToken.color(
      'warningSoft',
      fallback: '#fffaeb',
    ).toCss(),
    Tone.danger => ThemeToken.color('dangerSoft', fallback: '#fef3f2').toCss(),
    Tone.info => ThemeToken.color('infoSoft', fallback: '#eff8ff').toCss(),
  };
}

/// Resolves the soft hover background color for [tone].
Object toneSoftHover(Tone tone) {
  return switch (tone) {
    Tone.neutral => ThemeToken.color(
      'neutralSoftHover',
      fallback: '#e5e7eb',
    ).toCss(),
    Tone.primary => ThemeToken.color(
      'primarySoftHover',
      fallback: '#dbeafe',
    ).toCss(),
    Tone.success => ThemeToken.color(
      'successSoftHover',
      fallback: '#d1fadf',
    ).toCss(),
    Tone.warning => ThemeToken.color(
      'warningSoftHover',
      fallback: '#fef0c7',
    ).toCss(),
    Tone.danger => ThemeToken.color(
      'dangerSoftHover',
      fallback: '#fee4e2',
    ).toCss(),
    Tone.info => ThemeToken.color('infoSoftHover', fallback: '#d1e9ff').toCss(),
  };
}

/// Resolves the border color for [tone].
Object toneBorder(Tone tone) {
  return switch (tone) {
    Tone.neutral => ThemeToken.color(
      'neutralBorder',
      fallback: '#d1d5db',
    ).toCss(),
    Tone.primary => ThemeToken.color(
      'primaryBorder',
      fallback: '#b2ccff',
    ).toCss(),
    Tone.success => ThemeToken.color(
      'successBorder',
      fallback: '#abefc6',
    ).toCss(),
    Tone.warning => ThemeToken.color(
      'warningBorder',
      fallback: '#fedf89',
    ).toCss(),
    Tone.danger => ThemeToken.color(
      'dangerBorder',
      fallback: '#fecdca',
    ).toCss(),
    Tone.info => ThemeToken.color('infoBorder', fallback: '#b2ddff').toCss(),
  };
}

/// Resolves the text color for [tone].
Object toneText(Tone tone) {
  return switch (tone) {
    Tone.neutral => ThemeToken.color(
      'neutralText',
      fallback: '#374151',
    ).toCss(),
    Tone.primary => ThemeToken.color(
      'primaryText',
      fallback: '#1849a9',
    ).toCss(),
    Tone.success => ThemeToken.color(
      'successText',
      fallback: '#067647',
    ).toCss(),
    Tone.warning => ThemeToken.color(
      'warningText',
      fallback: '#b54708',
    ).toCss(),
    Tone.danger => ThemeToken.color('dangerText', fallback: '#b42318').toCss(),
    Tone.info => ThemeToken.color('infoText', fallback: '#175cd3').toCss(),
  };
}

/// Resolves the foreground color used on solid tone backgrounds.
Object toneOnSolid(Tone tone) {
  return switch (tone) {
    Tone.warning => ThemeToken.color(
      'warningOnSolid',
      fallback: '#111827',
    ).toCss(),
    _ => ThemeToken.color('onSolid', fallback: '#ffffff').toCss(),
  };
}

/// Resolves the focus ring color for [tone].
Object toneFocus(Tone tone) {
  return switch (tone) {
    Tone.neutral => ThemeToken.color(
      'neutralFocus',
      fallback: '#9ca3af',
    ).toCss(),
    Tone.primary => ThemeToken.color(
      'primaryFocus',
      fallback: '#155eef',
    ).toCss(),
    Tone.success => ThemeToken.color(
      'successFocus',
      fallback: '#079455',
    ).toCss(),
    Tone.warning => ThemeToken.color(
      'warningFocus',
      fallback: '#dc6803',
    ).toCss(),
    Tone.danger => ThemeToken.color('dangerFocus', fallback: '#d92d20').toCss(),
    Tone.info => ThemeToken.color('infoFocus', fallback: '#1570ef').toCss(),
  };
}
