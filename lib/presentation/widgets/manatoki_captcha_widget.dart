import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'dart:io' as io;
import '../../../presentation/viewmodels/global_cookie_provider.dart';
import '../../../data/providers/site_url_provider.dart';
import 'package:http/http.dart' as http;
import 'captcha/direct_captcha_image.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
import '../../../utils/manatoki_captcha_helper.dart';

/// 마나토끼 캡챠 위젯
class ManatokiCaptchaWidget extends ConsumerStatefulWidget {
  final ManatokiCaptchaInfo captchaInfo;
  final Function(bool success) onCaptchaComplete;

  const ManatokiCaptchaWidget({
    super.key,
    required this.captchaInfo,
    required this.onCaptchaComplete,
  });

  @override
  ConsumerState<ManatokiCaptchaWidget> createState() =>
      _ManatokiCaptchaWidgetState();
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
  bool _isInitialLoading = true; // 초기 로딩 상태 추가
  String _errorMessage = '';
  String _refreshKey = '';

  @override
  void initState() {
    super.initState();
    // 약간의 지연 후 초기 로딩 상태 해제
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    });
  }

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
        final phpCookie = io.Cookie(
            'PHPSESSID', 'sess_${DateTime.now().millisecondsSinceEpoch}');
        allCookies.add(phpCookie);
      }

      if (!allCookies.any((c) => c.name == 'cf_clearance')) {
        final cfCookie = io.Cookie('cf_clearance',
            'Smlpj2_ehK4z7yGnbr7P1B9rkj2OcJKcqfnJbwRwt-1746323245-0');
        allCookies.add(cfCookie);
      }

      // 쿠키 문자열 생성
      final cookieString =
          allCookies.map((c) => '${c.name}=${c.value}').join('; ');

      // 헤더 설정
      final headers = {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept':
            'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
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
      final urlWithParams =
          '$imageUrl${uri.hasQuery ? '&' : '?'}_t=$timestamp&_direct=1';

      print('요청 URL: $urlWithParams');
      print('쿠키: $cookieString');

      final response =
          await http.get(Uri.parse(urlWithParams), headers: headers);

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        print('캡챠 이미지 직접 로드 성공: ${response.bodyBytes.length} 바이트');
        print('콘텐츠 타입: ${response.headers['content-type']}');

        // 이미지 데이터 처음 부분 로깅
        final previewSize =
            response.bodyBytes.length > 20 ? 20 : response.bodyBytes.length;
        print(
            '이미지 데이터 처음 $previewSize 바이트: ${response.bodyBytes.sublist(0, previewSize)}');

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
      final cookieString =
          cookies.map((c) => '${c.name}=${c.value}').join('; ');

      // 폼 데이터 준비
      final Map<String, dynamic> formFields = {};

      // hiddenInputs가 있는 경우에만 추가
      formFields.addAll(widget.captchaInfo.hiddenInputs);

      // 캡챠 키 추가
      formFields['captcha_key'] = _captchaController.text;

      final formData = FormData.fromMap(formFields);

      // 캡챠 제출
      final response = await dio.post(
        widget.captchaInfo.formAction,
        data: formData,
        options: Options(
          headers: {
            'Cookie': cookieString,
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36',
            'Referer': baseUrl,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      // 응답 처리
      print('캡챠 인증 응답 상태 코드: ${response.statusCode}');

      // 리다이렉트 여부 확인
      bool hasRedirect = response.statusCode == 302 &&
          response.headers.value('location') != null;
      if (hasRedirect) {
        print('리다이렉트 URL 발견: ${response.headers.value('location')}');
      }

      // 응답 본문 확인
      final responseBody = response.data.toString().toLowerCase();
      print('캡챠 인증 응답 본문: $responseBody');

      // 성공 키워드 확인
      bool hasSuccessKeyword = responseBody.contains('성공') ||
          responseBody.contains('success') ||
          responseBody.contains('정상') ||
          responseBody.isEmpty; // 빈 응답도 성공으로 간주

      // 실패 키워드 확인
      bool hasFailureKeyword = responseBody.contains('실패') ||
          responseBody.contains('fail') ||
          responseBody.contains('오류') ||
          responseBody.contains('error');

      // 성공 판단
      bool isSuccess =
          (hasRedirect || response.statusCode == 200) && !hasFailureKeyword;

      print('캡챠 인증 결과: ${isSuccess ? '성공' : '실패'}');

      if (isSuccess) {
        // 성공적으로 캡챠 인증 완료
        if (mounted) {
          // PHPSESSID 쿠키 확인 및 저장
          final uri = Uri.parse(baseUrl);
          final savedCookies = await cookieJar.loadForRequest(uri);
          print(
              '캡챠 인증 후 저장된 쿠키: ${savedCookies.map((c) => '${c.name}=${c.value}').join('; ')}');

          // PHPSESSID 쿠키 찾기
          final phpSessionCookie = savedCookies.firstWhere(
            (cookie) => cookie.name == 'PHPSESSID',
            orElse: () => io.Cookie('PHPSESSID', ''),
          );

          if (phpSessionCookie.value.isNotEmpty) {
            print('중요: PHPSESSID 쿠키 발견: ${phpSessionCookie.value}');

            // 웹뷰와 쿠키 동기화 시도
            try {
              // 웹뷰에 쿠키 설정
              await CookieManager.instance().setCookie(
                url: WebUri(baseUrl),
                name: 'PHPSESSID',
                value: phpSessionCookie.value,
                domain: Uri.parse(baseUrl).host,
                path: '/',
                isSecure: true,
              );

              print('웹뷰에 PHPSESSID 쿠키 설정 완료');

              // 전역 쿠키 저장소에도 저장
              final globalCookie =
                  io.Cookie('PHPSESSID', phpSessionCookie.value);
              globalCookie.domain = Uri.parse(baseUrl).host;
              globalCookie.path = '/';
              await cookieJar.saveFromResponse(uri, [globalCookie]);

              print('전역 쿠키 저장소에 PHPSESSID 쿠키 저장 완료');
            } catch (syncError) {
              print('쿠키 동기화 오류: $syncError');
            }
          } else {
            print('경고: PHPSESSID 쿠키를 찾을 수 없습니다!');
          }

          // 쿠키 동기화 없이 즉시 콜백 호출
          // 쿠키 동기화 기능은 현재 사용하지 않음
          print('캡챠 인증 성공, 콜백 호출');
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              widget.onCaptchaComplete(true);
            }
          });
        }
      } else {
        // 인증 실패
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
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '캡챠 인증',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '아래 이미지에 표시된 문자를 입력해주세요.',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
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
                            url: effectiveImageUrl +
                                (_refreshKey.isEmpty ? '' : '?t=$_refreshKey'),
                            width: 200,
                            height: 80,
                            fit: BoxFit.contain,
                            loadingWidget: Container(
                              color: Colors.grey[100],
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.deepPurple),
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '캡챠 이미지 로딩 중...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.deepPurple,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            errorWidget: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('이미지 로드 오류',
                                    style: TextStyle(fontSize: 10)),
                                const SizedBox(height: 4),
                                ElevatedButton(
                                  onPressed: () => setState(() {}),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(30, 20),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                  ),
                                  child: const Text('재시도',
                                      style: TextStyle(fontSize: 10)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // 새로고침 버튼 추가
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.refresh,
                                  color: Colors.white, size: 20),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _refreshKey = DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString();
                                });
                              },
                              tooltip: '새로고침',
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
                      errorText:
                          _errorMessage.isNotEmpty ? _errorMessage : null,
                      border: const OutlineInputBorder(),
                    ),
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.text,
                    autofocus: true,
                    onSubmitted: (_) => _isLoading ? null : _submitCaptcha(),
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
                ],
              ),
            ),
            // 초기 로딩 인디케이터
            if (_isInitialLoading)
              Container(
                color: Colors.white,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '캡챠 페이지 준비 중...',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // 전체 화면 로딩 인디케이터
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '캡챠 인증 중...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
}
