class WeeklyBestItem {
  final String title;
  final String url;
  final String thumbnailUrl;
  final String author;
  final String date;
  final int rank;

  WeeklyBestItem({
    required this.title,
    required this.url,
    required this.thumbnailUrl,
    this.author = '',
    this.date = '',
    this.rank = 0,
  });

  factory WeeklyBestItem.fromJson(Map<String, dynamic> json) {
    return WeeklyBestItem(
      title: json['title'] as String,
      url: json['url'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      author: json['author'] as String? ?? '',
      date: json['date'] as String? ?? '',
      rank: json['rank'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'author': author,
      'date': date,
      'rank': rank,
    };
  }
}
