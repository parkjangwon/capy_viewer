import 'package:html/parser.dart' as parser;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/manga.dart';
import '../models/title.dart';
import 'package:logger/logger.dart';

part 'parser_service.g.dart';

@riverpod
class ParserService extends _$ParserService {
  final _logger = Logger();

  @override
  ParserService build() {
    _logger.i('ParserService 초기화');
    return this;
  }

  List<MangaTitle> parseRecentTitles(String html) {
    final document = parser.parse(html);
    final titleElements = document.querySelectorAll('.webtoon-list li');

    return titleElements.map((element) {
      final link = element.querySelector('a');
      final img = element.querySelector('img');
      final name = element.querySelector('.name');

      return MangaTitle(
        id: int.tryParse(link?.attributes['href']?.split('/').last ?? '0') ?? 0,
        name: name?.text ?? '',
        url: link?.attributes['href'] ?? '',
        thumbnails: [img?.attributes['src'] ?? ''],
        chapters: [],
      );
    }).toList();
  }

  MangaTitle parseTitleDetail(String html) {
    final document = parser.parse(html);
    final titleElement = document.querySelector('.webtoon-info');
    final chapterElements = document.querySelectorAll('.webtoon-list li');

    final title = MangaTitle(
      id: 0,
      name: titleElement?.querySelector('.name')?.text ?? '',
      url: '',
      thumbnails: [
        titleElement?.querySelector('img')?.attributes['src'] ?? '',
      ],
      chapters: chapterElements.map((element) {
        final link = element.querySelector('a');
        final name = element.querySelector('.name');

        return Manga(
          id: int.tryParse(link?.attributes['href']?.split('/').last ?? '0') ?? 0,
          name: name?.text ?? '',
          url: link?.attributes['href'] ?? '',
          thumbnails: [],
          mode: MangaMode.vertical,
          images: [],
          date: '',
        );
      }).toList(),
    );

    return title;
  }

  Manga parseChapter(String html) {
    _logger.i('챕터 HTML 파싱 시작');
    try {
      final document = parser.parse(html);
      
      // Find the main content container
      final contentElement = document.querySelector('#toon_img');
      if (contentElement == null) {
        _logger.e('컨텐츠 요소를 찾을 수 없음');
        throw Exception('컨텐츠 요소를 찾을 수 없음');
      }

      // Find all image elements within the content
      final imageElements = contentElement.querySelectorAll('img');
      _logger.d('${imageElements.length}개의 이미지 요소 발견');

      if (imageElements.isEmpty) {
        _logger.w('챕터에 이미지가 없음');
        throw Exception('챕터에 이미지가 없음');
      }

      final images = imageElements.map((element) {
        final src = element.attributes['data-original'] ?? element.attributes['src'];
        if (src == null) {
          _logger.w('src 속성이 없는 이미지 요소 발견');
          return null;
        }
        _logger.v('이미지 URL 발견: $src');
        return src;
      }).where((src) => src != null).map((src) => src!).toList();

      _logger.i('챕터에서 ${images.length}개의 이미지를 성공적으로 파싱함');
      return Manga(
        id: 0,  // 임시 ID 값
        name: '',
        url: '',
        thumbnails: [],
        mode: MangaMode.vertical,
        images: images,
        date: '',
      );
    } catch (e, stack) {
      _logger.e('챕터 파싱 중 오류 발생', error: e, stackTrace: stack);
      throw Exception('챕터 파싱 실패: $e');
    }
  }

  List<MangaTitle> parseSearchResults(String html) {
    _logger.i('검색 결과 HTML 파싱 시작');
    
    try {
      final document = parser.parse(html);
      _logger.d('HTML 문서 파싱 완료');
      
      // 웹툰 목록 형식으로 시도
      final webtoonItems = document.querySelectorAll('.webtoon-list li');
      _logger.i('웹툰 목록 형식으로 찾은 아이템 수: ${webtoonItems.length}');
      
      if (webtoonItems.isEmpty) {
        _logger.w('검색 결과를 찾을 수 없음');
        // 전체 HTML 구조를 로그로 출력
        _logger.d('HTML 구조: ${document.outerHtml.substring(0, math.min(1000, document.outerHtml.length))}');
        return [];
      }
      
      return webtoonItems.map((item) {
        try {
          final linkElement = item.querySelector('a');
          final imgElement = item.querySelector('img');
          final titleElement = item.querySelector('.name');
          final authorElement = item.querySelector('.author');
          final categoryElement = item.querySelector('.etc');
          
          final title = titleElement?.text.trim() ?? '';
          final href = linkElement?.attributes['href'] ?? '';
          final thumbnail = imgElement?.attributes['src'] ?? '';
          final author = authorElement?.text.trim() ?? '';
          final category = categoryElement?.text.trim() ?? '';
          
          final id = _extractIdFromUrl(href);
          
          _logger.d('아이템 파싱: 제목=$title, 작가=$author, 카테고리=$category, URL=$href');
          
          return MangaTitle(
            id: id,
            name: title,
            url: href,
            thumbnails: thumbnail.isNotEmpty ? [thumbnail] : [],
            author: author,
            category: category,
            chapters: [],
          );
        } catch (e, stack) {
          _logger.e('아이템 파싱 실패', error: e, stackTrace: stack);
          return null;
        }
      })
      .where((item) => item != null)
      .cast<MangaTitle>()
      .toList();
    } catch (e, stack) {
      _logger.e('검색 결과 파싱 중 오류 발생', error: e, stackTrace: stack);
      throw Exception('검색 결과 파싱 실패: $e');
    }
  }

  int _extractIdFromUrl(String url) {
    try {
      final parts = url.split('/');
      return int.parse(parts.last);
    } catch (e) {
      _logger.w('URL에서 ID 추출 실패: $url');
      return 0;
    }
  }
} 