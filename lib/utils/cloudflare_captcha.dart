import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

/// 클라우드플레어 캡차 관련 유틸리티 클래스
class CloudflareCaptcha {
  static const String _captchaVerifiedTimeKey = 'cloudflare_captcha_verified_time';
  static const String _captchaCookiesKey = 'cloudflare_captcha_cookies';
  static const String _captchaSuccessUrlKey = 'cloudflare_captcha_success_url';
  static const int _captchaValidDuration = 3600; // 1시간 (초 단위)
  static final Logger _logger = Logger();

  /// 캡차 인증 시간 저장
  static Future<void> saveCaptchaVerifiedTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_captchaVerifiedTimeKey, now);
      _logger.i('[캡차] 인증 시간 저장: ${DateTime.fromMillisecondsSinceEpoch(now)}');
    } catch (e) {
      _logger.e('[캡차] 인증 시간 저장 실패', error: e);
    }
  }
  
  /// 캡차 인증 쿠키 저장
  static Future<void> saveCaptchaCookies(List<String> cookies, String url) async {
    try {
      if (cookies.isEmpty) {
        _logger.w('[캡차] 저장할 쿠키가 없음');
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_captchaCookiesKey, cookies);
      await prefs.setString(_captchaSuccessUrlKey, url);
      _logger.i('[캡차] 인증 쿠키 저장: ${cookies.length}개, URL: $url');
    } catch (e) {
      _logger.e('[캡차] 인증 쿠키 저장 실패', error: e);
    }
  }
  
  /// 저장된 캡차 쿠키 가져오기
  static Future<List<String>> getSavedCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cookies = prefs.getStringList(_captchaCookiesKey) ?? [];
      _logger.i('[캡차] 저장된 쿠키 로드: ${cookies.length}개');
      return cookies;
    } catch (e) {
      _logger.e('[캡차] 저장된 쿠키 로드 실패', error: e);
      return [];
    }
  }

  /// 캡차 인증이 유효한지 확인
  static Future<bool> isCaptchaVerified() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final verifiedTime = prefs.getInt(_captchaVerifiedTimeKey);
      final cookies = prefs.getStringList(_captchaCookiesKey);
      
      if (verifiedTime == null || cookies == null || cookies.isEmpty) {
        _logger.w('[캡차] 인증 정보 없음');
        return false;
      }
      
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsedSeconds = (now - verifiedTime) ~/ 1000;
      final isValid = elapsedSeconds < _captchaValidDuration;
      
      _logger.i('[캡차] 인증 상태 확인: $isValid (경과 시간: ${elapsedSeconds}초)');
      return isValid;
    } catch (e) {
      _logger.e('[캡차] 인증 상태 확인 실패', error: e);
      return false;
    }
  }

  /// 캡차 인증 정보 초기화
  static Future<void> resetCaptchaVerification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_captchaVerifiedTimeKey);
      await prefs.remove(_captchaCookiesKey);
      await prefs.remove(_captchaSuccessUrlKey);
      _logger.i('[캡차] 인증 정보 초기화 완료');
    } catch (e) {
      _logger.e('[캡차] 인증 정보 초기화 실패', error: e);
    }
  }
  
  /// 클라우드플레어 캡차 페이지인지 확인
  static bool isCloudflareChallengePage(String htmlContent) {
    if (htmlContent.isEmpty) {
      return false;
    }
    
    // 클라우드플레어 캡차 페이지 확인
    final isCaptchaPage = htmlContent.contains('<title>잠시만 기다리십시오…</title>') ||
           htmlContent.contains('challenge-error-text') ||
           htmlContent.contains('Just a moment...') ||
           htmlContent.contains('cf-browser-verification') ||
           htmlContent.contains('cloudflare-challenge') ||
           htmlContent.contains('cf_captcha_kind') ||
           htmlContent.contains('cf-please-wait') ||
           htmlContent.contains('cf-spinner') ||
           htmlContent.contains('turnstile');
    
    if (isCaptchaPage) {
      _logger.w('[캡차] 클라우드플레어 캡차 페이지 감지됨');
    }
    
    return isCaptchaPage;
  }
}
