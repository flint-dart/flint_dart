class AuthConfig {
  final String table;
  final String emailColumn;
  final String? providerColumn; // e.g. 'provider'
  final String? providerIdColumn; // e.g. 'provider_id'
  final String? nameColumn; // e.g. 'name'
  final String? passwordColumn;
  final String? redirectBase;
  final String? googleClientSecret;
  final String? googleClientId;

  AuthConfig({
    required this.table,
    this.emailColumn = 'email',
    this.providerColumn,
    this.providerIdColumn,
    this.passwordColumn,
    this.nameColumn = 'name',
    this.redirectBase,
    this.googleClientSecret,
    this.googleClientId,
  });
}
