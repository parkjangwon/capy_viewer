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

class MangaDetailTestScreen extends ConsumerStatefulWidget {
  final String? mangaId;
  const MangaDetailTestScreen({Key? key, this.mangaId}) : super(key: key);

  @override
  ConsumerState<MangaDetailTestScreen> createState() => _MangaDetailTestScreenState();
}

class _MangaDetailTestScreenState extends ConsumerState<MangaDetailTestScreen> {
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
      final jar = ref.read(globalCookieJarProvider); // globalCookieJarProvider는 이미 정의되어 있다고 가정
      
      // 쿠키 동기화 생략 (WebView에 직접 접근하기 때문에 필요 없음)
      // await syncDioCookiesToWebView(baseUrl, jar);
      
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
      
      // 마나토끼 캡챠 확인
      try {
        if (ManatokiCaptchaHelper.isCaptchaRequired(htmlStr)) {
          print('마나토끼 캡챠 감지됨: 웹뷰로 캡챠 처리를 시작합니다.');
          
          // 캡챠 정보 추출
          final baseUrl = ref.read(siteUrlServiceProvider);
          final captchaInfo = ManatokiCaptchaHelper.extractCaptchaInfo(htmlStr, baseUrl);
          
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
        _htmlContent = htmlStr;
        
        // HTML 파싱
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
      final bodyClass = await _controller.runJavaScriptReturningResult(
        'document.body.className;'
      );
      print('Body 클래스: $bodyClass');
      
      // 회차 목록 관련 요소 확인
      final serialListCount = await _controller.runJavaScriptReturningResult(
        'document.querySelectorAll(".serial-list").length;'
      );
      print('serial-list 요소 수: $serialListCount');
      
      final listWrapCount = await _controller.runJavaScriptReturningResult(
        'document.querySelectorAll(".list-wrap").length;'
      );
      print('list-wrap 요소 수: $listWrapCount');
      
      final boardListCount = await _controller.runJavaScriptReturningResult(
        'document.querySelectorAll(".board-list").length;'
      );
      print('board-list 요소 수: $boardListCount');
      
      final comicLinksCount = await _controller.runJavaScriptReturningResult(
        'document.querySelectorAll("a[href*=\\"/comic/\\"]").length;'
      );
      print('만화 관련 링크 수: $comicLinksCount');
      
      // 첫 번째 만화 링크 확인
      if (int.parse(comicLinksCount.toString()) > 0) {
        final firstLinkHref = await _controller.runJavaScriptReturningResult(
          'document.querySelector("a[href*=\\"/comic/\\"]").getAttribute("href");'
        );
        final firstLinkText = await _controller.runJavaScriptReturningResult(
          'document.querySelector("a[href*=\\"/comic/\\"]").textContent.trim();'
        );
        print('첫 번째 만화 링크: $firstLinkHref, 텍스트: $firstLinkText');
      }
      
      // 회차 목록 관련 추가 선택자 확인
      final viewContentCount = await _controller.runJavaScriptReturningResult(
        'document.querySelectorAll(".view-content").length;'
      );
      print('view-content 요소 수: $viewContentCount');
      
      final comicWrapCount = await _controller.runJavaScriptReturningResult(
        'document.querySelectorAll(".comic-wrap").length;'
      );
      print('comic-wrap 요소 수: $comicWrapCount');
      
      // 테이블 구조 확인
      final tableCount = await _controller.runJavaScriptReturningResult(
        'document.querySelectorAll("table").length;'
      );
      print('table 요소 수: $tableCount');
      
      if (int.parse(tableCount.toString()) > 0) {
        final firstTableClass = await _controller.runJavaScriptReturningResult(
          'document.querySelector("table").className;'
        );
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
          builder: (context) => MangaCaptchaScreen(url: '$baseUrl/comic/$_mangaId'),
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
        final html = await _controller.runJavaScriptReturningResult('document.documentElement.outerHTML');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('작품 상세 보기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMangaDetail,
          ),
        ],
      ),
      body: _isLoading
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
              : _showManatokiCaptcha
                  ? _captchaInfo != null
                      ? ManatokiCaptchaWidget(
                          captchaInfo: _captchaInfo!,
                          onCaptchaComplete: (success) {
                            if (success) {
                              _retryAfterCaptcha();
                            }
                          },
                        )
                      : Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('캡챠 인증이 필요합니다. 아래 웹뷰에서 캡챠를 완료해주세요.'),
                            ),
                            Expanded(
                              child: WebViewWidget(controller: _controller),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _showManatokiCaptcha = false;
                                    _isLoading = true;
                                  });
                                  _getHtmlContent();
                                },
                                child: const Text('캡챠 완료 확인'),
                              ),
                            ),
                          ],
                        )
                  : _buildTestContent(),
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _mangaDetail!.thumbnailUrl.isNotEmpty
                            ? NetworkImageWithHeaders(
                                url: _mangaDetail!.thumbnailUrl,
                                width: 120,
                                height: 160,
                                fit: BoxFit.cover,
                              )
                            : const Center(
                                child: Icon(Icons.image_not_supported, size: 48),
                              ),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // 만화 정보
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _mangaDetail!.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(Icons.person, '작가', _mangaDetail!.author.isEmpty ? '정보 없음' : _mangaDetail!.author),
                          _buildInfoRow(Icons.category, '장르', _mangaDetail!.genre.isEmpty ? '정보 없음' : _mangaDetail!.genre),
                          _buildInfoRow(Icons.book, '발행상태', _mangaDetail!.releaseStatus.isEmpty ? '정보 없음' : _mangaDetail!.releaseStatus),
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
                    Text(
                      '${_mangaDetail!.chapters.length}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                
                const Divider(),
                
                // 회차 목록
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _mangaDetail!.chapters.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final chapter = _mangaDetail!.chapters[index];
                    
                    // 회차 번호 계산 (역순)
                    final chapterNumber = _mangaDetail!.chapters.length - index; // 순서대로 번호 부여
                    
                    // 별점 계산 (10점 만점 -> 5점 만점으로 변환)
                    final rating = chapter.rating / 10.0;
                    
                    // 조회수 포맷팅 (1000 -> 1천, 10000 -> 1만)
                    String formattedViews = chapter.views.toString();
                    if (chapter.views >= 10000) {
                      formattedViews = '${(chapter.views / 10000).toStringAsFixed(1)}만';
                    } else if (chapter.views >= 1000) {
                      formattedViews = '${(chapter.views / 1000).toStringAsFixed(1)}천';
                    }
                    
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        chapter.title,
                        style: theme.textTheme.titleMedium,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                              const SizedBox(width: 4),
                              Text(
                                chapter.uploadDate,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.visibility, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                              const SizedBox(width: 4),
                              Text(
                                formattedViews,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              if (chapter.likes > 0) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.thumb_up, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                                const SizedBox(width: 4),
                                Text(
                                  chapter.likes.toString(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                              if (chapter.rating > 0) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.star, size: 14, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                              if (chapter.comments > 0) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.comment, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                                const SizedBox(width: 4),
                                Text(
                                  chapter.comments.toString(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      leading: Container(
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
                      onTap: () {
                        // 회차 클릭 시 처리
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${chapter.title} 클릭됨'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
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
}
