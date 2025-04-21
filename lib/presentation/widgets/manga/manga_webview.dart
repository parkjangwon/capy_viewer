import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/site_url_service.dart';
import '../../../data/models/manga_title.dart';

class MangaWebView extends ConsumerStatefulWidget {
  final void Function(List<MangaTitle>) onTitlesLoaded;
  final String path;
  final Map<String, dynamic>? queryParameters;

  const MangaWebView({
    super.key,
    required this.onTitlesLoaded,
    required this.path,
    this.queryParameters,
  });

  @override
  ConsumerState<MangaWebView> createState() => _MangaWebViewState();
}

class _MangaWebViewState extends ConsumerState<MangaWebView> {
  late final InAppWebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    if (!mounted) return;

    final baseUrl = ref.read(siteUrlServiceProvider);
    var url = '$baseUrl${widget.path}';

    if (widget.queryParameters != null && widget.queryParameters!.isNotEmpty) {
      final query = widget.queryParameters!.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      url = '$url?$query';
    }

    setState(() {
      _isLoading = true;
    });
  }

  Future<void> _extractMangaTitles() async {
    if (!mounted) return;

    try {
      final titles = await _controller.evaluateJavascript(source: '''
        (function() {
          const items = document.querySelectorAll('#webtoon-list-all > li');
          return Array.from(items).map(item => {
            const listItem = item.querySelector('div.list-item');
            if (!listItem) return null;

            const imgItem = listItem.querySelector('div.img-item a');
            const img = imgItem?.querySelector('img');
            const titleElement = listItem.querySelector('div.in-table a');
            const artistElement = listItem.querySelector('div.list-artist a');
            const publishElement = listItem.querySelector('div.list-publish a');

            if (!imgItem || !titleElement) return null;

            const href = imgItem.getAttribute('href') || '';
            const id = href.split('/').pop()?.split('?')[0] || '';
            const title = titleElement.getAttribute('title') || titleElement.textContent.trim();
            const thumbnailUrl = img?.getAttribute('src') || '';
            const artist = artistElement?.textContent.trim() || '';
            const publish = publishElement?.textContent.trim() || '';

            return {
              id,
              title,
              thumbnailUrl,
              type: 'manga',
              author: artist,
              release: publish,
            };
          }).filter(item => item !== null);
        })();
      ''');

      if (!mounted) return;

      if (titles != null) {
        final List<dynamic> parsedTitles = List<dynamic>.from(titles as List);
        final mangaTitles = parsedTitles
            .map((item) => MangaTitle(
                  id: item['id'] as String,
                  title: item['title'] as String,
                  thumbnailUrl: item['thumbnailUrl'] as String,
                  type: item['type'] as String,
                  author: item['author'] as String,
                  release: item['release'] as String,
                ))
            .toList();

        widget.onTitlesLoaded(mangaTitles);
      }
    } catch (e) {
      debugPrint('Error extracting titles: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(_getUrl()),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1'
            },
          ),
          onWebViewCreated: (controller) {
            _controller = controller;
          },
          onLoadStop: (controller, url) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
            });
            _extractMangaTitles();
          },
          onProgressChanged: (controller, progress) {
            if (!mounted) return;
            setState(() {
              _isLoading = progress < 100;
            });
          },
        ),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  String _getUrl() {
    final baseUrl = ref.read(siteUrlServiceProvider);
    var url = '$baseUrl${widget.path}';

    if (widget.queryParameters != null && widget.queryParameters!.isNotEmpty) {
      final query = widget.queryParameters!.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      url = '$url?$query';
    }

    return url;
  }
}
