import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'manatoki_captcha_helper.dart';
import '../../../data/providers/site_url_provider.dart';
import '../../screens/settings/settings_screen.dart';

class CaptchaPage extends ConsumerStatefulWidget {
  final String url;
  final Function(String) onHtmlReceived;

  const CaptchaPage({
    super.key,
    required this.url,
    required this.onHtmlReceived,
  });

  @override
  ConsumerState<CaptchaPage> createState() => _CaptchaPageState();
}

class _CaptchaPageState extends ConsumerState<CaptchaPage> {
  late InAppWebViewController _webViewController;
  bool _isLoading = true;

  Future<void> _handleManatokiCaptcha(String url) async {
    if (ManatokiCaptchaHelper.isManatokiCaptchaUrl(url)) {
      final wrId = ManatokiCaptchaHelper.extractWrId(url);
      final baseUrl = ref.read(siteUrlServiceProvider);
      final result = await ManatokiCaptchaHelper.showCaptchaDialog(
        context: context,
        captchaUrl: url,
        formActionUrl: '$baseUrl/bbs/captcha_check.php',
        redirectUrl: '$baseUrl/comic/$wrId',
      );

      if (result != null) {
        _webViewController.loadUrl(
          urlRequest: URLRequest(url: WebUri(result)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = ref.read(siteUrlServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('보안 검증'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _webViewController.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialOptions: InAppWebViewGroupOptions(
              crossPlatform: InAppWebViewOptions(
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: false,
                useOnLoadResource: true,
                javaScriptEnabled: true,
                userAgent:
                    'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
              ),
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStart: (controller, url) async {
              setState(() {
                _isLoading = true;
              });

              if (url != null) {
                await _handleManatokiCaptcha(url.toString());
              }
            },
            onLoadStop: (controller, url) async {
              setState(() {
                _isLoading = false;
              });

              if (url != null) {
                await _handleManatokiCaptcha(url.toString());
              }

              final html = await controller.evaluateJavascript(
                source: "document.documentElement.outerHTML",
              );

              if (html != null &&
                  !html.contains('cf-browser-verification') &&
                  !html.contains('cf-challenge') &&
                  !html.contains('_cf_chl_opt')) {
                widget.onHtmlReceived(html);
              }
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          // 캡챠 인증 필요 화면 (방패 아이콘이 표시될 때)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: () {
                  final targetUrl = baseUrl.endsWith('/')
                      ? '${baseUrl}comic/129241'
                      : '$baseUrl/comic/129241';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CaptchaWebViewPage(
                          url: targetUrl, onCookiesExtracted: (cookies) {}),
                    ),
                  );
                },
                child: const Text('캡차 인증하기'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
