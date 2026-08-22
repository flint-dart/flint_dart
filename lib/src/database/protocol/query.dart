enum FlintDbOperator {
  eq('eq'),
  neq('neq'),
  gt('gt'),
  gte('gte'),
  lt('lt'),
  lte('lte'),
  inside('in'),
  notIn('notIn'),
  isNull('isNull'),
  isNotNull('isNotNull'),
  contains('contains'),
  startsWith('startsWith'),
  endsWith('endsWith');

  const FlintDbOperator(this.value);
  final String value;

  static FlintDbOperator parse(String value) => values.firstWhere(
        (operator) => operator.value == value,
        orElse: () => throw FormatException('Unknown Flint DB operator: $value'),
      );
}

enum FlintDbLogicalOperator {
  and('and'),
  or('or'),
  not('not');

  const FlintDbLogicalOperator(this.value);
  final String value;

  static FlintDbLogicalOperator parse(String value) => values.firstWhere(
        (operator) => operator.value == value,
        orElse: () =>
            throw FormatException('Unknown Flint DB logical operator: $value'),
      );
}

sealed class FlintDbFilter {
  const FlintDbFilter();

  factory FlintDbFilter.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('field')) return FlintDbComparison.fromJson(json);
    return FlintDbLogicalFilter.fromJson(json);
  }

  Map<String, dynamic> toJson();
}

class FlintDbComparison extends FlintDbFilter {
  const FlintDbComparison(this.field, this.operator, [this.value]);

  final String field;
  final FlintDbOperator operator;
  final Object? value;

  factory FlintDbComparison.fromJson(Map<String, dynamic> json) {
    final field = json['field']?.toString();
    final operator = json['operator']?.toString();
    if (field == null || field.isEmpty || operator == null) {
      throw const FormatException('A comparison requires field and operator.');
    }
    return FlintDbComparison(
      field,
      FlintDbOperator.parse(operator),
      json['value'],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'field': field,
        'operator': operator.value,
        if (operator != FlintDbOperator.isNull &&
            operator != FlintDbOperator.isNotNull)
          'value': value,
      };
}

class FlintDbLogicalFilter extends FlintDbFilter {
  const FlintDbLogicalFilter(this.operator, this.filters);

  final FlintDbLogicalOperator operator;
  final List<FlintDbFilter> filters;

  factory FlintDbLogicalFilter.fromJson(Map<String, dynamic> json) {
    if (json.length != 1) {
      throw const FormatException(
        'A logical filter must contain exactly one logical operator.',
      );
    }
    final entry = json.entries.single;
    final operator = FlintDbLogicalOperator.parse(entry.key);
    final rawFilters = entry.value;
    if (rawFilters is! List) {
      throw const FormatException('Logical filter value must be a list.');
    }
    final filters = rawFilters
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Filter entries must be objects.');
          }
          return FlintDbFilter.fromJson(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);
    if (filters.isEmpty) {
      throw const FormatException('Logical filters cannot be empty.');
    }
    if (operator == FlintDbLogicalOperator.not && filters.length != 1) {
      throw const FormatException('The not operator requires one filter.');
    }
    return FlintDbLogicalFilter(operator, filters);
  }

  @override
  Map<String, dynamic> toJson() => {
        operator.value: filters.map((filter) => filter.toJson()).toList(),
      };
}

class FlintDbOrder {
  const FlintDbOrder(this.field, {this.descending = false});

  final String field;
  final bool descending;

  factory FlintDbOrder.fromJson(Map<String, dynamic> json) {
    final field = json['field']?.toString();
    if (field == null || field.isEmpty) {
      throw const FormatException('Order requires a field.');
    }
    final direction = json['direction']?.toString().toLowerCase() ?? 'asc';
    if (direction != 'asc' && direction != 'desc') {
      throw FormatException('Invalid order direction: $direction');
    }
    return FlintDbOrder(field, descending: direction == 'desc');
  }

  Map<String, dynamic> toJson() => {
        'field': field,
        'direction': descending ? 'desc' : 'asc',
      };
}

class FlintDbQuery {
  const FlintDbQuery({
    this.select = const [],
    this.filter,
    this.order = const [],
    this.limit,
    this.offset,
    this.cursor,
  });

  final List<String> select;
  final FlintDbFilter? filter;
  final List<FlintDbOrder> order;
  final int? limit;
  final int? offset;
  final String? cursor;

  factory FlintDbQuery.fromJson(Map<String, dynamic> json) {
    final rawSelect = json['select'];
    final rawOrder = json['order'];
    final rawFilter = json['filter'];
    return FlintDbQuery(
      select: rawSelect is List
          ? rawSelect.map((item) => item.toString()).toList(growable: false)
          : const [],
      filter: rawFilter is Map
          ? FlintDbFilter.fromJson(Map<String, dynamic>.from(rawFilter))
          : null,
      order: rawOrder is List
          ? rawOrder
              .map((item) => FlintDbOrder.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ))
              .toList(growable: false)
          : const [],
      limit: _readInt(json['limit'], 'limit'),
      offset: _readInt(json['offset'], 'offset'),
      cursor: json['cursor']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (select.isNotEmpty) 'select': select,
        if (filter != null) 'filter': filter!.toJson(),
        if (order.isNotEmpty) 'order': order.map((item) => item.toJson()).toList(),
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
        if (cursor != null) 'cursor': cursor,
      };

  static int? _readInt(Object? value, String name) {
    if (value == null) return null;
    if (value is int) return value;
    final parsed = int.tryParse(value.toString());
    if (parsed == null) throw FormatException('$name must be an integer.');
    return parsed;
  }
}
