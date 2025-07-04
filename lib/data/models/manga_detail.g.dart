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
      genres: (json['genres'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      releaseStatus: json['releaseStatus'] as String? ?? '',
      chapters: (json['chapters'] as List<dynamic>?)
              ?.map((e) => MangaChapter.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <MangaChapter>[],
      previousChapterId: json['previousChapterId'] as String? ?? '',
      isLiked: json['isLiked'] as bool? ?? false,
    );

Map<String, dynamic> _$$MangaDetailImplToJson(_$MangaDetailImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'thumbnailUrl': instance.thumbnailUrl,
      'author': instance.author,
      'genres': instance.genres,
      'releaseStatus': instance.releaseStatus,
      'chapters': instance.chapters,
      'previousChapterId': instance.previousChapterId,
      'isLiked': instance.isLiked,
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
      isLiked: json['isLiked'] as bool? ?? false,
      fullViewUrl: json['fullViewUrl'] as String?,
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
      'isLiked': instance.isLiked,
      'fullViewUrl': instance.fullViewUrl,
    };
