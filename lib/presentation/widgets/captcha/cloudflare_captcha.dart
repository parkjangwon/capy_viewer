import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../../../core/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef OnVerifiedCallback = void Function(String html, List<String> cookies);
typedef OnErrorCallback = void Function(dynamic error);

class CloudflareCaptcha extends StatefulWidget {
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
      await prefs.setInt(_captchaVerifiedKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // 저장 실패는 무시
    }
  }

  @override
  State<CloudflareCaptcha> createState() => _CloudflareCaptchaState();
}

class _CloudflareCaptchaState extends State<CloudflareCaptcha> {
  late final WebViewController _controller;
  bool _isLoading = true;
  final _logger = Logger();

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (!mounted) return;
            setState(() => _isLoading = true);
            _logger.i('[CAPTCHA] 페이지 로드 시작: $url');
          },
          onPageFinished: (String url) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            _logger.i('[CAPTCHA] 페이지 로드 완료: $url');
            
            if (url.startsWith('blob:') || url.contains('challenges.cloudflare.com')) {
              _checkCaptchaStatus();
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            _logger.i('[CAPTCHA] 네비게이션 요청: ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (_controller.platform as AndroidWebViewController)
        ..setMediaPlaybackRequiresUserGesture(false);
    }
  }

  Future<void> _checkCaptchaStatus() async {
    try {
      final result = await _controller.runJavaScriptReturningResult('''
        document.documentElement.outerHTML;
      ''');

      if (result != null && result.toString().contains('cf-browser-verification')) {
        _logger.i('[CAPTCHA] 캡차 검증 중...');
        return;
      }

      final cookies = await _controller.runJavaScriptReturningResult('''
        document.cookie;
      ''');

      if (!mounted) return;
      
      widget.onVerified(
        result.toString(),
        cookies.toString().split(';').map((c) => c.trim()).toList(),
      );
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
}