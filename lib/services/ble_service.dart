import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rabbithole_health_tracker_new/providers/health_provider.dart';
import '../utils/device_storage.dart';
import '../services/background_service.dart';
import '../services/api_service.dart';
import '../services/local_db_service.dart';
import '../models/health_entry.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../providers/connection_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/background_health_provider.dart';

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

      // 백그라운드 건강 모니터링 서비스 시작
      await startHealthMonitoring();

      print("초기 설정 및 백그라운드 모니터링 시작 완료");
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
                battery: latest?.battery ?? 0,
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
                battery: latest?.battery ?? 0,
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
                battery: latest?.battery ?? 0,
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

              // 백그라운드 서비스에 MAC 주소 전달
              DeviceStorage.getDeviceInfo().then((deviceInfo) {
                if (deviceInfo != null) {
                  platform.invokeMethod('setLastKnownMacAddress', {
                    'macAddress': deviceInfo['id'],
                  });
                }
              });
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
        } else if (type == 'device_info') {
          // GET0 데이터 처리
          final String? dataString = data['data'] as String?;
          if (dataString != null) {
            try {
              final regex = RegExp(r'"battery_capacity":"(\d+)"');
              final match = regex.firstMatch(dataString);
              if (match != null) {
                final int batteryLevel = int.parse(match.group(1)!);

                final healthData = ref.read(healthDataProvider.notifier);
                final latest = ref.read(healthDataProvider).latest;

                healthData.updateHealthData(
                  heartRate: latest?.heartRate ?? 0,
                  spo2: latest?.spo2 ?? 0,
                  stepCount: latest?.stepCount ?? 0,
                  battery: batteryLevel,
                  chargingState: latest?.chargingState ?? 0,
                  sleepHours: latest?.sleepHours ?? 0,
                  sportsTime: latest?.sportsTime ?? 0,
                  screenStatus: latest?.screenStatus ?? 0,
                );

                debugPrint('[GET0] Battery capacity updated: $batteryLevel%');
              }
            } catch (e) {
              debugPrint('[GET0] Failed to parse battery_capacity: $e');
            }
          }
        } else if (type == 'background_data') {
          // 백그라운드에서 수집된 데이터 처리
          final String? dataType = data['data_type'] as String?;
          final int? value = data['value'] as int?;
          final String? timestamp = data['timestamp'] as String?;

          if (dataType != null && value != null && timestamp != null) {
            // 백그라운드 데이터 프로바이더로 전달
            BackgroundHealthProvider().processBackgroundData(
              dataType,
              value,
              timestamp,
            );
          }
        } else if (type == 'send_background_health_data') {
          // 백그라운드에서 수집된 데이터를 API로 전송
          final heartRate = data['heartRate'] as int? ?? 0;
          final spo2 = data['spo2'] as int? ?? 0;
          final stepCount = data['stepCount'] as int? ?? 0;
          final battery = data['battery'] as int? ?? 0;
          final chargingState = data['chargingState'] as int? ?? 0;
          final timestamp = data['timestamp'] as String? ?? '';

          debugPrint('🟡 백그라운드 건강 데이터 API 전송 요청 수신');
          debugPrint(
            '📊 HR: $heartRate, SpO2: $spo2%, Steps: $stepCount, Battery: $battery%',
          );

          _sendBackgroundHealthDataToServer(
            heartRate: heartRate,
            spo2: spo2,
            stepCount: stepCount,
            battery: battery,
            chargingState: chargingState,
            timestamp: timestamp,
          );
        } else if (type == 'save_background_health_data') {
          // 백그라운드에서 수집된 데이터를 로컬 데이터베이스에 저장
          final heartRate = data['heartRate'] as int? ?? 0;
          final spo2 = data['spo2'] as int? ?? 0;
          final stepCount = data['stepCount'] as int? ?? 0;
          final battery = data['battery'] as int? ?? 0;
          final chargingState = data['chargingState'] as int? ?? 0;
          final timestamp = data['timestamp'] as String? ?? '';

          debugPrint('💾 백그라운드 건강 데이터 로컬 저장 요청 수신');
          debugPrint(
            '📊 HR: $heartRate, SpO2: $spo2%, Steps: $stepCount, Battery: $battery%',
          );

          _saveBackgroundHealthDataToLocal(
            heartRate: heartRate,
            spo2: spo2,
            stepCount: stepCount,
            battery: battery,
            chargingState: chargingState,
            timestamp: timestamp,
          );
        }
      },
      onError: (error) {
        print('Error receiving data: $error');
      },
    );
  }

  Future<void> startHealthMonitoring() async {
    try {
      print('[BLE] 백그라운드 건강 모니터링 시작...');
      await platform.invokeMethod('startHealthMonitoring');

      // 백그라운드 서비스 시작
      print('[BLE] 30분 주기 백그라운드 서비스 시작...');
      await platform.invokeMethod('startBackgroundService');

      print('[BLE] ✅ 백그라운드 건강 모니터링 서비스 시작 완료');
    } catch (e) {
      print('[BLE] ❌ 백그라운드 건강 모니터링 시작 실패: $e');
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
        'battery': currentData?.battery ?? 0,
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
      // 먼저 GET0 (배터리 정보)를 요청하고 약간의 지연 후 다른 데이터 요청
      await platform.invokeMethod('requestCurrentData'); // GET0 요청

      // 배터리 정보가 업데이트될 시간을 주기 위해 잠시 대기
      await Future.delayed(const Duration(milliseconds: 500));

      await platform.invokeMethod('requestBackgroundHealthData');
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

  Future<void> testBackgroundDataCollection() async {
    try {
      await platform.invokeMethod('testBackgroundDataCollection');
    } catch (e) {
      print('Failed to test background data collection: $e');
    }
  }

  /// 백그라운드에서 수집된 건강 데이터를 서버로 전송
  void _sendBackgroundHealthDataToServer({
    required int heartRate,
    required int spo2,
    required int stepCount,
    required int battery,
    required int chargingState,
    required String timestamp,
  }) async {
    try {
      debugPrint('🚀 백그라운드 건강 데이터 서버 전송 시작');

      // ApiService를 import해야 합니다
      final success = await ApiService.sendHealthData(
        heartRate: heartRate,
        spo2: spo2,
        stepCount: stepCount,
        battery: battery,
        chargingState: chargingState,
        timestamp: timestamp,
      );

      if (success) {
        debugPrint('✅ 백그라운드 건강 데이터 서버 전송 성공');
      } else {
        debugPrint('❌ 백그라운드 건강 데이터 서버 전송 실패');
      }
    } catch (e) {
      debugPrint('💥 백그라운드 건강 데이터 서버 전송 오류: $e');
    }
  }

  /// 백그라운드에서 수집된 건강 데이터를 로컬 데이터베이스에 저장
  void _saveBackgroundHealthDataToLocal({
    required int heartRate,
    required int spo2,
    required int stepCount,
    required int battery,
    required int chargingState,
    required String timestamp,
  }) async {
    try {
      debugPrint('💾 백그라운드 건강 데이터 로컬 저장 시작');

      // 유효한 데이터인지 확인
      if (heartRate <= 0 || spo2 <= 0 || stepCount < 0) {
        debugPrint('❌ 유효하지 않은 데이터 - 로컬 저장 건너뜀');
        debugPrint('HR: $heartRate, SpO2: $spo2, Steps: $stepCount');
        return;
      }

      // HealthEntry 생성
      final healthEntry = HealthEntry.create(
        userId: 'current_user', // TODO: 실제 사용자 ID로 변경
        heartRate: heartRate,
        minHeartRate: heartRate,
        maxHeartRate: heartRate,
        spo2: spo2,
        stepCount: stepCount,
        battery: battery,
        chargingState: chargingState,
        sleepHours: 0.0,
        sportsTime: 0,
        screenStatus: 0,
        timestamp: DateTime.parse(timestamp),
      );

      // 로컬 데이터베이스에 저장
      await LocalDbService.saveHealthEntry(healthEntry);

      debugPrint('✅ 백그라운드 건강 데이터 로컬 저장 성공');
      debugPrint(
        '📊 저장된 데이터: HR=$heartRate, SpO2=$spo2%, Steps=$stepCount, Battery=$battery%',
      );

      // health_provider에도 업데이트하여 UI에 즉시 반영
      final healthData = ref.read(healthDataProvider.notifier);
      await healthData.updateFromBackgroundData(
        heartRate: heartRate,
        spo2: spo2,
        stepCount: stepCount,
        battery: battery,
        chargingState: chargingState,
        timestamp: DateTime.parse(timestamp),
      );
    } catch (e) {
      debugPrint('💥 백그라운드 건강 데이터 로컬 저장 오류: $e');
    }
  }
}
