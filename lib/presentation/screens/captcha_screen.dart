import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

class CaptchaScreen extends StatefulWidget {
  final String url;
  final Function() onCaptchaVerified;
  final SharedPreferences preferences;

  const CaptchaScreen({
    Key? key,
    required this.url,
    required this.onCaptchaVerified,
    required this.preferences,
  }) : super(key: key);

  @override
  State<CaptchaScreen> createState() => _CaptchaScreenState();
}

class _CaptchaScreenState extends State<CaptchaScreen> {
  final _logger = Logger();
  bool _isLoading = true;
  bool _isCaptchaVerified = false;
  DateTime? _lastCaptchaTime;
  String? _lastUrl;
  bool _mounted = true;
  InAppWebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _checkLastCaptchaTime();
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  void _checkLastCaptchaTime() {
    final lastTime = widget.preferences.getInt('lastCaptchaTime');
    if (lastTime != null) {
      _lastCaptchaTime = DateTime.fromMillisecondsSinceEpoch(lastTime);
      final now = DateTime.now();
      if (_lastCaptchaTime != null &&
          now.difference(_lastCaptchaTime!).inHours < 1) {
        _isCaptchaVerified = true;
        widget.onCaptchaVerified();
      }
    }
  }

  void _saveCaptchaTime() {
    final now = DateTime.now();
    widget.preferences.setInt('lastCaptchaTime', now.millisecondsSinceEpoch);
    _lastCaptchaTime = now;
  }

  void _updateLoadingState(bool isLoading) {
    if (_mounted) {
      setState(() {
        _isLoading = isLoading;
      });
    }
  }

  void _injectHelperScript() async {
    if (_webViewController == null) return;

    await Future.delayed(const Duration(seconds: 1));

    // CloudFlare 캡차 자동 해결 시도를 위한 스크립트
    await _webViewController!.evaluateJavascript(source: '''
      // 자동 체크박스 클릭 시도
      function clickCaptchaCheckbox() {
        const checkboxes = document.querySelectorAll('input[type="checkbox"]');
        for (let i = 0; i < checkboxes.length; i++) {
          checkboxes[i].click();
        }
        
        // iframe 내부 체크박스 처리
        const iframes = document.querySelectorAll('iframe');
        for (let i = 0; i < iframes.length; i++) {
          try {
            const iframeDoc = iframes[i].contentDocument || iframes[i].contentWindow.document;
            const iframeCheckboxes = iframeDoc.querySelectorAll('input[type="checkbox"]');
            for (let j = 0; j < iframeCheckboxes.length; j++) {
              iframeCheckboxes[j].click();
            }
          } catch (e) {
            console.error('Error accessing iframe content:', e);
          }
        }
      }
      
      // 자동 버튼 클릭 시도
      function clickVerifyButton() {
        const buttons = document.querySelectorAll('button');
        for (let i = 0; i < buttons.length; i++) {
          if (buttons[i].textContent.toLowerCase().includes('verify') || 
              buttons[i].textContent.toLowerCase().includes('확인') ||
              buttons[i].id.includes('submit')) {
            buttons[i].click();
          }
        }
      }
      
      // 수행
      setTimeout(function() {
        clickCaptchaCheckbox();
        setTimeout(clickVerifyButton, 1000);
      }, 1500);
    ''');
  }

  @override
  Widget build(BuildContext context) {
    if (_isCaptchaVerified) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('캡차 인증'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _webViewController?.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(widget.url),
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
              },
            ),
            initialOptions: InAppWebViewGroupOptions(
              crossPlatform: InAppWebViewOptions(
                useShouldOverrideUrlLoading: true,
                useOnLoadResource: true,
                javaScriptEnabled: true,
                userAgent:
                    'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
              ),
              ios: IOSInAppWebViewOptions(
                allowsInlineMediaPlayback: true,
                allowsBackForwardNavigationGestures: false,
              ),
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStart: (controller, url) {
              final urlStr = url?.toString() ?? '';
              _logger.d('[CAPTCHA] 페이지 로드 시작: $urlStr');
              _updateLoadingState(true);
            },
            onLoadStop: (controller, url) {
              final urlStr = url?.toString() ?? '';
              _logger.d('[CAPTCHA] 페이지 로드 완료: $urlStr');
              _updateLoadingState(false);
              _injectHelperScript();
            },
            onReceivedError: (controller, request, error) {
              _logger.e('[CAPTCHA] 에러: ${error.description}');
              _updateLoadingState(false);
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url?.toString() ?? '';
              _logger.d('[CAPTCHA] URL 변경: $url');

              // about:blank 또는 about:srcdoc로의 리다이렉션은 무시
              if (url.startsWith('about:')) {
                return NavigationActionPolicy.CANCEL;
              }

              // 이전 URL과 동일한 경우 리다이렉션 방지
              if (url == _lastUrl) {
                return NavigationActionPolicy.CANCEL;
              }

              // 캡차 인증 성공 후 리다이렉션 처리
              if (url.contains('manatoki') &&
                  !url.contains('challenges.cloudflare.com') &&
                  _lastUrl?.contains('challenges.cloudflare.com') == true) {
                if (_mounted) {
                  _isCaptchaVerified = true;
                  _saveCaptchaTime();
                  widget.onCaptchaVerified();
                }
                return NavigationActionPolicy.CANCEL;
              }

              _lastUrl = url;
              return NavigationActionPolicy.ALLOW;
            },
            onConsoleMessage: (controller, consoleMessage) {
              _logger.d('[CAPTCHA] 콘솔: ${consoleMessage.message}');
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
