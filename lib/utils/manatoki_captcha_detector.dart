import 'package:html/parser.dart' as html_parser;

/// 마나토끼 캡차 정보를 담는 클래스
class ManatokiCaptchaInfo {
  final String formActionUrl;
  final String redirectUrl;
  final String captchaImageUrl;
  
  ManatokiCaptchaInfo({
    required this.formActionUrl,
    required this.redirectUrl,
    required this.captchaImageUrl,
  });
  
  factory ManatokiCaptchaInfo.fromMap(Map<String, String> map) {
    return ManatokiCaptchaInfo(
      formActionUrl: map['formActionUrl'] ?? '',
      redirectUrl: map['redirectUrl'] ?? '',
      captchaImageUrl: map['captchaImageUrl'] ?? '',
    );
  }
  
  Map<String, String> toMap() {
    return {
      'formActionUrl': formActionUrl,
      'redirectUrl': redirectUrl,
      'captchaImageUrl': captchaImageUrl,
    };
  }
}

/// 마나토끼 캡챠 페이지인지 확인하는 함수
bool isManatokiCaptchaUrl(String htmlContent, String baseUrl) {
  // HTML 문서 파싱
  final document = html_parser.parse(htmlContent);
  
  // 캡챠 확인 로직 (더 정확한 감지를 위해 여러 조건 추가)
  
  // 1. "캡챠 인증!" 문자열 찾기
  final hasCaptchaText = document.body?.text.contains('캡챠 인증!') ?? false;
  
  // 2. "captcha.php" 포함 여부 확인
  final hasCaptchaPhp = htmlContent.contains('captcha.php');
  
  // 3. 폼 이름 "fcaptcha" 확인
  final hasCaptchaForm = document.querySelector('form[name="fcaptcha"]') != null;
  
  // 4. 캡챠 이미지 태그 확인
  final hasCaptchaImg = document.querySelector('.captcha_img') != null || 
                       document.querySelector('img[src*="captcha.php"]') != null;
  
  // 5. 캡챠 입력 필드 확인
  final hasCaptchaInput = document.querySelector('input[name="captcha"]') != null ||
                         document.querySelector('input[name="captcha_code"]') != null;
  
  // 6. 타이틀에 캡챠 관련 텍스트 확인
  final titleElement = document.querySelector('title');
  final hasCaptchaInTitle = titleElement != null && 
                           (titleElement.text.contains('캡챠') || 
                            titleElement.text.contains('captcha') ||
                            titleElement.text.contains('인증'));
  
  // 여러 조건 중 일정 수 이상이 만족되면 캡챠로 판단
  int matchCount = 0;
  if (hasCaptchaText) matchCount++;
  if (hasCaptchaPhp) matchCount++;
  if (hasCaptchaForm) matchCount++;
  if (hasCaptchaImg) matchCount++;
  if (hasCaptchaInput) matchCount++;
  if (hasCaptchaInTitle) matchCount++;
  
  // 적어도 2개 이상의 조건이 만족되면 캡챠로 판단
  return matchCount >= 2;
}

/// 캡챠 페이지에서 필요한 정보를 추출하는 함수
Map<String, String> extractCaptchaInfo(String htmlContent, String baseUrl) {
  final document = html_parser.parse(htmlContent);
  final result = <String, String>{};
  
  // 폼 액션 URL 추출
  final captchaForm = document.querySelector('form[name="fcaptcha"]');
  if (captchaForm != null) {
    final action = captchaForm.attributes['action'];
    if (action != null) {
      // 절대 경로인지 상대 경로인지 확인
      result['formActionUrl'] = action.startsWith('http') 
          ? action 
          : action.startsWith('/') 
              ? '$baseUrl$action' 
              : '$baseUrl/$action';
    }
  }
  
  // 리다이렉트 URL 추출
  final urlInput = document.querySelector('input[name="url"]');
  if (urlInput != null) {
    final redirectUrl = urlInput.attributes['value'];
    if (redirectUrl != null) {
      result['redirectUrl'] = redirectUrl;
    }
  }
  
  // 캡챠 이미지 URL 추출
  final captchaImg = document.querySelector('.captcha_img');
  if (captchaImg != null) {
    final imgSrc = captchaImg.attributes['src'];
    if (imgSrc != null) {
      // 절대 경로인지 상대 경로인지 확인
      result['captchaImageUrl'] = imgSrc.startsWith('http') 
          ? imgSrc 
          : imgSrc.startsWith('/') 
              ? '$baseUrl$imgSrc' 
              : '$baseUrl/$imgSrc';
    }
  }
  
  return result;
}
