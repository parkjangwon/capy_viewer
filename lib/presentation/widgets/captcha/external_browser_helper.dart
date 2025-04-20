import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalBrowserCaptcha extends StatelessWidget {
  final String url;
  final VoidCallback? onReload;
  const ExternalBrowserCaptcha({super.key, required this.url, this.onReload});

  Future<void> _launchBrowser(BuildContext context) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('외부 브라우저를 실행할 수 없습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.open_in_browser, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Cloudflare 보안 정책으로 인해\n앱 내 인증이 불가능합니다.\n\n[외부 브라우저로 인증을 진행해 주세요]\n\n인증 후 앱으로 돌아와 새로고침을 눌러주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.black),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('브라우저로 열기'),
              onPressed: () => _launchBrowser(context),
              style: ElevatedButton.styleFrom(minimumSize: const Size(180, 48)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('앱에서 새로고침'),
              onPressed: onReload,
              style: ElevatedButton.styleFrom(minimumSize: const Size(180, 48)),
            ),
          ],
        ),
      ),
    );
  }
}

// 전역 함수: 외부 브라우저로 URL 열기
Future<void> launchUrlExternal(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    debugPrint('[EXTERNAL_BROWSER][ERROR] Could not launch: $url');
    throw 'Could not launch $url';
  }
}
