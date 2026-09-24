import 'package:sembast/sembast.dart';

import '../../../core/storage/app_database.dart';

/// A person the user keeps in «Мои контакты» who is not in the university
/// directory (a partner, a parent, a colleague elsewhere). Local to the
/// device: the Mail API has no personal address book.
class PersonalContact {
  const PersonalContact({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.organization = '',
    this.position = '',
    this.note = '',
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String organization;
  final String position;
  final String note;

  /// «Должность · Организация» (or whichever is known).
  String get details => [position, organization].where((s) => s.trim().isNotEmpty).join(' · ');

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [name, email, phone, organization, position].any((f) => f.toLowerCase().contains(q));
  }

  factory PersonalContact.fromJson(Map<String, dynamic> j) => PersonalContact(
    id: (j['id'] as String?) ?? '',
    name: (j['name'] as String?) ?? '',
    email: (j['email'] as String?) ?? '',
    phone: (j['phone'] as String?) ?? '',
    organization: (j['organization'] as String?) ?? '',
    position: (j['position'] as String?) ?? '',
    note: (j['note'] as String?) ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (email.isNotEmpty) 'email': email,
    if (phone.isNotEmpty) 'phone': phone,
    if (organization.isNotEmpty) 'organization': organization,
    if (position.isNotEmpty) 'position': position,
    if (note.isNotEmpty) 'note': note,
  };
}

/// Personal contacts per account, kept like the favourite colleagues: they
/// survive sign-out and another account on the device never sees them.
class PersonalContactsStore {
  PersonalContactsStore(this._db);

  final AppDatabase _db;
  static final _store = stringMapStoreFactory.store('contacts_personal');

  Future<List<PersonalContact>> read({required String ownerId}) async {
    if (ownerId.isEmpty) return const [];
    final row = await _store.record(ownerId).get(_db.db);
    return ((row?['contacts'] as List?) ?? const [])
        .map((e) => PersonalContact.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((c) => c.id.isNotEmpty && c.name.trim().isNotEmpty)
        .toList();
  }

  Future<void> write({required String ownerId, required List<PersonalContact> contacts}) async {
    if (ownerId.isEmpty) return;
    await _store.record(ownerId).put(_db.db, {
      'contacts': [for (final c in contacts) c.toJson()],
    });
  }
}
