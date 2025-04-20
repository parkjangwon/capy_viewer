import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/datasources/site_url_service.dart';
import '../../../data/datasources/api_service.dart';
import '../../viewmodels/theme_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _urlController = TextEditingController();
  PackageInfo? _packageInfo;
  String _selectedInitialScreen = 'home';

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
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                        DropdownMenuItem(
                          value: 'test',
                          child: Text('테스트'),
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
                      final apiService = ref.read(apiServiceProvider.notifier);
                      await apiService.clearCache();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('쿠키가 삭제되었습니다..'), duration: Duration(seconds: 2)),
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