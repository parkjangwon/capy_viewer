import 'package:html/parser.dart' as html;
import 'package:html/dom.dart';
import '../models/recent_added_model.dart';

class RecentAddedParser {
  /// htmlText: 전체 html 문자열
  /// return: 최신순 RecentAddedItem 리스트
  static List<RecentAddedItem> parseRecentAddedList(String htmlText) {
    final doc = html.parse(htmlText);
    final items = <RecentAddedItem>[];
    final postRows = doc.querySelectorAll('.post-row .media.post-list');
    for (final el in postRows) {
      // id
      final id = el.attributes['rel'] ?? '';
      // 썸네일
      final thumbImg = el.querySelector('.post-image img');
      final thumbnailUrl = thumbImg?.attributes['src'] ?? '';
      // 작품 링크
      final url = el.querySelector('.post-image a')?.attributes['href'] ?? '';
      // 작품 상세
      final fullViewUrl =
          el.querySelector('.post-info p a')?.attributes['href'] ?? '';
      // 제목: <a> 태그의 텍스트 노드만 합쳐서 추출 (span 등 부가정보 제외)
      String title = '';
      final subjectAnchor = el.querySelector('.post-subject a');
      if (subjectAnchor != null) {
        for (final node in subjectAnchor.nodes) {
          if (node.nodeType == Node.TEXT_NODE) {
            title += node.text?.trim() ?? '';
          }
        }
        title = title.trim();
      }
      // 작가 및 장르
      final postTextEl = el.querySelector('.post-text');
      String author = '';
      List<String> genres = [];
      if (postTextEl != null) {
        final tagIcons = postTextEl.querySelectorAll('i.fa-tag');
        final nodes = postTextEl.nodes;
        // 작가명: 첫 번째 태그와 그 다음 텍스트 노드
        if (tagIcons.isNotEmpty) {
          final idx = nodes.indexOf(tagIcons.first);
          if (idx >= 0 && idx + 1 < nodes.length) {
            author = nodes[idx + 1].text?.trim() ?? '';
          }
        }
        // 장르: 두 번째 태그의 다음 텍스트(쉼표로 분리)
        if (tagIcons.length > 1) {
          final idx = nodes.indexOf(tagIcons[1]);
          if (idx >= 0 && idx + 1 < nodes.length) {
            final g = nodes[idx + 1].text?.trim() ?? '';
            genres = g
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        }
      }
      // 날짜
      final date = el.querySelector('.txt-normal')?.text.trim() ?? '';
      // 조회수
      final viewsText = el
              .querySelector('.fa-eye')
              ?.parent
              ?.text
              .replaceAll(RegExp(r'[^0-9,]'), '')
              .replaceAll(',', '') ??
          '';
      final views = int.tryParse(viewsText);
      // 좋아요
      final likesText = el
              .querySelector('.fa-thumbs-o-up')
              ?.parent
              ?.text
              .replaceAll(RegExp(r'[^0-9]'), '') ??
          '';
      final likes = int.tryParse(likesText);
      // 댓글
      final commentsText = el
              .querySelector('.fa-commenting-o')
              ?.parent
              ?.text
              .replaceAll(RegExp(r'[^0-9]'), '') ??
          '';
      final comments = int.tryParse(commentsText);

      items.add(RecentAddedItem(
        id: id,
        title: title,
        url: url,
        fullViewUrl: fullViewUrl,
        thumbnailUrl: thumbnailUrl,
        author: author,
        genres: genres,
        date: date,
        views: views,
        likes: likes,
        comments: comments,
      ));
    }
    return items;
  }
}
