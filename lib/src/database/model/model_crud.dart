// model_crud.dart
//
// CRUD methods are now defined directly on Model<T> in model.dart so Model
// subclasses expose create/update/delete/upsert without separate extension imports.
// This extension is preserved for backwards compatibility.

import 'model.dart';

extension ModelCrud<T extends Model<T>> on Model<T> {}
