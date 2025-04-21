import 'package:flutter/material.dart';

class SearchResultItem extends StatelessWidget {
  final String title;
  final String? thumbnailUrl;
  final VoidCallback onTap;

  const SearchResultItem({
    super.key,
    required this.title,
    this.thumbnailUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: thumbnailUrl != null
          ? Image.network(
              thumbnailUrl!,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            )
          : const Icon(Icons.image),
      title: Text(title),
      onTap: onTap,
    );
  }
} 