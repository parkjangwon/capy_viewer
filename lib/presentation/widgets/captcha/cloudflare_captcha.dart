import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class CloudflareCaptchaWidget extends StatelessWidget {
  final String url;
  final Function(String) onCaptchaSolved;

  const CloudflareCaptchaWidget({
    super.key,
    required this.url,
    required this.onCaptchaSolved,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 CAPTCHA'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        onLoadStop: (controller, url) {
          if (url != null) {
            if (url.toString().contains('cdn-cgi/') && url.toString().contains('challenges')) {
              onCaptchaSolved(url.toString());
            } else if (!url.toString().contains('cdn-cgi/') && !url.toString().contains('challenges')) {
              // CAPTCHA가 해결되었을 때
              Navigator.of(context).pop();
            }
          }
        },
      ),
    );
  }
} 