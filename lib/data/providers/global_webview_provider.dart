import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../presentation/widgets/manga_webview_controller.dart';

/// 컨트롤러 인스턴스 저장을 위한 글로벌 변수
WebViewController? _globalWebViewController;

/// 앱 전체에서 사용하는 WebView 컨트롤러 클래스 제공
/// 이를 통해 캡차 인증 상태와 쿠키가 모든 화면에서 공유됨
final mangaWebViewControllerProvider = Provider<MangaWebViewController>((ref) {
  return MangaWebViewController();
});

/// WebViewController 일단 생성해서 저장하는 함수
void setGlobalWebViewController(WebViewController controller) {
  _globalWebViewController = controller;
}

/// 저장된 WebViewController 가져오는 함수
WebViewController? getGlobalWebViewController() {
  return _globalWebViewController;
}
