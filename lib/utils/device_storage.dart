import 'package:shared_preferences/shared_preferences.dart';

class DeviceStorage {
  static const _keyDeviceId = 'device_id';
  static const _keyDeviceName = 'device_name';

  static Future<void> saveDeviceInfo(String id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeviceId, id);
    await prefs.setString(_keyDeviceName, name);
  }

  static Future<Map<String, String>?> getDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_keyDeviceId);
    final name = prefs.getString(_keyDeviceName);
    if (id != null && name != null) {
      return {'id': id, 'name': name};
    }
    return null;
  }

  static Future<void> clearDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDeviceId);
    await prefs.remove(_keyDeviceName);
  }
}
