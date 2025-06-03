import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 글로벌 쿠키 저장소 제공자
final globalCookieJarProvider = Provider<CookieJar>((ref) {
  return CookieJar();
});

// 글로벌 쿠키 매니저 제공자
final globalCookieManagerProvider = Provider<CookieManager>((ref) {
  final cookieJar = ref.watch(globalCookieJarProvider);
  return CookieManager(cookieJar);
});
