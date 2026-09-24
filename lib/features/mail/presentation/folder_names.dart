import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/localization/localization.dart';
import '../data/mail_models.dart';

/// Localized names for system folders; server names for everything else.
String folderDisplayName(
  AppLocalizations l10n,
  String type, {
  String? serverName,
}) {
  return switch (type) {
    MailFolderType.inbox => l10n.folderInbox,
    MailFolderType.sent => l10n.folderSent,
    MailFolderType.drafts => l10n.folderDrafts,
    MailFolderType.spam => l10n.folderSpam,
    MailFolderType.trash => l10n.folderTrash,
    MailFolderType.bookmarks => l10n.folderBookmarks,
    _ => (serverName != null && serverName.isNotEmpty) ? serverName : type,
  };
}

/// The web sidebar's `FOLDER_META` icons (lucide).
IconData folderIcon(String type) => switch (type) {
  MailFolderType.inbox => LucideIcons.inbox,
  MailFolderType.sent => LucideIcons.send,
  MailFolderType.drafts => LucideIcons.fileText,
  MailFolderType.spam => LucideIcons.octagonAlert,
  MailFolderType.trash => LucideIcons.trash2,
  MailFolderType.bookmarks => LucideIcons.bookmark,
  _ when MailFolderType.isSmart(type) => LucideIcons.folder,
  _ when MailFolderType.isBookmarkFolder(type) => LucideIcons.bookmark,
  _ => LucideIcons.folder,
};
