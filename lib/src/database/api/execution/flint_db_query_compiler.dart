import 'package:flint_dart/flint_dart.dart';

class FlintDbQueryCompiler {
  const FlintDbQueryCompiler(this.config);

  final FlintDatabaseApiConfig config;

  QueryBuilder compile(
    FlintDbResource resource,
    FlintDbQuery query, {
    DbExecutor? executor,
  }) {
    if (!resource.allows(FlintDbOperation.select)) {
      throw const FlintDbApiException(
        FlintDbErrorCode.permissionDenied,
        'The operation is not allowed.',
        statusCode: 403,
      );
    }

    _validateQuery(resource, query);
    final builder = QueryBuilder(
      table: resource.tableName,
      executor: executor,
    );

    final fields = query.select.isEmpty
        ? resource.readableFields.toList(growable: false)
        : query.select;
    builder.select(fields);

    if (query.filter != null) {
      _applyFilter(builder, query.filter!);
    }
    for (final order in query.order) {
      builder.orderBy(order.field, order.descending ? 'DESC' : 'ASC');
    }
    builder.limit(query.limit ?? config.maxPageSize);
    if (query.offset != null) builder.offset(query.offset!);
    return builder;
  }

  void _validateQuery(FlintDbResource resource, FlintDbQuery query) {
    if (query.cursor != null) {
      throw const FlintDbApiException(
        FlintDbErrorCode.invalidRequest,
        'Cursor pagination is not available in this release.',
      );
    }
    if (query.select.length > config.maxSelectedFields) {
      throw FlintDbApiException(
        FlintDbErrorCode.queryLimitExceeded,
        'Too many fields were selected.',
        details: {'maximum': config.maxSelectedFields},
      );
    }
    for (final field in query.select) {
      _requireReadableField(resource, field);
    }
    if (query.limit != null &&
        (query.limit! < 1 || query.limit! > config.maxPageSize)) {
      throw FlintDbApiException(
        FlintDbErrorCode.queryLimitExceeded,
        'The requested page size is outside the allowed range.',
        details: {'maximum': config.maxPageSize},
      );
    }
    if (query.offset != null && query.offset! < 0) {
      throw const FlintDbApiException(
        FlintDbErrorCode.invalidRequest,
        'Offset cannot be negative.',
      );
    }
    if (query.order.length > 5) {
      throw const FlintDbApiException(
        FlintDbErrorCode.queryLimitExceeded,
        'Too many order clauses were supplied.',
      );
    }
    for (final order in query.order) {
      _requireReadableField(resource, order.field);
    }
    if (query.filter != null) {
      final count = _validateFilter(resource, query.filter!, 1);
      if (count > config.maxFilterComparisons) {
        throw FlintDbApiException(
          FlintDbErrorCode.queryLimitExceeded,
          'Too many filter comparisons were supplied.',
          details: {'maximum': config.maxFilterComparisons},
        );
      }
    }
  }

  int _validateFilter(
    FlintDbResource resource,
    FlintDbFilter filter,
    int depth,
  ) {
    if (depth > config.maxLogicalDepth) {
      throw FlintDbApiException(
        FlintDbErrorCode.queryLimitExceeded,
        'Filter nesting exceeds the allowed depth.',
        details: {'maximum': config.maxLogicalDepth},
      );
    }
    if (filter is FlintDbComparison) {
      if (!resource.readableFields.contains(filter.field) &&
          !resource.policyFields.contains(filter.field)) {
        throw const FlintDbApiException(
          FlintDbErrorCode.permissionDenied,
          'A requested field is not available.',
          statusCode: 403,
        );
      }
      if ((filter.operator == FlintDbOperator.inside ||
              filter.operator == FlintDbOperator.notIn) &&
          filter.value is! List) {
        throw const FlintDbApiException(
          FlintDbErrorCode.invalidRequest,
          'The in and notIn operators require a list value.',
        );
      }
      return 1;
    }
    final logical = filter as FlintDbLogicalFilter;
    if (logical.operator != FlintDbLogicalOperator.and) {
      throw const FlintDbApiException(
        FlintDbErrorCode.invalidRequest,
        'OR and NOT filters require grouped-query support and are not yet available.',
      );
    }
    return logical.filters.fold<int>(
      0,
      (count, child) => count + _validateFilter(resource, child, depth + 1),
    );
  }

  void _applyFilter(QueryBuilder builder, FlintDbFilter filter) {
    if (filter is FlintDbLogicalFilter) {
      for (final child in filter.filters) {
        _applyFilter(builder, child);
      }
      return;
    }
    final comparison = filter as FlintDbComparison;
    switch (comparison.operator) {
      case FlintDbOperator.eq:
        builder.where(comparison.field, '=', comparison.value);
      case FlintDbOperator.neq:
        builder.where(comparison.field, '!=', comparison.value);
      case FlintDbOperator.gt:
        builder.where(comparison.field, '>', comparison.value);
      case FlintDbOperator.gte:
        builder.where(comparison.field, '>=', comparison.value);
      case FlintDbOperator.lt:
        builder.where(comparison.field, '<', comparison.value);
      case FlintDbOperator.lte:
        builder.where(comparison.field, '<=', comparison.value);
      case FlintDbOperator.inside:
        builder.whereIn(
            comparison.field, List<dynamic>.from(comparison.value as List));
      case FlintDbOperator.notIn:
        builder.whereNotIn(
          comparison.field,
          List<dynamic>.from(comparison.value as List),
        );
      case FlintDbOperator.isNull:
        builder.whereNull(comparison.field);
      case FlintDbOperator.isNotNull:
        builder.whereNotNull(comparison.field);
      case FlintDbOperator.contains:
        builder.whereContains(comparison.field, comparison.value.toString());
      case FlintDbOperator.startsWith:
        builder.whereStartsWith(comparison.field, comparison.value.toString());
      case FlintDbOperator.endsWith:
        builder.whereEndsWith(comparison.field, comparison.value.toString());
    }
  }

  void _requireReadableField(FlintDbResource resource, String field) {
    if (!resource.readableFields.contains(field)) {
      throw const FlintDbApiException(
        FlintDbErrorCode.permissionDenied,
        'A requested field is not available.',
        statusCode: 403,
      );
    }
  }
}
