import '../../flint_dart.dart';

/// A base class for grouping and organizing HTTP routes in Flint.
///
/// A [RouteGroup] allows you to:
/// - Group related routes into a single class
/// - Apply a common URL prefix (e.g. `/auth`, `/api/v1`)
/// - Apply middleware to all routes in the group
/// - Keep large applications modular and maintainable
///
/// Route groups are registered using [Flint.routes]:
///
/// ```dart
/// void main() {
///   final app = Flint();
///
///   app.routes(AuthRoutes());
///
///   app.listen(3000);
/// }
/// ```
///
/// ---
///
/// ### Basic example
///
/// ```dart
/// class AuthRoutes extends RouteGroup {
///
///   String get prefix => '/auth';
///
///
///   void register(Flint app) {
///     app.post('/login', login);
///     app.post('/register', register);
///   }
/// }
/// ```
///
/// ---
///
/// ### Using middleware
///
/// ```dart
/// class AdminRoutes extends RouteGroup {
///
///   String get prefix => '/admin';
///
///
///   List<Middleware> get middlewares => [AuthMiddleware()];
///
///   void register(Flint app) {
///     app.get('/dashboard', dashboard);
///   }
/// }
/// ```
///
/// ---
///
/// ### Notes
///
/// - Route paths defined inside [register] are **relative** to [prefix].
/// - Middlewares defined in [middlewares] are applied **before**
///   route-level middlewares.
/// - Route groups can be versioned by changing the [prefix].
///
/// See also:
/// - [Flint.routes]
/// - [Flint.mount]
abstract class RouteGroup {
  /// URL prefix for this route group (e.g. `/auth`, `/api/v1`).
  ///
  /// Defaults to an empty string, meaning no prefix is applied.
  String get prefix => '';

  /// Optional tag name for this route group.
  ///
  /// This is intended for tooling and documentation purposes
  /// (e.g. Swagger/OpenAPI grouping).
  ///
  /// Example:
  /// ```dart
  /// @override
  /// String get tag => 'Auth';
  /// ```
  ///
  /// Defaults to an empty string.
  String get tag => '';

  /// Middlewares applied to **all routes** in this group.
  ///
  /// These middlewares run after global middlewares
  /// and before any route-specific middleware.
  ///
  /// Defaults to an empty list.
  List<Middleware> get middlewares => const [];

  /// Registers all routes belonging to this group.
  ///
  /// This method is called internally by Flint when the group
  /// is registered using [Flint.routes].
  ///
  /// Implementations should define routes using the [Flint] API:
  ///
  /// ```dart
  /// void register(Flint app) {
  ///   app.get('/profile', profile);
  /// }
  /// ```
  void register(Flint app);
}
