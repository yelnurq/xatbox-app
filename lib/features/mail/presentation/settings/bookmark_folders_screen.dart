import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error_codes.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/utils/diagnostic_log.dart';
import '../../../../shared/utils/error_text.dart';
import '../../../../shared/widgets/state_view.dart';
import '../../data/mail_models.dart';
import '../../data/mail_settings_models.dart';
import '../mail_error_text.dart';
import '../mail_providers.dart';
import 'mail_settings_widgets.dart';

/// `GET/POST /mail/bookmark-folders`, `DELETE /mail/bookmark-folders/{id}`.
class BookmarkFoldersScreen extends ConsumerStatefulWidget {
  const BookmarkFoldersScreen({super.key});

  @override
  ConsumerState<BookmarkFoldersScreen> createState() =>
      _BookmarkFoldersScreenState();
}

class _BookmarkFoldersScreenState extends ConsumerState<BookmarkFoldersScreen> {
  List<MailBookmarkFolder>? _folders;
  Object? _loadError;
  bool _loading = true;
  final Set<String> _removing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final folders = await ref.read(mailApiProvider).listBookmarkFolders();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _loading = false;
      });
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'bookmark folders load failed', error: e);
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  /// The drawer lists bookmark folders from `/mail/summary`.
  void _refreshSummary() =>
      unawaited(ref.read(mailSummaryProvider.notifier).refresh());

  Future<void> _create() async {
    final l10n = context.l10n;
    final api = ref.read(mailApiProvider);
    await showDialog<bool>(
      context: context,
      builder: (_) => MailFormDialog(
        title: l10n.mailBookmarkFolderCreate,
        submitLabel: l10n.mailBookmarkFolderCreate,
        fields: [
          MailFormFieldSpec(
            key: 'bookmark_folder_name',
            label: l10n.mailBookmarkFolderName,
          ),
        ],
        validate: (values) {
          final n = values[0].trim().runes.length;
          return n == 0 || n > MailBookmarkFolder.maxNameChars
              ? l10n.mailBookmarkFolderNameInvalid
              : null;
        },
        onSubmit: (values) async {
          try {
            final folder = await api.createBookmarkFolder(values[0]);
            if (mounted) {
              setState(() => _folders = [...?_folders, folder]);
              _refreshSummary();
            }
            return null;
          } on AppException catch (e) {
            DiagnosticLog.warn('mail', 'bookmark folder create failed', error: e);
            return MailErrorText.describe(l10n, e);
          }
        },
      ),
    );
  }

  Future<void> _delete(MailBookmarkFolder folder) async {
    final l10n = context.l10n;
    final ok = await confirmMailAction(
      context,
      title: l10n.mailBookmarkFolderDeleteTitle(folder.name),
      body: l10n.mailBookmarkFolderDeleteBody,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _removing.add(folder.id));
    void dropLocally() {
      setState(
        () => _folders = [...?_folders?.where((f) => f.id != folder.id)],
      );
      if (ref.read(selectedFolderProvider) == folder.folderType) {
        ref.read(selectedFolderProvider.notifier).select(MailFolderType.inbox);
      }
      _refreshSummary();
    }

    try {
      await ref.read(mailApiProvider).deleteBookmarkFolder(folder.id);
      if (mounted) dropLocally();
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'bookmark folder delete failed', error: e);
      if (!mounted) return;
      if (e is ApiException && e.code == ApiErrorCodes.folderNotFound) {
        dropLocally();
      }
      messenger.showSnackBar(
        SnackBar(content: Text(MailErrorText.describe(l10n, e))),
      );
    } finally {
      if (mounted) setState(() => _removing.remove(folder.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final folders = _folders;

    Widget body;
    if (_loading && folders == null) {
      body = const StateView.loading();
    } else if (folders == null) {
      final err = _loadError!;
      body = ErrorText.isOffline(err)
          ? StateView.offline(
              message: ErrorText.describe(l10n, err),
              onRetry: _load,
            )
          : StateView.error(
              message: ErrorText.describe(l10n, err),
              onRetry: _load,
            );
    } else if (folders.isEmpty) {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.6,
              child: StateView.empty(
                title: l10n.mailBookmarkFoldersEmpty,
                icon: LucideIcons.bookmark,
              ),
            ),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final f in folders)
              ListTile(
                key: ValueKey('bookmark_folder_${f.id}'),
                leading: Icon(
                  LucideIcons.bookmark,
                  color: tokens.folderColor(f.color, fallback: tokens.brand),
                ),
                title: Text(f.name),
                onTap: () {
                  ref.read(selectedFolderProvider.notifier).select(f.folderType);
                  context.go(Routes.mail);
                },
                trailing: _removing.contains(f.id)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        tooltip: l10n.delete,
                        icon: const Icon(LucideIcons.trash2),
                        onPressed: () => _delete(f),
                      ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mailSettingsBookmarkFolders)),
      body: body,
      floatingActionButton: folders == null
          ? null
          : FloatingActionButton.extended(
              key: const Key('bookmark_folder_add'),
              onPressed: _create,
              icon: const Icon(LucideIcons.folderPlus),
              label: Text(l10n.mailBookmarkFolderCreate),
            ),
    );
  }
}
