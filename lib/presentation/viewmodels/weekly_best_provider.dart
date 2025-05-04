import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../data/models/weekly_best_model.dart';
import '../../data/parsers/weekly_best_parser.dart';
import '../../data/providers/site_url_provider.dart';
import 'global_cookie_provider.dart';

final weeklyBestProvider = FutureProvider<List<WeeklyBestItem>>((ref) async {
  final dio = Dio();
  final baseUrl = ref.read(siteUrlServiceProvider);
  final cookieJar = ref.read(globalCookieJarProvider);
  
  try {
    // 쿠키 가져오기
    final cookies = await cookieJar.loadForRequest(Uri.parse(baseUrl));
    final cookieString = cookies.isNotEmpty
        ? cookies.map((c) => '${c.name}=${c.value}').join('; ')
        : '';
    
    // 메인 페이지 요청
    final response = await dio.get(
      baseUrl,
      options: Options(
        headers: {
          'Cookie': cookieString,
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
          'Referer': baseUrl,
          'Origin': Uri.parse(baseUrl).origin,
        },
      ),
    );
    
    if (response.statusCode == 200) {
      final html = response.data as String;
      
      // 주간 베스트 파싱
      final weeklyBestItems = WeeklyBestParser.parseWeeklyBest(html);
      return weeklyBestItems;
    } else {
      print('주간 베스트 요청 실패: ${response.statusCode}');
      return [];
    }
  } catch (e) {
    print('주간 베스트 로딩 오류: $e');
    return [];
  }
});
