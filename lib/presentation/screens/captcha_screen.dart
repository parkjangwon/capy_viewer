import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../widgets/captcha/cloudflare_captcha.dart';

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
  late final InAppWebViewController _webViewController;
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('캡차 확인'),
      ),
      body: Stack(
        children: [
          CloudflareCaptchaWidget(
            url: widget.url,
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