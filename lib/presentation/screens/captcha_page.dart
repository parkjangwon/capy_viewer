import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/global_cookie_jar_provider.dart';
import '../../utils/cloudflare_captcha.dart';

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
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasSeenChallenge = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    final cookieJar = ref.read(globalCookieJarProvider);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            setState(() => _isLoading = false);

            // HTML 내용 가져오기
            final html = await _controller.runJavaScriptReturningResult(
              'document.documentElement.outerHTML',
            );
            final htmlStr = html.toString().toLowerCase();

            // 클라우드플레어 캡차 또는 마나토키 캡차 확인
            final bool isCaptchaPage = htmlStr.contains('challenge-form') ||
                htmlStr.contains('cf-please-wait') ||
                htmlStr.contains('turnstile') ||
                htmlStr.contains('_cf_chl_opt') ||
                htmlStr.contains('캡챠 인증') ||
                htmlStr.contains('captcha.php') ||
                htmlStr.contains('fcaptcha');

            if (!_hasSeenChallenge && !isCaptchaPage) {
              // 캡차가 없으면 바로 HTML 반환하고 페이지 닫기
              widget.onHtmlReceived(html.toString());
              if (mounted) {
                Navigator.of(context).pop();
              }
            } else if (isCaptchaPage) {
              _hasSeenChallenge = true;
            } else if (_hasSeenChallenge && !isCaptchaPage) {
              // 캡차를 본 후에 캡차가 없어지면 인증 완료로 간주
              widget.onHtmlReceived(html.toString());
              if (mounted) {
                Navigator.of(context).pop();
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('캡차 인증'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
