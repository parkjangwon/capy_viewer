import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/site_url_provider.dart';
import '../../viewmodels/global_cookie_provider.dart';
import '../../viewmodels/cookie_sync_utils.dart';

/// 만화 상세 페이지 캡차 인증 화면
class MangaCaptchaScreen extends ConsumerStatefulWidget {
  final String url;

  const MangaCaptchaScreen({
    Key? key,
    required this.url,
  }) : super(key: key);

  @override
  ConsumerState<MangaCaptchaScreen> createState() => _MangaCaptchaScreenState();
}

class _MangaCaptchaScreenState extends ConsumerState<MangaCaptchaScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _mounted = true;
  bool _hasSeenChallenge = false;
  String _lastHtml = '';
  int _blankCount = 0;
  bool _captchaVerified = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!_mounted) return;
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) async {
            if (!_mounted) return;
            setState(() => _isLoading = false);

            // about:blank 페이지는 캡차 인증 과정에서 여러 번 발생할 수 있음
            if (url.startsWith('about:')) {
              if (url == 'about:blank') {
                _blankCount++;
                if (_blankCount >= 3) {
                  // 여러 번의 about:blank 후에 인증이 완료된 것으로 간주
                  _captchaVerified = true;
                  if (_mounted) {
                    // 쿠키 동기화 후 결과 반환
                    await _syncCookies();
                    Navigator.of(context).pop(true);
                  }
                }
              }
              return;
            }

            final html = await _controller.runJavaScriptReturningResult('document.documentElement.outerHTML');
            final htmlStr = html.toString().toLowerCase();

            // HTML 내용이 변경되었는지 확인
            if (htmlStr != _lastHtml) {
              _lastHtml = htmlStr;
              
              // 첫 페이지 로드에서 챌린지를 보았는지 확인
              if (!_hasSeenChallenge) {
                if (htmlStr.contains('challenge-form') || 
                    htmlStr.contains('cf-please-wait') ||
                    htmlStr.contains('turnstile') ||
                    htmlStr.contains('_cf_chl_opt')) {
                  _hasSeenChallenge = true;
                } else {
                  // 챌린지가 없으면 바로 종료
                  _captchaVerified = true;
                  if (_mounted) {
                    // 쿠키 동기화 후 결과 반환
                    await _syncCookies();
                    Navigator.of(context).pop(true);
                  }
                }
              } else {
                // 챌린지를 본 후에 챌린지 요소가 없으면 인증 완료
                if (!htmlStr.contains('challenge-form') && 
                    !htmlStr.contains('cf-please-wait') &&
                    !htmlStr.contains('turnstile') &&
                    !htmlStr.contains('_cf_chl_opt')) {
                  _captchaVerified = true;
                  if (_mounted) {
                    // 쿠키 동기화 후 결과 반환
                    await _syncCookies();
                    Navigator.of(context).pop(true);
                  }
                }
              }
            }
          },
          onNavigationRequest: (request) {
            // 모든 네비게이션 허용
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _syncCookies() async {
    // WebView 쿠키를 Dio 쿠키 저장소에 동기화
    final jar = ref.read(globalCookieJarProvider);
    final url = ref.read(siteUrlServiceProvider);
    await syncWebViewCookiesToDio(url, jar);
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 뒤로 가기 시 캡차 인증 결과 반환
        Navigator.of(context).pop(_captchaVerified);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('보안 인증'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.of(context).pop(_captchaVerified);
            },
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading) 
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('클라우드플레어 보안 인증 중...', 
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text('인증이 완료되면 자동으로 진행됩니다',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
