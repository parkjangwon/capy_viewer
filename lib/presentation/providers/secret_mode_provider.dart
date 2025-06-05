import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final secretModeProvider =
    StateNotifierProvider<SecretModeNotifier, bool>((ref) {
  return SecretModeNotifier();
});

class SecretModeNotifier extends StateNotifier<bool> {
  SecretModeNotifier() : super(false) {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('secret_mode') ?? false;
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    state = !state;
    await prefs.setBool('secret_mode', state);
  }
}
