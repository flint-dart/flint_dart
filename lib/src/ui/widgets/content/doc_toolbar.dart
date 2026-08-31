import '../../component.dart';
import '../../node.dart';
import '../../style.dart';
import '../actions/button.dart';
import '../actions/icon_button.dart';
import '../icons/icons.dart';
import '../primitives/container.dart';
import '../primitives/row.dart';
import '../primitives/text.dart';
import '../shared/theme.dart';
import 'doc_viewer_controller.dart';

/// Interactive Floating or Sticky Navigation Toolbar for [DocxViewer] and [PdfViewer].
class DocViewerToolbar extends StatefulComponent {
  DocViewerToolbar({
    required this.controller,
    this.title,
    this.showSearch = true,
    this.showZoom = true,
    this.showPageNav = true,
    this.showToc = true,
    this.showReadingMode = true,
    this.dartStyle,
    this.className,
  });

  final DocViewerController controller;
  final String? title;
  final bool showSearch;
  final bool showZoom;
  final bool showPageNav;
  final bool showToc;
  final bool showReadingMode;
  final DartStyle? dartStyle;
  final String? className;

  @override
  void didMount() {
    controller.addListener(_onControllerChange);
  }

  @override
  void willUnmount() {
    controller.removeListener(_onControllerChange);
  }

  void _onControllerChange() {
    setState(() {});
  }

  @override
  View build() {
    final zoomPercent = (controller.zoom * 100).round();
    final mode = controller.readingMode;

    final (modeLabel, modeIcon) = switch (mode) {
      DocReadingMode.paper => ('Paper', Icons.sun),
      DocReadingMode.dark => ('Dark', Icons.moon),
      DocReadingMode.sepia => ('Sepia', Icons.book),
    };

    return Container(
      className: className,
      dartStyle: dartStyle ??
          DartStyle(
            width: const SizeValue('min(920px, 100%)'),
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            radius: 8,
            background: const Color('#131822'),
            border: Border.all(color: const Color.rgba(255, 255, 255, 0.12)),
            display: Display.flex,
            alignItems: AlignItems.center,
            justifyContent: JustifyContent.between,
            gap: 12,
            flexWrap: FlexWrap.wrap,
            shadow: const Shadow(
              y: 8,
              blur: 24,
              spread: -4,
              color: Color.rgba(0, 0, 0, 0.45),
            ),
          ),
      children: [
        // 🔹 Left: Document Title & TOC Drawer Toggle
        Row(
          dartStyle: DartStyle(
              display: Display.flex, alignItems: AlignItems.center, gap: 8),
          children: [
            if (showToc && controller.tableOfContents.isNotEmpty)
              IconButton(
                icon: Icons.list,
                label: 'Table of Contents',
                tooltip: 'Table of Contents',
                variant: controller.showOutline
                    ? ButtonVariant.solid
                    : ButtonVariant.ghost,
                size: ComponentSize.sm,
                onPressed: (_) => controller.toggleOutline(),
              ),
            if (title != null)
              Text.strong(
                title!,
                dartStyle: const DartStyle(
                  fontSize: 13,
                  fontWeight: 800,
                  color: Color('#f8fafc'),
                  maxWidth: SizeValue('200px'),
                  overflow: 'hidden',
                  textOverflow: TextOverflow.ellipsis,
                  whiteSpace: 'nowrap',
                ),
              ),
          ],
        ),

        // 🔹 Center: Page Navigation Stepper
        if (showPageNav)
          Row(
            dartStyle: DartStyle(
                display: Display.flex, alignItems: AlignItems.center, gap: 4),
            children: [
              IconButton(
                icon: Icons.chevronLeft,
                label: 'Previous Page',
                size: ComponentSize.sm,
                disabled: controller.currentPage <= 1,
                onPressed: (_) => controller.prevPage(),
              ),
              Container(
                dartStyle: DartStyle(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  background: const Color.rgba(255, 255, 255, 0.06),
                  border:
                      Border.all(color: const Color.rgba(255, 255, 255, 0.1)),
                  radius: 4,
                  fontSize: 12,
                  fontWeight: 700,
                  color: const Color('#cbd5e1'),
                ),
                child: Text.span(
                    'Page ${controller.currentPage} of ${controller.totalPages}'),
              ),
              IconButton(
                icon: Icons.chevronRight,
                label: 'Next Page',
                size: ComponentSize.sm,
                disabled: controller.currentPage >= controller.totalPages,
                onPressed: (_) => controller.nextPage(),
              ),
            ],
          ),

        // 🔹 Right: Reading Mode, Zoom & Live Search Controls
        Row(
          dartStyle: DartStyle(
              display: Display.flex, alignItems: AlignItems.center, gap: 8),
          children: [
            // Reading Mode Switcher
            if (showReadingMode)
              Button(
                size: ComponentSize.sm,
                variant: ButtonVariant.ghost,
                onPressed: (_) => controller.toggleReadingMode(),
                children: [
                  Icon(modeIcon,
                      size: 14,
                      color: mode == DocReadingMode.dark
                          ? const Color('#38bdf8')
                          : const Color('#fbbf24')),
                  Text.span(modeLabel),
                ],
              ),

            // Zoom Controls
            if (showZoom)
              Row(
                dartStyle: DartStyle(
                    display: Display.flex,
                    alignItems: AlignItems.center,
                    gap: 2),
                children: [
                  IconButton(
                    icon: Icons.minus,
                    label: 'Zoom Out',
                    size: ComponentSize.sm,
                    tooltip: 'Zoom Out',
                    onPressed: (_) => controller.zoomOut(),
                  ),
                  Button(
                    child: Text.span('$zoomPercent%'),
                    size: ComponentSize.sm,
                    variant: ButtonVariant.ghost,
                    onPressed: (_) => controller.resetZoom(),
                  ),
                  IconButton(
                    icon: Icons.plus,
                    label: 'Zoom In',
                    size: ComponentSize.sm,
                    tooltip: 'Zoom In',
                    onPressed: (_) => controller.zoomIn(),
                  ),
                ],
              ),

            // Live Search Input Box
            if (showSearch)
              Container(
                dartStyle: DartStyle(
                  display: Display.flex,
                  alignItems: AlignItems.center,
                  gap: 6,
                  background: const Color.rgba(255, 255, 255, 0.05),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  radius: 6,
                  border:
                      Border.all(color: const Color.rgba(255, 255, 255, 0.12)),
                ),
                children: [
                  Icon(Icons.search, size: 14, color: const Color('#94a3b8')),
                  FlintElement(
                    'input',
                    props: {
                      'type': 'text',
                      'placeholder': 'Find in doc...',
                      'value': controller.searchQuery,
                      'style': {
                        'background': 'transparent',
                        'border': 'none',
                        'outline': 'none',
                        'color': '#f8fafc',
                        'font-size': '12px',
                        'width': '100px',
                      },
                      'onInput': (Object event) {
                        final dynamic evt = event;
                        final dynamic target = evt?.target;
                        if (target != null) {
                          controller.search(target.value?.toString() ?? '');
                        }
                      },
                      'onKeyDown': (Object event) {
                        final dynamic evt = event;
                        if (evt?.key == 'Enter') {
                          if (evt?.shiftKey == true) {
                            controller.prevMatch();
                          } else {
                            controller.nextMatch();
                          }
                        }
                      },
                    },
                  ),
                  if (controller.totalMatches > 0)
                    Text.span(
                      '${controller.currentMatch}/${controller.totalMatches}',
                      dartStyle: const DartStyle(
                          fontSize: 11,
                          color: Color('#38bdf8'),
                          fontWeight: 700),
                    ),
                  if (controller.totalMatches > 0)
                    IconButton(
                      icon: Icons.chevronUp,
                      label: 'Previous Match',
                      size: ComponentSize.xs,
                      onPressed: (_) => controller.prevMatch(),
                    ),
                  if (controller.totalMatches > 0)
                    IconButton(
                      icon: Icons.chevronDown,
                      label: 'Next Match',
                      size: ComponentSize.xs,
                      onPressed: (_) => controller.nextMatch(),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
