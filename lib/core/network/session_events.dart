import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped whenever a request fails with 401 outside of an authentication
/// call. [AuthNotifier] listens to this and forces a sign-out, which in turn
/// makes the router redirect to /sign-in — the Flutter equivalent of
/// auth.interceptor.ts reacting to a 401 by calling authStore.signOut().
class UnauthorizedEventNotifier extends StateNotifier<int> {
  UnauthorizedEventNotifier() : super(0);

  void trigger() => state++;
}

final unauthorizedEventProvider =
    StateNotifierProvider<UnauthorizedEventNotifier, int>(
      (ref) => UnauthorizedEventNotifier(),
    );
