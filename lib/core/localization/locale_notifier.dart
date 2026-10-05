import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocaleStore {
  static const _key = 'nurse_pulse_language';
  final _storage = const FlutterSecureStorage();
  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}

final localeStoreProvider = Provider<LocaleStore>((ref) => LocaleStore());

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(this._store) : super(const Locale('es')) {
    _restore();
  }
  final LocaleStore _store;
  bool _chosen = false;
  Future<void> _writes = Future.value();

  Future<void> _restore() async {
    try {
      final code = await _store.read();
      if (mounted && !_chosen && (code == 'es' || code == 'en')) {
        state = Locale(code!);
      }
    } catch (_) {
      /* A failed preference read must not block sign-in. */
    }
  }

  Future<bool> select(String code) async {
    if (code != 'es' && code != 'en') return false;
    _chosen = true;
    state = Locale(code);
    var saved = true;
    // Serialize writes so rapid choices also persist the last selection.
    _writes = _writes.then((_) async {
      try {
        await _store.write(code);
      } catch (_) {
        saved = false;
      }
    });
    await _writes;
    return saved;
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(ref.watch(localeStoreProvider)),
);
