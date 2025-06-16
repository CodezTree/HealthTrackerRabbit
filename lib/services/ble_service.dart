import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rabbithole_health_tracker_new/providers/health_provider.dart';
import '../utils/device_storage.dart';
import '../services/background_service.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../providers/connection_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BleService {
  final Ref ref;

  BleService(this.ref);

  static const platform = MethodChannel('com.example.sr08_sdk/methods');
  static const eventChannel = EventChannel('com.example.sr08_sdk/events');

  BluetoothDevice? _device;
  StreamSubscription? _dataSubscription;
  Timer? _batteryTimer;

  // SR08 Ring Service UUID (primary)
  static const String SERVICE_UUID = "0000ff01-0000-1000-8000-00805f9b34fb";

  // 재연결 로직 관리
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectAttempts++;
    Future.delayed(_reconnectDelay * _reconnectAttempts, () async {
      final success = await tryReconnectFromSavedDevice();
      if (!success) {
        _scheduleReconnect();
      } else {
        _reconnectAttempts = 0; // reset on success
      }
    });
  }

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

      // 연결 성공 후 데이터 수신 리스너 설정
      _setupDataListener();

      if (save) {
        await DeviceStorage.saveDeviceInfo(macAddress, 'SR08');
      }

      print("실제 완료 대기");

      // 실제 연결 완료 대기
      final ok = await waitForConnection(timeout: const Duration(seconds: 10));
      if (!ok) throw Exception('Connection timeout');

      print("연결 됨. 최초 초기 설정 명령 전송 중...");

      // 최초 1회만 초기 설정 명령 전송
      final prefs = await SharedPreferences.getInstance();
      const initFlagKey = 'initial_setup_done';
      final done = prefs.getBool(initFlagKey) ?? false;
      if (!done) {
        await platform.invokeMethod('initialSetup');
        await prefs.setBool(initFlagKey, true);
      }

      // await BackgroundService.registerPeriodicTask();
      print("초기 설정 완료");
    } catch (e) {
      print('Failed to connect: $e');
      rethrow;
    }
  }

  void _setupDataListener() {
    _dataSubscription?.cancel();
    _dataSubscription = eventChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is! Map || data['type'] == null) return;

        final String type = data['type'] as String;

        // health data events expect an int 'value'
        if (type == 'heart' || type == 'oxygen' || type == 'steps') {
          final dynamic v = data['value'];
          if (v is! int) return; // 잘못된 데이터 skip
          final int value = v;

          final healthData = ref.read(healthDataProvider.notifier);
          final latest = ref.read(healthDataProvider).latest;

          debugPrint('[$type] 값 수신: $value');

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
        } else if (type == 'connection') {
          // 연결 상태 이벤트 처리 (0: disconnected, 2: connected 등)
          final int? state = data['state'] as int?;
          if (state != null) {
            if (state == 0) {
              _device = null;
              ref.read(connectionStateProvider.notifier).state = false;
              _stopBatteryTimer();
            } else if (state == 2) {
              // 연결 유지 플래그만 유지 (필요 시)
              ref.read(connectionStateProvider.notifier).state = true;
              _reconnectAttempts = 0;
              _startBatteryTimer();
            }
          }
        } else if (type == 'battery') {
          final dynamic v = data['value'];
          if (v is! int) return;
          final int value = v;

          final healthData = ref.read(healthDataProvider.notifier);
          final latest = ref.read(healthDataProvider).latest;

          healthData.updateHealthData(
            heartRate: latest?.heartRate ?? 0,
            spo2: latest?.spo2 ?? 0,
            stepCount: latest?.stepCount ?? 0,
            battery: value,
            chargingState: latest?.chargingState ?? 0,
            sleepHours: latest?.sleepHours ?? 0,
            sportsTime: latest?.sportsTime ?? 0,
            screenStatus: latest?.screenStatus ?? 0,
          );
        } else if (type == 'health87') {
          final entry = data['entry'];
          debugPrint('[GET87] entry: $entry');
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
    // 스캔을 시작하고, 결과를 서비스 UUID 또는 기기명으로 필터링합니다.
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        final advData = r.advertisementData;

        final bool matchByServiceUuid = advData.serviceUuids.any(
          (uuid) => uuid.toString().toLowerCase() == SERVICE_UUID,
        );

        final nameLower =
            (advData.advName.isNotEmpty ? advData.advName : r.device.name)
                .toLowerCase();

        final bool matchByName =
            nameLower.startsWith("sr") || nameLower.contains("sr08");

        if (matchByServiceUuid || matchByName) {
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
      ref.read(connectionStateProvider.notifier).state = false;
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

  Future<void> enableAutoMonitoring(bool enable) async {
    try {
      await platform.invokeMethod('enableAutoMonitoring', {
        'state': enable ? 1 : 0,
      });
    } catch (e) {
      print('Failed to set auto monitoring: $e');
    }
  }

  Future<void> requestCurrentData() async {
    try {
      await platform.invokeMethod('requestCurrentData');
    } catch (e) {
      print('Failed to request current data: $e');
    }
  }

  Future<void> requestBatteryStatus() async {
    try {
      await platform.invokeMethod('requestBatteryStatus');
    } catch (e) {
      print('Failed to request battery status: $e');
    }
  }

  Future<void> requestHalfHourHeartData({DateTime? date}) async {
    try {
      final ts =
          (date ?? DateTime.now())
              .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
              .millisecondsSinceEpoch ~/
          1000;
      await platform.invokeMethod('requestHalfHourHeartData', {
        'timestamp': ts,
      });
    } catch (e) {
      print('Failed to request 30min heart data: $e');
    }
  }

  Future<void> readBatteryLevelFromService() async {
    if (_device == null) return;
    try {
      List<BluetoothService> services = await _device!.discoverServices();
      BluetoothCharacteristic? char;
      for (var s in services) {
        if (s.uuid.toString().toLowerCase() ==
            "0000180f-0000-1000-8000-00805f9b34fb") {
          for (var c in s.characteristics) {
            if (c.uuid.toString().toLowerCase() ==
                "00002a19-0000-1000-8000-00805f9b34fb") {
              char = c;
              break;
            }
          }
          if (char != null) {
            final val = await char.read();
            if (val.isNotEmpty) {
              final int level = val[0];
              final healthData = ref.read(healthDataProvider.notifier);
              final latest = ref.read(healthDataProvider).latest;
              healthData.updateHealthData(
                heartRate: latest?.heartRate ?? 0,
                spo2: latest?.spo2 ?? 0,
                stepCount: latest?.stepCount ?? 0,
                battery: level,
                chargingState: latest?.chargingState ?? 0,
                sleepHours: latest?.sleepHours ?? 0,
                sportsTime: latest?.sportsTime ?? 0,
                screenStatus: latest?.screenStatus ?? 0,
              );
            }
            break;
          }
        }
      }
    } catch (e) {
      print('Failed to read battery characteristic: $e');
    }
  }

  void _startBatteryTimer() {
    _batteryTimer?.cancel();
    _batteryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      readBatteryLevelFromService();
    });
  }

  void _stopBatteryTimer() {
    _batteryTimer?.cancel();
    _batteryTimer = null;
  }

  Future<bool> waitForConnection({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (isConnected) return true;
    final completer = Completer<bool>();
    late final ProviderSubscription<bool> sub;
    sub = ref.listen<bool>(connectionStateProvider, (prev, next) {
      if (next) {
        sub.close();
        completer.complete(true);
      }
    });
    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        sub.close();
        completer.complete(false);
      }
    });
    return completer.future;
  }

  Future<void> startInstantHealthMeasurement() async {
    try {
      await platform.invokeMethod('instantHealthMeasurement');
    } catch (e) {
      print('Failed instant measurement: $e');
    }
  }

  Future<void> requestMonitoringData() async {
    try {
      await platform.invokeMethod('requestMonitoringData');
    } catch (e) {
      print('Failed to request monitoring data: $e');
    }
  }

  Future<void> resetDeviceData() async {
    try {
      await platform.invokeMethod('resetDeviceData');
    } catch (e) {
      print('Failed to reset device data: $e');
    }
  }
}
