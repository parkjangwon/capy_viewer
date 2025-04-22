import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:io';
import 'package:html/parser.dart' as html_parser;
import '../models/manga_title.dart';
import '../models/title_detail.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart' as dio_cookie;
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as inappwebview;
import '../providers/site_url_provider.dart';
import '../../presentation/screens/captcha_screen.dart';
import '../../presentation/viewmodels/navigator_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../presentation/viewmodels/global_cookie_provider.dart';
part 'api_service.g.dart';

// 모든 요청에 사용할 User-Agent (WebView & Dio 공용)
const String kUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36';

@Riverpod(keepAlive: true)
class ApiService extends _$ApiService {
  CookieJar? get cookieJar => _cookieJar;
  late final CookieJar _cookieJar;
  late final Dio _dio;
  final _logger = Logger();
  DateTime? _lastCaptchaSolvedTime;
  static const _captchaCheckInterval = Duration(minutes: 10);
  String? _sessionId;
  late final GlobalKey<NavigatorState> _navigatorKey;
  String? _lastRequestUrl;

  @override
  ApiService build({bool forceRefresh = false}) {
    _navigatorKey = ref.read(navigatorKeyProvider);

    final currentUrl = ref.read(siteUrlServiceProvider);

    _dio = Dio();
    _cookieJar = ref.read(globalCookieJarProvider);
    _dio.interceptors.add(dio_cookie.CookieManager(_cookieJar));

    _dio.options = BaseOptions(
      baseUrl: currentUrl,
      followRedirects: false,
      headers: {
        'User-Agent': kUserAgent,
      },
    );

    return this;
  }

  /// 캡차 우회를 위한 웹뷰 실행
  Future<bool> bypassCaptcha(String url) async {
    try {
      final navigatorState = _navigatorKey.currentState;
      if (navigatorState == null) {
        _logger.e('[CAPTCHA] navigatorState 없음');
        return false;
      }

      // 이미 캡차가 해결된 경우 (10분 내) 바로 성공 반환
      if (!_shouldCheckCaptcha()) {
        _logger.i('[CAPTCHA] 최근에 캡차가 이미 해결됨, 스킵');
        return true;
      }

      _logger.i('[CAPTCHA] 캡차 우회 시작: $url');
      final prefs = await SharedPreferences.getInstance();

      // 캡차 URL이 반복 호출되는 것을 방지하기 위한 호출 횟수 제한
      final captchaAttemptKey = 'captcha_attempt_${Uri.parse(url).host}';
      final captchaAttempts = prefs.getInt(captchaAttemptKey) ?? 0;

      if (captchaAttempts > 5) {  // 시도 횟수 제한을 5회로 증가
        final lastAttemptTime = prefs.getInt('captcha_last_attempt_time') ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        // 마지막 시도 후 30초가 지나지 않았으면 스킵 (1분에서 30초로 감소)
        if (now - lastAttemptTime < 30 * 1000) {
          _logger.w('[CAPTCHA] 과도한 캡차 시도, 일시적으로 스킵 (30초 대기)');
          return false;
        } else {
          // 시간이 지났으면 카운터 리셋
          await prefs.setInt(captchaAttemptKey, 0);
        }
      }

      // 시도 횟수 증가
      await prefs.setInt(captchaAttemptKey, captchaAttempts + 1);
      await prefs.setInt(
          'captcha_last_attempt_time', DateTime.now().millisecondsSinceEpoch);

      bool captchaSolved = false;
      await showDialog(
        context: navigatorState.context,
        barrierDismissible: false,
        builder: (context) => CaptchaScreen(
          url: url,
          onCaptchaVerified: () {
            captchaSolved = true;
            Navigator.of(context).pop();
          },
          preferences: prefs,
        ),
      );

      if (!captchaSolved) {
        _logger.e('[CAPTCHA] 캡차 우회 실패');
        return false;
      }

      _updateCaptchaSolvedTime();

      // 성공 시 캡차 시도 횟수 리셋
      await prefs.setInt(captchaAttemptKey, 0);

      return true;
    } catch (e, stack) {
      _logger.e('[CAPTCHA] 캡차 우회 중 오류', error: e, stackTrace: stack);
      return false;
    }
  }

  void _updateCaptchaSolvedTime() {
    _lastCaptchaSolvedTime = DateTime.now();
  }

  bool _shouldCheckCaptcha() {
    if (_lastCaptchaSolvedTime == null) return true;
    final now = DateTime.now();
    return now.difference(_lastCaptchaSolvedTime!) > _captchaCheckInterval;
  }

  /// 쿠키 동기화
  Future<void> _syncCookies(List<Cookie> cookies) async {
    try {
      final baseUrl = ref.read(siteUrlServiceProvider);
      final uri = Uri.parse(baseUrl);

      final dartCookies = cookies
          .map((c) => io.Cookie(
                c.name,
                c.value,
              )
                ..domain = c.domain
                ..path = c.path ?? '/'
                ..secure = c.isSecure ?? false)
          .toList();

      await _cookieJar.saveFromResponse(uri, dartCookies);
      _logger.i('[COOKIE] 쿠키 동기화 완료: ${dartCookies.length}개');
    } catch (e, stack) {
      _logger.e('[COOKIE] 쿠키 동기화 실패', error: e, stackTrace: stack);
    }
  }

  Future<Response<T>> _request<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    bool bypassCaptchaOnBlocked = false,
  }) async {
    final baseUrl = ref.read(siteUrlServiceProvider);

    try {
      final siteUrl = ref.read(siteUrlServiceProvider);
      var url = joinUrl(siteUrl, path);
      if (queryParameters != null && queryParameters.isNotEmpty) {
        final query = queryParameters.entries
            .map((e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
            .join('&');
        url = '$url?$query';
      }

      // 이미 처리 중인 URL인지 확인 (무한 루프 방지)
      if (_lastRequestUrl == url) {
        _logger.w('[REQUEST] 이미 처리 중인 URL 중복 요청 방지: $url');
        throw DioException(
            requestOptions: RequestOptions(path: url),
            error: '이미 처리 중인 URL입니다',
            type: DioExceptionType.cancel);
      }

      _lastRequestUrl = url;

      final response = await _dio.get<T>(
        url,
        options: options ??
            Options(
              responseType: ResponseType.plain,
              headers: {
                'Referer': baseUrl,
              },
            ),
      );

      // 요청 성공 후 _lastRequestUrl 초기화
      _lastRequestUrl = null;

      // HTML 응답에서 캡차 필요 여부 확인
      if (response.data is String &&
          _isCaptchaRequired(response.data as String)) {
        _logger.w('[REQUEST] HTML 응답에서 캡차 감지됨');
        if (bypassCaptchaOnBlocked) {
          final success = await bypassCaptcha(url);
          if (success) {
            return _request(path,
                queryParameters: queryParameters,
                options: options,
                bypassCaptchaOnBlocked: false);
          }
        }
        throw DioException(
            requestOptions: RequestOptions(path: url),
            error: '캡차 인증이 필요합니다',
            type: DioExceptionType.badResponse);
      }

      return response;
    } on DioException catch (e) {
      // 요청 실패 시에도 _lastRequestUrl 초기화
      _lastRequestUrl = null;

      if (e.response?.statusCode == 403 ||
          _isCaptchaRequired(e.response?.data as String? ?? '')) {
        _logger.w('[REQUEST] 캡차 감지됨');
        if (bypassCaptchaOnBlocked) {
          _logger.w('[REQUEST] 캡차 우회 시도');
          final success = await bypassCaptcha(e.requestOptions.uri.toString());
          if (success) {
            _logger.i('[REQUEST] 캡차 우회 성공, 재시도');
            return _request(path,
                queryParameters: queryParameters,
                options: options,
                bypassCaptchaOnBlocked: false);
          } else {
            _logger.e('[REQUEST] 캡차 우회 실패, 요청 중단');
            throw DioException(
                requestOptions: e.requestOptions,
                response: e.response,
                error: '캡차 우회 실패',
                type: DioExceptionType.badResponse);
          }
        } else {
          _logger.w('[REQUEST] 캡차 우회 시도하지 않음 (자동 요청)');
          throw DioException(
              requestOptions: e.requestOptions,
              response: e.response,
              error: '자동 요청 중 캡차 감지됨',
              type: DioExceptionType.badResponse);
        }
      }

      rethrow;
    }
  }

  bool _isCaptchaRequired(String html) {
    return html.contains('captcha-bypass') ||
        html.contains('_cf_chl_opt') ||
        html.contains('cf-browser-verification') ||
        html.contains('challenge-form');
  }

  /// 앱 내 쿠키 삭제
  Future<void> clearCookies() async {
    try {
      await _cookieJar.deleteAll();
      _lastCaptchaSolvedTime = null;  // 캡차 해결 시간도 초기화
      _logger.i('[SETTINGS] 모든 쿠키 삭제 완료');
    } catch (e, stack) {
      _logger.e('[SETTINGS] 쿠키 삭제 중 오류', error: e, stackTrace: stack);
    }
  }

  /// 웹뷰 캐시/쿠키 삭제 (SharedPreferences는 삭제하지 않음)
  Future<void> clearCache() async {
    try {
      await inappwebview.CookieManager.instance().deleteAllCookies();
      await InAppWebViewController.clearAllCache();
      _logger.i('[SETTINGS] 웹뷰 쿠키/캐시 전체 삭제 완료');
    } catch (e, stack) {
      _logger.e('[SETTINGS] 웹뷰 캐시 삭제 중 오류', error: e, stackTrace: stack);
    }
  }

  /// 쿠키 저장소 초기화 (앱 시작 시 한 번만 호출)
  Future<void> initializeCookieStorage() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cookieDir = '${dir.path}/.cookies';

      // 디렉토리가 없으면 생성
      final directory = Directory(cookieDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      _cookieJar = PersistCookieJar(
        storage: FileStorage(cookieDir),
      );
      debugPrint('Cookie storage initialized at $cookieDir');

      // 쿠키 저장소가 변경되었으므로 interceptor도 업데이트
      _dio.interceptors.clear();
      _dio.interceptors.add(dio_cookie.CookieManager(_cookieJar));
    } catch (e, stack) {
      _logger.e('[COOKIE] Failed to initialize cookie storage',
          error: e, stackTrace: stack);
      // 실패한 경우 메모리 기반 쿠키 저장소로 대체
      _cookieJar = CookieJar();
      _dio.interceptors.clear();
      _dio.interceptors.add(dio_cookie.CookieManager(_cookieJar));
    }
  }

  String joinUrl(String base, String path) {
    if (base.endsWith('/') && path.startsWith('/')) {
      return base + path.substring(1);
    } else if (!base.endsWith('/') && !path.startsWith('/')) {
      return '$base/$path';
    } else {
      return base + path;
    }
  }

  Future<List<MangaTitle>> fetchRecentTitles({int offset = 0}) async {
    try {
      final response = await _request<String>(
        '/comic',
        queryParameters: {
          'page': (offset ~/ 20 + 1).toString(),
        },
        bypassCaptchaOnBlocked: false, // 홈화면 자동 요청에서는 캡차 우회 시도 금지
      );

      if (response.data == null || response.data!.isEmpty) {
        _logger.w('Empty response data');
        return [];
      }

      try {
        _logger.d('Parsing HTML response for recent titles...');
        final document = html_parser.parse(response.data!);
        final items = document.querySelectorAll('.img-item');

        _logger.d('Found ${items.length} recent items');
        if (items.isEmpty) {
          _logger.w('No recent titles found');
          return [];
        }

        final results = items.map((item) {
          final anchor = item.querySelector('a');
          final img = item.querySelector('img');
          final titleSpan = item.querySelector('.title');

          final href = anchor?.attributes['href'] ?? '';
          final id = href.split('/').last.split('?').first;
          final title = titleSpan?.text ?? '';
          final thumbnailUrl = img?.attributes['src'] ?? '';

          _logger.d('Parsed recent item: id=$id, title=$title');

          return MangaTitle(
            id: id,
            title: title,
            thumbnailUrl: thumbnailUrl,
            
          );
        }).toList();

        _logger.i('Successfully parsed ${results.length} recent titles');
        return results;
      } catch (e, stack) {
        _logger.e('Error parsing HTML response', error: e, stackTrace: stack);
        return [];
      }
    } catch (e, stack) {
      _logger.e('Error fetching recent titles', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<List<MangaTitle>> fetchWeeklyBest({int offset = 0}) async {
    try {
      final response = await _request<String>(
        '/comic/weekly',
        queryParameters: {
          'page': (offset ~/ 20 + 1).toString(),
        },
        bypassCaptchaOnBlocked: false, // 홈화면 자동 요청에서는 캡차 우회 시도 금지
      );

      if (response.data == null || response.data!.isEmpty) {
        _logger.w('Empty response data');
        return [];
      }

      try {
        _logger.d('Parsing HTML response for weekly best...');
        final document = html_parser.parse(response.data!);
        final items = document.querySelectorAll('.img-item');

        _logger.d('Found ${items.length} weekly best items');
        if (items.isEmpty) {
          _logger.w('No weekly best titles found');
          return [];
        }

        final results = items.map((item) {
          final anchor = item.querySelector('a');
          final img = item.querySelector('img');
          final titleSpan = item.querySelector('.title');

          final href = anchor?.attributes['href'] ?? '';
          final id = href.split('/').last.split('?').first;
          final title = titleSpan?.text ?? '';
          final thumbnailUrl = img?.attributes['src'] ?? '';

          _logger.d('Parsed weekly best item: id=$id, title=$title');

          return MangaTitle(
            id: id,
            title: title,
            thumbnailUrl: thumbnailUrl,
            
          );
        }).toList();

        _logger.i('Successfully parsed ${results.length} weekly best titles');
        return results;
      } catch (e, stack) {
        _logger.e('Error parsing HTML response', error: e, stackTrace: stack);
        return [];
      }
    } catch (e, stack) {
      _logger.e('Error fetching weekly best', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<TitleDetail> fetchTitleDetail(String id) async {
    try {
      final response = await _request<String>('/title/$id');

      if (response.data == null || response.data!.isEmpty) {
        throw Exception('No data received');
      }

      final Map<String, dynamic> json = jsonDecode(response.data!);
      return TitleDetail.fromJson(json);
    } catch (e) {
      _logger.e('Error fetching title detail', error: e);
      rethrow;
    }
  }

  Future<List<String>> fetchChapter(String id) async {
    try {
      final response = await _request<String>('/chapter/$id');

      if (response.data == null || response.data!.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(response.data!);
      return jsonList.cast<String>();
    } catch (e) {
      _logger.e('Error fetching chapter', error: e);
      rethrow;
    }
  }

  Future<List<MangaTitle>> search(String query, {int offset = 0}) async {
    _logger.i('[SEARCH] 검색 시작: query="$query", offset=$offset');
    final page = (offset ~/ 10) + 1;
    final baseUrl = ref.read(siteUrlServiceProvider);
    final searchUrl =
        '$baseUrl/bbs/search.php?sfl=wr_subject&stx=${Uri.encodeComponent(query)}&sop=and&where=all&onetable=&page=$page';

    _logger.i('[SEARCH] 요청 URL: $searchUrl');
    
    try {
      Response response;
      bool captchaBypassAttempted = false;

      while (true) {
        try {
          response = await _dio.get(
            searchUrl,
            options: Options(
              followRedirects: false,
              validateStatus: (status) => true,
              headers: {
                'User-Agent': kUserAgent,
                'Referer': baseUrl,
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
                'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
              },
            ),
          );

          _logger.i('[SEARCH] 응답 상태 코드: ${response.statusCode}');

          // 캡차가 필요한 경우
          if (_needsCaptcha(response) || response.statusCode == 403) {
            if (captchaBypassAttempted) {
              _logger.e('[SEARCH] 캡차 우회 재시도 실패');
              return [];
            }

            _logger.i('[SEARCH] 캡차 감지됨, 우회 시도');
            final success = await bypassCaptcha(searchUrl);
            if (!success) {
              _logger.e('[SEARCH] 캡차 우회 실패');
              return [];
            }

            captchaBypassAttempted = true;
            continue;  // 캡차 우회 후 검색 재시도
          }

          // 정상 응답인 경우
          if (response.statusCode == 200) {
            final responseData = response.data as String;
            if (responseData.contains('검색결과가 없습니다')) {
              _logger.i('[SEARCH] 검색 결과 없음');
              return [];
            }
            return _parseMangaTitles(responseData);
          }

          _logger.e('[SEARCH] 예상치 못한 응답: ${response.statusCode}');
          return [];

        } on DioException catch (e) {
          if (e.response?.statusCode == 403 && !captchaBypassAttempted) {
            _logger.w('[SEARCH] DioException: 캡차 감지됨, 우회 시도');
            final success = await bypassCaptcha(searchUrl);
            if (!success) {
              _logger.e('[SEARCH] 캡차 우회 실패');
              return [];
            }
            captchaBypassAttempted = true;
            continue;  // 캡차 우회 후 검색 재시도
          }
          rethrow;
        }
      }
    } catch (e, stack) {
      _logger.e('[SEARCH] 검색 실패', error: e, stackTrace: stack);
      return [];
    }
  }

  bool _needsCaptcha(Response response) {
    if (response.statusCode == 302 || response.statusCode == 403) return true;
    if (response.data == null || !(response.data is String)) return false;

    final html = response.data as String;
    return html.contains('captcha-bypass') ||
        html.contains('_cf_chl_opt') ||
        html.contains('challenge-form') ||
        html.contains('cf-spinner') ||
        html.contains('cloudflare-challenge') ||
        html.contains('turnstile_') ||
        html.contains('cf-browser-verification') ||
        html.contains('cf_captcha_kind');
  }

  List<MangaTitle> _parseMangaTitles(String html) {
    final document = html_parser.parse(html);
    final titles = <MangaTitle>[];

    final table = document.querySelector('#fboardlist');
    if (table == null) {
      _logger.w(
          '[PARSE] #fboardlist 테이블 없음. HTML 일부: ${html.substring(0, html.length > 2000 ? 2000 : html.length)}');
      return titles;
    }

    final rows = table.querySelectorAll('tr[class^="board_list"]');
    for (final row in rows) {
      try {
        final titleElement = row.querySelector('td.subject a');
        final authorElement = row.querySelector('td:nth-child(3)');
        final dateElement = row.querySelector('td:nth-child(4)');
        final thumbnailElement = row.querySelector('img');

        if (titleElement != null) {
          final title = titleElement.text.trim();
          final href = titleElement.attributes['href'] ?? '';
          final author = authorElement?.text.trim() ?? '';
          final date = dateElement?.text.trim() ?? '';
          final thumbnail = thumbnailElement?.attributes['src'] ?? '';

          final siteUrl = ref.read(siteUrlServiceProvider);
          titles.add(MangaTitle(
            title: title,
            id: _extractIdFromUrl(href),
            thumbnailUrl: thumbnail.startsWith('http')
                ? thumbnail
                : '$siteUrl/$thumbnail',
            author: author,
            release: date,
          ));
        }
      } catch (e, stack) {
        _logger.e('[PARSE] 만화 타이틀 파싱 실패', error: e, stackTrace: stack);
        _logger.w(
            '[PARSE] 파싱 실패한 row HTML: ${row.outerHtml.substring(0, row.outerHtml.length > 500 ? 500 : row.outerHtml.length)}');
      }
    }

    if (titles.isEmpty) {
      _logger.w(
          '[PARSE] 최종적으로 파싱된 타이틀 없음. 전체 HTML 일부: ${html.substring(0, html.length > 2000 ? 2000 : html.length)}');
    }
    return titles;
  }

  String _extractIdFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';

    final pathSegments = uri.pathSegments;
    if (pathSegments.isEmpty) return '';

    return pathSegments.last;
  }

  Future<void> _handleCaptcha(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await showDialog(
      context: _navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (context) => CaptchaScreen(
        url: url,
        onCaptchaVerified: () {
          Navigator.of(context).pop();
          _retryLastRequest();
        },
        preferences: prefs,
      ),
    );
  }

  Future<void> _retryLastRequest() async {
    if (_lastRequestUrl != null) {
      final response = await _dio.get(_lastRequestUrl!);
      _handleResponse(response);
    }
  }

  Future<void> _handleResponse(Response response) async {
    if (response.statusCode == 200) {
      final html = response.data as String;
      if (html.contains('captcha-bypass') ||
          html.contains('_cf_chl_opt') ||
          html.contains('challenge-form')) {
        _lastRequestUrl = response.requestOptions.uri.toString();
        await _handleCaptcha(response.requestOptions.uri.toString());
      }
    }
  }

  /// 마나토끼 최근 추가된 작품 페이지 HTML (page: 1~10)
  Future<String> fetchRecentAddedPage(int page) async {
    final url = '/bbs/page.php?hid=update&page=$page';
    final response = await _dio.get(url);
    return response.data as String;
  }
}
