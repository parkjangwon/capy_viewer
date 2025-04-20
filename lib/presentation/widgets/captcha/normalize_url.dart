// URL 중복 슬래시 정규화 함수
String normalizeUrl(String url) {
  final uri = Uri.parse(url);
  final normPath = uri.path.replaceAll(RegExp(r'/+'), '/');
  return uri.replace(path: normPath).toString();
}
