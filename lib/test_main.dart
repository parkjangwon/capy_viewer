import 'dart:io';
import 'test_manga_parser.dart';

void main() async {
  // HTML 파일 읽기
  final file = File('manatoki_example.html');
  final htmlString = await file.readAsString();

  // 파서 생성 및 테스트 실행
  final parser = TestMangaParser();
  final images = parser.parseImages(htmlString);

  // 결과 출력
  print('\n=== 최종 결과 ===');
  print('찾은 이미지 URL 개수: ${images.length}');
  for (var url in images) {
    print(url);
  }
}
