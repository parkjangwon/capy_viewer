import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/logger.dart';
import '../../../data/providers/cookie_store_provider.dart';

/// 직접 캡차 핸들러 (WebView를 사용하지 않음)
class DirectCaptchaHandler extends ConsumerStatefulWidget {
  final String url;
  final Function(String html, List<String> cookies) onVerified;
  final Function(String error) onError;
  
  const DirectCaptchaHandler({
    super.key,
    required this.url,
    required this.onVerified,
    required this.onError,
  });

  @override
  ConsumerState<DirectCaptchaHandler> createState() => _DirectCaptchaHandlerState();
}

class _DirectCaptchaHandlerState extends ConsumerState<DirectCaptchaHandler> {
  final _logger = Logger();
  
  bool _isLoading = false;
  bool _isManatokiCaptcha = false;
  bool _isCloudflareCaptcha = false;
  int _retryCount = 0;
  String _captchaImageUrl = '';
  String _captchaInputValue = '';
  String _captchaFormAction = '';
  String _captchaRedirectUrl = '';
  String _currentHtml = '';
  List<String> _currentCookies = [];
  
  @override
  void initState() {
    super.initState();
    _logger.i('[DirectCaptchaHandler] macOS용 직접 캡차 핸들러 초기화');
    _loadInitialPage();
  }
  
  /// 초기 페이지 로드
  Future<void> _loadInitialPage() async {
    setState(() => _isLoading = true);
    
    try {
      _logger.i('[캡차] 페이지 로드 시도: ${widget.url}');
      
      // 쿠키 준비
      final cookieStore = ref.read(cookieStoreProvider.notifier);
      final cookieHeader = cookieStore.getCookieString();
      
      // HTTP 헤더 설정 - 더 완벽한 브라우저 헤더 사용
      final headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none',
        'Sec-Fetch-User': '?1',
        'Connection': 'keep-alive',
      };
      
      // 쿠키가 있으면 추가
      if (cookieHeader.isNotEmpty) {
        headers['Cookie'] = cookieHeader;
        _logger.d('[캡차] 저장된 쿠키 사용: $cookieHeader');
      }
      
      // HTTP 요청
      _logger.i('[캡차] 페이지 로드 시작: ${widget.url}');
      final response = await http.get(Uri.parse(widget.url), headers: headers);
      
      // 응답 헤더에서 쿠키 추출
      final cookies = _extractCookiesFromResponse(response);
      if (cookies.isNotEmpty) {
        cookieStore.setCookies(cookies);
        _currentCookies = cookies;
      }
      
      // 응답 HTML 분석
      _currentHtml = response.body;
      
      // 마나토끼 캡차 감지 (fcaptcha 폼 확인)
      if (_isManatokiCaptchaPage(_currentHtml)) {
        _logger.w('[캡차] 마나토끼 캡차 페이지 감지됨');
        
        // 캡차 정보 추출
        _extractManatokiCaptchaInfo(_currentHtml);
        setState(() {
          _isManatokiCaptcha = true;
          _isLoading = false;
        });
      } 
      // 클라우드플레어 캡차 감지
      else if (_isCloudflareChallengePage(_currentHtml)) {
        _logger.w('[캡차] 클라우드플레어 캡차 페이지 감지됨');
        
        // 바로 캡차 UI 표시
        setState(() {
          _isCloudflareCaptcha = true;
          _isLoading = false;
        });
        
        // 사용자에게 알림
        widget.onError('클라우드플레어 캡차가 나타났습니다. 다시 시도해주세요.');
      }
      // 일반 페이지
      else {
        _logger.i('[캡차] 일반 페이지 로드 완료 (캡차 없음)');
        setState(() => _isLoading = false);
        widget.onVerified(_currentHtml, _currentCookies);
      }
    } catch (e) {
      _logger.e('[캡차] 페이지 로드 오류: $e');
      setState(() => _isLoading = false);
      
      if (_retryCount < 3) {
        _retryCount++;
        _logger.i('[캡차] 재시도 ($_retryCount/3)...');
        await Future.delayed(const Duration(seconds: 2));
        _loadInitialPage();
      } else {
        widget.onError('페이지 로드 실패: $e');
      }
    }
  }
  
  /// 마나토끼 캡차 페이지인지 확인
  bool _isManatokiCaptchaPage(String html) {
    return html.contains('캡챠 인증') && 
           (html.contains('form name="fcaptcha"') || html.contains('captcha.php'));
  }
  
  /// 클라우드플레어 캡차 페이지인지 확인
  bool _isCloudflareChallengePage(String html) {
    return html.contains('<title>잠시만 기다리십시오…</title>') ||
           html.contains('challenge-error-text') ||
           html.contains('Just a moment') ||
           html.contains('cf-browser-verification') ||
           html.contains('cloudflare-challenge') ||
           html.contains('cf_captcha_kind') ||
           html.contains('cf-please-wait') ||
           html.contains('cf-spinner') ||
           html.contains('turnstile');
  }
  
  /// 마나토끼 캡차 정보 추출
  void _extractManatokiCaptchaInfo(String html) {
    try {
      // 폼 액션 URL 추출
      final formActionRegex = RegExp(r'<form[^>]*?name="fcaptcha"[^>]*?action="([^"]*)"');
      final formActionMatch = formActionRegex.firstMatch(html);
      final formAction = formActionMatch?.group(1) ?? '';
      
      // 리다이렉트 URL 추출
      final redirectRegex = RegExp(r'<input[^>]*?name="url"[^>]*?value="([^"]*)"');
      final redirectMatch = redirectRegex.firstMatch(html);
      final redirectUrl = redirectMatch?.group(1) ?? '';
      
      // 캡차 이미지 URL 추출
      final imageRegex = RegExp(r'<img[^>]*?class="captcha_img"[^>]*?src="([^"]*)"');
      final imageMatch = imageRegex.firstMatch(html);
      var imageUrl = imageMatch?.group(1) ?? '';
      
      // 상대 경로를 절대 경로로 변환
      if (imageUrl.startsWith('/')) {
        final uri = Uri.parse(widget.url);
        final baseUrl = '${uri.scheme}://${uri.host}';
        imageUrl = '$baseUrl$imageUrl';
      }
      
      _logger.i('[캡차] 마나토끼 캡차 정보 추출: 이미지=$imageUrl, 액션=$formAction, 리다이렉트=$redirectUrl');
      
      setState(() {
        _captchaFormAction = formAction;
        _captchaRedirectUrl = redirectUrl;
        _captchaImageUrl = imageUrl;
      });
    } catch (e) {
      _logger.e('[캡차] 마나토끼 캡차 정보 추출 오류: $e');
    }
  }
  
  /// 마나토끼 캡차 제출
  Future<void> _submitManatokiCaptcha() async {
    if (_captchaInputValue.isEmpty) {
      _logger.w('[캡차] 캡차 입력값이 비어 있음');
      return;
    }
    
    try {
      setState(() => _isLoading = true);
      
      // 쿠키 가져오기
      final cookieStore = ref.read(cookieStoreProvider.notifier);
      final cookieHeader = cookieStore.getCookieString();
      
      // 요청 URL 및 폼 데이터 준비
      final uri = Uri.parse(widget.url);
      final baseUrl = '${uri.scheme}://${uri.host}';
      final submitUrl = _captchaFormAction.isNotEmpty 
          ? (_captchaFormAction.startsWith('http') ? _captchaFormAction : '$baseUrl$_captchaFormAction')
          : '${baseUrl}/captcha.php';
      
      // 폼 데이터 설정
      final formData = {
        'captcha_key': _captchaInputValue,
      };
      
      // 리다이렉트 URL이 있으면 추가
      if (_captchaRedirectUrl.isNotEmpty) {
        formData['url'] = _captchaRedirectUrl;
      }
      
      // HTTP 헤더 설정
      final headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': baseUrl,
        'Referer': widget.url,
      };
      
      // 쿠키 헤더 추가
      if (cookieHeader.isNotEmpty) {
        headers['Cookie'] = cookieHeader;
      }
      
      _logger.i('[캡차] 마나토끼 캡차 제출: $submitUrl, 입력값: $_captchaInputValue');
      
      // POST 요청 (캡차 제출)
      final response = await http.post(
        Uri.parse(submitUrl),
        headers: headers,
        body: formData,
      );
      
      // 응답 헤더에서 쿠키 추출
      final cookies = _extractCookiesFromResponse(response);
      if (cookies.isNotEmpty) {
        cookieStore.setCookies(cookies);
        _currentCookies = cookies;
      }
      
      // 응답 처리
      if (response.statusCode >= 200 && response.statusCode < 400) {
        _logger.i('[캡차] 마나토끼 캡차 제출 성공: ${response.statusCode}');
        
        // 리다이렉트 URL로 다시 요청
        final redirectUrl = _captchaRedirectUrl.isNotEmpty 
            ? (_captchaRedirectUrl.startsWith('http') ? _captchaRedirectUrl : '$baseUrl$_captchaRedirectUrl')
            : widget.url;
            
        await _loadRedirectPage(redirectUrl, cookies);
      } else {
        _logger.e('[캡차] 마나토끼 캡차 제출 실패: ${response.statusCode}');
        setState(() => _isLoading = false);
        widget.onError('캡차 인증 실패: 상태 코드 ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('[캡차] 마나토끼 캡차 제출 오류: $e');
      setState(() => _isLoading = false);
      widget.onError('캡차 제출 오류: $e');
    }
  }
  
  /// 리다이렉트 페이지 로드
  Future<void> _loadRedirectPage(String url, List<String> cookies) async {
    try {
      final cookieStore = ref.read(cookieStoreProvider.notifier);
      final cookieHeader = cookieStore.getCookieString();
      
      final headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Referer': widget.url,
      };
      
      if (cookieHeader.isNotEmpty) {
        headers['Cookie'] = cookieHeader;
      }
      
      _logger.i('[캡차] 리다이렉트 페이지 로드: $url');
      
      final response = await http.get(Uri.parse(url), headers: headers);
      final newCookies = _extractCookiesFromResponse(response);
      
      if (newCookies.isNotEmpty) {
        cookieStore.setCookies(newCookies);
        cookies.addAll(newCookies);
      }
      
      _logger.i('[캡차] 리다이렉트 페이지 로드 완료: ${response.statusCode}');
      setState(() => _isLoading = false);
      
      // 캡차 성공 콜백 호출
      widget.onVerified(response.body, cookies);
    } catch (e) {
      _logger.e('[캡차] 리다이렉트 페이지 로드 오류: $e');
      setState(() => _isLoading = false);
      widget.onError('리다이렉트 페이지 로드 실패: $e');
    }
  }
  
  /// 응답 헤더에서 쿠키 추출
  List<String> _extractCookiesFromResponse(http.Response response) {
    final cookies = <String>[];
    final cookieHeaders = response.headers['set-cookie'];
    
    if (cookieHeaders != null) {
      final rawCookies = cookieHeaders.split(',');
      for (final rawCookie in rawCookies) {
        final cookieParts = rawCookie.split(';');
        if (cookieParts.isNotEmpty) {
          final cookie = cookieParts[0].trim();
          if (cookie.isNotEmpty) {
            cookies.add(cookie);
          }
        }
      }
    }
    
    return cookies;
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 배경 이미지
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: const Center(
              child: Icon(
                Icons.security,
                size: 64,
                color: Colors.white38,
              ),
            ),
          ),
        ),
        
        // 로딩 인디케이터
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        
        // 마나토끼 캡차 입력 UI
        if (_isManatokiCaptcha)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '캡챠 인증이 필요합니다',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_captchaImageUrl.isNotEmpty)
                    Container(
                      height: 80,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.network(
                        _captchaImageUrl,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          _logger.e('[캡차] 캡차 이미지 로드 오류: $error');
                          return const Center(
                            child: Text('이미지를 불러올 수 없습니다'),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '보안코드 입력',
                      hintText: '위 이미지의 문자를 입력하세요',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _captchaInputValue = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submitManatokiCaptcha,
                          child: const Text('확인'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
        // 클라우드플레어 캡차 UI
        if (_isCloudflareCaptcha)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '클라우드플레어 보안 검사',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '클라우드플레어 검사를 통과할 수 없습니다. 웹브라우저로 페이지를 열어 검사를 통과하신 뒤 다시 시도해주세요.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _retryCount = 0;
                            _loadInitialPage();
                          },
                          child: const Text('다시 시도'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
