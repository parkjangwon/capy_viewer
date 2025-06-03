import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

class TestMangaParser {
  List<String> parseImages(String htmlString) {
    final document = html_parser.parse(htmlString);
    List<dom.Element> foundImages = [];

    print('=== 테스트 1: article[itemprop="articleBody"] ===');
    final article = document.querySelector('article[itemprop="articleBody"]');
    if (article != null) {
      print('article 태그 찾음');
      // article 내의 모든 img 태그를 순서대로 찾습니다
      final images = article.querySelectorAll('img');
      print('이미지 개수: ${images.length}');
      foundImages = images.toList();
    }

    // 이미지 URL 추출 및 필터링
    final urls = foundImages
        .map((img) {
          // data- 속성 확인
          final dataUrl = img.attributes.entries
              .where((attr) =>
                  (attr.key as String).startsWith('data-') &&
                  attr.value.contains('://'))
              .map((attr) => attr.value)
              .firstOrNull;

          // src 속성 확인
          final src = dataUrl ?? img.attributes['src'] ?? '';
          if (src.isNotEmpty && !src.contains('/tokinbtoki/')) {
            print('이미지 발견: $src');
            return src;
          }
          return '';
        })
        .where((url) => url.isNotEmpty)
        .toList();

    print('\n=== 최종 결과 ===');
    print('필터링된 이미지 URL 개수: ${urls.length}');

    return urls;
  }
}
