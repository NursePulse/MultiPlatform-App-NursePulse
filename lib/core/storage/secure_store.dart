import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the auth session and the demo "view mode" toggle.
/// Mirrors token.storage.ts / view-mode.store.ts from the Angular app.
class SecureStore {
  SecureStore() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'nurse_pulse_token';
  static const _userKey = 'nurse_pulse_user';
  static const _viewModeKey = 'nurse_pulse_view_mode';
  static const _subscriptionPlanKey = 'nurse_pulse_subscription_plan';

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<Map<String, dynamic>?> readUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(user));
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }

  Future<String?> readViewMode() => _storage.read(key: _viewModeKey);

  Future<void> saveViewMode(String mode) =>
      _storage.write(key: _viewModeKey, value: mode);

  Future<void> clearViewMode() => _storage.delete(key: _viewModeKey);

  Future<String?> readSubscriptionPlan() =>
      _storage.read(key: _subscriptionPlanKey);

  Future<void> saveSubscriptionPlan(String planId) =>
      _storage.write(key: _subscriptionPlanKey, value: planId);
}
