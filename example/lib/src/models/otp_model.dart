import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

class OtpModel extends Model<OtpModel> {
  @override
  String? id;

  // Define your fields here
  String? field1;
  String? field2;
  DateTime? createdAt;

  @override
  Table get table => Table(
        name: 'table_name',
        columns: [
          Column(name: 'field1', type: ColumnType.string),
          Column(name: 'field2', type: ColumnType.string),
        ],
      );

  @override
  Map<String, dynamic> toMap() =>
      {'id': id, 'field1': field1, 'field2': field2, "created_at": createdAt};

  @override
  OtpModel fromMap(Map<String, dynamic> map) {
    return OtpModel()
      ..id = map['id']
      ..field1 = map['field1']
      ..field2 = map['field2']
      ..createdAt = map["created_at"];
  }
}
