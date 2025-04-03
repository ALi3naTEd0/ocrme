import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';
import 'package:ocrme/android_tesseract.dart';

enum OcrImplementation { commandLine, androidNative, web }

class PlatformOcrFactory {
  static final _logger = Logger('PlatformOcrFactory');

  static OcrImplementation getPreferredImplementation() {
    if (kIsWeb) {
      return OcrImplementation.web;
    } else if (Platform.isAndroid) {
      return OcrImplementation.androidNative;
    } else {
      return OcrImplementation.commandLine;
    }
  }

  static Future<bool> setupOcrForPlatform() async {
    try {
      final implementation = getPreferredImplementation();

      _logger.info('Setting up OCR for implementation: $implementation');

      switch (implementation) {
        case OcrImplementation.androidNative:
          return await AndroidTesseract.installTesseractFastModel();

        case OcrImplementation.commandLine:
          // No setup needed for command line
          return true;

        case OcrImplementation.web:
          // Web implementation not needed
          return true;
      }
    } catch (e) {
      _logger.severe('Error setting up OCR for platform: $e');
      return false;
    }
  }
}
