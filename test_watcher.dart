import 'dart:io';

void main() {
  print("Helloo");
  final watcher = Directory('lib').watch(recursive: true);
  watcher.listen((event) {
    print('Event: ${event.type} Path: ${event.path}');
  });
  print('Watching lib/ ...');
}
