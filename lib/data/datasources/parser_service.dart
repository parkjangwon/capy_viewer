import 'package:html/parser.dart' as parser;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/manga.dart';
import '../models/chapter.dart' as model;
import '../models/manga_title.dart';
import '../models/manga_viewer_state.dart';
import 'dart:math' as math;
import 'package:logger/logger.dart';

part 'parser_service.g.dart';

class ParserResult {
  final Manga? manga;
  final CaptchaType captchaType;
  final String errorMessage;

  ParserResult({
    this.manga,
    this.captchaType = CaptchaType.none,
    this.errorMessage = '',
  });
}

@riverpod
class ParserService extends _$ParserService {
  // 최근 작품 목록 파싱
  List<MangaTitle> parseMangaList(String html) {
    if (html.isEmpty) {
      _logger.w('빈 HTML 문자열이 전달됨');
      return [];
    }
    return parseRecentTitles(html);
  }

  // 챕터 목록 파싱
  List<model.Chapter> parseChapters(String html) {
    _logger.i('챕터 목록 HTML 파싱 시작');
    if (html.isEmpty) {
      _logger.w('빈 HTML 문자열이 전달됨');
      return [];
    }

    try {
      final document = parser.parse(html);
      final chapterElements = document.querySelectorAll('.webtoon-list li');

      if (chapterElements.isEmpty) {
        _logger.w('챕터 목록을 찾을 수 없음');
        return [];
      }

      return chapterElements
          .map((element) {
            try {
              final link = element.querySelector('a');
              final title = element.querySelector('.name');
              final date = element.querySelector('.date');

              if (link == null || title == null) {
                _logger.w('필수 요소가 없는 챕터 발견');
                return null;
              }

              final url = link.attributes['href'];
              if (url == null || url.isEmpty) {
                _logger.w('URL이 없는 챕터 발견');
                return null;
              }

              final chapterId = url.split('/').last;
              if (chapterId.isEmpty) {
                _logger.w('챕터 ID를 추출할 수 없음');
                return null;
              }

              final titleText = title.text.trim();
              if (titleText.isEmpty) {
                _logger.w('제목이 없는 챕터 발견');
                return null;
              }

              return model.Chapter(
                id: chapterId,
                title: titleText,
                url: url,
                uploadDate: date != null && date.text.trim().isNotEmpty
                    ? DateTime.parse(date.text.trim())
                    : DateTime.now(),
              );
            } catch (e, stack) {
              _logger.e('챕터 파싱 실패', error: e, stackTrace: stack);
              return null;
            }
          })
          .where((chapter) => chapter != null)
          .cast<model.Chapter>()
          .toList();
    } catch (e, stack) {
      _logger.e('챕터 목록 파싱 중 오류 발생', error: e, stackTrace: stack);
      throw Exception('챕터 목록 파싱 실패: $e');
    }
  }

  final _logger = Logger();

  @override
  ParserService build() {
    _logger.i('ParserService 초기화');
    return this;
  }

  List<MangaTitle> parseRecentTitles(String html) {
    if (html.isEmpty) {
      _logger.w('빈 HTML 문자열이 전달됨');
      return [];
    }

    final document = parser.parse(html);
    final titleElements = document.querySelectorAll('.webtoon-list li');

    return titleElements
        .map((element) {
          try {
            final link = element.querySelector('a');
            final img = element.querySelector('img');
            final name = element.querySelector('.name');

            if (link == null || name == null) {
              _logger.w('필수 요소가 없는 작품 발견');
              return null;
            }

            final href = link.attributes['href'];
            if (href == null || href.isEmpty) {
              _logger.w('URL이 없는 작품 발견');
              return null;
            }

            final id = href.split('/').last;
            if (id.isEmpty) {
              _logger.w('작품 ID를 추출할 수 없음');
              return null;
            }

            final titleText = name.text.trim();
            if (titleText.isEmpty) {
              _logger.w('제목이 없는 작품 발견');
              return null;
            }

            return MangaTitle(
              id: id,
              title: titleText,
              thumbnailUrl: img?.attributes['src'] ?? '',
            );
          } catch (e, stack) {
            _logger.e('작품 파싱 실패', error: e, stackTrace: stack);
            return null;
          }
        })
        .where((title) => title != null)
        .cast<MangaTitle>()
        .toList();
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

  ParserResult parseChapter(String html) {
    _logger.i('챕터 HTML 파싱 시작');

    // 클라우드플레어 캡차 감지 조건 강화
    if (_isCaptchaOrRedirect(html)) {
      _logger.e('[캡차감지] 클라우드플레어 캡차 감지됨');
      return ParserResult(
        captchaType: CaptchaType.cloudflare,
        errorMessage: '캡차 인증이 필요합니다',
      );
    }

    try {
      final document = parser.parse(html);
      final contentElement = document.querySelector('#toon_img');

      if (contentElement == null) {
        return ParserResult(
          errorMessage: '컨텐츠를 찾을 수 없습니다',
        );
      }

      final imageElements = contentElement.querySelectorAll('img');
      if (imageElements.isEmpty) {
        return ParserResult(
          errorMessage: '이미지를 찾을 수 없습니다',
        );
      }

      final images = imageElements
          .map((element) {
            final src = element.attributes['data-original'] ??
                element.attributes['src'];
            return src;
          })
          .where((src) => src != null)
          .map((src) => src!)
          .toList();

      if (images.isEmpty) {
        return ParserResult(
          errorMessage: '이미지 URL을 추출할 수 없습니다',
        );
      }

      return ParserResult(
        manga: Manga(
          id: 0,
          name: '',
          url: '',
          thumbnails: [],
          mode: MangaMode.vertical,
          images: images,
          date: '',
        ),
      );
    } catch (e, stack) {
      _logger.e('[파싱실패] 챕터 파싱 중 오류 발생', error: e, stackTrace: stack);
      return ParserResult(
        errorMessage: '파싱 중 오류가 발생했습니다: $e',
      );
    }
  }

  CaptchaType _detectCaptchaType(String html) {
    if (_isCaptchaOrRedirect(html)) {
      return CaptchaType.cloudflare;
    }
    return CaptchaType.none;
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
        _logger.d(
            'HTML 구조: ${document.outerHtml.substring(0, math.min(1000, document.outerHtml.length))}');
        return [];
      }
      return webtoonItems
          .map((item) {
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

  // 파일 내 private 함수로 추가
  bool _isCaptchaOrRedirect(String html) {
    final patterns = [
      "<title>Loading...</title>",
      "data-adblockkey",
      "Just a moment...",
      "Checking if the site connection is secure",
      "Enable JavaScript and cookies to continue",
      "Please wait while we verify your browser",
      "Please turn JavaScript on and reload the page",
      "cf-browser-verification",
      "cf_captcha_kind",
      "cf-please-wait",
      "challenge-form",
      "cf_challenge",
      "turnstile",
      "cf-content",
      "_cf_chl_opt",
      "cf_chl_prog"
    ];

    return patterns.any((pattern) => html.contains(pattern));
  }
}
