import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:html/parser.dart' as html_parser;
import '../../../data/models/manga_detail.dart';
import '../../../data/providers/site_url_provider.dart';
import '../../../utils/manga_detail_parser.dart';
import '../../../utils/network_image_with_headers.dart';
import '../../viewmodels/global_cookie_provider.dart';
import '../../viewmodels/cookie_sync_utils.dart';
import 'manga_captcha_screen.dart';
import 'manga_detail_screen.dart';

class MangaDetailTestScreen extends ConsumerStatefulWidget {
  const MangaDetailTestScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MangaDetailTestScreen> createState() => _MangaDetailTestScreenState();
}

class _MangaDetailTestScreenState extends ConsumerState<MangaDetailTestScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  MangaDetail? _mangaDetail;
  String _htmlContent = '';
  final String _testMangaId = '21054450';

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
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) async {
            // 페이지 로드 완료 후 HTML 가져오기
            await _getHtmlContent();
          },
          onNavigationRequest: (request) {
            return NavigationDecision.navigate;
          },
        ),
      );
    
    _loadMangaDetail();
  }

  Future<void> _loadMangaDetail() async {
    setState(() {
      _isLoading = true;
      _isError = false;
      _errorMessage = '';
    });

    try {
      final baseUrl = ref.read(siteUrlServiceProvider);
      final jar = ref.read(globalCookieJarProvider);
      
      // 쿠키 동기화 (Dio -> WebView)
      await syncDioCookiesToWebView(baseUrl, jar);
      
      // 만화 상세 페이지 로드
      final url = '$baseUrl/comic/$_testMangaId';
      await _controller.loadRequest(Uri.parse(url));
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = '데이터를 불러오는 중 오류가 발생했습니다: $e';
      });
    }
  }

  Future<void> _getHtmlContent() async {
    try {
      // 페이지 로드 후 약간의 지연 추가 (JavaScript 실행 시간 고려)
      await Future.delayed(const Duration(milliseconds: 500));
      
      final html = await _controller.runJavaScriptReturningResult('document.documentElement.outerHTML');
      final htmlStr = html.toString();
      
      // 캡차 체크
      if (_isCaptchaRequired(htmlStr)) {
        await _handleCaptcha();
        return;
      }
      
      // HTML 파싱
      final parseResult = parseMangaDetailFromHtml(htmlStr, _testMangaId);
      
      setState(() {
        _htmlContent = htmlStr;
        _mangaDetail = parseResult.mangaDetail;
        _isLoading = false;
      });
      
      // 쿠키 동기화 (WebView -> Dio)
      final jar = ref.read(globalCookieJarProvider);
      final baseUrl = ref.read(siteUrlServiceProvider);
      await syncWebViewCookiesToDio(baseUrl, jar);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = 'HTML 파싱 중 오류가 발생했습니다: $e';
      });
    }
  }

  bool _isCaptchaRequired(String html) {
    final htmlLower = html.toLowerCase();
    return htmlLower.contains('challenge-form') || 
           htmlLower.contains('cf-please-wait') ||
           htmlLower.contains('captcha') ||
           htmlLower.contains('_cf_chl_opt') ||
           htmlLower.contains('turnstile');
  }

  Future<void> _handleCaptcha() async {
    final baseUrl = ref.read(siteUrlServiceProvider);
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => MangaCaptchaScreen(
          url: '$baseUrl/comic/$_testMangaId',
        ),
      ),
    );

    if (result == true) {
      // 캡차 인증 성공 시 다시 로드
      await _loadMangaDetail();
    } else {
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = '캡차 인증에 실패했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('만화 상세 테스트'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMangaDetail,
            tooltip: '새로고침',
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
                  Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(_errorMessage, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadMangaDetail,
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 시도'),
                  ),
                ],
              ),
            )
          : _buildTestContent(),
    );
  }
  
  Widget _buildTestContent() {
    if (_mangaDetail == null) {
      return const Center(child: Text('데이터가 없습니다.'));
    }
    
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 만화 헤더 정보
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _mangaDetail!.title,
                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    // 좌우 레이아웃으로 썸네일과 상세 정보 표시
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 좌측 - 썸네일 이미지
                        if (_mangaDetail!.thumbnailUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 140,
                              height: 190,
                              child: NetworkImageWithHeaders(
                                url: _mangaDetail!.thumbnailUrl,
                                width: 140,
                                height: 190,
                                cookie: null,
                                fit: BoxFit.cover,
                                errorWidget: Container(
                                  width: 140,
                                  height: 190,
                                  color: colorScheme.surfaceVariant,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image, size: 36, color: colorScheme.error),
                                      const SizedBox(height: 8),
                                      Text('이미지 로드 실패', style: textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 16),
                        // 우측 - 상세 정보
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(Icons.person, '작가', _mangaDetail!.author),
                              _buildInfoRow(Icons.category, '장르', _mangaDetail!.genre),
                              _buildInfoRow(Icons.book, '발행상태', _mangaDetail!.releaseStatus),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text('회차 수: ', style: textTheme.titleSmall),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_mangaDetail!.chapters.length}',
                                      style: textTheme.labelMedium?.copyWith(color: colorScheme.onPrimaryContainer),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 회차 목록
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.format_list_numbered, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('회차 목록', style: textTheme.titleMedium),
                ],
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 1,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _mangaDetail!.chapters.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: colorScheme.outlineVariant),
                itemBuilder: (context, index) {
                  final chapter = _mangaDetail!.chapters[index];
                  
                  // 회차 번호 추출 (HTML에서 파싱한 값 사용)
                  final chapterNumber = _mangaDetail!.chapters.length - index; // 순서대로 번호 부여
                  
                  // 별점 표시를 위한 변환 (10점 만점에서 5점 만점으로)
                  final rating = (chapter.rating / 10).toStringAsFixed(1);
                  
                  // 회차 번호 추출 (제목에서 추출)
                  final chapterNumMatch = RegExp(r'([0-9]+)화').firstMatch(chapter.title);
                  final chapterNumText = chapterNumMatch?.group(1) ?? '';
                  
                  // 조회수, 추천수 포맷팅
                  final formattedViews = _formatNumber(chapter.views);
                  final formattedLikes = _formatNumber(chapter.likes);
                  
                  // 모든 변수 값 콘솔에 출력
                  print('\n회차 정보 [$index] =====================');
                  print('chapter.id: ${chapter.id}');
                  print('chapter.title: ${chapter.title}');
                  print('chapter.uploadDate: ${chapter.uploadDate}');
                  print('chapter.views: ${chapter.views}');
                  print('chapter.rating: ${chapter.rating}');
                  print('chapter.likes: ${chapter.likes}');
                  print('chapter.comments: ${chapter.comments}');
                  print('chapterNumber: $chapterNumber');
                  print('chapterNumText: $chapterNumText');
                  print('rating: $rating');
                  print('formattedViews: $formattedViews');
                  print('formattedLikes: $formattedLikes');
                  print('=======================================');
                  
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$chapterNumber',
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(text: chapter.title, style: textTheme.titleSmall),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '업로드: ${chapter.uploadDate} · 조회수: $formattedViews · 추천: $formattedLikes · 댓글: ${chapter.comments}',
                      style: textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        SizedBox(width: 4),
                        Text(
                          '$rating',
                          style: textTheme.titleSmall?.copyWith(color: Colors.amber),
                        ),
                        SizedBox(width: 8),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
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

  // 숫자 포맷팅 함수 (예: 1000 -> 1K, 1000000 -> 1M)
  String _formatNumber(int number) {
    if (number >= 10000000) {
      return '${(number / 10000000).toStringAsFixed(1)}M';
    } else if (number >= 10000) {
      return '${(number / 10000).toStringAsFixed(1)}만';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }
}
