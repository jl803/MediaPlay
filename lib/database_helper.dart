import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'media_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('media.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE media (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        path TEXT NOT NULL,
        isVideo INTEGER NOT NULL,
        size TEXT NOT NULL,
        thumbnailPath TEXT,
        originalThumbnailPath TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE playlist_media (
        playlistId INTEGER NOT NULL,
        mediaPath TEXT NOT NULL,
        PRIMARY KEY (playlistId, mediaPath),
        FOREIGN KEY (playlistId) REFERENCES playlists (id) ON DELETE CASCADE,
        FOREIGN KEY (mediaPath) REFERENCES media (path) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE playlists (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          createdAt TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE playlist_media (
          playlistId INTEGER NOT NULL,
          mediaPath TEXT NOT NULL,
          PRIMARY KEY (playlistId, mediaPath),
          FOREIGN KEY (playlistId) REFERENCES playlists (id) ON DELETE CASCADE,
          FOREIGN KEY (mediaPath) REFERENCES media (path) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('ALTER TABLE media ADD COLUMN originalThumbnailPath TEXT');
      await db.execute('UPDATE media SET originalThumbnailPath = thumbnailPath WHERE originalThumbnailPath IS NULL');
    }
  }

  Future<int> insertMedia(MediaFile file) async {
    final db = await instance.database;
    return await db.insert('media', {
      'name': file.name,
      'path': file.path,
      'isVideo': file.isVideo ? 1 : 0,
      'size': file.size,
      'thumbnailPath': file.thumbnailPath,
      'originalThumbnailPath': file.originalThumbnailPath,
    });
  }

  Future<List<MediaFile>> getAllMedia() async {
    final db = await instance.database;
    final result = await db.query('media');

    return result.map((json) => MediaFile(
      name: json['name'] as String,
      path: json['path'] as String,
      isVideo: (json['isVideo'] as int) == 1,
      size: json['size'] as String,
      thumbnailPath: json['thumbnailPath'] as String?,
      originalThumbnailPath: json['originalThumbnailPath'] as String?,
    )).toList();
  }

  Future<int> updateMediaThumbnailPath(String path, String? thumbnailPath) async {
    final db = await instance.database;
    return await db.update(
      'media',
      {'thumbnailPath': thumbnailPath},
      where: 'path = ?',
      whereArgs: [path],
    );
  }

  Future<int> deleteMedia(String path) async {
    final db = await instance.database;
    await db.delete(
      'playlist_media',
      where: 'mediaPath = ?',
      whereArgs: [path],
    );
    return await db.delete(
      'media',
      where: 'path = ?',
      whereArgs: [path],
    );
  }

  Future<int> renameMedia(String oldPath, String newName) async {
    final db = await instance.database;
    return await db.update(
      'media',
      {'name': newName},
      where: 'path = ?',
      whereArgs: [oldPath],
    );
  }

  Future<int> createPlaylist(String name) async {
    final db = await instance.database;
    return await db.insert('playlists', {
      'name': name,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<int> renamePlaylist(int playlistId, String name) async {
    final db = await instance.database;
    return await db.update(
      'playlists',
      {'name': name},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  Future<int> deletePlaylist(int playlistId) async {
    final db = await instance.database;
    await db.delete(
      'playlist_media',
      where: 'playlistId = ?',
      whereArgs: [playlistId],
    );
    return await db.delete(
      'playlists',
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  Future<void> addMediaToPlaylist(int playlistId, String mediaPath) async {
    final db = await instance.database;
    await db.insert(
      'playlist_media',
      {
        'playlistId': playlistId,
        'mediaPath': mediaPath,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> removeMediaFromPlaylist(int playlistId, String mediaPath) async {
    final db = await instance.database;
    return await db.delete(
      'playlist_media',
      where: 'playlistId = ? AND mediaPath = ?',
      whereArgs: [playlistId, mediaPath],
    );
  }

  Future<List<Playlist>> getAllPlaylistsWithMedia() async {
    final db = await instance.database;
    final playlistRows = await db.query(
      'playlists',
      orderBy: 'createdAt DESC',
    );

    final playlists = <Playlist>[];
    for (final row in playlistRows) {
      final playlistId = row['id'] as int;
      final mediaRows = await db.rawQuery(
        '''
        SELECT m.name, m.path, m.isVideo, m.size, m.thumbnailPath, m.originalThumbnailPath
        FROM playlist_media pm
        INNER JOIN media m ON m.path = pm.mediaPath
        WHERE pm.playlistId = ?
        ORDER BY m.name COLLATE NOCASE
        ''',
        [playlistId],
      );

      playlists.add(
        Playlist(
          id: playlistId,
          name: row['name'] as String,
          createdAt: DateTime.tryParse(row['createdAt'] as String? ?? '') ?? DateTime.now(),
          items: mediaRows
              .map(
                (json) => MediaFile(
                  name: json['name'] as String,
                  path: json['path'] as String,
                  isVideo: (json['isVideo'] as int) == 1,
                  size: json['size'] as String,
                  thumbnailPath: json['thumbnailPath'] as String?,
                  originalThumbnailPath: json['originalThumbnailPath'] as String?,
                ),
              )
              .toList(),
        ),
      );
    }

    return playlists;
  }
}
