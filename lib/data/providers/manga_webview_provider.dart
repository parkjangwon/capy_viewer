import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/widgets/manga_webview_controller.dart';

/// 웹뷰 컨트롤러 프로바이더
/// 전역적으로 웹뷰 컨트롤러에 접근할 수 있도록 합니다.
final mangaWebViewControllerProvider = Provider<MangaWebViewController>((ref) {
  return MangaWebViewController();
});
