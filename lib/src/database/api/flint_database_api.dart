import 'dart:math';

import '../../../flint_dart.dart';
import '../../../auth.dart';

class FlintDatabaseApi {
  FlintDatabaseApi({
    FlintDatabaseApiConfig? config,
    Iterable<FlintDbResource> resources = const [],
  })  : config = config ?? FlintDatabaseApiConfig(),
        registry = FlintDbResourceRegistry(resources);

  final FlintDatabaseApiConfig config;
  final FlintDbResourceRegistry registry;

  void register(Flint app) {
    app.routes(_FlintDatabaseRoutes(this));
  }

  Map<String, dynamic>? identity(Context context) {
    final token = context.req.authToken;
    if (token == null || token.isEmpty || !config.auth.enabled) return null;
    return Auth.verifyToken(token);
  }

  Future<List<Map<String, dynamic>>> select(
    String resourceName,
    FlintDbQuery query, {
    DbExecutor? executor,
    FlintDbFilter? enforcedFilter,
  }) async {
    final resource = registry.resolve(resourceName);
    final effectiveQuery = FlintDbQuery(
      select: query.select,
      filter: _combineFilters(query.filter, enforcedFilter),
      order: query.order,
      limit: query.limit,
      offset: query.offset,
      cursor: query.cursor,
    );
    final builder = FlintDbQueryCompiler(config).compile(
      resource,
      effectiveQuery,
      executor: executor,
    );
    final rows = await builder.get();
    return rows.map(resource.concealRow).toList(growable: false);
  }

  FlintDbFilter? _combineFilters(
      FlintDbFilter? requested, FlintDbFilter? enforced) {
    if (requested == null) return enforced;
    if (enforced == null) return requested;
    return FlintDbLogicalFilter(
      FlintDbLogicalOperator.and,
      [requested, enforced],
    );
  }
}

extension FlintDatabaseApiExtension on Flint {
  void databaseApi(FlintDatabaseApi api) => api.register(this);
}

class _FlintDatabaseRoutes extends RouteGroup {
  _FlintDatabaseRoutes(this.api);

  final FlintDatabaseApi api;

  @override
  String get prefix => api.config.basePath;

  @override
  String get tag => 'Flint DB API';

  @override
  void register(Flint app) {
    app.get('/health', _health);
    if (api.config.auth.enabled) {
      app.post('/auth/register', _registerAccount);
      app.post('/auth/login', _login);
      app.get('/auth/me', _me);
    }
    app.get('/schema', _schema);
    app.get('/:resource', _list);
    app.get('/:resource/:id', _find);
    app.query('/:resource', _query);
    app.post('/:resource/query', _query);
    app.post('/:resource', _insert);
    app.patch('/:resource/:id', _update);
    app.delete('/:resource/:id', _delete);
  }

  Future<Response?> _health(Context ctx) async => ctx.res?.json({
        'status': 'ok',
        'service': 'flint_db_api',
      });

  Future<Response?> _schema(Context ctx) async {
    try {
      await _requireAuthorized(ctx);
      return await ctx.res?.json(
        _success(
          ctx,
          api.registry.schema().map((resource) => resource.toJson()).toList(),
          count: api.registry.resources.length,
        ),
      );
    } on FlintDbApiException catch (error) {
      return await ctx.res?.status(error.statusCode).json(_failure(ctx, error));
    }
  }

  Future<Response?> _list(Context ctx) async {
    try {
      final resourceName = _requiredParam(ctx, 'resource');
      final resource = api.registry.resolve(resourceName);
      await _requireAuthorized(ctx, resource);
      final query = _queryFromUrl(ctx.req);
      final rows = await api.select(
        resourceName,
        query,
        enforcedFilter: await _readFilter(ctx, resourceName),
      );
      return await ctx.res?.json(_success(ctx, rows, count: rows.length));
    } on FlintDbApiException catch (error) {
      return await ctx.res?.status(error.statusCode).json(_failure(ctx, error));
    } on FormatException catch (error) {
      return await ctx.res?.status(400).json(
            _failure(
              ctx,
              FlintDbApiException(
                FlintDbErrorCode.invalidRequest,
                error.message,
              ),
            ),
          );
    } catch (_) {
      return await ctx.res?.status(500).json(
            _failure(
              ctx,
              const FlintDbApiException(
                FlintDbErrorCode.internalError,
                'The database request could not be completed.',
                statusCode: 500,
              ),
            ),
          );
    }
  }

  Future<Response?> _find(Context ctx) async {
    try {
      final resourceName = _requiredParam(ctx, 'resource');
      final resource = api.registry.resolve(resourceName);
      await _requireAuthorized(ctx, resource);
      final id = _requiredParam(ctx, 'id');
      final rows = await api.select(
        resourceName,
        FlintDbQuery(
          filter: FlintDbComparison(
            resource.primaryKey,
            FlintDbOperator.eq,
            id,
          ),
          limit: 1,
        ),
        enforcedFilter: await _readFilter(ctx, resourceName),
      );
      if (rows.isEmpty) {
        throw const FlintDbApiException(
          FlintDbErrorCode.recordNotFound,
          'The requested record was not found.',
          statusCode: 404,
        );
      }
      return await ctx.res?.json(_success(ctx, rows.first, count: 1));
    } on FlintDbApiException catch (error) {
      return await ctx.res?.status(error.statusCode).json(_failure(ctx, error));
    } catch (_) {
      return await ctx.res?.status(500).json(
            _failure(
              ctx,
              const FlintDbApiException(
                FlintDbErrorCode.internalError,
                'The database request could not be completed.',
                statusCode: 500,
              ),
            ),
          );
    }
  }

  Future<Response?> _query(Context ctx) async {
    try {
      final resourceName = _requiredParam(ctx, 'resource');
      final resource = api.registry.resolve(resourceName);
      await _requireAuthorized(ctx, resource);
      final body = await ctx.req.json();
      final query = FlintDbQuery.fromJson(body);
      final rows = await api.select(
        resourceName,
        query,
        enforcedFilter: await _readFilter(ctx, resourceName),
      );
      return await ctx.res?.json(_success(ctx, rows, count: rows.length));
    } on FlintDbApiException catch (error) {
      return await ctx.res?.status(error.statusCode).json(_failure(ctx, error));
    } on FormatException catch (error) {
      return await ctx.res?.status(400).json(
            _failure(
              ctx,
              FlintDbApiException(
                FlintDbErrorCode.invalidRequest,
                error.message,
              ),
            ),
          );
    } catch (_) {
      return await ctx.res?.status(500).json(
            _failure(
              ctx,
              const FlintDbApiException(
                FlintDbErrorCode.internalError,
                'The database request could not be completed.',
                statusCode: 500,
              ),
            ),
          );
    }
  }

  Future<Response?> _registerAccount(Context ctx) async {
    try {
      final body = await ctx.req.json();
      await Validator.validate(body, {
        'name': 'required|string|min:2|max:80',
        'email': 'required|email',
        'password': 'required|string|min:6',
      });
      final user = await Auth.register(
        name: body['name'].toString().trim(),
        email: body['email'].toString().trim().toLowerCase(),
        password: body['password'].toString(),
        additionalData: {
          if (api.config.auth.defaultRole case final role?) 'role': role,
        },
      );
      return await ctx.res?.status(201).json(
            _success(ctx, {
              'user': user,
              'token': Auth.generateToken(user),
            }),
          );
    } on ValidationException catch (error) {
      return await ctx.res?.status(422).json(
            _failure(
              ctx,
              FlintDbApiException(
                FlintDbErrorCode.validationFailed,
                'Please correct the registration details.',
                statusCode: 422,
                details: error.errors,
              ),
            ),
          );
    } on AuthException catch (error) {
      return await ctx.res?.status(409).json(
            _failure(
              ctx,
              FlintDbApiException(
                FlintDbErrorCode.conflict,
                error.message,
                statusCode: 409,
              ),
            ),
          );
    }
  }

  Future<Response?> _login(Context ctx) async {
    try {
      final body = await ctx.req.json();
      final result = await Auth.login(
        body['email']?.toString().trim().toLowerCase() ?? '',
        body['password']?.toString() ?? '',
      );
      return await ctx.res?.json(_success(ctx, result));
    } on AuthException catch (_) {
      return await ctx.res?.status(401).json(
            _failure(
              ctx,
              const FlintDbApiException(
                FlintDbErrorCode.invalidToken,
                'Invalid email or password.',
                statusCode: 401,
              ),
            ),
          );
    }
  }

  Future<Response?> _me(Context ctx) async {
    final identity = api.identity(ctx);
    if (identity == null) {
      return await ctx.res?.status(401).json(
            _failure(
              ctx,
              const FlintDbApiException(
                FlintDbErrorCode.authenticationRequired,
                'Authentication is required.',
                statusCode: 401,
              ),
            ),
          );
    }
    return await ctx.res?.json(_success(ctx, identity));
  }

  Future<Response?> _insert(Context ctx) async {
    try {
      final resource = api.registry.resolve(_requiredParam(ctx, 'resource'));
      await _requireAuthorized(ctx, resource);
      _requireOperation(resource, FlintDbOperation.insert);
      final data = _writablePayload(resource, await ctx.req.json());
      _injectOwner(ctx, resource, data);
      await _validateParents(ctx, resource, data, required: true);
      await QueryBuilder(table: resource.tableName).insert(data);
      final row = await _ownedBuilder(ctx, resource)
          .where(resource.primaryKey, '=', data[resource.primaryKey])
          .first();
      return await ctx.res?.status(201).json(
            _success(ctx, row == null ? data : resource.concealRow(row)),
          );
    } on FlintDbApiException catch (error) {
      return await ctx.res?.status(error.statusCode).json(_failure(ctx, error));
    } catch (_) {
      return await _internalFailure(ctx);
    }
  }

  Future<Response?> _update(Context ctx) async {
    try {
      final resource = api.registry.resolve(_requiredParam(ctx, 'resource'));
      await _requireAuthorized(ctx, resource);
      _requireOperation(resource, FlintDbOperation.update);
      final id = _requiredParam(ctx, 'id');
      final builder = _ownedBuilder(ctx, resource)
        ..where(resource.primaryKey, '=', id);
      if (await builder.first() == null) return await _recordNotFound(ctx);
      final data = _writablePayload(resource, await ctx.req.json());
      if (data.isEmpty) {
        throw const FlintDbApiException(
          FlintDbErrorCode.validationFailed,
          'At least one writable field is required.',
          statusCode: 422,
        );
      }
      await _validateParents(ctx, resource, data);
      await (_ownedBuilder(ctx, resource)..where(resource.primaryKey, '=', id))
          .update(data);
      final row = await (_ownedBuilder(ctx, resource)
            ..where(resource.primaryKey, '=', id))
          .first();
      return await ctx.res?.json(_success(ctx, resource.concealRow(row!)));
    } on FlintDbApiException catch (error) {
      return await ctx.res?.status(error.statusCode).json(_failure(ctx, error));
    } catch (_) {
      return await _internalFailure(ctx);
    }
  }

  Future<Response?> _delete(Context ctx) async {
    try {
      final resource = api.registry.resolve(_requiredParam(ctx, 'resource'));
      await _requireAuthorized(ctx, resource);
      _requireOperation(resource, FlintDbOperation.delete);
      final id = _requiredParam(ctx, 'id');
      final builder = _ownedBuilder(ctx, resource)
        ..where(resource.primaryKey, '=', id);
      if (await builder.first() == null) return await _recordNotFound(ctx);
      await (_ownedBuilder(ctx, resource)..where(resource.primaryKey, '=', id))
          .delete();
      return await ctx.res?.json(_success(ctx, {'deleted': true}));
    } on FlintDbApiException catch (error) {
      return await ctx.res?.status(error.statusCode).json(_failure(ctx, error));
    } catch (_) {
      return await _internalFailure(ctx);
    }
  }

  FlintDbQuery _queryFromUrl(Request request) {
    final select = request
        .queryParam('select')
        ?.split(',')
        .map((field) => field.trim())
        .where((field) => field.isNotEmpty)
        .toList(growable: false);
    final order = request.queryParam('order');
    return FlintDbQuery(
      select: select ?? const [],
      order: order == null || order.isEmpty
          ? const []
          : [
              FlintDbOrder(
                order.split('.').first,
                descending: order.split('.').last.toLowerCase() == 'desc',
              ),
            ],
      limit: _parseOptionalInt(request.queryParam('limit'), 'limit'),
      offset: _parseOptionalInt(request.queryParam('offset'), 'offset'),
    );
  }

  int? _parseOptionalInt(String? value, String name) {
    if (value == null) return null;
    final parsed = int.tryParse(value);
    if (parsed == null) throw FormatException('$name must be an integer.');
    return parsed;
  }

  String _requiredParam(Context ctx, String name) {
    final value = ctx.req.param(name);
    if (value == null || value.isEmpty) {
      throw FlintDbApiException(
        FlintDbErrorCode.invalidRequest,
        'Missing route parameter: $name.',
      );
    }
    return value;
  }

  Future<void> _requireAuthorized(
    Context ctx, [
    FlintDbResource? resource,
  ]) async {
    final authorizer = api.config.authorizer;
    final authorized = authorizer != null
        ? await authorizer(ctx)
        : api.config.auth.enabled && api.identity(ctx) != null;
    if (!authorized) {
      throw const FlintDbApiException(
        FlintDbErrorCode.authenticationRequired,
        'Authentication is required.',
        statusCode: 401,
      );
    }
    if (resource != null && !resource.permitsIdentity(api.identity(ctx))) {
      throw const FlintDbApiException(
        FlintDbErrorCode.permissionDenied,
        'The operation is not allowed.',
        statusCode: 403,
      );
    }
  }

  Future<FlintDbFilter?> _readFilter(Context ctx, String resourceName) async {
    final resource = api.registry.resolve(resourceName);
    final custom = await resource.readFilter?.call(ctx);
    final owner = resource.ownerPolicy;
    if (owner == null) return custom;
    final value = api.identity(ctx)?[owner.identityField];
    if (value == null) {
      throw const FlintDbApiException(
        FlintDbErrorCode.permissionDenied,
        'The operation is not allowed.',
        statusCode: 403,
      );
    }
    return api._combineFilters(
      custom,
      FlintDbComparison(owner.field, FlintDbOperator.eq, value),
    );
  }

  void _requireOperation(FlintDbResource resource, FlintDbOperation operation) {
    if (!resource.allows(operation)) {
      throw const FlintDbApiException(
        FlintDbErrorCode.permissionDenied,
        'The operation is not allowed.',
        statusCode: 403,
      );
    }
  }

  Map<String, dynamic> _writablePayload(
    FlintDbResource resource,
    Map<String, dynamic> body,
  ) {
    final unknown = body.keys.where(
      (field) => !resource.writableFields.contains(field),
    );
    if (unknown.isNotEmpty) {
      throw FlintDbApiException(
        FlintDbErrorCode.validationFailed,
        'One or more fields are not writable.',
        statusCode: 422,
        details: {'fields': unknown.toList(growable: false)},
      );
    }
    return Map<String, dynamic>.from(body);
  }

  void _injectOwner(
    Context ctx,
    FlintDbResource resource,
    Map<String, dynamic> data,
  ) {
    final owner = resource.ownerPolicy;
    if (owner == null) return;
    final value = api.identity(ctx)?[owner.identityField];
    if (value == null) {
      throw const FlintDbApiException(
        FlintDbErrorCode.permissionDenied,
        'The operation is not allowed.',
        statusCode: 403,
      );
    }
    data[owner.field] = value;
  }

  QueryBuilder _ownedBuilder(Context ctx, FlintDbResource resource) {
    final builder = QueryBuilder(table: resource.tableName);
    final owner = resource.ownerPolicy;
    if (owner != null) {
      final value = api.identity(ctx)?[owner.identityField];
      if (value == null) {
        throw const FlintDbApiException(
          FlintDbErrorCode.permissionDenied,
          'The operation is not allowed.',
          statusCode: 403,
        );
      }
      builder.where(owner.field, '=', value);
    }
    return builder;
  }

  Future<void> _validateParents(
    Context ctx,
    FlintDbResource resource,
    Map<String, dynamic> data, {
    bool required = false,
  }) async {
    for (final policy in resource.parentPolicies) {
      if (!data.containsKey(policy.field)) {
        if (required) {
          throw FlintDbApiException(
            FlintDbErrorCode.validationFailed,
            'A parent reference is required.',
            statusCode: 422,
            details: {'field': policy.field},
          );
        }
        continue;
      }
      final parent = api.registry.resolve(policy.parentResource);
      final parentId = data[policy.field];
      final builder = _ownedBuilder(ctx, parent)
        ..where(parent.primaryKey, '=', parentId);
      if (await builder.first() == null) {
        throw const FlintDbApiException(
          FlintDbErrorCode.validationFailed,
          'The referenced parent record is not available.',
          statusCode: 422,
        );
      }
    }
  }

  Future<Response?> _recordNotFound(Context ctx) async {
    final response = ctx.res;
    if (response == null) return null;
    return await response.status(404).json(
          _failure(
            ctx,
            const FlintDbApiException(
              FlintDbErrorCode.recordNotFound,
              'The requested record was not found.',
              statusCode: 404,
            ),
          ),
        );
  }

  Future<Response?> _internalFailure(Context ctx) async {
    final response = ctx.res;
    if (response == null) return null;
    return await response.status(500).json(
          _failure(
            ctx,
            const FlintDbApiException(
              FlintDbErrorCode.internalError,
              'The database request could not be completed.',
              statusCode: 500,
            ),
          ),
        );
  }

  Map<String, dynamic> _success(
    Context ctx,
    Object? data, {
    int? count,
  }) =>
      FlintDbResult<Object?>.success(
        data,
        FlintDbMeta(requestId: _requestId(ctx), count: count),
      ).toJson((value) => value);

  Map<String, dynamic> _failure(
    Context ctx,
    FlintDbApiException error,
  ) =>
      FlintDbResult<Object?>.failure(
        error.toProtocolError(),
        FlintDbMeta(requestId: _requestId(ctx)),
      ).toJson((value) => value);

  String _requestId(Context ctx) {
    final existing = ctx.req.headers['x-request-id'];
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    return 'req_${DateTime.now().microsecondsSinceEpoch}_$random';
  }
}
