import '../../../shared/utils/api_date.dart';
import '../../chat/data/chat_models.dart';

/// A colleague from the organization directory, as returned by the Chat
/// Service `GET /users` and `GET /users/{id}` (proxy of the Mail API
/// directory, enriched with chat presence).
class Contact {
  const Contact({
    required this.id,
    required this.email,
    required this.displayName,
    this.online = false,
    this.lastSeenAt,
    this.department = '',
    this.departmentId = '',
    this.position = '',
    this.mailbox = '',
    this.avatarUpdatedAt,
    this.status,
  });

  final String id;

  /// Public status («В отпуске до 20 сентября»); null when none.
  final ChatUserStatus? status;

  /// Login email.
  final String email;
  final String displayName;
  final bool online;
  final DateTime? lastSeenAt;
  final String department;
  final String departmentId;
  final String position;

  /// First active mailbox when it differs from the login (else empty).
  final String mailbox;
  final DateTime? avatarUpdatedAt;

  String get label =>
      displayName.trim().isNotEmpty ? displayName.trim() : email;

  /// Where mail should go: the mailbox when known, else the login.
  String get mailAddress => mailbox.isNotEmpty ? mailbox : email;

  factory Contact.fromJson(Map<String, dynamic> j) {
    final email = (j['email'] as String?) ?? '';
    final mailbox = (j['mailbox_address'] as String?)?.trim() ?? '';
    return Contact(
      id: (j['user_id'] as String?) ?? (j['id'] as String?) ?? '',
      email: email,
      displayName: (j['display_name'] as String?) ?? '',
      online: j['online'] == true || j['is_online'] == true,
      lastSeenAt: parseApiDate(j['last_seen_at'] as String?),
      department:
          (j['department_name'] as String?) ??
          (j['department'] as String?) ??
          '',
      departmentId: (j['department_id'] as String?) ?? '',
      position: (j['position'] as String?) ?? (j['job_title'] as String?) ?? '',
      mailbox: mailbox.toLowerCase() == email.trim().toLowerCase()
          ? ''
          : mailbox,
      avatarUpdatedAt: parseApiDate(j['avatar_updated_at'] as String?),
      status: ChatUserStatus.fromJsonOrNull(j['status']),
    );
  }

  /// Cache representation (not sent to any API).
  Map<String, dynamic> toJson() => {
    'user_id': id,
    'email': email,
    'display_name': displayName,
    'online': online,
    'last_seen_at': ?lastSeenAt?.toUtc().toIso8601String(),
    if (department.isNotEmpty) 'department_name': department,
    if (departmentId.isNotEmpty) 'department_id': departmentId,
    if (position.isNotEmpty) 'position': position,
    if (mailbox.isNotEmpty) 'mailbox_address': mailbox,
    'avatar_updated_at': ?avatarUpdatedAt?.toUtc().toIso8601String(),
    'status': ?status?.toJson(),
  };

  Contact copyWith({
    bool? online,
    DateTime? lastSeenAt,
    ChatUserStatus? status,
    bool clearStatus = false,
  }) => Contact(
    id: id,
    email: email,
    displayName: displayName,
    online: online ?? this.online,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    department: department,
    departmentId: departmentId,
    position: position,
    mailbox: mailbox,
    avatarUpdatedAt: avatarUpdatedAt,
    status: clearStatus ? null : (status ?? this.status),
  );

  /// For the chat presence formatter.
  ChatUser toChatUser() => ChatUser(
    userId: id,
    email: email,
    displayName: displayName,
    online: online,
    lastSeenAt: lastSeenAt,
    status: status,
  );

  /// For sharing to a chat as a contact card.
  ChatContact toChatContact() =>
      ChatContact(userId: id, displayName: displayName, email: email);

  /// Local (offline) search: name, email, mailbox, department, position.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      displayName,
      email,
      mailbox,
      department,
      position,
    ].any((f) => f.toLowerCase().contains(q));
  }

  /// vCard 3.0 text (share / copy fallback).
  String toVCard() {
    String esc(String s) => s
        .replaceAll(r'\', r'\\')
        .replaceAll(',', r'\,')
        .replaceAll(';', r'\;')
        .replaceAll('\n', r'\n');
    return [
      'BEGIN:VCARD',
      'VERSION:3.0',
      'FN:${esc(label)}',
      if (department.isNotEmpty) 'ORG:;${esc(department)}',
      if (position.isNotEmpty) 'TITLE:${esc(position)}',
      if (email.isNotEmpty) 'EMAIL;TYPE=INTERNET:${esc(email)}',
      if (mailbox.isNotEmpty) 'EMAIL;TYPE=INTERNET:${esc(mailbox)}',
      'END:VCARD',
    ].join('\r\n');
  }
}

/// A department of the organization (`GET /departments`).
class Department {
  const Department({
    required this.id,
    required this.name,
    this.description = '',
    this.managerUserId = '',
    this.managerName = '',
    this.managerEmail = '',
    this.employeeCount = 0,
    this.status = 'active',
  });

  final String id;
  final String name;
  final String description;
  final String managerUserId;
  final String managerName;
  final String managerEmail;
  final int employeeCount;
  final String status;

  bool get isArchived => status == 'archived';
  bool get hasManager => managerUserId.isNotEmpty;
  String get managerLabel =>
      managerName.trim().isNotEmpty ? managerName.trim() : managerEmail;

  factory Department.fromJson(Map<String, dynamic> j) => Department(
    id: (j['id'] as String?) ?? '',
    name: (j['name'] as String?) ?? '',
    description: (j['description'] as String?) ?? '',
    managerUserId: (j['manager_user_id'] as String?) ?? '',
    managerName: (j['manager_name'] as String?) ?? '',
    managerEmail: (j['manager_email'] as String?) ?? '',
    employeeCount: (j['employee_count'] as num?)?.toInt() ?? 0,
    status: (j['status'] as String?) ?? 'active',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    if (managerUserId.isNotEmpty) 'manager_user_id': managerUserId,
    if (managerName.isNotEmpty) 'manager_name': managerName,
    if (managerEmail.isNotEmpty) 'manager_email': managerEmail,
    'employee_count': employeeCount,
    'status': status,
  };
}

/// One section of the directory: a letter or a department.
class ContactSection {
  const ContactSection(this.letter, this.contacts, {this.departmentId});

  /// Header text: the letter, or the department name.
  final String letter;
  final List<Contact> contacts;

  /// Set in department grouping ('' = no department).
  final String? departmentId;
}

/// Bucket for names that do not start with a letter.
const contactsOtherSection = '#';

final _letterRe = RegExp(r'^\p{L}$', unicode: true);

String _sortKey(Contact c) =>
    c.label.toLowerCase().replaceAll('ё', 'е').trim();

int _byName(Contact a, Contact b) {
  final r = _sortKey(a).compareTo(_sortKey(b));
  return r != 0 ? r : a.email.compareTo(b.email);
}

/// Section letter: first letter upper-cased (Ё filed under Е), `#` otherwise.
String contactSectionLetter(Contact c) {
  final label = c.label.trim();
  if (label.isEmpty) return contactsOtherSection;
  var ch = String.fromCharCode(label.runes.first).toUpperCase();
  if (ch == 'Ё') ch = 'Е';
  return _letterRe.hasMatch(ch) ? ch : contactsOtherSection;
}

int _scriptRank(String letter) {
  if (letter == contactsOtherSection) return 3;
  final code = letter.runes.first;
  if (code >= 0x0400 && code <= 0x04FF) return 0; // Cyrillic (ru, kk)
  if (code >= 0x41 && code <= 0x5A) return 1; // Latin
  return 2;
}

Iterable<Contact> _unique(Iterable<Contact> contacts, String? excludeId) sync* {
  final seen = <String>{};
  for (final c in contacts) {
    if (c.id.isEmpty || c.id == excludeId || !seen.add(c.id)) continue;
    yield c;
  }
}

/// Groups contacts into alphabetical sections (pure, unit-tested):
/// Cyrillic letters first, then Latin, other scripts, and `#` last; names
/// sorted case-insensitively inside a section; duplicates and [excludeId]
/// (the signed-in user) removed.
List<ContactSection> groupContacts(
  Iterable<Contact> contacts, {
  String? excludeId,
}) {
  final buckets = <String, List<Contact>>{};
  for (final c in _unique(contacts, excludeId)) {
    buckets.putIfAbsent(contactSectionLetter(c), () => []).add(c);
  }
  final letters = buckets.keys.toList()
    ..sort((a, b) {
      final r = _scriptRank(a).compareTo(_scriptRank(b));
      return r != 0 ? r : a.compareTo(b);
    });
  return [
    for (final letter in letters)
      ContactSection(letter, buckets[letter]!..sort(_byName)),
  ];
}

/// Groups contacts by department name (sorted; people without a department
/// last under [noDepartment]); names sorted inside.
List<ContactSection> groupContactsByDepartment(
  Iterable<Contact> contacts, {
  required String noDepartment,
  String? excludeId,
}) {
  final buckets = <String, List<Contact>>{};
  final names = <String, String>{};
  for (final c in _unique(contacts, excludeId)) {
    final key = c.departmentId.isNotEmpty
        ? c.departmentId
        : (c.department.isNotEmpty ? 'name:${c.department}' : '');
    buckets.putIfAbsent(key, () => []).add(c);
    names[key] = key.isEmpty ? noDepartment : c.department;
  }
  final keys = buckets.keys.toList()
    ..sort((a, b) {
      if (a.isEmpty != b.isEmpty) return a.isEmpty ? 1 : -1;
      return names[a]!.toLowerCase().compareTo(names[b]!.toLowerCase());
    });
  return [
    for (final k in keys)
      ContactSection(
        names[k]!,
        buckets[k]!..sort(_byName),
        departmentId: k.startsWith('name:') ? '' : k,
      ),
  ];
}

/// Flat list row of the directory (built once per data change, not per build).
sealed class ContactRow {
  const ContactRow();
}

class ContactHeaderRow extends ContactRow {
  const ContactHeaderRow(this.title, {this.count = 0, this.icon});
  final String title;
  final int count;

  /// Marks special headers (favourites / recent) — the index skips them.
  final String? icon;
}

class ContactItemRow extends ContactRow {
  const ContactItemRow(this.contact, {this.section = ''});
  final Contact contact;

  /// Key prefix so the same person may appear in favourites and the list.
  final String section;
}

/// Case-insensitive match ranges of [query] in [text] (for highlighting).
List<(int, int)> matchRanges(String text, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty || text.isEmpty) return const [];
  final lower = text.toLowerCase();
  if (lower.length != text.length) return const [];
  final out = <(int, int)>[];
  var from = 0;
  while (true) {
    final i = lower.indexOf(q, from);
    if (i < 0) break;
    out.add((i, i + q.length));
    from = i + q.length;
  }
  return out;
}

/// Filter chips of the directory.
enum ContactsFilter { all, online, favourites }
