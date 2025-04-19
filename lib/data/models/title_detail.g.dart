// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'title_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TitleDetailImpl _$$TitleDetailImplFromJson(Map<String, dynamic> json) =>
    _$TitleDetailImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      url: json['url'] as String,
      chapters: (json['chapters'] as List<dynamic>?)
              ?.map((e) => Chapter.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      description: json['description'] as String?,
      author: json['author'] as String?,
      status: json['status'] as String?,
    );

Map<String, dynamic> _$$TitleDetailImplToJson(_$TitleDetailImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'thumbnailUrl': instance.thumbnailUrl,
      'url': instance.url,
      'chapters': instance.chapters,
      'description': instance.description,
      'author': instance.author,
      'status': instance.status,
    };

_$ChapterImpl _$$ChapterImplFromJson(Map<String, dynamic> json) =>
    _$ChapterImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      uploadDate: DateTime.parse(json['uploadDate'] as String),
    );

Map<String, dynamic> _$$ChapterImplToJson(_$ChapterImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'url': instance.url,
      'uploadDate': instance.uploadDate.toIso8601String(),
    };
