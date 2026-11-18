import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:universal_web/web.dart' as web;

import '../../component.dart';
import '../../node.dart';
import '../../style.dart';
import '../primitives/container.dart';
import '../primitives/iframe.dart';
import '../primitives/text.dart';
import 'doc_toolbar.dart';
import 'doc_viewer_controller.dart';

export 'doc_toolbar.dart';
export 'doc_viewer_controller.dart';

/// Native Flint UI in-browser PDF document viewer with multi-page canvas studio.
class PdfViewer extends StatefulComponent {
  PdfViewer({
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

  /// URL of the PDF document to load.
  String src;

  /// Accessible title for the document.
  String? title;

  /// Optional controller to manage zoom, page jumps, and outline.
  DocViewerController? controller;

  /// Whether to display the navigation toolbar.
  bool showToolbar;

  /// Optional class name for the wrapper.
  String? className;

  /// Typed style for the viewer container.
  DartStyle? dartStyle;

  /// Optional custom fallback widget.
  FlintNode? fallback;

  /// Optional custom loading widget.
  FlintNode? loadingWidget;

  late final String _instanceId = 'flint-pdf-viewer-${_nextId++}';
  late final DocViewerController _effectiveController = controller ?? DocViewerController();

  @override
  void updateFrom(covariant PdfViewer next) {
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
      _renderPdf();
    }
  }

  @override
  void didMount() {
    _bindController();
    _injectPdfStyles();
    _renderPdf();
  }

  void _bindController() {
    _effectiveController.onJumpToPage = (page) {
      final mount = web.document.getElementById('$_instanceId-mount');
      if (mount == null) return;
      final pages = mount.querySelectorAll('.flint-pdf-page-card');
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
      final htmlMount = mount as web.HTMLElement;
      htmlMount.classList.remove('mode-paper');
      htmlMount.classList.remove('mode-dark');
      htmlMount.classList.remove('mode-sepia');
      htmlMount.classList.add('mode-${mode.name}');
    };
  }

  void _injectPdfStyles() {
    const styleId = 'flint-pdf-injected-styles';
    if (web.document.getElementById(styleId) != null) return;

    final styleEl = web.document.createElement('style') as web.HTMLStyleElement;
    styleEl.id = styleId;
    styleEl.textContent = '''
.flint-pdf-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 28px;
  width: 100%;
  padding-bottom: 40px;
  transition: transform 0.15s ease-out;
}
.flint-pdf-page-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  background: #ffffff;
  border-radius: 4px;
  box-shadow: 0 16px 56px rgba(0, 0, 0, 0.65);
  overflow: hidden;
  max-width: 900px;
  width: 100%;
  position: relative;
  margin: 0 auto;
  transition: filter 0.2s ease, background-color 0.2s ease;
}
.flint-pdf-page-card canvas {
  width: 100% !important;
  height: auto !important;
  display: block;
}
.flint-pdf-page-footer {
  width: 100%;
  padding: 8px 16px;
  background: #f8fafc;
  border-top: 1px solid #e2e8f0;
  display: flex;
  justifyContent: space-between;
  font-size: 11px;
  font-weight: 700;
  color: #64748b;
}

/* 🌙 Dark Mode Filter for PDF Canvas */
.flint-pdf-container.mode-dark .flint-pdf-page-card {
  background: #111827;
  border: 1px solid rgba(255, 255, 255, 0.1);
}
.flint-pdf-container.mode-dark .flint-pdf-page-card canvas {
  filter: invert(0.88) hue-rotate(180deg) contrast(1.05);
}
.flint-pdf-container.mode-dark .flint-pdf-page-footer {
  background: #1e293b;
  border-top: 1px solid #334155;
  color: #94a3b8;
}

/* 📜 Sepia Mode */
.flint-pdf-container.mode-sepia .flint-pdf-page-card {
  background: #fbf0d9;
}
.flint-pdf-container.mode-sepia .flint-pdf-page-card canvas {
  filter: sepia(0.35) contrast(0.95);
}
.flint-pdf-container.mode-sepia .flint-pdf-page-footer {
  background: #f4e8cb;
  border-top: 1px solid #d7c4a3;
  color: #5c4731;
}
''';
    web.document.head?.appendChild(styleEl);
  }

  void _renderPdf() {
    final mount = web.document.getElementById('$_instanceId-mount');
    if (mount == null) {
      Future.delayed(const Duration(milliseconds: 50), _renderPdf);
      return;
    }

    final loadingEl = web.document.getElementById('$_instanceId-loading');
    final errorEl = web.document.getElementById('$_instanceId-error');
    final fallbackEl = web.document.getElementById('$_instanceId-fallback');

    if (loadingEl != null) (loadingEl as web.HTMLElement).style.display = 'flex';
    if (errorEl != null) (errorEl as web.HTMLElement).style.display = 'none';
    if (fallbackEl != null) (fallbackEl as web.HTMLElement).style.display = 'none';

    _ensurePdfJsLoaded(() {
      _executePdfRender(mount);
    });
  }

  void _ensurePdfJsLoaded(void Function() onReady) {
    final win = web.window as JSObject;
    final bool hasPdfJs = win.hasProperty('pdfjsLib'.toJS).toDart;

    if (hasPdfJs) {
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
          loadScript('https://unpkg.com/pdfjs-dist@3.11.174/build/pdf.min.js', next);
        }
      }).toJS;
      web.document.head?.appendChild(s);
    }

    loadScript('https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js', onReady);
  }

  void _executePdfRender(web.Element mount) {
    final loadingEl = web.document.getElementById('$_instanceId-loading');
    final errorEl = web.document.getElementById('$_instanceId-error');
    final fallbackEl = web.document.getElementById('$_instanceId-fallback');

    final win = web.window as JSObject;
    if (!win.hasProperty('pdfjsLib'.toJS).toDart) {
      Future.delayed(const Duration(milliseconds: 100), () => _executePdfRender(mount));
      return;
    }
    final pdfjsProp = win.getProperty('pdfjsLib'.toJS);
    if (pdfjsProp.isUndefinedOrNull) {
      Future.delayed(const Duration(milliseconds: 100), () => _executePdfRender(mount));
      return;
    }

    final pdfjs = pdfjsProp as JSObject;
    final globalWorkerOptions = pdfjs.getProperty('GlobalWorkerOptions'.toJS) as JSObject;
    globalWorkerOptions.setProperty('workerSrc'.toJS, 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js'.toJS);

    final getDocument = pdfjs.getProperty('getDocument'.toJS) as JSFunction;
    final loadingTask = getDocument.callAsFunction(pdfjs, src.toJS) as JSObject;
    final promise = loadingTask.getProperty('promise'.toJS) as JSPromise;

    promise.toDart.then((pdfDocObj) {
      final pdfDoc = pdfDocObj as JSObject;
      final numPages = (pdfDoc.getProperty('numPages'.toJS) as JSNumber).toDartInt;

      _effectiveController.updateDocumentMeta(currentPage: 1, totalPages: numPages);

      mount.innerHTML = ''.toJS;

      for (int pageNum = 1; pageNum <= numPages; pageNum++) {
        final getPage = pdfDoc.getProperty('getPage'.toJS) as JSFunction;
        final pagePromise = getPage.callAsFunction(pdfDoc, pageNum.toJS) as JSPromise;

        pagePromise.toDart.then((pageObj) {
          final page = pageObj as JSObject;
          final getViewport = page.getProperty('getViewport'.toJS) as JSFunction;
          final viewport = getViewport.callAsFunction(page, {'scale': 1.8}.jsify()) as JSObject;

          final width = (viewport.getProperty('width'.toJS) as JSNumber).toDartDouble;
          final height = (viewport.getProperty('height'.toJS) as JSNumber).toDartDouble;

          final pageCard = web.document.createElement('div') as web.HTMLDivElement;
          pageCard.className = 'flint-pdf-page-card';

          final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
          canvas.width = width.round();
          canvas.height = height.round();

          final getContext = (canvas as JSObject).getProperty('getContext'.toJS) as JSFunction;
          final ctx = getContext.callAsFunction(canvas as JSObject, '2d'.toJS);

          final render = page.getProperty('render'.toJS) as JSFunction;
          render.callAsFunction(page, {
            'canvasContext': ctx,
            'viewport': viewport,
          }.jsify());

          final footer = web.document.createElement('div') as web.HTMLDivElement;
          footer.className = 'flint-pdf-page-footer';
          footer.innerHTML = '<span>EULOGIA TECHNOLOGIES VAULT</span><span>PAGE $pageNum OF $numPages</span>'.toJS;

          pageCard.appendChild(canvas);
          pageCard.appendChild(footer);
          mount.appendChild(pageCard);
        });
      }

      if (loadingEl != null) (loadingEl as web.HTMLElement).style.display = 'none';
      if (errorEl != null) (errorEl as web.HTMLElement).style.display = 'none';

      // Apply initial reading mode
      _effectiveController.onSetReadingMode?.call(_effectiveController.readingMode);
    }).catchError((err) {
      if (loadingEl != null) (loadingEl as web.HTMLElement).style.display = 'none';
      if (fallbackEl != null) {
        (fallbackEl as web.HTMLElement).style.display = 'block';
      } else if (errorEl != null) {
        final htmlError = errorEl as web.HTMLElement;
        htmlError.style.display = 'block';
        htmlError.textContent = 'PDF render error: $err';
      }
    });
  }

  @override
  View build() {
    final pdfFallbackUrl = src.contains('#') ? src : '$src#toolbar=0&navpanes=0&scrollbar=0';

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
        // 🔹 Navigation & Zoom Toolbar
        if (showToolbar)
          DocViewerToolbar(
            controller: _effectiveController,
            title: title,
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
            loadingWidget ?? Text.span('⚡ Rendering High-Fidelity PDF Canvas Studio...'),
          ],
        ),

        // 🔹 Fallback Iframe
        Container(
          props: {
            'id': '$_instanceId-fallback',
            'style': {'display': 'none', 'width': '100%'},
          },
          dartStyle: DartStyle(
            width: const SizeValue('min(940px, 100%)'),
            height: const SizeValue('80vh'),
            radius: 8,
            overflow: 'hidden',
            border: Border.all(color: const Color.rgba(255, 255, 255, 0.12)),
          ),
          children: [
            Iframe(
              src: pdfFallbackUrl,
              title: title ?? 'PDF Preview',
              style: const {
                'width': '100%',
                'height': '100%',
                'border': 'none',
                'background': '#0a0d12',
              },
            ),
          ],
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

        // 🔹 Multi-page PDF Canvas Mount Target
        Container(
          props: {'id': '$_instanceId-mount', 'class': 'flint-pdf-container'},
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
