import 'dart:isolate';

import 'package:flint_dart/ai.dart' show flintAiTables;
import 'package:flint_dart/schema.dart';
import 'package:sample/models/post_model.dart';
import 'package:sample/models/user_model.dart';

void main(dynamic data, SendPort? sendPort) {
  runTableRegistry([
    ...flintAiTables,
    User().table,
    PostModel().table,
  ], data, sendPort);
}
