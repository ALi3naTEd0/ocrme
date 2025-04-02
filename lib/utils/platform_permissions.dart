import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';

// Conditionally import permission_handler to avoid build issues
import 'package:permission_handler/permission_handler.dart'
    if (dart.library.html) 'platform_permissions_web.dart'
    if (dart.library.io) 'package:permission_handler/permission_handler.dart';

class PlatformPermissions {
  static final _logger = Logger('PlatformPermissions');

  /// Request necessary app permissions based on the platform
  static Future<Map<Permission, PermissionStatus>> requestPermissions() async {
    try {
      // Only request permissions on Android/iOS
      if (kIsWeb || !Platform.isAndroid && !Platform.isIOS) {
        _logger.info(
            'Platform ${kIsWeb ? "Web" : Platform.operatingSystem} doesn\'t need explicit permissions');
        return {};
      }

      if (Platform.isAndroid) {
        // Request Android permissions
        return await [
          Permission.camera,
          Permission.storage,
          Permission.photos,
        ].request();
      } else if (Platform.isIOS) {
        // Request iOS permissions
        return await [
          Permission.camera,
          Permission.photos,
        ].request();
      }
    } catch (e) {
      _logger.severe('Error requesting permissions: $e');
    }

    return {};
  }

  /// Check if we have specific permission
  static Future<bool> hasPermission(Permission permission) async {
    try {
      if (kIsWeb || !Platform.isAndroid && !Platform.isIOS) {
        return true;
      }

      final status = await permission.status;
      return status.isGranted;
    } catch (e) {
      _logger.warning('Error checking permission status: $e');
      return false;
    }
  }
}
