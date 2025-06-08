import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../utils/cloudflare_captcha.dart' as cf_utils;
import 'captcha/cloudflare_captcha.dart';

/// Cloudflare 캡차 처리를 위한 위젯
/// 웹뷰를 사용하여 Cloudflare 캡차를 처리합니다.
class CloudflareCaptchaWidget extends ConsumerStatefulWidget {
  final String url;
  final Function(bool success) onCaptchaComplete;

  const CloudflareCaptchaWidget({
    super.key,
    required this.url,
    required this.onCaptchaComplete,
  });

  @override
  ConsumerState<CloudflareCaptchaWidget> createState() =>
      _CloudflareCaptchaWidgetState();
}

class _CloudflareCaptchaWidgetState
    extends ConsumerState<CloudflareCaptchaWidget> {
  final _logger = Logger();
  bool _isLoading = true;
  String _errorMessage = '';
  int _retryCount = 0;
  Timer? _retryTimer;
  bool _callbackTriggered = false;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _logger.i('[캡차 위젯] 클라우드플레어 캡차 위젯 초기화: ${widget.url}');
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  // 캡차 성공 처리
  void _handleCaptchaSuccess(String html, List<String> cookies) {
    if (_callbackTriggered) {
      _logger.w('[캡차 위젯] 콜백이 이미 호출됨. 무시함');
      return;
    }

    _logger.i('[캡차 위젯] 캡차 성공 처리');
    _callbackTriggered = true;

    cf_utils.CloudflareCaptcha.saveCaptchaVerifiedTime();
    cf_utils.CloudflareCaptcha.saveCaptchaCookies(cookies, widget.url);

    setState(() {
      _isLoading = false;
    });

    // 즉시 콜백 호출
    if (mounted) {
      _logger.i('[캡차 위젯] 콜백 즉시 호출');
      widget.onCaptchaComplete(true);
    }
  }

  // 캡차 실패 처리
  void _handleCaptchaFailure(String error) {
    if (_callbackTriggered) {
      _logger.w('[캡차 위젯] 콜백이 이미 호출됨. 실패 처리 무시함');
      return;
    }

    _logger.w('[캡차 위젯] 캡차 실패: $error');
    _retryCount++;

    if (_retryCount >= _maxRetries) {
      setState(() {
        _isLoading = false;
        _errorMessage = '최대 재시도 횟수를 초과했습니다. 잠시 후 다시 시도해주세요.';
      });

      _callbackTriggered = true;
      widget.onCaptchaComplete(false);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            '인증 중 오류가 발생했습니다: $error (재시도 ${_retryCount}/$_maxRetries)';
      });

      _retryTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _isLoading = true;
            _errorMessage = '';
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.7),
        title: const Text('Cloudflare 보안 인증'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = '';
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_errorMessage.isNotEmpty)
            Container(
              color: Colors.red.withOpacity(0.1),
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Cloudflare 보안 인증 페이지를 로드하는 중입니다...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  )
                : CloudflareCaptcha(
                    initialUrl: Uri.parse(widget.url),
                    onVerified: _handleCaptchaSuccess,
                    onError: _handleCaptchaFailure,
                  ),
          ),
        ],
      ),
    );
  }
}
