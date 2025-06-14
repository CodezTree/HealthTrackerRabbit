import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rabbithole_health_tracker_new/providers/health_provider.dart';
import '../utils/device_storage.dart';
import '../services/background_service.dart';
import 'dart:async';
import 'package:flutter/services.dart';

class BleService {
  final Ref ref;

  BleService(this.ref);

  static const platform = MethodChannel('com.example.sr08_sdk/methods');
  static const eventChannel = EventChannel('com.example.sr08_sdk/events');

  BluetoothDevice? _device;
  StreamSubscription? _dataSubscription;

  bool get isConnected => _device != null;

  Future<bool> tryReconnectFromSavedDevice() async {
    final info = await DeviceStorage.getDeviceInfo();
    if (info == null) return false;

    try {
      await connectToDevice(info['id']!, save: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> connectToDevice(String macAddress, {bool save = true}) async {
    try {
      await platform.invokeMethod('connectDevice', {'macAddress': macAddress});

      if (save) {
        await DeviceStorage.saveDeviceInfo(macAddress, 'SR08');
      }

      // 연결 성공 후 데이터 수신 리스너 설정
      _setupDataListener();

      await BackgroundService.registerPeriodicTask();
    } catch (e) {
      print('Failed to connect: $e');
      rethrow;
    }
  }

  void _setupDataListener() {
    _dataSubscription?.cancel();
    _dataSubscription = eventChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is Map) {
          final type = data['type'] as String;
          final value = data['value'] as int;

          final healthData = ref.read(healthDataProvider.notifier);
          final latest = ref.read(healthDataProvider).latest;

          switch (type) {
            case 'heart':
              healthData.updateHealthData(
                heartRate: value,
                spo2: latest?.spo2 ?? 0,
                stepCount: latest?.stepCount ?? 0,
                battery: latest?.battery ?? 100,
                chargingState: latest?.chargingState ?? 0,
                sleepHours: latest?.sleepHours ?? 0,
                sportsTime: latest?.sportsTime ?? 0,
                screenStatus: latest?.screenStatus ?? 0,
              );
              break;
            case 'oxygen':
              healthData.updateHealthData(
                heartRate: latest?.heartRate ?? 0,
                spo2: value,
                stepCount: latest?.stepCount ?? 0,
                battery: latest?.battery ?? 100,
                chargingState: latest?.chargingState ?? 0,
                sleepHours: latest?.sleepHours ?? 0,
                sportsTime: latest?.sportsTime ?? 0,
                screenStatus: latest?.screenStatus ?? 0,
              );
              break;
            case 'steps':
              healthData.updateHealthData(
                heartRate: latest?.heartRate ?? 0,
                spo2: latest?.spo2 ?? 0,
                stepCount: value,
                battery: latest?.battery ?? 100,
                chargingState: latest?.chargingState ?? 0,
                sleepHours: latest?.sleepHours ?? 0,
                sportsTime: latest?.sportsTime ?? 0,
                screenStatus: latest?.screenStatus ?? 0,
              );
              break;
          }
        }
      },
      onError: (error) {
        print('Error receiving data: $error');
      },
    );
  }

  Future<void> startHealthMonitoring() async {
    try {
      await platform.invokeMethod('startHealthMonitoring');
      // 백그라운드 서비스 시작
      await platform.invokeMethod('startBackgroundService');
    } catch (e) {
      print('Failed to start health monitoring: $e');
      rethrow;
    }
  }

  Future<void> stopHealthMonitoring() async {
    try {
      await platform.invokeMethod('stopBackgroundService');
    } catch (e) {
      print('Failed to stop health monitoring: $e');
      rethrow;
    }
  }

  Future<void> startScan(Function(BluetoothDevice) onDeviceFound) async {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.advertisementData.advName.contains("SR08") ||
            r.device.name.contains("SR08")) {
          onDeviceFound(r.device);
          FlutterBluePlus.stopScan();
        }
      }
    });
  }

  Future<void> disconnect() async {
    if (_device == null) {
      print("[BLE] disconnect(): 연결된 디바이스 없음 (스킵)");
      return;
    }

    try {
      await stopHealthMonitoring(); // 백그라운드 서비스 중지
      await platform.invokeMethod('disconnectDevice', {
        'macAddress': _device!.remoteId.str,
      });
      _dataSubscription?.cancel();
      await BackgroundService.cancelPeriodicTask();
      print("[BLE] disconnect(): 연결 해제 완료");
    } catch (e) {
      print('Failed to disconnect: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> measureHealthData() async {
    if (!isConnected) {
      throw Exception('Device not connected');
    }

    try {
      // SR08 SDK를 통해 건강 데이터 측정 요청
      await platform.invokeMethod('measureHealthData');

      // 현재 값을 기본값으로 사용
      final currentData = ref.read(healthDataProvider).latest;
      return {
        'heartRate': currentData?.heartRate ?? 0,
        'minHeartRate': currentData?.minHeartRate ?? 0,
        'maxHeartRate': currentData?.maxHeartRate ?? 0,
        'spo2': currentData?.spo2 ?? 0,
        'stepCount': currentData?.stepCount ?? 0,
        'battery': currentData?.battery ?? 100,
        'chargingState': currentData?.chargingState ?? 0,
        'sleepHours': currentData?.sleepHours ?? 0,
        'sportsTime': currentData?.sportsTime ?? 0,
        'screenStatus': currentData?.screenStatus ?? 0,
      };
    } catch (e) {
      print('Failed to measure health data: $e');
      rethrow;
    }
  }
}
