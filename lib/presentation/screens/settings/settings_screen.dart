import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/datasources/api_service.dart';
import '../../viewmodels/theme_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../viewmodels/global_cookie_provider.dart';
import '../../viewmodels/cookie_sync_utils.dart';
import '../../../data/providers/site_url_provider.dart';
import '../../../utils/html_manga_parser.dart';
import '../../widgets/captcha_modal.dart';
import '../captcha/captcha_screen.dart';
import 'package:logger/logger.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _urlController = TextEditingController();
  PackageInfo? _packageInfo;
  String _selectedInitialScreen = 'home';
  bool _safeMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPackageInfo();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedInitialScreen = prefs.getString('initial_screen') ?? 'home';
      _safeMode = prefs.getBool('safe_mode') ?? false;
    });
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  Future<void> _saveInitialScreen(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('initial_screen', value);
    setState(() {
      _selectedInitialScreen = value;
    });
  }

  Future<void> _toggleSafeMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('safe_mode', value);
    setState(() {
      _safeMode = value;
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urlService = ref.watch(siteUrlServiceProvider.notifier);
    final currentUrl = ref.watch(siteUrlServiceProvider);
    final currentTheme = ref.watch(themeProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'URL 설정',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            urlService.isAutoMode
                                ? '자동 모드: URL이 자동으로 업데이트됩니다.'
                                : '수동 모드: URL을 직접 입력할 수 있습니다.',
                          ),
                        ),
                        Switch(
                          value: urlService.isAutoMode,
                          onChanged: (value) async {
                            await urlService.setAutoMode(value);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (urlService.isAutoMode) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text('현재 URL: $currentUrl'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () async {
                              await urlService.refreshUrl();
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _urlController..text = currentUrl,
                              decoration: const InputDecoration(
                                labelText: 'URL 입력',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (value) async {
                                await urlService.updateUrl(value);
                                setState(() {});
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('URL이 저장되었습니다.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () async {
                              await urlService.updateUrl(_urlController.text);
                              setState(() {});
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('URL이 저장되었습니다.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.save),
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '화면 설정',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedInitialScreen,
                      decoration: const InputDecoration(
                        labelText: '시작 화면 선택',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'home',
                          child: Text('홈'),
                        ),
                        DropdownMenuItem(
                          value: 'search',
                          child: Text('검색'),
                        ),
                        DropdownMenuItem(
                          value: 'recent',
                          child: Text('최근에 본 작품'),
                        ),
                        DropdownMenuItem(
                          value: 'favorites',
                          child: Text('좋아요'),
                        ),
                        DropdownMenuItem(
                          value: 'saved',
                          child: Text('저장한 작품'),
                        ),
                        DropdownMenuItem(
                          value: 'settings',
                          child: Text('설정'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _saveInitialScreen(value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<ThemeMode>(
                      value: currentTheme,
                      decoration: const InputDecoration(
                        labelText: '테마 선택',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('시스템 설정'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('라이트 모드'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('다크 모드'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          ref.read(themeProvider.notifier).setTheme(value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '콘텐츠 필터',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '안심 모드',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '민감한 콘텐츠를 숨깁니다',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _safeMode,
                          onChanged: _toggleSafeMode,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('개발자 도구',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final targetUrl = currentUrl.endsWith('/')
                            ? '${currentUrl}comic/129241'
                            : '$currentUrl/comic/129241';
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CaptchaWebViewPage(
                                url: targetUrl,
                                onCookiesExtracted: (cookies) {}),
                          ),
                        );
                      },
                      child: const Text('캡차 인증하기'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final jar = ref.read(globalCookieJarProvider);
                        final prefs = await SharedPreferences.getInstance();
                        final baseUrl = prefs.getString('site_base_url') ??
                            'https://manatoki468.net';
                        final targetUrl =
                            '$baseUrl/comic?stx=%EB%B2%A0%EB%A5%B4%EC%84%B8%EB%A5%B4%ED%81%AC';
                        final controller = WebViewController()
                          ..setJavaScriptMode(JavaScriptMode.unrestricted);
                        await syncDioCookiesToWebView(targetUrl, jar); // 쿠키 동기화
                        await controller.loadRequest(Uri.parse(targetUrl));
                        await Future.delayed(const Duration(seconds: 3));
                        final html =
                            await controller.runJavaScriptReturningResult(
                                'document.documentElement.outerHTML');
                        final parsed = parseMangaListFromHtml(html.toString());
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('HTML 결과 (작품 리스트)'),
                              content: parsed.isEmpty
                                  ? const Text('작품 없음')
                                  : SizedBox(
                                      width: 320,
                                      height: 400,
                                      child: ListView.builder(
                                        itemCount: parsed.length,
                                        itemBuilder: (context, idx) {
                                          final item = parsed[idx];
                                          return ListTile(
                                            title: Text(item.title),
                                            subtitle: Text(item.href,
                                                style: const TextStyle(
                                                    fontSize: 11)),
                                            onTap: () async {
                                              final uri = Uri.parse(item.href);
                                              if (await canLaunchUrl(uri)) {
                                                launchUrl(uri,
                                                    mode: LaunchMode
                                                        .externalApplication);
                                              }
                                            },
                                          );
                                        },
                                      ),
                                    ),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('닫기'))
                              ],
                            ),
                          );
                        }
                      },
                      child: const Text('HTML 가져오기(WebView)'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_packageInfo != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '앱 정보',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('버전: ${_packageInfo!.version}'),
                      Text('빌드 번호: ${_packageInfo!.buildNumber}'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('쿠키 삭제'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    onPressed: () async {
                      final apiService = ref.read(apiServiceProvider());
                      await apiService.clearCache();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('쿠키가 삭제되었습니다..'),
                              duration: Duration(seconds: 2)),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// === CaptchaWebViewPage: 캡차 인증용 웹뷰 ===

class CaptchaWebViewPage extends StatefulWidget {
  final String url;
  final ValueChanged<String> onCookiesExtracted;
  const CaptchaWebViewPage(
      {super.key, required this.url, required this.onCookiesExtracted});

  @override
  State<CaptchaWebViewPage> createState() => _CaptchaWebViewPageState();
}

class _CaptchaWebViewPageState extends State<CaptchaWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _mounted = true;
  bool _hasSeenChallenge = false;
  String _lastHtml = '';
  int _blankCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!_mounted) return;
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) async {
            if (!_mounted) return;
            setState(() => _isLoading = false);

            if (url.startsWith('about:')) {
              if (url == 'about:blank') {
                _blankCount++;
                if (_blankCount >= 3) {
                  // 여러 번의 about:blank 후에 인증이 완료된 것으로 간주
                  if (_mounted) {
                    Navigator.of(context).pop();
                  }
                }
              }
              return;
            }

            final html = await _controller.runJavaScriptReturningResult(
                'document.documentElement.outerHTML');
            final htmlStr = html.toString().toLowerCase();

            // HTML 내용이 변경되었는지 확인
            if (htmlStr != _lastHtml) {
              _lastHtml = htmlStr;

              // 첫 페이지 로드에서 챌린지를 보았는지 확인
              if (!_hasSeenChallenge) {
                if (htmlStr.contains('challenge-form') ||
                    htmlStr.contains('cf-please-wait') ||
                    htmlStr.contains('turnstile')) {
                  _hasSeenChallenge = true;
                } else {
                  // 챌린지가 없으면 바로 종료
                  if (_mounted) {
                    Navigator.of(context).pop();
                  }
                }
              } else {
                // 챌린지를 본 후에 챌린지 요소가 없으면 인증 완료
                if (!htmlStr.contains('challenge-form') &&
                    !htmlStr.contains('cf-please-wait') &&
                    !htmlStr.contains('turnstile')) {
                  if (_mounted) {
                    Navigator.of(context).pop();
                  }
                }
              }
            }
          },
          onNavigationRequest: (request) {
            // 모든 네비게이션 허용
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('보안 인증'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
