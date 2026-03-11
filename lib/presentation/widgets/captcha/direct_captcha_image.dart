import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/site_url_provider.dart';
import '../../../presentation/viewmodels/global_cookie_provider.dart';

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
    _loadImage();
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
      final imageBytes = await _fetchImageBytes();
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

  Future<Uint8List?> _fetchImageBytes() async {
    final cookieJar = ref.read(globalCookieJarProvider);
    final siteBaseUrl = ref.read(siteUrlServiceProvider);

    String imageUrl = widget.url;
    if (!imageUrl.startsWith('http')) {
      imageUrl = '$siteBaseUrl$imageUrl';
    }

    final uri = Uri.parse(imageUrl);
    final cookies = await cookieJar.loadForRequest(uri);
    final cookieString = cookies.isNotEmpty
        ? cookies.map((c) => '${c.name}=${c.value}').join('; ')
        : null;

    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
      'Accept':
          'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      'Referer': '${uri.scheme}://${uri.host}',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
    };

    if (cookieString != null && cookieString.isNotEmpty) {
      headers['Cookie'] = cookieString;
    }

    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      return response.bodyBytes;
    }

    throw Exception('캡챠 이미지 로드 실패 (${response.statusCode})');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingWidget ??
          SizedBox(
            width: widget.width,
            height: widget.height,
            child:
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
              ],
            ),
          );
    }

    // 이미지 데이터 디버깅
    print(
        '이미지 데이터 처음 20바이트: ${_imageBytes!.sublist(0, _imageBytes!.length > 20 ? 20 : _imageBytes!.length)}');

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
          gaplessPlayback: true, // 이미지 전환 시 깜빡임 방지
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
