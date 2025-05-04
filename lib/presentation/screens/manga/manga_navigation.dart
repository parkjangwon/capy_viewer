import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/site_url_provider.dart';
import 'manga_detail_screen.dart'; // MangaDetailTestScreen이 이 파일에 있습니다

/// 만화 상세 화면으로 이동하는 유틸리티 함수
class MangaNavigation {
  /// 만화 상세 화면으로 이동
  /// [context] 현재 컨텍스트
  /// [mangaIdOrUrl] 만화 ID 또는 전체 URL
  /// [title] 만화 제목 (옵션)
  /// [isChapterUrl] 전체 URL을 전달하는 경우 true
  /// [parseFullPage] 전체 페이지를 파싱하여 전편보기 링크 추출
  static void navigateToMangaDetail(BuildContext context, String mangaIdOrUrl, {String? title, bool isChapterUrl = false, bool parseFullPage = false}) {
    // ProviderScope에서 사이트 URL 가져오기
    final container = ProviderScope.containerOf(context);
    final baseUrl = container.read(siteUrlServiceProvider);
    
    // 전체 URL이 전달된 경우
    String url;
    String mangaId;
    
    if (isChapterUrl) {
      // 이미 전체 URL이 전달된 경우
      if (mangaIdOrUrl.startsWith('http')) {
        url = mangaIdOrUrl;
        // URL에서 만화 ID 추출
        final match = RegExp(r'/comic/([0-9]+)').firstMatch(mangaIdOrUrl);
        mangaId = match?.group(1) ?? '';
      } else {
        // 상대 경로로 가정
        // baseUrl에서 끝에 슬래시가 있으면 제거
        final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
        url = mangaIdOrUrl.startsWith('/') ? '$cleanBaseUrl$mangaIdOrUrl' : '$cleanBaseUrl/$mangaIdOrUrl';
        // URL에서 만화 ID 추출
        final match = RegExp(r'/comic/([0-9]+)').firstMatch(url);
        mangaId = match?.group(1) ?? '';
      }
    } else {
      // 기존 방식: ID만 전달된 경우
      mangaId = mangaIdOrUrl;
      // baseUrl에서 끝에 슬래시가 있으면 제거
      final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      url = '$cleanBaseUrl/comic/$mangaId';
    }
    
    print('만화 상세 페이지 네비게이션: $url');
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MangaDetailTestScreen(
          mangaId: mangaId, 
          directUrl: isChapterUrl ? url : null,
          parseFullPage: parseFullPage,
        ),
      ),
    );
  }
  

}
