import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

class SimpleMangaItem {
  final String title;
  final String href;
  SimpleMangaItem({required this.title, required this.href});
}

List<SimpleMangaItem> parseMangaListFromHtml(String html) {
  final document = html_parser.parse(html);
  final List<Element> listItems = document.querySelectorAll('#webtoon-list-all > li');
  final List<SimpleMangaItem> result = [];

  for (final li in listItems) {
    // .imgframe 내 a[title] 찾기
    final aTag = li.querySelector('.list-item .imgframe .in-lable a[title]');
    if (aTag != null) {
      final title = aTag.attributes['title'] ?? '';
      final href = aTag.attributes['href'] ?? '';
      if (title.isNotEmpty && href.isNotEmpty) {
        result.add(SimpleMangaItem(title: title, href: href));
      }
    }
  }
  return result;
}
