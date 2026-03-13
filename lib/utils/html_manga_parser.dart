import 'package:html/parser.dart' as html_parser;

String _cleanText(String input) {
  return input
      .replaceAll(RegExp(r'[\t\r\n]+'), ' ')
      .replaceAll(RegExp(r'\\t|\\r|\\n'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}

class ParsedMangaItem {
  final String href;
  final String title;
  final String thumbnailUrl;
  final String author;
  final String period;
  final String updateDate;

  ParsedMangaItem({
    required this.href,
    required this.title,
    required this.thumbnailUrl,
    required this.author,
    required this.period,
    required this.updateDate,
  });
}

List<ParsedMangaItem> parseMangaListFromHtml(String html) {
  final document = html_parser.parse(html);
  final items = <ParsedMangaItem>[];

  // 검색 결과 목록 찾기
  final listItems = document.querySelectorAll('#webtoon-list-all > li');

  for (final item in listItems) {
    try {
      // 링크와 제목
      final titleElement = item.querySelector('.in-lable a');
      final href = titleElement?.attributes['href'] ?? '';
      final title =
          _cleanText(titleElement?.querySelector('.title')?.text ?? '');

      // 썸네일
      final imgElement = item.querySelector('.img-item img');
      final thumbnailUrl = imgElement?.attributes['src'] ?? '';

      // 작가
      final authorElement = item.querySelector('.list-artist a');
      final author = _cleanText(authorElement?.text ?? '');

      // 발행 주기
      final periodElement = item.querySelector('.list-publish a');
      final period = _cleanText(periodElement?.text ?? '');

      // 업데이트 날짜
      final dateElement = item.querySelector('.list-date');
      final updateDate = _cleanText(dateElement?.text ?? '');

      if (href.isNotEmpty && title.isNotEmpty) {
        items.add(ParsedMangaItem(
          href: href,
          title: title,
          thumbnailUrl: thumbnailUrl,
          author: author,
          period: period,
          updateDate: updateDate,
        ));
      }
    } catch (_) {
      // Skip malformed items and continue parsing the remaining results.
    }
  }

  return items;
}
