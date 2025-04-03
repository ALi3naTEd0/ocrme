import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';
import 'package:device_info_plus/device_info_plus.dart';

// Conditionally import permission_handler to avoid build issues
import 'package:permission_handler/permission_handler.dart'
    if (dart.library.html) 'platform_permissions_web.dart'
    if (dart.library.io) 'package:permission_handler/permission_handler.dart';

class PlatformPermissions {
  static final _logger = Logger('PlatformPermissions');
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

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
        final permissions = await [
          Permission.camera,
          Permission.storage,
          Permission.photos,
          // On Android 11+, we need to request special permissions in a different way
          if (Platform.isAndroid && await _isAndroid11OrHigher())
            Permission.manageExternalStorage,
        ].request();

        // Log granted permissions
        permissions.forEach((permission, status) {
          _logger.info(
              'Permission $permission: ${status.isGranted ? 'granted' : 'denied'}');
        });

        return permissions;
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

  /// Check if running on Android 11 or higher
  static Future<bool> _isAndroid11OrHigher() async {
    if (!Platform.isAndroid) return false;

    try {
      // Android 11 is API level 30
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      return androidInfo.version.sdkInt >= 30;
    } catch (e) {
      _logger.warning('Error checking Android version: $e');
      return false;
    }
  }
}
