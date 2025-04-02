// Stub file for web compatibility

class Permission {
  static const camera = Permission._('camera');
  static const storage = Permission._('storage');
  static const photos = Permission._('photos');

  // Store name and use it in toString to make the field used
  final String _name;
  const Permission._(this._name);

  @override
  String toString() => 'Permission($_name)';

  Future<PermissionStatus> get status async => PermissionStatus._granted;
}

class PermissionStatus {
  static const _granted = PermissionStatus._('granted');

  // Store name and use it in toString to make the field used
  final String _name;
  const PermissionStatus._(this._name);

  @override
  String toString() => 'PermissionStatus($_name)';

  bool get isGranted => this == PermissionStatus._granted;
}

typedef PermissionWithService = Permission;
