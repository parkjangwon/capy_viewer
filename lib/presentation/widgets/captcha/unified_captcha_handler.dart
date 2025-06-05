import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logger.dart';

class UnifiedCaptchaHandler extends ConsumerStatefulWidget {
  final String url;
  final Function(bool) onCaptchaVerified;

  const UnifiedCaptchaHandler({
    super.key,
    required this.url,
    required this.onCaptchaVerified,
  });

  @override
  ConsumerState<UnifiedCaptchaHandler> createState() =>
      _UnifiedCaptchaHandlerState();
}

class _UnifiedCaptchaHandlerState extends ConsumerState<UnifiedCaptchaHandler> {
  final Logger _logger = Logger();
  InAppWebViewController? _controller;
  bool _isLoading = true;
  bool _hasSeenChallenge = false;
  String? _initialUrl;

  bool _isChallengeUrl(String url) {
    return url.contains('challenges.cloudflare.com') ||
        url.contains('captcha.php') ||
        url.contains('captcha_check.php');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.url)),
          initialSettings: InAppWebViewSettings(
            userAgent:
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
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

            // HTML 내용 확인
            final html = await controller.evaluateJavascript(
              source: 'document.documentElement.outerHTML',
            );
            final htmlStr = html.toString().toLowerCase();

            // 캡차가 더 이상 필요하지 않은 경우
            if (_hasSeenChallenge && !_isChallengeUrl(currentUrl)) {
              if (!htmlStr.contains('캡챠 인증') &&
                  !htmlStr.contains('challenge-form') &&
                  !htmlStr.contains('cf-please-wait') &&
                  !htmlStr.contains('turnstile')) {
                _logger.i('[CAPTCHA] 캡차 인증 완료');
                widget.onCaptchaVerified(true);
                return;
              }
            }

            // 캡차 자동 처리 시도
            if (_isChallengeUrl(currentUrl)) {
              await _attemptAutoCaptcha(controller);
            }
          },
          onConsoleMessage: (controller, consoleMessage) {
            _logger.d('[CAPTCHA] Console: ${consoleMessage.message}');
          },
        ),
        if (_isLoading)
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  '보안 인증 중...',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  '인증이 완료되면 자동으로 진행됩니다',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _attemptAutoCaptcha(InAppWebViewController controller) async {
    try {
      // 체크박스 클릭 시도
      await controller.evaluateJavascript(source: '''
        (function() {
          var checkboxes = document.querySelectorAll('input[type="checkbox"]');
          checkboxes.forEach(function(checkbox) {
            checkbox.click();
            checkbox.checked = true;
          });
          
          var recaptchaElements = document.querySelectorAll('.recaptcha-checkbox, .recaptcha-checkbox-border');
          recaptchaElements.forEach(function(element) {
            element.click();
          });
        })();
      ''');

      // 폼 제출 시도
      await controller.evaluateJavascript(source: '''
        (function() {
          var forms = document.querySelectorAll('form');
          if (forms.length > 0) {
            forms[0].submit();
          }
        })();
      ''');
    } catch (e) {
      _logger.e('[CAPTCHA] 자동 캡차 처리 실패: $e');
    }
  }
}
