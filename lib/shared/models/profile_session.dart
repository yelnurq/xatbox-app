/// `ProfileSession` schema (`GET /me/sessions`).
class ProfileSession {
  const ProfileSession({
    required this.id,
    required this.current,
    required this.browser,
    required this.os,
    required this.kind,
    required this.createdAt,
    required this.lastSeenAt,
    required this.expiresAt,
    this.ip,
  });

  final String id;
  final bool current;
  final String browser;
  final String os;
  final String kind;
  final String? ip;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final DateTime? expiresAt;

  factory ProfileSession.fromJson(Map<String, dynamic> json) {
    final device =
        (json['device'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ProfileSession(
      id: json['id'] as String,
      current: json['current'] == true,
      browser: (device['browser'] as String?) ?? '',
      os: (device['os'] as String?) ?? '',
      kind: (device['kind'] as String?) ?? 'other',
      ip: json['ip'] as String?,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
      lastSeenAt: DateTime.tryParse((json['last_seen_at'] as String?) ?? ''),
      expiresAt: DateTime.tryParse((json['expires_at'] as String?) ?? ''),
    );
  }

  String get deviceLabel {
    final parts = [browser, os].where((p) => p.isNotEmpty).join(' · ');
    return parts.isEmpty ? kind : parts;
  }
}
