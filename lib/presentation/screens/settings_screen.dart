import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/captcha_modal.dart';
import '../../data/providers/site_url_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseUrl = ref.watch(siteUrlServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          ListTile(
            title: const Text('캡차 인증 테스트'),
            subtitle: const Text('클라우드플레어 보안 인증을 테스트합니다.'),
            trailing: ElevatedButton(
              onPressed: () {
                final targetUrl = baseUrl.endsWith('/')
                    ? '${baseUrl}comic/129241'
                    : '$baseUrl/comic/129241';
                showDialog(
                  context: context,
                  builder: (context) => CaptchaModal(
                    url: targetUrl,
                    onCaptchaVerified: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('캡차 인증이 완료되었습니다.'),
                        ),
                      );
                    },
                  ),
                );
              },
              child: const Text('테스트'),
            ),
          ),
          const Divider(),
          // ... 기존 설정 항목들
        ],
      ),
    );
  }
}
