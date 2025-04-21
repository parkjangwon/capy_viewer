import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cookie_jar/cookie_jar.dart';

final globalCookieJarProvider = Provider<CookieJar>((ref) => CookieJar());
