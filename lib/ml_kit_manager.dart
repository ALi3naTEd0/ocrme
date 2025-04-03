import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:logging/logging.dart';

/// Manages ML Kit functionality and language support
class MLKitManager {
  static final _logger = Logger('MLKitManager');
  static final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Get the list of supported languages for ML Kit
  static List<String> getSupportedLanguages() {
    // ML Kit automatically detects language for Latin-based scripts
    // It doesn't require specific language files like Tesseract does
    return [
      'eng', // English
      'spa', // Spanish
      'fra', // French
      'deu', // German
      'ita', // Italian
      'por', // Portuguese
      'nld', // Dutch
      'dan', // Danish
      'fin', // Finnish
      'nor', // Norwegian
      'swe', // Swedish
    ];
  }

  /// Check if ML Kit supports a particular language
  static bool isLanguageSupported(String languageCode) {
    return getSupportedLanguages().contains(languageCode);
  }

  /// Check if ML Kit is available on this platform
  static bool isMLKitAvailable() {
    // ML Kit is only available on Android and iOS
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Get the platform-specific ML Kit capabilities
  static Map<String, dynamic> getMLKitCapabilities() {
    if (!isMLKitAvailable()) {
      return {
        'available': false,
        'reason': 'ML Kit is only available on Android and iOS',
        'latinScript': false,
        'chineseScript': false,
        'japaneseScript': false,
        'koreanScript': false,
        'devanagariScript': false,
      };
    }

    return {
      'available': true,
      'latinScript': true, // Available on all ML Kit platforms
      'chineseScript': true, // Available on all ML Kit platforms
      'japaneseScript': true, // Available on all ML Kit platforms
      'koreanScript': true, // Available on all ML Kit platforms
      'devanagariScript': true, // Available on all ML Kit platforms
    };
  }

  /// Process an image with ML Kit text recognition
  static Future<Map<String, dynamic>> processImage(
      String imagePath, String language) async {
    if (!isMLKitAvailable()) {
      return {
        'text': 'ML Kit is not available on this platform.',
        'success': false,
      };
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _recognizer.processImage(inputImage);

      return {
        'text': recognizedText.text,
        'success': true,
        'blocks': recognizedText.blocks.length,
      };
    } catch (e) {
      _logger.severe('Error processing image with ML Kit: $e');
      return {
        'text': 'Error processing image: $e',
        'success': false,
      };
    }
  }

  /// Clean up ML Kit resources
  static Future<void> dispose() async {
    await _recognizer.close();
  }
}
