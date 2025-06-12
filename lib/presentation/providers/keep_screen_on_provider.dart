import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final keepScreenOnProvider =
    StateNotifierProvider<KeepScreenOnNotifier, bool>((ref) {
  return KeepScreenOnNotifier();
});

class KeepScreenOnNotifier extends StateNotifier<bool> {
  KeepScreenOnNotifier() : super(false) {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('keep_screen_on') ?? false;
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    state = !state;
    await prefs.setBool('keep_screen_on', state);
  }
}
