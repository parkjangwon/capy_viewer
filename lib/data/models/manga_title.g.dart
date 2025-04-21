// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manga_title.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MangaTitleImpl _$$MangaTitleImplFromJson(Map<String, dynamic> json) =>
    _$MangaTitleImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      author: json['author'] as String? ?? '',
      release: json['release'] as String? ?? '',
      period: json['period'] as String?,
      updateDate: json['updateDate'] as String?,
    );

Map<String, dynamic> _$$MangaTitleImplToJson(_$MangaTitleImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'thumbnailUrl': instance.thumbnailUrl,
      'author': instance.author,
      'release': instance.release,
      'period': instance.period,
      'updateDate': instance.updateDate,
    };
