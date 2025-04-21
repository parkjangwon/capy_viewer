import 'package:webview_flutter/webview_flutter.dart';
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

  Future<void> loadSearch(String query) async {
    final url = 'https://manatoki468.net/bbs/search.php?sfl=wr_subject&stx=${Uri.encodeComponent(query)}&sop=and&where=all&onetable=&page=1';
    await controller.loadRequest(Uri.parse(url));
  }

  Future<String> getHtml() async {
    // 페이지 로드가 끝났는지 체크하는 로직이 필요할 수 있음
    await Future.delayed(const Duration(seconds: 2));
    final html = await controller.runJavaScriptReturningResult('document.documentElement.outerHTML');
    return html.toString();
  }
}
