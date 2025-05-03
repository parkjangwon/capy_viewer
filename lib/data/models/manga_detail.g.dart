// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manga_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MangaDetailImpl _$$MangaDetailImplFromJson(Map<String, dynamic> json) =>
    _$MangaDetailImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      author: json['author'] as String? ?? '',
      genre: json['genre'] as String? ?? '',
      releaseStatus: json['releaseStatus'] as String? ?? '',
      chapters: (json['chapters'] as List<dynamic>?)
              ?.map((e) => MangaChapter.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <MangaChapter>[],
    );

Map<String, dynamic> _$$MangaDetailImplToJson(_$MangaDetailImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'thumbnailUrl': instance.thumbnailUrl,
      'author': instance.author,
      'genre': instance.genre,
      'releaseStatus': instance.releaseStatus,
      'chapters': instance.chapters,
    };

_$MangaChapterImpl _$$MangaChapterImplFromJson(Map<String, dynamic> json) =>
    _$MangaChapterImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      uploadDate: json['uploadDate'] as String? ?? '',
      views: (json['views'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      comments: (json['comments'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$MangaChapterImplToJson(_$MangaChapterImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'uploadDate': instance.uploadDate,
      'views': instance.views,
      'rating': instance.rating,
      'likes': instance.likes,
      'comments': instance.comments,
    };
