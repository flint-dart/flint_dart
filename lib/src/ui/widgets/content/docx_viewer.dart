import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:universal_web/web.dart' as web;

import '../../component.dart';
import '../../node.dart';
import '../../style.dart';
import '../actions/button.dart';
import '../icons/icons.dart';
import '../primitives/column.dart';
import '../primitives/container.dart';
import '../primitives/row.dart';
import '../primitives/text.dart';
import '../shared/theme.dart';
import 'doc_toolbar.dart';
import 'doc_viewer_controller.dart';

export 'doc_toolbar.dart';
export 'doc_viewer_controller.dart';

/// Native Flint UI in-browser DOCX high-fidelity canvas studio.
///
/// Preserves Microsoft Word drawings, diagrams, vector charts, full-color tables,
/// typography, and page headers/footers with interactive outline and zoom controls.
class DocxViewer extends StatefulComponent {
  DocxViewer({
    required this.src,
    this.title,
    this.controller,
    this.showToolbar = true,
    this.className,
    this.dartStyle,
    this.fallback,
    this.loadingWidget,
  });

  static int _nextId = 0;

  /// URL of the `.docx` document to load.
  String src;

  /// Accessible title for the document.
  String? title;

  /// Optional controller to manage zoom, navigation, and outline.
  DocViewerController? controller;

  /// Whether to display the interactive top navigation toolbar.
  bool showToolbar;

  /// Optional class name for the wrapper.
  String? className;

  /// Typed style for the canvas container.
  DartStyle? dartStyle;

  /// Optional custom fallback widget if document rendering fails.
  FlintNode? fallback;

  /// Optional custom loading widget.
  FlintNode? loadingWidget;

  late final String _instanceId = 'flint-docx-viewer-${_nextId++}';
  late final DocViewerController _effectiveController = controller ?? DocViewerController();

  int _activeMatchIndex = 0;

  @override
  void updateFrom(covariant DocxViewer next) {
    final changed = src != next.src;
    src = next.src;
    title = next.title;
    controller = next.controller;
    showToolbar = next.showToolbar;
    className = next.className;
    dartStyle = next.dartStyle;
    fallback = next.fallback;
    loadingWidget = next.loadingWidget;

    if (changed) {
      _renderDocx();
    }
  }

  @override
  void didMount() {
    _bindController();
    _injectDocxStyles();
    _renderDocx();
  }

  void _bindController() {
    _effectiveController.onJumpToPage = (page) {
      final mount = web.document.getElementById('$_instanceId-mount');
      if (mount == null) return;
      final pages = mount.querySelectorAll('.docx-wrapper > section.docx, section.docx, section');
      if (page >= 1 && page <= pages.length) {
        final target = pages.item(page - 1);
        if (target != null && target is web.HTMLElement) {
          (target as JSObject).callMethod('scrollIntoView'.toJS, {'behavior': 'smooth', 'block': 'start'}.jsify());
        }
      }
    };

    _effectiveController.onSetZoom = (scale) {
      final mount = web.document.getElementById('$_instanceId-mount');
      if (mount == null) return;
      final htmlMount = mount as web.HTMLElement;
      htmlMount.style.transform = 'scale($scale)';
      htmlMount.style.transformOrigin = 'top center';
    };

    _effectiveController.onSetReadingMode = (mode) {
      final mount = web.document.getElementById('$_instanceId-mount');
      if (mount == null) return;
      final wrapper = mount.querySelector('.docx-wrapper') ?? mount;
      if (wrapper is web.HTMLElement) {
        wrapper.classList.remove('mode-paper');
        wrapper.classList.remove('mode-dark');
        wrapper.classList.remove('mode-sepia');
        wrapper.classList.add('mode-${mode.name}');
      }
    };

    _effectiveController.onSearch = (query) {
      _highlightSearchInDoc(query);
    };

    _effectiveController.onNextMatch = () {
      final mount = web.document.getElementById('$_instanceId-mount');
      if (mount == null) return;
      final matches = mount.querySelectorAll('mark.flint-doc-match');
      if (matches.length == 0) return;
      _activeMatchIndex = (_activeMatchIndex + 1) % matches.length;
      _focusMatch(matches, _activeMatchIndex);
    };

    _effectiveController.onPrevMatch = () {
      final mount = web.document.getElementById('$_instanceId-mount');
      if (mount == null) return;
      final matches = mount.querySelectorAll('mark.flint-doc-match');
      if (matches.length == 0) return;
      _activeMatchIndex = (_activeMatchIndex - 1 + matches.length) % matches.length;
      _focusMatch(matches, _activeMatchIndex);
    };
  }

  void _highlightSearchInDoc(String query) {
    final mount = web.document.getElementById('$_instanceId-mount');
    if (mount == null) return;

    // Clear old highlights
    final oldMarks = mount.querySelectorAll('mark.flint-doc-match');
    for (int i = 0; i < oldMarks.length; i++) {
      final m = oldMarks.item(i);
      if (m != null && m.parentNode != null) {
        final parent = m.parentNode!;
        final textNode = web.document.createTextNode(m.textContent ?? '');
        parent.replaceChild(textNode, m);
      }
    }

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _effectiveController.updateSearchMatches(current: 0, total: 0);
      return;
    }

    final elements = mount.querySelectorAll('p, span, td, th, h1, h2, h3, h4, h5, li');
    int matchCount = 0;
    final regex = RegExp(RegExp.escape(trimmed), caseSensitive: false);

    for (int i = 0; i < elements.length; i++) {
      final node = elements.item(i);
      if (node == null || node is! web.HTMLElement) continue;
      final el = node;
      // Skip elements that contain many child container elements
      if (el.children.length > 3) continue;

      final text = el.textContent ?? '';
      if (regex.hasMatch(text)) {
        final rawHtml = el.innerHTML.toString();
        if (rawHtml.contains('<mark')) continue;

        final newHtml = rawHtml.replaceAllMapped(regex, (match) {
          matchCount++;
          return '<mark class="flint-doc-match" style="background:#fde047;color:#000000;padding:1px 3px;border-radius:2px;font-weight:700;">${match.group(0)}</mark>';
        });
        el.innerHTML = newHtml.toJS;
      }
    }

    _effectiveController.updateSearchMatches(current: matchCount > 0 ? 1 : 0, total: matchCount);
    _activeMatchIndex = 0;

    if (matchCount > 0) {
      final marks = mount.querySelectorAll('mark.flint-doc-match');
      if (marks.length > 0) {
        _focusMatch(marks, 0);
      }
    }
  }

  void _focusMatch(web.NodeList marks, int index) {
    for (int i = 0; i < marks.length; i++) {
      final m = marks.item(i);
      if (m != null && m is web.HTMLElement) {
        if (i == index) {
          m.style.background = '#38bdf8';
          m.style.outline = '2px solid #0284c7';
          (m as JSObject).callMethod('scrollIntoView'.toJS, {'behavior': 'smooth', 'block': 'center'}.jsify());
        } else {
          m.style.background = '#fde047';
          m.style.outline = 'none';
        }
      }
    }
    _effectiveController.updateSearchMatches(current: index + 1, total: marks.length);
  }

  void _injectDocxStyles() {
    const styleId = 'flint-docx-injected-styles';
    if (web.document.getElementById(styleId) != null) return;

    final styleEl = web.document.createElement('style') as web.HTMLStyleElement;
    styleEl.id = styleId;
    styleEl.textContent = '''
.docx-wrapper {
  background: transparent !important;
  padding: 0 !important;
  display: flex !important;
  flex-direction: column !important;
  align-items: center !important;
  gap: 24px !important;
  width: 100% !important;
  transition: transform 0.15s ease-out;
}
.docx-wrapper > section.docx {
  border-radius: 4px !important;
  margin: 0 auto 24px auto !important;
  max-width: 900px !important;
  width: 100% !important;
  min-height: 1000px !important;
  box-sizing: border-box !important;
  padding: 52px 60px !important;
  transition: background-color 0.2s ease, color 0.2s ease;
}
.docx-wrapper table {
  border-collapse: collapse !important;
  width: 100% !important;
  margin: 16px 0 !important;
}
.docx-wrapper table td, .docx-wrapper table th {
  padding: 8px 12px !important;
}
.docx-wrapper img, .docx-wrapper svg {
  max-width: 100% !important;
  height: auto !important;
}

/* ☀️ Paper Mode */
.docx-wrapper > section.docx, .docx-wrapper.mode-paper > section.docx {
  background: #ffffff !important;
  color: #0f172a !important;
  box-shadow: 0 16px 56px rgba(0, 0, 0, 0.6) !important;
}
.docx-wrapper table td, .docx-wrapper table th,
.docx-wrapper.mode-paper table td, .docx-wrapper.mode-paper table th {
  border: 1px solid #cbd5e1 !important;
  color: #0f172a !important;
  background: #ffffff !important;
}

/* 🌙 Dark Mode */
.docx-wrapper.mode-dark > section.docx {
  background: #141b26 !important;
  color: #f1f5f9 !important;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.75) !important;
  border: 1px solid rgba(255, 255, 255, 0.08) !important;
}
.docx-wrapper.mode-dark span, .docx-wrapper.mode-dark p, .docx-wrapper.mode-dark div {
  color: #f1f5f9 !important;
}
.docx-wrapper.mode-dark h1, .docx-wrapper.mode-dark h2, .docx-wrapper.mode-dark h3, .docx-wrapper.mode-dark h4 {
  color: #38bdf8 !important;
}
.docx-wrapper.mode-dark table {
  background: #1e293b !important;
}
.docx-wrapper.mode-dark table td, .docx-wrapper.mode-dark table th {
  border: 1px solid #334155 !important;
  color: #e2e8f0 !important;
  background: #1e293b !important;
}

/* 📜 Sepia Mode */
.docx-wrapper.mode-sepia > section.docx {
  background: #fbf0d9 !important;
  color: #433422 !important;
  box-shadow: 0 16px 56px rgba(0, 0, 0, 0.5) !important;
}
.docx-wrapper.mode-sepia span, .docx-wrapper.mode-sepia p, .docx-wrapper.mode-sepia div {
  color: #433422 !important;
}
.docx-wrapper.mode-sepia table td, .docx-wrapper.mode-sepia table th {
  border: 1px solid #d7c4a3 !important;
  color: #433422 !important;
  background: #fbf0d9 !important;
}
''';
    web.document.head?.appendChild(styleEl);
  }

  void _renderDocx() {
    final mount = web.document.getElementById('$_instanceId-mount');
    if (mount == null) {
      Future.delayed(const Duration(milliseconds: 50), _renderDocx);
      return;
    }

    final loadingEl = web.document.getElementById('$_instanceId-loading');
    final errorEl = web.document.getElementById('$_instanceId-error');
    final fallbackEl = web.document.getElementById('$_instanceId-fallback');

    if (loadingEl != null) (loadingEl as web.HTMLElement).style.display = 'flex';
    if (errorEl != null) (errorEl as web.HTMLElement).style.display = 'none';
    if (fallbackEl != null) (fallbackEl as web.HTMLElement).style.display = 'none';

    _ensureScriptsLoaded(() {
      _executeDocxRender(mount);
    });
  }

  void _ensureScriptsLoaded(void Function() onReady) {
    final win = web.window as JSObject;
    final bool hasZip = win.hasProperty('JSZip'.toJS).toDart;
    final bool hasDocx = win.hasProperty('docx'.toJS).toDart;

    if (hasZip && hasDocx) {
      onReady();
      return;
    }

    void loadScript(String url, void Function() next) {
      if (web.document.querySelector('script[src="$url"]') != null) {
        next();
        return;
      }
      final s = web.document.createElement('script') as web.HTMLScriptElement;
      s.src = url;
      s.crossOrigin = 'anonymous';
      s.onload = ((web.Event e) {
        next();
      }).toJS;
      s.onerror = ((web.Event e) {
        if (url.contains('cdnjs')) {
          loadScript('https://unpkg.com/jszip@3.10.1/dist/jszip.min.js', next);
        } else if (url.contains('jsdelivr')) {
          loadScript('https://unpkg.com/docx-preview@0.3.4/dist/docx-preview.min.js', next);
        }
      }).toJS;
      web.document.head?.appendChild(s);
    }

    if (!hasZip) {
      loadScript('https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js', () {
        loadScript('https://cdn.jsdelivr.net/npm/docx-preview@0.3.4/dist/docx-preview.min.js', onReady);
      });
    } else if (!hasDocx) {
      loadScript('https://cdn.jsdelivr.net/npm/docx-preview@0.3.4/dist/docx-preview.min.js', onReady);
    } else {
      onReady();
    }
  }

  void _executeDocxRender(web.Element mount) {
    final loadingEl = web.document.getElementById('$_instanceId-loading');
    final errorEl = web.document.getElementById('$_instanceId-error');
    final fallbackEl = web.document.getElementById('$_instanceId-fallback');

    final win = web.window as JSObject;
    if (!win.hasProperty('docx'.toJS).toDart) {
      Future.delayed(const Duration(milliseconds: 100), () => _executeDocxRender(mount));
      return;
    }
    final docxProp = win.getProperty('docx'.toJS);
    if (docxProp.isUndefinedOrNull) {
      Future.delayed(const Duration(milliseconds: 100), () => _executeDocxRender(mount));
      return;
    }

    final docxObj = docxProp as JSObject;
    final renderAsyncProp = docxObj.getProperty('renderAsync'.toJS);
    if (renderAsyncProp.isUndefinedOrNull) {
      Future.delayed(const Duration(milliseconds: 100), () => _executeDocxRender(mount));
      return;
    }
    final renderAsync = renderAsyncProp as JSFunction;

    web.window
        .fetch(src.toJS)
        .toDart
        .then((response) {
          if (!response.ok) {
            throw Exception('HTTP ${response.status}: ${response.statusText}');
          }
          return response.arrayBuffer().toDart;
        })
        .then((buf) {
          final options = {
            'className': 'flint-docx-paper',
            'inWrapper': true,
            'ignoreWidth': false,
            'ignoreHeight': false,
            'ignoreFonts': false,
            'breakPages': true,
            'useBase64URL': true,
            'renderChanges': false,
            'renderHeaders': true,
            'renderFooters': true,
            'renderFootnotes': true,
            'renderEndnotes': true,
            'experimental': true,
          }.jsify();

          mount.innerHTML = ''.toJS;
          final promise = renderAsync.callAsFunction(
            docxObj,
            buf,
            mount,
            null,
            options,
          ) as JSPromise;

          return promise.toDart;
        })
        .then((_) {
          if (loadingEl != null) (loadingEl as web.HTMLElement).style.display = 'none';
          if (errorEl != null) (errorEl as web.HTMLElement).style.display = 'none';

          // Extract Headings & Total Pages for Outline
          final pages = mount.querySelectorAll('.docx-wrapper > section.docx, section.docx, section');
          final headings = mount.querySelectorAll('h1, h2, h3');
          final toc = <DocTocItem>[];

          for (int i = 0; i < headings.length; i++) {
            final h = headings.item(i);
            final text = h?.textContent?.trim() ?? '';
            if (text.isNotEmpty) {
              // Find which page section contains this heading
              int pageIndex = 1;
              for (int p = 0; p < pages.length; p++) {
                final pageEl = pages.item(p);
                if (pageEl != null && pageEl.contains(h)) {
                  pageIndex = p + 1;
                  break;
                }
              }
              toc.add(DocTocItem(title: text, pageNumber: pageIndex));
            }
          }

          _effectiveController.updateDocumentMeta(
            currentPage: 1,
            totalPages: pages.length > 0 ? pages.length : 1,
            toc: toc,
          );

          // Apply initial reading mode
          _effectiveController.onSetReadingMode?.call(_effectiveController.readingMode);
        })
        .catchError((err) {
          if (loadingEl != null) (loadingEl as web.HTMLElement).style.display = 'none';
          if (fallback != null && fallbackEl != null) {
            (fallbackEl as web.HTMLElement).style.display = 'block';
          } else if (errorEl != null) {
            final htmlError = errorEl as web.HTMLElement;
            htmlError.style.display = 'block';
            htmlError.textContent = 'Document canvas error: $err';
          }
        });
  }

  @override
  View build() {
    return Container(
      className: className,
      dartStyle: dartStyle ??
          const DartStyle(
            width: SizeValue.full,
            display: Display.flex,
            flexDirection: FlexDirection.column,
            alignItems: AlignItems.center,
          ),
      children: [
        // 🔹 Interactive Navigation & Zoom Toolbar
        if (showToolbar)
          DocViewerToolbar(
            controller: _effectiveController,
            title: title,
          ),

        // 🔹 Table of Contents / Outline Drawer
        if (_effectiveController.showOutline && _effectiveController.tableOfContents.isNotEmpty)
          Container(
            dartStyle: DartStyle(
              width: const SizeValue('min(900px, 100%)'),
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              radius: 8,
              background: const Color('#0f172a'),
              border: Border.all(color: const Color.rgba(56, 189, 248, 0.3)),
              shadow: const Shadow(y: 12, blur: 32, spread: -4, color: Color.rgba(0, 0, 0, 0.5)),
            ),
            children: [
              Row(
                dartStyle: DartStyle(display: Display.flex, alignItems: AlignItems.center, justifyContent: JustifyContent.between, margin: const EdgeInsets.only(bottom: 12)),
                children: [
                  Row(
                    dartStyle: DartStyle(display: Display.flex, alignItems: AlignItems.center, gap: 8),
                    children: [
                      Icon(Icons.list, size: 16, color: const Color('#38bdf8')),
                      Text.strong('TABLE OF CONTENTS', dartStyle: const DartStyle(fontSize: 12, fontWeight: 900, color: Color('#38bdf8'), letterSpacing: 0.8)),
                    ],
                  ),
                  Button(
                    child: Text.span('Close'),
                    size: ComponentSize.xs,
                    variant: ButtonVariant.ghost,
                    onPressed: (_) => _effectiveController.toggleOutline(false),
                  ),
                ],
              ),
              Column(
                dartStyle: const DartStyle(gap: 6),
                children: [
                  for (final item in _effectiveController.tableOfContents)
                    Button(
                      child: Row(
                        dartStyle: DartStyle(display: Display.flex, alignItems: AlignItems.center, justifyContent: JustifyContent.between, width: SizeValue.full),
                        children: [
                          Text.span(item.title),
                          Container(
                            dartStyle: DartStyle(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              radius: 4,
                              background: const Color.rgba(255, 255, 255, 0.08),
                              fontSize: 10,
                              color: const Color('#94a3b8'),
                            ),
                            child: Text.span('p. ${item.pageNumber}'),
                          ),
                        ],
                      ),
                      size: ComponentSize.sm,
                      variant: ButtonVariant.ghost,
                      dartStyle: const DartStyle(justifyContent: JustifyContent.start, textAlign: TextAlign.left, color: Color('#cbd5e1')),
                      onPressed: (_) {
                        _effectiveController.jumpToPage(item.pageNumber);
                      },
                    ),
                ],
              ),
            ],
          ),

        // 🔹 Loading Indicator
        Container(
          props: {'id': '$_instanceId-loading'},
          dartStyle: DartStyle(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(bottom: 20),
            radius: 8,
            background: const Color.rgba(56, 189, 248, 0.1),
            border: Border.all(color: const Color.rgba(56, 189, 248, 0.25)),
            display: Display.flex,
            alignItems: AlignItems.center,
            justifyContent: JustifyContent.center,
            gap: 10,
            color: const Color('#38bdf8'),
            fontWeight: 700,
            fontSize: 14,
          ),
          children: [
            loadingWidget ?? Text.span('⚡ Rendering High-Fidelity Word Document (diagrams, tables & layout)...'),
          ],
        ),

        // 🔹 Fallback Container
        if (fallback != null)
          Container(
            props: {
              'id': '$_instanceId-fallback',
              'style': {'display': 'none', 'width': '100%'},
            },
            children: [fallback!],
          ),

        // 🔹 Error Container
        Container(
          props: {
            'id': '$_instanceId-error',
            'style': {'display': 'none'},
          },
          dartStyle: DartStyle(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 20),
            radius: 8,
            background: const Color.rgba(239, 68, 68, 0.1),
            border: Border.all(color: const Color.rgba(239, 68, 68, 0.3)),
            color: const Color('#ef4444'),
          ),
        ),

        // 🔹 Live Canvas Mount Target
        Container(
          props: {'id': '$_instanceId-mount'},
          dartStyle: const DartStyle(
            width: SizeValue.full,
            display: Display.flex,
            flexDirection: FlexDirection.column,
            alignItems: AlignItems.center,
          ),
        ),
      ],
    );
  }
}
