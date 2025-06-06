class Comment {
  final String id;
  final String profileImageUrl;
  final String nickname;
  final String content;
  final String timestamp;
  final int likes;
  final int depth;
  final bool isBest;
  final bool hasStarRating;
  final int starRating;

  Comment({
    required this.id,
    required this.profileImageUrl,
    required this.nickname,
    required this.content,
    required this.timestamp,
    required this.likes,
    required this.depth,
    this.isBest = false,
    this.hasStarRating = false,
    this.starRating = 0,
  });

  factory Comment.fromHtml(dynamic element, {bool isBest = false}) {
    final mediaBody = element.querySelector('.media-body');
    final mediaHeading = mediaBody?.querySelector('.media-heading');
    final mediaContent = mediaBody?.querySelector('.media-content');

    // 프로필 이미지 URL 추출
    final photoElement = element.querySelector('.photo');
    String profileImageUrl = '';
    if (photoElement != null) {
      final imgElement = photoElement.querySelector('img');
      if (imgElement != null) {
        profileImageUrl = imgElement.attributes['src'] ?? '';
      }
    }

    // 닉네임 추출
    final nicknameElement = mediaHeading?.querySelector('.member');
    String nickname = '';
    if (nicknameElement != null) {
      final nicknameText = nicknameElement.text?.trim() ?? '';
      // 레벨 이미지 텍스트 제거
      nickname = nicknameText.replaceAll(RegExp(r'Lv\.\d+'), '').trim();
    }

    // 댓글 내용 추출
    final contentDiv = mediaContent?.querySelector('div');
    final content = contentDiv?.text?.trim() ?? '';

    // 시간 정보 추출
    final timeElement = mediaHeading?.querySelector('.media-info');
    final timestamp = timeElement?.text?.trim() ?? '';

    // 좋아요 수 추출
    final likesElement = mediaContent?.querySelector('.cmt-good-btn span');
    final likes = int.tryParse(likesElement?.text ?? '0') ?? 0;

    // 댓글 깊이 계산 (margin-left 값으로 판단)
    final marginLeft =
        element.attributes['style']?.contains('margin-left') ?? false;
    final depthMatch = RegExp(r'margin-left:(\d+)px')
        .firstMatch(element.attributes['style'] ?? '');
    final depth =
        depthMatch != null ? (int.parse(depthMatch.group(1)!) ~/ 64) : 0;

    // 별점 정보 추출
    final starElements = mediaHeading?.querySelectorAll('.fa-star');
    final hasStarRating = starElements?.isNotEmpty ?? false;
    final starRating = starElements?.length ?? 0;

    return Comment(
      id: element.attributes['id']?.replaceAll('c_', '') ?? '',
      profileImageUrl: profileImageUrl,
      nickname: nickname,
      content: content,
      timestamp: timestamp,
      likes: likes,
      depth: depth,
      isBest: isBest,
      hasStarRating: hasStarRating,
      starRating: starRating,
    );
  }
}
