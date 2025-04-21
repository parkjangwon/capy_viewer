import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

class SimpleMangaItem {
  final String title;
  final String href;
  final String thumbnailUrl;
  final String author;
  final String release;
  final String type; // 'manga' or 'webtoon'
  final String period; // '월간', '주간' 등
  final String updateDate;
  SimpleMangaItem({
    required this.title,
    required this.href,
    required this.thumbnailUrl,
    required this.author,
    required this.release,
    required this.type,
    required this.period,
    required this.updateDate,
  });
}

List<SimpleMangaItem> parseMangaListFromHtml(String html) {
  final document = html_parser.parse(html);
  final List<Element> listItems = document.querySelectorAll('#webtoon-list-all > li');
  final List<SimpleMangaItem> result = [];

  for (final li in listItems) {
    // 제목
    final titleTag = li.querySelector('.list-item .imgframe .in-lable a[title]');
    final titleSpan = li.querySelector('.list-item .imgframe .in-lable span.title');
    // 썸네일
    final imgTag = li.querySelector('.list-item .imgframe img');
    // 만화 상세 링크
    final href = titleTag?.attributes['href'] ?? '';
    // 작가
    final artistTag = li.querySelector('.list-item .list-artist a');
    // 연재 주기(월간, 격주 등)
    final publishTag = li.querySelector('.list-item .list-publish a');
    // 업데이트 날짜
    final dateTag = li.querySelector('.list-item .list-date');
    // 타입(만화/웹툰) 추정: img-wrap style의 비율이나 기타 badge로 추후 확장 가능
    // 값 추출
    final title = titleTag?.attributes['title'] ?? titleSpan?.text.trim() ?? '';
    final thumbnailUrl = imgTag?.attributes['src'] ?? '';
    final author = artistTag?.text.trim() ?? '';
    final period = publishTag?.text.trim() ?? '';
    final updateDate = dateTag?.text.trim() ?? '';
    if (title.isNotEmpty && href.isNotEmpty) {
      result.add(SimpleMangaItem(
        title: title,
        href: href,
        thumbnailUrl: thumbnailUrl,
        author: author,
        release: '', // 별도 정보 없음
        type: '', // type 제거
        period: period,
        updateDate: updateDate,
      ));
    }
  }
  return result;
}
