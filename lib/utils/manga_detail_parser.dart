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
  print('파싱 시작: mangaId=$mangaId, HTML 길이=${html.length}');
  final document = html_parser.parse(html);
  
  // 캡챠 확인
  final hasCaptcha = _checkForCaptcha(html);
  print('캡챠 확인 결과: $hasCaptcha');
  if (hasCaptcha) {
    print('캡챠 감지됨: 빈 데이터 반환');
    return MangaDetailParseResult(
      mangaDetail: MangaDetail(
        id: mangaId,
        title: '',
        thumbnailUrl: '',
      ),
      hasCaptcha: true,
    );
  }
  
  // 현재 URL 확인 (URL에 이상이 있는지 확인)
  final currentUrl = document.querySelector('link[rel="canonical"]')?.attributes['href'] ?? '';
  print('현재 페이지 URL: $currentUrl');
  
  // URL에 이상이 있는지 확인 (리디렉션 등)
  if (!currentUrl.contains('/comic/$mangaId') && currentUrl.isNotEmpty) {
    print('예상하지 않은 URL 감지: $currentUrl');
  }
  
  // HTML 구조 디버깅
  print('주요 HTML 요소:');
  print('- title 태그: ${document.querySelector('title')?.text}');
  print('- body 클래스: ${document.querySelector('body')?.classes.join(', ')}');
  print('- h1 태그 개수: ${document.querySelectorAll('h1').length}');
  print('- img 태그 개수: ${document.querySelectorAll('img').length}');
  print('- 첫 번째 img src: ${document.querySelector('img')?.attributes['src']}');
  
  // 추가 디버깅 정보
  print('\n상세 HTML 구조 분석:');
  final allDivs = document.querySelectorAll('div');
  print('- div 태그 개수: ${allDivs.length}');
  
  // 클래스별 div 개수 확인
  final divClasses = <String, int>{};
  for (final div in allDivs) {
    for (final className in div.classes) {
      divClasses[className] = (divClasses[className] ?? 0) + 1;
    }
  }
  
  // 가장 많이 사용된 클래스 출력
  final sortedClasses = divClasses.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  
  print('- 가장 많이 사용된 div 클래스:');
  for (int i = 0; i < 5 && i < sortedClasses.length; i++) {
    print('  * ${sortedClasses[i].key}: ${sortedClasses[i].value}개');
  }
  
  // 제목 추출 - 실제 HTML에서 제목은 다양한 태그에 있을 수 있음
  String title = '제목 없음';
  
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
  
  print('\n제목 선택자 테스트:');
  Element? titleElement;
  
  for (final selector in titleSelectors) {
    final element = document.querySelector(selector);
    print('- $selector: ${element?.text}');
    
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
        title = parts[0].trim();
      }
    }
  } else {
    title = titleElement.text.trim();
  }
  
  print('제목 추출 ' + (titleElement != null ? '성공' : '실패') + ': $title');
  
  // 썸네일 이미지 추출
  String thumbnailUrl = '';
  
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
  
  print('\n썸네일 선택자 테스트:');
  Element? thumbnailElement;
  
  for (final selector in thumbnailSelectors) {
    final element = document.querySelector(selector);
    final src = element?.attributes['src'];
    print('- $selector: $src');
    
    if (element != null && src != null && src.isNotEmpty) {
      thumbnailElement = element;
      break;
    }
  }
  
  // 이미지를 찾지 못한 경우, 모든 이미지 태그를 확인
  if (thumbnailElement == null) {
    final allImages = document.querySelectorAll('img');
    print('\n모든 이미지 태그 확인:');
    for (int i = 0; i < 5 && i < allImages.length; i++) {
      final img = allImages[i];
      final src = img.attributes['src'];
      print('- img[$i]: $src');
      
      // 첫 번째 유효한 이미지 사용
      if (src != null && src.isNotEmpty && thumbnailElement == null) {
        thumbnailElement = img;
      }
    }
  }
  
  if (thumbnailElement != null) {
    thumbnailUrl = thumbnailElement.attributes['src'] ?? '';
    print('썸네일 추출 ' + (thumbnailUrl.isNotEmpty ? '성공' : '실패') + ': $thumbnailUrl');
  } else {
    print('썸네일 요소를 찾을 수 없음');
  }
  
  // 작가, 장르, 발행상태 추출
  String author = '';
  String genre = '';
  String releaseStatus = '';
  
  print('\n작가, 장르, 발행구분 정보 추출 시작');
  
  // 1. view-content 요소들 추출
  final viewContents = document.querySelectorAll('.view-content');
  print('view-content 요소 개수: ${viewContents.length}');
  
  // 2. 작가 정보 추출 - 여러 방법 시도
  print('\n작가 정보 추출 시도:');
  
  // 2.1. 새로운 선택자 시도 - 이미지 옆 작가 정보
  final authorSelectors = [
    '.view-content .view-info:contains(작가) a',
    '.view-content .view-info a',
    '.view-content .view-title + .view-content a',
    '.view-content a[href*="/author/"]',
    '.view-content a[href*="/artist/"]',
    '.manga-info .author a',
    '.comic-info .author a',
    '.profile-info .author',
    '.profile-info a',
  ];
  
  for (final selector in authorSelectors) {
    try {
      final elements = document.querySelectorAll(selector);
      print('- $selector: ${elements.length} 요소 발견');
      
      if (elements.isNotEmpty) {
        for (final element in elements) {
          final text = element.text.trim();
          if (text.isNotEmpty && !text.contains('분류') && !text.contains('발행') && !text.contains('상태')) {
            author = text;
            print('선택자로 작가 발견: $author');
            break;
          }
        }
      }
      
      if (author.isNotEmpty) break;
    } catch (e) {
      print('선택자 오류: $selector - $e');
    }
  }
  
  // 2.2. strong 태그로 작가 라벨이 있는 요소 찾기
  if (author.isEmpty) {
    Element? authorLabelElement;
    for (final content in viewContents) {
      final strongElements = content.querySelectorAll('strong, span.title, span.label, th');
      for (final strong in strongElements) {
        if (strong.text.contains('작가')) {
          authorLabelElement = strong;
          print('작가 라벨 발견: ${strong.outerHtml}');
          break;
        }
      }
      if (authorLabelElement != null) break;
    }
    
    // 작가 라벨이 있는 경우 그 주변에서 정보 추출
    if (authorLabelElement != null) {
      // 부모 요소 찾기
      Element? parentElement = authorLabelElement.parent;
      if (parentElement != null) {
        // a 태그 찾기
        final authorLinks = parentElement.querySelectorAll('a');
        if (authorLinks.isNotEmpty) {
          author = authorLinks.first.text.trim();
          print('작가 정보 추출 (링크): $author');
        } else {
          // 링크가 없는 경우 텍스트에서 추출
          final parentText = parentElement.text;
          final match = RegExp(r'작가\s*:?\s*([^\n\r\•]+)').firstMatch(parentText);
          if (match != null && match.groupCount >= 1) {
            author = match.group(1)!.trim();
            print('작가 정보 추출 (텍스트): $author');
          }
        }
      }
      
      // 형제 요소나 이웃 요소에서 찾기
      if (author.isEmpty) {
        Element? siblingElement = authorLabelElement.nextElementSibling;
        if (siblingElement != null) {
          final text = siblingElement.text.trim();
          if (text.isNotEmpty) {
            author = text;
            print('이웃 요소에서 작가 정보 추출: $author');
          }
        }
      }
      
      // 테이블 구조인 경우 다음 셀에서 찾기
      if (author.isEmpty) {
        Element? tableCell = authorLabelElement.parent;
        if (tableCell != null && tableCell.localName == 'td') {
          Element? nextCell = tableCell.nextElementSibling;
          if (nextCell != null) {
            author = nextCell.text.trim();
            print('테이블 다음 셀에서 작가 정보 추출: $author');
          }
        }
      }
    }
  }
  
  // 2.3. 작가 정보가 없는 경우 전체 텍스트에서 검색
  if (author.isEmpty) {
    for (final content in viewContents) {
      final contentText = content.text;
      if (contentText.contains('작가')) {
        final match = RegExp(r'작가\s*:?\s*([^\n\r\•]+)').firstMatch(contentText);
        if (match != null && match.groupCount >= 1) {
          author = match.group(1)!.trim();
          print('전체 텍스트에서 작가 정보 추출: $author');
          break;
        }
      }
    }
  }
  
  // 2.4. 이미지 옆 텍스트에서 작가 정보 추출 시도
  if (author.isEmpty && thumbnailElement != null) {
    Element? parent = thumbnailElement.parent;
    if (parent != null) {
      final siblingText = parent.text;
      if (siblingText.contains('작가')) {
        final match = RegExp(r'작가\s*:?\s*([^\n\r\•]+)').firstMatch(siblingText);
        if (match != null && match.groupCount >= 1) {
          author = match.group(1)!.trim();
          print('이미지 옆 텍스트에서 작가 정보 추출: $author');
        }
      }
    }
  }
  
  // 3. 장르 정보 추출 - 여러 방법 시도
  print('\n장르 정보 추출 시도:');
  
  // 3.1. 새로운 선택자 시도
  final genreSelectors = [
    '.view-content .tags a', 
    '.view-content .tag a',
    '.view-content .category a',
    '.view-content .genre a',
    '.view-content a[href*="/genre/"]',
    '.view-content a[href*="/category/"]',
    '.view-content .view-info:contains(분류) a',
    '.manga-info .genre a',
    '.comic-info .genre a',
  ];
  
  for (final selector in genreSelectors) {
    try {
      final elements = document.querySelectorAll(selector);
      print('- $selector: ${elements.length} 요소 발견');
      
      if (elements.isNotEmpty) {
        final genres = elements.map((e) => e.text.trim()).where((e) => e.isNotEmpty).toList();
        if (genres.isNotEmpty) {
          genre = genres.join(', ');
          print('선택자로 장르 발견: $genre');
          break;
        }
      }
    } catch (e) {
      print('선택자 오류: $selector - $e');
    }
  }
  
  // 3.2. 분류 라벨이 있는 요소 찾기
  if (genre.isEmpty) {
    Element? genreLabelElement;
    for (final content in viewContents) {
      final strongElements = content.querySelectorAll('strong, span.title, span.label, th');
      for (final strong in strongElements) {
        if (strong.text.contains('분류') || strong.text.contains('장르')) {
          genreLabelElement = strong;
          print('분류/장르 라벨 발견: ${strong.outerHtml}');
          break;
        }
      }
      if (genreLabelElement != null) break;
    }
    
    if (genreLabelElement != null) {
      Element? parentElement = genreLabelElement.parent;
      if (parentElement != null) {
        final genreLinks = parentElement.querySelectorAll('a');
        if (genreLinks.isNotEmpty) {
          final genres = genreLinks.map((e) => e.text.trim()).where((e) => e.isNotEmpty).toList();
          genre = genres.join(', ');
          print('분류 요소에서 장르 추출: $genre');
        } else {
          final parentText = parentElement.text;
          final match = RegExp(r'분류|\s*장르\s*:?\s*([^\n\r\•]+)').firstMatch(parentText);
          if (match != null && match.groupCount >= 1) {
            genre = match.group(1)!.trim();
            print('분류 텍스트에서 장르 추출: $genre');
          }
        }
      }
    }
  }
  
  // 4. 발행구분 정보 추출 - 여러 방법 시도
  print('\n발행구분 정보 추출 시도:');
  
  // 4.1. 새로운 선택자 시도
  final statusSelectors = [
    '.view-content .status a',
    '.view-content .state a',
    '.view-content a[href*="/state/"]',
    '.view-content a[href*="/status/"]',
    '.view-content .view-info:contains(발행구분) a',
    '.view-content .view-info:contains(상태) a',
    '.manga-info .status',
    '.comic-info .status',
  ];
  
  for (final selector in statusSelectors) {
    try {
      final elements = document.querySelectorAll(selector);
      print('- $selector: ${elements.length} 요소 발견');
      
      if (elements.isNotEmpty) {
        for (final element in elements) {
          final text = element.text.trim();
          if (text.isNotEmpty) {
            releaseStatus = text;
            print('선택자로 발행구분 발견: $releaseStatus');
            break;
          }
        }
      }
      
      if (releaseStatus.isNotEmpty) break;
    } catch (e) {
      print('선택자 오류: $selector - $e');
    }
  }
  
  // 4.2. 발행구분 라벨이 있는 요소 찾기
  if (releaseStatus.isEmpty) {
    Element? statusLabelElement;
    for (final content in viewContents) {
      final strongElements = content.querySelectorAll('strong, span.title, span.label, th');
      for (final strong in strongElements) {
        if (strong.text.contains('발행구분') || strong.text.contains('상태')) {
          statusLabelElement = strong;
          print('발행구분/상태 라벨 발견: ${strong.outerHtml}');
          break;
        }
      }
      if (statusLabelElement != null) break;
    }
    
    if (statusLabelElement != null) {
      // 부모 요소 찾기
      Element? parentElement = statusLabelElement.parent;
      if (parentElement != null) {
        final statusLinks = parentElement.querySelectorAll('a');
        if (statusLinks.isNotEmpty) {
          releaseStatus = statusLinks.first.text.trim();
          print('발행구분 요소에서 상태 추출: $releaseStatus');
        } else {
          final parentText = parentElement.text;
          final match = RegExp(r'발행구분\s*:?\s*([^\n\r\•]+)').firstMatch(parentText);
          if (match != null && match.groupCount >= 1) {
            releaseStatus = match.group(1)!.trim();
            print('발행구분 텍스트에서 상태 추출: $releaseStatus');
          }
        }
      }
      
      // 형제 요소나 이웃 요소에서 찾기
      if (releaseStatus.isEmpty) {
        Element? siblingElement = statusLabelElement.nextElementSibling;
        if (siblingElement != null) {
          final text = siblingElement.text.trim();
          if (text.isNotEmpty) {
            releaseStatus = text;
            print('이웃 요소에서 발행구분 정보 추출: $releaseStatus');
          }
        }
      }
      
      // 테이블 구조인 경우 다음 셀에서 찾기
      if (releaseStatus.isEmpty) {
        Element? tableCell = statusLabelElement.parent;
        if (tableCell != null && tableCell.localName == 'td') {
          Element? nextCell = tableCell.nextElementSibling;
          if (nextCell != null) {
            releaseStatus = nextCell.text.trim();
            print('테이블 다음 셀에서 발행구분 정보 추출: $releaseStatus');
          }
        }
      }
    }
  }
  
  // 4.3. 상태 관련 키워드 검색
  if (releaseStatus.isEmpty) {
    final statusKeywords = ['진행중', '완결', '연재중', '휴재', '완결작', '연재'];
    for (final keyword in statusKeywords) {
      if (html.contains(keyword)) {
        releaseStatus = keyword;
        print('전체 HTML에서 상태 키워드 발견: $releaseStatus');
        break;
      }
    }
  }
  
  print('\n최종 추출 결과:');
  print('- 작가: ${author.isNotEmpty ? author : "작가 정보 없음"}');
  print('- 장르: ${genre.isNotEmpty ? genre : "장르 정보 없음"}');
  print('- 발행구분: ${releaseStatus.isNotEmpty ? releaseStatus : "상태 정보 없음"}');
  
  // "전편보기" 링크 추출
  String previousChapterId = '';
  try {
    print('\n전편보기 링크 추출 시도:');
    
    // 1. 정확한 선택자로 찾기: .pull-right.post-info 내부의 전편보기 버튼
    final postInfoDivs = document.querySelectorAll('.pull-right.post-info');
    print('- .pull-right.post-info 요소 개수: ${postInfoDivs.length}');
    
    for (final postInfo in postInfoDivs) {
      final links = postInfo.querySelectorAll('a');
      print('  - 링크 개수: ${links.length}');
      
      for (final link in links) {
        final text = link.text.trim();
        final rel = link.attributes['rel'];
        final href = link.attributes['href'];
        final className = link.attributes['class'] ?? '';
        
        print('  - 링크 검색: text="$text", rel=$rel, href=$href, class=$className');
        
        // 전편보기 텍스트가 있는지 확인
        if (text.contains('전편보기')) {
          print('    -> 전편보기 텍스트 발견!');
          
          // rel 속성에서 ID 추출 시도
          if (rel != null && rel.isNotEmpty) {
            previousChapterId = rel;
            print('    -> 전편보기 ID 추출 (속성): $previousChapterId');
            break;
          }
          
          // href URL에서 ID 추출 시도
          if (href != null && href.isNotEmpty) {
            final match = RegExp(r'/comic/([0-9]+)').firstMatch(href);
            if (match != null && match.groupCount >= 1) {
              previousChapterId = match.group(1)!;
              print('    -> 전편보기 ID 추출 (URL): $previousChapterId');
              break;
            }
          }
        }
      }
      
      if (previousChapterId.isNotEmpty) break;
    }
    
    // 2. 버튼 클래스로 찾기
    if (previousChapterId.isEmpty) {
      print('- 버튼 클래스로 찾기 시도');
      final primaryButtons = document.querySelectorAll('a.btn-primary, a.btn-xs.btn-primary');
      print('  - 버튼 요소 개수: ${primaryButtons.length}');
      
      for (final button in primaryButtons) {
        final text = button.text.trim();
        final rel = button.attributes['rel'];
        final href = button.attributes['href'];
        
        print('  - 버튼 검색: text="$text", rel=$rel, href=$href');
        
        if (text.contains('전편보기')) {
          // rel 속성에서 ID 추출 시도
          if (rel != null && rel.isNotEmpty) {
            previousChapterId = rel;
            print('    -> 전편보기 ID 추출 (속성): $previousChapterId');
            break;
          }
          
          // href URL에서 ID 추출 시도
          if (href != null && href.isNotEmpty) {
            final match = RegExp(r'/comic/([0-9]+)').firstMatch(href);
            if (match != null && match.groupCount >= 1) {
              previousChapterId = match.group(1)!;
              print('    -> 전편보기 ID 추출 (URL): $previousChapterId');
              break;
            }
          }
        }
      }
    }
    
    // 3. 모든 링크를 검색하는 방법 (마지막 수단)
    if (previousChapterId.isEmpty) {
      print('- 모든 링크 검색 시도');
      final allLinks = document.querySelectorAll('a');
      
      for (final link in allLinks) {
        final text = link.text.trim();
        final rel = link.attributes['rel'];
        final href = link.attributes['href'];
        
        // 전편보기 텍스트가 있거나 rel 속성이 있는 경우
        if ((text.contains('전편보기') || text.contains('전편') || text.contains('이전')) && 
            href != null && href.isNotEmpty && href.contains('/comic/')) {
          final match = RegExp(r'/comic/([0-9]+)').firstMatch(href);
          if (match != null && match.groupCount >= 1) {
            previousChapterId = match.group(1)!;
            print('  -> 전편보기 ID 추출 (일반 링크): $previousChapterId');
            break;
          }
        }
      }
    }
  } catch (e) {
    print('전편보기 링크 추출 오류: $e');
  }
  
  print('전편보기 ID: ${previousChapterId.isNotEmpty ? previousChapterId : "없음"}');
  
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
      previousChapterId: previousChapterId, // 전편보기 ID 추가
    ),
    hasCaptcha: false,
  );
}

List<MangaChapter> _parseChapters(Document document) {
  final List<MangaChapter> chapters = [];
  
  print('\n회차 목록 파싱 시작...');
  
  // 1. 테이블 기반 레이아웃 확인 (가장 일반적인 형태)
  final tables = document.querySelectorAll('table');
  print('테이블 요소 개수: ${tables.length}');
  
  // 테이블 중에서 회차 목록이 포함된 테이블 찾기
  Element? chapterTable;
  for (final table in tables) {
    final links = table.querySelectorAll('a[href*="/comic/"]');
    if (links.isNotEmpty) {
      chapterTable = table;
      print('회차 링크가 포함된 테이블 발견: ${links.length}개의 링크');
      break;
    }
  }
  
  // 2. 테이블 기반 레이아웃이 있는 경우 처리
  if (chapterTable != null) {
    print('테이블 기반 회차 목록 파싱 시작');
    final rows = chapterTable.querySelectorAll('tr');
    print('행 개수: ${rows.length}');
    
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
          final dateCell = row.querySelector('td:nth-child(4), td.date, td[data-title="등록일"]');
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
        
        print('회차 추출: id=$chapterId, title=$title, date=$uploadDate, views=$views');
        
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
        print('회차 정보 추출 오류: $e');
        continue;
      }
    }
    
    if (chapters.isNotEmpty) {
      // 회차 목록 정렬 (ID 기준 내림차순 - 최신 회차가 먼저 오도록)
      chapters.sort((a, b) => int.parse(b.id).compareTo(int.parse(a.id)));
      print('총 ${chapters.length}개의 회차를 추출했습니다.');
      return chapters;
    }
  }
  
  // 테이블 기반 파싱이 실패한 경우, 링크 기반 파싱 시도
  print('링크 기반 파싱 시도');
  
  // 만화 관련 링크 찾기
  final comicLinks = document.querySelectorAll('a[href*="/comic/"]');
  print('만화 관련 링크 개수: ${comicLinks.length}');
  
  if (comicLinks.isEmpty) {
    print('만화 관련 링크를 찾을 수 없습니다.');
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
    print('적절한 부모 요소를 찾을 수 없습니다.');
    return chapters;
  }
  
  print('가장 많은 링크(${maxCount}개)를 포함한 부모 요소를 찾았습니다.');
  
  // 이 부모 요소 내의 링크만 필터링
  final candidateLinks = comicLinks.where((link) {
    Element? currentParent = link.parent;
    for (int i = 0; i < 3 && currentParent != null; i++) {
      if (currentParent == bestParent) return true;
      currentParent = currentParent.parent;
    }
    return false;
  }).toList();
  
  print('부모 요소에서 ${candidateLinks.length}개의 링크를 찾았습니다.');
  
  // 회차 링크 필터링 (네비게이션 링크 제외)
  final chapterLinks = candidateLinks.where((link) {
    final text = link.text.trim();
    // 특정 키워드가 포함된 항목 필터링 (네비게이션 링크 등)
    if (text.contains('이전화') || text.contains('다음화') || 
        text.contains('전체목록') || text.contains('처음') || 
        text.contains('마지막')) {
      return false;
    }
    return true;
  }).toList();
  
  print('필터링 후 ${chapterLinks.length}개의 회차 링크를 찾았습니다.');
  
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
      
      print('회차 추출: id=$chapterId, title=$title');
      
      chapters.add(MangaChapter(
        id: chapterId,
        title: title,
        uploadDate: '',  // 링크에서는 날짜 정보를 추출하기 어려움
        views: 0,        // 기본값
        likes: 0,
        rating: 0,
        comments: 0,
      ));
    } catch (e) {
      print('회차 정보 추출 오류: $e');
      continue;
    }
  }
  
  // 회차 목록 정렬 (ID 기준 내림차순 - 최신 회차가 먼저 오도록)
  chapters.sort((a, b) => int.parse(b.id).compareTo(int.parse(a.id)));
  
  print('총 ${chapters.length}개의 회차를 추출했습니다.');
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
    } catch (e) {
      print('회차 번호 파싱 오류: ${match.group(1)}');
    }
  }
  
  // 숫자만 추출
  final numericMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
  if (numericMatch != null && numericMatch.groupCount >= 1) {
    try {
      return double.parse(numericMatch.group(1)!);
    } catch (e) {
      print('숫자 파싱 오류: ${numericMatch.group(1)}');
    }
  }
  
  return null;
}

// HTML 구조를 디버깅하기 위한 헬퍼 메서드
void _debugHtmlStructure(Document document) {
  try {
    // 주요 요소 개수 확인
    final divCount = document.querySelectorAll('div').length;
    final aCount = document.querySelectorAll('a').length;
    final liCount = document.querySelectorAll('li').length;
    final tableCount = document.querySelectorAll('table').length;
    final trCount = document.querySelectorAll('tr').length;
    
    print('HTML 구조 디버깅:');
    print('- div 태그 개수: $divCount');
    print('- a 태그 개수: $aCount');
    print('- li 태그 개수: $liCount');
    print('- table 태그 개수: $tableCount');
    print('- tr 태그 개수: $trCount');
    
    // 만화 관련 링크 확인
    final comicLinks = document.querySelectorAll('a[href*="/comic/"]');
    print('- 만화 관련 링크 개수: ${comicLinks.length}');
    
    if (comicLinks.isNotEmpty) {
      final firstLink = comicLinks.first;
      print('- 첫 번째 만화 링크: ${firstLink.attributes['href']}');
      print('- 첫 번째 만화 링크 텍스트: ${firstLink.text.trim()}');
    }
    
    // 주요 클래스 확인
    final classes = <String, int>{};
    document.querySelectorAll('[class]').forEach((element) {
      final classList = element.attributes['class']?.split(' ') ?? [];
      for (final cls in classList) {
        if (cls.isNotEmpty) {
          classes[cls] = (classes[cls] ?? 0) + 1;
        }
      }
    });
    
    final sortedClasses = classes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    print('- 자주 사용되는 클래스 (상위 5개):');
    for (int i = 0; i < 5 && i < sortedClasses.length; i++) {
      print('  * ${sortedClasses[i].key}: ${sortedClasses[i].value}개');
    }
  } catch (e) {
    print('HTML 구조 디버깅 중 오류: $e');
  }
}

// 문서 전체에서 회차 링크를 찾는 메서드
List<MangaChapter> _findChapterLinksInDocument(Document document) {
  final List<MangaChapter> chapters = [];
  
  try {
    // 만화 관련 링크 찾기
    final comicLinks = document.querySelectorAll('a[href*="/comic/"]');
    print('전체 문서에서 찾은 만화 관련 링크 개수: ${comicLinks.length}');
    
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
    
    // 가장 많은 링크를 포함한 부모 요소를 찾습니다
    Element? bestParent;
    int maxCount = 0;
    parentCounts.forEach((parent, count) {
      if (count > maxCount) {
        maxCount = count;
        bestParent = parent;
      }
    });
    
    if (bestParent == null) {
      print('적절한 부모 요소를 찾을 수 없습니다.');
      return chapters;
    }
    
    print('가장 많은 링크(${maxCount}개)를 포함한 부모 요소를 찾았습니다.');
    
    // 이 부모 요소 내의 링크만 필터링
    final candidateLinks = comicLinks.where((link) {
      Element? currentParent = link.parent;
      for (int i = 0; i < 3 && currentParent != null; i++) {
        if (currentParent == bestParent) return true;
        currentParent = currentParent.parent;
      }
      return false;
    }).toList();
    
    print('부모 요소에서 ${candidateLinks.length}개의 링크를 찾았습니다.');
    
    // 회차 링크 필터링 (네비게이션 링크 제외)
    final chapterLinks = candidateLinks.where((link) {
      final text = link.text.trim();
      // 특정 키워드가 포함된 항목 필터링 (네비게이션 링크 등)
      if (text.contains('이전화') || text.contains('다음화') || 
          text.contains('전체목록') || text.contains('처음') || 
          text.contains('마지막')) {
        return false;
      }
      return true;
    }).toList();
    
    print('필터링 후 ${chapterLinks.length}개의 회차 링크를 찾았습니다.');
    
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
        
        print('회차 추출: id=$chapterId, title=$title');
        
        chapters.add(MangaChapter(
          id: chapterId,
          title: title,
          uploadDate: '',  // 링크에서는 날짜 정보를 추출하기 어려움
          views: 0,        // 기본값
          likes: 0,
          rating: 0,
          comments: 0,
        ));
      } catch (e) {
        print('회차 정보 추출 오류: $e');
        continue;
      }
    }
    
    // 회차 목록 정렬 (ID 기준 내림차순 - 최신 회차가 먼저 오도록)
    chapters.sort((a, b) => int.parse(b.id).compareTo(int.parse(a.id)));
    
  } catch (e, stackTrace) {
    print('회차 링크 찾기 오류: $e');
    print('스택 트레이스: $stackTrace');
  }
  
  return chapters;
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
