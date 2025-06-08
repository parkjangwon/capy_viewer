import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../data/providers/site_url_provider.dart';
import '../../../utils/manatoki_captcha_helper.dart';
import '../../widgets/manatoki_captcha_widget.dart';
import '../../viewmodels/global_cookie_provider.dart';
import '../../../data/database/database_helper.dart';
import '../../providers/secret_mode_provider.dart';
import '../../../data/models/manga_viewer_state.dart';
import '../captcha_page.dart';
import 'comments_screen.dart';
import '../../../utils/manga_detail_parser.dart';

/// 만화 뷰어 화면
/// 만화 페이지를 표시하고 캡차 처리를 담당합니다.
class MangaViewerScreen extends ConsumerStatefulWidget {
  final String title;
  final String chapterId;
  final int initialPage;
  final String? thumbnailUrl;

  const MangaViewerScreen({
    super.key,
    required this.title,
    required this.chapterId,
    this.initialPage = 0,
    this.thumbnailUrl,
  });

  @override
  ConsumerState<MangaViewerScreen> createState() => _MangaViewerScreenState();
}

class _MangaViewerScreenState extends ConsumerState<MangaViewerScreen> {
  late WebViewController _controller;
  final _db = DatabaseHelper.instance;
  String _currentTitle = '';
  int _currentPage = 0;
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _showManatokiCaptcha = false;
  bool _showError = false;
  bool _showNavigationBar = false;
  List<String> _imageUrls = [];
  String? _prevChapterUrl;
  String? _nextChapterUrl;
  bool _isInitialLoad = true;
  Timer? _dragTimer;
  Timer? _loadingTimer;
  Timer? _overscrollTimer;
  Timer? _scrollAnimationTimer;
  bool _isDragging = false;
  bool _isScrollAnimating = false;
  bool _isOverscrollTimerActive = false;
  double _dragOffset = 0;
  ManatokiCaptchaInfo? _captchaInfo;
  final ScrollController _scrollController = ScrollController();

  static const _overscrollThreshold = 100.0;
  static const _overscrollHoldDuration = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _initWebView();
    _setupScrollController();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _scrollController.dispose();
    _dragTimer?.cancel();
    _overscrollTimer?.cancel();
    _scrollAnimationTimer?.cancel();
    super.dispose();
  }

  void _setupScrollController() {
    _scrollController.addListener(() {
      // 현재 스크롤 위치 로깅
      print('[스크롤] 현재 위치: ${_scrollController.position.pixels}');
      print('[스크롤] 최대 위치: ${_scrollController.position.maxScrollExtent}');
      print('[스크롤] 최소 위치: ${_scrollController.position.minScrollExtent}');

      // 현재 페이지 번호 계산 및 업데이트
      if (_imageUrls.isNotEmpty) {
        final viewportHeight = _scrollController.position.viewportDimension;
        final scrollPosition = _scrollController.position.pixels;
        final currentPage = (scrollPosition / viewportHeight).floor() + 1;
        _updateLastPage(currentPage);
      }
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_isScrollAnimating) {
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final metrics = notification.metrics;

      // 오버스크롤 상태 확인
      if (metrics.outOfRange) {
        final overscroll = metrics.pixels -
            (metrics.pixels < 0
                ? metrics.minScrollExtent
                : metrics.maxScrollExtent);

        print('[스크롤] 오버스크롤: $overscroll');

        // 스크롤 애니메이션 중이 아니고 오버스크롤이 임계값을 넘었을 때
        if (!_isDragging &&
            !_isScrollAnimating &&
            overscroll.abs() > _overscrollThreshold) {
          setState(() {
            _isDragging = true;
            _dragOffset = overscroll;
          });

          // 이미 타이머가 실행 중이 아닐 때만 새로운 타이머 시작
          if (!_isOverscrollTimerActive) {
            _isOverscrollTimerActive = true;
            _overscrollTimer?.cancel();
            _overscrollTimer = Timer(_overscrollHoldDuration, () {
              if (_isDragging && mounted) {
                if (overscroll < 0 && _prevChapterUrl != null) {
                  print('[스크롤] 이전화로 이동');
                  _navigateToUrl(_prevChapterUrl);
                } else if (overscroll > 0 && _nextChapterUrl != null) {
                  print('[스크롤] 다음화로 이동');
                  _navigateToUrl(_nextChapterUrl);
                }
              }
              _isOverscrollTimerActive = false;
            });
          }
        }
      } else {
        _cancelOverscroll();
      }
    } else if (notification is ScrollEndNotification) {
      _cancelOverscroll();
    }
    return false;
  }

  void _scrollToPosition(double position) {
    if (!_scrollController.hasClients) return;

    // 이전 타이머 취소
    _scrollAnimationTimer?.cancel();

    setState(() => _isScrollAnimating = true);

    _scrollController
        .animateTo(
      position,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    )
        .then((_) {
      // 스크롤 애니메이션이 끝난 후 약간의 지연 시간을 두고 플래그를 해제
      _scrollAnimationTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() => _isScrollAnimating = false);
        }
      });
    });
  }

  void _scrollToTop() {
    _scrollToPosition(0);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollToPosition(_scrollController.position.maxScrollExtent);
    }
  }

  Future<void> _initWebView() async {
    print('[뷰어] 웹뷰 초기화 시작');
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

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('[웹뷰] 페이지 로딩 시작: $url');
          },
          onPageFinished: _onPageFinished,
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..enableZoom(false);

    await _loadUrl();
  }

  Future<void> _loadUrl() async {
    print('[뷰어] URL 로드: ${widget.chapterId}');
    final baseUrl = ref.read(siteUrlServiceProvider);
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
    await _controller.loadRequest(Uri.parse(fullUrl));
  }

  Future<void> _loadPageContent() async {
    if (!mounted || !_isInitialLoad) return;

    print('[뷰어] 페이지 콘텐츠 로딩 시작');
    print('[뷰어] 초기 페이지: ${widget.initialPage}');

    // 이미 이미지 URL이 로드되어 있다면 다시 로드하지 않음
    if (_imageUrls.isNotEmpty) {
      setState(() {
        _isLoading = false;
      });
      if (widget.initialPage > 0) {
        print('[뷰어] 기존 이미지로 페이지 이동 시도');
        await Future.delayed(const Duration(milliseconds: 1000));
        await _moveToPage(widget.initialPage);
      }
      return;
    }

    _loadingTimer?.cancel();
    setState(() {
      _isLoading = true;
      _showError = false;
    });

    try {
      print('[뷰어] HTML 콘텐츠 가져오기 시작');
      final html = await _controller.runJavaScriptReturningResult(
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
          await _addToRecentChapters();

          // 이미지 로딩을 위한 지연 후 페이지 이동
          if (widget.initialPage > 0 && mounted) {
            print('[뷰어] 새로운 이미지로 페이지 이동 시도');
            await Future.delayed(const Duration(milliseconds: 2000));
            await _moveToPage(widget.initialPage);
          }
        } else {
          print('[뷰어] 이미지를 찾을 수 없음');
          setState(() {
            _showError = true;
            _isLoading = false;
          });
        }
      }

      _isInitialLoad = false;
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

  Future<void> _moveToPage(int page) async {
    print('[뷰어] 페이지 이동 시도: $page');
    if (_imageUrls.isEmpty) {
      print('[뷰어] 페이지 이동 실패: 이미지 URL이 없음');
      return;
    }

    // 페이지 번호가 범위를 벗어나면 마지막 페이지로 이동
    final targetPage = page >= _imageUrls.length ? _imageUrls.length - 1 : page;
    print('[뷰어] 목표 페이지: $targetPage (전체 ${_imageUrls.length}페이지)');

    final imageUrl = _imageUrls[targetPage];
    print('[뷰어] 이동할 이미지 URL: $imageUrl');

    // 이미지가 로드될 때까지 대기
    bool success = false;
    int retryCount = 0;
    const maxRetries = 5;

    while (!success && retryCount < maxRetries && mounted) {
      try {
        final result = await _controller.runJavaScriptReturningResult('''
          (function() {
            const images = document.querySelectorAll('img');
            let targetImage = null;
            let targetIndex = -1;
            
            for (let i = 0; i < images.length; i++) {
              const img = images[i];
              if (img.src === '$imageUrl' || img.getAttribute('data-original') === '$imageUrl') {
                targetImage = img;
                targetIndex = i;
                break;
              }
            }
            
            if (targetImage && targetImage.complete) {
              const rect = targetImage.getBoundingClientRect();
              if (rect.height > 0) {
                const offset = targetImage.offsetTop;
                window.scrollTo({
                  top: offset,
                  behavior: 'instant'
                });
                return {success: true, index: targetIndex, offset: offset};
              }
            }
            return {success: false, index: targetIndex, offset: 0};
          })()
        ''');

        print('[뷰어] 스크롤 결과: $result');
        final Map<String, dynamic> scrollResult =
            Map<String, dynamic>.from(result as Map<dynamic, dynamic>);

        success = scrollResult['success'] == true;

        if (success) {
          print(
              '[뷰어] 페이지 이동 성공 (인덱스: ${scrollResult['index']}, 오프셋: ${scrollResult['offset']})');
          _currentPage = targetPage;
          await _updateLastPage(targetPage);
          break;
        } else {
          print('[뷰어] 이미지 로드 대기 중... (시도 ${retryCount + 1}/$maxRetries)');
          await Future.delayed(const Duration(milliseconds: 500));
          retryCount++;
        }
      } catch (e) {
        print('[뷰어] 페이지 이동 오류: $e');
        retryCount++;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    if (!success) {
      print('[뷰어] 페이지 이동 실패: 이미지를 찾을 수 없거나 로드되지 않음');
    }
  }

  Future<void> _updateCurrentPage() async {
    try {
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          const images = document.querySelectorAll('img');
          const viewportTop = window.scrollY;
          const viewportBottom = viewportTop + window.innerHeight;
          let currentPage = 0;

          for (let i = 0; i < images.length; i++) {
            const rect = images[i].getBoundingClientRect();
            const elementTop = rect.top + viewportTop;
            if (elementTop > viewportTop) {
              currentPage = i;
              break;
            }
          }
          return currentPage;
        })()
      ''');

      if (result != 'null') {
        final page = int.tryParse(result.toString()) ?? 0;
        if (page != _currentPage) {
          _currentPage = page;
          await _updateLastPage(page);
        }
      }
    } catch (e) {
      print('[뷰어] 현재 페이지 업데이트 실패: $e');
    }
  }

  String _extractThumbnail(String html) {
    try {
      final document = html_parser.parse(html);

      // 정확한 구조로 썸네일 찾기
      final postImage = document.querySelector('.post-image');
      if (postImage != null) {
        final imgItem = postImage.querySelector('.img-item img');
        if (imgItem != null) {
          final src = imgItem.attributes['src'];
          if (src != null && src.isNotEmpty) {
            print('[썸네일 추출] 성공: $src');
            return src;
          }
        }
      }

      print('[썸네일 추출] .post-image > .img-item > img 구조에서 썸네일을 찾지 못함');
      return '';
    } catch (e) {
      print('[썸네일 추출] 실패: $e');
      return '';
    }
  }

  Future<void> _addToRecentChapters() async {
    if (_currentTitle.isNotEmpty) {
      print('[최근에 본 작품] 저장 시도');
      print('[최근에 본 작품] ID: ${widget.chapterId}');
      print('[최근에 본 작품] 작품 ID: ${widget.title}');
      print('[최근에 본 작품] 제목: $_currentTitle');
      print('[최근에 본 작품] 썸네일: ${widget.thumbnailUrl}');

      // 시크릿 모드 상태 확인
      final isSecretMode = ref.read(secretModeProvider);
      if (isSecretMode) {
        print('[최근에 본 작품] 시크릿 모드가 켜져있어 저장하지 않음');
        return;
      }

      try {
        // 기존 최근 본 작품 정보 가져오기
        final existingChapter = await _db.getRecentChapter(widget.title);

        // 만화 ID가 같은 경우 기존 데이터 업데이트
        if (existingChapter != null) {
          // 썸네일 우선순위:
          // 1. 새로 전달받은 썸네일
          // 2. 기존에 저장된 썸네일
          final thumbnailUrl = widget.thumbnailUrl?.isNotEmpty == true
              ? widget.thumbnailUrl!
              : existingChapter['thumbnail_url'] as String;

          await _db.updateRecentChapter(
            chapterId: widget.chapterId,
            mangaId: widget.title,
            chapterTitle: _currentTitle,
            thumbnailUrl: thumbnailUrl,
            lastPage: _currentPage,
          );
          print('[최근에 본 작품] 업데이트됨: ${widget.chapterId} - $_currentTitle');
        } else {
          // 새로운 데이터 추가
          await _db.addRecentChapter(
            chapterId: widget.chapterId,
            mangaId: widget.title,
            chapterTitle: _currentTitle,
            thumbnailUrl: widget.thumbnailUrl ?? '', // 전달받은 썸네일 사용
            lastPage: _currentPage,
          );
          print('[최근에 본 작품] 추가됨: ${widget.chapterId} - $_currentTitle');
        }
      } catch (e) {
        print('[최근에 본 작품] 저장 실패: $e');
      }
    }
  }

  Future<void> _updateLastPage(int pageNumber) async {
    print('[최근에 본 작품] 페이지 업데이트 시도: $pageNumber');

    // 시크릿 모드 상태 확인
    final isSecretMode = ref.read(secretModeProvider);
    if (isSecretMode) {
      print('[최근에 본 작품] 시크릿 모드가 켜져있어 페이지 업데이트하지 않음');
      return;
    }

    try {
      // 기존 데이터 가져오기
      final existingChapter = await _db.getRecentChapter(widget.title);
      if (existingChapter != null) {
        await _db.updateRecentChapter(
          chapterId: widget.chapterId,
          mangaId: widget.title,
          chapterTitle: _currentTitle.isNotEmpty
              ? _currentTitle
              : existingChapter['chapter_title'] as String,
          thumbnailUrl: existingChapter['thumbnail_url'] as String,
          lastPage: pageNumber,
        );
        print('[최근에 본 작품] 페이지 업데이트: ${widget.chapterId} - $pageNumber');
      }
    } catch (e) {
      print('[최근에 본 작품] 페이지 업데이트 실패 상세: $e');
      print('[최근에 본 작품] 페이지 업데이트 실패: $e');
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
              Scaffold(
                appBar: AppBar(
                  backgroundColor: Colors.black,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                backgroundColor: Colors.black,
                body: Center(
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
                        '페이지를 불러올 수 없습니다. "캡차 인증" 버튼을 눌러보세요.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _showError = false;
                                _isInitialLoad = true;
                              });
                              _controller.reload();
                            },
                            child: const Text('다시 시도'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () async {
                              final baseUrl = ref.read(siteUrlServiceProvider);
                              final targetUrl =
                                  '$baseUrl/comic/129241'; // 베르세르크 페이지로 고정

                              if (mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CaptchaPage(
                                      url: targetUrl,
                                      onHtmlReceived: (html) async {
                                        if (mounted) {
                                          setState(() {
                                            _showError = false;
                                            _isLoading = true;
                                          });

                                          // 원래 보려고 했던 챕터의 URL로 직접 이동
                                          final baseUrl =
                                              ref.read(siteUrlServiceProvider);
                                          final targetUrl = widget.chapterId
                                                  .startsWith('http')
                                              ? widget.chapterId
                                              : '$baseUrl/comic/${widget.chapterId}';

                                          await _controller.loadRequest(
                                            Uri.parse(targetUrl),
                                          );

                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content:
                                                    Text('캡차 인증이 완료되었습니다.'),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                            ),
                            child: const Text('캡차 인증'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            if (_showManatokiCaptcha && _captchaInfo != null)
              ManatokiCaptchaWidget(
                captchaInfo: _captchaInfo!,
                onSuccess: () {
                  _onCaptchaVerified();
                },
              ),

            if (!_isLoading && !_showError && !_showManatokiCaptcha)
              NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
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
                      child: Stack(
                        children: [
                          ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.zero,
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            itemCount: _imageUrls.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2.0),
                                child: CachedMangaImage(
                                  url: _imageUrls[index],
                                  width: MediaQuery.of(context).size.width,
                                  height: 0, // height는 이미지 비율에 따라 자동 조정됨
                                ),
                              );
                            },
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
                          icon: const Icon(Icons.comment, color: Colors.white),
                          onPressed: () async {
                            final html =
                                await _controller.runJavaScriptReturningResult(
                              'document.documentElement.outerHTML',
                            );
                            if (!mounted) return;

                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => CommentsScreen(
                                  htmlContent: html.toString(),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.list, color: Colors.white),
                          onPressed: _showChapterList,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_up,
                              color: Colors.white),
                          onPressed: _scrollToTop,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down,
                              color: Colors.white),
                          onPressed: _scrollToBottom,
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

  void _cancelOverscroll() {
    _overscrollTimer?.cancel();
    _isOverscrollTimerActive = false;
    if (_isDragging) {
      setState(() {
        _isDragging = false;
        _dragOffset = 0;
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
      final baseUrl = ref.read(siteUrlServiceProvider);
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
        await _controller.reload();
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
    _controller.loadRequest(Uri.parse(fullUrl));
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

      // 현재 회차 제목 찾기
      final titleElement = document.querySelector('.toon-title');
      if (titleElement != null) {
        _currentTitle = titleElement.text.trim();
        // 최근에 본 작품에 추가
        _addToRecentChapters();
      }
    } else {
      print('[파서] .toon-nav를 찾을 수 없음');
    }
  }

  void _showChapterList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        '회차 목록',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _chapters.length,
                    itemBuilder: (context, index) {
                      final chapter = _chapters[index];
                      final isCurrentChapter = chapter.id == widget.chapterId;

                      return ListTile(
                        title: Text(
                          chapter.title,
                          style: TextStyle(
                            color:
                                isCurrentChapter ? Colors.blue : Colors.white,
                            fontWeight: isCurrentChapter
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          if (!isCurrentChapter) {
                            _navigateToChapter(chapter.id);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _navigateToChapter(String chapterId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MangaViewerScreen(
          title: widget.title,
          chapterId: chapterId,
          thumbnailUrl: widget.thumbnailUrl,
        ),
      ),
    );
  }

  List<Chapter> _chapters = [];

  void _parseChapterList(String htmlString) {
    try {
      print('[회차 목록] 파싱 시작');
      final document = html_parser.parse(htmlString);

      // select 태그 찾기
      final select = document.querySelector('select[name="wr_id"]');
      print('[회차 목록] select 태그 ${select != null ? "발견" : "없음"}');

      if (select != null) {
        // select 태그의 HTML 출력
        print('[회차 목록] select HTML: ${select.outerHtml}');

        final options = select.querySelectorAll('option');
        print('[회차 목록] option 태그 수: ${options.length}');

        _chapters = options.map((option) {
          final id = option.attributes['value'] ?? '';
          final title = option.text.trim();
          final url = 'https://manatoki468.net/comic/$id';
          print('[회차 목록] 회차 발견: id=$id, title=$title');
          return Chapter(id: id, title: title, url: url);
        }).toList();

        setState(() {});
        print('[회차 목록] 총 ${_chapters.length}개의 회차를 파싱했습니다.');
      } else {
        print('[회차 목록] select 태그를 찾을 수 없음');
        // toon-nav 요소 확인
        final toonNav = document.querySelector('.toon-nav');
        if (toonNav != null) {
          print('[회차 목록] toon-nav HTML: ${toonNav.outerHtml}');
        }
      }
    } catch (e, stackTrace) {
      print('[회차 목록] 파싱 실패: $e');
      print('[회차 목록] 스택 트레이스: $stackTrace');
    }
  }

  Future<void> _onPageFinished(String url) async {
    print('[웹뷰] 페이지 로딩 완료: $url');

    if (!mounted) return;

    try {
      // JavaScript를 실행하여 전체 HTML을 가져옴
      final html = await _controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );

      if (!mounted) return;

      final htmlString = html.toString();
      print('[웹뷰] HTML 길이: ${htmlString.length}');

      // 네비게이션 링크와 회차 목록 파싱
      _parseNavigationLinks(htmlString);
      _parseChapterList(htmlString);

      // 클라우드플레어 캡차 확인
      if (htmlString.contains('challenge-form') ||
          htmlString.contains('cf-please-wait') ||
          htmlString.contains('turnstile') ||
          htmlString.contains('_cf_chl_opt')) {
        print('[뷰어] 클라우드플레어 캡차 감지됨');

        if (mounted) {
          final baseUrl = ref.read(siteUrlServiceProvider);
          final targetUrl = '$baseUrl/comic/129241';

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CaptchaPage(
                url: targetUrl,
                onHtmlReceived: (html) {
                  if (mounted) {
                    setState(() {
                      _showError = false;
                      _isLoading = true;
                    });
                    _controller.reload();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('캡차 인증이 완료되었습니다.'),
                      ),
                    );
                  }
                },
              ),
            ),
          );
          return;
        }
      }

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

      // 페이지 처리를 위해 _isInitialLoad 설정
      setState(() {
        _isInitialLoad = true;
        _isLoading = true;
      });

      // 일반 페이지 처리
      await _loadPageContent();
    } catch (e, stackTrace) {
      print('[웹뷰] 페이지 처리 오류: $e');
      print('[웹뷰] 스택 트레이스: $stackTrace');
      if (mounted) {
        setState(() {
          _showError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _parseImages(String htmlString) {
    try {
      final document = html_parser.parse(htmlString);
      final article = document.querySelector('article[itemprop="articleBody"]');

      if (article != null) {
        final images = article.querySelectorAll('img');
        final urls = images
            .map((img) {
              final dataUrl = img.attributes.entries
                  .where((attr) =>
                      (attr.key as String).startsWith('data-') &&
                      attr.value.contains('://'))
                  .map((attr) => attr.value)
                  .firstOrNull;

              final src = dataUrl ?? img.attributes['src'] ?? '';
              if (src.isNotEmpty && !src.contains('/tokinbtoki/')) {
                return src;
              }
              return '';
            })
            .where((url) => url.isNotEmpty)
            .toList();

        setState(() {
          _imageUrls = urls;
          _isLoading = false;
        });
      } else {
        setState(() {
          _showError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[이미지 파싱] 실패: $e');
      setState(() {
        _showError = true;
        _isLoading = false;
      });
    }
  }

  void _loadChapter() async {
    final baseUrl = ref.read(siteUrlServiceProvider);
    final url = widget.chapterId.startsWith('http')
        ? widget.chapterId
        : '$baseUrl/comic/${widget.chapterId}';

    try {
      final response = await http.get(Uri.parse(url));
      final html = response.body;

      if (mounted) {
        _processHtml(html);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _showError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _processHtml(String html) {
    if (ManatokiCaptchaHelper.isCaptchaRequired(html)) {
      print('[뷰어] 마나토끼 캡차 감지됨');
      final baseUrl = ref.read(siteUrlServiceProvider);
      final captchaInfo =
          ManatokiCaptchaHelper.extractCaptchaInfo(html, baseUrl);

      if (captchaInfo != null) {
        setState(() {
          _showManatokiCaptcha = true;
          _captchaInfo = captchaInfo;
          _isLoading = false;
        });
        return;
      }
    }

    final document = html_parser.parse(html);
    final imageElements = document.querySelectorAll('img.page-data');
    final urls = imageElements
        .map((e) => e.attributes['src'])
        .where((url) => url != null)
        .map((url) => url!)
        .toList();

    if (urls.isEmpty) {
      setState(() {
        _showError = true;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _imageUrls = urls;
      _isLoading = false;
      _showError = false;
      _showManatokiCaptcha = false;
    });
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
          fit: BoxFit.fitWidth,
          httpHeaders: {
            'Cookie': cookieString,
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
            'Referer': baseUrl,
          },
          placeholder: (context, url) => Container(
            color: Colors.grey[900],
            width: width,
            height: width * 1.4,
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
