/// Visual reading theme for rendered documents.
enum DocReadingMode {
  /// Authentic white paper mode (exact document styling).
  paper,

  /// Dark canvas mode with high-contrast text for night reading.
  dark,

  /// Warm sepia tone for reduced eye strain.
  sepia,
}

/// Represents an entry in a document's Table of Contents (Outline).
class DocTocItem {
  DocTocItem({
    required this.title,
    this.pageNumber = 1,
    this.dest,
    this.children = const [],
  });

  /// The section / heading title.
  final String title;

  /// Target 1-based page number.
  final int pageNumber;

  /// Raw destination object or anchor.
  final Object? dest;

  /// Subsections / nested headings.
  final List<DocTocItem> children;
}

/// Controller to programmatically navigate, zoom, search, switch reading modes,
/// and inspect document pages in [PdfViewer] and [DocxViewer].
class DocViewerController {
  DocViewerController({
    double initialZoom = 1.0,
    int initialPage = 1,
    DocReadingMode initialReadingMode = DocReadingMode.paper,
  })  : _zoom = initialZoom,
        _currentPage = initialPage,
        _readingMode = initialReadingMode;

  int _currentPage = 1;
  int _totalPages = 1;
  double _zoom = 1.0;
  String _searchQuery = '';
  int _currentMatch = 0;
  int _totalMatches = 0;
  List<DocTocItem> _tableOfContents = [];
  bool _showOutline = false;
  DocReadingMode _readingMode = DocReadingMode.paper;

  final List<void Function()> _listeners = [];

  // Internal hooks bound by the active viewer
  void Function(int page)? onJumpToPage;
  void Function(double scale)? onSetZoom;
  void Function(String query)? onSearch;
  void Function(DocReadingMode mode)? onSetReadingMode;
  void Function()? onNextMatch;
  void Function()? onPrevMatch;

  /// Current 1-based active page.
  int get currentPage => _currentPage;

  /// Total number of pages in the loaded document.
  int get totalPages => _totalPages;

  /// Current zoom multiplier (e.g. 1.0 = 100%, 1.5 = 150%).
  double get zoom => _zoom;

  /// Current active search term.
  String get searchQuery => _searchQuery;

  /// Active highlighted match index (1-based).
  int get currentMatch => _currentMatch;

  /// Total search occurrences found.
  int get totalMatches => _totalMatches;

  /// Extracted Table of Contents / Document Outline.
  List<DocTocItem> get tableOfContents => _tableOfContents;

  /// Whether the Table of Contents sidebar is open.
  bool get showOutline => _showOutline;

  /// Current reading mode (paper, dark, sepia).
  DocReadingMode get readingMode => _readingMode;

  /// Adds a change listener.
  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  /// Removes a change listener.
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void _notify() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  /// Sets document metadata (invoked by the viewer).
  void updateDocumentMeta({
    int? currentPage,
    int? totalPages,
    List<DocTocItem>? toc,
  }) {
    if (currentPage != null) _currentPage = currentPage;
    if (totalPages != null) _totalPages = totalPages;
    if (toc != null) _tableOfContents = toc;
    _notify();
  }

  /// Updates search match statistics.
  void updateSearchMatches({
    required int current,
    required int total,
  }) {
    _currentMatch = current;
    _totalMatches = total;
    _notify();
  }

  /// Toggles Table of Contents / Outline sidebar.
  void toggleOutline([bool? show]) {
    _showOutline = show ?? !_showOutline;
    _notify();
  }

  /// Changes the active reading mode.
  void setReadingMode(DocReadingMode mode) {
    _readingMode = mode;
    onSetReadingMode?.call(mode);
    _notify();
  }

  /// Cycles to next reading mode (paper -> dark -> sepia -> paper).
  void toggleReadingMode() {
    switch (_readingMode) {
      case DocReadingMode.paper:
        setReadingMode(DocReadingMode.dark);
        break;
      case DocReadingMode.dark:
        setReadingMode(DocReadingMode.sepia);
        break;
      case DocReadingMode.sepia:
        setReadingMode(DocReadingMode.paper);
        break;
    }
  }

  /// Navigates directly to [page] (1-indexed).
  void jumpToPage(int page) {
    final target = page.clamp(1, _totalPages > 0 ? _totalPages : 1);
    _currentPage = target;
    onJumpToPage?.call(target);
    _notify();
  }

  /// Navigates to the next page.
  void nextPage() {
    if (_currentPage < _totalPages) {
      jumpToPage(_currentPage + 1);
    }
  }

  /// Navigates to the previous page.
  void prevPage() {
    if (_currentPage > 1) {
      jumpToPage(_currentPage - 1);
    }
  }

  /// Updates zoom level to [scale] (clamped between 0.4x and 3.0x).
  void setZoom(double scale) {
    final target = scale.clamp(0.4, 3.0);
    _zoom = target;
    onSetZoom?.call(target);
    _notify();
  }

  /// Increases zoom by 20%.
  void zoomIn() {
    setZoom((_zoom + 0.2).clamp(0.4, 3.0));
  }

  /// Decreases zoom by 20%.
  void zoomOut() {
    setZoom((_zoom - 0.2).clamp(0.4, 3.0));
  }

  /// Resets zoom to 100%.
  void resetZoom() {
    setZoom(1.0);
  }

  /// Executes full-text search across document pages.
  void search(String query) {
    _searchQuery = query;
    onSearch?.call(query);
    _notify();
  }

  /// Navigates to next search match.
  void nextMatch() {
    onNextMatch?.call();
  }

  /// Navigates to previous search match.
  void prevMatch() {
    onPrevMatch?.call();
  }
}
