import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 메인 화면의 선택된 탭 인덱스를 관리하는 프로바이더
final selectedTabProvider = StateProvider<int>((ref) => 0);
