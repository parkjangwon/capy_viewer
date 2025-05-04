import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/manatoki_captcha_helper.dart';
import '../../../data/providers/site_url_provider.dart';
import '../../../presentation/viewmodels/global_cookie_provider.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:http/http.dart' as http;
import 'captcha/direct_captcha_image.dart';

/// 마나토끼 캡챠 위젯
class ManatokiCaptchaWidget extends ConsumerStatefulWidget {
  final ManatokiCaptchaInfo captchaInfo;
  final Function(bool success) onCaptchaComplete;

  const ManatokiCaptchaWidget({
    Key? key,
    required this.captchaInfo,
    required this.onCaptchaComplete,
  }) : super(key: key);

  @override
  ConsumerState<ManatokiCaptchaWidget> createState() => _ManatokiCaptchaWidgetState();
}

// 쿠키 문자열 가져오기 함수
Future<String?> getCookieString(CookieJar jar, String url) async {
  try {
    final cookies = await jar.loadForRequest(Uri.parse(url));
    if (cookies.isEmpty) return null;
    return cookies.map((c) => '${c.name}=${c.value}').join('; ');
  } catch (_) {
    return null;
  }
}

class _ManatokiCaptchaWidgetState extends ConsumerState<ManatokiCaptchaWidget> {
  final TextEditingController _captchaController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  
  @override
  void dispose() {
    _captchaController.dispose();
    super.dispose();
  }

  // 캡챠 이미지를 직접 로드하는 메서드
  Future<Uint8List?> _loadCaptchaImageDirectly(String imageUrl) async {
    try {
      final cookieJar = ref.read(globalCookieJarProvider);
      final siteBaseUrl = ref.read(siteUrlServiceProvider);
      
      // URL 처리
      if (!imageUrl.startsWith('http')) {
        imageUrl = '$siteBaseUrl$imageUrl';
      }
      
      final uri = Uri.parse(imageUrl);
      final baseUrl = '${uri.scheme}://${uri.host}';
      
      print('캡챠 이미지 직접 로드 시도: $imageUrl');
      
      // 쿠키 가져오기
      final cookies = await cookieJar.loadForRequest(uri);
      final baseCookies = await cookieJar.loadForRequest(Uri.parse(baseUrl));
      
      // 모든 쿠키 병합
      final allCookies = [...cookies];
      for (var cookie in baseCookies) {
        if (!allCookies.any((c) => c.name == cookie.name)) {
          allCookies.add(cookie);
        }
      }
      
      // 필수 쿠키 추가
      if (!allCookies.any((c) => c.name == 'PHPSESSID')) {
        allCookies.add(Cookie('PHPSESSID', 'sess_${DateTime.now().millisecondsSinceEpoch}'));
      }
      
      if (!allCookies.any((c) => c.name == 'cf_clearance')) {
        allCookies.add(Cookie('cf_clearance', 'Smlpj2_ehK4z7yGnbr7P1B9rkj2OcJKcqfnJbwRwt-1746323245-0'));
      }
      
      // 쿠키 문자열 생성
      final cookieString = allCookies.map((c) => '${c.name}=${c.value}').join('; ');
      
      // 헤더 설정
      final headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
        'Referer': baseUrl,
        'Origin': baseUrl,
        'Host': uri.host,
        'Connection': 'keep-alive',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Cookie': cookieString,
      };
      
      // 이미지 요청
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final urlWithParams = '$imageUrl${uri.hasQuery ? '&' : '?'}_t=$timestamp&_direct=1';
      
      print('요청 URL: $urlWithParams');
      print('쿠키: $cookieString');
      
      final response = await http.get(Uri.parse(urlWithParams), headers: headers);
      
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        print('캡챠 이미지 직접 로드 성공: ${response.bodyBytes.length} 바이트');
        print('콘텐츠 타입: ${response.headers['content-type']}');
        
        // 이미지 데이터 처음 부분 로깅
        final previewSize = response.bodyBytes.length > 20 ? 20 : response.bodyBytes.length;
        print('이미지 데이터 처음 $previewSize 바이트: ${response.bodyBytes.sublist(0, previewSize)}');
        
        return response.bodyBytes;
      } else {
        print('캡챠 이미지 직접 로드 실패: 상태 코드 ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('캡챠 이미지 직접 로드 오류: $e');
      return null;
    }
  }

  Future<void> _submitCaptcha() async {
    if (_captchaController.text.isEmpty) {
      setState(() {
        _errorMessage = '캡챠 코드를 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final dio = Dio();
      final cookieJar = ref.read(globalCookieJarProvider);
      final baseUrl = ref.read(siteUrlServiceProvider);
      
      // 쿠키 설정
      final cookies = await cookieJar.loadForRequest(Uri.parse(baseUrl));
      final cookieString = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      
      // 폼 데이터 준비
      final formData = FormData.fromMap({
        ...widget.captchaInfo.hiddenInputs,
        'captcha_key': _captchaController.text,
      });
      
      // 캡챠 제출
      final response = await dio.post(
        widget.captchaInfo.formAction,
        data: formData,
        options: Options(
          headers: {
            'Cookie': cookieString,
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36',
            'Referer': baseUrl,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      
      // 응답 처리
      if (response.statusCode == 302 || response.statusCode == 200) {
        // 성공적으로 캡챠 인증 완료
        if (mounted) {
          widget.onCaptchaComplete(true);
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = '캡챠 인증에 실패했습니다. 다시 시도해주세요.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '오류가 발생했습니다: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 캡챠 이미지 URL 디버깅
    print('캡챠 이미지 URL: ${widget.captchaInfo.captchaImageUrl}');
    print('캡챠 폼 액션: ${widget.captchaInfo.formAction}');
    print('캡챠 리다이렉트 URL: ${widget.captchaInfo.redirectUrl}');
    
    // 이미지 URL이 유효한지 확인
    final imageUrl = widget.captchaInfo.captchaImageUrl;
    final isValidUrl = Uri.tryParse(imageUrl)?.hasScheme ?? false;
    print('유효한 URL인가요? $isValidUrl');
    
    // 이미지 URL 수정 (필요한 경우)
    final baseUrl = ref.read(siteUrlServiceProvider); // 동적 URL 사용
    final effectiveImageUrl = isValidUrl ? imageUrl : '$baseUrl$imageUrl';
    print('최종 이미지 URL: $effectiveImageUrl');
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '캡챠 인증',
            style: TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16.0),
          const Text(
            '아래 이미지에 표시된 문자를 입력해주세요.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16.0),
          // 캡챠 이미지 URL 표시 (디버깅용)
          Text(
            '캡챠 이미지 URL: $effectiveImageUrl',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8.0),
          // 캡챠 이미지
          Container(
            width: 200,
            height: 80,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                // 이미지 로드 시도: DirectCaptchaImage 위젯 사용
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: DirectCaptchaImage(
                    url: effectiveImageUrl,
                    width: 200,
                    height: 80,
                    fit: BoxFit.contain,
                    loadingWidget: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2),
                          SizedBox(height: 4),
                          Text('캡챠 이미지 로딩 중...', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                    errorWidget: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('이미지 로드 오류', style: TextStyle(fontSize: 10)),
                        const SizedBox(height: 4),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(30, 20),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          child: const Text('재시도', style: TextStyle(fontSize: 10)),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // 새로고침 버튼
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh, size: 16),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() {}),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
          // 캡챠 입력 필드
          TextField(
            controller: _captchaController,
            decoration: InputDecoration(
              hintText: '캡챠 코드 입력',
              errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
              border: const OutlineInputBorder(),
            ),
            textAlign: TextAlign.center,
            maxLength: 6,
            keyboardType: TextInputType.text,
            autofocus: true,
          ),
          const SizedBox(height: 16.0),
          // 제출 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitCaptcha,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                      ),
                    )
                  : const Text('확인'),
            ),
          ),
          const SizedBox(height: 8.0),
          // 취소 버튼
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => widget.onCaptchaComplete(false),
              child: const Text('취소'),
            ),
          ),
        ],
      ),
    );
  }
}
