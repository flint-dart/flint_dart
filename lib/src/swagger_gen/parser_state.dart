/// Tracks parser state while processing a file
class ParserState {
  List<String> docBuffer = [];
  String? currentClassPrefixFromDocs;
  String? currentGroupPrefix;
  String? currentGroupTag;
  bool insideRouteGroupClass = false;
}
