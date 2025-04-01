import 'dart:io';
import 'package:ocrme/ocr_processor.dart';
import 'package:path/path.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logging/logging.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  final _logger = Logger('DatabaseHelper');
  static Database? _database;

  String? _tessdataDir;

  // Make the setter public (remove underscore)
  void setTessdataDir(String dir) {
    _tessdataDir = dir;
  }

  String _getTessdataDir() {
    // Return the directory set by language manager or a fallback
    return _tessdataDir ?? '${Directory.systemTemp.path}/tessdata';
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String dbPath = join(documentsDirectory.path, "ocrme.db");
      _logger.info('Database path: $dbPath');

      return await openDatabase(
        dbPath,
        version: 1,
        onCreate: _createDB,
        onOpen: (db) async {
          _logger.info('Database opened successfully');
          await updateSchema(db);
        },
      );
    } catch (e) {
      _logger.severe('Failed to initialize database: $e');
      rethrow;
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE languages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE,
        name TEXT,
        size INTEGER,
        downloaded_date INTEGER,
        is_bundled INTEGER,
        is_installed INTEGER DEFAULT 1
      )
    ''');

    _logger.info('Database created with languages table');

    // Insert bundled languages
    await insertBundledLanguages(db);
  }

  Future<void> updateSchema(Database db) async {
    // Check if is_installed column exists, add if not
    var tableInfo = await db.rawQuery('PRAGMA table_info(languages)');
    bool hasInstalledColumn =
        tableInfo.any((column) => column['name'] == 'is_installed');

    if (!hasInstalledColumn) {
      await db.execute(
          'ALTER TABLE languages ADD COLUMN is_installed INTEGER DEFAULT 1');
      _logger.info('Added is_installed column to languages table');
    }
  }

  Future insertBundledLanguages(Database db) async {
    final bundledLanguages = [
      {'code': 'eng', 'name': 'English'},
      {'code': 'spa', 'name': 'Spanish'},
    ];

    final batch = db.batch();
    for (var lang in bundledLanguages) {
      batch.insert(
        'languages',
        {
          'code': lang['code'],
          'name': lang['name'],
          'size': 0, // Will be updated when we get actual file size
          'downloaded_date': DateTime.now().millisecondsSinceEpoch,
          'is_bundled': 1,
          'is_installed': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
    _logger.info('Bundled languages inserted into database');
  }

  Future<void> addOrUpdateLanguage({
    required String code,
    required String name,
    required int size,
    required bool isBundled,
  }) async {
    final db = await database;

    await db.insert(
      'languages',
      {
        'code': code,
        'name': name,
        'size': size,
        'downloaded_date': DateTime.now().millisecondsSinceEpoch,
        'is_bundled': isBundled ? 1 : 0,
        'is_installed': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    _logger.info('Added/updated language $code in database');
  }

  Future<List<Map<String, dynamic>>> getLanguages() async {
    try {
      final db = await database;
      final languages =
          await db.query('languages', orderBy: 'downloaded_date DESC');

      // Get current bundled languages
      const currentBundledLanguages = OcrProcessor.bundledLanguages;

      // Filter languages to only show:
      // 1. Currently bundled languages (eng, spa)
      // 2. Non-bundled languages that have been downloaded
      // 3. Skip previously bundled languages that are no longer bundled
      return languages.where((lang) {
        final code = lang['code'] as String;
        final isBundled = lang['is_bundled'] == 1;
        final isInstalled = lang['is_installed'] == 1;

        // If it's currently bundled, show it
        if (currentBundledLanguages.contains(code)) {
          return true;
        }

        // If it's a downloaded non-bundled language and installed, show it
        if (!isBundled && isInstalled) {
          return true;
        }

        // If it was previously bundled but is now marked as not installed, don't show it
        if (isBundled && !isInstalled) {
          return false;
        }

        // Catch-all for previously bundled languages that are no longer bundled
        if (isBundled && !currentBundledLanguages.contains(code)) {
          return false;
        }

        return isInstalled; // Only show installed languages
      }).toList();
    } catch (e) {
      _logger.warning('Error getting languages: $e');
      // Return default bundled languages as fallback
      return [
        {
          'code': 'eng',
          'name': 'English',
          'size': 1024 * 1024 * 3, // Approximate size
          'downloaded_date': DateTime.now().millisecondsSinceEpoch,
          'is_bundled': 1,
          'is_installed': 1,
        },
        {
          'code': 'spa',
          'name': 'Spanish',
          'size': 1024 * 1024 * 3, // Approximate size
          'downloaded_date': DateTime.now().millisecondsSinceEpoch,
          'is_bundled': 1,
          'is_installed': 1,
        },
      ];
    }
  }

  Future<bool> isLanguageDownloaded(String code) async {
    try {
      final db = await database;
      final result = await db.query(
        'languages',
        where: 'code = ? AND is_installed = 1',
        whereArgs: [code],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      _logger.warning('Error checking if language is downloaded: $e');
      // Default to checking if language is in bundled languages
      return code == 'eng' || code == 'spa';
    }
  }

  Future<void> removeLanguage(String code) async {
    try {
      final db = await database;

      // For non-bundled languages, delete the entry
      await db.delete(
        'languages',
        where: 'code = ? AND is_bundled = 0',
        whereArgs: [code],
      );

      // For bundled languages, update the is_installed flag
      await db.update(
        'languages',
        {'is_installed': 0},
        where: 'code = ? AND is_bundled = 1',
        whereArgs: [code],
      );

      _logger.info('Removed or marked language $code as uninstalled');
    } catch (e) {
      _logger.warning('Error removing language: $e');
    }
  }

  Future<void> markLanguageAsRemoved(String code) async {
    try {
      final db = await database;
      await db.update(
        'languages',
        {'is_installed': 0},
        where: 'code = ?',
        whereArgs: [code],
      );
      _logger.info('Marked language $code as removed');
    } catch (e) {
      _logger.warning('Error marking language as removed: $e');
    }
  }

  Future<int> getTotalStorageUsed() async {
    try {
      final db = await database;
      final result =
          await db.rawQuery('SELECT SUM(size) as total FROM languages');
      return result.first['total'] as int? ?? 0;
    } catch (e) {
      _logger.warning('Error getting total storage used: $e');
      return 0; // Safe fallback
    }
  }

  /// Clean up database and remove orphaned language files
  Future<CleanupResult> cleanupDatabase() async {
    final result = CleanupResult();
    try {
      final db = await database;

      // First, get list of all language files on disk
      if (await Directory(_getTessdataDir()).exists()) {
        final dir = Directory(_getTessdataDir());
        final List<FileSystemEntity> files = await dir.list().toList();

        // Filter for .traineddata files
        final languageFiles = files
            .whereType<File>()
            .where((file) => file.path.endsWith('.traineddata'))
            .toList();

        // Get current languages from database
        final dbLanguages = await db.query(
          'languages',
          columns: ['code'],
          where: 'is_installed = 1', // Only active languages
        );

        final dbLanguageCodes =
            dbLanguages.map((lang) => '${lang['code']}.traineddata').toList();

        // Find files on disk that aren't in the database
        int bytesFreed = 0;
        int filesRemoved = 0;
        for (var file in languageFiles) {
          final fileName = path.basename(file.path);

          // Keep bundled languages
          if (OcrProcessor.bundledLanguages
              .any((lang) => fileName == '$lang.traineddata')) {
            continue;
          }

          // If not in active database entries, delete it
          if (!dbLanguageCodes.contains(fileName)) {
            final size = await File(file.path).length();
            await File(file.path).delete();
            bytesFreed += size;
            filesRemoved++;
            _logger.info(
                'Removed orphaned file: $fileName (${_formatSize(size)})');
          }
        }

        result.filesRemoved = filesRemoved;
        result.bytesFreed = bytesFreed;

        // Clean up database entries for languages without files
        final removedCount = await db.delete(
          'languages',
          where: 'is_bundled = 0 AND is_installed = 0',
        );

        result.entriesRemoved = removedCount;
        _logger.info('Removed $removedCount obsolete database entries');

        // Vacuum database to reclaim space
        await db.execute('VACUUM');
        _logger.info('Database vacuumed');
      }

      return result;
    } catch (e) {
      _logger.severe('Error cleaning up database: $e');
      return result;
    }
  }

  /// Format file size for human readability
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Class to hold results of cleanup operation
class CleanupResult {
  int filesRemoved = 0;
  int bytesFreed = 0;
  int entriesRemoved = 0;

  String get formattedBytesFreed {
    if (bytesFreed < 1024) return '$bytesFreed B';
    if (bytesFreed < 1024 * 1024) {
      return '${(bytesFreed / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytesFreed / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
