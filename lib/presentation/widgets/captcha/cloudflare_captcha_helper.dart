import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/logger.dart';

/// 클라우드플레어 캡차 처리를 위한 JavaScript 코드
class CloudflareCaptchaHelper {
  static final Logger _logger = Logger();
  
  /// 체크박스 클릭 스크립트
  static const String clickCheckboxScript = '''
  (function() {
    console.log('[캡차] 체크박스 클릭 시도');
    
    // 체크박스 찾기 및 클릭
    var checkboxes = document.querySelectorAll('input[type="checkbox"]');
    if (checkboxes.length > 0) {
      console.log('[캡차] 체크박스 발견: ' + checkboxes.length + '개');
      for (var i = 0; i < checkboxes.length; i++) {
        checkboxes[i].click();
        checkboxes[i].checked = true;
        console.log('[캡차] 체크박스 ' + i + ' 클릭 완료');
      }
      return true;
    }
    
    // 리캡차 특별 처리
    var recaptchaElements = document.querySelectorAll('.recaptcha-checkbox, .recaptcha-checkbox-border');
    if (recaptchaElements.length > 0) {
      console.log('[캡차] 리캡차 요소 발견: ' + recaptchaElements.length + '개');
      for (var i = 0; i < recaptchaElements.length; i++) {
        recaptchaElements[i].click();
        console.log('[캡차] 리캡차 요소 ' + i + ' 클릭 완료');
      }
      return true;
    }
    
    return false;
  })();
  ''';
  
  /// 폼 제출 스크립트
  static const String submitFormScript = '''
  (function() {
    console.log('[캡차] 폼 제출 시도');
    
    // 폼 찾기 및 제출
    var forms = document.querySelectorAll('form');
    if (forms.length > 0) {
      console.log('[캡차] 폼 발견: ' + forms.length + '개');
      forms[0].submit();
      console.log('[캡차] 폼 제출 완료');
      return true;
    }
    
    return false;
  })();
  ''';
  
  /// 버튼 클릭 스크립트
  static const String clickButtonsScript = '''
  (function() {
    console.log('[캡차] 버튼 클릭 시도');
    
    // 버튼 찾기 및 클릭
    var buttons = document.querySelectorAll('button, input[type="submit"], .cf-button');
    if (buttons.length > 0) {
      console.log('[캡차] 버튼 발견: ' + buttons.length + '개');
      for (var i = 0; i < buttons.length; i++) {
        buttons[i].click();
        console.log('[캡차] 버튼 ' + i + ' 클릭 완료');
      }
      return true;
    }
    
    return false;
  })();
  ''';
  
  /// iframe 처리 스크립트
  static const String processIframesScript = '''
  (function() {
    console.log('[캡차] iframe 처리 시도');
    
    // iframe 찾기
    var iframes = document.querySelectorAll('iframe');
    console.log('[캡차] iframe 발견: ' + iframes.length + '개');
    
    for (var i = 0; i < iframes.length; i++) {
      try {
        var iframe = iframes[i];
        console.log('[캡차] iframe ' + i + ' 처리 중');
        
        // iframe 내부 접근 시도
        var iframeDoc = iframe.contentDocument || iframe.contentWindow?.document;
        if (iframeDoc) {
          // iframe 내부 체크박스 클릭
          var checkboxes = iframeDoc.querySelectorAll('input[type="checkbox"]');
          if (checkboxes.length > 0) {
            console.log('[캡차] iframe ' + i + ' 내부 체크박스 발견: ' + checkboxes.length + '개');
            for (var j = 0; j < checkboxes.length; j++) {
              checkboxes[j].click();
              checkboxes[j].checked = true;
            }
          }
          
          // iframe 내부 버튼 클릭
          var buttons = iframeDoc.querySelectorAll('button, input[type="submit"]');
          if (buttons.length > 0) {
            console.log('[캡차] iframe ' + i + ' 내부 버튼 발견: ' + buttons.length + '개');
            for (var j = 0; j < buttons.length; j++) {
              buttons[j].click();
            }
          }
        }
      } catch (e) {
        console.log('[캡차] iframe ' + i + ' 처리 실패: ' + e.message);
      }
    }
  })();
  ''';
  
  /// 클라우드플레어 캡차 페이지 감지 스크립트
  static const String detectCaptchaScript = '''
  (function() {
    // 클라우드플레어 캡차 페이지 감지
    var isCaptchaPage = 
      document.title.includes('잠시만 기다리십시오') || 
      document.title.includes('Just a moment') || 
      document.querySelector('.cf-browser-verification') !== null ||
      document.querySelector('.cf-challenge-container') !== null ||
      document.querySelector('.cf-im-under-attack') !== null ||
      document.querySelector('.cf-error-code') !== null ||
      document.querySelector('#challenge-form') !== null ||
      document.querySelector('#cf-please-wait') !== null ||
      document.querySelector('#cf-spinner') !== null ||
      document.querySelector('[data-cf-challenge]') !== null;
    
    console.log('[캡차] 캡차 페이지 감지 결과: ' + (isCaptchaPage ? '캡차 페이지임' : '캡차 페이지 아님'));
    return isCaptchaPage;
  })();
  ''';
  
  /// 캡차 처리 실행 함수
  static Future<void> processCaptcha(WebViewController controller) async {
    try {
      _logger.i('[캡차] 캡차 처리 시작');
      
      // 1. 캡차 페이지인지 확인
      final isCaptchaPageResult = await controller.runJavaScriptReturningResult(detectCaptchaScript);
      final isCaptchaPage = isCaptchaPageResult.toString().toLowerCase() == 'true';
      
      if (!isCaptchaPage) {
        _logger.i('[캡차] 캡차 페이지가 아님, 처리 필요 없음');
        return;
      }
      
      _logger.w('[캡차] 캡차 페이지 감지됨, 자동 처리 시작');
      
      // 2. 체크박스 클릭 시도
      await controller.runJavaScript(clickCheckboxScript);
      
      // 3. 폼 제출 시도
      await controller.runJavaScript(submitFormScript);
      
      // 4. 버튼 클릭 시도
      await controller.runJavaScript(clickButtonsScript);
      
      // 5. iframe 처리 시도
      await controller.runJavaScript(processIframesScript);
      
      // 6. 페이지 상태 확인을 위한 콘솔 로그 추가
      await controller.runJavaScript('''
        console.log('[캡차] 캡차 처리 완료');
        console.log('[캡차] 현재 문서 제목: ' + document.title);
        console.log('[캡차] 현재 URL: ' + window.location.href);
      ''');
      
      _logger.i('[캡차] 캡차 처리 명령 실행 완료');
    } catch (e) {
      _logger.e('[캡차] 캡차 처리 중 오류 발생: $e');
    }
  }
  
  /// 캡차 페이지인지 확인하는 함수
  static Future<bool> isCaptchaPage(WebViewController controller) async {
    try {
      final result = await controller.runJavaScriptReturningResult(detectCaptchaScript);
      return result.toString().toLowerCase() == 'true';
    } catch (e) {
      _logger.e('[캡차] 캡차 페이지 확인 중 오류 발생: $e');
      return false;
    }
  }
  
  /// 페이지 HTML 가져오기
  static Future<String?> getPageHtml(WebViewController controller) async {
    try {
      final result = await controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML'
      );
      return result.toString();
    } catch (e) {
      _logger.e('[캡차] HTML 가져오기 실패: $e');
      return null;
    }
  }
  
  /// 페이지 쿠키 가져오기
  static Future<List<String>> getPageCookies(WebViewController controller) async {
    try {
      final result = await controller.runJavaScriptReturningResult('document.cookie');
      final cookieString = result.toString();
      
      if (cookieString.isEmpty || cookieString == 'null') {
        return [];
      }
      
      return cookieString
        .split(';')
        .map((cookie) => cookie.trim())
        .where((cookie) => cookie.isNotEmpty)
        .toList();
    } catch (e) {
      _logger.e('[캡차] 쿠키 가져오기 실패: $e');
      return [];
    }
  }
}
