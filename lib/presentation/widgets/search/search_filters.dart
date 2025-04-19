import 'package:flutter/material.dart';

class SearchFilters extends StatelessWidget {
  final String selectedFilter;
  final Function(String) onFilterChanged;

  const SearchFilters({
    Key? key,
    required this.selectedFilter,
    required this.onFilterChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FilterChip(
          label: const Text('전체'),
          selected: selectedFilter == 'all',
          onSelected: (selected) => onFilterChanged('all'),
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('제목'),
          selected: selectedFilter == 'title',
          onSelected: (selected) => onFilterChanged('title'),
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('작가'),
          selected: selectedFilter == 'author',
          onSelected: (selected) => onFilterChanged('author'),
        ),
      ],
    );
  }
} 