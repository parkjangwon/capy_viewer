import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'dart:io' as io;
import '../../../presentation/viewmodels/global_cookie_provider.dart';
import '../../../data/providers/site_url_provider.dart';
import 'captcha/direct_captcha_image.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../utils/manatoki_captcha_helper.dart';

/// 마나토끼 캡챠 위젯
class ManatokiCaptchaWidget extends ConsumerStatefulWidget {
  final ManatokiCaptchaInfo captchaInfo;
  final Function() onSuccess;

  const ManatokiCaptchaWidget({
    super.key,
    required this.captchaInfo,
    required this.onSuccess,
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
  String _errorMessage = '';
  String _refreshKey = '';
  late String _effectiveImageUrl;

  @override
  void initState() {
    super.initState();

    final imageUrl = widget.captchaInfo.captchaImageUrl;
    final isValidUrl = Uri.tryParse(imageUrl)?.hasScheme ?? false;
    final baseUrl = ref.read(siteUrlServiceProvider);
    _effectiveImageUrl = isValidUrl ? imageUrl : '$baseUrl$imageUrl';
  }

  @override
  void dispose() {
    _captchaController.dispose();
    super.dispose();
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

      // 리다이렉트 여부 확인
      final hasRedirect = response.statusCode == 302 &&
          response.headers.value('location') != null;

      // 응답 본문 확인
      final responseBody = response.data.toString().toLowerCase();

      // 실패 키워드 확인
      final hasFailureKeyword = responseBody.contains('실패') ||
          responseBody.contains('fail') ||
          responseBody.contains('오류') ||
          responseBody.contains('error');

      // 성공 판단
      final isSuccess =
          (hasRedirect || response.statusCode == 200) && !hasFailureKeyword;

      if (isSuccess) {
        // 성공적으로 캡챠 인증 완료
        if (mounted) {
          // PHPSESSID 쿠키 확인 및 저장
          final uri = Uri.parse(baseUrl);
          final savedCookies = await cookieJar.loadForRequest(uri);

          // PHPSESSID 쿠키 찾기
          final phpSessionCookie = savedCookies.firstWhere(
            (cookie) => cookie.name == 'PHPSESSID',
            orElse: () => io.Cookie('PHPSESSID', ''),
          );

          if (phpSessionCookie.value.isNotEmpty) {
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

              // 전역 쿠키 저장소에도 저장
              final globalCookie =
                  io.Cookie('PHPSESSID', phpSessionCookie.value);
              globalCookie.domain = Uri.parse(baseUrl).host;
              globalCookie.path = '/';
              await cookieJar.saveFromResponse(uri, [globalCookie]);
            } catch (_) {
              // Ignore cookie sync failures; the success callback still unblocks the flow.
            }
          }

          // 쿠키 동기화 없이 즉시 콜백 호출
          // 쿠키 동기화 기능은 현재 사용하지 않음
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              widget.onSuccess();
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
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        width: double.infinity,
        height: double.infinity,
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '마나토끼 캡차 인증',
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
                                url: _effectiveImageUrl +
                                    (_refreshKey.isEmpty
                                        ? ''
                                        : '?t=$_refreshKey'),
                                width: 200,
                                height: 80,
                                fit: BoxFit.contain,
                                loadingWidget: Container(
                                  color: Colors.grey[100],
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          hintText: '캡챠 코드 입력',
                          hintStyle: const TextStyle(color: Colors.white70),
                          errorText:
                              _errorMessage.isNotEmpty ? _errorMessage : null,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.08),
                          border: const OutlineInputBorder(),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white54),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.white, width: 2),
                          ),
                        ),
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.text,
                        autofocus: true,
                        onSubmitted: (_) =>
                            _isLoading ? null : _submitCaptcha(),
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
        ),
      ),
    );
  }
}
