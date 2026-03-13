import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';

class SearchWebViewController {
  late final WebViewController controller;
  bool _isInitialized = false;

  String _normalizeHtmlFromJsResult(Object? rawResult) {
    var html = rawResult?.toString() ?? '';

    if (html.startsWith('"') && html.endsWith('"') && html.length >= 2) {
      html = html.substring(1, html.length - 1);
    }

    return html
        .replaceAll(r'\u003C', '<')
        .replaceAll(r'\u003E', '>')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\"', '"')
        .replaceAll(r"\'", "'")
        .replaceAll(r'\/', '/')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r');
  }

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
      if (publish?.isNotEmpty == true) 'publish': publish!,
      if (jaum?.isNotEmpty == true) 'jaum': jaum!,
      if (tag?.isNotEmpty == true) 'tag': tag!,
      'sst': sort ?? 'wr_datetime',
      'sod': 'desc',
      if (title?.isNotEmpty == true) 'stx': title!,
      'artist': '',
    }).toString();

    await controller.loadRequest(Uri.parse(searchUrl));
  }

  Future<String> getHtml() async {
    // 페이지 로드가 끝났는지 체크하는 로직이 필요할 수 있음
    await Future.delayed(const Duration(seconds: 2));
    final html = await controller
        .runJavaScriptReturningResult('document.documentElement.outerHTML');
    return _normalizeHtmlFromJsResult(html);
  }

  void dispose() {
    controller = WebViewController();
    _isInitialized = false;
  }
}
