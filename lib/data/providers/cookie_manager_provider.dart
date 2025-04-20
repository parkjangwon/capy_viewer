import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

final cookieManagerProvider = Provider<CookieManager>((ref) {
  return CookieManager.instance();
}); 