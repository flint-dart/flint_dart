import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

class AdeOfe extends Model<AdeOfe> {
  @override
  String? id;

  // Define your fields here
  String? name;

  @override
  Table get table => Table(
    name: 'ade_ofes',
    columns: [
      Column(name: 'name', type: ColumnType.string),
    ],
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
  };

  @override
  AdeOfe fromMap(Map<String, dynamic> map) {
    return AdeOfe()
      ..id = map['id']
      ..name = map['name'];
  }
}
