import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:logger/logger.dart';

class CaptchaScreen extends StatefulWidget {
  final String url;

  const CaptchaScreen({
    super.key,
    required this.url,
  });

  @override
  State<CaptchaScreen> createState() => _CaptchaScreenState();
}

class _CaptchaScreenState extends State<CaptchaScreen> {
  final _logger = Logger();
  bool _isLoading = true;
  InAppWebViewController? _controller;
  bool _hasSeenChallenge = false;

  String get _targetUrl {
    final baseUrl = widget.url.endsWith('/') ? widget.url : '${widget.url}/';
    return '${baseUrl}comic/129241';
  }

  bool _isChallengeUrl(String url) {
    return url.contains('challenge') || 
           url.contains('cloudflare') ||
           url.contains('captcha') ||
           url.contains('cdn-cgi');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('보안 인증'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_targetUrl)),
            initialSettings: InAppWebViewSettings(
              userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
              javaScriptEnabled: true,
              clearCache: true,
            ),
            onLoadStart: (controller, url) {
              _controller = controller;
              setState(() => _isLoading = true);
              final currentUrl = url.toString();
              _logger.i('[CAPTCHA] 페이지 로드 시작: $currentUrl');

              if (_isChallengeUrl(currentUrl)) {
                _hasSeenChallenge = true;
                _logger.i('[CAPTCHA] 챌린지 페이지 감지');
              }
            },
            onLoadStop: (controller, url) async {
              setState(() => _isLoading = false);
              final currentUrl = url.toString();
              _logger.i('[CAPTCHA] 페이지 로드 완료: $currentUrl');

              // 챌린지를 만난 적이 있고, 현재 일반 페이지면 인증 완료로 처리
              if (_hasSeenChallenge && !_isChallengeUrl(currentUrl)) {
                _logger.i('[CAPTCHA] 인증 완료 감지');
                Navigator.of(context).pop(true); // true = 인증 성공
              }
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
