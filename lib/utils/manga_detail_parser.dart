import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../data/models/manga_detail.dart';

String _cleanText(String input) {
  return input
      .replaceAll(RegExp(r'[\t\r\n]+'), ' ')
      .replaceAll(RegExp(r'\\t|\\r|\\n'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}

class MangaDetailParseResult {
  final MangaDetail mangaDetail;
  final bool hasCaptcha;

  MangaDetailParseResult({
    required this.mangaDetail,
    this.hasCaptcha = false,
  });
}

MangaDetailParseResult parseMangaDetailFromHtml(String html, String mangaId) {
  final document = html_parser.parse(html);

  // 캡챠 확인
  final hasCaptcha = checkForCaptcha(html);
  if (hasCaptcha) {
    return MangaDetailParseResult(
      mangaDetail: MangaDetail(
        id: mangaId,
        title: '',
        thumbnailUrl: '',
      ),
      hasCaptcha: true,
    );
  }

  // 제목
  String title = document
          .querySelector('.view-content span[style*="font-size:20px"] b')
          ?.text
          .trim() ??
      '';

  // 제목 선택자 테스트 (더 많은 선택자 시도)
  final titleSelectors = [
    '.view-content span[style="font-size:20px"] b',
    '.view-title h1',
    '.tit',
    'h1',
    '.title',
    '.subject',
    '.comic-subject',
    '.comic-title',
    '.manga-title',
    '.view-subject',
    'title',
    'h2',
    'h3',
    '.view-content strong',
    '.view-content b',
    '.view-content span'
  ];

  Element? titleElement;

  for (final selector in titleSelectors) {
    final element = document.querySelector(selector);

    if (element != null && element.text.trim().isNotEmpty) {
      titleElement = element;
      break;
    }
  }

  // 제목을 찾지 못한 경우, 페이지 제목에서 추출 시도
  if (titleElement == null) {
    final pageTitle = document.querySelector('title')?.text;
    if (pageTitle != null && pageTitle.isNotEmpty) {
      // 일반적으로 페이지 제목은 "제목 - 사이트이름" 형태
      final parts = pageTitle.split(' - ');
      if (parts.isNotEmpty) {
        title = _cleanText(parts[0]);
      }
    }
  } else {
    title = _cleanText(titleElement.text);
  }

  // 썸네일
  String thumbnailUrl =
      document.querySelector('.view-img img')?.attributes['src'] ?? '';

  // 썸네일 선택자 테스트 (더 많은 선택자 시도)
  final thumbnailSelectors = [
    '.view-img img',
    '.img-item img',
    '.view-content img',
    '.comic-img img',
    '.thumbnail img',
    '.cover img',
    '.comic-thumbnail img',
    '.manga-thumbnail img',
    '.thumb img',
    'img.thumb',
    'img.thumbnail',
    'img.cover',
    // 모든 이미지 중 처음 발견된 것
    'img'
  ];

  Element? thumbnailElement;

  for (final selector in thumbnailSelectors) {
    final element = document.querySelector(selector);
    final src = element?.attributes['src'];

    if (element != null && src != null && src.isNotEmpty) {
      thumbnailElement = element;
      break;
    }
  }

  // 이미지를 찾지 못한 경우, 모든 이미지 태그를 확인
  if (thumbnailElement == null) {
    final allImages = document.querySelectorAll('img');
    for (int i = 0; i < 5 && i < allImages.length; i++) {
      final img = allImages[i];
      final src = img.attributes['src'];

      // 첫 번째 유효한 이미지 사용
      if (src != null && src.isNotEmpty && thumbnailElement == null) {
        thumbnailElement = img;
      }
    }
  }

  if (thumbnailElement != null) {
    thumbnailUrl = thumbnailElement.attributes['src'] ?? '';
  } else {}

  // 작가
  String author = '';
  for (final strong in document.querySelectorAll('.view-content strong')) {
    if (strong.text.trim().contains('작가')) {
      final a = strong.parent?.querySelector('a');
      if (a != null) {
        author = _cleanText(a.text);
      }
      break;
    }
  }

  // 분류(장르) 여러 개 추출
  List<String> genres = [];
  for (final tag in document.querySelectorAll('.view-content.tags a')) {
    final text = tag.text.trim();
    if (text.isNotEmpty) genres.add(text);
  }

  // 발행상태
  String releaseStatus = '';
  for (final strong in document.querySelectorAll('.view-content strong')) {
    if (strong.text.trim().contains('발행구분')) {
      final a = strong.parent?.querySelector('a');
      if (a != null) {
        releaseStatus = _cleanText(a.text);
      }
      break;
    }
  }

  // 회차 목록
  final List<MangaChapter> chapters = [];
  final items = document.querySelectorAll('.serial-list .list-body .list-item');
  for (final item in items) {
    final aTag = item.querySelector('.wr-subject a');
    String title = '';
    int comments = 0;
    final comment = item.querySelector('.count.orangered.hidden-xs');
    if (comment != null) {
      comments = int.parse(comment.text.trim());
    }
    // 댓글 수 추출 및 span 제거
    aTag
        ?.querySelectorAll('.count, .wr-comment, .orangered')
        .forEach((e) => e.remove());
    // 제목 추출 (자식 태그 제거 후 텍스트만)
    title = _cleanText(aTag?.text ?? '');
    final href = aTag?.attributes['href'] ?? '';
    final idMatch = RegExp(r'/comic/(\d+)').firstMatch(href);
    final id = idMatch != null ? idMatch.group(1)! : '';
    final uploadDate = item.querySelector('.wr-date')?.text.trim() ?? '';
    final views = int.tryParse(
            item.querySelector('.wr-hit')?.text.replaceAll(',', '').trim() ??
                '0') ??
        0;
    final likes = int.tryParse(
            item.querySelector('.wr-good')?.text.replaceAll(',', '').trim() ??
                '0') ??
        0;
    final ratingText = item.querySelector('.wr-star')?.text ?? '';
    final ratingMatch = RegExp(r'\((\d+(?:\.\d+)?)\)').firstMatch(ratingText);
    final rating = ratingMatch != null
        ? double.tryParse(ratingMatch.group(1)!)?.toInt() ?? 0
        : 0;

    // 전편보기 버튼 링크 추출
    String? fullViewUrl;
    final fullViewButton =
        item.querySelector('button[data-original-title="전편보기"]');
    if (fullViewButton != null) {
      final onclick = fullViewButton.attributes['onclick'];
      if (onclick != null && onclick.contains("location.href='")) {
        final start = onclick.indexOf("location.href='") + 15;
        final end = onclick.indexOf("'", start);
        if (start > 0 && end > start) {
          fullViewUrl = onclick.substring(start, end);
        }
      }
    }

    if (id.isNotEmpty && title.isNotEmpty) {
      chapters.add(MangaChapter(
        id: id,
        title: title,
        uploadDate: uploadDate,
        views: views,
        likes: likes,
        rating: rating,
        comments: comments,
        fullViewUrl: fullViewUrl,
      ));
    }
  }

  // "전편보기" 링크 추출
  String previousChapterId = '';
  try {
    // 1. 정확한 선택자로 찾기: .pull-right.post-info 내부의 전편보기 버튼
    final postInfoDivs = document.querySelectorAll('.pull-right.post-info');

    for (final postInfo in postInfoDivs) {
      final links = postInfo.querySelectorAll('a');

      for (final link in links) {
        final text = link.text.trim();
        final rel = link.attributes['rel'];
        final href = link.attributes['href'];
        final className = link.attributes['class'] ?? '';

        // 전편보기 텍스트가 있는지 확인
        if (text.contains('전편보기')) {
          // rel 속성에서 ID 추출 시도
          if (rel != null && rel.isNotEmpty) {
            previousChapterId = rel;
            break;
          }

          // href URL에서 ID 추출 시도
          if (href != null && href.isNotEmpty) {
            final match = RegExp(r'/comic/([0-9]+)').firstMatch(href);
            if (match != null && match.groupCount >= 1) {
              previousChapterId = match.group(1)!;
              break;
            }
          }
        }
      }

      if (previousChapterId.isNotEmpty) break;
    }

    // 2. 버튼 클래스로 찾기
    if (previousChapterId.isEmpty) {
      final primaryButtons =
          document.querySelectorAll('a.btn-primary, a.btn-xs.btn-primary');

      for (final button in primaryButtons) {
        final text = button.text.trim();
        final rel = button.attributes['rel'];
        final href = button.attributes['href'];

        if (text.contains('전편보기')) {
          // rel 속성에서 ID 추출 시도
          if (rel != null && rel.isNotEmpty) {
            previousChapterId = rel;
            break;
          }

          // href URL에서 ID 추출 시도
          if (href != null && href.isNotEmpty) {
            final match = RegExp(r'/comic/([0-9]+)').firstMatch(href);
            if (match != null && match.groupCount >= 1) {
              previousChapterId = match.group(1)!;
              break;
            }
          }
        }
      }
    }

    // 3. 모든 링크를 검색하는 방법 (마지막 수단)
    if (previousChapterId.isEmpty) {
      final allLinks = document.querySelectorAll('a');

      for (final link in allLinks) {
        final text = link.text.trim();
        final rel = link.attributes['rel'];
        final href = link.attributes['href'];

        // 전편보기 텍스트가 있거나 rel 속성이 있는 경우
        if ((text.contains('전편보기') ||
                text.contains('전편') ||
                text.contains('이전')) &&
            href != null &&
            href.isNotEmpty &&
            href.contains('/comic/')) {
          final match = RegExp(r'/comic/([0-9]+)').firstMatch(href);
          if (match != null && match.groupCount >= 1) {
            previousChapterId = match.group(1)!;
            break;
          }
        }
      }
    }
  } catch (_) {
    // Ignore previous-chapter parsing failures and return partial data.
  }

  return MangaDetailParseResult(
    mangaDetail: MangaDetail(
      id: mangaId,
      title: title,
      thumbnailUrl: thumbnailUrl,
      author: author,
      genres: genres,
      releaseStatus: releaseStatus,
      chapters: chapters,
      previousChapterId: previousChapterId,
    ),
    hasCaptcha: false,
  );
}

List<MangaChapter> _parseChapters(Document document) {
  final List<MangaChapter> chapters = [];

  // 1. 테이블 기반 레이아웃 확인 (가장 일반적인 형태)
  final tables = document.querySelectorAll('table');

  // 테이블 중에서 회차 목록이 포함된 테이블 찾기
  Element? chapterTable;
  for (final table in tables) {
    final links = table.querySelectorAll('a[href*="/comic/"]');
    if (links.isNotEmpty) {
      chapterTable = table;
      break;
    }
  }

  // 2. 테이블 기반 레이아웃이 있는 경우 처리
  if (chapterTable != null) {
    final rows = chapterTable.querySelectorAll('tr');

    // 헤더 행을 제외한 데이터 행만 처리
    final dataRows = rows.length > 1 ? rows.sublist(1) : rows;

    for (final row in dataRows) {
      try {
        // 링크 추출
        final link = row.querySelector('a[href*="/comic/"]');
        if (link == null) continue;

        final href = link.attributes['href'] ?? '';
        final chapterId = _extractChapterId(href);
        if (chapterId.isEmpty) continue;

        // 제목 추출
        String title = link.text.trim();
        if (title.isEmpty) continue;

        // 제목 정제 - 불필요한 공백 및 특수문자 제거
        title = title.replaceAll(RegExp(r'\s+'), ' ').trim();

        // 회차 번호 추출 시도
        double? number = _parseNumber(title);

        // 업로드 날짜 추출
        String uploadDate = '';
        final dateCells = row.querySelectorAll('td');
        if (dateCells.length >= 4) {
          uploadDate = dateCells[dateCells.length - 1].text.trim();
        } else {
          final dateCell = row
              .querySelector('td:nth-child(4), td.date, td[data-title="등록일"]');
          if (dateCell != null) {
            uploadDate = dateCell.text.trim();
          }
        }

        // 조회수 추출
        int views = 0;
        final viewsCell = row.querySelector('td:nth-child(5)');
        if (viewsCell != null) {
          final viewsNumber = _parseNumber(viewsCell.text.trim());
          views = viewsNumber?.toInt() ?? 0;
        }

        chapters.add(MangaChapter(
          id: chapterId,
          title: title,
          uploadDate: uploadDate,
          views: views,
          likes: 0,
          rating: 0,
          comments: 0,
        ));
      } catch (e) {
        continue;
      }
    }

    if (chapters.isNotEmpty) {
      // 회차 목록 정렬 (ID 기준 내림차순 - 최신 회차가 먼저 오도록)
      chapters.sort((a, b) => int.parse(b.id).compareTo(int.parse(a.id)));
      return chapters;
    }
  }

  // 테이블 기반 파싱이 실패한 경우, 링크 기반 파싱 시도

  // 만화 관련 링크 찾기
  final comicLinks = document.querySelectorAll('a[href*="/comic/"]');

  if (comicLinks.isEmpty) {
    return chapters;
  }

  // 가장 많은 링크가 모여있는 부모 요소 찾기
  final Map<Element, int> parentCounts = {};
  for (final link in comicLinks) {
    // 부모 요소 3단계까지 확인
    Element? parent = link.parent;
    for (int i = 0; i < 3 && parent != null; i++) {
      parentCounts[parent] = (parentCounts[parent] ?? 0) + 1;
      parent = parent.parent;
    }
  }

  // 가장 많은 링크를 포함한 부모 요소 찾기
  Element? bestParent;
  int maxCount = 0;
  parentCounts.forEach((parent, count) {
    if (count > maxCount) {
      maxCount = count;
      bestParent = parent;
    }
  });

  if (bestParent == null) {
    return chapters;
  }

  // 이 부모 요소 내의 링크만 필터링
  final candidateLinks = comicLinks.where((link) {
    Element? currentParent = link.parent;
    for (int i = 0; i < 3 && currentParent != null; i++) {
      if (currentParent == bestParent) return true;
      currentParent = currentParent.parent;
    }
    return false;
  }).toList();

  // 회차 링크 필터링 (네비게이션 링크 제외)
  final chapterLinks = candidateLinks.where((link) {
    final text = link.text.trim();
    // 특정 키워드가 포함된 항목 필터링 (네비게이션 링크 등)
    if (text.contains('이전화') ||
        text.contains('다음화') ||
        text.contains('전체목록') ||
        text.contains('처음') ||
        text.contains('마지막')) {
      return false;
    }
    return true;
  }).toList();

  // 중복 ID 방지를 위한 세트
  final Set<String> processedIds = {};

  // 회차 정보 추출
  for (final link in chapterLinks) {
    try {
      final href = link.attributes['href'] ?? '';
      final chapterId = _extractChapterId(href);

      if (chapterId.isEmpty) continue;

      // 중복 ID 처리
      if (processedIds.contains(chapterId)) continue;
      processedIds.add(chapterId);

      String title = link.text.trim();

      // 제목이 비어있는 경우 처리
      if (title.isEmpty) continue;

      // 제목 정제 - 불필요한 공백 및 특수문자 제거
      title = title.replaceAll(RegExp(r'\s+'), ' ').trim();

      chapters.add(MangaChapter(
        id: chapterId,
        title: title,
        uploadDate: '', // 링크에서는 날짜 정보를 추출하기 어려움
        views: 0, // 기본값
        likes: 0,
        rating: 0,
        comments: 0,
      ));
    } catch (e) {
      continue;
    }
  }

  // 회차 목록 정렬 (ID 기준 내림차순 - 최신 회차가 먼저 오도록)
  chapters.sort((a, b) => int.parse(b.id).compareTo(int.parse(a.id)));

  return chapters;
}

String _extractChapterId(String href) {
  if (href.isEmpty) return '';

  // 예시: https://manatoki468.net/comic/12345?spage=1 형태의 URL에서 ID 추출
  final match = RegExp(r'/comic/([0-9]+)').firstMatch(href);
  return match?.group(1) ?? '';
}

double? _parseNumber(String text) {
  // 회차 번호 패턴 찾기 (예: 1화, 2화, 제3화, 제 4화, 4.5화 등)
  final match = RegExp(r'(\d+(?:\.\d+)?)\s*(?:화|회|\s*편)').firstMatch(text);
  if (match != null && match.groupCount >= 1) {
    try {
      return double.parse(match.group(1)!);
    } catch (_) {
      // Ignore malformed numeric chapter labels.
    }
  }

  // 숫자만 추출
  final numericMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
  if (numericMatch != null && numericMatch.groupCount >= 1) {
    try {
      return double.parse(numericMatch.group(1)!);
    } catch (_) {
      // Ignore malformed numeric values and keep parsing.
    }
  }

  return null;
}

bool checkForCaptcha(String html) {
  final htmlLower = html.toLowerCase();

  // 클라우드플레어 캡차 확인
  if (htmlLower.contains('challenge-form') ||
      htmlLower.contains('cf-please-wait') ||
      htmlLower.contains('_cf_chl_opt') ||
      htmlLower.contains('turnstile')) {
    return true;
  }

  // 마나토키 자체 캡차 확인
  if (htmlLower.contains('캡챠 인증') || htmlLower.contains('captcha.php')) {
    return true;
  }

  return false;
}
