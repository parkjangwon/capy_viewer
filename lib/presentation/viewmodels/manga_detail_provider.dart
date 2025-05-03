import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/manga_detail.dart';
import '../screens/manga/manga_detail_webview_controller.dart';
import '../../utils/manga_detail_parser.dart';
import '../screens/captcha/captcha_screen.dart';
import 'global_cookie_provider.dart';
import '../../data/providers/site_url_provider.dart';

final mangaDetailControllerProvider = Provider.autoDispose<MangaDetailWebViewController>((ref) {
  return MangaDetailWebViewController();
});

final mangaDetailProvider = FutureProvider.family<MangaDetail, String>((ref, mangaId) async {
  final controller = ref.watch(mangaDetailControllerProvider);
  final baseUrl = ref.watch(siteUrlServiceProvider);
  
  // 웹뷰 초기화
  await controller.initialize();
  
  // 만화 상세 페이지 로드
  await controller.loadMangaDetail(baseUrl, mangaId);
  
  // HTML 가져오기
  final html = await controller.getHtml();
  
  // HTML 파싱
  final parseResult = parseMangaDetailFromHtml(html, mangaId);
  
  // 캡차 확인
  if (parseResult.hasCaptcha) {
    throw Exception('캡차 인증이 필요합니다.');
  }
  
  return parseResult.mangaDetail;
});
