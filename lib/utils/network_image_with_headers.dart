import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/providers/site_url_provider.dart';
import '../presentation/viewmodels/global_cookie_provider.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

class NetworkImageWithHeaders extends ConsumerWidget {
  final String url;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? errorWidget;
  final String? cookie;

  const NetworkImageWithHeaders({
    required this.url,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
    this.cookie,
    super.key,
  });

  Future<Uint8List?> _fetchImageBytes(
      String siteBaseUrl, CookieJar cookieJar) async {
    try {
      // URL이 상대 경로인 경우 절대 경로로 변환
      String imageUrl = url;
      if (url.startsWith('/')) {
        // 상대 경로인 경우 동적 기본 도메인 추가
        imageUrl = '$siteBaseUrl$url';
      }

      // URL에 http/https가 없는 경우 추가
      if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
        imageUrl = 'https://$imageUrl';
      }

      final uri = Uri.parse(imageUrl);
      final baseUrl = '${uri.scheme}://${uri.host}';

      // 모든 쿠키 수집
      List<Cookie> allCookies = [];

      // 제공된 쿠키가 있으면 파싱
      if (cookie != null && cookie!.isNotEmpty) {
        final cookieParts = cookie!.split('; ');
        for (var part in cookieParts) {
          final keyValue = part.split('=');
          if (keyValue.length == 2) {
            allCookies.add(Cookie(keyValue[0], keyValue[1]));
          }
        }
      }

      // 이미지 URL에 대한 쿠키 로드
      final imageCookies = await cookieJar.loadForRequest(uri);
      for (var cookie in imageCookies) {
        if (!allCookies.any((c) => c.name == cookie.name)) {
          allCookies.add(cookie);
        }
      }

      // 기본 도메인에 대한 쿠키도 로드
      final baseCookies = await cookieJar.loadForRequest(Uri.parse(baseUrl));
      for (var cookie in baseCookies) {
        if (!allCookies.any((c) => c.name == cookie.name)) {
          allCookies.add(cookie);
        }
      }

      // PHPSESSID 쿠키가 있는지 확인 (캡챠에 중요)
      bool hasPhpSessionId = allCookies.any((c) => c.name == 'PHPSESSID');
      bool isCaptchaImage =
          imageUrl.contains('captcha') || imageUrl.contains('kcaptcha');

      // 캡챠 이미지이고 PHPSESSID가 없는 경우 더미 추가
      if (isCaptchaImage && !hasPhpSessionId) {
        allCookies.add(Cookie('PHPSESSID',
            'dummy_session_${DateTime.now().millisecondsSinceEpoch}'));
      }

      // 캡챠 이미지인 경우 브라우저 쿠키 추가
      if (isCaptchaImage) {
        final browserCookies = [
          Cookie('_gfont', 'GD01704277'),
          Cookie('cf_clearance',
              'Smlpj2_ehK4z7yGnbr7P1B9rkj2OcJKcqfnJbwRwt-1746323245-0'),
          Cookie('YSWAMnAL30', 'YSWAMnAL30'),
          Cookie('HitC', '1'),
          Cookie('HitCt', '1'),
          Cookie('HitCm', '1'),
          Cookie('HitCc', '1'),
          Cookie('HitCcm', '1'),
          Cookie('HitCctm', '1'),
          Cookie('HitCt446728', '1746323245608'),
          Cookie('HitCm446728', '1746323245608'),
          Cookie('HitCc446728', '1'),
          Cookie('HitCcm446728', '1'),
          Cookie('HitCctm446728', '1'),
          Cookie('HitCt446828', '1'),
        ];

        for (var cookie in browserCookies) {
          if (!allCookies.any((c) => c.name == cookie.name)) {
            allCookies.add(cookie);
          }
        }
      }

      // 쿠키 문자열 생성
      final cookieString = allCookies.isNotEmpty
          ? allCookies.map((c) => '${c.name}=${c.value}').join('; ')
          : null;

      // 캐시 방지를 위한 타임스탬프 추가
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // 캡챠 이미지인 경우 _direct 파라미터도 추가
      final String urlWithTimestamp = isCaptchaImage
          ? '$imageUrl${uri.hasQuery ? '&' : '?'}_t=$timestamp&_direct=1'
          : '$imageUrl${uri.hasQuery ? '&' : '?'}_t=$timestamp';

      // 헤더 설정 (브라우저 네트워크 탭 정보 기반)
      final headers = {
        'Referer': baseUrl,
        'Origin': baseUrl,
        'Host': uri.host,
        'Connection': 'keep-alive',
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept':
            'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Sec-Ch-Ua': '"Chromium";v="123", "Not-A-Brand";v="8"',
        'Sec-Ch-Ua-Mobile': '?0',
        'Sec-Ch-Ua-Platform': '"macOS"',
        'Sec-Fetch-Dest': 'image',
        'Sec-Fetch-Mode': 'no-cors',
        'Sec-Fetch-Site': 'same-origin',
      };

      // 쿠키가 있으면 헤더에 추가
      if (cookieString != null && cookieString.isNotEmpty) {
        headers['Cookie'] = cookieString;
      }

      // http 패키지를 사용하여 이미지 요청 (Dio 대신)
      try {
        // 첫 번째 시도: 타임스탬프가 있는 URL로 요청
        final httpResponse = await http.get(
          Uri.parse(urlWithTimestamp),
          headers: headers,
        );

        if (httpResponse.statusCode == 200 &&
            httpResponse.bodyBytes.isNotEmpty) {
          return httpResponse.bodyBytes;
        } else {
          // 두 번째 시도: 원본 URL로 요청
          final secondResponse = await http.get(
            Uri.parse(imageUrl),
            headers: headers,
          );

          if (secondResponse.statusCode == 200 &&
              secondResponse.bodyBytes.isNotEmpty) {
            return secondResponse.bodyBytes;
          }
        }
      } catch (_) {
        // Fall back to Dio below.
      }

      // HTTP 요청이 실패하면 Dio로 시도
      final dio = Dio();

      // 첫 번째 시도 - 기본 URL로 요청
      var response = await dio.get<List<int>>(
        urlWithTimestamp,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
          headers: headers,
        ),
      );

      // 첫 번째 시도가 실패하면 원본 URL로 다시 시도
      if (response.statusCode != 200 ||
          response.data == null ||
          response.data!.isEmpty) {
        response = await dio.get<List<int>>(
          imageUrl,
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: true,
            validateStatus: (status) => status != null && status < 500,
            headers: headers,
          ),
        );
      }

      if (response.statusCode == 200 &&
          response.data != null &&
          response.data!.isNotEmpty) {
        return Uint8List.fromList(response.data!);
      } else {
        // 마지막 시도: 직접 URL 요청 (이미지가 캡챠인 경우 특별 처리)
        if (imageUrl.contains('captcha') || imageUrl.contains('kcaptcha')) {
          // 캡챠 이미지에 대한 특별 처리
          final directResponse = await http.get(
            Uri.parse('$imageUrl?_direct=1&t=$timestamp'),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
              if (cookieString != null && cookieString.isNotEmpty)
                'Cookie': cookieString,
            },
          );

          if (directResponse.statusCode == 200 &&
              directResponse.bodyBytes.isNotEmpty) {
            return directResponse.bodyBytes;
          }
        }

        return null;
      }
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final siteBaseUrl = ref.watch(siteUrlServiceProvider);
    final cookieJar = ref.watch(globalCookieJarProvider);

    return FutureBuilder<Uint8List?>(
      future: _fetchImageBytes(siteBaseUrl, cookieJar),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            width: width,
            height: height,
            fit: fit,
          );
        } else if (snapshot.connectionState == ConnectionState.done) {
          // Diagnostic error widget for debugging black screen issues
          final errorMsg =
              '이미지 로딩 실패!\nURL: $url\n에러: ${(snapshot.error ?? 'Unknown error').toString()}';
          return errorWidget ??
              Container(
                width: width,
                height: height,
                color: Colors.red[100],
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image, size: 40, color: Colors.red),
                    const SizedBox(height: 8),
                    Text('이미지 로딩 오류',
                        style: const TextStyle(color: Colors.red)),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        'URL: $url',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        '에러: ${(snapshot.error ?? 'Unknown error').toString()}',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.black54),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
        } else {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child:
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
      },
    );
  }
}

class NetworkImageWithHeadersLoader {
  final String url;
  final Map<String, String> headers;

  NetworkImageWithHeadersLoader(this.url, this.headers);

  Future<ui.Image> load() async {
    final response = await http.get(Uri.parse(url), headers: headers);
    final bytes = response.bodyBytes;
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
