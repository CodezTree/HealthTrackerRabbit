import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/health_entry.dart';
import '../services/local_db_service.dart';
import '../providers/ble_provider.dart';

class BackgroundService {
  static const int periodicTaskId = 0;

  static Future<void> initialize() async {
    await AndroidAlarmManager.initialize();
  }

  @pragma('vm:entry-point')
  static Future<void> _periodicTask() async {
    try {
      // 1. BLE 서비스를 통해 SR08 링에서 데이터 측정
      final container = ProviderContainer();
      final bleService = container.read(bleServiceProvider);

      if (!bleService.isConnected) {
        print('SR08 ring is not connected. Skipping measurement.');
        return;
      }

      // 2. 건강 데이터 측정
      final healthData = await bleService.measureHealthData();

      // 3. 측정된 데이터를 로컬 데이터베이스에 저장
      final healthEntry = HealthEntry.create(
        userId: 'current_user', // TODO: 실제 사용자 ID로 대체
        heartRate: healthData['heartRate'] as int,
        minHeartRate: healthData['minHeartRate'] as int,
        maxHeartRate: healthData['maxHeartRate'] as int,
        spo2: healthData['spo2'] as int,
        stepCount: healthData['stepCount'] as int,
        battery: healthData['battery'] as int,
        chargingState: healthData['chargingState'] as int,
        sleepHours: (healthData['sleepHours'] as int).toDouble(),
        sportsTime: healthData['sportsTime'] as int,
        screenStatus: healthData['screenStatus'] as int,
        timestamp: DateTime.now(),
      );

      await LocalDbService.saveHealthEntry(healthEntry);
      print('Periodic health measurement completed successfully');

      // 컨테이너 정리
      container.dispose();
    } catch (err) {
      print('Error during periodic measurement: $err');
    }
  }

  static Future<void> registerPeriodicTask() async {
    await AndroidAlarmManager.periodic(
      const Duration(minutes: 30),
      periodicTaskId,
      _periodicTask,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
    print('Periodic health measurement task registered');
  }

  static Future<void> cancelPeriodicTask() async {
    await AndroidAlarmManager.cancel(periodicTaskId);
    print('Periodic health measurement task cancelled');
  }
}
