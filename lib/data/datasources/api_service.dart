import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:html/parser.dart' as html_parser;
import '../models/manga_title.dart';
import '../models/title_detail.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../presentation/widgets/captcha/cloudflare_captcha.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:dio/io.dart';
import 'site_url_service.dart';
import '../../presentation/screens/captcha_screen.dart';
import '../../presentation/viewmodels/navigator_provider.dart';

part 'api_service.g.dart';

@Riverpod(keepAlive: true)
class ApiService extends _$ApiService {
  final _logger = Logger();
  late final Dio _dio;
  late final CookieJar _cookieJar;
  DateTime? _lastCaptchaSolvedTime;
  static const _captchaCheckInterval = Duration(minutes: 10);
  String? _sessionId;
  final String baseUrl = 'https://manatoki468.net';
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  ApiService build() {
    _dio = Dio();
    _cookieJar = CookieJar();
    _dio.interceptors.add(CookieManager(_cookieJar));
    
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
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
          if (!options.path.startsWith(baseUrl)) {
            options.path = '$baseUrl${options.path}';
          }
          
          final cookies = await _cookieJar.loadForRequest(Uri.parse(baseUrl));
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
      var url = '$baseUrl$path';
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
    final page = (offset ~/ 10) + 1;
    final searchUrl = '$baseUrl/bbs/search.php?sfl=wr_subject&stx=${Uri.encodeComponent(query)}&sop=and&where=all&onetable=&page=$page';
    
    try {
      final response = await _dio.get(
        searchUrl,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
          },
        ),
      );

      if (response.statusCode == 200) {
        final html = response.data as String;
        if (!html.contains('cf-browser-verification') && 
            !html.contains('cf-challenge') &&
            !html.contains('_cf_chl_opt')) {
          return _parseMangaTitles(html);
        }
      }
    } catch (e) {
      _logger.e('Direct HTTP request failed', error: e);
    }

    final navigatorState = _navigatorKey.currentState;
    if (navigatorState != null) {
      final html = await navigatorState.push<String>(
        MaterialPageRoute(
          builder: (context) => CaptchaScreen(
            url: searchUrl,
            onHtmlReceived: (html) {
              navigatorState.pop(html);
            },
          ),
        ),
      );

      if (html != null) {
        return _parseMangaTitles(html);
      }
    }

    return [];
  }

  List<MangaTitle> _parseMangaTitles(String html) {
    final document = html_parser.parse(html);
    final titles = <MangaTitle>[];

    final table = document.querySelector('#fboardlist');
    if (table == null) return titles;

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

          titles.add(MangaTitle(
            title: title,
            id: _extractIdFromUrl(href),
            thumbnailUrl: thumbnail.startsWith('http') ? thumbnail : '$baseUrl/$thumbnail',
            author: author,
            release: date,
          ));
        }
      } catch (e) {
        _logger.e('Error parsing manga title', error: e);
      }
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