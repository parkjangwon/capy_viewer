import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:logger/logger.dart';

class CaptchaModal extends StatefulWidget {
  final String url;
  final Function() onCaptchaVerified;

  const CaptchaModal({
    super.key,
    required this.url,
    required this.onCaptchaVerified,
  });

  @override
  State<CaptchaModal> createState() => _CaptchaModalState();
}

class _CaptchaModalState extends State<CaptchaModal> {
  final _logger = Logger();
  bool _isLoading = true;
  InAppWebViewController? _controller;
  bool _hasSeenChallenge = false;
  String? _initialUrl;

  bool _isChallengeUrl(String url) {
    return url.contains('challenge') || 
           url.contains('cloudflare') ||
           url.contains('captcha') ||
           url.contains('cdn-cgi');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        height: 500,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '보안 인증',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(widget.url)),
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

                      // 초기 URL 저장
                      _initialUrl ??= currentUrl;

                      // 챌린지 URL을 만나면 플래그 설정
                      if (_isChallengeUrl(currentUrl)) {
                        _hasSeenChallenge = true;
                        _logger.i('[CAPTCHA] 챌린지 페이지 감지');
                      }
                    },
                    onLoadStop: (controller, url) async {
                      setState(() => _isLoading = false);
                      final currentUrl = url.toString();
                      _logger.i('[CAPTCHA] 페이지 로드 완료: $currentUrl');

                      // 챌린지를 만난 적이 있고, 현재 URL이 초기 URL과 같거나 챌린지가 아닌 경우
                      if (_hasSeenChallenge && 
                          !_isChallengeUrl(currentUrl) &&
                          (currentUrl == _initialUrl || currentUrl.startsWith(widget.url))) {
                        _logger.i('[CAPTCHA] 인증 완료 감지');
                        widget.onCaptchaVerified();
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 