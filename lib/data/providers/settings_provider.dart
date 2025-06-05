import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsNotifier extends StateNotifier<Map<String, dynamic>> {
  final SharedPreferences prefs;

  SettingsNotifier(this.prefs)
      : super({
          'isSecretMode': false,
        }) {
    _loadSettings();
  }

  void _loadSettings() {
    state = {
      'isSecretMode': prefs.getBool('isSecretMode') ?? false,
    };
  }

  Future<void> setSecretMode(bool value) async {
    await prefs.setBool('isSecretMode', value);
    state = {
      ...state,
      'isSecretMode': value,
    };
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, Map<String, dynamic>>((ref) {
  throw UnimplementedError('SharedPreferences instance required');
});

final settingsProviderFamily = StateNotifierProvider.family<SettingsNotifier,
    Map<String, dynamic>, SharedPreferences>((ref, prefs) {
  return SettingsNotifier(prefs);
});
