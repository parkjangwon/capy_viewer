// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manga_search_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$mangaSearchServiceHash() =>
    r'b0805687ee060078670b24f2b0e070e6a2614258';

/// See also [mangaSearchService].
@ProviderFor(mangaSearchService)
final mangaSearchServiceProvider =
    AutoDisposeProvider<MangaSearchService>.internal(
  mangaSearchService,
  name: r'mangaSearchServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$mangaSearchServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MangaSearchServiceRef = AutoDisposeProviderRef<MangaSearchService>;
String _$searchResultsHash() => r'c3ce73f322b887e480aa8ec091da63ef0c4866d8';

/// See also [SearchResults].
@ProviderFor(SearchResults)
final searchResultsProvider = AutoDisposeAsyncNotifierProvider<SearchResults,
    List<Map<String, dynamic>>>.internal(
  SearchResults.new,
  name: r'searchResultsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$searchResultsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SearchResults = AutoDisposeAsyncNotifier<List<Map<String, dynamic>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
