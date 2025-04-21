import 'package:html/parser.dart' as parser;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_title.dart';
import 'dart:math' as math;
import 'package:logger/logger.dart';

part 'parser_service.g.dart';

@riverpod
class ParserService extends _$ParserService {
  // 최근 작품 목록 파싱
  List<MangaTitle> parseMangaList(String html) {
    return parseRecentTitles(html);
  }
  // 챕터 목록 파싱 (임시: 빈 리스트 반환)
  List<Chapter> parseChapters(String html) {
    // TODO: 실제 파싱 로직 구현
    return [];
  }
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
        id: link?.attributes['href']?.split('/').last ?? '',
        title: name?.text ?? '',
        thumbnailUrl: img?.attributes['src'] ?? '',
      );
    }).toList();
  }

  MangaTitle parseTitleDetail(String html) {
    final document = parser.parse(html);
    final titleElement = document.querySelector('.webtoon-info');
    return MangaTitle(
      id: '',
      title: titleElement?.querySelector('.name')?.text ?? '',
      thumbnailUrl: titleElement?.querySelector('img')?.attributes['src'] ?? '',
    );
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
      final webtoonItems = document.querySelectorAll('.webtoon-list li');
      _logger.i('웹툰 목록 형식으로 찾은 아이템 수: ${webtoonItems.length}');
      if (webtoonItems.isEmpty) {
        _logger.w('검색 결과를 찾을 수 없음');
        _logger.d('HTML 구조: ${document.outerHtml.substring(0, math.min(1000, document.outerHtml.length))}');
        return [];
      }
      return webtoonItems.map((item) {
        try {
          final linkElement = item.querySelector('a');
          final imgElement = item.querySelector('img');
          final titleElement = item.querySelector('.name');
          return MangaTitle(
            id: linkElement?.attributes['href']?.split('/').last ?? '',
            title: titleElement?.text.trim() ?? '',
            thumbnailUrl: imgElement?.attributes['src'] ?? '',
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


} 