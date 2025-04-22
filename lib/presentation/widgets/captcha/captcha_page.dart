import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'manatoki_captcha_helper.dart';

class CaptchaPage extends StatefulWidget {
  final String url;
  final Function(String) onHtmlReceived;

  const CaptchaPage({
    super.key,
    required this.url,
    required this.onHtmlReceived,
  });

  @override
  State<CaptchaPage> createState() => _CaptchaPageState();
}

class _CaptchaPageState extends State<CaptchaPage> {
  late InAppWebViewController _webViewController;
  bool _isLoading = true;

  Future<void> _handleManatokiCaptcha(String url) async {
    if (ManatokiCaptchaHelper.isManatokiCaptchaUrl(url)) {
      final wrId = ManatokiCaptchaHelper.extractWrId(url);
      final result = await ManatokiCaptchaHelper.showCaptchaDialog(
        context: context,
        captchaUrl: url,
        formActionUrl: 'https://manatoki468.net/bbs/captcha_check.php',
        redirectUrl: 'https://manatoki468.net/comic/$wrId',
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
                userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
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
        ],
      ),
    );
  }
} 