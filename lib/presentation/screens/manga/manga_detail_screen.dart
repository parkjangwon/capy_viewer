import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../data/models/manga_detail.dart';
import '../../../data/providers/site_url_provider.dart';
import '../../../utils/html_manga_parser.dart';
import '../../../utils/network_image_with_headers.dart';
import '../../viewmodels/global_cookie_provider.dart';
import '../../viewmodels/cookie_sync_utils.dart';
import 'manga_captcha_screen.dart';
import 'manga_detail_webview_controller.dart';

class MangaDetailScreen extends ConsumerStatefulWidget {
  final String mangaId;

  const MangaDetailScreen({Key? key, required this.mangaId}) : super(key: key);

  @override
  ConsumerState<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends ConsumerState<MangaDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  MangaDetail? _mangaDetail;
  int _captchaRetryCount = 0;
  static const int _maxCaptchaRetries = 3;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      
      // 웹뷰 컨트롤러 초기화
      final webViewController = ref.read(mangaDetailWebViewControllerProvider);
      await webViewController.initialize();
      
      // 쿠키 동기화 (Dio -> WebView)
      await syncDioCookiesToWebView(baseUrl, jar);
      
      // 만화 상세 페이지 로드
      await webViewController.loadMangaDetail(baseUrl, widget.mangaId);
      final html = await webViewController.getHtml();

      // 캡차 체크
      if (_isCaptchaRequired(html)) {
        if (_captchaRetryCount >= _maxCaptchaRetries) {
          setState(() {
            _isLoading = false;
            _isError = true;
            _errorMessage = '캡차 인증 시도 횟수를 초과했습니다.';
          });
          return;
        }

        _captchaRetryCount++;
        final captchaResult = await _handleCaptcha(baseUrl);
        if (captchaResult) {
          // 캡차 인증 성공 시 다시 로드
          return await _loadMangaDetail();
        } else {
          setState(() {
            _isLoading = false;
            _isError = true;
            _errorMessage = '캡차 인증에 실패했습니다.';
          });
          return;
        }
      }

      // HTML 파싱
      // 실제 구현 시 파싱 로직 추가
      final mangaDetail = MangaDetail(
        id: widget.mangaId,
        title: '원피스',
        thumbnailUrl: 'https://example.com/thumbnail.jpg',
        author: '오다 에이치로',
        genre: '액션, 모험, 판타지',
        releaseStatus: '연재중 (1997)',
        chapters: List.generate(
          20,
          (index) => MangaChapter(
            id: '${widget.mangaId}_${100 - index}',
            title: '${100 - index}화: 샘플 챕터 ${100 - index}',
            uploadDate: DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: index))),
            views: 1000 + (index * 100),
            likes: 50 + (index * 5),
            rating: (45 - (index > 10 ? 10 : index)).toInt(),
            comments: 10 + (index * 2),
          ),
        ),
      );

      setState(() {
        _mangaDetail = mangaDetail;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = '데이터를 불러오는 중 오류가 발생했습니다: $e';
      });
    }
  }

  bool _isCaptchaRequired(String html) {
    // 캡차 체크 로직 (Cloudflare 또는 사이트 자체 캡차)
    final htmlLower = html.toLowerCase();
    return htmlLower.contains('challenge-form') || 
           htmlLower.contains('cf-please-wait') ||
           htmlLower.contains('captcha') ||
           htmlLower.contains('_cf_chl_opt') ||
           htmlLower.contains('turnstile');
  }

  Future<bool> _handleCaptcha(String baseUrl) async {
    // 캡차 처리 화면으로 이동
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => MangaCaptchaScreen(
          url: '$baseUrl/comic/${widget.mangaId}',
        ),
      ),
    );

    // null 체크 추가 (사용자가 뒤로가기 버튼으로 나갔을 경우)
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = ref.watch(siteUrlServiceProvider);
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: const Text('만화 상세'),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadMangaDetail(),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // 공유 기능 구현
            },
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
                  Text(_errorMessage),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _loadMangaDetail(),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            )
          : _buildMangaDetailContent(context, baseUrl),
    );
  }
  
  Widget _buildMangaDetailContent(BuildContext context, String baseUrl) {
    if (_mangaDetail == null) return const SizedBox.shrink();
    
    return Column(
      children: [
        // 만화 정보 헤더
        _buildMangaHeader(context, _mangaDetail!, baseUrl),
        
        // 메뉴 탭
        _buildMenuTabs(context),
        
        // 탭 컨텐츠
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // 회차 탭
              SingleChildScrollView(
                child: _buildChapterList(context, _mangaDetail!),
              ),
              
              // 남기 탭
              const Center(child: Text('남기 기능은 추후 추가될 예정입니다.')),
              
              // 추천 탭
              const Center(child: Text('추천 기능은 추후 추가될 예정입니다.')),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildMangaHeader(BuildContext context, MangaDetail manga, String baseUrl) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 만화 제목 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              manga.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          
          // 만화 정보 영역
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 썸네일 이미지
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.0),
                  child: SizedBox(
                    width: 120,
                    height: 160,
                    child: NetworkImageWithHeaders(
                      url: manga.thumbnailUrl,
                      width: 120,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 만화 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 작가 정보
                      _buildInfoRow('• 작가', manga.author),
                      const SizedBox(height: 4),
                      
                      // 장르 정보
                      _buildInfoRow('• 분류', manga.genre),
                      const SizedBox(height: 4),
                      
                      // 발행구분 정보
                      _buildInfoRow('• 발행구분', manga.releaseStatus),
                      const SizedBox(height: 16),
                      
                      // 추천 및 별점 버튼
                      Row(
                        children: [
                          // 첫화보기 버튼
                          ElevatedButton(
                            onPressed: () {
                              // 첫화보기 기능 구현
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: const Text('첫화보기'),
                          ),
                          const SizedBox(width: 8),
                          
                          // 만화목록 버튼
                          ElevatedButton(
                            onPressed: () {
                              // 만화목록 기능 구현
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: const Text('만화목록'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // 별점 및 추천 버튼
                      Row(
                        children: [
                          // 별점 표시
                          Row(
                            children: List.generate(5, (index) => 
                              Icon(
                                Icons.star, 
                                color: Colors.red, 
                                size: 16
                              )
                            ),
                          ),
                          const SizedBox(width: 8),
                          
                          // 추천 버튼
                          ElevatedButton.icon(
                            onPressed: () {
                              // 추천 기능 구현
                            },
                            icon: const Icon(Icons.thumb_up, size: 16),
                            label: Text('${manga.chapters.isNotEmpty ? manga.chapters.first.likes : 0}'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }
  
  Widget _buildMenuTabs(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: '회차'),
          Tab(text: '남기'),
          Tab(text: '추천'),
        ],
        labelColor: Colors.black,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Colors.red,
        indicatorWeight: 3,
      ),
    );
  }
  
  Widget _buildChapterList(BuildContext context, MangaDetail manga) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 테이블 헤더
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: const Row(
              children: [
                SizedBox(width: 40, child: Text('회차', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text('연재 목록', style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 60, child: Text('별점', style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 80, child: Text('날짜', style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 60, child: Text('조회', style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 60, child: Text('추천', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          
          // 회차 목록
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: manga.chapters.length,
            separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1),
            itemBuilder: (context, index) {
              final chapter = manga.chapters[index];
              return InkWell(
                onTap: () {
                  // 챗터 선택 시 뷰어로 이동하는 기능 구현
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    children: [
                      // 회차 번호
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${manga.chapters.length - index}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      
                      // 회차 제목
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chapter.title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (index == 0)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  '${chapter.comments} 개의 댓글',
                                  style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // 별점
                      SizedBox(
                        width: 60,
                        child: Row(
                          children: [
                            ...List.generate(
                              (chapter.rating / 20).round(),
                              (i) => const Icon(Icons.star, color: Colors.red, size: 14),
                            ),
                            if ((chapter.rating / 10) % 1 >= 0.5)
                              const Icon(Icons.star_half, color: Colors.red, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              '(${(chapter.rating / 10).toStringAsFixed(1)})',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      
                      // 날짜
                      SizedBox(
                        width: 80,
                        child: Text(
                          chapter.uploadDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: index == 0 ? Colors.orange : null,
                          ),
                        ),
                      ),
                      
                      // 조회수
                      SizedBox(
                        width: 60,
                        child: Text(
                          _formatNumber(chapter.views),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      
                      // 추천수
                      SizedBox(
                        width: 60,
                        child: Text(
                          _formatNumber(chapter.likes),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          // 페이지네이션
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPageButton(Icons.first_page, true),
                _buildPageButton(Icons.chevron_left, true),
                _buildPageButton('1', false, isActive: true),
                _buildPageButton(Icons.chevron_right, true),
                _buildPageButton(Icons.last_page, true),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPageButton(dynamic content, bool isIcon, {bool isActive = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue : Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: isIcon
              ? Icon(
                  content as IconData,
                  size: 16,
                  color: isActive ? Colors.white : Colors.black,
                )
              : Text(
                  content as String,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
  
  String _formatNumber(int number) {
    if (number >= 10000) {
      return '${(number / 10000).toStringAsFixed(1)}만';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}천';
    } else {
      return number.toString();
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
