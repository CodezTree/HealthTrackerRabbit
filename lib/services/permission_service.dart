import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> requestBlePermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }
}
