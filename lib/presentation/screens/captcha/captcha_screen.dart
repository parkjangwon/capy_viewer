import 'package:flutter/material.dart';
import '../../widgets/captcha/cloudflare_captcha.dart';
import '../../../core/logger.dart';

class CaptchaScreen extends StatefulWidget {
  final String url;
  static final _logger = Logger();

  const CaptchaScreen({
    super.key,
    required this.url,
  });

  @override
  State<CaptchaScreen> createState() => _CaptchaScreenState();
}

class _CaptchaScreenState extends State<CaptchaScreen> {
  final bool _isLoading = true;
  final _logger = Logger();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CAPTCHA 인증'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: CloudflareCaptcha(
        url: widget.url,
        onVerified: (html, cookies) {
          if (!mounted) return;
          _logger.i('[CAPTCHA] 인증 완료');
          Navigator.of(context).pop({
            'html': html,
            'cookies': cookies,
          });
        },
        onError: (error) {
          if (!mounted) return;
          _logger.e('[CAPTCHA] 인증 실패', error: error);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
