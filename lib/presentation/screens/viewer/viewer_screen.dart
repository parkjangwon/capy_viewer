import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import '../../../data/models/manga.dart';
import '../../../data/datasources/api_service.dart';

class ViewerScreen extends ConsumerStatefulWidget {
  final String titleId;
  final String chapterId;

  const ViewerScreen({
    required this.titleId,
    required this.chapterId,
    super.key,
  });

  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  final _pageController = PageController();
  bool _isAppBarVisible = true;
  Manga? _manga;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChapter();
  }

  Future<void> _loadChapter() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final manga = await api.fetchChapter(widget.titleId, widget.chapterId);
      setState(() {
        _manga = manga;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleAppBar() {
    setState(() {
      _isAppBarVisible = !_isAppBarVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('오류가 발생했습니다'),
              ElevatedButton(
                onPressed: _loadChapter,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final manga = _manga!;

    return Scaffold(
      appBar: _isAppBarVisible
          ? AppBar(
              title: Text(manga.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  onPressed: _toggleAppBar,
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: _toggleAppBar,
        child: PageView.builder(
          controller: _pageController,
          itemCount: manga.images.length,
          itemBuilder: (context, index) {
            return PhotoView(
              imageProvider: NetworkImage(manga.images[index]),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
              backgroundDecoration: const BoxDecoration(
                color: Colors.black,
              ),
            );
          },
        ),
      ),
    );
  }
}
