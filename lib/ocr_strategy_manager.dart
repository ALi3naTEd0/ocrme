import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:ocrme/tesseract_checker.dart';
import 'ml_kit_manager.dart';

/// Manages OCR strategy selection across platforms
class OcrStrategyManager {
  static final _logger = Logger('OcrStrategyManager');
  static bool? _tesseractAvailable;

  /// Get the best OCR strategy for the current platform
  static Future<Map<String, dynamic>> getBestStrategy() async {
    if (kIsWeb) {
      return {
        'engine': 'web',
        'supportsMultipleLanguages': false,
        'defaultLanguage': 'eng',
        'availableLanguages': ['eng'],
      };
    }

    if (Platform.isAndroid || Platform.isIOS) {
      // On mobile platforms, prioritize ML Kit
      return {
        'engine': 'ml_kit',
        'supportsMultipleLanguages': true,
        'defaultLanguage': 'eng',
        'availableLanguages': MLKitManager.getSupportedLanguages(),
      };
    }

    // On desktop, check for Tesseract command line availability
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      if (_tesseractAvailable == null) {
        final checker = TesseractChecker();
        _tesseractAvailable = await checker.isTesseractInstalled();
      }

      if (_tesseractAvailable == true) {
        return {
          'engine': 'tesseract_command',
          'supportsMultipleLanguages': true,
          'defaultLanguage': 'eng',
          'availableLanguages': await _getDesktopAvailableLanguages(),
        };
      }

      // Fall back to a basic implementation if Tesseract isn't available
      return {
        'engine': 'basic',
        'supportsMultipleLanguages': false,
        'defaultLanguage': 'eng',
        'availableLanguages': ['eng'],
      };
    }

    // Default fallback for unknown platforms
    return {
      'engine': 'basic',
      'supportsMultipleLanguages': false,
      'defaultLanguage': 'eng',
      'availableLanguages': ['eng'],
    };
  }

  /// Get available languages on desktop
  static Future<List<String>> _getDesktopAvailableLanguages() async {
    try {
      final checker = TesseractChecker();
      if (await checker.isTesseractInstalled()) {
        final result = await Process.run('tesseract', ['--list-langs']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          final languages = output
              .split('\n')
              .where((line) => line.trim().isNotEmpty && !line.contains(':'))
              .toList();

          // Return at least English if the list is empty
          if (languages.isEmpty) {
            return ['eng'];
          }
          return languages;
        }
      }
    } catch (e) {
      _logger.warning('Error getting available languages: $e');
    }

    // Default to English if we can't determine available languages
    return ['eng'];
  }

  /// Check if a specific language is available on the current platform
  static Future<bool> isLanguageAvailable(String languageCode) async {
    final strategy = await getBestStrategy();
    return strategy['availableLanguages'].contains(languageCode);
  }
}
