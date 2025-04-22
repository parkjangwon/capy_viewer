import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CookieStore extends StateNotifier<Map<String, String>> {
  CookieStore() : super({});

  void setCookies(List<String> cookies) {
    final Map<String, String> newCookies = {};
    for (final cookie in cookies) {
      final parts = cookie.split('=');
      if (parts.length == 2) {
        newCookies[parts[0].trim()] = parts[1].trim();
      }
    }
    state = {...state, ...newCookies};
  }

  void setCookie(String name, String value) {
    state = {...state, name: value};
  }

  String? getCookie(String name) {
    return state[name];
  }

  List<String> getAllCookies() {
    return state.entries.map((e) => '${e.key}=${e.value}').toList();
  }

  String getCookieString() {
    return getAllCookies().join('; ');
  }

  void clearCookies() {
    state = {};
  }
}

final cookieStoreProvider = StateNotifierProvider<CookieStore, Map<String, String>>((ref) {
  return CookieStore();
}); 