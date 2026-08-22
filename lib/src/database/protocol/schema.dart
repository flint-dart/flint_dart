class FlintDbFieldSchema {
  const FlintDbFieldSchema({
    required this.name,
    required this.type,
    required this.nullable,
    this.primary = false,
    this.writable = false,
  });

  final String name;
  final String type;
  final bool nullable;
  final bool primary;
  final bool writable;

  factory FlintDbFieldSchema.fromJson(Map<String, dynamic> json) =>
      FlintDbFieldSchema(
        name: json['name']?.toString() ?? '',
        type: json['type']?.toString() ?? 'unknown',
        nullable: json['nullable'] == true,
        primary: json['primary'] == true,
        writable: json['writable'] == true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'nullable': nullable,
        'primary': primary,
        'writable': writable,
      };
}

class FlintDbResourceSchema {
  const FlintDbResourceSchema({
    required this.name,
    required this.operations,
    required this.fields,
  });

  final String name;
  final Set<String> operations;
  final List<FlintDbFieldSchema> fields;

  factory FlintDbResourceSchema.fromJson(Map<String, dynamic> json) =>
      FlintDbResourceSchema(
        name: json['name']?.toString() ?? '',
        operations: (json['operations'] as List? ?? const [])
            .map((item) => item.toString())
            .toSet(),
        fields: (json['fields'] as List? ?? const [])
            .map((item) => FlintDbFieldSchema.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'operations': operations.toList()..sort(),
        'fields': fields.map((field) => field.toJson()).toList(),
      };
}
