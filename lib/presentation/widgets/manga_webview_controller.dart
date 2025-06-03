import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../data/providers/cookie_store_provider.dart';
import '../../data/providers/global_webview_provider.dart';
import '../../data/providers/global_cookie_jar_provider.dart';

class MangaWebViewController {
  late WebViewController controller;
  static const String _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1';
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  String _lastUrl = '';

  Future<void> initialize(dynamic ref) async {
    if (_isInitialized) return;

    try {
      final cookieStore = ref.read(cookieStoreProvider.notifier);

      // 전역 WebViewController 확인
      final globalController = getGlobalWebViewController();

      if (globalController != null) {
        // 기존 전역 컨트롤러 사용
        print('MangaWebViewController: 전역 WebViewController 재사용');
        controller = globalController;
      } else {
        print('MangaWebViewController: 새 WebViewController 생성 및 전역 저장');

        // 새 컨트롤러 생성
        controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..enableZoom(false)
          ..setUserAgent(_userAgent)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (String url) {
                print('WebView 페이지 로드 시작: $url');
              },
              onPageFinished: (String url) async {
                print('WebView 페이지 로드 완료: $url');

                try {
                  // 쿠키 추출 및 저장
                  final cookieList =
                      await controller.runJavaScriptReturningResult(
                    "document.cookie",
                  ) as String;

                  if (cookieList.isNotEmpty) {
                    print('WebView 쿠키 추출: $cookieList');
                    cookieStore.setCookies(cookieList.split('; '));
                  }
                } catch (e) {
                  print('WebView 쿠키 추출 중 오류: $e');
                }

                // 현재 URL 저장
                _lastUrl = url;
              },
              onWebResourceError: (WebResourceError error) {
                print('WebView 리소스 오류: ${error.description}');
              },
            ),
          );

        // 전역 함수를 통해 컨트롤러 저장
        setGlobalWebViewController(controller);
      }

      _isInitialized = true;
      print('MangaWebViewController 초기화 완료');
    } catch (e) {
      print('MangaWebViewController 초기화 중 오류: $e');
      // 오류가 발생해도 초기화 상태를 true로 설정하여 무한 재시도 방지
      _isInitialized = true;

      // 컨트롤러가 없는 경우 빈 컨트롤러 생성
      if (!_isInitialized) {
        controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..enableZoom(false)
          ..setUserAgent(_userAgent);
      }
    }

    _isInitialized = true;
  }

  Map<String, String>? _customHeaders;

  // 현재 URL 가져오기
  Future<String?> currentUrl() async {
    if (!_isInitialized) {
      print('[에러] WebViewController가 초기화되지 않았습니다');
      return null;
    }

    try {
      // 저장된 URL 반환
      if (_lastUrl.isNotEmpty) {
        return _lastUrl;
      }

      // 현재 URL 가져오기
      return await controller.currentUrl();
    } catch (e) {
      print('[에러] 현재 URL 가져오기 오류: $e');
      return null;
    }
  }

  // HTML 콘텐츠 가져오기
  Future<String?> getHtmlContent() async {
    if (!_isInitialized) {
      print('[에러] WebViewController가 초기화되지 않았습니다');
      return null;
    }

    try {
      // JavaScript를 사용하여 HTML 콘텐츠 가져오기
      final result = await controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );

      if (result == null) {
        print('[에러] HTML 콘텐츠가 비어 있습니다');
        return null;
      }

      final String html = result.toString();
      if (html.isEmpty) {
        print('[에러] HTML 콘텐츠가 비어 있습니다');
        return null;
      }

      // 결과가 문자열이 아닌 경우 문자열로 변환
      if (html.startsWith('"') && html.endsWith('"')) {
        // JavaScript 문자열 특수 문자 제거
        return html
            .substring(1, html.length - 1)
            .replaceAll('\\"', '"')
            .replaceAll('\\n', '\n')
            .replaceAll('\\r', '\r')
            .replaceAll('\\t', '\t');
      }

      return html;
    } catch (e) {
      print('[에러] HTML 콘텐츠 가져오기 오류: $e');
      return null;
    }
  }

  // 폼 제출
  Future<void> submitForm(
      String formActionUrl, Map<String, String> formData) async {
    if (!_isInitialized) {
      print('[에러] WebViewController가 초기화되지 않았습니다');
      return;
    }

    try {
      // JavaScript 폼 제출 코드 생성
      final jsCode = _generateFormSubmitJsCode(formActionUrl, formData);
      print('[디버그] 폼 제출 JavaScript: $jsCode');

      // JavaScript 실행
      await controller.runJavaScript(jsCode);
      print('[성공] 폼 제출 완료');
    } catch (e) {
      print('[에러] 폼 제출 오류: $e');
    }
  }

  // JavaScript 폼 제출 코드 생성
  String _generateFormSubmitJsCode(
      String formActionUrl, Map<String, String> formData) {
    final formInputs = formData.entries.map((entry) {
      return "formElement.appendChild(inputElement = document.createElement('input'));"
          "inputElement.name = '${entry.key}';"
          "inputElement.value = '${entry.value}';"
          "inputElement.type = 'hidden';";
    }).join('\n');

    return """
      (function() {
        var formElement = document.createElement('form');
        formElement.method = 'POST';
        formElement.action = '$formActionUrl';
        var inputElement;
        $formInputs
        document.body.appendChild(formElement);
        formElement.submit();
      })();
    """;
  }

  // 쿠키 설정 메서드
  Future<void> setCookies(Uri uri, Map<String, String> cookies) async {
    final cookieManager = WebViewCookieManager();
    for (final entry in cookies.entries) {
      print(
          '[WebView 쿠키 세팅] ${entry.key}=${entry.value}; domain=${uri.host}; path=/');
      await cookieManager.setCookie(
        WebViewCookie(
          name: entry.key,
          value: entry.value,
          domain: uri.host,
          path: '/',
        ),
      );
    }
    print('[WebView 쿠키 세팅 완료] ${cookies.length}개');
  }

  Future<void> setCustomHeaders(Map<String, String> headers) async {
    _customHeaders = headers;
    print('[WebView 헤더 세팅] $_customHeaders');
  }

  // 폼 데이터 제출 메서드 참고 주석
  // 이 메서드는 위에 정의된 submitForm 메서드로 대체되었습니다.

  Future<void> loadUrl(String url) async {
    await controller.loadRequest(
      Uri.parse(url),
      headers: _customHeaders ??
          {
            'User-Agent': _userAgent,
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
            'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
    );
  }

  Future<String> getHtml() async {
    final result = await controller.runJavaScriptReturningResult('''
      document.documentElement.outerHTML
    ''');
    return result.toString();
  }

  Future<void> syncCookiesFromCookieJar(dynamic ref, String url) async {
    try {
      final cookieJar = ref.read(globalCookieJarProvider);
      final uri = Uri.parse(url);
      final cookies = await cookieJar.loadForRequest(uri);
      final cookieMap = <String, String>{
        for (var c in cookies) c.name: c.value
      };
      await setCookies(uri, cookieMap);
      print('[WebView] 쿠키 동기화 완료: ${cookieMap.length}개');
    } catch (e) {
      print('[WebView] 쿠키 동기화 실패: $e');
    }
  }
}

final mangaWebViewControllerProvider = Provider<MangaWebViewController>((ref) {
  return MangaWebViewController();
});
