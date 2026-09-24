import '../../../shared/utils/api_date.dart';

/// Заявка of a `type: request` / `request_update` message (chat-service
/// migration 0016). Only the desktop app shows the «Заявки» chat for now.
class ChatRequest {
  const ChatRequest({
    required this.id,
    required this.number,
    required this.what,
    required this.room,
    required this.date,
    this.status = 'new',
    this.comment = '',
    this.updatedAt,
  });

  final String id;

  /// Short number people say aloud («заявка №42»).
  final int number;

  /// Что случилось.
  final String what;

  /// Кабинет.
  final String room;

  /// Дата из формы, YYYY-MM-DD.
  final String date;

  /// new | in_progress | done | rejected
  final String status;

  /// The service's latest comment ('' = none).
  final String comment;
  final DateTime? updatedAt;

  static const statuses = ['new', 'in_progress', 'done', 'rejected'];

  bool get isClosed => status == 'done' || status == 'rejected';

  /// [date] as dd.MM.yyyy ([date] itself if it does not parse).
  String get dateLabel {
    final d = DateTime.tryParse(date);
    if (d == null) return date;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  factory ChatRequest.fromJson(Map<String, dynamic> j) => ChatRequest(
    id: (j['id'] as String?) ?? '',
    number: (j['number'] as num?)?.toInt() ?? 0,
    what: (j['what'] as String?) ?? '',
    room: (j['room'] as String?) ?? '',
    date: (j['date'] as String?) ?? '',
    status: (j['status'] as String?) ?? 'new',
    comment: (j['comment'] as String?) ?? '',
    updatedAt: parseApiDate(j['updated_at'] as String?),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'what': what,
    'room': room,
    'date': date,
    'status': status,
    'comment': comment,
    'updated_at': ?updatedAt?.toUtc().toIso8601String(),
  };
}
