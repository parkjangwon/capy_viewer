import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class BackupHelper {
  static const String backupVersion = '1.0.0';
  final _db = DatabaseHelper.instance;

  Future<String> createBackup() async {
    try {
      // 1. 백업 데이터 준비
      final backupData = {
        'version': backupVersion,
        'timestamp': DateTime.now().toIso8601String(),
        'preferences': await _getPreferences(),
      };

      // 2. 백업 파일 생성
      final backupDir = await _getDownloadsDirectory();
      final backupFileName =
          'capy_viewer_backup_${DateTime.now().millisecondsSinceEpoch}.cbak';
      final backupFile = File(join(backupDir.path, backupFileName));

      // 3. 데이터베이스 파일 복사
      final dbPath = await getDatabasesPath();
      final dbFile = File(join(dbPath, 'capy_viewer.db'));

      // 4. ZIP 파일 생성 (데이터베이스 + 설정)
      final archive = {
        'metadata': json.encode(backupData),
        'database': await dbFile.readAsBytes(),
      };

      // 5. 백업 파일 저장
      await backupFile.writeAsString(json.encode(archive));

      return backupFile.path;
    } catch (e) {
      throw Exception('백업 생성 중 오류 발생: $e');
    }
  }

  Future<void> restoreBackup(String backupPath) async {
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

  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // Android의 경우 Download 폴더
      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        throw Exception('다운로드 폴더를 찾을 수 없습니다.');
      }
      return directory;
    } else if (Platform.isIOS) {
      // iOS의 경우 Documents 폴더 내 Downloads 디렉토리
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/Downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create();
      }
      return downloadsDir;
    } else if (Platform.isMacOS) {
      // macOS의 경우 사용자의 Downloads 폴더
      final home = Platform.environment['HOME'];
      if (home == null) {
        throw Exception('홈 디렉토리를 찾을 수 없습니다.');
      }
      final directory = Directory('$home/Downloads');
      if (!await directory.exists()) {
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
    final backupDir = await _getDownloadsDirectory();
    final files = await backupDir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.cbak'))
        .toList();

    // 최신 백업이 먼저 오도록 정렬
    files
        .sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    return files;
  }
}
