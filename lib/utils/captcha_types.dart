/// 캡차 타입을 정의하는 열거형
enum CaptchaType {
  /// 캡차 없음
  none,
  
  /// 마나토끼 자체 캡차
  manatoki,
  
  /// 클라우드플레어 캡차
  cloudflare,
  
  /// 알 수 없는 캡차 타입 (기타 서버 보안 조치)
  unknown,
}
