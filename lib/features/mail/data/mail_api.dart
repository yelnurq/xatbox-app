import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import 'mail_message_extras.dart';
import 'mail_models.dart';
import 'mail_settings_models.dart';

/// Thin, spec-faithful wrapper over the Mail / Folders / Attachments / Compose
/// endpoints. No business logic; see [MailRepository] for caching.
class MailApi {
  MailApi(this._client);
  final ApiClient _client;

  /// `GET /mail/summary` — mailbox + every sidebar folder with counters.
  Future<MailSummary> summary() async =>
      MailSummary.fromJson(await _client.getJson('/mail/summary'));

  /// `GET /mail/folders` — smart (sender-sorted) folders only.
  Future<List<Map<String, dynamic>>> smartFolders() async {
    final json = await _client.getJson('/mail/folders');
    return ((json['folders'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  /// `GET /mail/bookmark-folders`.
  Future<List<Map<String, dynamic>>> bookmarkFolders() async {
    final json = await _client.getJson('/mail/bookmark-folders');
    return ((json['folders'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  /// `GET /mail/messages`.
  Future<MailMessagePage> listMessages(
    MailListQuery query, {
    CancelToken? cancelToken,
  }) async {
    final json = await _client.getJson(
      '/mail/messages',
      query: query.toQueryParameters(),
      cancelToken: cancelToken,
    );
    return MailMessagePage.fromJson(json);
  }

  /// `GET /mail/messages/{id}`. Side effect on the server: marks the message read.
  Future<MailMessageDetail> getMessage(
    String id, {
    CancelToken? cancelToken,
  }) async {
    final json = await _client.getJson(
      '/mail/messages/${Uri.encodeComponent(id)}',
      cancelToken: cancelToken,
    );
    return MailMessageDetail.fromJson(json);
  }

  /// `PATCH /mail/messages/{id}`. Only the given fields are sent.
  Future<void> patchMessage(
    String id, {
    bool? isRead,
    bool? isStarred,
    String? folder,
  }) async {
    final body = <String, dynamic>{
      'is_read': ?isRead,
      'is_starred': ?isStarred,
      'folder': ?folder,
    };
    await _client.patchJson(
      '/mail/messages/${Uri.encodeComponent(id)}',
      body: body,
    );
  }

  /// `DELETE /mail/messages/{id}` — Trash, or destroy when already in
  /// Trash/Drafts.
  Future<void> deleteMessage(String id) async {
    await _client.deleteJson(
      '/mail/messages/${Uri.encodeComponent(id)}',
      expectedStatuses: const {200},
    );
  }

  /// `POST /mail/messages/{id}/report`. Returns the folder the message moved to.
  Future<String> reportMessage(String id, MailReportKind kind) async {
    final json = await _client.postJson(
      '/mail/messages/${Uri.encodeComponent(id)}/report',
      body: {'kind': kind.name},
      expectedStatuses: const {200},
    );
    return (json['folder'] as String?) ?? '';
  }

  /// `POST /mail/send` → public `msg_…` id (202).
  Future<String> send(MailSendRequest request) async {
    final json = await _client.postJson(
      '/mail/send',
      body: request.toJson(),
      expectedStatuses: const {202},
    );
    final id = json['message_id'];
    if (id is! String) {
      throw const UnexpectedApiException('send: no message_id');
    }
    return id;
  }

  /// `POST /mail/drafts` → store id (201).
  Future<String> createDraft(MailDraftRequest request) async {
    final json = await _client.postJson(
      '/mail/drafts',
      body: request.toJson(),
      expectedStatuses: const {201},
    );
    final id = json['id'];
    if (id is! String) throw const UnexpectedApiException('createDraft: no id');
    return id;
  }

  /// `PUT /mail/drafts/{id}` → NEW draft id (the old one is destroyed).
  Future<String> updateDraft(String id, MailDraftRequest request) async {
    final json = await _client.putJson(
      '/mail/drafts/${Uri.encodeComponent(id)}',
      body: request.toJson(),
    );
    final newId = json['id'];
    if (newId is! String) {
      throw const UnexpectedApiException('updateDraft: no id');
    }
    return newId;
  }

  /// `POST /mail/attachments` — multipart with the file in field `file`.
  Future<MailComposeAttachment> uploadAttachment({
    required String filename,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData();
    form.files.add(
      MapEntry('file', MultipartFile.fromBytes(bytes, filename: filename)),
    );
    final res = await _client.send(
      () => _client.dio.post<dynamic>(
        '/mail/attachments',
        data: form,
        onSendProgress: onProgress,
      ),
      expectedStatuses: const {201},
    );
    return MailComposeAttachment.fromJson(
      ApiClient.asJsonObject(res.data, '/mail/attachments'),
    );
  }

  /// `GET /mail/blob/{blobID}` — streams an attachment of a stored message to
  /// [savePath]. Name/type are passed so the server sets proper headers.
  Future<void> downloadBlob(
    MailAttachment attachment, {
    required String savePath,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await _client.send(
      () => _client.dio.download(
        '/mail/blob/${Uri.encodeComponent(attachment.id)}',
        savePath,
        queryParameters: {
          if (attachment.filename.isNotEmpty) 'name': attachment.filename,
          if (attachment.contentType.isNotEmpty) 'type': attachment.contentType,
        },
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
        options: Options(headers: {'Accept': '*/*'}),
      ),
    );
  }

  /// `GET /mail/blob/{blobID}/pdf` — server-side office → PDF rendering.
  /// `Accept: application/json` guarantees JSON errors instead of HTML.
  Future<void> downloadBlobAsPdf(
    MailAttachment attachment, {
    required String savePath,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await _client.send(
      () => _client.dio.download(
        '/mail/blob/${Uri.encodeComponent(attachment.id)}/pdf',
        savePath,
        queryParameters: {
          'name': attachment.filename,
          if (attachment.contentType.isNotEmpty) 'type': attachment.contentType,
        },
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
        options: Options(
          headers: {'Accept': 'application/pdf, application/json'},
        ),
      ),
    );
  }

  /// Fetches blob bytes in memory (used to re-attach when forwarding).
  Future<Uint8List> fetchBlobBytes(MailAttachment attachment) async {
    final res = await _client.send(
      () => _client.dio.get<List<int>>(
        '/mail/blob/${Uri.encodeComponent(attachment.id)}',
        queryParameters: {
          if (attachment.filename.isNotEmpty) 'name': attachment.filename,
          if (attachment.contentType.isNotEmpty) 'type': attachment.contentType,
        },
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': '*/*'},
        ),
      ),
    );
    return Uint8List.fromList(res.data ?? const []);
  }

  /// `GET /mail/client-config` — attachment size limit.
  Future<MailClientConfig> clientConfig() async =>
      MailClientConfig.fromJson(await _client.getJson('/mail/client-config'));

  // ---- message extras -------------------------------------------------------

  /// `GET /mail/messages/{id}/events` — delivery timeline (possibly empty).
  Future<MailDeliveryReport> messageEvents(String id) async =>
      MailDeliveryReport.fromJson(
        await _client.getJson('/mail/messages/${Uri.encodeComponent(id)}/events'),
      );

  /// `GET /mail/messages/{id}/calendar-invitation?blob_id=`.
  Future<MailInvitationPreview> calendarInvitation(
    String id, {
    String? blobId,
  }) async => MailInvitationPreview.fromJson(
    await _client.getJson(
      '/mail/messages/${Uri.encodeComponent(id)}/calendar-invitation',
      query: {if (blobId != null && blobId.isNotEmpty) 'blob_id': blobId},
    ),
  );

  /// `POST /mail/messages/{id}/calendar-invitation/respond?blob_id=`.
  /// The server reads the attachment from the query; the body `blob_id` is
  /// ignored but sent as well, like the web client does.
  Future<MailInvitationResponse> respondToInvitation(
    String id, {
    required String blobId,
    required MailRsvp status,
  }) async => MailInvitationResponse.fromJson(
    await _client.postJson(
      '/mail/messages/${Uri.encodeComponent(id)}/calendar-invitation/respond',
      query: {'blob_id': blobId},
      body: {'blob_id': blobId, 'status': status.name},
      expectedStatuses: const {200},
    ),
  );

  // ---- mail settings --------------------------------------------------------

  /// `GET /mail/signature-preview`.
  Future<MailSignaturePreview> signaturePreview() async =>
      MailSignaturePreview.fromJson(
        await _client.getJson('/mail/signature-preview'),
      );

  /// `GET /mail/signature`.
  Future<MailPersonalSignature> signature() async =>
      MailPersonalSignature.fromJson(await _client.getJson('/mail/signature'));

  /// `PUT /mail/signature` — empty text restores the generated default.
  Future<MailPersonalSignature> updateSignature(String text) async =>
      MailPersonalSignature.fromJson(
        await _client.putJson('/mail/signature', body: {'text': text}),
      );

  /// `GET /mail/vacation`.
  Future<MailVacation> vacation() async =>
      MailVacation.fromJson(await _client.getJson('/mail/vacation'));

  /// `PUT /mail/vacation` — full replacement.
  Future<MailVacation> updateVacation(MailVacationUpdate update) async =>
      MailVacation.fromJson(
        await _client.putJson('/mail/vacation', body: update.toJson()),
      );

  /// `GET /mail/sender-rules`.
  Future<MailSenderRuleList> senderRules() async =>
      MailSenderRuleList.fromJson(await _client.getJson('/mail/sender-rules'));

  /// `POST /mail/sender-rules` (201). `list` is omitted (= `block`).
  Future<MailSenderRule> addSenderRule({
    required String value,
    String note = '',
  }) async {
    final json = await _client.postJson(
      '/mail/sender-rules',
      body: {
        'value': value.trim(),
        if (note.trim().isNotEmpty) 'note': note.trim(),
      },
      expectedStatuses: const {201},
    );
    return MailSenderRule.fromJson(json);
  }

  /// `DELETE /mail/sender-rules/{ruleID}` (204, empty body).
  Future<void> deleteSenderRule(String id) async {
    await _client.deleteJson(
      '/mail/sender-rules/${Uri.encodeComponent(id)}',
      expectedStatuses: const {204},
    );
  }

  // ---- importing one's own mail --------------------------------------------

  /// `GET /mail/imports` — the archives this person uploaded into their own
  /// mailbox, newest first, plus the mailbox address they land in.
  Future<MailImportList> mailImports() async =>
      MailImportList.fromJson(await _client.getJson('/mail/imports'));

  /// `POST /mail/import` (201) — a multipart form with the archive in `file`.
  ///
  /// The file is streamed from disk: an export of a working mailbox runs to
  /// gigabytes and must never be read into memory. The client's own timeouts
  /// are lifted for the same reason — the upload is bounded by the server's
  /// size limit, not by a minute.
  Future<MailArchiveImport> uploadMailImport({
    required String path,
    required String filename,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final form = FormData();
    form.files.add(
      MapEntry('file', await MultipartFile.fromFile(path, filename: filename)),
    );
    final res = await _client.send(
      () => _client.dio.post<dynamic>(
        '/mail/import',
        data: form,
        onSendProgress: onProgress,
        cancelToken: cancelToken,
        options: Options(
          sendTimeout: const Duration(hours: 6),
          receiveTimeout: const Duration(minutes: 5),
        ),
      ),
      expectedStatuses: const {201},
    );
    return MailArchiveImport.fromJson(
      ApiClient.asJsonObject(res.data, '/mail/import'),
    );
  }

  /// `POST /mail/imports/{importID}/retry` (204) — a failed import goes back
  /// on the queue and resumes where it stopped.
  Future<void> retryMailImport(String id) async {
    await _client.postJson(
      '/mail/imports/${Uri.encodeComponent(id)}/retry',
      body: const <String, dynamic>{},
      expectedStatuses: const {204},
    );
  }

  /// `DELETE /mail/imports/{importID}` (204) — the record and the uploaded
  /// file go; mail already imported stays in the folders.
  Future<void> deleteMailImport(String id) async {
    await _client.deleteJson(
      '/mail/imports/${Uri.encodeComponent(id)}',
      expectedStatuses: const {204},
    );
  }

  /// `GET /mail/bookmark-folders`, typed.
  Future<List<MailBookmarkFolder>> listBookmarkFolders() async {
    final json = await _client.getJson('/mail/bookmark-folders');
    return ((json['folders'] as List?) ?? const [])
        .map(
          (e) => MailBookmarkFolder.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  /// `GET /mail/folders/{folderID}/accounts` — the per-sender overview a
  /// smart folder opens with on the web.
  Future<List<MailSmartFolderAccount>> smartFolderAccounts(String folderId) async {
    final json = await _client.getJson('/mail/folders/${Uri.encodeComponent(folderId)}/accounts');
    return ((json['accounts'] as List?) ?? const [])
        .map((e) => MailSmartFolderAccount.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// `POST /mail/folders/{folderID}/senders`: "Sort sender" — put a sender
  /// into a smart folder, optionally with the mail already received.
  Future<void> addSenderToSmartFolder(String folderId, String sender, {bool includeExisting = true}) async {
    await _client.postJson(
      '/mail/folders/${Uri.encodeComponent(folderId)}/senders',
      body: {'sender': sender, 'include_existing': includeExisting},
      expectedStatuses: const {200, 201},
    );
  }

  /// `POST /mail/folders` (201): an empty smart folder; the server picks the
  /// colour. `INVALID_FOLDER_NAME` (400), `FOLDER_EXISTS` (409).
  Future<MailFolder> createSmartFolder(String name) async {
    final json = await _client.postJson(
      '/mail/folders',
      body: {'name': name.trim()},
      expectedStatuses: const {201},
    );
    final folder = MailFolder.fromJson(json);
    return folder.type.isEmpty
        ? MailFolder(
            id: folder.id,
            name: folder.name,
            type: '${MailFolderType.customPrefix}${folder.id}',
            color: folder.color,
            unread: folder.unread,
            total: folder.total,
          )
        : folder;
  }

  /// `POST /mail/bookmark-folders` (201).
  Future<MailBookmarkFolder> createBookmarkFolder(String name) async =>
      MailBookmarkFolder.fromJson(
        await _client.postJson(
          '/mail/bookmark-folders',
          body: {'name': name.trim()},
          expectedStatuses: const {201},
        ),
      );

  /// `POST /mail/bookmark-folders/{folderID}/messages` (200): "Save" in the
  /// reading pane — the message joins the collection (and is starred).
  Future<void> addMessageToBookmarkFolder(String folderId, String messageId) async {
    await _client.postJson(
      '/mail/bookmark-folders/${Uri.encodeComponent(folderId)}/messages',
      body: {'message_id': messageId},
      expectedStatuses: const {200},
    );
  }

  /// `POST /tasks` (201): "Remind me" / "Add to tasks" on a message. The
  /// server fires an in-app `reminder` notification at [reminderAt].
  Future<void> createTask({
    required String title,
    String description = '',
    String? sourceType,
    String? sourceId,
    DateTime? reminderAt,
    DateTime? dueAt,
  }) async {
    await _client.postJson(
      '/tasks',
      body: {
        'title': title,
        if (description.isNotEmpty) 'description': description,
        'source_type': ?sourceType,
        'source_id': ?sourceId,
        if (reminderAt != null) 'reminder_at': reminderAt.toUtc().toIso8601String(),
        if (dueAt != null) 'due_at': dueAt.toUtc().toIso8601String(),
      },
      expectedStatuses: const {201},
    );
  }

  /// `DELETE /mail/bookmark-folders/{folderID}` (200). Messages stay starred.
  Future<void> deleteBookmarkFolder(String id) async {
    await _client.deleteJson(
      '/mail/bookmark-folders/${Uri.encodeComponent(id)}',
      expectedStatuses: const {200},
    );
  }
}
