import '../../../shared/utils/api_date.dart';

/// Longest in-call chat message (the server enforces the same).
const callChatMaxLength = 2000;

enum CallChatStatus { sending, sent, failed }

/// A message of the in-call chat. [id] is the client message id: the same
/// value travels over the data channel, the Call Service
/// (`client_message_id`) and — for calls of a conversation — the chat
/// outbox, so every copy of one message collapses into one bubble.
class CallChatMessage {
  const CallChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.senderName = '',
    this.local = false,
    this.status = CallChatStatus.sent,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String body;
  final DateTime createdAt;

  /// Sent from this device.
  final bool local;
  final CallChatStatus status;

  CallChatMessage copyWith({CallChatStatus? status}) => CallChatMessage(
    id: id,
    senderId: senderId,
    senderName: senderName,
    body: body,
    createdAt: createdAt,
    local: local,
    status: status ?? this.status,
  );

  /// Data channel payload (`type: chat`).
  Map<String, Object?> toData() => {
    'type': 'chat',
    'id': id,
    'sender_id': senderId,
    'sender_name': senderName,
    'body': body,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  /// A `chat` data packet. [identity] is the LiveKit sender (`''` for
  /// packets the Call Service sends): a participant can only speak for
  /// itself, only the server may name the sender.
  static CallChatMessage? fromData(String identity, Map<String, Object?> p) {
    final id = p['id'];
    final body = p['body'];
    if (id is! String || id.isEmpty || id.length > 64 || body is! String) return null;
    final text = body.trim();
    if (text.isEmpty || text.length > callChatMaxLength) return null;
    final claimed = p['sender_id'] is String ? p['sender_id']! as String : '';
    final sender = identity.isEmpty ? claimed : identity.split('#').first;
    if (sender.isEmpty) return null;
    return CallChatMessage(
      id: id,
      senderId: sender,
      senderName: p['sender_name'] is String ? p['sender_name']! as String : '',
      body: text,
      createdAt: parseApiDate(p['created_at'] as String?)?.toLocal() ?? DateTime.now(),
    );
  }

  /// `GET/POST /calls/{id}/messages` item.
  factory CallChatMessage.fromJson(Map<String, dynamic> j) => CallChatMessage(
    id: (j['client_message_id'] as String?) ?? (j['id'] as String?) ?? '',
    senderId: (j['sender_id'] as String?) ?? '',
    senderName: (j['sender_name'] as String?) ?? '',
    body: (j['body'] as String?) ?? '',
    createdAt: parseApiDate(j['created_at'] as String?)?.toLocal() ?? DateTime.now(),
  );
}

/// An item of `GET /calls/{id}/recordings` (docs/CALLS-API.md §10).
class CallRecordingItem {
  const CallRecordingItem({
    required this.id,
    required this.callId,
    required this.status,
    required this.type,
    this.startedBy = '',
    this.startedByName = '',
    this.startedAt,
    this.endedAt,
    this.durationSec = 0,
    this.sizeBytes = 0,
    this.contentType = '',
    this.filename = '',
    this.downloadPath = '',
    this.transcriptStatus = 'none',
  });

  /// none | queued | processing | complete | failed (docs/CALLS-API.md §14).
  final String transcriptStatus;

  final String id;
  final String callId;

  /// starting | active | complete | failed
  final String status;

  /// video (MP4) | audio (OGG)
  final String type;
  final String startedBy;
  final String startedByName;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int durationSec;
  final int sizeBytes;
  final String contentType;
  final String filename;

  /// Relative to the Call Service API base (`/recordings/{id}/download`).
  final String downloadPath;

  bool get ready => status == 'complete';
  bool get failed => status == 'failed';
  bool get isAudio => type == 'audio';

  factory CallRecordingItem.fromJson(Map<String, dynamic> j) {
    final id = (j['id'] as String?) ?? '';
    return CallRecordingItem(
      id: id,
      callId: (j['call_id'] as String?) ?? '',
      status: (j['status'] as String?) ?? '',
      type: (j['type'] as String?) ?? 'video',
      startedBy: (j['started_by'] as String?) ?? '',
      startedByName: (j['started_by_name'] as String?) ?? '',
      startedAt: parseApiDate(j['started_at'] as String?),
      endedAt: parseApiDate(j['ended_at'] as String?),
      durationSec: (j['duration_sec'] as num?)?.toInt() ?? 0,
      sizeBytes: (j['size_bytes'] as num?)?.toInt() ?? 0,
      contentType: (j['content_type'] as String?) ?? '',
      filename: (j['filename'] as String?) ?? '',
      downloadPath: (j['download_path'] as String?) ?? '/recordings/$id/download',
      transcriptStatus: (j['transcript_status'] as String?) ?? 'none',
    );
  }
}
