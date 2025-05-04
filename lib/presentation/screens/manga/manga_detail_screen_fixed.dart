import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:html/parser.dart' as html_parser;
import '../../../data/models/manga_detail.dart';
import '../../../data/providers/site_url_provider.dart';
import '../../../utils/manga_detail_parser.dart';
import '../../../utils/manatoki_captcha_helper.dart';
import '../../../utils/cookie_utils.dart';
import '../../../utils/network_image_with_headers.dart';
import '../../widgets/manatoki_captcha_widget.dart';
import '../../viewmodels/global_cookie_provider.dart';
import '../../viewmodels/cookie_sync_utils.dart';
import '../manga/manga_captcha_screen.dart';
import 'dart:io' show Cookie;

class MangaDetailScreen extends ConsumerStatefulWidget {
  final String url;
  final String? mangaId;
  final String? title;
  const MangaDetailScreen({Key? key, required this.url, this.mangaId, this.title}) : super(key: key);

  @override
  ConsumerState<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends ConsumerState<MangaDetailScreen> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  String _htmlContent = '';
  MangaDetail? _mangaDetail;
  bool _showManatokiCaptcha = false;
  ManatokiCaptchaInfo? _captchaInfo;
  String get _mangaId => widget.mangaId ?? '22551218'; // 기본값 설정
  
  @override
  void initState() {
    super.initState();
    _initWebView();
    _loadMangaDetail();
  }
  
  @override
  void dispose() {
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
      
      final baseUrl = ref.read(siteUrlServiceProvider); // 동적 URL 사용
      final jar = ref.read(globalCookieJarProvider);
      
      // 만화 상세 페이지 로드
      // baseUrl에서 끝에 슬래시가 있으면 제거
      final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final url = '$cleanBaseUrl/comic/$_mangaId';
      print('만화 상세 페이지 로드: $url');
      await _controller.loadRequest(Uri.parse(url));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = '데이터를 불러오는 중 오류가 발생했습니다: $e';
      });
    }
  }

  // 캡챠 인증 후 페이지를 완전히 새로고침
  Future<void> _retryAfterCaptcha() async {
    print('캡챠 인증 후 페이지 다시 로드 시작');
    setState(() {
      _showManatokiCaptcha = false;
      _isLoading = true;
      _captchaInfo = null; // 캡챠 정보 초기화
    });
    
    try {
      // 쿠키 정보 확인
      final baseUrl = ref.read(siteUrlServiceProvider);
      final cookieJar = ref.read(globalCookieJarProvider);
      final uri = Uri.parse(baseUrl);
      final cookies = await cookieJar.loadForRequest(uri);
      
      print('캡챠 인증 후 사용할 쿠키: ${cookies.map((c) => '${c.name}=${c.value}').join('; ')}');
      
      // PHPSESSID 쿠키 확인
      final phpSessionCookie = cookies.firstWhere(
        (cookie) => cookie.name == 'PHPSESSID',
        orElse: () => Cookie('PHPSESSID', ''),
      );
      
      if (phpSessionCookie.value.isNotEmpty) {
        print('PHPSESSID 쿠키 발견: ${phpSessionCookie.value}');
      } else {
        print('PHPSESSID 쿠키가 없습니다!');
      }
      
      // 웹뷰 컨트롤러 새로 초기화
      _initWebView();
      
      // 웹뷰에 쿠키 설정
      await _setupWebViewCookies(cookies);
      
      // 약간의 지연 후 로드 (쿠키 적용 시간 확보)
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // 만화 상세 페이지 URL 생성
      final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final url = '$cleanBaseUrl/comic/$_mangaId';
      print('만화 상세 페이지 로드: $url');
      
      // 웹뷰 로드
      await _controller.loadRequest(Uri.parse(url));
      
      // 일정 시간 후 로딩 상태 확인
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isLoading) {
          _getHtmlContent(); // HTML 콘텐츠 가져오기
        }
      });
    } catch (e) {
      print('캡챠 인증 후 페이지 로드 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = '캡챠 인증 후 페이지 로드에 실패했습니다: $e';
        });
      }
    }
  }
  
  // 웹뷰에 쿠키 설정
  Future<void> _setupWebViewCookies(List<Cookie> cookies) async {
    try {
      // 웹뷰에 쿠키 설정
      for (final cookie in cookies) {
        // 쿠키 유효성 확인
        if (cookie.name.isEmpty) continue;
        
        // 도메인 설정
        String domain = cookie.domain ?? '';
        if (domain.isEmpty) {
          final baseUrl = ref.read(siteUrlServiceProvider);
          domain = Uri.parse(baseUrl).host;
        }
        
        // 경로 설정
        String path = cookie.path ?? '/';
        
        print('웹뷰에 쿠키 설정: ${cookie.name}=${cookie.value} (도메인: $domain, 경로: $path)');
        
        // 웹뷰에 쿠키 설정
        await _controller.runJavaScript(
          "document.cookie='${cookie.name}=${cookie.value}; path=$path; domain=$domain';"
        );
      }
      
      // 쿠키 설정 확인
      final cookieResult = await _controller.runJavaScriptReturningResult('document.cookie');
      print('웹뷰 쿠키 설정 후: $cookieResult');
    } catch (e) {
      print('웹뷰 쿠키 설정 오류: $e');
    }
  }

  Future<void> _getHtmlContent() async {
    if (!mounted) return;
    
    try {
      // 페이지 로드 후 약간의 지연 추가 (JavaScript 실행 시간 고려)
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // 현재 URL 출력
      final currentUrl = await _controller.currentUrl();
      print('현재 WebView URL: $currentUrl');
      
      // HTML 가져오기 - 안전하게 처리
      String htmlStr = '';
      try {
        final html = await _controller.runJavaScriptReturningResult('document.documentElement.outerHTML');
        if (html != null) {
          htmlStr = html.toString();
          // 크기 제한을 위해 최대 길이 제한
          if (htmlStr.length > 500000) {
            print('매우 큰 HTML 감지. 잘라냄: ${htmlStr.length} -> 500000');
            htmlStr = htmlStr.substring(0, 500000);
          }
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
      
      // 디버그용 - HTML 일부 출력
      print('HTML 미리보기: ${htmlStr.substring(0, htmlStr.length > 300 ? 300 : htmlStr.length)}...');
      
      // 마나토끼 캡챠 확인
      try {
        // 캡챠 페이지 키워드 확인
        final hasCaptchaKeyword = htmlStr.contains('캡챠 인증') || 
                                  htmlStr.contains('captcha') || 
                                  htmlStr.contains('kcaptcha') ||
                                  htmlStr.contains('fcaptcha');
        
        if (hasCaptchaKeyword && ManatokiCaptchaHelper.isCaptchaRequired(htmlStr)) {
          print('마나토끼 캡챠 감지됨: 캡챠 처리를 시작합니다.');
          
          // 캡챠 정보 추출
          final baseUrl = ref.read(siteUrlServiceProvider);
          final captchaInfo = ManatokiCaptchaHelper.extractCaptchaInfo(htmlStr, baseUrl);
          
          if (captchaInfo != null) {
            print('캡챠 정보 추출 성공: ${captchaInfo.captchaImageUrl}');
            setState(() {
              _showManatokiCaptcha = true;
              _captchaInfo = captchaInfo;
              _isLoading = false;
            });
            return;
          } else {
            print('캡챠 정보 추출 실패');
          }
        } else {
          print('캡챠 필요 없음');
        }
      } catch (e) {
        print('캡챠 확인 오류: $e');
      }
      
      // HTML 파싱 시작
      print('만화 상세 페이지 HTML 파싱 시작: $_mangaId');
      try {
        _htmlContent = htmlStr;
        
        // HTML 파싱
        final result = parseMangaDetailFromHtml(htmlStr, _mangaId);
        
        if (result.hasCaptcha) {
          print('파싱 결과: 캡챠 필요');
          final baseUrl = ref.read(siteUrlServiceProvider);
          final captchaInfo = ManatokiCaptchaHelper.extractCaptchaInfo(htmlStr, baseUrl);
          
          if (captchaInfo != null) {
            setState(() {
              _showManatokiCaptcha = true;
              _captchaInfo = captchaInfo;
              _isLoading = false;
            });
            return;
          } else {
            // 캡챠 정보를 추출할 수 없으면 웹뷰 상태로 유지
            setState(() {
              _isLoading = false;
              _showManatokiCaptcha = false;
            });
          }
        } else {
          setState(() {
            _mangaDetail = result.mangaDetail;
            _isLoading = false;
            print('파싱 결과: ${_mangaDetail?.title}');
          });
        }
      } catch (e) {
        print('HTML 파싱 오류: $e');
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = 'HTML 파싱 중 오류가 발생했습니다: $e';
        });
      }
    } catch (e) {
      print('전체 _getHtmlContent 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = '데이터 처리 중 오류가 발생했습니다: $e';
        });
      }
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text('$label: ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildTestContent() {
    // 만화 상세 정보가 없는 경우 테스트 데이터 추가
    if (_mangaDetail == null) {
      return const Center(child: Text('만화 상세 정보를 불러올 수 없습니다.'));
    }
    
    // 회차 목록이 없을 경우 테스트 데이터 추가
    if (_mangaDetail!.chapters.isEmpty) {
      print('회차 목록이 없습니다. 테스트 데이터를 추가합니다.');
      
      // 테스트 데이터 추가
      _mangaDetail = MangaDetail(
        id: _mangaDetail!.id,
        title: _mangaDetail!.title,
        thumbnailUrl: _mangaDetail!.thumbnailUrl,
        author: _mangaDetail!.author.isEmpty ? '드래곤볼 작가' : _mangaDetail!.author,
        genre: _mangaDetail!.genre.isEmpty ? '액션, 판타지' : _mangaDetail!.genre,
        releaseStatus: _mangaDetail!.releaseStatus.isEmpty ? '연재중' : _mangaDetail!.releaseStatus,
        chapters: [
          MangaChapter(
            id: '123456',
            title: '드래곤볼 슈퍼 104-2화',
            uploadDate: '2023-05-01',
            views: 12500,
            rating: 49,
            likes: 350,
            comments: 25,
          ),
          MangaChapter(
            id: '123455',
            title: '드래곤볼 슈퍼 104-1화',
            uploadDate: '2023-04-25',
            views: 15000,
            rating: 48,
            likes: 420,
            comments: 32,
          ),
          MangaChapter(
            id: '123454',
            title: '드래곤볼 슈퍼 103화',
            uploadDate: '2023-04-18',
            views: 18000,
            rating: 50,
            likes: 520,
            comments: 45,
          ),
        ],
      );
    }
    
    final theme = Theme.of(context);
    
    return Column(
      children: [
        // 웹뷰 (디버깅용)
        SizedBox(
          height: 200,
          child: WebViewWidget(controller: _controller),
        ),
        
        // 만화 정보
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
                    Container(
                      width: 120,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _mangaDetail!.thumbnailUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FutureBuilder<String?>(
                                future: getCookieString(ref.read(globalCookieJarProvider), _mangaDetail!.thumbnailUrl),
                                builder: (context, snapshot) {
                                  return NetworkImageWithHeaders(
                                    url: _mangaDetail!.thumbnailUrl,
                                    cookie: snapshot.data,
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            )
                          : const Center(child: Icon(Icons.image_not_supported, size: 40)),
                    ),
                    const SizedBox(width: 16),
                    // 정보
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _mangaDetail!.title,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(Icons.person, '작가', _mangaDetail!.author),
                          _buildInfoRow(Icons.category, '장르', _mangaDetail!.genre),
                          _buildInfoRow(Icons.info_outline, '상태', _mangaDetail!.releaseStatus),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // 회차 목록 헤더
                Text(
                  '회차 목록',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Divider(),
                
                // 회차 목록
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _mangaDetail!.chapters.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final chapter = _mangaDetail!.chapters[index];
                    return ListTile(
                      title: Text(chapter.title),
                      subtitle: Text('조회수: ${chapter.views} | 평점: ${chapter.rating} | 댓글: ${chapter.comments}'),
                      trailing: Text(chapter.uploadDate),
                      onTap: () {
                        // 회차 상세 페이지로 이동
                        print('회차 선택: ${chapter.title}');
                      },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? _mangaDetail?.title ?? '만화 상세'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMangaDetail,
          ),
        ],
      ),
      body: _showManatokiCaptcha && _captchaInfo != null
          ? ManatokiCaptchaWidget(
              captchaInfo: _captchaInfo!,
              onCaptchaComplete: (success) {
                if (success) {
                  print('캡챠 인증 성공, 페이지 다시 로드 시작');
                  // 레거시 앱처럼 페이지 새로고침 방식 사용
                  _retryAfterCaptcha();
                } else {
                  Navigator.of(context).pop(); // 취소 시 뒤로 가기
                }
              },
            )
          : _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : _isError
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
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
                  : _buildTestContent(),
    );
  }
}
