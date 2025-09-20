import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

class StudentModel extends Model<StudentModel> {
  int? id;

  // Define your fields here
  String? name;

  @override
  Table get table => Table(
        name: 'student_models',
        columns: [
          Column(
              name: 'id',
              type: ColumnType.integer,
              isPrimaryKey: true,
              isAutoIncrement: true),
          Column(name: 'name', type: ColumnType.string),
        ],
      );

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
      };

  @override
  StudentModel fromMap(Map<String, dynamic> map) {
    return StudentModel()
      ..id = map['id']
      ..name = map['name'];
  }
}
