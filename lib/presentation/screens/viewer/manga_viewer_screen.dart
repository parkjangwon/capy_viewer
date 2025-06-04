import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/gestures.dart'; // DragStartBehavior를 위한 import 추가

import '../../../data/providers/site_url_provider.dart';
import '../../../utils/manatoki_captcha_helper.dart';
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
  String? _prevChapterUrl;
  String? _nextChapterUrl;
  Timer? _loadingTimer;
  bool _showError = false;
  final ScrollController _scrollController = ScrollController();
  bool _isOverscrolling = false;
  double _overscrollStart = 0;
  String _currentTitle = ''; // 현재 페이지의 실제 제목
  bool _isInitialLoad = true; // 초기 로드 여부를 추적하는 플래그
  Timer? _dragTimer;
  bool _isDragging = false;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _setupScrollController();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _scrollController.dispose();
    _dragTimer?.cancel();
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
        onPageFinished: (url) {
          if (mounted) {
            _loadPageContent();
          }
        },
      ))
      ..enableZoom(false);

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
    _isInitialLoad = true; // 새 페이지 로드 시 초기 로드 플래그 설정
    await controller.loadRequest(Uri.parse(fullUrl));
  }

  // 페이지 콘텐츠 로드 (HTML 파싱 포함)
  Future<void> _loadPageContent() async {
    if (!mounted || !_isInitialLoad) return;

    // 이미 이미지 URL이 로드되어 있다면 다시 로드하지 않음
    if (_imageUrls.isNotEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    _loadingTimer?.cancel();
    setState(() {
      _isLoading = true;
      _showError = false;
    });

    try {
      print('[뷰어] HTML 콘텐츠 가져오기 시작');
      final html = await _controller!.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );

      if (!mounted) return;

      final htmlString = html.toString();
      print('[뷰어] HTML 길이: ${htmlString.length}');

      // HTML 파싱
      final document = html_parser.parse(htmlString);

      // 현재 페이지의 제목 파싱
      final titleElement = document.querySelector('.toon-title');
      if (titleElement != null) {
        final title = titleElement.attributes['title'];
        if (title != null) {
          setState(() {
            _currentTitle = title;
          });
          print('[뷰어] 현재 페이지 제목: $_currentTitle');
        }
      }

      // 네비게이션 링크 파싱
      _parseNavigationLinks(htmlString);

      // 마나토끼 캡차 확인
      if (ManatokiCaptchaHelper.isCaptchaRequired(htmlString)) {
        print('[뷰어] 마나토끼 캡차 감지됨');
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
          String? imageUrl;

          // data- 속성에서 URL 찾기
          for (final attr in img.attributes.entries) {
            if ((attr.key as String).startsWith('data-') &&
                attr.value.contains('://') &&
                !attr.value.contains('loading-image.gif') &&
                !attr.value.contains('/tokinbtoki/') &&
                !attr.value.contains('banner') &&
                !attr.value.contains('ads')) {
              imageUrl = attr.value;
              break;
            }
          }

          // data-original 속성 확인
          if (imageUrl == null) {
            final dataOriginal = img.attributes['data-original'];
            if (dataOriginal != null &&
                !dataOriginal.contains('loading-image.gif') &&
                !dataOriginal.contains('/tokinbtoki/') &&
                !dataOriginal.contains('banner') &&
                !dataOriginal.contains('ads')) {
              imageUrl = dataOriginal;
            }
          }

          // data-src 속성 확인
          if (imageUrl == null) {
            final dataSrc = img.attributes['data-src'];
            if (dataSrc != null &&
                !dataSrc.contains('loading-image.gif') &&
                !dataSrc.contains('/tokinbtoki/') &&
                !dataSrc.contains('banner') &&
                !dataSrc.contains('ads')) {
              imageUrl = dataSrc;
            }
          }

          // src 속성 확인
          if (imageUrl == null) {
            final src = img.attributes['src'];
            if (src != null &&
                !src.contains('loading-image.gif') &&
                !src.contains('/tokinbtoki/') &&
                !src.contains('banner') &&
                !src.contains('ads')) {
              imageUrl = src;
            }
          }

          if (imageUrl != null && imageUrl.isNotEmpty) {
            if (!imageUrl.startsWith('http')) {
              final baseUrl = ref.read(siteUrlServiceProvider);
              imageUrl = imageUrl.startsWith('/')
                  ? baseUrl + imageUrl
                  : '$baseUrl/$imageUrl';
            }
            urls.add(imageUrl);
          }
        }

        if (urls.isNotEmpty) {
          setState(() {
            _imageUrls = urls;
            _isLoading = false;
          });
          print('[뷰어] 이미지 URL 추출 완료: ${urls.length}개');
        } else {
          print('[뷰어] 이미지를 찾을 수 없음');
          setState(() {
            _showError = true;
            _isLoading = false;
          });
        }
      }

      _isInitialLoad = false; // HTML 파싱이 완료되면 초기 로드 플래그를 false로 설정
    } catch (e) {
      print('[뷰어] HTML 파싱 오류: $e');
      if (mounted) {
        setState(() {
          _showError = true;
          _isLoading = false;
        });
      }
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

  // 네비게이션 바 토글 (HTML 파싱 없이 단순 UI 상태만 변경)
  void _toggleNavigationBar() {
    setState(() {
      _showNavigationBar = !_showNavigationBar;
    });
  }

  // 다른 페이지로 이동
  void _navigateToUrl(String? url) {
    if (url == null || url == '#next') return;

    print('[네비게이션] URL 처리 시작: $url');

    final baseUrl = ref.read(siteUrlServiceProvider);
    String fullUrl;

    // URL 정규화
    if (url.startsWith('http')) {
      fullUrl = url;
    } else if (url.startsWith('/')) {
      fullUrl = baseUrl + url;
    } else {
      fullUrl = '$baseUrl/comic/$url';
    }

    print('[네비게이션] 이동할 URL: $fullUrl');
    setState(() {
      _imageUrls = [];
      _isLoading = true;
      _showError = false;
      _isInitialLoad = true;
    });
    _controller?.loadRequest(Uri.parse(fullUrl));
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
          // 이전화 설정 (더 높은 인덱스)
          if (currentIndex < options.length - 1) {
            final nextValue = options[currentIndex + 1].attributes['value'];
            if (nextValue != null) {
              _prevChapterUrl = nextValue;
              print('[파서] 이전화 ID: $_prevChapterUrl');
            }
          }

          // 다음화 설정 (더 낮은 인덱스)
          if (currentIndex > 0) {
            final prevValue = options[currentIndex - 1].attributes['value'];
            if (prevValue != null) {
              _nextChapterUrl = prevValue;
              print('[파서] 다음화 ID: $_nextChapterUrl');
            }
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
      appBar: (_isLoading || _showManatokiCaptcha)
          ? AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: SafeArea(
        child: Stack(
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
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '잠시만 기다려주세요',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            if (_showError)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '페이지를 불러올 수 없습니다',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _showError = false;
                          _isInitialLoad = true;
                        });
                        _controller?.reload();
                      },
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),

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
              ),

            if (!_isLoading && !_showError && !_showManatokiCaptcha)
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification) {
                    final pixels = _scrollController.position.pixels;
                    if (pixels < 0) {
                      // 위로 당기는 중
                      if (!_isDragging && pixels <= -60) {
                        _startDragTimer(true);
                      }
                      _dragOffset = pixels;
                    } else if (pixels >
                        _scrollController.position.maxScrollExtent) {
                      // 아래로 당기는 중
                      if (!_isDragging &&
                          pixels >=
                              _scrollController.position.maxScrollExtent + 60) {
                        _startDragTimer(false);
                      }
                      _dragOffset =
                          pixels - _scrollController.position.maxScrollExtent;
                    } else {
                      // 당기기 취소
                      _cancelDragTimer();
                    }
                  } else if (notification is ScrollEndNotification) {
                    // 스크롤이 끝나면 타이머 취소
                    _cancelDragTimer();
                  }
                  return false;
                },
                child: Stack(
                  children: [
                    GestureDetector(
                      dragStartBehavior: DragStartBehavior.down,
                      onTapUp: (details) {
                        final screenHeight = MediaQuery.of(context).size.height;
                        final tapY = details.globalPosition.dy;

                        if (tapY < screenHeight * 0.2) {
                          setState(() {
                            _showNavigationBar = !_showNavigationBar;
                          });
                        } else {
                          setState(() {
                            _showNavigationBar = !_showNavigationBar;
                          });
                        }
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: _imageUrls.length,
                        itemBuilder: (context, index) {
                          return CachedMangaImage(
                            url: _imageUrls[index],
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height,
                          );
                        },
                      ),
                    ),
                    if (_isDragging)
                      Positioned(
                        top: _dragOffset < 0 ? 20 : null,
                        bottom: _dragOffset > 0 ? 20 : null,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _dragOffset < 0 ? '이전화로 이동하기' : '다음화로 이동하기',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // 상단 네비게이션 바 (뒤로가기 버튼만)
            if (_showNavigationBar &&
                !_isLoading &&
                !_showError &&
                !_showManatokiCaptcha)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withOpacity(0.8),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: SafeArea(
                    child: Row(
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_up,
                              color: Colors.white),
                          onPressed: () {
                            _scrollController.animateTo(
                              0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down,
                              color: Colors.white),
                          onPressed: () {
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 하단 네비게이션 바
            if (_showNavigationBar &&
                !_isLoading &&
                !_showError &&
                !_showManatokiCaptcha)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.black.withOpacity(0.8),
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Colors.white),
                        onPressed: _prevChapterUrl != null
                            ? () => _navigateToUrl(_prevChapterUrl)
                            : null,
                      ),
                      Expanded(
                        child: Text(
                          _currentTitle.isNotEmpty
                              ? _currentTitle
                              : widget.title,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios,
                            color: Colors.white),
                        onPressed: _nextChapterUrl != null
                            ? () => _navigateToUrl(_nextChapterUrl)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _startDragTimer(bool isPrevious) {
    if (_isDragging) return;

    setState(() {
      _isDragging = true;
    });

    _dragTimer?.cancel();
    _dragTimer = Timer(const Duration(milliseconds: 700), () {
      if (_isDragging) {
        if (isPrevious && _prevChapterUrl != null) {
          _navigateToUrl(_prevChapterUrl);
        } else if (!isPrevious && _nextChapterUrl != null) {
          _navigateToUrl(_nextChapterUrl);
        }
      }
    });
  }

  void _cancelDragTimer() {
    _dragTimer?.cancel();
    if (_isDragging) {
      setState(() {
        _isDragging = false;
        _dragOffset = 0;
      });
    }
  }
}

/// 캐시된 만화 이미지 위젯
class CachedMangaImage extends ConsumerWidget {
  final String url;
  final double width;
  final double height;

  const CachedMangaImage({
    Key? key,
    required this.url,
    required this.width,
    required this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cookieJar = ref.watch(globalCookieJarProvider);
    final baseUrl = ref.watch(siteUrlServiceProvider);

    return FutureBuilder<List<Cookie>>(
      future: cookieJar.loadForRequest(Uri.parse(baseUrl)),
      builder: (context, snapshot) {
        final cookieString = snapshot.hasData
            ? snapshot.data!.map((c) => '${c.name}=${c.value}').join('; ')
            : '';

        return CachedNetworkImage(
          imageUrl: url,
          width: width,
          height: height,
          fit: BoxFit.fitWidth,
          httpHeaders: {
            'Cookie': cookieString,
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
            'Referer': baseUrl,
          },
          placeholder: (context, url) => Container(
            color: Colors.grey[900],
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          errorWidget: (context, url, error) => const Center(
            child: Text(
              '이미지를 불러올 수 없습니다.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}
