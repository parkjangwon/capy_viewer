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
      version: 5,
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
        manga_id TEXT NOT NULL,
        chapter_title TEXT NOT NULL,
        thumbnail_url TEXT NOT NULL DEFAULT '',
        last_read INTEGER NOT NULL,
        last_page INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (manga_id) REFERENCES liked_manga(id) ON DELETE CASCADE
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

    if (oldVersion < 4) {
      // 버전 3에서 4로 업그레이드: recent_chapters 테이블 수정
      await db.execute('DROP TABLE IF EXISTS recent_chapters_old');
      await db
          .execute('ALTER TABLE recent_chapters RENAME TO recent_chapters_old');

      // 새로운 스키마로 테이블 생성
      await db.execute('''
        CREATE TABLE recent_chapters (
          id TEXT PRIMARY KEY,
          manga_id TEXT NOT NULL,
          chapter_title TEXT NOT NULL,
          last_read INTEGER NOT NULL,
          last_page INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (manga_id) REFERENCES liked_manga(id) ON DELETE CASCADE
        )
      ''');

      // 기존 데이터 마이그레이션
      await db.execute('''
        INSERT INTO recent_chapters (id, manga_id, chapter_title, last_read, last_page)
        SELECT id, '', '', last_read, 0 FROM recent_chapters_old
      ''');

      // 백업 테이블 삭제
      await db.execute('DROP TABLE recent_chapters_old');
    }

    if (oldVersion < 5) {
      // 버전 4에서 5로 업그레이드: recent_chapters 테이블에 thumbnail_url 필드 추가
      await db.execute('DROP TABLE IF EXISTS recent_chapters_old');
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
        INSERT INTO recent_chapters (id, manga_id, chapter_title, thumbnail_url, last_read, last_page)
        SELECT id, manga_id, chapter_title, '', last_read, last_page FROM recent_chapters_old
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

  // 최근 본 작품 관련 메서드
  Future<List<Map<String, dynamic>>> getRecentChapters({int? limit}) async {
    print('[데이터베이스] 최근 본 회차 조회 시작');
    final db = await database;
    final result = await db.query(
      'recent_chapters',
      orderBy: 'last_read DESC',
      limit: limit,
    );
    print('[데이터베이스] 조회된 회차 수: ${result.length}');
    return result;
  }

  Future<void> addRecentChapter({
    required String chapterId,
    required String mangaId,
    required String chapterTitle,
    required String thumbnailUrl,
    required int lastPage,
  }) async {
    print('[데이터베이스] 최근 본 회차 추가: $chapterId');
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
    print('[데이터베이스] 회차 추가 완료');
  }

  Future<void> updateLastPage(String chapterId, int lastPage) async {
    print('[데이터베이스] 페이지 업데이트: $chapterId - $lastPage');
    final db = await database;
    await db.update(
      'recent_chapters',
      {
        'last_page': lastPage,
        'last_read': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [chapterId],
    );
    print('[데이터베이스] 페이지 업데이트 완료');
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
