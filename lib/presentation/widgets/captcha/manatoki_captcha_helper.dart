import 'package:flutter/material.dart';
import 'manatoki_captcha_dialog.dart';

class ManatokiCaptchaHelper {
  static Future<String?> showCaptchaDialog({
    required BuildContext context,
    required String captchaUrl,
    required String formActionUrl,
    required String redirectUrl,
  }) async {
    String? result;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ManatokiCaptchaDialog(
        captchaUrl: captchaUrl,
        formActionUrl: formActionUrl,
        redirectUrl: redirectUrl,
        onSuccess: (value) {
          result = value;
          Navigator.of(context).pop();
        },
      ),
    );

    return result;
  }

  static bool isManatokiCaptchaUrl(String url) {
    return url.contains('manatoki') && url.contains('captcha.php');
  }

  static String extractWrId(String url) {
    final uri = Uri.parse(url);
    final wrId = uri.queryParameters['wr_id'];
    return wrId ?? '';
  }
} 