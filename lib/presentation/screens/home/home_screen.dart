import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/manga_title.dart';
import '../../../data/datasources/api_service.dart';
import '../../viewmodels/manga_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();
  List<MangaTitle>? _recentTitles;
  List<MangaTitle> _weeklyBestTitles = [];
  String? _error;
  bool _isLoading = true;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() async {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;

    if (currentScroll >= (maxScroll * 0.9) && !_isLoading && _hasMore) {
      await _loadMoreWeeklyBest();
    }
  }

  Future<void> _loadData() async {
    try {
      final recentTitles =
          await ref.read(apiServiceProvider()).fetchRecentTitles();
      final weeklyBest = await ref.read(apiServiceProvider()).fetchWeeklyBest();

      if (!mounted) return;

      setState(() {
        _recentTitles = recentTitles;
        _weeklyBestTitles = weeklyBest;
        _isLoading = false;
        _hasMore = weeklyBest.length >= 20;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMoreWeeklyBest() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final moreTitles = await ref.read(apiServiceProvider()).fetchWeeklyBest(
            offset: _weeklyBestTitles.length,
          );

      setState(() {
        _weeklyBestTitles.addAll(moreTitles);
        _isLoading = false;
        _hasMore = moreTitles.length >= 20;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () {
            ref.invalidate(recentTitlesProvider);
            ref.invalidate(weeklyBestProvider);
            return Future(() {});
          },
          child: CustomScrollView(
            slivers: [
              const SliverAppBar(
                floating: true,
                snap: true,
              ),
              _buildRecentTitles(),
              _buildWeeklyBest(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTitles() {
    return Consumer(
      builder: (context, ref, child) {
        final recentTitles = ref.watch(recentTitlesProvider);

        return recentTitles.when(
          data: (titles) {
            if (titles.isEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }

            return SliverList(
              delegate: SliverChildListDelegate([
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '최근 업데이트',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: titles.length,
                    itemBuilder: (context, index) {
                      final title = titles[index];
                      return _TitleCard(title: title);
                    },
                  ),
                ),
              ]),
            );
          },
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
          error: (error, stackTrace) => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('데이터를 불러올 수 없습니다'),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeeklyBest() {
    return Consumer(
      builder: (context, ref, child) {
        final weeklyBest = ref.watch(weeklyBestProvider);

        return weeklyBest.when(
          data: (titles) {
            if (titles.isEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }

            return SliverList(
              delegate: SliverChildListDelegate([
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '주간 인기',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: titles.length,
                    itemBuilder: (context, index) {
                      final title = titles[index];
                      return _TitleCard(title: title);
                    },
                  ),
                ),
              ]),
            );
          },
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
          error: (error, stackTrace) => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('데이터를 불러올 수 없습니다'),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TitleCard extends StatelessWidget {
  final MangaTitle title;

  const _TitleCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => context.push('/viewer/${title.id}'),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Image.network(
                  title.thumbnailUrl,
                  width: 120,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 120,
                      height: 160,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.error_outline),
                    );
                  },
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    title.title,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
