import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../utils/network_image_with_headers.dart';

typedef OnVerifiedCallback = void Function(String html, List<String> cookies);
typedef OnErrorCallback = void Function(String error);

/// 클라우드플레어 캡차 처리 위젯 (Flutter 네이티브 구현)
class CloudflareCaptcha extends ConsumerStatefulWidget {
  final Uri initialUrl;
  final OnVerifiedCallback onVerified;
  final OnErrorCallback? onError;
  final Duration loadingDuration;
  final bool allowRedirects;

  const CloudflareCaptcha({
    super.key,
    required this.initialUrl,
    required this.onVerified,
    this.onError,
    this.loadingDuration = const Duration(seconds: 10),
    this.allowRedirects = true,
  });

  @override
  ConsumerState<CloudflareCaptcha> createState() => _CloudflareCaptchaState();
}

class _CloudflareCaptchaState extends ConsumerState<CloudflareCaptcha> {
  bool _isLoading = false;
  String? _captchaImageUrl;
  String? _errorMessage;
  String _userInput = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCaptchaImage();
  }

  void _loadCaptchaImage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _captchaImageUrl = widget.initialUrl.toString();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '캡차 이미지 로딩 중 오류가 발생했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
          child: Text(_errorMessage!, style: TextStyle(color: Colors.red)));
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_captchaImageUrl != null)
            NetworkImageWithHeaders(
              url: _captchaImageUrl!,
              width: 240,
              height: 80,
              fit: BoxFit.contain,
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: TextField(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '캡챠 입력',
              ),
              onChanged: (v) => _userInput = v,
              enabled: !_isSubmitting,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitCaptcha,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('제출'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitCaptcha() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final response = await http.post(
        widget.initialUrl,
        body: {'captcha': _userInput},
      );
      if (response.statusCode == 200) {
        widget.onVerified(response.body, []);
      } else {
        setState(() {
          _errorMessage = '캡차 인증에 실패했습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '캡차 인증 요청 중 오류가 발생했습니다.';
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}
