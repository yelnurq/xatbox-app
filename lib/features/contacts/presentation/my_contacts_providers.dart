import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../data/personal_contacts.dart';

final personalContactsStoreProvider = Provider<PersonalContactsStore>(
  (ref) => PersonalContactsStore(ref.watch(appDatabaseProvider)),
);

/// Desktop «Мои контакты»: the people the user added by hand (sorted by
/// name). The pinned colleagues are the favourites (`contactsFavouritesProvider`).
class PersonalContactsNotifier extends Notifier<List<PersonalContact>> {
  bool _touched = false;

  String get _owner => ref.read(currentUserProvider)?.id ?? '';

  @override
  List<PersonalContact> build() {
    ref.watch(currentUserProvider.select((u) => u?.id));
    _touched = false;
    Future.microtask(() async {
      try {
        final saved = await ref.read(personalContactsStoreProvider).read(ownerId: _owner);
        if (ref.mounted && !_touched) state = _sorted(saved);
      } on Object catch (e) {
        DiagnosticLog.warn('contacts', 'personal contacts not read', error: e);
      }
    });
    return const [];
  }

  static List<PersonalContact> _sorted(List<PersonalContact> list) =>
      [...list]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Adds [contact] or replaces the one with its id.
  Future<void> save(PersonalContact contact) async {
    _touched = true;
    final exists = state.any((c) => c.id == contact.id);
    state = _sorted(exists ? [for (final c in state) c.id == contact.id ? contact : c] : [...state, contact]);
    await _write();
  }

  Future<void> remove(String id) async {
    _touched = true;
    state = [for (final c in state) if (c.id != id) c];
    await _write();
  }

  Future<void> _write() async {
    try {
      await ref.read(personalContactsStoreProvider).write(ownerId: _owner, contacts: state);
    } on Object catch (e) {
      DiagnosticLog.warn('contacts', 'personal contacts not saved', error: e);
    }
  }
}

final personalContactsProvider = NotifierProvider<PersonalContactsNotifier, List<PersonalContact>>(
  PersonalContactsNotifier.new,
);
