import 'package:cookie_jar/cookie_jar.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Dio의 쿠키를 WebView로 동기화하는 함수
Future<void> syncDioCookiesToWebView(
    String baseUrl, CookieJar cookieJar) async {
  try {
    // CookieJar에서 쿠키 가져오기
    final cookies = await cookieJar.loadForRequest(Uri.parse(baseUrl));

    // WebView에 쿠키 설정
    for (final cookie in cookies) {
      final cookieString = '${cookie.name}=${cookie.value}';
      await WebViewCookieManager().setCookie(
        WebViewCookie(
          name: cookie.name,
          value: cookie.value,
          domain: cookie.domain ?? Uri.parse(baseUrl).host,
          path: cookie.path ?? '/',
        ),
      );
      print('WebView에 쿠키 설정: $cookieString');
    }
  } catch (e) {
    print('쿠키 동기화 오류: $e');
  }
}

/// WebView의 쿠키를 Dio로 동기화하는 함수
Future<void> syncWebViewCookiesToDio(
    String baseUrl, CookieJar cookieJar) async {
  try {
    // 참고: WebViewCookieManager().getCookies 메서드는 현재 버전에서 지원되지 않음
    // 대신 JavaScript를 사용하여 쿠키를 가져오는 방법을 사용할 수 있지만
    // 여기서는 간단히 처리

    // 현재 구현에서는 WebView에서 Dio로 쿠키를 동기화하지 않음
    // 필요한 경우 JavaScript를 사용하여 document.cookie를 가져오는 방식으로 구현 가능

    print('WebView에서 Dio로 쿠키 동기화 (더미 구현)');
  } catch (e) {
    print('쿠키 동기화 오류: $e');
  }
}
