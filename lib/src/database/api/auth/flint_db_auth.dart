class FlintDbAuth {
  const FlintDbAuth._({required this.enabled, this.defaultRole});

  const FlintDbAuth.disabled() : this._(enabled: false);
  const FlintDbAuth.enabled({this.defaultRole = 'user'}) : enabled = true;

  final bool enabled;
  final String? defaultRole;
}
