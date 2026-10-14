import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal key-value surface for encrypted storage, so tests can fake it.
abstract class SecretStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecretStorage implements SecretStorage {
  final FlutterSecureStorage _storage;

  const FlutterSecretStorage([
    this._storage = const FlutterSecureStorage(),
  ]);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// A decoded copy of the saved Medical ID.
class MedicalIdSnapshot {
  final Map<String, Object> _values;

  const MedicalIdSnapshot(this._values);

  static const empty = MedicalIdSnapshot({});

  String string(String key) {
    final value = _values[key];
    return value is String ? value : '';
  }

  List<String> list(String key) {
    final value = _values[key];
    return value is List ? value.map((item) => item.toString()).toList() : [];
  }
}

/// Stores the Medical ID (name, blood type, conditions, medications, contacts)
/// in encrypted storage instead of plain SharedPreferences.
///
/// Existing data in SharedPreferences is migrated on first load. Legacy values
/// are only removed once the encrypted copy has been read back correctly, and
/// if encrypted storage is unusable the legacy values stay readable, so SOS
/// keeps working.
class MedicalIdStore {
  static const String _secretKey = 'medical_id_v1';

  static const List<String> stringKeys = [
    'name',
    'photo_url',
    'age',
    'blood',
    'address',
    'conditions',
    'medications',
    'preferred_hospital',
    'note',
    'critical_warning',
    'contact',
  ];

  static const List<String> listKeys = [
    'allergy_items',
    'medication_items',
    'contact_names',
    'contact_phones',
    'contact_relationships',
  ];

  final SecretStorage _secrets;

  MedicalIdStore({SecretStorage? secrets})
    : _secrets = secrets ?? const FlutterSecretStorage();

  Future<MedicalIdSnapshot> load() async {
    Map<String, Object>? stored;
    try {
      stored = _decode(await _secrets.read(_secretKey));
    } catch (error) {
      // Typically an undecryptable blob (e.g. restored from a backup onto a
      // new device). Fall through to legacy values or an empty ID.
      debugPrint('MedicalIdStore: could not read encrypted data: $error');
    }
    if (stored != null) return MedicalIdSnapshot(stored);

    final prefs = await SharedPreferences.getInstance();
    final legacy = _readLegacy(prefs);
    if (legacy.isEmpty) return MedicalIdSnapshot.empty;

    await _migrate(prefs, legacy);
    return MedicalIdSnapshot(legacy);
  }

  Future<void> save(Map<String, Object> values) async {
    final clean = <String, Object>{
      for (final key in stringKeys)
        if (values[key] is String) key: values[key]!,
      for (final key in listKeys)
        if (values[key] is List) key: values[key]!,
    };
    await _secrets.write(_secretKey, jsonEncode(clean));

    // Anything left in plain storage is stale now.
    final prefs = await SharedPreferences.getInstance();
    await _removeLegacy(prefs);
  }

  Future<void> _migrate(
    SharedPreferences prefs,
    Map<String, Object> legacy,
  ) async {
    try {
      await _secrets.write(_secretKey, jsonEncode(legacy));
      final check = _decode(await _secrets.read(_secretKey));
      if (check == null || jsonEncode(check) != jsonEncode(legacy)) {
        throw StateError('encrypted copy did not match');
      }
      await _removeLegacy(prefs);
    } catch (error) {
      // Keep the plain copy: losing an emergency contact is worse than
      // retrying the migration next launch.
      debugPrint('MedicalIdStore: migration deferred: $error');
    }
  }

  Map<String, Object> _readLegacy(SharedPreferences prefs) {
    return {
      for (final key in stringKeys) key: ?prefs.getString(key),
      for (final key in listKeys) key: ?prefs.getStringList(key),
    };
  }

  Future<void> _removeLegacy(SharedPreferences prefs) async {
    for (final key in [...stringKeys, ...listKeys]) {
      if (prefs.containsKey(key)) await prefs.remove(key);
    }
  }

  Map<String, Object>? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return {
      for (final entry in decoded.entries)
        if (entry.value != null) entry.key.toString(): entry.value as Object,
    };
  }
}
