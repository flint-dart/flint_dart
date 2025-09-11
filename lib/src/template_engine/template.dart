import 'dart:io';

class TemplateEngine {
  final String viewsPath;

  TemplateEngine({this.viewsPath = 'views'});

  /// Main render function
  /// Only `.flint.html` files are processed with sections/includes
  Future<String> render(String template, {Map<String, dynamic>? data}) async {
    if (!template.endsWith('.flint.html')) {
      // Return raw content for normal HTML files
      final file = File('$viewsPath/$template');
      if (!await file.exists()) {
        throw Exception('Template not found: $template');
      }
      return await file.readAsString();
    }

    final file = File('$viewsPath/$template');
    if (!await file.exists()) throw Exception('Template not found: $template');

    String content = await file.readAsString();

    // Process includes
    content = await _processIncludes(content, data);

    // Process layout/extends
    content = await _processExtends(content, data);

    // Replace variables {{key}}
    if (data != null) {
      data.forEach((key, value) {
        content = content.replaceAll('{{$key}}', value.toString());
      });
    }

    return content;
  }

  /// Handles @include('file') directives
  Future<String> _processIncludes(
      String content, Map<String, dynamic>? data) async {
    final includeRegex = RegExp(r"@include\('(.+?)'\)");
    final matches = includeRegex.allMatches(content).toList();

    for (final match in matches) {
      final includeFile = match.group(1)!;
      final includedContent =
          await render('$includeFile.flint.html', data: data);
      content = content.replaceFirst(match.group(0)!, includedContent);
    }

    return content;
  }

  /// Handles @extends('layout') and @section/@yield
  Future<String> _processExtends(
      String content, Map<String, dynamic>? data) async {
    final extendsRegex = RegExp(r"@extends\('(.+?)'\)");
    final match = extendsRegex.firstMatch(content);

    if (match != null) {
      final layoutFile = match.group(1)!;
      String layoutContent = await render('$layoutFile.flint.html', data: data);

      // Collect sections from the child template
      final sectionRegex = RegExp(r"@section\('(.+?)'\)([\s\S]*?)@endsection");
      final sections = <String, String>{};

      for (final m in sectionRegex.allMatches(content)) {
        sections[m.group(1)!] = m.group(2)!;
      }

      // Replace @yield('sectionName') in layout with child sections
      sections.forEach((name, sectionContent) {
        layoutContent =
            layoutContent.replaceAll("@yield('$name')", sectionContent);
      });

      return layoutContent;
    }

    return content;
  }
}
