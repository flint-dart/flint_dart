import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

class OtpModel extends Model<OtpModel> {
  @override
  String? id;
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
  OtpModel fromMap(Map map) {
    return OtpModel();
  }

  @override
  Map<String, dynamic> toMap() {
    // TODO: implement toMap
    throw UnimplementedError();
  }
}
