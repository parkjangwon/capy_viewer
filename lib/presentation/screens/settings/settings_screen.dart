import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../data/providers/site_url_provider.dart';
import '../../viewmodels/theme_provider.dart';
import '../../../data/backup/backup_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../../../data/providers/global_cookie_jar_provider.dart';
import '../../../presentation/screens/captcha_page.dart';
import '../../providers/secret_mode_provider.dart';
import '../../../data/database/database_helper.dart';
import '../../providers/recent_chapters_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  final _backupHelper = BackupHelper();
  bool _isProcessing = false;

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

  Future<void> _createBackup() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    try {
      final backupPath = await _backupHelper.createBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('백업이 생성되었습니다: ${path.basename(backupPath)}'),
            action: SnackBarAction(
              label: '확인',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('백업 생성 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _restoreBackup() async {
    if (_isProcessing) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) throw Exception('파일 경로를 찾을 수 없습니다.');

      // 파일 확장자 검사
      if (!file.path!.toLowerCase().endsWith('.capy')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('.capy 확장자의 백업 파일만 복원할 수 있습니다.')),
          );
        }
        return;
      }

      setState(() => _isProcessing = true);

      await _backupHelper.restoreBackup(file.path!);

      // 데이터베이스 연결 재초기화
      final db = DatabaseHelper.instance;
      if (db.isOpen) {
        await db.close();
      }
      await Future.delayed(
          const Duration(milliseconds: 100)); // 데이터베이스가 완전히 닫힐 때까지 잠시 대기
      DatabaseHelper.resetDatabase(); // 데이터베이스 인스턴스 초기화
      await db.database; // 새로운 연결 생성

      // 쿠키 초기화
      ref.invalidate(globalCookieJarProvider);

      // URL 설정 새로고침
      ref.invalidate(siteUrlServiceProvider);

      // 시크릿 모드 설정 새로고침
      ref.invalidate(secretModeProvider);

      // 테마 설정 새로고침
      ref.invalidate(themeProvider);

      // 최근에 본 작품 목록 새로고침
      await ref.read(recentChaptersProvider.notifier).refresh();
      await ref.read(recentChaptersPreviewProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('백업이 복원되었습니다.'),
            duration: Duration(seconds: 3),
          ),
        );

        // 홈 화면으로 이동
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('백업 복원 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
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
    final isSecretMode = ref.watch(secretModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
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
                  const Text(
                    '시크릿 모드',
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
                              '시크릿 모드',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '최근에 본 작품에 기록을 남기지 않습니다',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isSecretMode,
                        onChanged: (value) {
                          ref.read(secretModeProvider.notifier).toggle();
                        },
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
                  const Text(
                    '개발자 도구',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final baseUrl = prefs.getString('site_base_url') ??
                          'https://manatoki468.net';
                      final targetUrl = '$baseUrl/comic/129241';
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CaptchaPage(
                              url: targetUrl,
                              onHtmlReceived: (html) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('캡차 인증이 완료되었습니다.'),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('캡차 인증하기'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      // Dio 쿠키 삭제
                      final cookieJar = ref.read(globalCookieJarProvider);
                      await cookieJar.deleteAll();

                      // WebView 쿠키 삭제
                      final cookieManager = WebViewCookieManager();
                      await cookieManager.clearCookies();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('모든 쿠키가 삭제되었습니다. 필요한 경우 캡차 인증을 다시 해주세요.'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    child: const Text('쿠키 삭제'),
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
                    '백업 및 복원',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _createBackup,
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.backup),
                          label: const Text('백업 생성'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _restoreBackup,
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.restore),
                          label: const Text('백업 복원'),
                        ),
                      ),
                    ],
                  ),
                  if (_isProcessing) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        '처리 중...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_packageInfo != null) ...[
            const SizedBox(height: 16),
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
          ],
        ],
      ),
    );
  }
}
