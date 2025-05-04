/// 만화 회차 정보 모델
class MangaChapter {
  final String title;
  final String url;
  final String uploadDate;
  final String views;
  final String rating;
  final String comments;

  const MangaChapter({
    required this.title,
    required this.url,
    required this.uploadDate,
    required this.views,
    required this.rating,
    required this.comments,
  });
}
