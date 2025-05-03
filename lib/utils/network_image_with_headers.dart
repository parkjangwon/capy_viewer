import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/providers/site_url_provider.dart';

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

  Future<Uint8List?> _fetchImageBytes(String siteBaseUrl) async {
    try {
      // URL이 상대 경로인 경우 절대 경로로 변환
      String imageUrl = url;
      if (url.startsWith('/')) {
        // 상대 경로인 경우 동적 기본 도메인 추가
        imageUrl = '$siteBaseUrl$url';
        print('상대 경로 URL 변환: $url -> $imageUrl');
      }
      
      final dio = Dio();
      final baseUrl = Uri.parse(imageUrl).origin;
      
      print('이미지 로딩 시도: $imageUrl');
      
      final response = await dio.get<List<int>>(
        imageUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'Referer': baseUrl,
            'Origin': baseUrl,
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
            'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
            'Sec-Ch-Ua': '"Chromium";v="123", "Not-A-Brand";v="8"',
            'Sec-Ch-Ua-Mobile': '?0',
            'Sec-Ch-Ua-Platform': '"macOS"',
            'Sec-Fetch-Dest': 'image',
            'Sec-Fetch-Mode': 'no-cors',
            'Sec-Fetch-Site': 'cross-site',
            if (cookie != null && cookie!.isNotEmpty) 'Cookie': cookie!,
          },
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        print('이미지 로드 성공: $imageUrl');
        return Uint8List.fromList(response.data!);
      } else {
        print('이미지 로드 실패: $imageUrl, 상태 코드: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('이미지 로드 오류: $url, 예외: ${e.toString()}');
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final siteBaseUrl = ref.watch(siteUrlServiceProvider);
    
    return FutureBuilder<Uint8List?>(
      future: _fetchImageBytes(siteBaseUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            width: width,
            height: height,
            fit: fit,
          );
        } else if (snapshot.connectionState == ConnectionState.done) {
          return errorWidget ??
              Container(
                width: width,
                height: height,
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
              );
        } else {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
      },
    );
  }
}
