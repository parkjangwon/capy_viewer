import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../data/models/manga_chapter.dart';

class MangaChapterParser {
  /// HTML에서 회차 목록을 파싱합니다.
  static List<MangaChapter> parseChapterList(
      String html, String currentChapterId) {
    try {
      final document = html_parser.parse(html);
      final chapterList = <MangaChapter>[];

      // 회차 목록을 찾습니다.
      final chapterElements =
          document.querySelectorAll('.list-body .list-item');

      for (final element in chapterElements) {
        final linkElement = element.querySelector('a');
        if (linkElement == null) continue;

        final url = linkElement.attributes['href'] ?? '';
        if (url.isEmpty) continue;

        // ID 추출
        final idMatch = RegExp(r'/comic/(\d+)').firstMatch(url);
        final id = idMatch?.group(1) ?? '';
        if (id.isEmpty) continue;

        // 제목 추출
        String title = linkElement.text.trim();

        // 업로드 날짜 추출
        final dateElement = element.querySelector('.item-date');
        final uploadDate = dateElement?.text.trim() ?? '';

        // 조회수 추출
        final viewsElement = element.querySelector('.item-views');
        int views = 0;
        if (viewsElement != null) {
          final viewsText = viewsElement.text.replaceAll(RegExp(r'[^0-9]'), '');
          views = int.tryParse(viewsText) ?? 0;
        }

        chapterList.add(MangaChapter(
          id: id,
          title: title,
          url: url,
          uploadDate: uploadDate,
          views: views,
          isCurrent: id == currentChapterId,
        ));
      }

      return chapterList;
    } catch (e) {
      print('회차 목록 파싱 오류: $e');
      return [];
    }
  }
}
