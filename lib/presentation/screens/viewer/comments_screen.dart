import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import '../../widgets/comment_widget.dart';
import '../../../data/models/comment.dart';

class CommentsScreen extends StatelessWidget {
  final String htmlContent;

  const CommentsScreen({
    super.key,
    required this.htmlContent,
  });

  List<Comment> _parseComments() {
    final document = html_parser.parse(htmlContent);
    final comments = <Comment>[];

    // 실제 댓글이 있는 영역 찾기
    final commentSection = document.querySelector('#bo_vc');
    if (commentSection == null) return comments;

    // BEST 댓글 파싱 (실제 댓글만)
    final bestComments = document.querySelectorAll('.cbest').where((element) {
      final mediaBody = element.querySelector('.media-body');
      final content =
          mediaBody?.querySelector('.media-content div')?.text?.trim() ?? '';
      final nickname = mediaBody?.querySelector('.member')?.text?.trim() ?? '';
      // 내용과 닉네임이 있는 실제 댓글만 포함
      return content.isNotEmpty && nickname.isNotEmpty;
    });

    for (final element in bestComments) {
      comments.add(Comment.fromHtml(element, isBest: true));
    }

    // 일반 댓글 파싱 (실제 댓글만)
    final normalComments =
        commentSection.querySelectorAll('.media:not(.cbest)').where((element) {
      final mediaBody = element.querySelector('.media-body');
      final content =
          mediaBody?.querySelector('.media-content div')?.text?.trim() ?? '';
      final nickname = mediaBody?.querySelector('.member')?.text?.trim() ?? '';
      // 내용과 닉네임이 있는 실제 댓글만 포함
      return content.isNotEmpty && nickname.isNotEmpty;
    });

    for (final element in normalComments) {
      comments.add(Comment.fromHtml(element));
    }

    return comments;
  }

  @override
  Widget build(BuildContext context) {
    final comments = _parseComments();

    return Scaffold(
      appBar: AppBar(
        title: const Text('댓글'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: comments.isEmpty
          ? const Center(
              child: Text('댓글이 없습니다.'),
            )
          : ListView.builder(
              itemCount: comments.length,
              itemBuilder: (context, index) {
                return CommentWidget(comment: comments[index]);
              },
            ),
    );
  }
}
