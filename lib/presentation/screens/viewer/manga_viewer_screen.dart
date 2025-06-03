import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:cookie_jar/cookie_jar.dart';
import '../../../data/models/manga_viewer_state.dart';
import '../../../data/providers/site_url_provider.dart';
import '../../../data/providers/cookie_store_provider.dart';
import '../../../utils/manga_detail_parser.dart';
import '../../../utils/manatoki_captcha_helper.dart';
import '../../../data/models/manga_page.dart';
import '../../../utils/network_image_with_headers.dart';
import '../../viewmodels/manga_viewer_view_model.dart';
import '../../widgets/manatoki_captcha_widget.dart';
import '../../widgets/captcha/unified_captcha_handler.dart';
import '../../../core/logger.dart';
import '../manga/manga_captcha_screen.dart';
import '../../../test_manga_parser.dart';
import '../../viewmodels/global_cookie_provider.dart';

/// 만화 뷰어 화면
/// 만화 페이지를 표시하고 캡차 처리를 담당합니다.
class MangaViewerScreen extends ConsumerStatefulWidget {
  final String chapterId;
  final String title;

  const MangaViewerScreen({
    Key? key,
    required this.chapterId,
    required this.title,
  }) : super(key: key);

  @override
  ConsumerState<MangaViewerScreen> createState() => _MangaViewerScreenState();
}

class _MangaViewerScreenState extends ConsumerState<MangaViewerScreen> {
  final Logger _logger = Logger();
  WebViewController? _controller; // nullable로 변경
  List<String> _imageUrls = [];
  bool _isLoading = true;
  bool _showManatokiCaptcha = false;
  ManatokiCaptchaInfo? _captchaInfo;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    final cookieManager = WebViewCookieManager();
    await cookieManager.clearCookies();

    final baseUrl = 'https://manatoki468.net';
    final cookieJar = ref.read(globalCookieJarProvider);
    final cookies = await cookieJar.loadForRequest(Uri.parse(baseUrl));

    for (final cookie in cookies) {
      await cookieManager.setCookie(
        WebViewCookie(
          name: cookie.name,
          value: cookie.value,
          domain: Uri.parse(baseUrl).host,
        ),
      );
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _getHtmlContent(),
      ))
      ..enableZoom(false);

    // 컨트롤러 설정이 완료된 후에 setState
    setState(() {
      _controller = controller;
    });

    // URL 로드는 컨트롤러 설정 후에 수행
    await controller.loadRequest(
        Uri.parse('https://manatoki468.net/comic/${widget.chapterId}'));
  }

  Future<void> _getHtmlContent() async {
    try {
      print('[뷰어] HTML 콘텐츠 가져오기 시작');
      final html = await _controller!.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );

      if (!mounted) return;

      final htmlString = html.toString();
      print('[뷰어] HTML 길이: ${htmlString.length}');

      // 마나토끼 캡차 확인
      if (ManatokiCaptchaHelper.isCaptchaRequired(htmlString)) {
        print('[뷰어] 마나토끼 캡차 감지됨');

        // 캡차 정보 추출
        final baseUrl = ref.read(siteUrlServiceProvider);
        final captchaInfo =
            ManatokiCaptchaHelper.extractCaptchaInfo(htmlString, baseUrl);

        if (captchaInfo != null) {
          setState(() {
            _showManatokiCaptcha = true;
            _captchaInfo = captchaInfo;
            _isLoading = false;
          });
          return;
        }
      }

      // HTML 파싱
      print('[뷰어] HTML 파싱 시작');
      final document = html_parser.parse(htmlString);
      List<dom.Element> foundImages = [];

      // 1. article 태그를 찾습니다
      final article = document.querySelector('article[itemprop="articleBody"]');
      print('[뷰어] article 태그 찾음: ${article != null}');

      if (article != null) {
        // 2. article 내의 모든 img 태그를 순서대로 찾습니다
        final images = article.querySelectorAll('img');
        print('[뷰어] 이미지 태그 개수: ${images.length}');
        foundImages = images.toList();
      }

      // 3. 이미지 URL 추출 및 필터링
      final urls = foundImages
          .map((img) {
            // data- 속성 확인
            final dataUrl = img.attributes.entries
                .where((attr) =>
                    (attr.key as String).startsWith('data-') &&
                    attr.value.contains('://'))
                .map((attr) => attr.value)
                .firstOrNull;

            // src 속성 확인
            final src = dataUrl ?? img.attributes['src'] ?? '';
            if (src.isNotEmpty && !src.contains('/tokinbtoki/')) {
              print('[뷰어] 이미지 URL 발견: $src');
              return src;
            }
            return '';
          })
          .where((url) => url.isNotEmpty)
          .toList();

      print('[뷰어] 필터링된 이미지 URL 개수: ${urls.length}');

      if (urls.isNotEmpty) {
        setState(() {
          _imageUrls = urls;
          _isLoading = false;
        });
        print('[뷰어] 상태 업데이트 완료');
      } else {
        print('[뷰어] 이미지를 찾을 수 없음');
      }
    } catch (e, stack) {
      print('[뷰어] HTML 파싱 중 오류 발생: $e\n$stack');
    }
  }

  void _onCaptchaVerified() async {
    setState(() {
      _showManatokiCaptcha = false;
      _isLoading = true;
    });

    try {
      final cookieManager = WebViewCookieManager();
      final baseUrl = 'https://manatoki468.net';
      final cookieJar = ref.read(globalCookieJarProvider);
      final cookies = await cookieJar.loadForRequest(Uri.parse(baseUrl));

      // 기존 쿠키 제거
      await cookieManager.clearCookies();

      // 새로운 쿠키 설정
      for (final cookie in cookies) {
        await cookieManager.setCookie(
          WebViewCookie(
            name: cookie.name,
            value: cookie.value,
            domain: Uri.parse(baseUrl).host,
          ),
        );
      }

      // 웹뷰 컨트롤러 재초기화
      await _initWebView();
    } catch (e) {
      print('쿠키 동기화 오류: $e');
      if (_controller != null) {
        await _controller!.reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _imageUrls = [];
              });
              _controller?.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 숨겨진 WebView
          if (_controller != null) // null 체크 추가
            Offstage(
              offstage: true,
              child: SizedBox(
                width: 0,
                height: 0,
                child: WebViewWidget(controller: _controller!),
              ),
            ),

          // 메인 콘텐츠
          if (_showManatokiCaptcha && _captchaInfo != null)
            ManatokiCaptchaWidget(
              captchaInfo: _captchaInfo!,
              onCaptchaComplete: (success) {
                if (success) {
                  _onCaptchaVerified();
                } else {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
            )
          else if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_imageUrls.isEmpty)
            const Center(child: Text('이미지를 찾을 수 없습니다.'))
          else
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.horizontal,
              itemCount: _imageUrls.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 3.0,
                  child: NetworkImageWithHeaders(
                    url: _imageUrls[index],
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    fit: BoxFit.contain,
                    errorWidget: const Center(
                      child: Text('이미지를 불러올 수 없습니다.'),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
