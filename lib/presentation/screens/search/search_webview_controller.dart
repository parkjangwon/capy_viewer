import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../data/models/manga_title.dart';
import '../../../utils/html_manga_parser.dart';
import 'dart:async';

class SearchWebViewController {
  late final WebViewController controller;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    _isInitialized = true;
  }

  Future<void> loadSearch(
    String baseUrl, {
    String? title,
    String? publish,
    String? jaum,
    String? tag,
    String? sort,
  }) async {
    final searchUrl = Uri.parse('$baseUrl/comic').replace(queryParameters: {
      'publish': publish ?? '',
      'jaum': jaum ?? '',
      'tag': tag ?? '',
      'sst': sort ?? 'wr_datetime',
      'sod': 'desc',
      'stx': title ?? '',
      'artist': '',
    }).toString();

    print('[DEBUG] Search URL: $searchUrl');
    await controller.loadRequest(Uri.parse(searchUrl));
  }

  Future<String> getHtml() async {
    // 페이지 로드가 끝났는지 체크하는 로직이 필요할 수 있음
    await Future.delayed(const Duration(seconds: 2));
    final html = await controller
        .runJavaScriptReturningResult('document.documentElement.outerHTML');
    return html.toString();
  }

  void dispose() {
    controller = WebViewController();
    _isInitialized = false;
  }
}
