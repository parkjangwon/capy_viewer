import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import '../../../data/models/manga_detail.dart';
import '../../../data/providers/site_url_provider.dart';
import '../../../utils/manga_detail_parser.dart';
import '../../../utils/manatoki_captcha_helper.dart';

import '../../widgets/manatoki_captcha_widget.dart';
import '../../viewmodels/global_cookie_provider.dart';

import '../manga/manga_captcha_screen.dart';
import '../viewer/manga_viewer_screen.dart';
import '../../providers/tab_provider.dart';
import '../../../data/database/database_helper.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class MangaDetailScreen extends ConsumerStatefulWidget {
  final String? mangaId;
  final String? title;
  final String? directUrl; // 직접 접근할 URL (전편보기 버튼이 있는 페이지)
  final bool parseFullPage; // 전체 페이지를 파싱하여 전편보기 링크 추출

  const MangaDetailScreen(
      {super.key,
      this.mangaId,
      this.title,
      this.directUrl,
      this.parseFullPage = false});

  @override
  ConsumerState<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends ConsumerState<MangaDetailScreen> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';

  MangaDetail? _mangaDetail;
  bool _showManatokiCaptcha = false;
  ManatokiCaptchaInfo? _captchaInfo;
  final _db = DatabaseHelper.instance;
  String get _mangaId {
    if (widget.mangaId == null || widget.mangaId!.isEmpty) {
      throw Exception('mangaId가 전달되지 않았습니다.');
    }
    return widget.mangaId!;
  }

  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 0;

  // 저장 관련 상태 변수
  bool _isSaving = false;
  Set<String> _selectedChapters = {};
  bool _showSaveDialog = false;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _loadMangaDetail();
    _checkLikeStatus();
    _initializeNotifications();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            print('페이지 로드 완료: $url');
            // 페이지 로드가 완료되면 HTML 콘텐츠 가져오기
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted) {
                _getHtmlContent();
              }
            });
          },
          onNavigationRequest: (request) {
            print('네비게이션 요청: ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      );
  }

  Future<void> _loadMangaDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _isError = false;
        _errorMessage = '';
        _showManatokiCaptcha = false;
        _captchaInfo = null;
      });

      final baseUrl = ref.read(siteUrlServiceProvider);
      final jar = ref.read(globalCookieJarProvider);

      String url;
      if (widget.directUrl != null && widget.directUrl!.isNotEmpty) {
        url = widget.directUrl!;
        print('전편보기 버튼이 있는 페이지 로드: $url');
      } else {
        final cleanBaseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;
        url = '$cleanBaseUrl/comic/$_mangaId';
        print('만화 상세 페이지 로드: $url');
      }

      await _controller.loadRequest(Uri.parse(url));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = '데이터를 불러오는 중 오류가 발생했습니다: $e';
      });
      print('만화 상세 정보 로드 중 오류: $e');
    }
  }

  Future<void> _getHtmlContent() async {
    if (!mounted) return;

    try {
      // 페이지 로드 후 약간의 지연 추가 (JavaScript 실행 시간 고려)
      await Future.delayed(const Duration(milliseconds: 500));

      // 현재 URL 출력
      final currentUrl = await _controller.currentUrl();
      print('현재 WebView URL: $currentUrl');

      // HTML 가져오기 - 안전하게 처리
      String htmlStr = '';
      try {
        final html = await _controller
            .runJavaScriptReturningResult('document.documentElement.outerHTML');
        htmlStr = html.toString();
        // 크기 제한을 위해 최대 길이 제한
        if (htmlStr.length > 500000) {
          print('매우 큰 HTML 감지. 잘라냄: ${htmlStr.length} -> 500000');
          htmlStr = htmlStr.substring(0, 500000);
        }
      } catch (e) {
        print('HTML 가져오기 오류: $e');
        htmlStr = '';
      }

      if (!mounted) return;

      // HTML 길이 출력 - 안전하게 처리
      try {
        final htmlLength = htmlStr.length;
        print('HTML 길이: $htmlLength');
      } catch (e) {
        print('HTML 길이 출력 오류: $e');
      }

      // 빈 HTML 문자열 처리
      if (htmlStr.isEmpty) {
        print('빈 HTML 문자열 감지. 다시 시도합니다.');
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = 'HTML 내용을 가져올 수 없습니다. 다시 시도해주세요.';
        });
        return;
      }

      // 마나토끼 캡챠 확인
      try {
        if (ManatokiCaptchaHelper.isCaptchaRequired(htmlStr)) {
          print('마나토끼 캡챠 감지됨: 웹뷰로 캡챠 처리를 시작합니다.');

          // 캡챠 정보 추출
          final baseUrl = ref.read(siteUrlServiceProvider);
          final captchaInfo =
              ManatokiCaptchaHelper.extractCaptchaInfo(htmlStr, baseUrl);

          if (captchaInfo != null) {
            setState(() {
              _showManatokiCaptcha = true;
              _captchaInfo = captchaInfo;
              _isLoading = false;
            });
            return;
          }
        }
      } catch (e) {
        print('캡챠 확인 오류: $e');
      }

      // HTML 파싱 시작
      print('만화 상세 페이지 HTML 파싱 시작: $_mangaId');
      try {
        // 전편보기 링크가 있는 페이지인 경우 (파싱 후 전편보기 링크로 이동)
        if (widget.parseFullPage) {
          print('전편보기 링크 추출 시도...');

          // HTML 문서 파싱
          final document = html_parser.parse(htmlStr);

          // 전편보기 링크 추출
          String? previousUrl;

          // 1. 가장 정확한 방법: .pull-right.post-info 내부의 .btn.btn-xs.btn-primary 버튼 검색
          final postInfoDivs =
              document.querySelectorAll('.pull-right.post-info');
          print('- .pull-right.post-info 요소 개수: ${postInfoDivs.length}');

          for (final postInfo in postInfoDivs) {
            // 정확히 전편보기 버튼을 찾기
            final previousButtons = postInfo
                .querySelectorAll('a.btn-primary, a.btn-xs.btn-primary');
            print('  - 전편보기 버튼 개수: ${previousButtons.length}');

            for (final button in previousButtons) {
              final text = button.text.trim();
              final href = button.attributes['href'];
              final rel = button.attributes['rel'];
              final className = button.attributes['class'] ?? '';

              print(
                  '  - 버튼 검색: text="$text", href=$href, rel=$rel, class=$className');

              if (text.contains('전편보기') && href != null && href.isNotEmpty) {
                previousUrl = href;
                print('  -> 전편보기 버튼 발견: $previousUrl');

                // rel 속성을 저장하여 나중에 활용
                if (rel != null && rel.isNotEmpty) {
                  print('  -> 전편보기 ID (rel 속성): $rel');
                }
                break;
              }
            }

            if (previousUrl != null) break;

            // 전편보기 버튼을 찾지 못한 경우 모든 링크 검색
            if (previousUrl == null) {
              final links = postInfo.querySelectorAll('a');
              print('  - 모든 링크 개수: ${links.length}');

              for (final link in links) {
                final text = link.text.trim();
                final href = link.attributes['href'];
                final rel = link.attributes['rel'];

                print('  - 링크 검색: text="$text", href=$href, rel=$rel');

                if (text.contains('전편보기') && href != null && href.isNotEmpty) {
                  previousUrl = href;
                  print('  -> 전편보기 링크 발견: $previousUrl');
                  break;
                }
              }
            }
          }

          // 2. 전체 페이지에서 버튼 클래스로 찾기
          if (previousUrl == null) {
            final primaryButtons = document
                .querySelectorAll('a.btn-primary, a.btn-xs.btn-primary');
            print('- 전체 페이지 버튼 개수: ${primaryButtons.length}');

            for (final button in primaryButtons) {
              final text = button.text.trim();
              final href = button.attributes['href'];
              final rel = button.attributes['rel'];

              print('  - 버튼 검색: text="$text", href=$href, rel=$rel');

              if (text.contains('전편보기') && href != null && href.isNotEmpty) {
                previousUrl = href;
                print('  -> 전편보기 버튼 발견: $previousUrl');
                break;
              }
            }
          }

          // 3. 모든 링크 검색 (마지막 수단)
          if (previousUrl == null) {
            final allLinks = document.querySelectorAll('a');
            print('- 모든 링크 개수: ${allLinks.length}');

            for (final link in allLinks) {
              final text = link.text.trim();
              final href = link.attributes['href'];
              final rel = link.attributes['rel'];

              print('  - 링크 검색: text="$text", href=$href, rel=$rel');

              if ((text.contains('전편보기') ||
                      text.contains('전편') ||
                      text.contains('이전')) &&
                  href != null &&
                  href.isNotEmpty &&
                  href.contains('/comic/')) {
                previousUrl = href;
                print('  -> 전편보기 관련 링크 발견: $previousUrl');
                break;
              }
            }
          }

          // 전편보기 링크를 찾았으면 해당 URL로 이동
          if (previousUrl != null && previousUrl.isNotEmpty) {
            print('전편보기 링크로 이동: $previousUrl');

            // URL이 상대 경로인 경우 절대 경로로 변환
            if (!previousUrl.startsWith('http')) {
              final baseUrl = ref.read(siteUrlServiceProvider);
              final cleanBaseUrl = baseUrl.endsWith('/')
                  ? baseUrl.substring(0, baseUrl.length - 1)
                  : baseUrl;
              previousUrl = previousUrl.startsWith('/')
                  ? '$cleanBaseUrl$previousUrl'
                  : '$cleanBaseUrl/$previousUrl';
            }

            // 전편보기 링크로 이동
            await _controller.loadRequest(Uri.parse(previousUrl));
            return; // 페이지 로드가 완료되면 onPageFinished에서 _getHtmlContent가 다시 호출됨
          } else {
            print('전편보기 링크를 찾을 수 없습니다.');
          }
        }

        // 일반 HTML 파싱 (전편보기 링크를 찾지 못했거나, parseFullPage가 false인 경우)
        final result = parseMangaDetailFromHtml(htmlStr, _mangaId);

        if (result.hasCaptcha) {
          print('파싱 결과: 캡챠 필요');
          setState(() {
            _isLoading = false;
            _showManatokiCaptcha = true;
          });
          return;
        }

        setState(() {
          _mangaDetail = result.mangaDetail;
          _isLoading = false;
          print('파싱 결과: ${_mangaDetail?.title}');
        });
      } catch (e) {
        print('HTML 파싱 오류: $e');
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = 'HTML 파싱 중 오류가 발생했습니다: $e';
        });
      }
    } catch (e) {
      print('HTML 콘텐츠 가져오기 오류: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = 'HTML 내용을 가져오는 중 오류가 발생했습니다: $e';
      });
    }
  }

  // 디버깅을 위한 HTML 구조 분석 메서드
  Future<void> _debugHtmlStructure() async {
    try {
      // 주요 요소 확인
      final bodyClass = await _controller
          .runJavaScriptReturningResult('document.body.className;');
      print('Body 클래스: $bodyClass');

      // 회차 목록 관련 요소 확인
      final serialListCount = await _controller.runJavaScriptReturningResult(
          'document.querySelectorAll(".serial-list").length;');
      print('serial-list 요소 수: $serialListCount');

      final listWrapCount = await _controller.runJavaScriptReturningResult(
          'document.querySelectorAll(".list-wrap").length;');
      print('list-wrap 요소 수: $listWrapCount');

      final boardListCount = await _controller.runJavaScriptReturningResult(
          'document.querySelectorAll(".board-list").length;');
      print('board-list 요소 수: $boardListCount');

      final comicLinksCount = await _controller.runJavaScriptReturningResult(
          'document.querySelectorAll("a[href*=\\"/comic/\\"]").length;');
      print('만화 관련 링크 수: $comicLinksCount');

      // 첫 번째 만화 링크 확인
      if (int.parse(comicLinksCount.toString()) > 0) {
        final firstLinkHref = await _controller.runJavaScriptReturningResult(
            'document.querySelector("a[href*=\\"/comic/\\"]").getAttribute("href");');
        final firstLinkText = await _controller.runJavaScriptReturningResult(
            'document.querySelector("a[href*=\\"/comic/\\"]").textContent.trim();');
        print('첫 번째 만화 링크: $firstLinkHref, 텍스트: $firstLinkText');
      }

      // 회차 목록 관련 추가 선택자 확인
      final viewContentCount = await _controller.runJavaScriptReturningResult(
          'document.querySelectorAll(".view-content").length;');
      print('view-content 요소 수: $viewContentCount');

      final comicWrapCount = await _controller.runJavaScriptReturningResult(
          'document.querySelectorAll(".comic-wrap").length;');
      print('comic-wrap 요소 수: $comicWrapCount');

      // 테이블 구조 확인
      final tableCount = await _controller.runJavaScriptReturningResult(
          'document.querySelectorAll("table").length;');
      print('table 요소 수: $tableCount');

      if (int.parse(tableCount.toString()) > 0) {
        final firstTableClass = await _controller.runJavaScriptReturningResult(
            'document.querySelector("table").className;');
        print('첫 번째 테이블 클래스: $firstTableClass');
      }
    } catch (e) {
      print('HTML 구조 디버깅 오류: $e');
    }
  }

  Future<bool> _handleManatokiCaptcha() async {
    if (!mounted) return false;

    try {
      setState(() {
        _isLoading = true;
      });

      final baseUrl = ref.read(siteUrlServiceProvider); // 동적 URL 사용
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              MangaCaptchaScreen(url: '$baseUrl/comic/$_mangaId'),
        ),
      );

      if (!mounted) return false;

      if (result == true) {
        // 캡챠 인증 성공
        setState(() {
          _isLoading = true;
        });

        // WebView 초기화 및 다시 로드
        _initWebView();
        await _loadMangaDetail();

        return true;
      } else {
        // 캡챠 인증 실패
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = '캡챠 인증에 실패했습니다.';
        });
      }
    } catch (e) {
      if (!mounted) return false;

      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = '캡챠 처리 중 오류가 발생했습니다: $e';
      });
    }

    return false;
  }

  void _handleManatokiCaptchaInWebView() {
    if (!mounted || !_showManatokiCaptcha) return;

    // 최대 60초 동안 캡챠 완료 확인
    int attempts = 0;
    const maxAttempts = 60;

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      attempts++;

      if (!mounted || !_showManatokiCaptcha) {
        return false; // 루프 종료
      }

      try {
        // JavaScript를 사용하여 HTML 내용을 가져옵니다.
        final html = await _controller
            .runJavaScriptReturningResult('document.documentElement.outerHTML');
        final htmlStr = html.toString();

        // 캡챠가 더 이상 필요하지 않은지 확인
        if (!ManatokiCaptchaHelper.isCaptchaRequired(htmlStr)) {
          print('캡챠가 완료되었습니다. 만화 상세 정보를 다시 로드합니다.');

          if (mounted) {
            setState(() {
              _showManatokiCaptcha = false;
              _isLoading = true;
            });
            await _getHtmlContent();
          }

          return false; // 루프 종료
        }
      } catch (e) {
        print('캡챠 확인 중 오류: $e');
      }

      // 최대 시도 횟수 초과 시 종료
      if (attempts >= maxAttempts) {
        print('캡챠 완료 확인 시간 초과');

        // 페이지 새로고침 시도
        try {
          await _controller.reload();
        } catch (e) {
          print('페이지 새로고침 오류: $e');
        }

        return false; // 루프 종료
      }

      return true; // 루프 계속
    });
  }

  void _retryAfterCaptcha() {
    if (!mounted) return;

    setState(() {
      _showManatokiCaptcha = false;
      _captchaInfo = null;
      _isLoading = true;
    });

    // 페이지 다시 로드
    try {
      _loadMangaDetail();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = '캡챠 인증에 실패했습니다.';
      });
    }
  }

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      // 먼저 탭 상태를 변경
      ref.read(selectedTabProvider.notifier).state = index;
      // 그 다음 네비게이션 수행
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  // 회차의 이미지 URL 목록을 가져오는 함수
  Future<List<String>> _getChapterImageUrls(String chapterId) async {
    try {
      final baseUrl = ref.read(siteUrlServiceProvider);
      final url = '$baseUrl/comic/$chapterId';

      print('[이미지 파싱] URL: $url');

      // 쿠키 가져오기
      final jar = ref.read(globalCookieJarProvider);
      final cookies = await jar.loadForRequest(Uri.parse(url));
      final cookieString =
          cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');

      // HTTP 요청 보내기
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Cookie': cookieString,
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
          'Referer': baseUrl,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('페이지를 불러올 수 없습니다. (${response.statusCode})');
      }

      final document = html_parser.parse(response.body);
      final imageUrls = <String>[];

      // 다양한 선택자로 이미지 찾기
      final imgContainers = [
        ...document.querySelectorAll('.view-content img'), // 뷰어 컨텐츠 내 이미지
        ...document
            .querySelectorAll('.comicdetail img'), // comicdetail 클래스 내 이미지
        ...document
            .querySelectorAll('article[itemprop="articleBody"] img'), // 본문 이미지
        ...document.querySelectorAll('.post-content img'), // post-content 내 이미지
        ...document
            .querySelectorAll('.entry-content img'), // entry-content 내 이미지
        ...document.querySelectorAll('.comic-images img'), // comic-images 내 이미지
        ...document.querySelectorAll('.manga-images img'), // manga-images 내 이미지
        ...document
            .querySelectorAll('.chapter-content img'), // chapter-content 내 이미지
      ];

      print('[이미지 파싱] HTML 구조 분석:');
      print('- 전체 HTML 길이: ${response.body.length}');
      print('- 이미지 태그 총 개수: ${document.querySelectorAll('img').length}');
      print('- 선택자별 이미지 개수:');
      print(
          '  * .view-content img: ${document.querySelectorAll('.view-content img').length}');
      print(
          '  * .comicdetail img: ${document.querySelectorAll('.comicdetail img').length}');
      print(
          '  * article[itemprop="articleBody"] img: ${document.querySelectorAll('article[itemprop="articleBody"] img').length}');
      print(
          '  * .post-content img: ${document.querySelectorAll('.post-content img').length}');
      print(
          '  * .entry-content img: ${document.querySelectorAll('.entry-content img').length}');
      print(
          '  * .comic-images img: ${document.querySelectorAll('.comic-images img').length}');
      print(
          '  * .manga-images img: ${document.querySelectorAll('.manga-images img').length}');
      print(
          '  * .chapter-content img: ${document.querySelectorAll('.chapter-content img').length}');

      print('[이미지 파싱] 찾은 이미지 태그 개수: ${imgContainers.length}');

      for (var img in imgContainers) {
        String? imageUrl;
        final attributes = img.attributes;

        print('\n[이미지 파싱] 이미지 태그 분석:');
        print('- 클래스: ${attributes['class']}');
        print('- src: ${attributes['src']}');
        print('- data-original: ${attributes['data-original']}');
        print('- data-src: ${attributes['data-src']}');

        // data- 속성 모두 확인
        final dataAttributes = attributes.entries
            .where((attr) =>
                (attr.key as String).startsWith('data-') &&
                attr.value.isNotEmpty)
            .map((attr) => attr.value)
            .toList();

        print('- data- 속성들: $dataAttributes');

        // 1. data- 속성 확인
        if (dataAttributes.isNotEmpty) {
          for (var attr in dataAttributes) {
            if (!attr.contains('loading-image.gif')) {
              imageUrl = attr;
              print('- data- 속성에서 URL 발견: $imageUrl');
              break;
            }
          }
        }

        // 2. data-original 속성 확인
        if (imageUrl == null || imageUrl.isEmpty) {
          final dataOriginal = attributes['data-original'];
          if (dataOriginal != null &&
              dataOriginal.isNotEmpty &&
              !dataOriginal.contains('loading-image.gif')) {
            imageUrl = dataOriginal;
            print('- data-original에서 URL 발견: $imageUrl');
          }
        }

        // 3. data-src 속성 확인
        if (imageUrl == null || imageUrl.isEmpty) {
          final dataSrc = attributes['data-src'];
          if (dataSrc != null &&
              dataSrc.isNotEmpty &&
              !dataSrc.contains('loading-image.gif')) {
            imageUrl = dataSrc;
            print('- data-src에서 URL 발견: $imageUrl');
          }
        }

        // 4. src 속성 확인
        if (imageUrl == null || imageUrl.isEmpty) {
          final src = attributes['src'];
          if (src != null &&
              src.isNotEmpty &&
              !src.contains('loading-image.gif')) {
            imageUrl = src;
            print('- src에서 URL 발견: $imageUrl');
          }
        }

        // URL이 발견되었고 광고나 배너가 아닌 경우에만 추가
        if (imageUrl != null &&
            imageUrl.isNotEmpty &&
            !imageUrl.contains('loading-image.gif') &&
            !imageUrl.contains('banner') &&
            !imageUrl.contains('ads')) {
          // 상대 경로를 절대 경로로 변환
          if (!imageUrl.startsWith('http')) {
            imageUrl = imageUrl.startsWith('/')
                ? baseUrl + imageUrl
                : '$baseUrl/$imageUrl';
          }

          // URL이 유효한지 확인
          try {
            final uri = Uri.parse(imageUrl);
            if (uri.hasScheme && uri.host.isNotEmpty) {
              print('[이미지 파싱] 유효한 이미지 URL 추가: $imageUrl');
              imageUrls.add(imageUrl);
            }
          } catch (e) {
            print('[이미지 파싱] 유효하지 않은 이미지 URL: $imageUrl (에러: $e)');
            continue;
          }
        } else {
          print('[이미지 파싱] 이미지 URL 필터링됨: $imageUrl');
        }
      }

      print('[이미지 파싱] 추출된 이미지 URL 개수: ${imageUrls.length}');

      if (imageUrls.isEmpty) {
        print('[이미지 파싱] HTML 내용 확인:');
        print(response.body.substring(0, min(1000, response.body.length)));
        throw Exception('이미지를 찾을 수 없습니다.');
      }

      return imageUrls;
    } catch (e, stack) {
      print('이미지 URL 가져오기 실패: $e');
      print('스택 트레이스: $stack');
      rethrow;
    }
  }

  // 이미지 다운로드 함수
  Future<Uint8List?> _downloadImage(String url) async {
    try {
      print('[이미지 다운로드] 시작: $url');
      final jar = ref.read(globalCookieJarProvider);
      final cookies = await jar.loadForRequest(Uri.parse(url));
      final cookieString =
          cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');

      final headers = {
        'Cookie': cookieString,
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Referer': ref.read(siteUrlServiceProvider),
      };

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode != 200) {
        print('[이미지 다운로드] 실패 - 상태 코드: ${response.statusCode}');
        return null;
      }

      print('[이미지 다운로드] 성공 - 크기: ${response.bodyBytes.length} bytes');
      return response.bodyBytes;
    } catch (e, stack) {
      print('[이미지 다운로드] 실패: $e');
      print('[이미지 다운로드] 스택 트레이스: $stack');
      return null;
    }
  }

  // PDF 파일 생성 함수
  Future<File?> _createPdf(String chapterId, String chapterTitle) async {
    try {
      final imageUrls = await _getChapterImageUrls(chapterId);
      if (imageUrls.isEmpty) {
        throw Exception('이미지를 찾을 수 없습니다.');
      }

      final pdf = pw.Document();
      final images = <Uint8List>[];

      // 각 이미지 다운로드
      for (var i = 0; i < imageUrls.length; i++) {
        final imageUrl = imageUrls[i];
        final imageBytes = await _downloadImage(imageUrl);
        if (imageBytes != null) {
          images.add(imageBytes);
        }
      }

      // 다운로드된 이미지가 없으면 에러
      if (images.isEmpty) {
        throw Exception('이미지 다운로드에 실패했습니다.');
      }

      // 각 이미지를 PDF 페이지로 변환
      for (var imageBytes in images) {
        final image = pw.MemoryImage(imageBytes);
        pdf.addPage(
          pw.Page(
            build: (context) {
              return pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              );
            },
          ),
        );
      }

      // PDF 파일 저장
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$chapterTitle.pdf');
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      print('PDF 생성 실패: $e');
      return null;
    }
  }

  // ZIP 파일 생성 함수
  Future<File?> _createZipFile(String title, List<File> files) async {
    try {
      final archive = Archive();

      for (var file in files) {
        final bytes = await file.readAsBytes();
        final archiveFile = ArchiveFile(
          file.path.split('/').last,
          bytes.length,
          bytes,
        );
        archive.addFile(archiveFile);
      }

      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) return null;

      final tempDir = await getTemporaryDirectory();
      final zipFile = File('${tempDir.path}/$title.zip');
      await zipFile.writeAsBytes(zipData);

      return zipFile;
    } catch (e) {
      print('ZIP 파일 생성 실패: $e');
      return null;
    }
  }

  // 선택된 회차 저장 함수 수정
  Future<void> _saveSelectedChapters() async {
    if (_selectedChapters.isEmpty || _mangaDetail == null) return;

    setState(() {
      _isSaving = true;
      _showSaveDialog = false;
    });

    try {
      final selectedChaptersList = _mangaDetail!.chapters
          .where((chapter) => _selectedChapters.contains(chapter.id))
          .toList();

      if (selectedChaptersList.isEmpty) return;

      // 단일 회차인 경우
      if (selectedChaptersList.length == 1) {
        final chapter = selectedChaptersList.first;
        final imageUrls = await _getChapterImageUrls(chapter.id);

        if (imageUrls.isEmpty) {
          throw Exception('이미지를 찾을 수 없습니다.');
        }

        final images = <Uint8List>[];
        for (var url in imageUrls) {
          final imageData = await _downloadImage(url);
          if (imageData != null) {
            images.add(imageData);
          }
        }

        if (images.isEmpty) {
          throw Exception('이미지 다운로드에 실패했습니다.');
        }

        final pdfFile = await _createPdf(chapter.id, chapter.title);
        if (pdfFile != null) {
          await Share.shareXFiles([XFile(pdfFile.path)]);
        }
      }
      // 다중 회차인 경우
      else {
        final tempDir = await getTemporaryDirectory();
        final pdfs = <File>[];

        for (var chapter in selectedChaptersList) {
          final imageUrls = await _getChapterImageUrls(chapter.id);
          if (imageUrls.isNotEmpty) {
            final images = <Uint8List>[];
            for (var url in imageUrls) {
              final imageData = await _downloadImage(url);
              if (imageData != null) {
                images.add(imageData);
              }
            }
            if (images.isNotEmpty) {
              final pdfFile = await _createPdf(chapter.id, chapter.title);
              if (pdfFile != null) {
                pdfs.add(pdfFile);
              }
            }
          }
        }

        if (pdfs.isEmpty) {
          throw Exception('PDF 생성에 실패했습니다.');
        }

        // ZIP 파일 생성
        final zipFile = await _createZipFile(_mangaDetail!.title, pdfs);
        if (zipFile != null) {
          await Share.shareXFiles([XFile(zipFile.path)]);
        } else {
          throw Exception('ZIP 파일 생성에 실패했습니다.');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _selectedChapters.clear();
        });
      }
    }
  }

  // 단일 회차 저장 함수
  Future<void> _saveSingleChapter(MangaChapter chapter) async {
    if (_isDownloading) return;
    _isDownloading = true;

    try {
      await _showProgressNotification(
        '다운로드 시작',
        '${_mangaDetail!.title} - ${chapter.title} 다운로드를 시작합니다.',
      );

      final pdfFile = await _createPdf(chapter.id, chapter.title);
      if (pdfFile != null) {
        await _showProgressNotification(
          '다운로드 완료',
          '${_mangaDetail!.title} - ${chapter.title} 다운로드가 완료되었습니다.',
        );
        await Share.shareXFiles([XFile(pdfFile.path)]);
        await pdfFile.delete();
      }
    } catch (e) {
      await _showProgressNotification(
        '다운로드 실패',
        '${_mangaDetail!.title} - ${chapter.title} 다운로드 중 오류가 발생했습니다.',
      );
      print('단일 회차 저장 실패: $e');
    } finally {
      _isDownloading = false;
    }
  }

  // 여러 회차 저장 함수
  Future<void> _saveMultipleChapters(List<MangaChapter> chapters) async {
    if (_isDownloading) return;
    _isDownloading = true;

    try {
      final pdfs = <File>[];
      final total = chapters.length;

      await _showProgressNotification(
        '다운로드 시작',
        '${_mangaDetail!.title} - 총 $total 회차 다운로드를 시작합니다.',
      );

      for (var i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        await _showProgressNotification(
          '다운로드 진행 중',
          '${_mangaDetail!.title} - ${i + 1}/$total 회차 다운로드 중',
        );

        final pdfFile = await _createPdf(chapter.id, chapter.title);
        if (pdfFile != null) {
          pdfs.add(pdfFile);
        }
      }

      if (pdfs.isNotEmpty) {
        await _showProgressNotification(
          'ZIP 파일 생성 중',
          '${_mangaDetail!.title} - ZIP 파일을 생성하고 있습니다.',
        );

        final archive = Archive();
        for (final pdf in pdfs) {
          final bytes = await pdf.readAsBytes();
          archive.addFile(
            ArchiveFile(pdf.path.split('/').last, bytes.length, bytes),
          );
        }

        final dir = await getTemporaryDirectory();
        final zipFile = File('${dir.path}/${_mangaDetail!.title}.zip');
        await zipFile.writeAsBytes(ZipEncoder().encode(archive)!);

        await _showProgressNotification(
          '다운로드 완료',
          '${_mangaDetail!.title} - 다운로드가 완료되었습니다.',
        );

        await Share.shareXFiles([XFile(zipFile.path)]);

        // 임시 파일 정리
        for (final pdf in pdfs) {
          await pdf.delete();
        }
        await zipFile.delete();
      }
    } catch (e) {
      await _showProgressNotification(
        '다운로드 실패',
        '${_mangaDetail!.title} - 다운로드 중 오류가 발생했습니다.',
      );
      print('여러 회차 저장 실패: $e');
    } finally {
      _isDownloading = false;
    }
  }

  // 회차 선택 다이얼로그를 표시하는 함수
  Future<void> _showChapterSelectionDialog() async {
    if (_mangaDetail == null) return;

    final selectedChapters = <MangaChapter>{};
    bool selectAll = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('저장할 회차 선택'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 전체 선택 버튼
                    CheckboxListTile(
                      title: const Text('전체 선택'),
                      value: selectAll,
                      onChanged: (bool? value) {
                        setState(() {
                          selectAll = value ?? false;
                          if (selectAll) {
                            selectedChapters.addAll(_mangaDetail!.chapters);
                          } else {
                            selectedChapters.clear();
                          }
                        });
                      },
                    ),
                    const Divider(),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _mangaDetail!.chapters.length,
                        itemBuilder: (context, index) {
                          final chapter = _mangaDetail!.chapters[index];
                          return CheckboxListTile(
                            title: Text(chapter.title),
                            value: selectedChapters.contains(chapter),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value ?? false) {
                                  selectedChapters.add(chapter);
                                } else {
                                  selectedChapters.remove(chapter);
                                }
                                selectAll = selectedChapters.length ==
                                    _mangaDetail!.chapters.length;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (selectedChapters.length == 1) {
                      _saveSingleChapter(selectedChapters.first);
                    } else if (selectedChapters.length > 1) {
                      _saveMultipleChapters(selectedChapters.toList());
                    }
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _checkLikeStatus() async {
    if (widget.mangaId != null && _mangaDetail != null) {
      final isLiked = await _db.isLiked(widget.mangaId!);
      if (mounted) {
        setState(() {
          _mangaDetail = _mangaDetail!.copyWith(isLiked: isLiked);
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    if (widget.mangaId != null && _mangaDetail != null) {
      final newLikeStatus = !(_mangaDetail!.isLiked);

      if (newLikeStatus) {
        await _db.insertLike(
          widget.mangaId!,
          _mangaDetail!.title,
          _mangaDetail!.author.isEmpty ? '작가 미상' : _mangaDetail!.author,
          _mangaDetail!.thumbnailUrl,
          _mangaDetail!.genres,
        );
      } else {
        await _db.removeLike(widget.mangaId!);
      }

      if (mounted) {
        setState(() {
          _mangaDetail = _mangaDetail!.copyWith(isLiked: newLikeStatus);
        });
      }
    }
  }

  Future<void> _initializeNotifications() async {
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initializationSettings = InitializationSettings(
      iOS: initializationSettingsIOS,
    );
    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showProgressNotification(String title, String body) async {
    const notificationDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
      ),
    );

    await _notificationsPlugin.show(
      0, // notification id
      title,
      body,
      notificationDetails,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_mangaDetail?.title ?? ''),
        actions: [
          // 저장 버튼
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _showChapterSelectionDialog,
          ),
          // 좋아요 버튼
          IconButton(
            icon: Icon(
              _mangaDetail?.isLiked ?? false
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: _mangaDetail?.isLiked ?? false ? Colors.red : null,
            ),
            onPressed: _toggleLike,
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView 완전 제거 (숨김 처리 및 디버깅용 모두 삭제)
          // 실제 사용자에게 보이는 내용만 남김
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : _isError
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(_errorMessage, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadMangaDetail,
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    )
                  : _showManatokiCaptcha && _captchaInfo != null
                      ? ManatokiCaptchaWidget(
                          captchaInfo: _captchaInfo!,
                          onSuccess: _retryAfterCaptcha,
                        )
                      : _buildTestContent(),

          // 저장 다이얼로그
          if (_showSaveDialog) _buildSaveDialog(),

          // 저장 중 로딩 인디케이터
          if (_isSaving)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      '저장 중...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: '검색',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: '최근',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: '좋아요',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline),
            selectedIcon: Icon(Icons.bookmark),
            label: '저장',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }

  Widget _buildTestContent() {
    // 만화 상세 정보가 없는 경우 안내 메시지
    if (_mangaDetail == null) {
      return const Center(child: Text('만화 상세 정보를 불러올 수 없습니다.'));
    }
    // 회차 목록이 없을 경우 안내 메시지
    if (_mangaDetail!.chapters.isEmpty) {
      return const Center(child: Text('회차 목록이 없습니다.'));
    }
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 타이틀 및 썸네일
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 썸네일
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _mangaDetail!.thumbnailUrl,
                        width: 120,
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(
                          width: 120,
                          height: 160,
                          child: Center(
                            child: Icon(Icons.error_outline),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 제목 및 정보
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _mangaDetail!.title,
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                              Icons.person,
                              '작가',
                              _mangaDetail!.author.isEmpty
                                  ? '정보 없음'
                                  : _mangaDetail!.author),
                          _buildInfoRow(Icons.category, '분류', ''),
                          Wrap(
                            spacing: 6,
                            runSpacing: 2,
                            children: _mangaDetail!.genres.isNotEmpty
                                ? _mangaDetail!.genres
                                    .map((g) => Chip(
                                          label: Text(g,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                      color: theme.colorScheme
                                                          .onPrimary)),
                                          backgroundColor:
                                              theme.colorScheme.primary,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 0),
                                        ))
                                    .toList()
                                : [
                                    Text('정보 없음',
                                        style: theme.textTheme.bodyMedium)
                                  ],
                          ),
                          _buildInfoRow(
                              Icons.book,
                              '발행상태',
                              _mangaDetail!.releaseStatus.isEmpty
                                  ? '정보 없음'
                                  : _mangaDetail!.releaseStatus),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // 회차 정보
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('회차 목록', style: theme.textTheme.titleMedium),
                    if (_mangaDetail?.chapters.isNotEmpty == true)
                      TextButton.icon(
                        onPressed: () {
                          // 마지막 회차(첫화)로 이동
                          final firstChapter = _mangaDetail!.chapters.last;
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      MangaViewerScreen(
                                chapterId: firstChapter.id,
                                title: firstChapter.title,
                                thumbnailUrl: _mangaDetail?.thumbnailUrl,
                              ),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                              transitionDuration:
                                  const Duration(milliseconds: 300),
                            ),
                          );
                        },
                        icon: const Icon(Icons.first_page),
                        label: const Text('첫화 보기'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(),
                // 회차 목록
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _mangaDetail!.chapters.length,
                  separatorBuilder: (context, index) => Divider(
                      height: 1, color: theme.dividerColor.withOpacity(0.2)),
                  itemBuilder: (context, index) {
                    final chapter = _mangaDetail!.chapters[index];
                    final chapterNumber = _mangaDetail!.chapters.length - index;
                    final rating = chapter.rating / 10.0;
                    String formattedViews = chapter.views.toString();
                    if (chapter.views >= 10000) {
                      formattedViews =
                          '${(chapter.views / 10000).toStringAsFixed(1)}만';
                    } else if (chapter.views >= 1000) {
                      formattedViews =
                          '${(chapter.views / 1000).toStringAsFixed(1)}천';
                    }
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          print(
                              '뷰어 진입: chapter.id=${chapter.id}, title=${chapter.title}, fullViewUrl=${chapter.fullViewUrl}');
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      MangaViewerScreen(
                                chapterId: chapter.id,
                                title: chapter.title,
                                thumbnailUrl: _mangaDetail?.thumbnailUrl,
                              ),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                              transitionDuration:
                                  const Duration(milliseconds: 300),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    chapterNumber.toString(),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      chapter.title,
                                      style: theme.textTheme.titleMedium,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today,
                                            size: 14,
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.6)),
                                        const SizedBox(width: 4),
                                        Text(
                                          chapter.uploadDate,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Icon(Icons.visibility,
                                            size: 14,
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.6)),
                                        const SizedBox(width: 4),
                                        Text(
                                          formattedViews,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Icon(Icons.comment,
                                            size: 14,
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.6)),
                                        const SizedBox(width: 4),
                                        Text(
                                          chapter.comments.toString(),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Icon(Icons.thumb_up,
                                            size: 14,
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.6)),
                                        const SizedBox(width: 4),
                                        Text(
                                          chapter.likes.toString(),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Icon(Icons.star,
                                            size: 14, color: Colors.amber),
                                        const SizedBox(width: 4),
                                        Text(
                                          rating.toStringAsFixed(1),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text('$label: ',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveDialog() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '저장할 회차 선택',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _showSaveDialog = false;
                          _selectedChapters.clear();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: _mangaDetail?.chapters.length ?? 0,
                    itemBuilder: (context, index) {
                      final chapter = _mangaDetail!.chapters[index];
                      return CheckboxListTile(
                        title: Text(chapter.title),
                        value: _selectedChapters.contains(chapter.id),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedChapters.add(chapter.id);
                            } else {
                              _selectedChapters.remove(chapter.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showSaveDialog = false;
                          _selectedChapters.clear();
                        });
                      },
                      child: const Text('취소'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _selectedChapters.isEmpty
                          ? null
                          : _saveSelectedChapters,
                      child: const Text('저장'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
