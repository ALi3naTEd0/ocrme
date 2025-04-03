// Stub file for web compatibility

class Permission {
  static const camera = Permission._('camera');
  static const storage = Permission._('storage');
  static const photos = Permission._('photos');
  // Add external storage permission for Android
  static const manageExternalStorage = Permission._('manageExternalStorage');

  // Store name and use it in toString to make the field used
  final String _name;
  const Permission._(this._name);

  @override
  String toString() => 'Permission($_name)';

  Future<PermissionStatus> get status async => PermissionStatus._granted;
  
  // Add request method for better API compatibility
  Future<PermissionStatus> request() async => PermissionStatus._granted;
}

class PermissionStatus {
  static const _granted = PermissionStatus._('granted');
  static const _denied = PermissionStatus._('denied');
  static const _permanentlyDenied = PermissionStatus._('permanentlyDenied');

  // Store name and use it in toString to make the field used
  final String _name;
  const PermissionStatus._(this._name);

  @override
  String toString() => 'PermissionStatus($_name)';

  bool get isGranted => this == PermissionStatus._granted;
  bool get isDenied => this == PermissionStatus._denied;
  bool get isPermanentlyDenied => this == PermissionStatus._permanentlyDenied;
}

typedef PermissionWithService = Permission;
