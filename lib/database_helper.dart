import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  final _logger = Logger('DatabaseHelper');

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  static Database? _database;
  String? _tessdataDir;

  // Getter for the database singleton
  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  // Initialize the database
  Future<Database> _initDatabase() async {
    // Initialize FFI for desktop platforms
    if (!kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Get the database directory
    final documentsDirectory = await getApplicationSupportDirectory();
    final path = join(documentsDirectory.path, 'ocr_languages.db');

    // Open/create the database
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Create database tables
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE languages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE,
        name TEXT,
        size INTEGER DEFAULT 0,
        is_installed INTEGER DEFAULT 1,
        is_bundled INTEGER DEFAULT 0,
        downloaded_date INTEGER DEFAULT 0
      )
    ''');

    _logger.info('Database created successfully');
  }

  // Add or update a language in the database
  Future<void> addOrUpdateLanguage({
    required String code,
    required String name,
    required int size,
    bool isBundled = false,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      // Check if language exists
      final exists = await db.query(
        'languages',
        where: 'code = ?',
        whereArgs: [code],
      );

      if (exists.isEmpty) {
        // Insert new language
        await db.insert('languages', {
          'code': code,
          'name': name,
          'size': size,
          'is_installed': 1,
          'is_bundled': isBundled ? 1 : 0,
          'downloaded_date': now,
        });
        _logger.info('Added new language: $code');
      } else {
        // Update existing language
        await db.update(
          'languages',
          {
            'name': name,
            'size': size,
            'is_installed': 1,
            'is_bundled': isBundled ? 1 : 0,
            'downloaded_date': now,
          },
          where: 'code = ?',
          whereArgs: [code],
        );
        _logger.info('Updated language: $code');
      }
    } catch (e) {
      _logger.severe('Error adding/updating language $code: $e');
    }
  }

  // Check if a language is marked as downloaded in the database
  Future<bool> isLanguageDownloaded(String code) async {
    final db = await database;

    try {
      final result = await db.query(
        'languages',
        columns: ['is_installed'],
        where: 'code = ?',
        whereArgs: [code],
      );

      if (result.isEmpty) return false;
      return result.first['is_installed'] == 1;
    } catch (e) {
      _logger.warning('Error checking if language $code is downloaded: $e');
      return false;
    }
  }

  // Get all languages from the database
  Future<List<Map<String, dynamic>>> getLanguages() async {
    final db = await database;

    try {
      return await db.query('languages', orderBy: 'name ASC');
    } catch (e) {
      _logger.severe('Error getting languages: $e');
      return [];
    }
  }

  // Remove a language from the database
  Future<void> removeLanguage(String code) async {
    final db = await database;

    try {
      await db.update(
        'languages',
        {'is_installed': 0},
        where: 'code = ?',
        whereArgs: [code],
      );
      _logger.info('Removed language: $code');
    } catch (e) {
      _logger.severe('Error removing language $code: $e');
    }
  }

  // Mark a bundled language as removed
  Future<void> markLanguageAsRemoved(String code) async {
    final db = await database;

    try {
      await db.update(
        'languages',
        {'is_installed': 0},
        where: 'code = ?',
        whereArgs: [code],
      );
      _logger.info('Marked language as removed: $code');
    } catch (e) {
      _logger.severe('Error marking language $code as removed: $e');
    }
  }

  // Get total storage used by all languages
  Future<int> getTotalStorageUsed() async {
    final db = await database;

    try {
      final result = await db.rawQuery(
          'SELECT SUM(size) as total FROM languages WHERE is_installed = 1');

      if (result.isEmpty || result.first['total'] == null) {
        return 0;
      }

      return result.first['total'] as int;
    } catch (e) {
      _logger.severe('Error calculating storage: $e');
      return 0;
    }
  }

  // Set the tessdata directory
  void setTessdataDir(String dir) {
    _tessdataDir = dir;
  }

  // Clean up database and remove orphaned files
  Future<CleanupResult> cleanupDatabase() async {
    if (_tessdataDir == null) {
      _logger.warning('Tessdata directory not set, cannot clean up');
      throw Exception('Tessdata directory not set');
    }

    final db = await database;
    int filesRemoved = 0;
    int entriesRemoved = 0;
    int bytesFreed = 0;

    try {
      // Get all language files in the tessdata directory
      final dir = Directory(_tessdataDir!);
      if (!await dir.exists()) {
        _logger.warning('Tessdata directory does not exist');
        return CleanupResult(0, 0, '0 B', 0);
      }

      // Get files from filesystem
      final files = await dir.list().toList();
      final trainedDataFiles = files
          .whereType<File>()
          .where((file) => file.path.endsWith('.traineddata'))
          .toList();

      // Get languages from database
      final dbLanguages =
          await db.query('languages', columns: ['code', 'is_installed']);

      // Find orphaned files (files without database entries)
      for (var file in trainedDataFiles) {
        final fileName = file.path.split('/').last;
        final langCode = fileName.replaceAll('.traineddata', '');

        final dbEntry = dbLanguages.firstWhere(
          (entry) => entry['code'] == langCode,
          orElse: () => {'code': langCode, 'is_installed': 0},
        );

        // If not in database or marked as not installed, delete the file
        if (dbEntry['is_installed'] == 0) {
          final fileSize = await file.length();
          await file.delete();
          bytesFreed += fileSize;
          filesRemoved++;
          _logger.info('Deleted orphaned file: ${file.path}');
        }
      }

      // Clean up database entries without files
      for (var lang in dbLanguages) {
        final langCode = lang['code'] as String;
        final file = File('${_tessdataDir!}/$langCode.traineddata');

        if (!await file.exists() && lang['is_installed'] == 1) {
          await db.update(
            'languages',
            {'is_installed': 0},
            where: 'code = ?',
            whereArgs: [langCode],
          );
          entriesRemoved++;
          _logger.info('Updated database entry for missing file: $langCode');
        }
      }

      // Format bytes freed
      String formattedBytesFreed;
      if (bytesFreed < 1024) {
        formattedBytesFreed = '$bytesFreed B';
      } else if (bytesFreed < 1024 * 1024) {
        formattedBytesFreed = '${(bytesFreed / 1024).toStringAsFixed(1)} KB';
      } else {
        formattedBytesFreed =
            '${(bytesFreed / (1024 * 1024)).toStringAsFixed(1)} MB';
      }

      return CleanupResult(
          filesRemoved, entriesRemoved, formattedBytesFreed, bytesFreed);
    } catch (e) {
      _logger.severe('Error during cleanup: $e');
      throw Exception('Error during cleanup: $e');
    }
  }
}

class CleanupResult {
  final int filesRemoved;
  final int entriesRemoved;
  final String formattedBytesFreed;
  final int bytesFreed;

  CleanupResult(this.filesRemoved, this.entriesRemoved,
      this.formattedBytesFreed, this.bytesFreed);
}
