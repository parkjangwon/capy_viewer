import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';

class BackupHelper {
  static const String backupVersion = '1.0.0';
  final _db = DatabaseHelper.instance;

  Future<String> createBackup() async {
    try {
      debugPrint('백업 생성 시작');
      // 1. SharedPreferences에서 모든 설정 가져오기
      final prefs = await SharedPreferences.getInstance();
      final prefsData = await _getPreferences();
      debugPrint('설정 데이터 가져오기 완료');

      // 2. 백업 데이터 준비
      final backupData = {
        'version': backupVersion,
        'timestamp': DateTime.now().toIso8601String(),
        'preferences': {
          'site_base_url': prefs.getString('site_base_url'),
          'is_auto_mode': prefs.getBool('is_auto_mode'),
          'safe_mode': prefs.getBool('safe_mode'),
          'secret_mode': prefs.getBool('secret_mode'),
          ...prefsData,
        },
      };
      debugPrint('백업 데이터 준비 완료');

      // 3. 백업 파일 생성
      final backupDir = await _getBackupDirectory();
      debugPrint('백업 디렉토리 경로: ${backupDir.path}');

      final now = DateTime.now();
      final timestamp = DateFormat('yyyyMMddHHmm').format(now);
      final backupFileName = 'capy-viewer-backup-$timestamp.capy';
      final backupFile = File(join(backupDir.path, backupFileName));
      debugPrint('백업 파일 경로: ${backupFile.path}');

      // 4. 데이터베이스 파일 복사
      final dbPath = await getDatabasesPath();
      final dbFile = File(join(dbPath, 'capy_viewer.db'));
      debugPrint('데이터베이스 파일 경로: ${dbFile.path}');

      // 5. ZIP 파일 생성 (데이터베이스 + 설정)
      final archive = {
        'metadata': json.encode(backupData),
        'database': await dbFile.readAsBytes(),
      };

      // 6. 백업 파일 저장
      await backupFile.writeAsString(json.encode(archive));
      debugPrint('백업 파일 저장 완료');

      // iOS의 경우 파일 공유 시트 표시
      if (Platform.isIOS) {
        debugPrint('iOS 공유 시트 표시 시도');
        try {
          await Share.shareXFiles(
            [XFile(backupFile.path)],
            subject: '카피 뷰어 백업 파일',
          ).then((_) async {
            // 공유가 완료된 후 임시 파일 삭제
            if (await backupFile.exists()) {
              await backupFile.delete();
              debugPrint('임시 백업 파일 삭제 완료');
            }
          });
          debugPrint('iOS 공유 완료');
        } catch (e) {
          debugPrint('iOS 공유 실패: $e');
          rethrow;
        }
      }

      return backupFile.path;
    } catch (e, stackTrace) {
      debugPrint('백업 생성 중 오류 발생: $e');
      debugPrint('스택 트레이스: $stackTrace');
      throw Exception('백업 생성 중 오류 발생: $e');
    }
  }

  Future<void> restoreBackup(String backupPath) async {
    if (!backupPath.toLowerCase().endsWith('.capy')) {
      throw Exception('올바른 백업 파일이 아닙니다. (.capy 파일만 복원 가능)');
    }

    try {
      // 1. 백업 파일 읽기
      final backupFile = File(backupPath);
      final archive = json.decode(await backupFile.readAsString());

      // 2. 메타데이터 검증
      final metadata = json.decode(archive['metadata'] as String);
      if (metadata['version'] != backupVersion) {
        throw Exception('지원하지 않는 백업 버전입니다.');
      }

      // 3. 데이터베이스 복원
      final dbPath = await getDatabasesPath();
      final dbFile = File(join(dbPath, 'capy_viewer.db'));

      // 데이터베이스 파일이 있다면 삭제
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      // 새 데이터베이스 파일 생성
      await dbFile.writeAsBytes(List<int>.from(archive['database']));

      // 4. 설정 복원
      await _restorePreferences(
          metadata['preferences'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('백업 복원 중 오류 발생: $e');
    }
  }

  Future<Map<String, dynamic>> _getPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final prefsMap = <String, dynamic>{};

    for (final key in keys) {
      prefsMap[key] = prefs.get(key);
    }

    return prefsMap;
  }

  Future<void> _restorePreferences(Map<String, dynamic> prefsData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    for (final entry in prefsData.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(key, value);
      }
    }
  }

  Future<Directory> _getBackupDirectory() async {
    if (Platform.isAndroid) {
      // Android의 경우 Download 폴더
      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        throw Exception('다운로드 폴더를 찾을 수 없습니다.');
      }
      return directory;
    } else if (Platform.isIOS) {
      // iOS의 경우 임시 디렉토리 사용 (공유 후 자동 삭제)
      return await getTemporaryDirectory();
    } else if (Platform.isMacOS) {
      // macOS의 경우 path_provider의 getDownloadsDirectory() 사용
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception('다운로드 폴더를 찾을 수 없습니다.');
      }
      return directory;
    } else {
      // 기타 플랫폼의 경우 앱의 documents 디렉토리
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/Downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create();
      }
      return downloadsDir;
    }
  }

  Future<List<FileSystemEntity>> getBackupFiles() async {
    final backupDir = await _getBackupDirectory();
    final files = await backupDir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.capy'))
        .toList();

    // 최신 백업이 먼저 오도록 정렬
    files
        .sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    return files;
  }
}
