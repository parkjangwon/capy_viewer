import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../data/providers/site_url_provider.dart';
import '../../../utils/manatoki_captcha_helper.dart';
import '../../../utils/network_image_with_headers.dart';
import '../../widgets/manatoki_captcha_widget.dart';
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
  WebViewController? _controller;
  List<String> _imageUrls = [];
  bool _isLoading = true;
  bool _showManatokiCaptcha = false;
  ManatokiCaptchaInfo? _captchaInfo;
  bool _showNavigationBar = false;
  Timer? _hideTimer;
  String? _prevChapterUrl;
  String? _nextChapterUrl;
  Timer? _loadingTimer;
  bool _showError = false;
  final ScrollController _scrollController = ScrollController();
  bool _isOverscrolling = false;
  double _overscrollStart = 0;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _setupScrollController();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _loadingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollController() {
    _scrollController.addListener(() {
      // 현재 스크롤 위치 로깅
      print('[스크롤] 현재 위치: ${_scrollController.position.pixels}');
      print('[스크롤] 최대 위치: ${_scrollController.position.maxScrollExtent}');
      print('[스크롤] 최소 위치: ${_scrollController.position.minScrollExtent}');

      if (_scrollController.position.outOfRange) {
        print('[스크롤] 범위 초과 감지');

        if (!_isOverscrolling) {
          final overscroll = _scrollController.position.pixels -
              (_scrollController.position.pixels < 0
                  ? _scrollController.position.minScrollExtent
                  : _scrollController.position.maxScrollExtent);

          print('[스크롤] 오버스크롤 거리: $overscroll');

          if (overscroll.abs() > 50) {
            // 50픽셀 이상 오버스크롤하면 시작
            print('[스크롤] 오버스크롤 시작');
            setState(() {
              _isOverscrolling = true;
              _overscrollStart = _scrollController.position.pixels;
            });
          }
        } else {
          final overscrollDistance =
              (_scrollController.position.pixels - _overscrollStart).abs();
          print('[스크롤] 현재 당긴 거리: $overscrollDistance');

          if (overscrollDistance > 150) {
            // 150픽셀 이상 당기면 페이지 전환
            print('[스크롤] 페이지 전환 시도');
            _isOverscrolling = false;

            if (_scrollController.position.pixels <
                _scrollController.position.minScrollExtent) {
              print('[스크롤] 이전화로 이동');
              if (_prevChapterUrl != null) {
                _navigateToUrl(_prevChapterUrl);
              }
            } else {
              print('[스크롤] 다음화로 이동');
              if (_nextChapterUrl != null) {
                _navigateToUrl(_nextChapterUrl);
              }
            }
          }
        }
      } else {
        if (_isOverscrolling) {
          print('[스크롤] 오버스크롤 상태 초기화');
          setState(() {
            _isOverscrolling = false;
          });
        }
      }
    });
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

      final html = await _controller!.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );

      if (!mounted) return;

      final htmlString = html.toString();
      print('[뷰어] HTML 길이: ${htmlString.length}');

      // 네비게이션 링크 파싱
      _parseNavigationLinks(htmlString);

      // HTML 파싱
      print('[뷰어] HTML 파싱 시작');
      final document = html_parser.parse(htmlString);

      // 네비게이션 링크 파싱
      _parseNavigationLinks(htmlString);

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

  void _navigateToUrl(String? url) {
    if (url == null) return;

    print('[네비게이션] URL 처리 시작: $url');

    final baseUrl = ref.read(siteUrlServiceProvider);
    String fullUrl;
    String chapterId;

    // URL 정규화
    if (url.startsWith('http')) {
      fullUrl = url;
      // URL에서 chapter ID 추출
      final idMatch = RegExp(r'/comic/(\d+)').firstMatch(url);
      chapterId = idMatch?.group(1) ?? '';
    } else {
      // ID만 있는 경우
      chapterId = url.replaceAll(RegExp(r'[^0-9]'), '');
      fullUrl = '$baseUrl/comic/$chapterId';
    }

    print('[네비게이션] 정규화된 URL: $fullUrl');
    print('[네비게이션] Chapter ID: $chapterId');

    if (chapterId.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MangaViewerScreen(
            chapterId: chapterId,
            title: widget.title,
          ),
        ),
      );
    }
  }

  // HTML에서 네비게이션 링크 파싱
  void _parseNavigationLinks(String htmlString) {
    print('[파서] 네비게이션 링크 파싱 시작');

    final document = html_parser.parse(htmlString);
    final navDiv = document.querySelector('.toon-nav');

    if (navDiv != null) {
      print('[파서] .toon-nav 찾음');
      print('[파서] HTML: ${navDiv.outerHtml}');

      // select 태그에서 현재 회차와 이전/다음 회차 찾기
      final select = navDiv.querySelector('select[name="wr_id"]');
      if (select != null) {
        final options = select.querySelectorAll('option');
        print('[파서] 전체 회차 수: ${options.length}');

        // 현재 선택된 회차 찾기
        int currentIndex = -1;
        for (var i = 0; i < options.length; i++) {
          if (options[i].attributes['selected'] != null) {
            currentIndex = i;
            print('[파서] 현재 회차 인덱스: $i');
            break;
          }
        }

        if (currentIndex != -1) {
          // 이전화 설정
          if (currentIndex < options.length - 1) {
            final nextValue = options[currentIndex + 1].attributes['value'];
            if (nextValue != null) {
              _prevChapterUrl = nextValue;
              print('[파서] 이전화 ID: $_prevChapterUrl');
            }
          }

          // 다음화 설정
          if (currentIndex > 0) {
            final prevValue = options[currentIndex - 1].attributes['value'];
            if (prevValue != null) {
              _nextChapterUrl = prevValue;
              print('[파서] 다음화 ID: $_nextChapterUrl');
            }
          }
        }
      }

      // a 태그에서도 확인 (백업)
      if (_prevChapterUrl == null) {
        final prevBtn = navDiv.querySelector('#goPrevBtn');
        if (prevBtn != null) {
          final href = prevBtn.attributes['href'];
          if (href != null && !href.contains('javascript:')) {
            _prevChapterUrl = href;
            print('[파서] a 태그에서 이전화 링크 찾음: $_prevChapterUrl');
          }
        }
      }

      if (_nextChapterUrl == null) {
        final nextBtn = navDiv.querySelector('#goNextBtn');
        if (nextBtn != null) {
          final href = nextBtn.attributes['href'];
          if (href != null && !href.contains('javascript:')) {
            _nextChapterUrl = href;
            print('[파서] a 태그에서 다음화 링크 찾음: $_nextChapterUrl');
          }
        }
      }
    } else {
      print('[파서] .toon-nav를 찾을 수 없음');
    }
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
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // 이전화로 당기기 인디케이터
                  if (_isOverscrolling &&
                      _scrollController.position.pixels <
                          _scrollController.position.minScrollExtent &&
                      _prevChapterUrl != null)
                    Container(
                      height: 100,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.keyboard_arrow_up,
                              color: Colors.white70, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            '이전화로 이동하기',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  // 이미지 목록
                  ..._imageUrls.map((url) {
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
                  // 다음화로 당기기 인디케이터
                  if (_isOverscrolling &&
                      _scrollController.position.pixels >
                          _scrollController.position.maxScrollExtent &&
                      _nextChapterUrl != null)
                    Container(
                      height: 100,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '다음화로 이동하기',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          const Icon(Icons.keyboard_arrow_down,
                              color: Colors.white70, size: 36),
                        ],
                      ),
                    ),
                ],
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
                onTapUp: (details) => _toggleNavigationBar(),
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
                    widget.title,
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
                    color:
                        _prevChapterUrl == null ? Colors.white38 : Colors.white,
                    onPressed: _prevChapterUrl == null
                        ? null
                        : () => _navigateToUrl(_prevChapterUrl),
                    tooltip: '이전화',
                  ),
                  IconButton(
                    icon: const Icon(Icons.list),
                    color: Colors.white38,
                    onPressed: null, // 회차 목록 비활성화
                    tooltip: '회차 목록 (준비중)',
                  ),
                  IconButton(
                    icon: const Icon(Icons.comment),
                    color: Colors.white38,
                    onPressed: null, // 댓글 비활성화
                    tooltip: '댓글 (준비중)',
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    color:
                        _nextChapterUrl == null ? Colors.white38 : Colors.white,
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
