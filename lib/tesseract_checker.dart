import 'dart:io';
import 'package:logging/logging.dart';

class TesseractChecker {
  final _logger = Logger('TesseractChecker');

  /// Checks if Tesseract OCR is installed and returns the version if available
  Future<bool> isTesseractInstalled() async {
    try {
      final result = await Process.run('tesseract', ['--version']);

      if (result.exitCode == 0) {
        _logger.info('Tesseract is installed: ${result.stdout}');
        return true;
      } else {
        _logger.severe('Tesseract not properly installed: ${result.stderr}');
        return false;
      }
    } catch (e) {
      _logger.severe('Error checking Tesseract installation: $e');
      return false;
    }
  }

  /// Verifies if a specific language traineddata file is accessible
  Future<bool> verifyLanguageAvailability(
      String languageCode, String tessdataDir) async {
    try {
      final result = await Process.run('tesseract', [
        '--list-langs',
        '--tessdata-dir',
        tessdataDir,
      ]);

      final output = result.stdout as String;
      _logger.info('Available languages: $output');

      return output.split('\n').any((lang) => lang.trim() == languageCode);
    } catch (e) {
      _logger.severe('Error checking language availability: $e');
      return false;
    }
  }
}
