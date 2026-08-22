import 'style.dart';

final List<String> _collectedStyleCss = [];
final Set<String> _registeredStyleSheets = {};
final Set<String> _registeredRootDesigns = {};

void registerRootDesign(RootDesign design) {
  if (_registeredRootDesigns.contains(design.name)) return;

  final cssText = design.cssText.trim();
  if (cssText.isEmpty) return;

  _collectedStyleCss.add(cssText);
  _registeredRootDesigns.add(design.name);
}

void registerStyleSheet(StyleSheet stylesheet) {
  if (_registeredStyleSheets.contains(stylesheet.name)) return;

  final cssText = stylesheet.cssText.trim();
  if (cssText.isEmpty) return;

  _collectedStyleCss.add(cssText);
  _registeredStyleSheets.add(stylesheet.name);
}

String consumeCollectedStyleCss() {
  final cssText = _collectedStyleCss.join('\n');
  resetCollectedStyleCss();
  return cssText;
}

void resetCollectedStyleCss() {
  _collectedStyleCss.clear();
  _registeredRootDesigns.clear();
  _registeredStyleSheets.clear();
}
