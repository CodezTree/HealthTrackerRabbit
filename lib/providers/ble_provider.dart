import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ble_service.dart';

final bleServiceProvider = Provider<BleService>((ref) {
  return BleService(ref); // ref를 BleService에 넘겨줌
});
