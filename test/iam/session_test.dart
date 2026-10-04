import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/core/network/session_events.dart';
import 'package:nurse_pulse_app/core/storage/secure_store.dart';
import 'package:nurse_pulse_app/features/iam/application/auth_notifier.dart';

class MemoryStore extends SecureStore {
  MemoryStore({this.role = 'ROLE_DOCTOR', this.failRead = false});

  final String role;
  final bool failRead;
  bool cleared = false;

  @override
  Future<String?> readToken() async {
    if (failRead) throw StateError('Storage unavailable');
    return 'test-token';
  }

  @override
  Future<Map<String, dynamic>?> readUser() async => {
    'id': 1,
    'username': 'doctor.test',
    'roles': [role],
  };

  @override
  Future<void> clearSession() async {
    cleared = true;
  }

  @override
  Future<void> clearViewMode() async {}

  @override
  Future<void> saveViewMode(String mode) async {}
}

void main() {
  test('restaura el rol Doctor real', () async {
    final container = ProviderContainer(
      overrides: [secureStoreProvider.overrideWithValue(MemoryStore())],
    );
    addTearDown(container.dispose);

    container.read(authNotifierProvider);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(authNotifierProvider);
    expect(state.restoring, isFalse);
    expect(state.isAuthenticated, isTrue);
    expect(state.user!.primaryRole, 'ROLE_DOCTOR');
  });

  test('un rol desconocido no restaura una sesión autenticada', () async {
    final store = MemoryStore(role: 'ROLE_UNKNOWN');
    final container = ProviderContainer(
      overrides: [secureStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    container.read(authNotifierProvider);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authNotifierProvider).isAuthenticated, isFalse);
    expect(store.cleared, isTrue);
  });

  test('fallo de almacenamiento no deja el splash cargando', () async {
    final container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(MemoryStore(failRead: true)),
      ],
    );
    addTearDown(container.dispose);

    container.read(authNotifierProvider);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authNotifierProvider).restoring, isFalse);
    expect(container.read(authNotifierProvider).isAuthenticated, isFalse);
  });

  test('un evento 401 cierra la sesión restaurada', () async {
    final store = MemoryStore();
    final container = ProviderContainer(
      overrides: [secureStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    container.read(authNotifierProvider);
    await Future<void>.delayed(Duration.zero);

    container.read(unauthorizedEventProvider.notifier).trigger();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authNotifierProvider).isAuthenticated, isFalse);
    expect(store.cleared, isTrue);
  });
}
