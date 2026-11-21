// query_condition.dart

/// Represents a typed query condition to avoid raw SQL operator strings.
class QueryCondition {
  final String operator;
  final dynamic value;

  const QueryCondition(this.operator, this.value);
}

/// Namespace for typed query operators to avoid top-level name collisions:
/// ```dart
/// where('role', Op.equals('admin'))
/// where('age', Op.greaterThan(18))
/// ```
abstract final class Op {
  /// `Op.equals('admin')` -> `=`
  static QueryCondition equals(dynamic value) => QueryCondition('=', value);

  /// `Op.notEquals('banned')` -> `!=`
  static QueryCondition notEquals(dynamic value) => QueryCondition('!=', value);

  /// `Op.greaterThan(18)` or `Op.gt(18)` -> `>`
  static QueryCondition greaterThan(dynamic value) => QueryCondition('>', value);
  static QueryCondition gt(dynamic value) => QueryCondition('>', value);

  /// `Op.greaterThanOrEqual(18)` or `Op.gte(18)` -> `>=`
  static QueryCondition greaterThanOrEqual(dynamic value) => QueryCondition('>=', value);
  static QueryCondition gte(dynamic value) => QueryCondition('>=', value);

  /// `Op.lessThan(100)` or `Op.lt(100)` -> `<`
  static QueryCondition lessThan(dynamic value) => QueryCondition('<', value);
  static QueryCondition lt(dynamic value) => QueryCondition('<', value);

  /// `Op.lessThanOrEqual(100)` or `Op.lte(100)` -> `<=`
  static QueryCondition lessThanOrEqual(dynamic value) => QueryCondition('<=', value);
  static QueryCondition lte(dynamic value) => QueryCondition('<=', value);
}
