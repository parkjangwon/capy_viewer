import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

/// 사이트 URL을 관리하는 서비스
final siteUrlServiceProvider =
    StateNotifierProvider<SiteUrlService, String>((ref) => SiteUrlService());

class SiteUrlService extends StateNotifier<String> {
  SiteUrlService() : super('https://manatoki468.net') {
    initialize();
  }

  final _logger = Logger();
  final _dio = Dio();
  bool _isAutoMode = true;
  final _telegramChannelUrl = 'https://t.me/s/p48v267tsgubym7';
  final _defaultUrl = 'https://manatoki468.net';
  
  bool get isAutoMode => _isAutoMode;
  
  String get baseUrl => state;
  
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isAutoMode = prefs.getBool('auto_mode') ?? true;
    
    // 저장된 URL이 있으면 우선 사용
    final savedUrl = prefs.getString('site_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      state = savedUrl;
    } else {
      // 저장된 URL이 없는 경우에만 기본값 사용
      state = _defaultUrl;
    }

    // 자동 모드일 때만 URL 갱신
    if (_isAutoMode) {
      await refreshUrl();
    }
  }

  Future<void> setAutoMode(bool value) async {
    _isAutoMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_mode', value);
    
    if (value) {
      await refreshUrl();
    }
  }

  Future<bool> isUrlAccessible(String url) async {
    try {
      final response = await _dio.head(url);
      return response.statusCode == 200;
    } catch (e) {
      _logger.w('URL is not accessible: $url', error: e);
      return false;
    }
  }

  Future<void> refreshUrl() async {
    // 수동 모드일 때는 URL 갱신을 하지 않음
    if (!_isAutoMode) {
      _logger.i('Manual mode: Skipping URL refresh');
      return;
    }

    _logger.i('Starting URL refresh from Telegram channel: $_telegramChannelUrl');
    try {
      final response = await _dio.get<String>(_telegramChannelUrl);
      final html = response.data;
      if (html == null) {
        _logger.w('Telegram channel response is empty');
        return;
      }

      _logger.i('Successfully accessed Telegram channel');
      final regex = RegExp(r'<a[^>]*href="([^"]*manatoki[^"]*)"[^>]*>');
      final match = regex.firstMatch(html);
      
      if (match != null && match.groupCount >= 1) {
        final url = match.group(1)!;
        _logger.i('Found new URL in Telegram channel: $url');
        if (url.isNotEmpty && url != state) {
          await updateUrl(url);
          _logger.i('Successfully updated URL to: $url');
        } else {
          _logger.i('URL is same as current or empty, skipping update');
        }
      } else {
        _logger.w('No matching URL found in Telegram channel');
      }
    } catch (e) {
      _logger.e('Failed to refresh URL', error: e);
      // 에러 발생 시에도 수동 모드에서는 URL을 변경하지 않음
      if (_isAutoMode && state.isEmpty) {
        _logger.w('Using default URL due to error');
        await updateUrl(_defaultUrl);
      }
    }
  }

  Future<void> updateUrl(String url) async {
    // 수동 모드일 때는 URL 갱신을 하지 않음
    if (!_isAutoMode) {
      state = url;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('site_url', url);
      _logger.i('Updated site URL in manual mode: $url');
      return;
    }

    // 자동 모드일 때만 URL 갱신
    if (url != state) {
      state = url;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('site_url', url);
      _logger.i('Updated site URL in auto mode: $url');
    }
  }
} 