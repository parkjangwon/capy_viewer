import 'package:flutter/material.dart';
import 'manga_detail_screen.dart';

/// 만화 상세 화면으로 이동하는 유틸리티 함수
class MangaNavigation {
  /// 만화 상세 화면으로 이동
  /// [context] 현재 컨텍스트
  /// [mangaId] 만화 ID
  /// [title] 만화 제목 (옵션)
  static void navigateToMangaDetail(BuildContext context, String mangaId, {String? title}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MangaDetailTestScreen(mangaId: mangaId),
      ),
    );
  }
  

}
