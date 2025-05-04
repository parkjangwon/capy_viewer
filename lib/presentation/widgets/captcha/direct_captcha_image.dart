import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/site_url_provider.dart';
import '../../../presentation/viewmodels/global_cookie_provider.dart';
import 'package:cookie_jar/cookie_jar.dart';

/// 캡챠 이미지를 직접 표시하는 위젯
class DirectCaptchaImage extends ConsumerStatefulWidget {
  final String url;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? errorWidget;
  final Widget? loadingWidget;

  const DirectCaptchaImage({
    required this.url,
    required this.width,
    required this.height,
    this.fit = BoxFit.contain,
    this.errorWidget,
    this.loadingWidget,
    super.key,
  });

  @override
  ConsumerState<DirectCaptchaImage> createState() => _DirectCaptchaImageState();
}

class _DirectCaptchaImageState extends ConsumerState<DirectCaptchaImage> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  String? _errorMessage;
  String? manualCookieString;
  
  @override
  void initState() {
    super.initState();
    // 약간의 지연 후 이미지 로드 (쿠키가 준비되도록)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _loadImage();
    });
  }
  
  @override
  void didUpdateWidget(DirectCaptchaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadImage();
    }
  }
  
  Future<void> _loadImage() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final cookieJar = ref.read(globalCookieJarProvider);
      final siteBaseUrl = ref.read(siteUrlServiceProvider);
      
      // 1. 레거시 앱처럼 쿠키 세션 초기화 - kcaptcha_session.php에 POST 요청
      String? phpSessionId;
      int tries = 3; // 재시도 횟수
      
      while (tries > 0) {
        try {
          print('쿠키 세션 초기화 시도 ($tries 회 남음)');
          final sessionResponse = await http.post(
            Uri.parse('$siteBaseUrl/plugin/kcaptcha/kcaptcha_session.php'),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
              'Accept': '*/*',
              'Accept-Encoding': 'gzip, deflate, br',
              'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
              'Origin': siteBaseUrl,
              'Referer': '$siteBaseUrl/plugin/kcaptcha/',
              'Connection': 'keep-alive',
            },
          );
          
          print('세션 응답 상태 코드: ${sessionResponse.statusCode}');
          
          // 응답 헤더에서 Set-Cookie 추출
          String? setCookieHeader = sessionResponse.headers['set-cookie'];
          print('세션 응답 쿠키: $setCookieHeader');
          
          if (setCookieHeader != null && setCookieHeader.isNotEmpty) {
            // PHPSESSID 쿠키 추출
            if (setCookieHeader.contains('PHPSESSID=')) {
              int startIndex = setCookieHeader.indexOf('PHPSESSID=') + 'PHPSESSID='.length;
              int endIndex = setCookieHeader.indexOf(';', startIndex);
              if (endIndex == -1) endIndex = setCookieHeader.length;
              
              phpSessionId = setCookieHeader.substring(startIndex, endIndex);
              print('추출된 PHPSESSID: $phpSessionId');
              
              // 쿠키저장소에 저장
              final uri = Uri.parse(siteBaseUrl);
              await cookieJar.saveFromResponse(
                uri, 
                [Cookie('PHPSESSID', phpSessionId)]
              );
              print('쿠키저장소에 PHPSESSID 저장 완료');
              break; // 성공적으로 쿠키를 받았으니 루프 종료
            }
          }
          
          // 실패하면 재시도
          tries--;
          if (tries > 0) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        } catch (e) {
          print('쿠키 세션 초기화 오류: $e');
          tries--;
          if (tries > 0) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      }
      
      // 2. 쿠키 확보 후 이미지 요청
      final imageBytes = await _fetchImageBytes(phpSessionId);
      if (!mounted) return;
      setState(() {
        _imageBytes = imageBytes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<Uint8List?> _fetchImageBytes(String? phpSessionId) async {
    try {
      final cookieJar = ref.read(globalCookieJarProvider);
      final siteBaseUrl = ref.read(siteUrlServiceProvider);
      
      // URL 처리
      String imageUrl = widget.url;
      if (!imageUrl.startsWith('http')) {
        imageUrl = '$siteBaseUrl$imageUrl';
      }
      
      // 타임스탬프 추가 (캐시 방지)
      final currentTimestamp = DateTime.now().millisecondsSinceEpoch;
      if (!imageUrl.contains('?t=') && !imageUrl.contains('&t=')) {
        imageUrl = '$imageUrl${imageUrl.contains('?') ? '&' : '?'}t=$currentTimestamp';
      }
      
      final uri = Uri.parse(imageUrl);
      final baseUrl = '${uri.scheme}://${uri.host}';
      
      print('캡챠 이미지 로딩 시도: $imageUrl');
      print('기본 URL: $baseUrl');
      
      // 쿠키 수집 시작
      List<Cookie> allCookies = [];
      
      // 1. 세션 초기화에서 받은 PHPSESSID가 있다면 최우선 사용
      if (phpSessionId != null && phpSessionId.isNotEmpty) {
        allCookies.add(Cookie('PHPSESSID', phpSessionId));
        print('세션 초기화에서 받은 PHPSESSID 쿠키 사용: $phpSessionId');
      }
      
      // 2. 쿠키저장소에서 기본 도메인 쿠키 로드
      final domainCookies = await cookieJar.loadForRequest(Uri.parse(baseUrl));
      for (var cookie in domainCookies) {
        // PHPSESSID가 이미 있는 경우 제외
        if (cookie.name == 'PHPSESSID' && allCookies.any((c) => c.name == 'PHPSESSID')) {
          continue;
        }
        if (!allCookies.any((c) => c.name == cookie.name)) {
          allCookies.add(cookie);
        }
      }
      
      // 3. 이미지 URL에 대한 쿠키 로드
      final imageUrlCookies = await cookieJar.loadForRequest(uri);
      for (var cookie in imageUrlCookies) {
        // PHPSESSID가 이미 있는 경우 제외
        if (cookie.name == 'PHPSESSID' && allCookies.any((c) => c.name == 'PHPSESSID')) {
          continue;
        }
        if (!allCookies.any((c) => c.name == cookie.name)) {
          allCookies.add(cookie);
        }
      }
      
      // 4. 중요 쿠키 확인
      bool hasPhpSessionId = allCookies.any((c) => c.name == 'PHPSESSID');
      bool hasCfClearance = allCookies.any((c) => c.name == 'cf_clearance');
      
      print('PHPSESSID 쿠키 존재: $hasPhpSessionId');
      print('cf_clearance 쿠키 존재: $hasCfClearance');
      
      // 5. 필수 쿠키 추가
      if (!hasPhpSessionId) {
        final dummySessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}';
        allCookies.add(Cookie('PHPSESSID', dummySessionId));
        print('PHPSESSID 쿠키가 없어 더미 추가: $dummySessionId');
      }
      
      if (!hasCfClearance) {
        allCookies.add(Cookie('cf_clearance', 'Smlpj2_ehK4z7yGnbr7P1B9rkj2OcJKcqfnJbwRwt-1746323245-0'));
      }
      
      // 6. 브라우저에서 보이는 추가 쿠키 (네트워크 탭 정보 기반)
      final browserCookies = [
        Cookie('_gfont', 'GD01704277'),
        Cookie('YSWAMnAL30', 'YSWAMnAL30'),
        Cookie('HitC', '1'),
        Cookie('HitCt', '1'),
        Cookie('HitCm', '1'),
        Cookie('HitCc', '1'),
        Cookie('HitCcm', '1'),
        Cookie('HitCctm', '1'),
        Cookie('HitCt446728', '${DateTime.now().millisecondsSinceEpoch}'),
        Cookie('HitCm446728', '${DateTime.now().millisecondsSinceEpoch}'),
        Cookie('HitCc446728', '1'),
        Cookie('HitCcm446728', '1'),
        Cookie('HitCctm446728', '1'),
        Cookie('HitCt446828', '1'),
      ];
      
      // 기존 쿠키에 없는 경우에만 추가
      for (var cookie in browserCookies) {
        if (!allCookies.any((c) => c.name == cookie.name)) {
          allCookies.add(cookie);
        }
      }
      
      // 쿠키 문자열 생성
      final cookieString = allCookies.isNotEmpty 
          ? allCookies.map((c) => '${c.name}=${c.value}').join('; ')
          : null;
      
      print('쿠키 개수: ${allCookies.length}');
      print('쿠키 이름들: ${allCookies.map((c) => c.name).join(', ')}');
      
      // 타임스탬프 추가 (캐시 방지)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // 여러 방식의 URL 생성
      final urlWithTimestamp = '$imageUrl${uri.hasQuery ? '&' : '?'}_t=$timestamp&_direct=1';
      final urlWithoutParams = imageUrl.split('?')[0] + '?t=$timestamp&_direct=1';
      final directUrl = '$baseUrl/plugin/kcaptcha/kcaptcha_image.php?t=$timestamp';
      
      // 헤더 설정 (브라우저 네트워크 탭 정보 기반)
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
        'Sec-Ch-Ua': '"Chromium";v="123", "Not-A-Brand";v="8"',
        'Sec-Ch-Ua-Mobile': '?0',
        'Sec-Ch-Ua-Platform': '"macOS"',
        'Sec-Fetch-Dest': 'image',
        'Sec-Fetch-Mode': 'no-cors',
        'Sec-Fetch-Site': 'same-origin',
        'Referrer-Policy': 'strict-origin-when-cross-origin',
      };
      
      // 1. 세션 초기화에서 받은 PHPSESSID가 있다면 최우선 사용
      if (phpSessionId != null && phpSessionId.isNotEmpty) {
        // 기존 쿠키에서 PHPSESSID 제거
        allCookies.removeWhere((c) => c.name == 'PHPSESSID');
        // 새로운 PHPSESSID 추가
        allCookies.add(Cookie('PHPSESSID', phpSessionId));
        print('세션 초기화에서 받은 PHPSESSID 쿠키 사용: $phpSessionId');
      }
      
      // 3. 이미지 URL에 대한 쿠키 로드
      final captchaUrlCookies = await cookieJar.loadForRequest(uri);
      for (var cookie in captchaUrlCookies) {
        // PHPSESSID가 이미 있는 경우 제외
        if (cookie.name == 'PHPSESSID' && allCookies.any((c) => c.name == 'PHPSESSID')) {
          continue;
        }
        if (!allCookies.any((c) => c.name == cookie.name)) {
          allCookies.add(cookie);
        }
      }
      
      // 4. 여전히 PHPSESSID가 없는 경우 더미 추가
      if (!allCookies.any((c) => c.name == 'PHPSESSID')) {
        final dummySessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}';
        allCookies.add(Cookie('PHPSESSID', dummySessionId));
        print('PHPSESSID 쿠키가 없어 더미 추가: $dummySessionId');
      }
      
      // 쿠키 문자열 생성
      final combinedCookieString = allCookies.isNotEmpty 
          ? allCookies.map((c) => '${c.name}=${c.value}').join('; ')
          : null;
      
      if (combinedCookieString != null && combinedCookieString.isNotEmpty) {
        headers['Cookie'] = combinedCookieString;
      }
      
      // 요청 헤더 상세 로깅
      print('\n=== 캡챠 이미지 요청 헤더 상세 정보 ===');
      headers.forEach((key, value) {
        print('$key: $value');
      });
      print('\n=== 쿠키 상세 정보 ===');
      for (var cookie in allCookies) {
        print('${cookie.name}: ${cookie.value}');
      }
      print('===============================\n');
      
      // 레가시 앱에서 사용하는 정확한 캐챠 이미지 URL 형식 사용
      final requestTimestamp = DateTime.now().millisecondsSinceEpoch;
      
      // 우선순위로 시도할 URL 목록
      final urlVariations = [
        // 1. 레가시 앱에서 사용하는 정확한 경로
        '$baseUrl/plugin/kcaptcha/kcaptcha_image.php?t=$requestTimestamp',
        // 2. 원본 URL에 타임스탬프 추가
        '$imageUrl${imageUrl.contains('?') ? '&' : '?'}t=$requestTimestamp',
        // 3. 원본 URL
        imageUrl,
        // 4. 기본 captcha.php 접근
        '$baseUrl/captcha.php?t=$requestTimestamp',
        // 5. 다른 형식의 캡챠 URL
        '$baseUrl/plugin/kcaptcha/?t=$requestTimestamp'
      ];
      
      // 각 URL 변형을 순차적으로 시도
      for (int i = 0; i < urlVariations.length; i++) {
        final currentUrl = urlVariations[i];
        try {
          print('\n${i+1}번째 시도: $currentUrl');
          final response = await http.get(Uri.parse(currentUrl), headers: headers);
          
          // 응답 헤더 로깅
          print('\n=== 응답 헤더 ===');
          response.headers.forEach((key, value) {
            print('$key: $value');
          });
          print('===================\n');
          
          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            print('캡챠 이미지 로드 성공: ${response.bodyBytes.length} 바이트');
            print('콘텐츠 타입: ${response.headers['content-type']}');
            
            // 이미지 데이터 처음 부분 로깅
            final previewSize = response.bodyBytes.length > 20 ? 20 : response.bodyBytes.length;
            print('이미지 데이터 처음 $previewSize 바이트: ${response.bodyBytes.sublist(0, previewSize)}');
            
            // 응답 쿠키 저장 (있다면)
            if (response.headers.containsKey('set-cookie')) {
              print('응답에서 쿠키 발견: ${response.headers['set-cookie']}');
              try {
                final cookies = response.headers['set-cookie']!.split(',');
                for (var cookieStr in cookies) {
                  final parts = cookieStr.split(';')[0].split('=');
                  if (parts.length == 2) {
                    final name = parts[0].trim();
                    final value = parts[1].trim();
                    await cookieJar.saveFromResponse(uri, [Cookie(name, value)]);
                    print('쿠키 저장됨: $name=$value');
                  }
                }
              } catch (e) {
                print('쿠키 저장 오류: $e');
              }
            }
            
            return response.bodyBytes;
          } else {
            print('${i+1}번째 시도 실패: 상태 코드 ${response.statusCode}');
          }
        } catch (e) {
          print('${i+1}번째 시도 오류: $e');
        }
      }
      
      // 모든 시도가 실패한 경우
      throw Exception('모든 캡챠 이미지 로드 시도 실패');
    } catch (e) {
      print('캡챠 이미지 로드 오류: $e');
      rethrow;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingWidget ?? 
        SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
    }
    
    if (_errorMessage != null || _imageBytes == null) {
      return widget.errorWidget ??
        Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[300],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image, size: 40, color: Colors.grey),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton(
                onPressed: _loadImage,
                child: const Text('새로고침'),
              ),
            ],
          ),
        );
    }
    
    // 이미지 데이터 디버깅
    print('이미지 데이터 처음 20바이트: ${_imageBytes!.sublist(0, _imageBytes!.length > 20 ? 20 : _imageBytes!.length)}');
    
    // JPEG 이미지 시그니처 확인 (FF D8 FF)
    bool isJpeg = _imageBytes!.length > 3 && 
                 _imageBytes![0] == 0xFF && 
                 _imageBytes![1] == 0xD8 && 
                 _imageBytes![2] == 0xFF;
    
    // PNG 이미지 시그니처 확인 (89 50 4E 47)
    bool isPng = _imageBytes!.length > 4 && 
                _imageBytes![0] == 0x89 && 
                _imageBytes![1] == 0x50 && 
                _imageBytes![2] == 0x4E && 
                _imageBytes![3] == 0x47;
    
    print('이미지 형식: ${isJpeg ? "JPEG" : isPng ? "PNG" : "알 수 없음"}');
    
    // 단순화된 이미지 표시 방법
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.memory(
          _imageBytes!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          gaplessPlayback: true,  // 이미지 전환 시 깜빡임 방지
          errorBuilder: (context, error, stackTrace) {
            print('이미지 렌더링 오류:');
            print(error);
            print(stackTrace);
            return Container(
              width: widget.width,
              height: widget.height,
              color: Colors.red, // 오류 시 빨간색으로 표시
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image_not_supported, color: Colors.white),
                  const SizedBox(height: 4),
                  Text(
                    '이미지 표시 오류 (${_imageBytes!.length}바이트)',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  ElevatedButton(
                    onPressed: _loadImage,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(30, 20),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: const Text('새로고침', style: TextStyle(fontSize: 10)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
