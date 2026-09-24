import '../../../shared/utils/api_date.dart';

/// `MailSettingsSyncState` — whether the mail server already follows the
/// latest change to the block list / out-of-office reply.
class MailSyncState {
  const MailSyncState({required this.state, this.syncedAt});

  /// `synced`, `pending` or `failed`.
  final String state;
  final DateTime? syncedAt;

  bool get isPending => state == 'pending';
  bool get isFailed => state == 'failed';

  factory MailSyncState.fromJson(Map<String, dynamic>? json) => MailSyncState(
    state: (json?['state'] as String?) ?? 'synced',
    syncedAt: parseApiDate(json?['synced_at'] as String?),
  );
}

/// `MailSettingsPersonalSignature`.
class MailPersonalSignature {
  const MailPersonalSignature({
    required this.text,
    required this.html,
    required this.isDefault,
    required this.defaultText,
  });

  final String text;
  final String html;
  final bool isDefault;
  final String defaultText;

  /// `PUT /mail/signature` limit, in UTF-8 bytes after trimming.
  static const maxBytes = 2000;

  factory MailPersonalSignature.fromJson(Map<String, dynamic> json) =>
      MailPersonalSignature(
        text: (json['text'] as String?) ?? '',
        html: (json['html'] as String?) ?? '',
        isDefault: json['is_default'] == true,
        defaultText: (json['default_text'] as String?) ?? '',
      );
}

/// `MailSettingsSignaturePreview` — what the server appends on send.
class MailSignaturePreview {
  const MailSignaturePreview({
    required this.personal,
    required this.mandatory,
    required this.applied,
    this.personalText = '',
    this.personalHtml = '',
    this.name = '',
    this.text = '',
    this.html = '',
    this.reason,
    this.missing = const [],
  });

  final bool personal;
  final bool mandatory;
  final bool applied;
  final String personalText;
  final String personalHtml;
  final String name;
  final String text;
  final String html;
  final String? reason;
  final List<String> missing;

  /// Plain-text parts in the order the server appends them: personal first,
  /// then the organization signature when it is mandatory.
  List<String> get appendedParts => [
    if (personal && personalText.trim().isNotEmpty) personalText.trim(),
    if (mandatory && text.trim().isNotEmpty) text.trim(),
  ];

  factory MailSignaturePreview.fromJson(Map<String, dynamic> json) =>
      MailSignaturePreview(
        personal: json['personal'] == true,
        mandatory: json['mandatory'] == true,
        applied: json['applied'] == true,
        personalText: (json['personal_text'] as String?) ?? '',
        personalHtml: (json['personal_html'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        text: (json['text'] as String?) ?? '',
        html: (json['html'] as String?) ?? '',
        reason: json['reason'] as String?,
        missing: ((json['missing'] as List?) ?? const []).cast<String>(),
      );
}

/// `MailSettingsVacation`.
class MailVacation {
  const MailVacation({
    required this.enabled,
    required this.subject,
    required this.body,
    required this.startsOn,
    required this.endsOn,
    required this.timeZone,
    required this.activeNow,
    required this.pending,
    required this.sync,
  });

  final bool enabled;
  final String subject;
  final String body;

  /// `YYYY-MM-DD` or empty.
  final String startsOn;
  final String endsOn;
  final String timeZone;
  final bool activeNow;
  final bool pending;
  final MailSyncState sync;

  static const defaultTimeZone = 'Asia/Almaty';

  factory MailVacation.fromJson(Map<String, dynamic> json) => MailVacation(
    enabled: json['enabled'] == true,
    subject: (json['subject'] as String?) ?? '',
    body: (json['body'] as String?) ?? '',
    startsOn: (json['starts_on'] as String?) ?? '',
    endsOn: (json['ends_on'] as String?) ?? '',
    timeZone: (json['time_zone'] as String?)?.isNotEmpty == true
        ? json['time_zone'] as String
        : defaultTimeZone,
    activeNow: json['active_now'] == true,
    pending: json['pending'] == true,
    sync: MailSyncState.fromJson(
      (json['sync'] as Map?)?.cast<String, dynamic>(),
    ),
  );
}

/// `MailSettingsVacationUpdate` — full replacement, so every field is sent.
class MailVacationUpdate {
  const MailVacationUpdate({
    required this.enabled,
    this.subject = '',
    this.body = '',
    this.startsOn = '',
    this.endsOn = '',
    this.timeZone = MailVacation.defaultTimeZone,
  });

  final bool enabled;
  final String subject;
  final String body;
  final String startsOn;
  final String endsOn;
  final String timeZone;

  static const maxSubjectChars = 200;
  static const maxBodyChars = 4000;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'subject': subject.trim(),
    'body': body.replaceAll('\r\n', '\n').trim(),
    'starts_on': startsOn,
    'ends_on': endsOn,
    'time_zone': timeZone.trim(),
  };
}

/// `MailSettingsSenderRule` (block list entry).
class MailSenderRule {
  const MailSenderRule({
    required this.id,
    required this.kind,
    required this.pattern,
    required this.note,
    this.createdAt,
  });

  final String id;

  /// `domain`, `ip` or `network`.
  final String kind;
  final String pattern;
  final String note;
  final DateTime? createdAt;

  static const maxNoteChars = 200;

  factory MailSenderRule.fromJson(Map<String, dynamic> json) => MailSenderRule(
    id: (json['id'] as String?) ?? '',
    kind: (json['kind'] as String?) ?? 'domain',
    pattern: (json['pattern'] as String?) ?? '',
    note: (json['note'] as String?) ?? '',
    createdAt: parseApiDate(json['created_at'] as String?),
  );
}

/// `MailSettingsSenderRuleList`.
class MailSenderRuleList {
  const MailSenderRuleList({
    required this.rules,
    required this.limit,
    required this.sync,
  });

  final List<MailSenderRule> rules;
  final int limit;
  final MailSyncState sync;

  factory MailSenderRuleList.fromJson(Map<String, dynamic> json) =>
      MailSenderRuleList(
        rules: ((json['rules'] as List?) ?? const [])
            .map(
              (e) => MailSenderRule.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList(),
        limit: (json['limit'] as num?)?.toInt() ?? 500,
        sync: MailSyncState.fromJson(
          (json['sync'] as Map?)?.cast<String, dynamic>(),
        ),
      );
}

/// `MailBookmarkFolder`.
class MailBookmarkFolder {
  const MailBookmarkFolder({
    required this.id,
    required this.name,
    required this.color,
  });

  final String id;
  final String name;
  final String color;

  static const maxNameChars = 80;

  /// Value for `GET /mail/messages?folder=`.
  String get folderType => 'bookmark:$id';

  factory MailBookmarkFolder.fromJson(Map<String, dynamic> json) =>
      MailBookmarkFolder(
        id: (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        color: (json['color'] as String?) ?? '',
      );
}

/// One folder's outcome inside an archive import (`folders` in `ArchiveView`).
class MailImportFolder {
  const MailImportFolder({
    required this.imported,
    required this.skipped,
    required this.failed,
  });

  final int imported;
  final int skipped;
  final int failed;

  factory MailImportFolder.fromJson(Map<String, dynamic> json) =>
      MailImportFolder(
        imported: (json['imported'] as num?)?.toInt() ?? 0,
        skipped: (json['skipped'] as num?)?.toInt() ?? 0,
        failed: (json['failed'] as num?)?.toInt() ?? 0,
      );
}

/// `ArchiveView` — one archive this person uploaded into their own mailbox.
///
/// The counters are the whole progress report: the importer only adds, so a
/// message the mailbox already holds is `skipped` rather than written twice,
/// and an entry that is not mail at all (a contact, a calendar) is counted
/// in [itemsNotMail].
class MailArchiveImport {
  const MailArchiveImport({
    required this.id,
    required this.filename,
    required this.sizeBytes,
    required this.status,
    required this.messagesTotal,
    required this.messagesImported,
    required this.messagesSkipped,
    required this.messagesFailed,
    required this.itemsNotMail,
    required this.bytesImported,
    required this.currentFolder,
    required this.folders,
    required this.error,
    required this.fileAvailable,
    this.createdAt,
    this.finishedAt,
  });

  final String id;
  final String filename;
  final int sizeBytes;

  /// `queued`, `running`, `done` or `failed`.
  final String status;
  final int messagesTotal;
  final int messagesImported;
  final int messagesSkipped;
  final int messagesFailed;
  final int itemsNotMail;
  final int bytesImported;

  /// The folder being read right now, while [status] is `running`.
  final String currentFolder;
  final Map<String, MailImportFolder> folders;
  final String error;

  /// Whether the uploaded archive is still on the server, i.e. whether a
  /// failed import can be retried without uploading it again.
  final bool fileAvailable;
  final DateTime? createdAt;
  final DateTime? finishedAt;

  /// Still on the server's queue, so the list keeps polling.
  bool get isActive => status == 'queued' || status == 'running';
  bool get isFailed => status == 'failed';

  /// How far the import has read, 0..1; 0 while the total is still unknown.
  double get progress {
    if (messagesTotal <= 0) return 0;
    final done = messagesImported + messagesSkipped + messagesFailed;
    return (done / messagesTotal).clamp(0, 1).toDouble();
  }

  /// An export is named for its account (`user@domain.tgz`), and that name is
  /// the check: a file named for somebody else would put their mail in this
  /// mailbox. Refused here before the upload starts, and again by the server.
  static bool namedFor(String filename, String mailbox) {
    final base = filename
        .replaceAll(RegExp(r'\.(tgz|tar\.gz)$', caseSensitive: false), '')
        .trim()
        .toLowerCase();
    return base == mailbox.trim().toLowerCase();
  }

  factory MailArchiveImport.fromJson(Map<String, dynamic> json) =>
      MailArchiveImport(
        id: (json['id'] as String?) ?? '',
        filename: (json['filename'] as String?) ?? '',
        sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
        status: (json['status'] as String?) ?? 'queued',
        messagesTotal: (json['messages_total'] as num?)?.toInt() ?? 0,
        messagesImported: (json['messages_imported'] as num?)?.toInt() ?? 0,
        messagesSkipped: (json['messages_skipped'] as num?)?.toInt() ?? 0,
        messagesFailed: (json['messages_failed'] as num?)?.toInt() ?? 0,
        itemsNotMail: (json['items_not_mail'] as num?)?.toInt() ?? 0,
        bytesImported: (json['bytes_imported'] as num?)?.toInt() ?? 0,
        currentFolder: (json['current_folder'] as String?) ?? '',
        folders: ((json['folders'] as Map?) ?? const {}).map(
          (key, value) => MapEntry(
            key as String,
            MailImportFolder.fromJson((value as Map).cast<String, dynamic>()),
          ),
        ),
        error: (json['error'] as String?) ?? '',
        fileAvailable: (json['file_available'] as bool?) ?? false,
        createdAt: parseApiDate(json['created_at'] as String?),
        finishedAt: parseApiDate(json['finished_at'] as String?),
      );
}

/// `GET /mail/imports` — this person's own uploads, newest first, and the
/// mailbox they go into (the address the archive must be named for).
class MailImportList {
  const MailImportList({required this.imports, required this.mailbox});

  final List<MailArchiveImport> imports;
  final String mailbox;

  bool get hasActive => imports.any((i) => i.isActive);

  factory MailImportList.fromJson(Map<String, dynamic> json) => MailImportList(
    imports: ((json['imports'] as List?) ?? const [])
        .map(
          (e) => MailArchiveImport.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList(),
    mailbox: (json['mailbox'] as String?) ?? '',
  );
}
