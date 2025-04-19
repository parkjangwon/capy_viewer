import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manga_view_flutter/services/site_url_service.dart';

class SiteCaptchaWidget extends ConsumerStatefulWidget {
  final String imageUrl;
  final Function(String) onSubmit;

  const SiteCaptchaWidget({
    super.key,
    required this.imageUrl,
    required this.onSubmit,
  });

  @override
  ConsumerState<SiteCaptchaWidget> createState() => _SiteCaptchaWidgetState();
}

class _SiteCaptchaWidgetState extends ConsumerState<SiteCaptchaWidget> {
  final _logger = Logger();
  final _controller = TextEditingController();
  final _dio = Dio();

  Uint8List? _imageBytes;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _controller.dispose();
    _dio.close();
    super.dispose();
  }

  Future<void> _loadImage() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _logger.d('Loading captcha image from: ${widget.imageUrl}');
      final response = await _dio.get<List<int>>(
        widget.imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _imageBytes = Uint8List.fromList(response.data!);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load image: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error loading captcha image: $e');
      if (!mounted) return;
      
      setState(() {
        _errorMessage = '이미지를 불러올 수 없습니다';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshCaptcha() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = widget.imageUrl.contains('?')
        ? '${widget.imageUrl}&t=$timestamp'
        : '${widget.imageUrl}?t=$timestamp';

    setState(() {
      _imageBytes = null;
    });

    try {
      _logger.d('Loading captcha image from: $url');
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _imageBytes = Uint8List.fromList(response.data!);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load image: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error loading captcha image: $e');
      if (!mounted) return;
      
      setState(() {
        _errorMessage = '이미지를 불러올 수 없습니다';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: IntrinsicHeight(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '보안 문자 입력',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _refreshCaptcha,
                    tooltip: '새로고침',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildImageContent(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: '보안 문자 입력',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, letterSpacing: 4),
                autofocus: true,
                onSubmitted: (value) => _submit(value),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _submit(_controller.text),
                    child: const Text('확인'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    if (_isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_imageBytes != null) {
      return Image.memory(
        _imageBytes!,
        height: 60,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          _logger.e('Error displaying image: $error');
          return const Text(
            '이미지 표시 오류',
            style: TextStyle(color: Colors.red),
          );
        },
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: Colors.red),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  void _submit(String value) {
    if (value.isNotEmpty) {
      widget.onSubmit(value);
      Navigator.pop(context);
    }
  }
} 