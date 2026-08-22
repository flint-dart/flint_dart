import 'dart:async';

import 'package:flint_dart/flint_dart.dart';

typedef FlintModelFactory = Model Function();
typedef FlintDbReadFilter = FutureOr<FlintDbFilter?> Function(Context context);

/// Package-owned secure default for authenticated model CRUD.
///
/// Example: `resources: [Todo.new.resource, Subtask.new.resource]`.
extension FlintDbModelResourceExtension<T extends Model<T>> on T Function() {
  FlintDbResource get resource => FlintDbResource.ownedCrud(this);
}

/// Instance form of the authenticated CRUD convention.
///
/// Example: `resources: [Todo().resource, Subtask().resource]`.
extension FlintDbModelInstanceResourceExtension<T extends Model<T>> on T {
  FlintDbResource get resource => FlintDbResource.ownedCrud(newInstance);
}

class FlintDbResource {
  /// Creates an authenticated CRUD resource using Flint model conventions.
  ///
  /// The model must contain [ownerField]. Primary, owner, concealed, and
  /// explicitly hidden fields are never writable. `belongsTo` foreign keys are
  /// protected with parent ownership policies automatically.
  factory FlintDbResource.ownedCrud(
    FlintModelFactory modelFactory, {
    String? name,
    String ownerField = 'user_id',
    Set<String> hiddenFields = const {},
  }) {
    final model = modelFactory();
    final fields = model.table.columns.map((column) => column.name).toSet();
    if (!fields.contains(ownerField)) {
      throw ArgumentError.value(
        ownerField,
        'ownerField',
        'Owned CRUD resources must declare an ownership column.',
      );
    }
    final concealed = model.conceal.toSet();
    final parents = model.relations.values
        .where((relation) => relation.type == RelationType.belongsTo)
        .map(
          (relation) => FlintDbParentPolicy(
            field: relation.foreignKey,
            parentResource: relation.relatedFactory().table.name,
          ),
        )
        .toList(growable: false);
    final writable = fields.difference({
      model.primaryKey,
      ownerField,
      ...concealed,
      ...hiddenFields,
    });

    return FlintDbResource.fromModel(
      modelFactory,
      name: name,
      operations: const {
        FlintDbOperation.select,
        FlintDbOperation.insert,
        FlintDbOperation.update,
        FlintDbOperation.delete,
      },
      hiddenFields: hiddenFields,
      writableFields: writable,
      policies: [
        FlintDbOwnerPolicy(field: ownerField),
        ...parents,
      ],
    );
  }

  FlintDbResource.fromModel(
    this.modelFactory, {
    String? name,
    Set<FlintDbOperation> operations = const {},
    Set<String> hiddenFields = const {},
    Set<String> writableFields = const {},
    this.readFilter,
    List<FlintDbPolicy> policies = const [],
  })  : model = modelFactory(),
        allowedOperations = Set.unmodifiable(operations),
        hiddenFields = Set.unmodifiable(hiddenFields),
        writableFields = Set.unmodifiable(writableFields),
        appliedPolicies = List.unmodifiable(policies),
        _configuredName = name {
    _validateIdentifier(resourceName, 'resource');
    for (final field in {...hiddenFields, ...writableFields}) {
      _validateIdentifier(field, 'field');
      if (!fieldNames.contains(field)) {
        throw ArgumentError.value(
          field,
          'field',
          'Field is not declared by model ${model.runtimeType}.',
        );
      }
    }
    for (final policy in policies) {
      if (policy is FlintDbOwnerPolicy) {
        _validateIdentifier(policy.field, 'owner field');
        if (!fieldNames.contains(policy.field)) {
          throw ArgumentError.value(
            policy.field,
            'owner field',
            'Field is not declared by model ${model.runtimeType}.',
          );
        }
        if (writableFields.contains(policy.field)) {
          throw ArgumentError.value(
            policy.field,
            'writableFields',
            'Policy-owned fields cannot be client writable.',
          );
        }
      }
      if (policy is FlintDbParentPolicy) {
        _validateIdentifier(policy.field, 'parent field');
        _validateIdentifier(policy.parentResource, 'parent resource');
        if (!fieldNames.contains(policy.field)) {
          throw ArgumentError.value(
            policy.field,
            'parent field',
            'Field is not declared by model ${model.runtimeType}.',
          );
        }
        if (!writableFields.contains(policy.field)) {
          throw ArgumentError.value(
            policy.field,
            'writableFields',
            'Parent reference fields must be explicitly writable.',
          );
        }
      }
    }
  }

  final FlintModelFactory modelFactory;
  final Model model;
  final String? _configuredName;
  final Set<FlintDbOperation> allowedOperations;
  final Set<String> hiddenFields;
  final Set<String> writableFields;
  final FlintDbReadFilter? readFilter;
  final List<FlintDbPolicy> appliedPolicies;

  FlintDbOwnerPolicy? get ownerPolicy {
    for (final policy in appliedPolicies) {
      if (policy is FlintDbOwnerPolicy) return policy;
    }
    return null;
  }

  Iterable<FlintDbParentPolicy> get parentPolicies =>
      appliedPolicies.whereType<FlintDbParentPolicy>();

  Iterable<FlintDbRolePolicy> get rolePolicies =>
      appliedPolicies.whereType<FlintDbRolePolicy>();

  String get resourceName => _configuredName ?? model.table.name;
  String get tableName => model.table.name;
  String get primaryKey => model.primaryKey;
  Set<String> get fieldNames =>
      model.table.columns.map((column) => column.name).toSet();
  Set<String> get concealedFields => model.conceal.toSet();
  Set<String> get policyFields => {
        for (final policy in appliedPolicies)
          if (policy is FlintDbOwnerPolicy) policy.field,
      };
  Set<String> get readableFields => fieldNames
      .difference({...hiddenFields, ...concealedFields, ...policyFields});

  bool allows(FlintDbOperation operation) =>
      allowedOperations.contains(operation);

  bool permitsIdentity(Map<String, dynamic>? identity) {
    for (final policy in rolePolicies) {
      final role = identity?[policy.identityField]?.toString();
      if (role == null || !policy.roles.contains(role)) return false;
    }
    return true;
  }

  /// Replaces the automatically inferred operation grants.
  FlintDbResource operations(Set<FlintDbOperation> operations) => _copyWith(
        operations: operations,
      );

  /// Adds policies while retaining inferred ownership and parent policies.
  FlintDbResource policies(Iterable<FlintDbPolicy> policies) => _copyWith(
        policies: [...appliedPolicies, ...policies],
      );

  FlintDbResource policy(FlintDbPolicy policy) => policies([policy]);

  FlintDbResource readOnly() => operations(const {FlintDbOperation.select});

  FlintDbResource createOnly() => operations(const {
        FlintDbOperation.select,
        FlintDbOperation.insert,
      });

  FlintDbResource adminOnly({String role = 'admin'}) =>
      policy(FlintDbRolePolicy.allow({role}));

  FlintDbResource _copyWith({
    Set<FlintDbOperation>? operations,
    Iterable<FlintDbPolicy>? policies,
  }) =>
      FlintDbResource.fromModel(
        modelFactory,
        name: resourceName,
        operations: operations ?? allowedOperations,
        hiddenFields: hiddenFields,
        writableFields: writableFields,
        readFilter: readFilter,
        policies: policies?.toList(growable: false) ?? appliedPolicies,
      );

  FlintDbResourceSchema toSchema() => FlintDbResourceSchema(
        name: resourceName,
        operations:
            allowedOperations.map((operation) => operation.name).toSet(),
        fields: model.table.columns
            .where((column) => readableFields.contains(column.name))
            .map(
              (column) => FlintDbFieldSchema(
                name: column.name,
                type: column.type.name,
                nullable: column.isNullable,
                primary: column.isPrimaryKey,
                writable: writableFields.contains(column.name),
              ),
            )
            .toList(growable: false),
      );

  Map<String, dynamic> concealRow(Map<String, dynamic> row) => {
        for (final entry in row.entries)
          if (readableFields.contains(entry.key)) entry.key: entry.value,
      };

  static final RegExp _safeIdentifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  static void _validateIdentifier(String value, String label) {
    if (!_safeIdentifier.hasMatch(value)) {
      throw ArgumentError.value(value, label, 'Unsafe database identifier.');
    }
  }
}
