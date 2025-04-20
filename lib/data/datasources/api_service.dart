import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:convert';
import 'dart:io' as io;
import '../../core/typedefs.dart';
import 'dart:math';
import 'package:html/parser.dart' as html_parser;
import '../models/manga_title.dart';
import '../models/title_detail.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../presentation/widgets/captcha/cloudflare_captcha.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart' as dio_cookie;
import 'package:dio/io.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as inappwebview;
import 'site_url_service.dart';
import '../../presentation/screens/captcha_screen.dart';
import '../../presentation/viewmodels/navigator_provider.dart';

part 'api_service.g.dart';

@Riverpod(keepAlive: true)
class ApiService extends _$ApiService {
  /// 앱 내 쿠키 삭제
  Future<void> clearCookies() async {
    try {
      await _cookieJar.deleteAll();
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
  final _logger = Logger();
  late final Dio _dio;
  late final CookieJar _cookieJar;
  DateTime? _lastCaptchaSolvedTime;
  static const _captchaCheckInterval = Duration(minutes: 10);
  String? _sessionId;
  
  late final GlobalKey<NavigatorState> _navigatorKey;

  @override
  ApiService build() {
    _navigatorKey = ref.watch(navigatorKeyProvider);

    _dio = Dio();
    _cookieJar = CookieJar();
    _dio.interceptors.add(dio_cookie.CookieManager(_cookieJar));
    
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = io.HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      client.connectionTimeout = const Duration(seconds: 20);
      client.idleTimeout = const Duration(seconds: 20);
      client.findProxy = (uri) => 'DIRECT';
      return client;
    };
    
    _dio.options.headers = {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 13; SM-G981B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Cache-Control': 'max-age=0',
      'sec-ch-ua': '"Chromium";v="122", "Not(A:Brand";v="24", "Google Chrome";v="122"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"Windows"',
      'Upgrade-Insecure-Requests': '1',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none',
      'Sec-Fetch-User': '?1',
    };
    
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 20);
    _dio.options.followRedirects = false;
    _dio.options.maxRedirects = 0;
    _dio.options.validateStatus = (status) => status != null && status < 500;

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final siteUrl = ref.read(siteUrlServiceProvider);
          if (!options.path.startsWith(siteUrl)) {
            options.path = '$siteUrl${options.path}';
          }
          
          final cookies = await _cookieJar.loadForRequest(Uri.parse(siteUrl));
          if (cookies.isNotEmpty) {
            options.headers['Cookie'] = cookies
                .map((cookie) => '${cookie.name}=${cookie.value}')
                .join('; ');
          }
          
          return handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 403) {
            _logger.w('Access denied (403)');
          }
          return handler.next(error);
        },
      ),
    );

    return this;
  }

  bool _shouldCheckCaptcha() {
    if (_lastCaptchaSolvedTime == null) return true;
    
    final currentSessionId = _dio.options.headers['cookie']?.toString().split('PHPSESSID=').last.split(';').first;
    if (currentSessionId != _sessionId) {
      _logger.d('Session changed, captcha check needed');
      return true;
    }
    
    return DateTime.now().difference(_lastCaptchaSolvedTime!) > _captchaCheckInterval;
  }

  void _updateCaptchaSolvedTime() {
    _lastCaptchaSolvedTime = DateTime.now();
    _sessionId = _dio.options.headers['cookie']?.toString().split('PHPSESSID=').last.split(';').first;
    _logger.d('Captcha solved, updated session: $_sessionId');
  }

  Future<Response<T>> _request<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final baseUrl = ref.read(siteUrlServiceProvider);
    
    try {
      final siteUrl = ref.read(siteUrlServiceProvider);
      var url = '$siteUrl$path';
      if (queryParameters != null && queryParameters.isNotEmpty) {
        final query = queryParameters.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
            .join('&');
        url = '$url?$query';
      }
      
      final response = await _dio.get<T>(
        url,
        options: options ?? Options(
          responseType: ResponseType.plain,
          headers: {
            'Referer': baseUrl,
          },
        ),
      );

      return response;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.unknown && e.message?.contains('host') == true) {
        _logger.w('Unknown host error, checking if URL needs refresh...');
        final siteUrlService = ref.read(siteUrlServiceProvider.notifier);
        if (siteUrlService.isAutoMode) {
          _logger.i('Auto mode: Attempting to refresh URL due to unknown host...');
          await siteUrlService.refreshUrl();
          return _request(path, queryParameters: queryParameters, options: options);
        } else {
          _logger.w('Manual mode: Keeping current URL despite unknown host');
          throw Exception('Unknown host error');
        }
      }
      
      if (e.response?.statusCode == 403) {
        _logger.w('Access denied (403)');
        throw Exception('Access denied (403)');
      } else if (e.response?.statusCode == 404) {
        _logger.w('Page not found (404)');
        throw Exception('Page not found (404)');
      } else if (e.response?.statusCode == 500) {
        _logger.w('Server error (500)');
        throw Exception('Server error (500)');
      }
      
      rethrow;
    }
  }

  Future<List<MangaTitle>> fetchRecentTitles({int offset = 0}) async {
    try {
      final response = await _request<String>(
        '/comic',
        queryParameters: {
          'page': (offset ~/ 20 + 1).toString(),
        },
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
            type: 'manga',
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
            type: 'manga',
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
  _logger.i('[SEARCH][FLOW] 검색 진입: query="$query", offset=$offset');
  final page = (offset ~/ 10) + 1;
  final baseUrl = ref.read(siteUrlServiceProvider);
  final searchUrl = '$baseUrl/bbs/search.php?sfl=wr_subject&stx=${Uri.encodeComponent(query)}&sop=and&where=all&onetable=&page=$page';

  _logger.i('[SEARCH] 요청 URL: $searchUrl');
  try {
    _logger.i('[SEARCH][FLOW] Dio 요청 시작: url=$searchUrl, UA=${_dio.options.headers['User-Agent']}');
    final response = await _dio.get(
      searchUrl,
      options: Options(
        headers: {
          'User-Agent': _dio.options.headers['User-Agent'] ?? 'N/A',
        },
      ),
    );
    _logger.i('[SEARCH] 응답 코드: ${response.statusCode}');
    _logger.i('[SEARCH][FLOW] Dio 응답 수신: statusCode=${response.statusCode}');
    if (response.statusCode == 200) {
      final html = response.data as String;
      _logger.i('[SEARCH] 응답 본문 일부: ${html.substring(0, html.length > 300 ? 300 : html.length)}');
      _logger.i('[SEARCH][FLOW] HTML 길이: ${html.length}');
      if (!html.contains('captcha-bypass') && !html.contains('_cf_chl_opt')) {
        _logger.i('[SEARCH][FLOW] 파싱 시작');
        final result = _parseMangaTitles(html);
        if (result.isEmpty) {
          _logger.w('[SEARCH][FLOW] 파싱 결과 없음. HTML 일부: ${html.substring(0, html.length > 2000 ? 2000 : html.length)}');
        } else {
          _logger.i('[SEARCH][FLOW] 파싱 성공: 결과 ${result.length}건');
        }
        return result;
      } else {
        _logger.w('[SEARCH][FLOW] Cloudflare 캡차 감지됨. 캡차 위젯 진입');
      }
    } else if (response.statusCode == 302) {
      _logger.w('[SEARCH][FLOW] 302 리다이렉트 감지, 강제 캡차 우회 시도. 캡차 위젯 진입');
      final navigatorState = _navigatorKey.currentState;
      if (navigatorState != null) {
        _logger.i('[SEARCH][FLOW] 캡차 위젯 진입');
        final Map<String, dynamic>? resultTuple = await navigatorState.push(
          MaterialPageRoute<Map<String, dynamic>>(
            builder: (context) => CaptchaScreen(
              url: searchUrl,
            ),
          ),
        );

        String? html;
        List<Cookie>? cookies;
        if (resultTuple != null) {
          html = resultTuple['html'] as String?;
          final inappCookies = resultTuple['cookies'] as List?;
          List<io.Cookie>? dartCookies;
          if (inappCookies != null && inappCookies.isNotEmpty) {
            try {
              dartCookies = inappCookies.map((c) {
                if (c is io.Cookie) {
                  return c;
                } else if (c is Map) {
                  // flutter_inappwebview Cookie 객체는 Map으로 전달될 수 있음
                  final name = c['name']?.toString() ?? '';
                  final value = c['value']?.toString() ?? '';
                  final domain = c['domain']?.toString();
                  final path = c['path']?.toString();
                  final expires = c['expires'] is DateTime ? c['expires'] : null;
                  final isHttpOnly = c['isHttpOnly'] == true;
                  final isSecure = c['isSecure'] == true;
                  return io.Cookie(name, value)
                    ..domain = domain
                    ..path = path
                    ..expires = expires
                    ..httpOnly = isHttpOnly
                    ..secure = isSecure;
                } else {
                  throw Exception('Unknown cookie type: "+c.runtimeType.toString()+"');
                }
              }).toList();
              final siteUrl = ref.read(siteUrlServiceProvider);
              await _cookieJar.saveFromResponse(Uri.parse(siteUrl), dartCookies);
              _logger.i('[SEARCH][FLOW] 캡차 쿠키 동기화 완료');
            } catch (e, stack) {
              _logger.e('[SEARCH][FLOW] 쿠키 변환 오류', error: e, stackTrace: stack);
            }
          }
          _logger.i('[SEARCH][FLOW] 캡차 위젯 종료: html 길이=${html?.length ?? 0}, 쿠키=${dartCookies?.map((c) => c.name + '=' + c.value).join('; ') ?? '없음'}');
        }

        if (html != null) {
          _logger.i('[SEARCH][FLOW] 캡차 우회 후 HTML 일부: ${html.substring(0, html.length > 300 ? 300 : html.length)}');
          _logger.i('[SEARCH][FLOW] 캡차 우회 후 파싱 시작');
          final result = _parseMangaTitles(html);
          if (result.isEmpty) {
            _logger.w('[SEARCH][FLOW] 캡차 우회 후 파싱 결과 없음. HTML 일부: ${html.substring(0, html.length > 2000 ? 2000 : html.length)}');
          } else {
            _logger.i('[SEARCH][FLOW] 캡차 우회 후 파싱 성공: 결과 ${result.length}건');
          }
          return result;
        } else {
          _logger.e('[SEARCH][FLOW] 캡차 우회 실패 또는 HTML 미수신');
        }
      } else {
        _logger.e('[SEARCH] navigatorState 없음, 캡차 우회 불가');
      }
    }
  } catch (e, stack) {
    _logger.e('[SEARCH] HTTP 요청 실패', error: e, stackTrace: stack);
  }
  return [];
} 



  List<MangaTitle> _parseMangaTitles(String html) {
    final document = html_parser.parse(html);
    final titles = <MangaTitle>[];

    final table = document.querySelector('#fboardlist');
    if (table == null) {
      _logger.w('[PARSE] #fboardlist 테이블 없음. HTML 일부: ${html.substring(0, html.length > 2000 ? 2000 : html.length)}');
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
  thumbnailUrl: thumbnail.startsWith('http') ? thumbnail : '$siteUrl/$thumbnail',
  author: author,
  release: date,
));
        }
      } catch (e, stack) {
        _logger.e('[PARSE] 만화 타이틀 파싱 실패', error: e, stackTrace: stack);
        _logger.w('[PARSE] 파싱 실패한 row HTML: ${row.outerHtml.substring(0, row.outerHtml.length > 500 ? 500 : row.outerHtml.length)}');
      }
    }

    if (titles.isEmpty) {
      _logger.w('[PARSE] 최종적으로 파싱된 타이틀 없음. 전체 HTML 일부: ${html.substring(0, html.length > 2000 ? 2000 : html.length)}');
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
} 