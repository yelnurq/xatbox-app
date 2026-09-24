import '../../../shared/utils/api_date.dart';

/// An official announcement as seen by the signed-in recipient
/// (`OfficialMessage` of the Mail API).
///
/// Timestamps come as PostgreSQL `timestamptz` text
/// (`2026-09-14 09:00:00+00`) and are parsed by [parseApiDate]. `read_at` /
/// `acknowledged_at` are the caller's own and omitted until set. The body is
/// plain text: never render it as HTML.
class OfficialMessage {
  const OfficialMessage({
    required this.id,
    required this.senderName,
    required this.senderRole,
    required this.title,
    required this.body,
    required this.requiresAcknowledgement,
    this.createdAt,
    this.readAt,
    this.acknowledgedAt,
  });

  final String id;

  /// Sender display name, or email.
  final String senderName;

  /// Role code at send time (e.g. `org_admin`), or `member`.
  final String senderRole;
  final String title;
  final String body;
  final bool requiresAcknowledgement;
  final DateTime? createdAt;
  final DateTime? readAt;
  final DateTime? acknowledgedAt;

  bool get isRead => readAt != null;
  bool get isAcknowledged => acknowledgedAt != null;

  /// «Требует ознакомления» and not yet acknowledged.
  bool get awaitsAcknowledgement => requiresAcknowledgement && !isAcknowledged;

  factory OfficialMessage.fromJson(Map<String, dynamic> json) =>
      OfficialMessage(
        id: (json['id'] as String?) ?? '',
        senderName: (json['sender_name'] as String?) ?? '',
        senderRole: (json['sender_role'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        requiresAcknowledgement: json['requires_acknowledgement'] == true,
        createdAt: parseApiDate(json['created_at'] as String?),
        readAt: parseApiDate(json['read_at'] as String?),
        acknowledgedAt: parseApiDate(json['acknowledged_at'] as String?),
      );

  /// Cache representation (RFC 3339, re-parsed by [fromJson]).
  Map<String, dynamic> toJson() => {
    'id': id,
    'sender_name': senderName,
    'sender_role': senderRole,
    'title': title,
    'body': body,
    'requires_acknowledgement': requiresAcknowledgement,
    'created_at': ?createdAt?.toUtc().toIso8601String(),
    'read_at': ?readAt?.toUtc().toIso8601String(),
    'acknowledged_at': ?acknowledgedAt?.toUtc().toIso8601String(),
  };

  OfficialMessage copyWith({DateTime? readAt, DateTime? acknowledgedAt}) =>
      OfficialMessage(
        id: id,
        senderName: senderName,
        senderRole: senderRole,
        title: title,
        body: body,
        requiresAcknowledgement: requiresAcknowledgement,
        createdAt: createdAt,
        readAt: readAt ?? this.readAt,
        acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      );

  /// Server cap of `GET /official` (no pagination).
  static const maxItems = 200;
}

/// `OfficialStats`: recipient counts of a message the caller sent. The API
/// returns only aggregates (no per-recipient list); an unknown id or a
/// message of another sender yields all zeros rather than 404.
class OfficialStats {
  const OfficialStats({
    required this.sent,
    required this.delivered,
    required this.read,
    required this.acknowledged,
  });

  final int sent;
  final int delivered;
  final int read;
  final int acknowledged;

  bool get isEmpty => sent == 0;

  static int _int(Object? v) => v is num ? v.toInt() : 0;

  factory OfficialStats.fromJson(Map<String, dynamic> json) => OfficialStats(
    sent: _int(json['sent']),
    delivered: _int(json['delivered']),
    read: _int(json['read']),
    acknowledged: _int(json['acknowledged']),
  );
}

/// `OfficialCreateRequest`. Only documented keys are sent (the server rejects
/// unknown fields — with an empty 200, see `OfficialApi.create`).
class OfficialDraft {
  const OfficialDraft({
    required this.title,
    required this.body,
    this.requiresAcknowledgement = false,
    this.wholeOrganization = false,
    this.departmentIds = const [],
    this.userIds = const [],
  });

  final String title;
  final String body;
  final bool requiresAcknowledgement;
  final bool wholeOrganization;
  final List<String> departmentIds;
  final List<String> userIds;

  bool get hasContent => title.trim().isNotEmpty && body.trim().isNotEmpty;
  bool get hasRecipients =>
      wholeOrganization || departmentIds.isNotEmpty || userIds.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'body': body.trim(),
    'requires_acknowledgement': requiresAcknowledgement,
    if (wholeOrganization) 'whole_organization': true,
    if (!wholeOrganization && departmentIds.isNotEmpty)
      'department_ids': departmentIds,
    if (!wholeOrganization && userIds.isNotEmpty) 'user_ids': userIds,
  };
}

/// `OfficialCreateResponse`.
class OfficialCreated {
  const OfficialCreated({required this.id, required this.recipientCount});
  final String id;
  final int recipientCount;
}

/// A message the signed-in user sent from this device. `GET /official` does
/// not list the sender's own messages, so the app remembers them locally to
/// reopen their statistics.
class SentOfficial {
  const SentOfficial({
    required this.id,
    required this.title,
    required this.recipientCount,
    required this.requiresAcknowledgement,
    this.sentAt,
  });

  final String id;
  final String title;
  final int recipientCount;
  final bool requiresAcknowledgement;
  final DateTime? sentAt;

  factory SentOfficial.fromJson(Map<String, dynamic> json) => SentOfficial(
    id: (json['id'] as String?) ?? '',
    title: (json['title'] as String?) ?? '',
    recipientCount: (json['recipient_count'] as num?)?.toInt() ?? 0,
    requiresAcknowledgement: json['requires_acknowledgement'] == true,
    sentAt: parseApiDate(json['sent_at'] as String?),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'recipient_count': recipientCount,
    'requires_acknowledgement': requiresAcknowledgement,
    'sent_at': ?sentAt?.toUtc().toIso8601String(),
  };
}
