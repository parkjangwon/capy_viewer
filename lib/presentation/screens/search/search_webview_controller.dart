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

  Future<void> loadSearch(String baseUrl, {String? title, String? artist, String? publish, String? jaum, String? tag, String? sort}) async {
    final params = <String, String>{};
    if ((title ?? '').isNotEmpty) {
      params['stx'] = title!;
      params['sfl'] = 'wr_subject';
    }
    if ((artist ?? '').isNotEmpty) {
      params['artist'] = artist!;
    }
    if ((publish ?? '').isNotEmpty && publish != '전체') {
      params['publish'] = publish!;
    }
    if ((jaum ?? '').isNotEmpty && jaum != '전체') {
      params['jaum'] = jaum!;
    }
    if ((tag ?? '').isNotEmpty && tag != '전체') {
      params['tag'] = tag!;
    }
    if ((sort ?? '').isNotEmpty && sort != 'wr_datetime') {
      params['sst'] = sort!;
      params['sod'] = 'desc';
    } else if ((sort ?? '').isNotEmpty && sort == 'wr_datetime') {
      params['sst'] = 'wr_datetime';
      params['sod'] = 'desc';
    }
    // 기본값 보장
    params['sop'] = 'and';
    params['where'] = 'all';
    params['onetable'] = '';
    params['page'] = '1';
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final url = '$baseUrl/comic?$query';
    await controller.loadRequest(Uri.parse(url));
  }

  Future<String> getHtml() async {
    // 페이지 로드가 끝났는지 체크하는 로직이 필요할 수 있음
    await Future.delayed(const Duration(seconds: 2));
    final html = await controller.runJavaScriptReturningResult('document.documentElement.outerHTML');
    return html.toString();
  }
}
