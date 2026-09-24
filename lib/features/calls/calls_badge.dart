import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_session.dart';
import 'presentation/calls_providers.dart';

/// Missed calls for the "Звонки" tab badge (ТЗ п.24.2), from the Call Service.
final callsBadgeProvider = Provider<int>((ref) {
  if (!ref.watch(callsEnabledProvider)) return 0;
  if (ref.watch(authStateProvider).status != AuthStatus.authenticated) return 0;
  return ref.watch(missedCallsProvider);
});
