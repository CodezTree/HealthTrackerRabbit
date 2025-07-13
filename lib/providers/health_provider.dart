import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/health_data.dart';
import '../models/health_entry.dart';
import '../services/local_db_service.dart';

final healthDataProvider =
    StateNotifierProvider<HealthDataNotifier, HealthData>(
      (ref) => HealthDataNotifier(),
    );

class HealthDataNotifier extends StateNotifier<HealthData> {
  HealthDataNotifier()
    : super(HealthData(latest: null, today: [], week: [], month: []));

  Future<void> loadInitialData() async {
    final latest = await LocalDbService.getLatestEntry();
    final today = await LocalDbService.getEntriesForToday();
    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month - 1, now.day);

    final week = await LocalDbService.getEntriesForRange(weekStart, now);
    final month = await LocalDbService.getEntriesForRange(monthStart, now);

    state = HealthData(latest: latest, today: today, week: week, month: month);
  }

  Future<void> updateHealthData({
    required int heartRate,
    required int spo2,
    required int stepCount,
    required int battery,
    required int chargingState,
    required double sleepHours,
    required int sportsTime,
    required int screenStatus,
  }) async {
    final now = DateTime.now();
    // 시간 단위로 정규화 (분, 초, 밀리초 제거)
    final hourlyTimestamp = DateTime(now.year, now.month, now.day, now.hour);

    // 해당 시간대의 기존 데이터 조회
    final existingEntry = await LocalDbService.getEntryForHour(hourlyTimestamp);

    if (existingEntry != null) {
      // 기존 데이터가 있으면 업데이트 (0이 아닌 값만 반영)
      final updatedEntry = HealthEntry.create(
        id: existingEntry.id,
        userId: existingEntry.userId,
        heartRate: heartRate > 0 ? heartRate : existingEntry.heartRate,
        minHeartRate: heartRate > 0
            ? (heartRate < existingEntry.minHeartRate
                  ? heartRate
                  : existingEntry.minHeartRate)
            : existingEntry.minHeartRate,
        maxHeartRate: heartRate > 0
            ? (heartRate > existingEntry.maxHeartRate
                  ? heartRate
                  : existingEntry.maxHeartRate)
            : existingEntry.maxHeartRate,
        spo2: spo2 > 0 ? spo2 : existingEntry.spo2,
        stepCount: stepCount > 0 ? stepCount : existingEntry.stepCount,
        battery: battery > 0 ? battery : existingEntry.battery,
        chargingState: chargingState >= 0
            ? chargingState
            : existingEntry.chargingState,
        sleepHours: sleepHours > 0 ? sleepHours : existingEntry.sleepHours,
        sportsTime: sportsTime > 0 ? sportsTime : existingEntry.sportsTime,
        screenStatus: screenStatus >= 0
            ? screenStatus
            : existingEntry.screenStatus,
        timestamp: hourlyTimestamp,
      );
      await LocalDbService.updateHealthEntry(updatedEntry);
    } else {
      // 새로운 시간대 데이터 생성
      final newEntry = HealthEntry.create(
        userId: 'current_user',
        heartRate: heartRate,
        minHeartRate: heartRate,
        maxHeartRate: heartRate,
        spo2: spo2,
        stepCount: stepCount,
        battery: battery,
        chargingState: chargingState,
        sleepHours: sleepHours,
        sportsTime: sportsTime,
        screenStatus: screenStatus,
        timestamp: hourlyTimestamp,
      );
      await LocalDbService.saveHealthEntry(newEntry);
    }

    await loadInitialData();
  }
}
