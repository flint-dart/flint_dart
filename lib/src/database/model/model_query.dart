// model_query.dart
//
// Query builder methods are now defined directly on Model<T> in model.dart so
// Model subclasses can be queried without importing separate extension files.
// This extension is preserved for backwards compatibility.

import 'model.dart';

extension ModelQuery<T extends Model<T>> on Model<T> {}
