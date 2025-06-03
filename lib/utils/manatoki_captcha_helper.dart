import 'package:html/parser.dart' as html_parser;

/// 마나토끼 캡챠 정보
class ManatokiCaptchaInfo {
  final String formAction;
  final String redirectUrl;
  final String captchaImageUrl;
  final Map<String, String> hiddenInputs;

  ManatokiCaptchaInfo({
    required this.formAction,
    required this.redirectUrl,
    required this.captchaImageUrl,
    required this.hiddenInputs,
  });
  
  /// Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'formAction': formAction,
      'redirectUrl': redirectUrl,
      'captchaImageUrl': captchaImageUrl,
      'hiddenInputs': hiddenInputs,
    };
  }
}

/// 마나토끼 캡챠 감지 및 정보 추출 헬퍼
class ManatokiCaptchaHelper {
  /// HTML 내용에서 마나토키 캡챠 필요 여부 확인
  static bool isCaptchaRequired(String html) {
    if (html.isEmpty) {
      print('빈 HTML 문자열이 전달되어 캡챠 필요 여부를 확인할 수 없습니다.');
      return false;
    }

    try {
      // 웹사이트 정상 접속 확인
      if (html.contains('접속이 안전하지 않음') ||
          html.contains('This site can\'t be reached')) {
        print('웹사이트에 접속할 수 없습니다.');
        return false;
      }

      // 마나토키 캡챠 확인 (여러 가지 패턴 확인)
      final isCaptchaRequired = html.contains('캡챠 인증!') || // 캡챠 인증 텍스트
          html.contains('captcha.php') || // 캡챠 파일 경로
          html.contains('kcaptcha_image.php') || // 캡챠 이미지 경로
          html.contains('form name="fcaptcha"') || // 캡챠 폼 이름
          html.contains('captcha_check.php'); // 캡챠 처리 경로

      if (isCaptchaRequired) {
        print('마나토키 캡챠 필요 확인: 캡챠 필요');
      }

      return isCaptchaRequired;
    } catch (e) {
      print('캡챠 필요 여부 확인 중 오류: $e');
      return false;
    }
  }

  /// HTML 내용에서 마나토끼 캡챠 정보 추출
  static ManatokiCaptchaInfo? extractCaptchaInfo(String html, String baseUrl) {
    if (html.isEmpty) {
      print('빈 HTML 문자열이 전달되어 캡챠 정보를 추출할 수 없습니다.');
      return null;
    }

    try {
      final document = html_parser.parse(html);

      // 캡챠 폼 찾기
      final captchaForm = document.querySelector('form[name="fcaptcha"]');
      if (captchaForm == null) {
        print('캡챠 폼을 찾을 수 없습니다.');
        return null;
      }

      // 폼 액션 URL 추출
      String formAction = captchaForm.attributes['action'] ?? '';
      if (formAction.isEmpty) {
        print('폼 액션 URL이 비어있습니다.');
        formAction = 'captcha_check.php'; // 기본값 사용
      }

      if (!formAction.startsWith('http')) {
        formAction = baseUrl +
            (formAction.startsWith('/') ? formAction : '/$formAction');
      }

      // 리다이렉트 URL 추출
      final redirectUrlInput = captchaForm.querySelector('input[name="url"]');
      final redirectUrl = redirectUrlInput?.attributes['value'] ?? '';

      // 캡챠 이미지 URL 추출 - 다양한 선택자 시도
      print('캡챠 이미지 추출 시도');
      String captchaImageUrl = '';

      // HTML 내용 일부 출력 (안전하게 처리)
      print('캡챠 HTML 내용 일부:');
      if (html.isNotEmpty) {
        final previewLength = html.length > 100 ? 100 : html.length;
        print(html.substring(0, previewLength));
      } else {
        print('빈 HTML 문자열');
      }

      // 이미지 선택자 순서대로 시도
      final captchaSelectors = [
        '.captcha_img',
        'img[src*="captcha"]',
        'img[src*="kcaptcha"]',
        'img[src*="kcaptcha_image"]',
        'form[name="fcaptcha"] img',
        'form img'
      ];

      // 모든 이미지 태그 출력
      final allImages = document.querySelectorAll('img');
      print('모든 이미지 태그 개수: ${allImages.length}');
      for (var i = 0; i < allImages.length; i++) {
        final img = allImages[i];
        final src = img.attributes['src'] ?? '';
        print('img[$i] src: $src');

        // 이미지 URL에 'captcha'나 'kcaptcha'가 포함되어 있는지 확인
        if (src.contains('captcha') || src.contains('kcaptcha')) {
          captchaImageUrl = src;
          print('캡챠 이미지 찾음 (direct): $captchaImageUrl');
          break;
        }
      }

      // 선택자로 찾지 못했다면 선택자 사용
      if (captchaImageUrl.isEmpty) {
        for (final selector in captchaSelectors) {
          final imgElement = document.querySelector(selector);
          if (imgElement != null && imgElement.attributes['src'] != null) {
            captchaImageUrl = imgElement.attributes['src'] ?? '';
            print('캡챠 이미지 찾음: $selector => $captchaImageUrl');
            break;
          }
        }
      }

      // 캡챠 이미지 URL이 없는 경우 기본값 사용
      if (captchaImageUrl.isEmpty) {
        print('캡챠 이미지 URL을 찾을 수 없어 기본값을 사용합니다.');
        captchaImageUrl = '/kcaptcha/kcaptcha_image.php';
      }

      // 이미지 URL이 상대 경로인 경우 절대 경로로 변환
      // 이미 절대 URL인지 확인
      final isAbsoluteUrl = captchaImageUrl.startsWith('http');

      if (!isAbsoluteUrl) {
        // 상대 경로인 경우 절대 경로로 변환
        final hasLeadingSlash = captchaImageUrl.startsWith('/');
        captchaImageUrl =
            baseUrl + (hasLeadingSlash ? captchaImageUrl : '/$captchaImageUrl');
      }

      print('최종 캡챠 이미지 URL: $captchaImageUrl');

      // 숨겨진 입력 필드 추출
      final hiddenInputs = <String, String>{};
      captchaForm.querySelectorAll('input[type="hidden"]').forEach((element) {
        final name = element.attributes['name'];
        final value = element.attributes['value'];
        if (name != null && value != null) {
          hiddenInputs[name] = value;
        }
      });

      return ManatokiCaptchaInfo(
        formAction: formAction,
        redirectUrl: redirectUrl,
        captchaImageUrl: captchaImageUrl,
        hiddenInputs: hiddenInputs,
      );
    } catch (e) {
      print('캡챠 정보 추출 중 오류: $e');
      return null;
    }
  }
}
