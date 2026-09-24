import '../../../shared/utils/api_date.dart';

/// System folder roles as accepted by `folder=` and returned in `type`.
abstract final class MailFolderType {
  static const inbox = 'inbox';
  static const sent = 'sent';
  static const drafts = 'drafts';
  static const spam = 'spam';
  static const trash = 'trash';
  static const bookmarks = 'bookmarks';
  static const customPrefix = 'custom:';
  static const bookmarkPrefix = 'bookmark:';

  static const system = [inbox, sent, drafts, spam, trash];

  static bool isSystem(String type) => system.contains(type);
  static bool isSmart(String type) => type.startsWith(customPrefix);
  static bool isBookmarkFolder(String type) => type.startsWith(bookmarkPrefix);

  /// `threads=1` is ignored for these; `q`/filters ignored for `bookmark:`.
  static bool supportsFilters(String type) => !isBookmarkFolder(type);

  /// `threads=1` is ignored for `drafts`, `bookmarks` and `bookmark:<id>`.
  static bool supportsThreads(String type) =>
      type != drafts && type != bookmarks && !isBookmarkFolder(type);
}

/// `MailSummaryFolder`.
class MailFolder {
  const MailFolder({
    required this.id,
    required this.name,
    required this.type,
    required this.unread,
    required this.total,
    this.color,
    this.accounts,
  });

  final String id;
  final String name;

  /// Value for the `folder` query parameter of `GET /mail/messages`.
  final String type;
  final String? color;
  final int? accounts;
  final int unread;
  final int total;

  bool get isSystem => MailFolderType.isSystem(type);
  bool get isSmart => MailFolderType.isSmart(type);
  bool get isBookmarkFolder => MailFolderType.isBookmarkFolder(type);

  factory MailFolder.fromJson(Map<String, dynamic> json) => MailFolder(
    id: (json['id'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    type: (json['type'] as String?) ?? '',
    color: json['color'] as String?,
    accounts: (json['accounts'] as num?)?.toInt(),
    unread: (json['unread'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    if (color != null) 'color': color,
    if (accounts != null) 'accounts': accounts,
    'unread': unread,
    'total': total,
  };
}

/// `MailSummary`.
class MailSummary {
  const MailSummary({required this.mailboxAddress, required this.folders});

  final String mailboxAddress;
  final List<MailFolder> folders;

  factory MailSummary.fromJson(Map<String, dynamic> json) {
    final mailbox =
        (json['mailbox'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MailSummary(
      mailboxAddress: (mailbox['address'] as String?) ?? '',
      folders: ((json['folders'] as List?) ?? const [])
          .map((e) => MailFolder.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'mailbox': {'address': mailboxAddress},
    'folders': folders.map((f) => f.toJson()).toList(),
  };

  MailFolder? folderByType(String type) {
    for (final f in folders) {
      if (f.type == type) return f;
    }
    return null;
  }

  /// Unread mail that lives in the Inbox: the summary subtracts smart-folder
  /// counts from `inbox.unread`, but those messages are still listed in the
  /// Inbox, so the tab badge adds them back.
  int get inboxUnreadTotal {
    var total = 0;
    for (final f in folders) {
      if (f.type == MailFolderType.inbox || f.isSmart) total += f.unread;
    }
    return total;
  }
}

class MailParticipant {
  const MailParticipant({required this.name, required this.email});
  final String name;
  final String email;

  factory MailParticipant.fromJson(Map<String, dynamic> json) =>
      MailParticipant(
        name: (json['name'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
      );
  Map<String, dynamic> toJson() => {'name': name, 'email': email};
}

/// `MailListItem`.
class MailListItem {
  const MailListItem({
    required this.id,
    required this.messageId,
    required this.from,
    required this.fromDisplay,
    required this.subject,
    required this.snippet,
    required this.rawDate,
    required this.date,
    required this.isRead,
    required this.isStarred,
    required this.hasAttachments,
    this.folderType,
    this.folderName,
    this.folderColor,
    this.threadId,
    this.threadCount,
    this.threadUnread,
    this.threadMessageIds,
    this.participants,
  });

  final String id;
  final String messageId;
  final String from;
  final String fromDisplay;
  final String? folderType;
  final String? folderName;
  final String? folderColor;
  final String subject;
  final String snippet;
  final String rawDate;
  final DateTime? date;
  final bool isRead;
  final bool isStarred;
  final bool hasAttachments;
  final String? threadId;
  final int? threadCount;
  final int? threadUnread;
  final List<String>? threadMessageIds;
  final List<MailParticipant>? participants;

  String get senderLabel => fromDisplay.isNotEmpty ? fromDisplay : from;

  factory MailListItem.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['date'] as String?) ?? '';
    return MailListItem(
      id: json['id'] as String,
      messageId: (json['message_id'] as String?) ?? '',
      from: (json['from'] as String?) ?? '',
      fromDisplay: (json['from_display'] as String?) ?? '',
      folderType: json['folder_type'] as String?,
      folderName: json['folder_name'] as String?,
      folderColor: json['folder_color'] as String?,
      subject: (json['subject'] as String?) ?? '',
      snippet: (json['snippet'] as String?) ?? '',
      rawDate: rawDate,
      date: parseApiDate(rawDate),
      isRead: json['is_read'] == true,
      isStarred: json['is_starred'] == true,
      hasAttachments: json['has_attachments'] == true,
      threadId: json['thread_id'] as String?,
      threadCount: (json['thread_count'] as num?)?.toInt(),
      threadUnread: (json['thread_unread'] as num?)?.toInt(),
      threadMessageIds: (json['thread_message_ids'] as List?)?.cast<String>(),
      participants: (json['participants'] as List?)
          ?.map(
            (e) => MailParticipant.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'message_id': messageId,
    'from': from,
    'from_display': fromDisplay,
    if (folderType != null) 'folder_type': folderType,
    if (folderName != null) 'folder_name': folderName,
    if (folderColor != null) 'folder_color': folderColor,
    'subject': subject,
    'snippet': snippet,
    'date': rawDate,
    'is_read': isRead,
    'is_starred': isStarred,
    'has_attachments': hasAttachments,
    if (threadId != null) 'thread_id': threadId,
    if (threadCount != null) 'thread_count': threadCount,
    if (threadUnread != null) 'thread_unread': threadUnread,
    if (threadMessageIds != null) 'thread_message_ids': threadMessageIds,
    if (participants != null)
      'participants': participants!.map((p) => p.toJson()).toList(),
  };

  MailListItem copyWith({bool? isRead, bool? isStarred}) => MailListItem(
    id: id,
    messageId: messageId,
    from: from,
    fromDisplay: fromDisplay,
    folderType: folderType,
    folderName: folderName,
    folderColor: folderColor,
    subject: subject,
    snippet: snippet,
    rawDate: rawDate,
    date: date,
    isRead: isRead ?? this.isRead,
    isStarred: isStarred ?? this.isStarred,
    hasAttachments: hasAttachments,
    threadId: threadId,
    threadCount: threadCount,
    threadUnread: threadUnread,
    threadMessageIds: threadMessageIds,
    participants: participants,
  );
}

/// `MailMessageList`.
class MailMessagePage {
  const MailMessagePage({
    required this.messages,
    required this.total,
    required this.limit,
    required this.offset,
    this.nextOffset,
  });

  final List<MailListItem> messages;
  final int total;
  final int limit;
  final int offset;

  /// Conversation mode only.
  final int? nextOffset;

  factory MailMessagePage.fromJson(Map<String, dynamic> json) =>
      MailMessagePage(
        messages: ((json['messages'] as List?) ?? const [])
            .map(
              (e) => MailListItem.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        limit: (json['limit'] as num?)?.toInt() ?? 0,
        offset: (json['offset'] as num?)?.toInt() ?? 0,
        nextOffset: (json['next_offset'] as num?)?.toInt(),
      );

  /// Offset of the next page, or null when there is nothing more to read.
  /// Implements the paging rules from the spec for both list modes.
  int? computeNextOffset() {
    if (nextOffset != null) {
      final next = nextOffset!;
      if (next >= total || next <= offset) return null;
      return next;
    }
    if (messages.isEmpty) return null;
    final next = offset + messages.length;
    return next >= total ? null : next;
  }
}

/// Query for `GET /mail/messages`. Only documented parameters are emitted.
class MailListQuery {
  const MailListQuery({
    this.folder = MailFolderType.inbox,
    this.q,
    this.unread = false,
    this.starred = false,
    this.attachments = false,
    this.threads = false,
    this.sender,
    this.limit = 50,
    this.offset = 0,
  });

  final String folder;
  final String? q;
  final bool unread;
  final bool starred;
  final bool attachments;
  final bool threads;
  final String? sender;
  final int limit;
  final int offset;

  bool get hasFilters =>
      (q != null && q!.trim().isNotEmpty) ||
      unread ||
      starred ||
      attachments ||
      sender != null;

  MailListQuery copyWith({
    String? folder,
    String? q,
    bool clearQ = false,
    bool? unread,
    bool? starred,
    bool? attachments,
    bool? threads,
    int? limit,
    int? offset,
  }) => MailListQuery(
    folder: folder ?? this.folder,
    q: clearQ ? null : (q ?? this.q),
    unread: unread ?? this.unread,
    starred: starred ?? this.starred,
    attachments: attachments ?? this.attachments,
    threads: threads ?? this.threads,
    sender: sender,
    limit: limit ?? this.limit,
    offset: offset ?? this.offset,
  );

  Map<String, dynamic> toQueryParameters() {
    final filtersAllowed = MailFolderType.supportsFilters(folder);
    final query = q?.trim();
    return {
      'folder': folder,
      if (filtersAllowed && query != null && query.isNotEmpty) 'q': query,
      if (filtersAllowed && unread) 'unread': '1',
      if (filtersAllowed && starred) 'starred': '1',
      if (filtersAllowed && attachments) 'attachments': '1',
      if (filtersAllowed && threads) 'threads': '1',
      if (sender != null && MailFolderType.isSmart(folder)) 'sender': sender,
      // Always explicit: `bookmark:<id>` returns nothing without a limit.
      'limit': limit.clamp(1, 100),
      'offset': offset < 0 ? 0 : offset,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is MailListQuery &&
      other.folder == folder &&
      other.q == q &&
      other.unread == unread &&
      other.starred == starred &&
      other.attachments == attachments &&
      other.threads == threads &&
      other.sender == sender &&
      other.limit == limit &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(
    folder,
    q,
    unread,
    starred,
    attachments,
    threads,
    sender,
    limit,
    offset,
  );
}

/// `MailAttachment` (blob of a stored message).
class MailAttachment {
  const MailAttachment({
    required this.id,
    required this.filename,
    required this.contentType,
    required this.sizeBytes,
    this.contentId = '',
    this.inline = false,
  });

  final String id;
  final String filename;
  final String contentType;
  final int sizeBytes;

  /// Content-ID of a picture the HTML body draws with `cid:` (no brackets).
  final String contentId;
  final bool inline;

  static const officeExtensions = {
    'doc',
    'docx',
    'odt',
    'rtf',
    'xls',
    'xlsx',
    'ods',
    'csv',
    'ppt',
    'pptx',
    'odp',
  };

  String get extension {
    final dot = filename.lastIndexOf('.');
    if (dot < 0 || dot == filename.length - 1) return '';
    return filename.substring(dot + 1).toLowerCase();
  }

  /// `GET /mail/blob/{id}/pdf` can render these as PDF for preview.
  bool get isOfficeDocument => officeExtensions.contains(extension);

  /// Same rule as `GET /mail/messages/{id}/calendar-invitation`.
  bool get isCalendarInvitation =>
      extension == 'ics' || contentType.toLowerCase().contains('text/calendar');

  factory MailAttachment.fromJson(Map<String, dynamic> json) => MailAttachment(
    id: json['id'] as String,
    filename: (json['filename'] as String?) ?? '',
    contentType: (json['content_type'] as String?) ?? '',
    sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
    contentId: (json['content_id'] as String?) ?? '',
    inline: json['inline'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'filename': filename,
    'content_type': contentType,
    'size_bytes': sizeBytes,
    if (contentId.isNotEmpty) 'content_id': contentId,
    if (inline) 'inline': true,
  };
}

enum RecipientKind { to, cc, bcc }

class MailRecipient {
  const MailRecipient({required this.kind, required this.address});
  final RecipientKind kind;
  final String address;

  factory MailRecipient.fromJson(Map<String, dynamic> json) => MailRecipient(
    kind: switch (json['kind']) {
      'cc' => RecipientKind.cc,
      'bcc' => RecipientKind.bcc,
      _ => RecipientKind.to,
    },
    address: (json['address'] as String?) ?? '',
  );
  Map<String, dynamic> toJson() => {'kind': kind.name, 'address': address};
}

/// `MailThreadItem`.
class MailThreadItem {
  const MailThreadItem({
    required this.id,
    required this.subject,
    required this.from,
    required this.date,
    this.fromName,
    this.preview,
    this.to,
  });

  final String id;
  final String subject;
  final String from;
  final String? fromName;
  final DateTime? date;
  final String? preview;
  final List<String>? to;

  String get senderLabel =>
      (fromName != null && fromName!.isNotEmpty) ? fromName! : from;

  factory MailThreadItem.fromJson(Map<String, dynamic> json) => MailThreadItem(
    id: json['id'] as String,
    subject: (json['subject'] as String?) ?? '',
    from: (json['from'] as String?) ?? '',
    fromName: json['from_name'] as String?,
    date: parseApiDate(json['date'] as String?),
    preview: json['preview'] as String?,
    to: (json['to'] as List?)?.cast<String>(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'from': from,
    if (fromName != null) 'from_name': fromName,
    'date': date?.toUtc().toIso8601String() ?? '',
    if (preview != null) 'preview': preview,
    if (to != null) 'to': to,
  };
}

/// `MailMessageDetail`.
class MailMessageDetail {
  const MailMessageDetail({
    required this.id,
    required this.messageId,
    required this.folder,
    required this.from,
    required this.fromDisplay,
    required this.recipients,
    required this.subject,
    required this.bodyText,
    required this.bodyHtml,
    required this.date,
    required this.isRead,
    required this.isStarred,
    required this.hasAttachments,
    required this.attachments,
    required this.thread,
  });

  final String id;
  final String messageId;
  final String folder;
  final String from;
  final String fromDisplay;
  final List<MailRecipient> recipients;
  final String subject;
  final String bodyText;
  final String bodyHtml;
  final DateTime? date;
  final bool isRead;
  final bool isStarred;
  final bool hasAttachments;
  final List<MailAttachment> attachments;
  final List<MailThreadItem> thread;

  String get senderLabel => fromDisplay.isNotEmpty ? fromDisplay : from;
  List<String> get to => recipients
      .where((r) => r.kind == RecipientKind.to)
      .map((r) => r.address)
      .toList();
  List<String> get cc => recipients
      .where((r) => r.kind == RecipientKind.cc)
      .map((r) => r.address)
      .toList();
  List<String> get bcc => recipients
      .where((r) => r.kind == RecipientKind.bcc)
      .map((r) => r.address)
      .toList();

  /// Drafts and Trash are destroyed permanently by `DELETE`.
  bool get deleteIsPermanent =>
      folder == MailFolderType.trash || folder == MailFolderType.drafts;

  factory MailMessageDetail.fromJson(
    Map<String, dynamic> json,
  ) => MailMessageDetail(
    id: json['id'] as String,
    messageId: (json['message_id'] as String?) ?? '',
    folder: (json['folder'] as String?) ?? '',
    from: (json['from'] as String?) ?? '',
    fromDisplay: (json['from_display'] as String?) ?? '',
    recipients: ((json['recipients'] as List?) ?? const [])
        .map((e) => MailRecipient.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    subject: (json['subject'] as String?) ?? '',
    bodyText: (json['body_text'] as String?) ?? '',
    bodyHtml: (json['body_html'] as String?) ?? '',
    date: parseApiDate(json['date'] as String?),
    isRead: json['is_read'] == true,
    isStarred: json['is_starred'] == true,
    hasAttachments: json['has_attachments'] == true,
    attachments: ((json['attachments'] as List?) ?? const [])
        .map((e) => MailAttachment.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    thread: ((json['thread'] as List?) ?? const [])
        .map((e) => MailThreadItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'message_id': messageId,
    'folder': folder,
    'from': from,
    'from_display': fromDisplay,
    'recipients': recipients.map((r) => r.toJson()).toList(),
    'subject': subject,
    'body_text': bodyText,
    'body_html': bodyHtml,
    'date': date?.toUtc().toIso8601String() ?? '',
    'is_read': isRead,
    'is_starred': isStarred,
    'has_attachments': hasAttachments,
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'thread': thread.map((t) => t.toJson()).toList(),
  };

  MailMessageDetail copyWith({bool? isRead, bool? isStarred, String? folder}) =>
      MailMessageDetail(
        id: id,
        messageId: messageId,
        folder: folder ?? this.folder,
        from: from,
        fromDisplay: fromDisplay,
        recipients: recipients,
        subject: subject,
        bodyText: bodyText,
        bodyHtml: bodyHtml,
        date: date,
        isRead: isRead ?? this.isRead,
        isStarred: isStarred ?? this.isStarred,
        hasAttachments: hasAttachments,
        attachments: attachments,
        thread: thread,
      );
}

/// `MailComposeAttachment` (staged upload, `att_…`).
class MailComposeAttachment {
  const MailComposeAttachment({
    required this.id,
    required this.filename,
    required this.contentType,
    required this.sizeBytes,
  });
  final String id;
  final String filename;
  final String contentType;
  final int sizeBytes;

  factory MailComposeAttachment.fromJson(Map<String, dynamic> json) =>
      MailComposeAttachment(
        id: json['id'] as String,
        filename: (json['filename'] as String?) ?? '',
        contentType: (json['content_type'] as String?) ?? '',
        sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      );
}

/// `MailComposeSendRequest`. Serialises only documented, non-empty fields.
class MailSendRequest {
  const MailSendRequest({
    required this.to,
    this.cc = const [],
    this.bcc = const [],
    this.subject = '',
    this.text = '',
    this.html,
    this.inReplyTo,
    this.attachmentIds = const [],
  });

  final List<String> to;
  final List<String> cc;
  final List<String> bcc;
  final String subject;
  final String text;
  final String? html;
  final String? inReplyTo;
  final List<String> attachmentIds;

  static const maxRecipients = 100;
  static const maxAttachments = 20;
  static const maxSubjectBytes = 500;

  Map<String, dynamic> toJson() => {
    'to': to,
    if (cc.isNotEmpty) 'cc': cc,
    if (bcc.isNotEmpty) 'bcc': bcc,
    'subject': subject,
    'text': text,
    if (html != null && html!.isNotEmpty) 'html': html,
    if (inReplyTo != null && inReplyTo!.isNotEmpty) 'in_reply_to': inReplyTo,
    if (attachmentIds.isNotEmpty) 'attachment_ids': attachmentIds,
  };

  /// Back from [toJson] (the desktop outbox keeps queued letters).
  factory MailSendRequest.fromJson(Map<String, dynamic> json) {
    List<String> list(String k) => ((json[k] as List?) ?? const []).cast<String>();
    return MailSendRequest(
      to: list('to'),
      cc: list('cc'),
      bcc: list('bcc'),
      subject: (json['subject'] as String?) ?? '',
      text: (json['text'] as String?) ?? '',
      html: json['html'] as String?,
      inReplyTo: json['in_reply_to'] as String?,
      attachmentIds: list('attachment_ids'),
    );
  }
}

/// `MailComposeDraftRequest`. `bcc` is accepted by the API but not stored;
/// attachments and reply target cannot be kept in a draft at all.
class MailDraftRequest {
  const MailDraftRequest({
    this.to = const [],
    this.cc = const [],
    this.bcc = const [],
    this.subject = '',
    this.text = '',
    this.html,
  });

  final List<String> to;
  final List<String> cc;
  final List<String> bcc;
  final String subject;
  final String text;
  final String? html;

  Map<String, dynamic> toJson() => {
    'to': to,
    'cc': cc,
    'bcc': bcc,
    'subject': subject,
    'text': text,
    if (html != null && html!.isNotEmpty) 'html': html,
  };
}

enum MailReportKind { spam, phishing, ham }

/// IMAP/SMTP endpoint of `GET /mail/client-config`.
class MailClientServer {
  const MailClientServer({required this.host, required this.port, required this.encryption});
  final String host;
  final String port;
  final String encryption;

  factory MailClientServer.fromJson(Map<String, dynamic>? json) => MailClientServer(
    host: (json?['host'] as String?) ?? '',
    port: (json?['port'] as String?) ?? '',
    encryption: (json?['encryption'] as String?) ?? '',
  );
}

class MailClientConfig {
  const MailClientConfig({
    required this.enabled,
    required this.attachmentLimitBytes,
    this.imap,
    this.smtp,
    this.loginHint = '',
  });
  final bool enabled;
  final int attachmentLimitBytes;
  final MailClientServer? imap;
  final MailClientServer? smtp;
  final String loginHint;

  /// Spec default when the config cannot be fetched.
  static const defaultAttachmentLimitBytes = 60 * 1024 * 1024;

  factory MailClientConfig.fromJson(Map<String, dynamic> json) =>
      MailClientConfig(
        enabled: json['enabled'] == true,
        attachmentLimitBytes:
            (json['attachment_limit_bytes'] as num?)?.toInt() ??
            defaultAttachmentLimitBytes,
        imap: json['imap'] is Map ? MailClientServer.fromJson((json['imap'] as Map).cast<String, dynamic>()) : null,
        smtp: json['smtp'] is Map ? MailClientServer.fromJson((json['smtp'] as Map).cast<String, dynamic>()) : null,
        loginHint: (json['login_hint'] as String?) ?? '',
      );
}

/// One sender of a smart folder (`GET /mail/folders/{id}/accounts`).
class MailSmartFolderAccount {
  const MailSmartFolderAccount({
    required this.address,
    required this.displayName,
    required this.total,
    required this.unread,
    required this.lastSubject,
    required this.lastDate,
    required this.includesExisting,
  });

  final String address;
  final String displayName;
  final int total;
  final int unread;
  final String lastSubject;
  final DateTime? lastDate;
  final bool includesExisting;

  String get label => displayName.isNotEmpty ? displayName : address;

  factory MailSmartFolderAccount.fromJson(Map<String, dynamic> json) => MailSmartFolderAccount(
    address: (json['address'] as String?) ?? '',
    displayName: (json['display_name'] as String?) ?? '',
    total: (json['total'] as num?)?.toInt() ?? 0,
    unread: (json['unread'] as num?)?.toInt() ?? 0,
    lastSubject: (json['last_subject'] as String?) ?? '',
    lastDate: parseApiDate(json['last_date'] as String?),
    includesExisting: json['includes_existing'] == true,
  );
}
