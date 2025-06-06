import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const _databaseName = "capy_viewer.db";
  // 데이터베이스 버전을 8로 올립니다
  static const _databaseVersion = 8;

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  bool get isOpen => _database?.isOpen ?? false;

  static void resetDatabase() {
    _database = null;
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 좋아요한 회차 테이블
    await db.execute('''
      CREATE TABLE liked_chapters (
        id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL
      )
    ''');

    // 저장한 회차 테이블
    await db.execute('''
      CREATE TABLE saved_chapters (
        id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL
      )
    ''');

    // 최근 본 회차 테이블 (최신 스키마)
    await db.execute('''
      CREATE TABLE recent_chapters (
        id TEXT PRIMARY KEY,
        manga_id TEXT NOT NULL,
        chapter_title TEXT NOT NULL,
        thumbnail_url TEXT NOT NULL DEFAULT '',
        last_read INTEGER NOT NULL,
        last_page INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (manga_id) REFERENCES liked_manga(id) ON DELETE CASCADE
      )
    ''');

    // 좋아요한 작품 테이블
    await db.execute('''
      CREATE TABLE liked_manga (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        author TEXT NOT NULL DEFAULT '',
        thumbnail_url TEXT NOT NULL DEFAULT '',
        genres TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 6) {
      // 기존 테이블 삭제
      await db.execute('DROP TABLE IF EXISTS liked_manga');

      // 새로운 스키마로 테이블 생성
      await db.execute('''
        CREATE TABLE liked_manga (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL DEFAULT '',
          author TEXT NOT NULL DEFAULT '',
          thumbnail_url TEXT NOT NULL DEFAULT '',
          genres TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 7) {
      // recent_chapters 테이블에 author 필드 추가
      await db
          .execute('ALTER TABLE recent_chapters RENAME TO recent_chapters_old');

      await db.execute('''
        CREATE TABLE recent_chapters (
          id TEXT PRIMARY KEY,
          manga_id TEXT NOT NULL,
          chapter_title TEXT NOT NULL,
          thumbnail_url TEXT NOT NULL DEFAULT '',
          author TEXT NOT NULL DEFAULT '',
          last_read INTEGER NOT NULL,
          last_page INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (manga_id) REFERENCES liked_manga(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        INSERT INTO recent_chapters (
          id, manga_id, chapter_title, thumbnail_url, last_read, last_page
        )
        SELECT id, manga_id, chapter_title, thumbnail_url, last_read, last_page 
        FROM recent_chapters_old
      ''');

      await db.execute('DROP TABLE recent_chapters_old');
    }

    if (oldVersion < 8) {
      // recent_chapters 테이블의 author 필드를 NULL 허용으로 변경
      await db
          .execute('ALTER TABLE recent_chapters RENAME TO recent_chapters_old');

      await db.execute('''
        CREATE TABLE recent_chapters (
          id TEXT PRIMARY KEY,
          manga_id TEXT NOT NULL,
          chapter_title TEXT NOT NULL,
          thumbnail_url TEXT NOT NULL DEFAULT '',
          author TEXT,
          last_read INTEGER NOT NULL,
          last_page INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (manga_id) REFERENCES liked_manga(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        INSERT INTO recent_chapters (
          id, manga_id, chapter_title, thumbnail_url, author, last_read, last_page
        )
        SELECT id, manga_id, chapter_title, thumbnail_url, author, last_read, last_page 
        FROM recent_chapters_old
      ''');

      await db.execute('DROP TABLE recent_chapters_old');
    }

    if (oldVersion < 9) {
      // recent_chapters 테이블에서 author 필드 제거
      await db
          .execute('ALTER TABLE recent_chapters RENAME TO recent_chapters_old');

      await db.execute('''
        CREATE TABLE recent_chapters (
          id TEXT PRIMARY KEY,
          manga_id TEXT NOT NULL,
          chapter_title TEXT NOT NULL,
          thumbnail_url TEXT NOT NULL DEFAULT '',
          last_read INTEGER NOT NULL,
          last_page INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (manga_id) REFERENCES liked_manga(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        INSERT INTO recent_chapters (
          id, manga_id, chapter_title, thumbnail_url, last_read, last_page
        )
        SELECT id, manga_id, chapter_title, thumbnail_url, last_read, last_page 
        FROM recent_chapters_old
      ''');

      await db.execute('DROP TABLE recent_chapters_old');
    }
  }

  // 좋아요 관련 메서드
  Future<List<String>> getLikedChapters() async {
    final db = await database;
    final result = await db.query(
      'liked_chapters',
      columns: ['id'],
      orderBy: 'created_at DESC',
    );
    return result.map((row) => row['id'] as String).toList();
  }

  Future<void> addLikedChapter(String chapterId) async {
    final db = await database;
    await db.insert(
      'liked_chapters',
      {
        'id': chapterId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeLikedChapter(String chapterId) async {
    final db = await database;
    await db.delete(
      'liked_chapters',
      where: 'id = ?',
      whereArgs: [chapterId],
    );
  }

  // 저장한 작품 관련 메서드
  Future<List<String>> getSavedChapters() async {
    final db = await database;
    final result = await db.query(
      'saved_chapters',
      columns: ['id'],
      orderBy: 'created_at DESC',
    );
    return result.map((row) => row['id'] as String).toList();
  }

  Future<void> addSavedChapter(String chapterId) async {
    final db = await database;
    await db.insert(
      'saved_chapters',
      {
        'id': chapterId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeSavedChapter(String chapterId) async {
    final db = await database;
    await db.delete(
      'saved_chapters',
      where: 'id = ?',
      whereArgs: [chapterId],
    );
  }

  // 최근에 본 작품 관련 메서드
  Future<List<Map<String, dynamic>>> getRecentChapters({int? limit}) async {
    print('[데이터베이스] 최근 본 회차 조회 시작');
    final db = await database;
    final result = await db.query(
      'recent_chapters',
      orderBy: 'last_read DESC',
      limit: limit,
      groupBy: 'manga_id', // 만화 ID로 그룹화하여 중복 제거
    );
    print('[데이터베이스] 조회된 회차 수: ${result.length}');
    return result;
  }

  Future<Map<String, dynamic>?> getRecentChapter(String mangaId) async {
    final db = await database;
    final result = await db.query(
      'recent_chapters',
      where: 'manga_id = ?',
      whereArgs: [mangaId],
      orderBy: 'last_read DESC',
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> updateRecentChapter({
    required String chapterId,
    required String mangaId,
    required String chapterTitle,
    required String thumbnailUrl,
    required int lastPage,
  }) async {
    final db = await database;

    // 기존 데이터 삭제
    await db.delete(
      'recent_chapters',
      where: 'manga_id = ?',
      whereArgs: [mangaId],
    );

    // 새로운 데이터 추가
    await db.insert(
      'recent_chapters',
      {
        'id': chapterId,
        'manga_id': mangaId,
        'chapter_title': chapterTitle,
        'thumbnail_url': thumbnailUrl,
        'last_read': DateTime.now().millisecondsSinceEpoch,
        'last_page': lastPage,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> addRecentChapter({
    required String chapterId,
    required String mangaId,
    required String chapterTitle,
    required String thumbnailUrl,
    required int lastPage,
  }) async {
    final db = await database;
    await db.insert(
      'recent_chapters',
      {
        'id': chapterId,
        'manga_id': mangaId,
        'chapter_title': chapterTitle,
        'thumbnail_url': thumbnailUrl,
        'last_read': DateTime.now().millisecondsSinceEpoch,
        'last_page': lastPage,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 작품 좋아요 관련 메서드
  Future<bool> isLiked(String mangaId) async {
    final db = await database;
    final result = await db.query(
      'liked_manga',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [mangaId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> insertLike(String mangaId, String title, String author,
      String thumbnailUrl, List<String> genres) async {
    final db = await database;
    await db.insert(
      'liked_manga',
      {
        'id': mangaId,
        'title': title,
        'author': author,
        'thumbnail_url': thumbnailUrl,
        'genres': genres.join('|'),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeLike(String mangaId) async {
    final db = await database;
    await db.delete(
      'liked_manga',
      where: 'id = ?',
      whereArgs: [mangaId],
    );
  }

  Future<List<Map<String, dynamic>>> getLikedManga() async {
    final db = await database;
    final result = await db.query(
      'liked_manga',
      orderBy: 'created_at DESC',
    );
    return result;
  }

  // 데이터베이스 관리 메서드
  Future<void> close() async {
    final db = await database;
    db.close();
  }

  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'capy_viewer.db');
    await databaseFactory.deleteDatabase(path);
  }

  Future<void> deleteRecentChapter(String chapterId) async {
    print('[데이터베이스] 최근 본 회차 삭제: $chapterId');
    final db = await database;
    await db.delete(
      'recent_chapters',
      where: 'id = ?',
      whereArgs: [chapterId],
    );
    print('[데이터베이스] 회차 삭제 완료');
  }
}
