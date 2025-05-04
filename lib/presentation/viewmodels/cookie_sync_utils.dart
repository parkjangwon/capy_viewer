import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'dart:io' as io;

Future<void> syncWebViewCookiesToDio(String url, CookieJar jar) async {
  final cookies = await CookieManager.instance().getCookies(url: WebUri(url));
  final List<io.Cookie> dartCookies = cookies.map((c) {
    final cookie = io.Cookie(c.name ?? '', c.value ?? '');
    if (c.domain != null) cookie.domain = c.domain!;
    if (c.path != null) cookie.path = c.path!;
    if (c.expiresDate != null)
      cookie.expires = DateTime.fromMillisecondsSinceEpoch(c.expiresDate!);
    if (c.isHttpOnly != null) cookie.httpOnly = c.isHttpOnly!;
    if (c.isSecure != null) cookie.secure = c.isSecure!;
    return cookie;
  }).toList();
  await jar.saveFromResponse(Uri.parse(url), dartCookies);
}

Future<void> syncDioCookiesToWebView(String url, CookieJar jar) async {
  final cookies = await jar.loadForRequest(Uri.parse(url));
  for (final cookie in cookies) {
    await CookieManager.instance().setCookie(
      url: WebUri(url),
      name: cookie.name,
      value: cookie.value,
      domain: cookie.domain,
      path: cookie.path ?? '/',
      expiresDate: cookie.expires?.millisecondsSinceEpoch,
      isSecure: cookie.secure,
      isHttpOnly: cookie.httpOnly,
    );
  }
}
