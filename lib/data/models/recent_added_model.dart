import 'package:freezed_annotation/freezed_annotation.dart';

part 'recent_added_model.freezed.dart';
part 'recent_added_model.g.dart';

@freezed
class RecentAddedItem with _$RecentAddedItem {
  const factory RecentAddedItem({
    required String id,
    required String title,
    required String fullViewUrl,
    required String url,
    required String thumbnailUrl,
    required String author,
    required List<String> genres,
    required String date,
    int? views,
    int? likes,
    int? comments,
  }) = _RecentAddedItem;

  factory RecentAddedItem.fromJson(Map<String, dynamic> json) =>
      _$RecentAddedItemFromJson(json);
}
