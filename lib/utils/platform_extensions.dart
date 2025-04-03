import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Extension methods for Platform to make code more readable
extension PlatformExtensions on Platform {
  /// Check if the app is running on a desktop platform
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Check if the app is running on a mobile platform
  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }
}
