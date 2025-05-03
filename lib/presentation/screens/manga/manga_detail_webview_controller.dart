import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/global_cookie_provider.dart';
import '../../../data/providers/site_url_provider.dart';

class MangaDetailWebViewController {
  late final WebViewController controller;
  bool _isInitialized = false;
  final NavigationDelegate _navigationDelegate;
  final Completer<bool> _pageLoadedCompleter = Completer<bool>();
  bool _isPageLoaded = false;
  
  MangaDetailWebViewController({
    required NavigationDelegate navigationDelegate,
  }) : _navigationDelegate = navigationDelegate;

  Future<void> initialize() async {
    if (_isInitialized) return;
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(_navigationDelegate);
    _isInitialized = true;
  }

  Future<void> loadMangaDetail(String baseUrl, String mangaId) async {
    final url = '$baseUrl/comic/$mangaId';
    _isPageLoaded = false;
    _pageLoadedCompleter.complete(false);
    await controller.loadRequest(Uri.parse(url));
  }

  void notifyPageLoaded() {
    if (!_isPageLoaded) {
      _isPageLoaded = true;
      if (!_pageLoadedCompleter.isCompleted) {
        _pageLoadedCompleter.complete(true);
      }
    }
  }

  Future<String> getHtml() async {
    // 페이지 로드가 완료될 때까지 대기
    if (!_isPageLoaded) {
      await _pageLoadedCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (!_pageLoadedCompleter.isCompleted) {
            _pageLoadedCompleter.complete(true);
          }
          return true;
        },
      );
    }
    
    // 페이지 로드 후 약간의 지연 추가 (JavaScript 실행 시간 고려)
    await Future.delayed(const Duration(milliseconds: 500));
    
    final html = await controller.runJavaScriptReturningResult('document.documentElement.outerHTML');
    return html.toString();
  }
}

// 웹뷰 컨트롤러 Provider
final mangaDetailWebViewControllerProvider = Provider.autoDispose<MangaDetailWebViewController>((ref) {
  // 상태 관리를 위한 상태 객체
  final pageLoadedStateProvider = StateProvider<bool>((ref) => false);
  
  final navigationDelegate = NavigationDelegate(
    onPageStarted: (url) {
      // 페이지 로드 시작 시 상태 초기화
      ref.read(pageLoadedStateProvider.notifier).state = false;
    },
    onPageFinished: (url) {
      // 페이지 로드 완료 시 상태 변경
      ref.read(pageLoadedStateProvider.notifier).state = true;
    },
    onNavigationRequest: (request) {
      // 모든 네비게이션 허용
      return NavigationDecision.navigate;
    },
  );
  
  // 컨트롤러 생성
  final controller = MangaDetailWebViewController(navigationDelegate: navigationDelegate);
  
  // 상태 변경 감지
  ref.listen(pageLoadedStateProvider, (previous, current) {
    if (current) {
      controller.notifyPageLoaded();
    }
  });
  
  return controller;
});
