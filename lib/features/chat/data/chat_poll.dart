import '../../../shared/utils/api_date.dart';

/// Poll of a `type: poll` message (chat-service migration 0010).
class ChatPollOption {
  const ChatPollOption({required this.text, this.votes = 0});
  final String text;
  final int votes;

  factory ChatPollOption.fromJson(Map<String, dynamic> j) => ChatPollOption(
    text: (j['text'] as String?) ?? '',
    votes: (j['votes'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {'text': text, 'votes': votes};
}

class ChatPoll {
  const ChatPoll({
    required this.question,
    required this.options,
    this.anonymous = true,
    this.multiple = false,
    this.quiz = false,
    this.correctOption,
    this.closeAt,
    this.closed = false,
    this.closedAt,
    this.totalVoters = 0,
    this.myVotes,
    this.createdBy = '',
  });

  final String question;
  final List<ChatPollOption> options;
  final bool anonymous;
  final bool multiple;
  final bool quiz;

  /// Quiz answer; the server reveals it to the creator, to voters and once
  /// the poll is closed.
  final int? correctOption;
  final DateTime? closeAt;
  final bool closed;
  final DateTime? closedAt;

  /// People who voted (a multiple-choice voter counts once).
  final int totalVoters;

  /// The viewer's option indexes; null when unknown (broadcast updates).
  final List<int>? myVotes;
  final String createdBy;

  bool get voted => myVotes?.isNotEmpty ?? false;

  bool isClosedAt(DateTime now) =>
      closed || (closeAt != null && !closeAt!.isAfter(now));

  /// Share of voters who chose option [index], 0–100.
  int percentOf(int index) {
    if (totalVoters <= 0 || index < 0 || index >= options.length) return 0;
    return (options[index].votes * 100 / totalVoters).round();
  }

  /// Folds a `poll.updated` payload in: the copy sent to other members has no
  /// `my_votes` (and no quiz answer before closing), so the viewer's own
  /// values are kept.
  ChatPoll mergeUpdate(ChatPoll update) => ChatPoll(
    question: update.question,
    options: update.options,
    anonymous: update.anonymous,
    multiple: update.multiple,
    quiz: update.quiz,
    correctOption: update.correctOption ?? correctOption,
    closeAt: update.closeAt,
    closed: update.closed,
    closedAt: update.closedAt,
    totalVoters: update.totalVoters,
    myVotes: update.myVotes ?? myVotes,
    createdBy: update.createdBy.isEmpty ? createdBy : update.createdBy,
  );

  factory ChatPoll.fromJson(Map<String, dynamic> j) => ChatPoll(
    question: (j['question'] as String?) ?? '',
    options: ((j['options'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ChatPollOption.fromJson(e.cast<String, dynamic>()))
        .toList(),
    anonymous: j['anonymous'] != false,
    multiple: j['multiple'] == true,
    quiz: j['quiz'] == true,
    correctOption: (j['correct_option'] as num?)?.toInt(),
    closeAt: parseApiDate(j['close_at'] as String?),
    closed: j['closed'] == true,
    closedAt: parseApiDate(j['closed_at'] as String?),
    totalVoters: (j['total_voters'] as num?)?.toInt() ?? 0,
    myVotes: j['my_votes'] is List
        ? (j['my_votes'] as List).whereType<num>().map((e) => e.toInt()).toList()
        : null,
    createdBy: (j['created_by'] as String?) ?? '',
  );

  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options.map((o) => o.toJson()).toList(),
    'anonymous': anonymous,
    'multiple': multiple,
    'quiz': quiz,
    'correct_option': ?correctOption,
    'close_at': ?closeAt?.toUtc().toIso8601String(),
    'closed': closed,
    'closed_at': ?closedAt?.toUtc().toIso8601String(),
    'total_voters': totalVoters,
    'my_votes': ?myVotes,
    'created_by': createdBy,
  };
}
