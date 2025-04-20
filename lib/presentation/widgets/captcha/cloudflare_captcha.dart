import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:io'; // Cookie 타입 명확화
import '../../../core/typedefs.dart';

typedef OnCaptchaSolved = void Function(String html, List<Cookie> cookies);

class CloudflareCaptchaWidget extends StatefulWidget {
  final String url;
  final OnCaptchaSolved? onCaptchaSolved;
  const CloudflareCaptchaWidget({super.key, required this.url, this.onCaptchaSolved});
  @override
  State<CloudflareCaptchaWidget> createState() => _CloudflareCaptchaWidgetState();
}

class _CloudflareCaptchaWidgetState extends State<CloudflareCaptchaWidget> {
  bool _isLoading = true;
  String? _errorMsg;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
              userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
              javaScriptEnabled: true,
              useOnDownloadStart: true,
              clearCache: true,
              sharedCookiesEnabled: true,
              allowsInlineMediaPlayback: true,
              allowsBackForwardNavigationGestures: true,
              allowsLinkPreview: true,
              mediaPlaybackRequiresUserGesture: false,
              isFraudulentWebsiteWarningEnabled: false,
              suppressesIncrementalRendering: false,
            ),
            onLoadStart: (controller, url) {
              debugPrint('[CAPTCHA][LOAD_START] url: "+${url?.toString() ?? 'null'}"');
              setState(() {
                _isLoading = true;
                _errorMsg = null;
              });
            },
            onLoadStop: (controller, url) async {
              setState(() => _isLoading = false);
              if (url != null) {
                debugPrint('[CAPTCHA][LOAD_STOP] url: ${url.toString()}');
                try {
                  final html = await controller.evaluateJavascript(source: "document.documentElement.outerHTML");
                  final cookies = await CookieManager.instance().getCookies(url: url);
                  debugPrint('[CAPTCHA][LOAD_STOP] HTML length: "+${html?.length ?? 0}", cookies: ${cookies.map((c) => c.name + '=' + c.value).join('; ')}');
                  if (html != null && html.isNotEmpty && !html.contains('cf-browser-verification') && !html.contains('cf-challenge') && !html.contains('_cf_chl_opt')) {
                    if (widget.onCaptchaSolved != null) {
                      widget.onCaptchaSolved!(html, cookies);
                    }
                    if (mounted) Navigator.of(context).pop();
                  }
                } catch (e) {
                  debugPrint('[CAPTCHA][EXTRACT ERROR] $e');
                  setState(() => _errorMsg = '[CAPTCHA][EXTRACT ERROR] $e');
                }
              }
            },
            onLoadError: (controller, url, code, message) {
              debugPrint('[CAPTCHA][ERROR] onLoadError: $url, code: $code, message: $message');
              setState(() {
                _isLoading = false;
                _errorMsg = '[onLoadError] code: $code, message: $message';
              });
            },
            onReceivedError: (controller, request, error) async {
              final cookies = await CookieManager.instance().getCookies(url: request.url);
              debugPrint('[CAPTCHA][ERROR] onReceivedError: $request, error: $error, cookies: ${cookies.map((c) => c.name + '=' + c.value).join('; ')}');
              setState(() {
                _isLoading = false;
                _errorMsg = '[onReceivedError] $error';
              });
            },
            onReceivedHttpError: (controller, request, response) {
              debugPrint('[CAPTCHA][HTTP ERROR] $request, statusCode: ${response.statusCode}');
            },
          ),
      ],
    );
  }
}