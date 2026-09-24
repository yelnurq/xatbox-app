import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../../shared/utils/diagnostic_log.dart';
import '../auth/auth_providers.dart';
import 'desktop.dart';

/// The desktop layout: the web's shell (full-height sidebar with folders and
/// workspace links, top bar with search and account controls) around every
/// signed-in screen. Overridden in tests.
final desktopLayoutProvider = Provider<bool>((_) => isDesktop);

/// Desktop: the app's root messenger, for in-window notices raised outside
/// any screen (a letter from «Исходящие» went out). Not set on phones.
final desktopMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// The sidebar collapsed to icons (web «Свернуть меню»), remembered like the
/// web's `xatbox-sidebar-collapsed`.
class DesktopSidebarCollapsedNotifier extends Notifier<bool> {
  static final _store = stringMapStoreFactory.store('settings');
  static const _key = 'desktop';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final raw = await _store.record(_key).get(ref.read(appDatabaseProvider).db);
      if (raw?['sidebar_collapsed'] == true) state = true;
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'sidebar state not read', error: e);
    }
  }

  Future<void> toggle() async {
    state = !state;
    try {
      await _store.record(_key).put(ref.read(appDatabaseProvider).db, {'sidebar_collapsed': state}, merge: true);
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'sidebar state not saved', error: e);
    }
  }
}

final desktopSidebarCollapsedProvider = NotifierProvider<DesktopSidebarCollapsedNotifier, bool>(
  DesktopSidebarCollapsedNotifier.new,
);
