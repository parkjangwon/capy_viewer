import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:manga_view_flutter/utils/html_manga_parser.dart';
import 'package:url_launcher/url_launcher.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  String? _targetUrl;
  static const String _comicPath =
      '/comic?stx=%EB%B2%A0%EB%A5%B4%EC%84%B8%EB%A5%B4%ED%81%AC';

  @override
  void initState() {
    super.initState();
    _loadTargetUrl();
  }

  Future<void> _loadTargetUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl =
        prefs.getString('site_base_url') ?? 'https://manatoki468.net';
    setState(() {
      _targetUrl = baseUrl + _comicPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_targetUrl == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SafeArea(
      child: CloudflareBypassWidget(targetUrl: _targetUrl!),
    );
  }
}

class CloudflareBypassWidget extends StatefulWidget {
  final String targetUrl;
  const CloudflareBypassWidget({super.key, required this.targetUrl});

  @override
  State<CloudflareBypassWidget> createState() => _CloudflareBypassWidgetState();
}

class _CloudflareBypassWidgetState extends State<CloudflareBypassWidget> {
  late final WebViewController _webViewController;
  String? _htmlContent;
  bool _isFetchingHtml = false;
  List<SimpleMangaItem>? _parsedMangaList;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.targetUrl));
  }

  Future<void> _fetchHtmlFromWebView() async {
    setState(() {
      _parsedMangaList = null;
      _isFetchingHtml = true;
      _htmlContent = null;
    });
    try {
      final html = await _webViewController
          .runJavaScriptReturningResult('document.documentElement.outerHTML');
      setState(() {
        _htmlContent = html.toString();
        _parsedMangaList = parseMangaListFromHtml(_htmlContent!);
        _isFetchingHtml = false;
      });
    } catch (e) {
      setState(() {
        _htmlContent = 'HTML 추출 실패: $e';
        _isFetchingHtml = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('HTML 추출 실패: $e')),
      );
    }
  }

  void _navigateToCaptchaWebView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CaptchaWebViewPage(
          url: widget.targetUrl,
          onCookiesExtracted: (cookies) async {
            // 인증 후 별도 동작 없음 (쿠키 저장/동기화 제거)
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          ElevatedButton(
            onPressed: _navigateToCaptchaWebView,
            child: const Text('캡차 인증하기'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _fetchHtmlFromWebView(),
            child: const Text('HTML 가져오기(WebView)'),
          ),
          const SizedBox(height: 20),
          if (_isFetchingHtml)
            const CircularProgressIndicator()
          else if (_parsedMangaList != null)
            Expanded(
              child: ListView.builder(
                itemCount: _parsedMangaList!.length,
                itemBuilder: (context, idx) {
                  final item = _parsedMangaList![idx];
                  return ListTile(
                    title: Text(item.title),
                    onTap: () async {
                      final uri = Uri.parse(item.href);
                      if (await canLaunchUrl(uri)) {
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    subtitle: Text(item.href, style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            )
          else if (_htmlContent != null)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Text('HTML 내용:\n$_htmlContent'),
              ),
            )
          else
            const Text('HTML 내용은 여기에 표시됩니다.'),
        ],
      ),
    );
  }
}

class CaptchaWebViewPage extends StatefulWidget {
  final String url;
  final ValueChanged<String> onCookiesExtracted;
  const CaptchaWebViewPage(
      {super.key, required this.url, required this.onCookiesExtracted});

  @override
  State<CaptchaWebViewPage> createState() => _CaptchaWebViewPageState();
}

class _CaptchaWebViewPageState extends State<CaptchaWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) async {
            setState(() => _isLoading = false);
            final cookies = await _controller
                .runJavaScriptReturningResult('document.cookie');
            if (cookies.toString().isNotEmpty) {
              widget.onCookiesExtracted(cookies.toString());
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    // setBackgroundColor는 macOS가 아닐 때만 호출
    if (!Platform.isMacOS) {
      _controller.setBackgroundColor(Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('캡차 인증')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
