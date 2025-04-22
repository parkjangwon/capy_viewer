import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../../core/logger.dart';
import '../../../data/providers/cookie_store_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef OnVerifiedCallback = void Function(String html, List<String> cookies);
typedef OnErrorCallback = void Function(dynamic error);

class CloudflareCaptcha extends ConsumerStatefulWidget {
  final String url;
  final OnVerifiedCallback onVerified;
  final OnErrorCallback onError;
  static const String _captchaVerifiedKey = 'captcha_verified_at';
  static const Duration _captchaValidDuration = Duration(hours: 1);
  static final _logger = Logger();

  const CloudflareCaptcha({
    super.key,
    required this.url,
    required this.onVerified,
    required this.onError,
  });

  /// 캡차 인증이 유효한지 확인
  static Future<bool> isCaptchaValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastVerified = prefs.getInt(_captchaVerifiedKey);
      if (lastVerified == null) return false;

      final now = DateTime.now().millisecondsSinceEpoch;
      return now - lastVerified <= _captchaValidDuration.inMilliseconds;
    } catch (e) {
      return false;
    }
  }

  /// 캡차 인증 시간 저장
  static Future<void> saveCaptchaVerifiedTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _captchaVerifiedKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // 저장 실패는 무시
    }
  }

  @override
  ConsumerState<CloudflareCaptcha> createState() => _CloudflareCaptchaState();
}

class _CloudflareCaptchaState extends ConsumerState<CloudflareCaptcha> {
  late final WebViewController _controller;
  bool _isLoading = true;
  final _logger = Logger();
  static const String _userAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final cookieStore = ref.read(cookieStoreProvider.notifier);
    final cookieManager = WebViewCookieManager();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..enableZoom(false)  // 줌 비활성화
      ..setUserAgent(_userAgent)  // 사용자 에이전트 설정
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) async {
            if (!mounted) return;
            setState(() => _isLoading = true);
            _logger.i('[CAPTCHA] 페이지 로드 시작: $url');

            // 저장된 쿠키 설정
            final cookies = cookieStore.getAllCookies();
            for (final cookie in cookies) {
              final parts = cookie.split('=');
              if (parts.length == 2) {
                await cookieManager.setCookie(
                  WebViewCookie(
                    name: parts[0].trim(),
                    value: parts[1].trim(),
                    domain: Uri.parse(widget.url).host,
                  ),
                );
              }
            }
          },
          onPageFinished: (String url) async {
            if (!mounted) return;
            setState(() => _isLoading = false);
            _logger.i('[CAPTCHA] 페이지 로드 완료: $url');

            // JavaScript 인젝션으로 클라우드플레어 캡차 상태 확인
            final isCaptchaPresent = await _controller.runJavaScriptReturningResult('''
              document.querySelector('#challenge-form') != null;
            ''');

            if (isCaptchaPresent.toString() == 'true') {
              _logger.i('[CAPTCHA] 클라우드플레어 캡차 감지됨');
              // 캡차 자동 클릭 시도
              await _controller.runJavaScript('''
                document.querySelector('#challenge-form button[type="submit"]')?.click();
              ''');
            } else if (!url.contains('challenges.cloudflare.com')) {
              await _checkCaptchaStatus();
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            _logger.i('[CAPTCHA] 네비게이션 요청: ${request.url}');
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            _logger.e('[CAPTCHA] 웹 리소스 오류', error: error.description);
            if (!mounted) return;
            widget.onError(error.description);
          },
        ),
      );

    // 웹뷰 설정
    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (_controller.platform as AndroidWebViewController)
        ..setMediaPlaybackRequiresUserGesture(false)
        ..setUserAgent(_userAgent);
    }

    // 초기 URL 로드
    _controller.loadRequest(
      Uri.parse(widget.url),
      headers: {
        'User-Agent': _userAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );
  }

  Future<void> _checkCaptchaStatus() async {
    try {
      final result = await _controller.runJavaScriptReturningResult('''
        document.documentElement.outerHTML;
      ''');

      final html = result.toString();
      if (html.contains('cf-browser-verification')) {
        _logger.i('[CAPTCHA] 캡차 검증 중...');
        return;
      }

      final cookies = await WebViewCookieManager().getCookies(widget.url);
      final cookieStrings = cookies.map((c) => '${c.name}=${c.value}').toList();

      // 쿠키 저장
      ref.read(cookieStoreProvider.notifier).setCookies(cookieStrings);

      if (!mounted) return;
      widget.onVerified(html, cookieStrings);
      
      // 캡차 인증 시간 저장
      await CloudflareCaptcha.saveCaptchaVerifiedTime();
    } catch (e) {
      if (!mounted) return;
      _logger.e('[CAPTCHA] 캡차 상태 확인 실패', error: e);
      widget.onError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.clearCache();
    _controller.clearLocalStorage();
    super.dispose();
  }
}
