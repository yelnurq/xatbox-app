import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-shot request to open a module's own search, pre-filled with a query
/// ('' = just open the field): `/chat/search` and «Показать все» of the
/// unified search. The module root consumes it (null = nothing pending).
class SearchPrefillNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void request([String query = '']) => state = query;
  void consume() => state = null;
}

/// Chat list: opens its search field.
final chatSearchRequestProvider =
    NotifierProvider<SearchPrefillNotifier, String?>(SearchPrefillNotifier.new);

/// Mail home: Inbox with the search field and `q`.
final mailSearchRequestProvider =
    NotifierProvider<SearchPrefillNotifier, String?>(SearchPrefillNotifier.new);

/// Unified search: the query typed into the desktop top bar.
final unifiedSearchRequestProvider =
    NotifierProvider<SearchPrefillNotifier, String?>(SearchPrefillNotifier.new);

/// Contacts tab: the directory search field.
final contactsSearchRequestProvider =
    NotifierProvider<SearchPrefillNotifier, String?>(SearchPrefillNotifier.new);
