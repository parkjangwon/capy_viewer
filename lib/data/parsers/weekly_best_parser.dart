import 'package:html/parser.dart' as html_parser;
import '../models/weekly_best_model.dart';

class WeeklyBestParser {
  /// 메인 페이지 HTML에서 주간 베스트 목록을 파싱
  static List<WeeklyBestItem> parseWeeklyBest(String htmlContent) {
    try {
      final document = html_parser.parse(htmlContent);
      
      // 여러 가지 가능한 선택자를 시도
      final selectors = [
        '.tab-content .miso-post-list .post-list',
        '.miso-post-list .post-list',
        '.post-list',
        '.rank-list',
        '.post-wrap ul',
        '.widget-side-post-list',
        '.tab-content ul',
      ];
      
      var weeklyBestSection;
      String usedSelector = '';
      
      for (final selector in selectors) {
        weeklyBestSection = document.querySelector(selector);
        if (weeklyBestSection != null) {
          usedSelector = selector;
          print('주간 베스트 섹션 발견: $selector');
          break;
        }
      }
      
      if (weeklyBestSection == null) {
        // 마지막 시도: 모든 ul 요소 중 .post-row 하위 요소가 있는 것 찾기
        final allUlElements = document.querySelectorAll('ul');
        for (final ul in allUlElements) {
          if (ul.querySelectorAll('.post-row').isNotEmpty) {
            weeklyBestSection = ul;
            usedSelector = 'ul with .post-row';
            print('주간 베스트 섹션 발견: ul with .post-row');
            break;
          }
        }
      }
      
      if (weeklyBestSection == null) {
        print('주간 베스트 섹션을 찾을 수 없습니다.');
        return [];
      }
      
      final items = weeklyBestSection.querySelectorAll('.post-row');
      final result = <WeeklyBestItem>[];
      
      for (var i = 0; i < items.length && i < 10; i++) {
        final item = items[i];
        final rank = i + 1;
        
        // a 태그에서 제목과 URL 추출
        final linkElement = item.querySelector('a.ellipsis');
        if (linkElement == null) continue;
        
        // URL 추출
        final url = linkElement.attributes['href'] ?? '';
        
        // 제목 추출 (rank-icon 요소를 제외한 텍스트)
        final rankIcon = linkElement.querySelector('.rank-icon');
        String title = linkElement.text.trim();
        
        // rank-icon과 count 요소의 텍스트를 제거하기 위해 전체 텍스트에서 정제
        final countElement = linkElement.querySelector('.count');
        if (countElement != null) {
          title = title.replaceAll(countElement.text.trim(), '').trim();
        }
        
        if (rankIcon != null) {
          title = title.replaceAll(rankIcon.text.trim(), '').trim();
        }
        
        // 불필요한 공백 제거
        title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
        
        if (title.isNotEmpty && url.isNotEmpty) {
          result.add(WeeklyBestItem(
            title: title,
            url: url,
            thumbnailUrl: '', // 썸네일 없음
            author: '', // 작가 정보 없음
            date: '', // 날짜 정보 없음
            rank: rank,
          ));
        }
      }
      
      return result;
    } catch (e) {
      print('주간 베스트 파싱 오류: $e');
      return [];
    }
  }
}
