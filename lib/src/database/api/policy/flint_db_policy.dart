abstract class FlintDbPolicy {
  const FlintDbPolicy();
}

/// Restricts every operation to rows whose [field] matches the JWT user ID.
/// The field is injected on insert and cannot be supplied by the client.
class FlintDbOwnerPolicy extends FlintDbPolicy {
  const FlintDbOwnerPolicy({this.field = 'user_id', this.identityField = 'id'});

  final String field;
  final String identityField;
}

/// Requires [field] to reference a parent row owned by the same JWT identity.
class FlintDbParentPolicy extends FlintDbPolicy {
  const FlintDbParentPolicy({
    required this.field,
    required this.parentResource,
  });

  final String field;
  final String parentResource;
}

/// Allows a resource only when the JWT identity contains one of [roles].
class FlintDbRolePolicy extends FlintDbPolicy {
  const FlintDbRolePolicy.allow(this.roles, {this.identityField = 'role'});

  final Set<String> roles;
  final String identityField;
}
