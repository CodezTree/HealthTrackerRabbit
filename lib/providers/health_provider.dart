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
    final entry = HealthEntry.create(
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
      timestamp: DateTime.now(),
    );

    await LocalDbService.saveHealthEntry(entry);
    await loadInitialData();
  }
}
