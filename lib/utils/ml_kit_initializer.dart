import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Helper class to properly initialize ML Kit for the platform
class MLKitInitializer {
  static final _logger = Logger('MLKitInitializer');
  static bool _initialized = false;

  /// Initialize ML Kit libraries - call this at app startup
  static Future<bool> initializeMLKit() async {
    if (_initialized) {
      return true;
    }

    try {
      if (!kIsWeb && Platform.isAndroid) {
        _logger.info('Initializing ML Kit for Android');

        // Additional Android-specific ML Kit initialization could go here
        // Currently not needed as we're using the default initialization

        _initialized = true;
        _logger.info('ML Kit initialized successfully');
        return true;
      } else if (!kIsWeb && Platform.isIOS) {
        _logger.info('Initializing ML Kit for iOS');
        // iOS-specific initialization if needed
        _initialized = true;
        return true;
      } else {
        // No special initialization needed for other platforms
        _initialized = true;
        return true;
      }
    } catch (e) {
      _logger.severe('Error initializing ML Kit: $e');
      return false;
    }
  }
}
