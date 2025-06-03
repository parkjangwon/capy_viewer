import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:html/parser.dart' as html_parser;

import '../../../data/providers/site_url_provider.dart';

import '../../../utils/manga_chapter_parser.dart';
import '../../../utils/manatoki_captcha_helper.dart';

import '../../../data/models/manga_chapter.dart';
import '../../../utils/network_image_with_headers.dart';

import '../../widgets/manatoki_captcha_widget.dart';

import '../../../core/logger.dart';

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
  WebViewController? _controller;
  List<String> _imageUrls = [];
  bool _isLoading = true;
  bool _showManatokiCaptcha = false;
  ManatokiCaptchaInfo? _captchaInfo;
  bool _showNavigationBar = false;
  Timer? _hideTimer;
  String? _prevChapterUrl;
  String? _nextChapterUrl;
  String? _listUrl;
  final _animationDuration = const Duration(milliseconds: 200);
  final PageController _pageController = PageController();
  List<MangaChapter> _chapters = [];
  MangaChapter? _currentChapter;
  bool _isLoadingChapters = false;
  String? _currentTitle;
  Timer? _loadingTimer;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _loadChapterList();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _loadingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initWebView() async {
    final cookieManager = WebViewCookieManager();
    await cookieManager.clearCookies();

    final baseUrl = ref.read(siteUrlServiceProvider);
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

    // URL 정규화
    String fullUrl;
    if (widget.chapterId.startsWith('http')) {
      fullUrl = widget.chapterId;
    } else if (widget.chapterId.startsWith('/comic/')) {
      fullUrl = '$baseUrl${widget.chapterId.substring(1)}';
    } else if (widget.chapterId.startsWith('comic/')) {
      fullUrl = '$baseUrl/${widget.chapterId}';
    } else {
      fullUrl = '$baseUrl/comic/${widget.chapterId}';
    }

    print('[뷰어] 로드할 URL: $fullUrl');
    await controller.loadRequest(Uri.parse(fullUrl));
  }

  Future<void> _getHtmlContent() async {
    _loadingTimer?.cancel();

    setState(() {
      _isLoading = true;
      _showError = false;
    });

    _loadingTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _imageUrls.isEmpty && !_showManatokiCaptcha) {
        setState(() {
          _showError = true;
        });
      }
    });

    try {
      print('[뷰어] HTML 콘텐츠 가져오기 시작');

      // 자바스크립트로 이미지 URL 배열 가져오기 시도
      try {
        final jsResult = await _controller!.runJavaScriptReturningResult('''
          function getImageUrls() {
            const urls = [];
            document.querySelectorAll('article[itemprop="articleBody"] img').forEach(img => {
              let url = null;
              
              // data- 속성에서 URL 찾기
              for (const attrName of Object.keys(img.dataset)) {
                const value = img.dataset[attrName];
                if (value && value.includes('://') && !value.includes('loading-image.gif') && !value.includes('/tokinbtoki/')) {
                  url = value;
                  break;
                }
              }
              
              // data-original 속성 확인
              if (!url) {
                const dataOriginal = img.getAttribute('data-original');
                if (dataOriginal && !dataOriginal.includes('loading-image.gif') && !dataOriginal.includes('/tokinbtoki/')) {
                  url = dataOriginal;
                }
              }
              
              // src 속성은 마지막 옵션으로 사용
              if (!url) {
                const src = img.getAttribute('src');
                if (src && !src.includes('loading-image.gif') && !src.includes('/tokinbtoki/')) {
                  url = src;
                }
              }
              
              if (url) {
                urls.push(url);
              }
            });
            return JSON.stringify(urls);
          }
          getImageUrls();
        ''');

        final List<dynamic> urls = jsResult != null
            ? List<dynamic>.from(json.decode(jsResult.toString()))
            : [];

        if (urls.isNotEmpty) {
          print('[뷰어] JavaScript에서 이미지 URL ${urls.length}개 찾음');

          // URL 정규화
          final baseUrl = ref.read(siteUrlServiceProvider);
          final normalizedUrls = urls.map((url) {
            if (url.toString().startsWith('http')) return url.toString();
            return url.toString().startsWith('/')
                ? baseUrl + url.toString()
                : '$baseUrl/$url';
          }).toList();

          setState(() {
            _imageUrls = normalizedUrls.cast<String>();
            _isLoading = false;
            _showError = false;
          });
          _loadingTimer?.cancel();
          return;
        }
      } catch (e) {
        print('[뷰어] JavaScript 이미지 URL 가져오기 실패: $e');
      }

      final html = await _controller!.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );

      if (!mounted) return;

      final htmlString = html.toString();
      print('[뷰어] HTML 길이: ${htmlString.length}');

      // HTML 파싱
      print('[뷰어] HTML 파싱 시작');
      final document = html_parser.parse(htmlString);

      // 제목 파싱
      final titleElement = document.querySelector('.page-header .pull-left h3');
      if (titleElement != null) {
        final currentTitle = titleElement.text.trim();
        if (currentTitle.isNotEmpty) {
          setState(() {
            _currentTitle = currentTitle;
          });
        }
      }

      // 네비게이션 링크 파싱 (최초 1회만)
      if (_prevChapterUrl == null) {
        final navDiv = document.querySelector('.toon-nav');
        if (navDiv != null) {
          // 이전화 링크
          final prevBtn = navDiv.querySelector('.btn_prev');
          if (prevBtn != null) {
            final href = prevBtn.attributes['href'];
            if (href != null && !href.contains('javascript:alert')) {
              _prevChapterUrl = href;
            }
          }

          // 목록 링크
          final listLink = navDiv.querySelector('a i.fa-list')?.parent;
          if (listLink != null) {
            _listUrl = listLink.attributes['href'];
            print('[뷰어] 목록 링크 찾음: $_listUrl');
          }

          // 다음화 링크
          final nextBtn = navDiv.querySelector('.btn_next');
          if (nextBtn != null) {
            final href = nextBtn.attributes['href'];
            if (href != null && !href.contains('javascript:alert')) {
              _nextChapterUrl = href;
            }
          }
        }
      }

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

      // 이미지 파싱
      final article = document.querySelector('article[itemprop="articleBody"]');
      if (article != null) {
        final images = article.querySelectorAll('img');
        print('[뷰어] 찾은 이미지 태그 개수: ${images.length}');

        final urls = <String>[];
        for (final img in images) {
          print('[뷰어] 이미지 태그 속성: ${img.attributes}');

          String? imageUrl;

          // data- 속성에서 URL 찾기
          for (final attr in img.attributes.entries) {
            if ((attr.key as String).startsWith('data-') &&
                attr.value.contains('://') &&
                !attr.value.contains('loading-image.gif') &&
                !attr.value.contains('/tokinbtoki/')) {
              imageUrl = attr.value;
              print('[뷰어] data- 속성에서 URL 찾음: $imageUrl');
              break;
            }
          }

          // data-original 속성 확인
          if (imageUrl == null) {
            final dataOriginal = img.attributes['data-original'];
            if (dataOriginal != null &&
                !dataOriginal.contains('loading-image.gif') &&
                !dataOriginal.contains('/tokinbtoki/')) {
              imageUrl = dataOriginal;
              print('[뷰어] data-original 속성에서 URL 찾음: $imageUrl');
            }
          }

          // src 속성 확인
          if (imageUrl == null) {
            final src = img.attributes['src'];
            if (src != null &&
                !src.contains('loading-image.gif') &&
                !src.contains('/tokinbtoki/')) {
              imageUrl = src;
              print('[뷰어] src 속성에서 URL 찾음: $imageUrl');
            }
          }

          if (imageUrl != null && imageUrl.isNotEmpty) {
            // 상대 경로를 절대 경로로 변환
            if (!imageUrl.startsWith('http')) {
              final baseUrl = ref.read(siteUrlServiceProvider);
              imageUrl = imageUrl.startsWith('/')
                  ? baseUrl + imageUrl
                  : '$baseUrl/$imageUrl';
            }
            urls.add(imageUrl);
          }
        }

        print('[뷰어] 최종 이미지 URL 개수: ${urls.length}');
        print('[뷰어] 이미지 URL 목록:');
        for (var i = 0; i < urls.length; i++) {
          print('[뷰어] ${i + 1}번째 이미지: ${urls[i]}');
        }

        if (urls.isNotEmpty) {
          setState(() {
            _imageUrls = urls;
            _isLoading = false;
          });
          print('[뷰어] 상태 업데이트 완료');
        } else {
          print('[뷰어] 이미지를 찾을 수 없음');
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        print('[뷰어] article 태그를 찾을 수 없음');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      print('[뷰어] HTML 파싱 중 오류 발생: $e\n$stack');
      setState(() {
        _isLoading = false;
        _showError = true;
      });
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

  // 네비게이션 바 토글
  void _toggleNavigationBar() {
    setState(() {
      _showNavigationBar = !_showNavigationBar;
    });

    // 이전 타이머 취소
    _hideTimer?.cancel();

    // 네비게이션 바가 보이는 경우에만 타이머 설정
    if (_showNavigationBar) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showNavigationBar = false;
          });
        }
      });
    }
  }

  Future<void> _loadChapterList() async {
    if (_isLoadingChapters) return;
    setState(() => _isLoadingChapters = true);

    try {
      final baseUrl = ref.read(siteUrlServiceProvider);
      final cookieJar = ref.read(globalCookieJarProvider);
      final cookies = await cookieJar.loadForRequest(Uri.parse(baseUrl));
      final cookieString =
          cookies.map((c) => '${c.name}=${c.value}').join('; ');

      // 현재 회차의 상위 URL로 이동하여 회차 목록을 가져옵니다
      final response = await _controller?.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );

      if (response != null) {
        final html = response.toString();
        final chapters =
            MangaChapterParser.parseChapterList(html, widget.chapterId);

        if (mounted) {
          setState(() {
            _chapters = chapters;
            _currentChapter = chapters.firstWhere(
              (chapter) => chapter.id == widget.chapterId,
              orElse: () => MangaChapter(
                id: widget.chapterId,
                title: widget.title,
                url: '/comic/${widget.chapterId}',
              ),
            );
          });
        }
      }
    } catch (e) {
      print('회차 목록 로딩 오류: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingChapters = false);
      }
    }
  }

  void _navigateToUrl(String? url) {
    if (url == null) return;

    final baseUrl = ref.read(siteUrlServiceProvider);
    String fullUrl;

    // URL 정규화
    if (url.startsWith('http')) {
      fullUrl = url;
    } else if (url.startsWith('/comic/')) {
      fullUrl = '$baseUrl${url.substring(1)}';
    } else if (url.startsWith('comic/')) {
      fullUrl = '$baseUrl/$url';
    } else {
      // 숫자만 있는 경우 (chapterId)
      if (RegExp(r'^\d+$').hasMatch(url)) {
        fullUrl = '$baseUrl/comic/$url';
      } else {
        fullUrl = '$baseUrl${url.startsWith('/') ? url : '/$url'}';
      }
    }

    // URL에서 chapterId 추출
    final idMatch = RegExp(r'/comic/(\d+)').firstMatch(fullUrl);
    final chapterId = idMatch?.group(1);

    if (chapterId != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MangaViewerScreen(
            chapterId: chapterId,
            title: widget.title,
          ),
        ),
      );
    }
  }

  void _showChapterList() {
    if (_listUrl == null) return;

    final baseUrl = ref.read(siteUrlServiceProvider);
    String fullUrl;

    // URL 정규화
    if (_listUrl!.startsWith('http')) {
      fullUrl = _listUrl!;
    } else if (_listUrl!.startsWith('/comic/')) {
      fullUrl = '$baseUrl${_listUrl!.substring(1)}';
    } else if (_listUrl!.startsWith('comic/')) {
      fullUrl = '$baseUrl/$_listUrl!';
    } else {
      fullUrl =
          '$baseUrl${_listUrl!.startsWith('/') ? _listUrl! : '/$_listUrl!'}';
    }

    // 목록 페이지로 이동
    Navigator.pop(context);
    Navigator.pushNamed(context, '/detail', arguments: {
      'url': fullUrl,
      'title': widget.title,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 메인 콘텐츠 영역
          if (_isLoading ||
              (_imageUrls.isEmpty && !_showManatokiCaptcha && !_showError))
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const Column(
                    children: [
                      Text(
                        '페이지를 가져오고 있습니다',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '잠시만 기다려주세요...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else if (_showManatokiCaptcha && _captchaInfo != null)
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
          else if (_imageUrls.isEmpty && !_showManatokiCaptcha && _showError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '이미지를 찾을 수 없습니다.',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('뒤로 가기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          else if (!_showManatokiCaptcha)
            SingleChildScrollView(
              child: Column(
                children: _imageUrls.map((url) {
                  return NetworkImageWithHeaders(
                    url: url,
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.width * 1.4,
                    fit: BoxFit.fitWidth,
                    errorWidget: const Center(
                      child: Text(
                        '이미지를 불러올 수 없습니다.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // 숨겨진 WebView
          if (_controller != null)
            Offstage(
              offstage: true,
              child: SizedBox(
                width: 0,
                height: 0,
                child: WebViewWidget(controller: _controller!),
              ),
            ),

          // 터치 감지 영역
          if (!_showManatokiCaptcha && !_isLoading)
            Positioned.fill(
              child: GestureDetector(
                onTapUp: (details) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final tapPosition = details.globalPosition.dx;

                  if (tapPosition < screenWidth / 3) {
                    if (_prevChapterUrl != null) {
                      _navigateToUrl(_prevChapterUrl);
                    }
                  } else if (tapPosition > (screenWidth * 2 / 3)) {
                    if (_nextChapterUrl != null) {
                      _navigateToUrl(_nextChapterUrl);
                    }
                  } else {
                    _toggleNavigationBar();
                  }
                },
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),

          // 네비게이션 바 (상단)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            top: _showNavigationBar && !_showManatokiCaptcha
                ? 0
                : -kToolbarHeight - MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withOpacity(0.7),
              child: SafeArea(
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: Text(
                    _currentTitle ?? widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),

          // 네비게이션 바 (하단)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            bottom: _showNavigationBar && !_showManatokiCaptcha
                ? 0
                : -kToolbarHeight - MediaQuery.of(context).padding.bottom,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withOpacity(0.7),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    color: Colors.white,
                    onPressed: _prevChapterUrl == null
                        ? null
                        : () => _navigateToUrl(_prevChapterUrl),
                    tooltip: '이전화',
                  ),
                  IconButton(
                    icon: const Icon(Icons.list),
                    color: Colors.white,
                    onPressed: _listUrl == null ? null : _showChapterList,
                    tooltip: '회차 목록',
                  ),
                  IconButton(
                    icon: const Icon(Icons.comment),
                    color: Colors.white,
                    onPressed: null,
                    tooltip: '댓글',
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    color: Colors.white,
                    onPressed: _nextChapterUrl == null
                        ? null
                        : () => _navigateToUrl(_nextChapterUrl),
                    tooltip: '다음화',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
