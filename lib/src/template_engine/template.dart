import 'package:flint_dart/src/template_engine/all_expression/base_run.dart';

import 'all_expression/all_expression.dart';
import 'template_reader.dart';

class TemplateEngine {
  static final TemplateEngine _singleton = TemplateEngine._internal();
  factory TemplateEngine() => _singleton;
  TemplateEngine._internal();

  final SectionProcessor _sectionProcessor = SectionProcessor();

  final Map<String, dynamic> sessionErrors = {};
  final Map<String, dynamic> formData = {};
  final Map<String, dynamic> sessions = {};

  String render(String template, [Map<String, dynamic>? data]) {
    String templateContent = FileTemplateReader().read(template);
    var realdata = {...(data ?? {}), "templateName": template};
    String renderedTemplate = renderString(templateContent, realdata);
    sessionErrors.clear();
    formData.clear();
    sessions.clear();
    return renderedTemplate;
  }

  /// Renders a template string with the provided data context.
  ///
  /// This function processes the template content by running it through a pipeline
  /// of processors, including extends, include, section, for loop, switch case,
  /// conditional, and variables processors. Each processor modifies the template
  /// content based on the provided context data.
  ///
  /// The context data is first merged with any child sections parsed from the template content.
  ///
  /// Returns the fully rendered content as a string.
  ///
  /// Parameters:
  /// - [templateContent]: The raw template content to be rendered.
  /// - [data] (optional): A map of context data to be used for rendering the template.
  ///   If not provided, an empty map is used.
  ///
  String renderString(String templateContent, [Map<String, dynamic>? data]) {
    data = {
      ...data ?? {},
      ..._sectionProcessor.parseChildSections(templateContent),
    };

    final pipeline = _Processing([
      ExtendsProcessor(),
      _sectionProcessor,
      // ErrorProcessor(),
      SessionProcessor(),
      ForLoopProcessor(),
      SwitchCasesProcessor(),
      IfStatementProcessor(),
      VariablesProcessor(),

      OldProcessor(),
      // TranslateProcessor(),
      CommentProcessor(),
      // RouteProcessor(),
      AssetsProcessor(),
      IncludeProcessor(),
    ]);

    final renderedContent = pipeline.run(templateContent, data);
    return renderedContent;
  }
}

class _Processing {
  final List<BaseExpression> _processors;

  _Processing(this._processors);

  String run(String content, Map<String, dynamic> data) {
    for (final processor in _processors) {
      content = processor.run(content, data);
    }
    return content;
  }
}
