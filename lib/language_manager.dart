import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:ocrme/ocr_processor.dart';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';
import 'database_helper.dart';
import 'language_util.dart';

class LanguageManager {
  final _logger = Logger('LanguageManager');
  late String _tessdataDir;
  final _dbHelper = DatabaseHelper();
  bool _isInitialized = false;

  // Base URL for tessdata files (using tessdata_fast from tesseract-ocr GitHub)
  static const String _baseUrl =
      'https://github.com/tesseract-ocr/tessdata_fast/raw/main/';

  Future<void> initialize(String tessdataDir) async {
    _tessdataDir = tessdataDir;
    try {
      // Sync the database with the current state of bundled languages
      await _syncBundledLanguages();
      await _updateBundledLanguagesSizes();
      _isInitialized = true;
    } catch (e) {
      _logger.severe('Error initializing language manager: $e');
      // Continue with _isInitialized = false
    }
  }

  // Sync the database with the current bundled languages list
  Future<void> _syncBundledLanguages() async {
    try {
      final db = await _dbHelper.database;

      // Get all languages currently marked as bundled in the database
      final bundledInDB = await db.query(
        'languages',
        columns: ['code'],
        where: 'is_bundled = 1',
      );

      final bundledCodesInDB =
          bundledInDB.map((e) => e['code'] as String).toList();

      // For languages that were previously bundled but no longer are,
      // update their status in the database to remove them completely
      for (final code in bundledCodesInDB) {
        if (!OcrProcessor.bundledLanguages.contains(code)) {
          // If not in current bundled list, delete from database
          await db.delete(
            'languages',
            where: 'code = ? AND is_bundled = 1 AND is_installed = 0',
            whereArgs: [code],
          );

          // Update any remaining entries
          await db.update(
            'languages',
            {'is_bundled': 0},
            where: 'code = ?',
            whereArgs: [code],
          );

          _logger.info('Cleaned up obsolete bundled language: $code');
        }
      }
    } catch (e) {
      _logger.warning('Error syncing bundled languages: $e');
    }
  }

  // Make the sync method public so it can be called from outside
  Future<void> syncBundledLanguages() async {
    await _syncBundledLanguages();
  }

  // Update the file sizes of bundled languages
  Future<void> _updateBundledLanguagesSizes() async {
    for (final langCode in OcrProcessor.bundledLanguages) {
      final file = File(path.join(_tessdataDir, '$langCode.traineddata'));
      if (await file.exists()) {
        int size = await file.length();
        String name = LanguageUtil.getDisplayName(langCode);

        await _dbHelper.addOrUpdateLanguage(
          code: langCode,
          name: name,
          size: size,
          isBundled: true,
        );
      }
    }
  }

  /// Check if a language file exists locally
  Future<bool> isLanguageAvailable(String languageCode) async {
    // First check if it's a bundled language
    if (OcrProcessor.bundledLanguages.contains(languageCode)) {
      return true;
    }

    // If database initialization failed, check file system directly
    if (!_isInitialized) {
      final file = File(path.join(_tessdataDir, '$languageCode.traineddata'));
      return await file.exists();
    }

    try {
      // Otherwise check database
      bool inDatabase = await _dbHelper.isLanguageDownloaded(languageCode);
      if (inDatabase) {
        // Verify the file actually exists
        final file = File(path.join(_tessdataDir, '$languageCode.traineddata'));
        final exists = await file.exists();

        if (!exists) {
          _logger.warning(
              'Language $languageCode is in database but file not found');
        }

        return exists;
      }
      return false;
    } catch (e) {
      _logger.warning('Database error, falling back to file check: $e');
      final file = File(path.join(_tessdataDir, '$languageCode.traineddata'));
      return await file.exists();
    }
  }

  /// Mark a language as available in database
  Future<void> markLanguageAsAvailable(String languageCode) async {
    final file = File(path.join(_tessdataDir, '$languageCode.traineddata'));
    if (await file.exists()) {
      int size = await file.length();
      String name = LanguageUtil.getDisplayName(languageCode);

      await _dbHelper.addOrUpdateLanguage(
        code: languageCode,
        name: name,
        size: size,
        isBundled: OcrProcessor.bundledLanguages.contains(languageCode),
      );
    }
  }

  /// Download a language file from GitHub
  Future<bool> downloadLanguage(String languageCode,
      {Function(double)? onProgress}) async {
    final url = '$_baseUrl$languageCode.traineddata';
    final file = File(path.join(_tessdataDir, '$languageCode.traineddata'));

    _logger.info('Downloading language $languageCode from $url');

    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      if (response.statusCode == 200) {
        // Create tessdata directory if it doesn't exist
        final directory = Directory(_tessdataDir);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        // Get total file size for progress tracking
        final totalBytes = response.contentLength ?? 0;
        var downloadedBytes = 0;

        // Open file for writing
        final fileStream = file.openWrite();

        // Stream the download with progress updates
        await response.stream.listen((chunk) {
          fileStream.add(chunk);
          downloadedBytes += chunk.length;

          if (totalBytes > 0 && onProgress != null) {
            final progress = downloadedBytes / totalBytes;
            onProgress(progress);
          }
        }).asFuture();

        // Close file
        await fileStream.close();

        // Get file size and add to database
        int fileSize = await file.length();
        String name = LanguageUtil.getDisplayName(languageCode);

        await _dbHelper.addOrUpdateLanguage(
          code: languageCode,
          name: name,
          size: fileSize,
          isBundled: false,
        );

        _logger.info('Language $languageCode downloaded successfully');
        return true;
      } else {
        _logger.severe(
            'Failed to download language $languageCode. Status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _logger.severe('Error downloading language $languageCode: $e');
      return false;
    }
  }

  /// Get a list of all available languages
  Future<List<Map<String, dynamic>>> getAvailableLanguages() async {
    try {
      return await _dbHelper.getLanguages();
    } catch (e) {
      _logger.warning('Database error while fetching languages: $e');
      return [];
    }
  }

  /// Delete any language file (bundled or downloaded)
  Future<bool> deleteLanguage(String languageCode) async {
    try {
      final file = File(path.join(_tessdataDir, '$languageCode.traineddata'));
      if (await file.exists()) {
        await file.delete();
        _logger.info('Deleted language file for $languageCode');
      }

      // Update database to mark as not available
      await _dbHelper.removeLanguage(languageCode);

      // For bundled languages, we just mark them as not available
      // rather than actually removing from the database
      if (OcrProcessor.bundledLanguages.contains(languageCode)) {
        await _dbHelper.markLanguageAsRemoved(languageCode);
        _logger.info('Marked bundled language $languageCode as removed');
      }

      return true;
    } catch (e) {
      _logger.severe('Error deleting language $languageCode: $e');
      return false;
    }
  }

  /// Check if a bundled language is currently installed
  Future<bool> isBundledLanguageInstalled(String languageCode) async {
    if (!OcrProcessor.bundledLanguages.contains(languageCode)) {
      return false; // Not a bundled language
    }

    try {
      final file = File(path.join(_tessdataDir, '$languageCode.traineddata'));
      return await file.exists();
    } catch (e) {
      _logger.warning('Error checking bundled language file: $e');
      return false;
    }
  }

  /// Install or reinstall a bundled language
  Future<bool> installBundledLanguage(String languageCode,
      {Function(double)? onProgress}) async {
    if (!OcrProcessor.bundledLanguages.contains(languageCode)) {
      _logger.warning(
          'Attempted to install non-bundled language as bundled: $languageCode');
      return false;
    }

    // For bundled languages, we attempt to download from the internet
    // since we want to allow users to reinstall them if deleted
    return await downloadLanguage(languageCode, onProgress: onProgress);
  }

  /// Get total storage used by language files
  Future<String> getStorageUsage() async {
    try {
      int bytes = await _dbHelper.getTotalStorageUsed();

      // Convert to human-readable format
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (e) {
      _logger.warning('Database error while calculating storage usage: $e');
      return 'Unknown';
    }
  }

  /// Check if a language has been marked as removed by the user
  Future<bool> isLanguageMarkedAsRemoved(String languageCode) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'languages',
        columns: ['is_installed'],
        where: 'code = ?',
        whereArgs: [languageCode],
        limit: 1,
      );

      if (result.isEmpty) {
        return false; // No record found, so not marked as removed
      }

      return result.first['is_installed'] == 0; // 0 means removed
    } catch (e) {
      _logger.warning('Error checking if language is marked as removed: $e');
      return false; // Default to false if there's an error
    }
  }

  /// Clean up database and remove orphaned files
  Future<Map<String, dynamic>> cleanupStorage() async {
    try {
      // Pass tessdata directory to db helper for cleanup
      _dbHelper.setTessdataDir(_tessdataDir); // Use the public method
      final result = await _dbHelper.cleanupDatabase();

      // Get updated storage usage
      final newStorageSize = await getStorageUsage();

      return {
        'success': true,
        'filesRemoved': result.filesRemoved,
        'entriesRemoved': result.entriesRemoved,
        'spaceFreed': result.formattedBytesFreed,
        'currentSize': newStorageSize,
      };
    } catch (e) {
      _logger.severe('Error cleaning up storage: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
