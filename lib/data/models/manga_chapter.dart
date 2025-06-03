/// 만화 회차 정보 모델
class MangaChapter {
  final String id;
  final String title;
  final String url;
  final String uploadDate;
  final int views;
  final bool isCurrent;

  MangaChapter({
    required this.id,
    required this.title,
    required this.url,
    this.uploadDate = '',
    this.views = 0,
    this.isCurrent = false,
  });

  factory MangaChapter.fromJson(Map<String, dynamic> json) {
    return MangaChapter(
      id: json['id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      uploadDate: json['uploadDate'] as String? ?? '',
      views: json['views'] as int? ?? 0,
      isCurrent: json['isCurrent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'uploadDate': uploadDate,
      'views': views,
      'isCurrent': isCurrent,
    };
  }
}
