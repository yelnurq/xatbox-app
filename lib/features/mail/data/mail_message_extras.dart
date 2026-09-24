import '../../../shared/utils/api_date.dart';

/// `MailDeliveryRecipient`.
class MailDeliveryRecipient {
  const MailDeliveryRecipient({
    required this.address,
    required this.status,
    this.error,
  });

  final String address;

  /// `pending`, `delivered`, `relayed`, `failed`, `quarantined`.
  final String status;
  final String? error;

  factory MailDeliveryRecipient.fromJson(Map<String, dynamic> json) =>
      MailDeliveryRecipient(
        address: (json['address'] as String?) ?? '',
        status: (json['status'] as String?) ?? '',
        error: json['error'] as String?,
      );
}

/// `MailDeliveryEvent`.
class MailDeliveryEvent {
  const MailDeliveryEvent({required this.type, required this.createdAt});

  /// Open list, e.g. `email.accepted`, `email.delivered_local`.
  final String type;

  /// PostgreSQL text timestamp, parsed.
  final DateTime? createdAt;

  factory MailDeliveryEvent.fromJson(Map<String, dynamic> json) =>
      MailDeliveryEvent(
        type: (json['type'] as String?) ?? '',
        createdAt: parseApiDate(json['created_at'] as String?),
      );
}

/// `MailMessageEvents` — delivery timeline of a sent message.
class MailDeliveryReport {
  const MailDeliveryReport({
    required this.status,
    required this.recipients,
    required this.events,
  });

  /// Empty when the platform has no send record for the message.
  final String status;
  final List<MailDeliveryRecipient> recipients;

  /// Oldest first.
  final List<MailDeliveryEvent> events;

  bool get isEmpty => status.isEmpty && recipients.isEmpty && events.isEmpty;

  factory MailDeliveryReport.fromJson(Map<String, dynamic> json) =>
      MailDeliveryReport(
        status: (json['status'] as String?) ?? '',
        recipients: ((json['recipients'] as List?) ?? const [])
            .map(
              (e) => MailDeliveryRecipient.fromJson(
                (e as Map).cast<String, dynamic>(),
              ),
            )
            .toList(),
        events: ((json['events'] as List?) ?? const [])
            .map(
              (e) =>
                  MailDeliveryEvent.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList(),
      );
}

/// iCalendar METHOD of an invitation attachment.
enum MailInvitationMethod {
  request,
  cancel,
  reply;

  static MailInvitationMethod parse(String? raw) =>
      switch (raw?.toUpperCase()) {
        'CANCEL' => cancel,
        'REPLY' => reply,
        _ => request,
      };
}

/// `MailCalendarInvitation`.
class MailCalendarInvitation {
  const MailCalendarInvitation({
    required this.method,
    required this.uid,
    required this.sequence,
    required this.title,
    required this.description,
    required this.location,
    required this.startsAt,
    required this.endsAt,
    required this.timezone,
    required this.status,
    required this.organizerEmail,
    required this.organizerName,
    required this.attendees,
    this.rrule,
    this.partstat,
  });

  final MailInvitationMethod method;
  final String uid;
  final int sequence;
  final String title;
  final String description;
  final String location;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// IANA zone from the invitation; may be empty.
  final String timezone;

  /// iCalendar STATUS uppercased (`CONFIRMED`, `CANCELLED`, …); may be empty.
  final String status;
  final String organizerEmail;
  final String organizerName;
  final List<String> attendees;
  final String? rrule;

  /// Lowercased PARTSTAT (mainly REPLY).
  final String? partstat;

  bool get isCancelled =>
      method == MailInvitationMethod.cancel || status == 'CANCELLED';

  String get organizerLabel =>
      organizerName.isNotEmpty ? organizerName : organizerEmail;

  factory MailCalendarInvitation.fromJson(Map<String, dynamic> json) =>
      MailCalendarInvitation(
        method: MailInvitationMethod.parse(json['method'] as String?),
        uid: (json['uid'] as String?) ?? '',
        sequence: (json['sequence'] as num?)?.toInt() ?? 0,
        title: (json['title'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        location: (json['location'] as String?) ?? '',
        startsAt: parseApiDate(json['starts_at'] as String?)?.toUtc(),
        endsAt: parseApiDate(json['ends_at'] as String?)?.toUtc(),
        timezone: (json['timezone'] as String?) ?? '',
        status: ((json['status'] as String?) ?? '').toUpperCase(),
        organizerEmail: (json['organizer_email'] as String?) ?? '',
        organizerName: (json['organizer_name'] as String?) ?? '',
        attendees: ((json['attendees'] as List?) ?? const []).cast<String>(),
        rrule: (json['rrule'] as String?)?.isNotEmpty == true
            ? json['rrule'] as String
            : null,
        partstat: (json['partstat'] as String?)?.isNotEmpty == true
            ? (json['partstat'] as String).toLowerCase()
            : null,
      );
}

/// Response to an invitation (`MailCalendarRespondRequest.status`).
enum MailRsvp {
  accepted,
  tentative,
  declined;

  static MailRsvp? tryParse(String? raw) => switch (raw?.toLowerCase()) {
    'accepted' => accepted,
    'tentative' => tentative,
    'declined' => declined,
    _ => null,
  };
}

/// `MailCalendarInvitationPreview`.
class MailInvitationPreview {
  const MailInvitationPreview({
    required this.invitation,
    required this.blobId,
    this.eventId,
    this.status,
  });

  final MailCalendarInvitation invitation;
  final String blobId;

  /// Existing calendar event with the same UID; null when none.
  final String? eventId;

  /// Caller's response on that event (`accepted`, `tentative`, `declined`,
  /// `pending`); null when none.
  final String? status;

  MailInvitationPreview copyWith({String? eventId, String? status}) =>
      MailInvitationPreview(
        invitation: invitation,
        blobId: blobId,
        eventId: eventId ?? this.eventId,
        status: status ?? this.status,
      );

  factory MailInvitationPreview.fromJson(Map<String, dynamic> json) =>
      MailInvitationPreview(
        invitation: MailCalendarInvitation.fromJson(
          (json['invitation'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        blobId: (json['blob_id'] as String?) ?? '',
        eventId: (json['event_id'] as String?)?.isNotEmpty == true
            ? json['event_id'] as String
            : null,
        status: (json['status'] as String?)?.isNotEmpty == true
            ? json['status'] as String
            : null,
      );
}

/// `MailCalendarRespondResponse`.
class MailInvitationResponse {
  const MailInvitationResponse({required this.eventId, required this.status});

  /// Empty for REPLY invitations.
  final String eventId;
  final String status;

  factory MailInvitationResponse.fromJson(Map<String, dynamic> json) =>
      MailInvitationResponse(
        eventId: (json['event_id'] as String?) ?? '',
        status: (json['status'] as String?) ?? '',
      );
}
