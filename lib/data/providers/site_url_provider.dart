import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/site_url_service.dart';

final siteUrlServiceProvider = StateNotifierProvider<SiteUrlService, String>((ref) {
  return SiteUrlService();
}); 