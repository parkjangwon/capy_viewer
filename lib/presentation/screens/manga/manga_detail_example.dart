import 'package:flutter/material.dart';
import 'manga_navigation.dart';

class MangaDetailExample extends StatelessWidget {
  const MangaDetailExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('만화 상세 예제'),
        centerTitle: true,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // 만화 상세 화면으로 이동 (더미 데이터 사용)
            MangaNavigation.navigateToMangaDetail(context, '21054450');
          },
          child: const Text('만화 상세 보기'),
        ),
      ),
    );
  }
}
