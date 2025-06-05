import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('capy_viewer.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE liked_chapters (
        id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE saved_chapters (
        id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE recent_chapters (
        id TEXT PRIMARY KEY,
        last_read INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE liked_manga (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        author TEXT NOT NULL DEFAULT '',
        thumbnail_url TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 버전 1에서 2로 업그레이드: liked_manga 테이블 추가
      await db.execute('''
        CREATE TABLE liked_manga (
          id TEXT PRIMARY KEY,
          created_at INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      // 버전 2에서 3으로 업그레이드: liked_manga 테이블에 새 컬럼 추가
      // 기존 테이블 백업
      await db.execute('ALTER TABLE liked_manga RENAME TO liked_manga_old');

      // 새로운 스키마로 테이블 생성
      await db.execute('''
        CREATE TABLE liked_manga (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL DEFAULT '',
          author TEXT NOT NULL DEFAULT '',
          thumbnail_url TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL
        )
      ''');

      // 기존 데이터 마이그레이션
      await db.execute('''
        INSERT INTO liked_manga (id, created_at)
        SELECT id, created_at FROM liked_manga_old
      ''');

      // 백업 테이블 삭제
      await db.execute('DROP TABLE liked_manga_old');
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

  // 최근 본 작품 관련 메서드
  Future<List<String>> getRecentChapters() async {
    final db = await database;
    final result = await db.query(
      'recent_chapters',
      columns: ['id'],
      orderBy: 'last_read DESC',
    );
    return result.map((row) => row['id'] as String).toList();
  }

  Future<void> addRecentChapter(String chapterId) async {
    final db = await database;
    await db.insert(
      'recent_chapters',
      {
        'id': chapterId,
        'last_read': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeRecentChapter(String chapterId) async {
    final db = await database;
    await db.delete(
      'recent_chapters',
      where: 'id = ?',
      whereArgs: [chapterId],
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

  Future<void> insertLike(
      String mangaId, String title, String author, String thumbnailUrl) async {
    final db = await database;
    await db.insert(
      'liked_manga',
      {
        'id': mangaId,
        'title': title,
        'author': author,
        'thumbnail_url': thumbnailUrl,
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
}
