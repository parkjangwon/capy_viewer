import 'package:shared_preferences/shared_preferences.dart';

class ContentFilter {
  static final List<String> _restrictedTags = [
    '17',
    'BL',
    'TS',
    '붕탁',
    '백합',
    '러브코미디',
  ];

  static Future<bool> isSafeModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('safe_mode') ?? false;
  }

  static bool shouldFilterContent(String title, String tags) {
    final combinedText = '$title $tags'.toLowerCase();
    return _restrictedTags.any((tag) => combinedText.contains(tag.toLowerCase()));
  }

  static Future<bool> isContentAllowed(String title, String tags) async {
    final isSafeMode = await isSafeModeEnabled();
    if (!isSafeMode) return true;
    return !shouldFilterContent(title, tags);
  }
} 