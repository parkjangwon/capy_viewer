// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_added_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RecentAddedItemImpl _$$RecentAddedItemImplFromJson(
        Map<String, dynamic> json) =>
    _$RecentAddedItemImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      fullViewUrl: json['fullViewUrl'] as String,
      url: json['url'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      author: json['author'] as String,
      genres:
          (json['genres'] as List<dynamic>).map((e) => e as String).toList(),
      date: json['date'] as String,
      views: (json['views'] as num?)?.toInt(),
      likes: (json['likes'] as num?)?.toInt(),
      comments: (json['comments'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$RecentAddedItemImplToJson(
        _$RecentAddedItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'fullViewUrl': instance.fullViewUrl,
      'url': instance.url,
      'thumbnailUrl': instance.thumbnailUrl,
      'author': instance.author,
      'genres': instance.genres,
      'date': instance.date,
      'views': instance.views,
      'likes': instance.likes,
      'comments': instance.comments,
    };
