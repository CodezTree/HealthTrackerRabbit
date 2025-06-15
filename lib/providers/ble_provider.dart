import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ble_service.dart';

final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService(ref); // ref를 BleService에 넘겨줌

  // Provider가 dispose될 때 BLE 연결을 정리합니다.
  ref.onDispose(() {
    service.disconnect(); // dispose는 비동기를 지원하지 않으므로 await 없이 호출
  });

  return service;
});
