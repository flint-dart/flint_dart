class Head {
  // ---------- Standard HTML head fields ----------
  String? title;

  // SEO + meta
  String? description;
  String? keywords;
  String? viewport;
  String? author;
  String? charset;
  String? robots;

  // Extra custom meta tags
  Map<String, String> meta;

  // <link> tags: icon, stylesheet, manifest, etc.
  Map<String, String> links;

  // <style> tags
  List<String> styles;

  // <script> tags
  List<String> scripts;

  Head({
    this.title,
    this.description,
    this.keywords,
    this.viewport = "width=device-width, initial-scale=1.0",
    this.author,
    this.charset = "utf-8",
    this.robots,
    this.meta = const {},
    this.links = const {},
    this.styles = const [],
    this.scripts = const [],
  });

  // ---------- Render to HTML ----------
  String toHtml() {
    final buffer = StringBuffer();

    if (title != null) buffer.writeln('<title>$title</title>');
    if (charset != null) buffer.writeln('<meta charset="$charset" />');
    if (description != null) {
      buffer.writeln('<meta name="description" content="$description" />');
    }
    if (keywords != null) {
      buffer.writeln('<meta name="keywords" content="$keywords" />');
    }
    if (viewport != null) {
      buffer.writeln('<meta name="viewport" content="$viewport" />');
    }
    if (author != null) {
      buffer.writeln('<meta name="author" content="$author" />');
    }
    if (robots != null) {
      buffer.writeln('<meta name="robots" content="$robots" />');
    }

    meta.forEach((name, content) {
      buffer.writeln('<meta name="$name" content="$content" />');
    });

    links.forEach((rel, href) {
      buffer.writeln('<link rel="$rel" href="$href" />');
    });

    for (final css in styles) {
      buffer.writeln('<style>$css</style>');
    }
    for (final js in scripts) {
      buffer.writeln('<script>$js</script>');
    }
    buffer.write(
        '<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>');
    return buffer.toString();
  }

  // ---------- Serialize to JSON ----------
  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'keywords': keywords,
        'viewport': viewport,
        'author': author,
        'charset': charset,
        'robots': robots,
        'meta': meta,
        'links': links,
        'styles': styles,
        'scripts': scripts,
      };
}
