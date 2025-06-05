import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import '../../data/models/manga_page.dart';
import '../../data/providers/site_url_provider.dart';
import '../../utils/cloudflare_captcha.dart';
import '../../data/models/manga_viewer_state.dart';
import '../../presentation/viewmodels/global_cookie_provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:dio/dio.dart';

final cloudflareHelperProvider = Provider<CloudflareCaptcha>((ref) {
  return CloudflareCaptcha();
});

final mangaViewerProvider =
    StateNotifierProvider.family<MangaViewerNotifier, MangaViewerState, String>(
        (ref, mangaUrl) {
  return MangaViewerNotifier(ref, mangaUrl);
});

// 전역 WebView 인스턴스 Provider (숨겨진 WebView)
final globalInAppWebViewControllerProvider =
    StateProvider<InAppWebViewController?>((ref) => null);
final globalInAppWebViewWidgetProvider = Provider<Widget>((ref) {
  return Offstage(
    offstage: true,
    child: InAppWebView(
      initialUrlRequest: null, // 최초에는 로드하지 않음
      initialOptions: InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(
          javaScriptEnabled: true,
          useShouldOverrideUrlLoading: true,
          userAgent:
              'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
        ),
      ),
      onWebViewCreated: (controller) {
        ref.read(globalInAppWebViewControllerProvider.notifier).state =
            controller;
      },
    ),
  );
});

// 만화 뷰어에서만 사용하는 Dio 요청 유틸 (쿠키 강제 적용)
Future<Response> mangaViewerDioGetWithCookies(Ref ref, String url) async {
  final dio = Dio();
  final cookieJar = ref.read(globalCookieJarProvider);
  final cookies = await cookieJar.loadForRequest(Uri.parse(url));
  final cookieHeader = cookies.isNotEmpty
      ? cookies.map((c) => '${c.name}=${c.value}').join('; ')
      : '';
  return dio.get(
    url,
    options: Options(
      headers: {
        'Cookie': cookieHeader,
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
        'Referer': url,
        'Origin': Uri.parse(url).origin,
      },
    ),
  );
}

class MangaViewerNotifier extends StateNotifier<MangaViewerState> {
  final Ref ref;
  final String mangaUrl;

  MangaViewerNotifier(this.ref, this.mangaUrl)
      : super(MangaViewerState(
          isLoading: true,
          hasError: false,
          errorMessage: '',
          pages: [],
          currentPageIndex: 0,
          viewMode: ViewMode.basic,
          readingDirection: ReadingDirection.rtl,
          captchaType: CaptchaType.none,
          chapterTitle: '',
          seriesTitle: '',
          prevChapterUrl: '',
          nextChapterUrl: '',
        )) {
    _loadMangaPages();
  }

  void setPages(List<MangaPage> pages) {
    state = state.copyWith(
      isLoading: false,
      hasError: false,
      pages: pages
          .asMap()
          .entries
          .map((e) => e.value.copyWith(index: e.key))
          .toList(),
      captchaType: CaptchaType.none,
    );
  }

  Future<void> _loadMangaPages() async {
    state = state.copyWith(isLoading: true, hasError: false, errorMessage: '');

    try {
      final baseUrl = ref.read(siteUrlServiceProvider);
      final url =
          mangaUrl.startsWith('http') ? mangaUrl : '$baseUrl/comic/$mangaUrl';

      // HTML 가져오기
      final response = await mangaViewerDioGetWithCookies(ref, url);
      final html = response.data.toString();

      // 캡차 체크
      if (html.contains('잠시만 기다리십시오') ||
          html.contains('challenge-form') ||
          html.contains('cf-turnstile-response') ||
          html.contains('캡챠 인증')) {
        state = state.copyWith(
          isLoading: false,
          hasError: false,
          captchaType: CaptchaType.cloudflare,
        );
        return;
      }

      // HTML 파싱
      final document = html_parser.parse(html);

      // 이미지 추출
      final contentElement = document.querySelector('#toon_img');
      if (contentElement == null) {
        throw Exception('컨텐츠를 찾을 수 없습니다.');
      }

      final images = contentElement.querySelectorAll('img');
      if (images.isEmpty) {
        throw Exception('이미지를 찾을 수 없습니다.');
      }

      final pages = images.map((img) {
        final src = img.attributes['src'] ?? '';
        final dataSrc = img.attributes['data-src'] ?? '';
        final imageUrl = dataSrc.isNotEmpty ? dataSrc : src;

        return MangaPage(
          index: 0, // 인덱스는 나중에 설정됨
          imageUrl:
              imageUrl.startsWith('http') ? imageUrl : '$baseUrl$imageUrl',
          isLoaded: false,
          isError: false,
        );
      }).toList();

      // 이전/다음 화 링크 추출
      final prevLink = document.querySelector('a.btn_prev')?.attributes['href'];
      final nextLink = document.querySelector('a.btn_next')?.attributes['href'];
      final title = document.querySelector('.toon-title')?.text ?? '';

      state = state.copyWith(
        isLoading: false,
        hasError: false,
        pages: pages
            .asMap()
            .entries
            .map((e) => e.value.copyWith(index: e.key))
            .toList(),
        chapterTitle: title,
        prevChapterUrl: prevLink ?? '',
        nextChapterUrl: nextLink ?? '',
        captchaType: CaptchaType.none,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: '오류가 발생했습니다: $e',
      );
    }
  }

  void reload() => _loadMangaPages();
}
