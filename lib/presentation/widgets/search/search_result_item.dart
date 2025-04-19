import 'package:flutter/material.dart';

class SearchResultItem extends StatelessWidget {
  final String title;
  final String? thumbnailUrl;
  final VoidCallback onTap;

  const SearchResultItem({
    Key? key,
    required this.title,
    this.thumbnailUrl,
    required this.onTap,
  }) : super(key: key);

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