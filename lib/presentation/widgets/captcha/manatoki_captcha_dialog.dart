import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ManatokiCaptchaDialog extends StatefulWidget {
  final String captchaUrl;
  final String formActionUrl;
  final String redirectUrl;
  final Function(String) onSuccess;

  const ManatokiCaptchaDialog({
    super.key,
    required this.captchaUrl,
    required this.formActionUrl,
    required this.redirectUrl,
    required this.onSuccess,
  });

  @override
  State<ManatokiCaptchaDialog> createState() => _ManatokiCaptchaDialogState();
}

class _ManatokiCaptchaDialogState extends State<ManatokiCaptchaDialog> {
  late InAppWebViewController _webViewController;
  bool _isLoading = true;
  String _captchaKey = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              '캡차 인증',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(widget.captchaUrl)),
                    initialOptions: InAppWebViewGroupOptions(
                      crossPlatform: InAppWebViewOptions(
                        useShouldOverrideUrlLoading: true,
                        mediaPlaybackRequiresUserGesture: false,
                        useOnLoadResource: true,
                        javaScriptEnabled: true,
                      ),
                    ),
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                      
                      // 캡차 제출 핸들러 등록
                      controller.addJavaScriptHandler(
                        handlerName: 'submitCaptcha',
                        callback: (args) async {
                          if (args.isNotEmpty) {
                            _captchaKey = args[0] as String;
                            await _submitCaptcha();
                          }
                        },
                      );

                      // 캡차 새로고침 핸들러 등록
                      controller.addJavaScriptHandler(
                        handlerName: 'reloadCaptcha',
                        callback: (args) async {
                          await _reloadCaptcha();
                        },
                      );
                    },
                    onLoadStart: (controller, url) {
                      setState(() {
                        _isLoading = true;
                      });
                    },
                    onLoadStop: (controller, url) async {
                      setState(() {
                        _isLoading = false;
                      });

                      // 캡차 이미지 URL 추출
                      final imageUrl = await controller.evaluateJavascript(
                        source: "document.querySelector('.captcha_img').src",
                      );

                      // 새로고침 버튼 이벤트 리스너 추가
                      await controller.evaluateJavascript(
                        source: """
                          document.getElementById('captcha_reload').addEventListener('click', function() {
                            window.flutter_inappwebview.callHandler('reloadCaptcha');
                          });
                        """,
                      );

                      // 폼 제출 이벤트 리스너 추가
                      await controller.evaluateJavascript(
                        source: """
                          document.forms['fcaptcha'].addEventListener('submit', function(e) {
                            e.preventDefault();
                            const captchaKey = document.getElementById('captcha_key').value;
                            window.flutter_inappwebview.callHandler('submitCaptcha', captchaKey);
                          });
                        """,
                      );
                    },
                    onConsoleMessage: (controller, consoleMessage) {
                      debugPrint(consoleMessage.message);
                    },
                  ),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _reloadCaptcha,
                  child: const Text('새로고침'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _webViewController.evaluateJavascript(
                      source: "document.forms['fcaptcha'].submit();",
                    );
                  },
                  child: const Text('확인'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reloadCaptcha() async {
    await _webViewController.evaluateJavascript(
      source: "document.getElementById('captcha_reload').click();",
    );
  }

  Future<void> _submitCaptcha() async {
    try {
      final response = await _webViewController.evaluateJavascript(
        source: """
          fetch('${widget.formActionUrl}', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: new URLSearchParams({
              'url': '${widget.redirectUrl}',
              'captcha_key': '$_captchaKey'
            })
          })
          .then(response => response.text())
          .then(text => {
            try {
              return JSON.parse(text);
            } catch (e) {
              return text;
            }
          });
        """,
      );

      if (response != null) {
        // response가 JSON 문자열인 경우 파싱
        final Map<String, dynamic> jsonResponse = 
            response is String ? {} : response as Map<String, dynamic>;
        
        if (jsonResponse.containsKey('url')) {
          widget.onSuccess(jsonResponse['url'] as String);
        }
      }
    } catch (e) {
      debugPrint('캡차 제출 오류: $e');
    }
  }
} 