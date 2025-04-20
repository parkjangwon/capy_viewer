import 'package:flutter/material.dart';
import 'dart:io';
import '../widgets/captcha/cloudflare_captcha.dart';

class CaptchaScreen extends StatelessWidget {
  final String url;

  const CaptchaScreen({
    super.key,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CloudflareCaptchaWidget(
        url: url,
        onCaptchaSolved: (String html, List<Cookie> cookies) {
          Navigator.of(context).pop({'html': html, 'cookies': cookies});
        },
      ),
    );
  }
}