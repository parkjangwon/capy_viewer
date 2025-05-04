import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cookie_jar/cookie_jar.dart';

/// 전역 쿠키 저장소를 제공하는 Provider
final globalCookieJarProvider = Provider<CookieJar>((ref) => CookieJar());
