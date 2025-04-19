import 'package:flutter/material.dart';
import '../widgets/captcha/cloudflare_captcha.dart';

class CaptchaScreen extends StatelessWidget {
  final String url;
  final Function(String) onHtmlReceived;

  const CaptchaScreen({
    super.key,
    required this.url,
    required this.onHtmlReceived,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CloudflareCaptchaWidget(
        url: url,
        onCaptchaSolved: (html) {
          onHtmlReceived(html);
          Navigator.of(context).pop(html);
        },
      ),
    );
  }
} 