import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../data/models/manga_detail.dart';

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
  
  // 캡차 확인
  final hasCaptcha = _checkForCaptcha(html);
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
  
  // 제목 추출 - 실제 HTML에서 제목은 span 태그에 있음
  String title = '제목 없음';
  final titleElement = document.querySelector('.view-content span[style="font-size:20px"] b');
  if (titleElement != null) {
    title = titleElement.text.trim();
  }
  
  // 썸네일 이미지 추출
  String thumbnailUrl = '';
  final thumbnailElement = document.querySelector('.view-img img');
  if (thumbnailElement != null) {
    thumbnailUrl = thumbnailElement.attributes['src'] ?? '';
  }
  
  // 작가, 장르, 발행상태 추출
  String author = '';
  String genre = '';
  String releaseStatus = '';
  
  // 작가 정보 추출
  final authorElements = document.querySelectorAll('.view-content strong');
  for (final element in authorElements) {
    if (element.text.trim() == '작가') {
      // 작가 요소의 부모 요소에서 a 태그 찾기
      final parentDiv = element.parent;
      if (parentDiv != null) {
        final authorLink = parentDiv.querySelector('a');
        if (authorLink != null) {
          author = authorLink.text.trim();
        }
      }
    }
  }
  
  // 장르 정보 추출
  final genreElements = document.querySelectorAll('.view-content strong');
  for (final element in genreElements) {
    if (element.text.trim() == '분류') {
      // 분류 요소의 부모 요소에서 a 태그 찾기
      final parentDiv = element.parent;
      if (parentDiv != null) {
        final genreLinks = parentDiv.querySelectorAll('a');
        if (genreLinks.isNotEmpty) {
          genre = genreLinks.map((link) => link.text.trim()).join(', ');
        }
      }
    }
  }
  
  // 발행상태 정보 추출
  final releaseElements = document.querySelectorAll('.view-content strong');
  for (final element in releaseElements) {
    if (element.text.trim() == '발행구분') {
      // 발행구분 요소의 부모 요소에서 a 태그 찾기
      final parentDiv = element.parent;
      if (parentDiv != null) {
        final releaseLink = parentDiv.querySelector('a');
        if (releaseLink != null) {
          releaseStatus = releaseLink.text.trim();
        }
      }
    }
  }
  
  // 회차 목록 추출
  final chapters = _parseChapters(document);
  
  return MangaDetailParseResult(
    mangaDetail: MangaDetail(
      id: mangaId,
      title: title,
      thumbnailUrl: thumbnailUrl,
      author: author,
      genre: genre,
      releaseStatus: releaseStatus,
      chapters: chapters,
    ),
    hasCaptcha: false,
  );
}

List<MangaChapter> _parseChapters(Document document) {
  final List<MangaChapter> chapters = [];
  
  // 회차 목록 찾기 - 실제 HTML에서는 .serial-list .list-item으로 존재
  final chapterItems = document.querySelectorAll('.serial-list .list-item');
  if (chapterItems.isEmpty) {
    return chapters;
  }
  
  for (final item in chapterItems) {
    // 회차 번호 추출
    final numElement = item.querySelector('.wr-num');
    String chapterNum = numElement?.text.trim() ?? '';
    int chapterNumber = _parseNumber(chapterNum);
    
    // 회차 ID와 제목 추출
    final titleElement = item.querySelector('.wr-subject a');
    if (titleElement == null) continue;
    
    final href = titleElement.attributes['href'] ?? '';
    final chapterId = _extractChapterId(href);
    
    // 제목에서 댓글 수 추출 및 제목 정리
    String title = titleElement.text.trim();
    
    // 제목에서 숫자로 시작하는 부분 추출 (댓글 수)
    int comments = 0;
    final commentsMatch = RegExp(r'^\s*(\d+)\s*').firstMatch(title);
    if (commentsMatch != null && commentsMatch.groupCount >= 1) {
      comments = int.tryParse(commentsMatch.group(1) ?? '0') ?? 0;
    }
    
    // 제목에서 숫자로 시작하는 부분을 제거 (댓글 수)
    title = title.replaceFirst(RegExp(r'^\s*\d+\s*'), '');
    
    // 제목 끝에 있는 댓글 수와 공백 제거
    title = title.replaceFirst(RegExp(r'\s+\d+\s*$'), '');
    
    // 양쪽 공백 제거
    title = title.trim();
    
    if (chapterId.isEmpty || title.isEmpty) continue;
    
    // 업로드 날짜 추출
    String uploadDate = '';
    final dateElement = item.querySelector('.wr-date');
    if (dateElement != null) {
      uploadDate = dateElement.text.trim();
    }
    
    // 조회수 추출
    int views = 0;
    final viewsElement = item.querySelector('.wr-hit');
    if (viewsElement != null) {
      final viewsText = viewsElement.text.trim();
      views = _parseNumber(viewsText);
    }
    
    // 추천수 추출
    int likes = 0;
    final likesElement = item.querySelector('.wr-good');
    if (likesElement != null) {
      final likesText = likesElement.text.trim();
      likes = _parseNumber(likesText);
    }
    
    // 별점 추출
    int rating = 0;
    final ratingElement = item.querySelector('.wr-star');
    if (ratingElement != null) {
      final ratingText = ratingElement.text.trim();
      // 별점 텍스트에서 숫자 추출 (e.g., "(4.9)")
      final ratingMatch = RegExp(r'\((\d+\.?\d*)\)').firstMatch(ratingText);
      if (ratingMatch != null && ratingMatch.groupCount >= 1) {
        final ratingValue = double.tryParse(ratingMatch.group(1) ?? '0');
        if (ratingValue != null) {
          rating = (ratingValue * 10).round(); // 10점 만점 기준으로 변환
        }
      }
    }
    
    chapters.add(MangaChapter(
      id: chapterId,
      title: title,
      uploadDate: uploadDate,
      views: views,
      likes: likes,
      rating: rating,
      comments: comments,
    ));
  }
  
  return chapters;
}

String _extractChapterId(String href) {
  if (href.isEmpty) return '';
  
  // 예시: https://manatoki468.net/comic/12345?spage=1 형태의 URL에서 ID 추출
  final match = RegExp(r'/comic/([0-9]+)').firstMatch(href);
  return match?.group(1) ?? '';
}

int _parseNumber(String text) {
  // 숫자만 추출
  final numericText = text.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(numericText) ?? 0;
}

bool _checkForCaptcha(String html) {
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
