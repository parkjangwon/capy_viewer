import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

// 전역 쿠키 저장소
final globalCookieJarProvider = Provider<CookieJar>((ref) {
  return CookieJar();
});

// Dio용 쿠키 매니저
final cookieManagerProvider = Provider<CookieManager>((ref) {
  final jar = ref.watch(globalCookieJarProvider);
  return CookieManager(jar);
});

// 쿠키 문자열 추출 헬퍼 함수
Future<String?> getCookieString(CookieJar jar, String url) async {
  try {
    final cookies = await jar.loadForRequest(Uri.parse(url));
    if (cookies.isEmpty) return null;
    return cookies.map((c) => '${c.name}=${c.value}').join('; ');
  } catch (e) {
    print('쿠키 로드 오류: $e');
    return null;
  }
}
