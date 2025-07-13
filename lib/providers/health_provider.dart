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

    // 최신 데이터 로드 완료 로그
    if (latest != null) {
      print(
        '📊 최신 건강 데이터 로드: HR=${latest.heartRate}, SpO2=${latest.spo2}%, Steps=${latest.stepCount}',
      );
    }
  }

  /// 실시간 건강 데이터 업데이트 (백그라운드 데이터 수신 시 사용)
  Future<void> updateFromBackgroundData({
    required int heartRate,
    required int spo2,
    required int stepCount,
    required int battery,
    required int chargingState,
    required DateTime timestamp,
  }) async {
    try {
      // 새로운 데이터로 latest 업데이트
      final updatedLatest = HealthEntry.create(
        userId: state.latest?.userId ?? 'current_user',
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
        timestamp: timestamp,
      );

      // 전체 데이터 다시 로드
      await loadInitialData();

      print(
        '✅ 백그라운드 데이터로 UI 업데이트 완료: HR=$heartRate, SpO2=$spo2%, Steps=$stepCount',
      );
    } catch (e) {
      print('❌ 백그라운드 데이터 UI 업데이트 오류: $e');
    }
  }

  /// 일간 데이터: 24시간 데이터를 시간별로 처리
  /// 1시간 평균치 반환 (걸음수는 해당 시간별 데이터)
  Future<List<HealthEntry>> getDailyData() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(hours: 24));

    final entries = await LocalDbService.getEntriesForRange(
      startOfDay,
      endOfDay,
    );

    List<HealthEntry> hourlyData = [];

    for (int hour = 0; hour < 24; hour++) {
      final hourStart = DateTime(now.year, now.month, now.day, hour);
      final hourEnd = hourStart.add(const Duration(hours: 1));

      final hourEntries = entries
          .where(
            (entry) =>
                entry.timestamp.isAfter(hourStart) &&
                entry.timestamp.isBefore(hourEnd),
          )
          .toList();

      if (hourEntries.isNotEmpty) {
        // 시간별 평균치 계산 (0값 제외)
        final validHeartRates = hourEntries
            .map((e) => e.heartRate)
            .where((hr) => hr > 0)
            .toList();
        final validSpo2 = hourEntries
            .map((e) => e.spo2)
            .where((spo2) => spo2 > 0)
            .toList();
        final validBattery = hourEntries
            .map((e) => e.battery)
            .where((battery) => battery > 0)
            .toList();

        final avgHeartRate = validHeartRates.isNotEmpty
            ? validHeartRates.reduce((a, b) => a + b) ~/ validHeartRates.length
            : 0;
        final avgSpo2 = validSpo2.isNotEmpty
            ? validSpo2.reduce((a, b) => a + b) ~/ validSpo2.length
            : 0;
        final avgBattery = validBattery.isNotEmpty
            ? validBattery.reduce((a, b) => a + b) ~/ validBattery.length
            : 0;

        // 걸음수는 해당 시간의 최대값 사용
        final maxSteps = hourEntries
            .map((e) => e.stepCount)
            .reduce((a, b) => a > b ? a : b);

        // 심박수 최대/최소값
        final minHeartRate = validHeartRates.isNotEmpty
            ? validHeartRates.reduce((a, b) => a < b ? a : b)
            : 0;
        final maxHeartRate = validHeartRates.isNotEmpty
            ? validHeartRates.reduce((a, b) => a > b ? a : b)
            : 0;

        hourlyData.add(
          HealthEntry.create(
            userId: 'current_user',
            heartRate: avgHeartRate,
            minHeartRate: minHeartRate,
            maxHeartRate: maxHeartRate,
            spo2: avgSpo2,
            stepCount: maxSteps,
            battery: avgBattery,
            chargingState: hourEntries.last.chargingState,
            sleepHours: hourEntries.last.sleepHours,
            sportsTime: hourEntries.last.sportsTime,
            screenStatus: hourEntries.last.screenStatus,
            timestamp: hourStart,
          ),
        );
      }
    }

    return hourlyData;
  }

  /// 주간 데이터: 월-일 7일간 데이터를 일별로 처리
  /// 평균치 반환 (걸음수는 최대치)
  Future<List<HealthEntry>> getWeeklyData() async {
    final now = DateTime.now();
    final currentWeekday = now.weekday; // 1=월요일, 7=일요일

    // 이번 주 월요일 찾기
    final mondayOfThisWeek = now.subtract(Duration(days: currentWeekday - 1));
    final startOfWeek = DateTime(
      mondayOfThisWeek.year,
      mondayOfThisWeek.month,
      mondayOfThisWeek.day,
    );

    List<HealthEntry> weeklyData = [];

    // 월요일부터 현재 요일까지만 표시
    for (int day = 0; day < currentWeekday; day++) {
      final dayStart = startOfWeek.add(Duration(days: day));
      final dayEnd = dayStart.add(const Duration(days: 1));

      final dayEntries = await LocalDbService.getEntriesForRange(
        dayStart,
        dayEnd,
      );

      if (dayEntries.isNotEmpty) {
        // 일별 평균치 계산 (0값 제외)
        final validHeartRates = dayEntries
            .map((e) => e.heartRate)
            .where((hr) => hr > 0)
            .toList();
        final validSpo2 = dayEntries
            .map((e) => e.spo2)
            .where((spo2) => spo2 > 0)
            .toList();
        final validBattery = dayEntries
            .map((e) => e.battery)
            .where((battery) => battery > 0)
            .toList();

        final avgHeartRate = validHeartRates.isNotEmpty
            ? validHeartRates.reduce((a, b) => a + b) ~/ validHeartRates.length
            : 0;
        final avgSpo2 = validSpo2.isNotEmpty
            ? validSpo2.reduce((a, b) => a + b) ~/ validSpo2.length
            : 0;
        final avgBattery = validBattery.isNotEmpty
            ? validBattery.reduce((a, b) => a + b) ~/ validBattery.length
            : 0;

        // 걸음수는 최대값 사용
        final maxSteps = dayEntries
            .map((e) => e.stepCount)
            .reduce((a, b) => a > b ? a : b);

        // 심박수 최대/최소값
        final minHeartRate = validHeartRates.isNotEmpty
            ? validHeartRates.reduce((a, b) => a < b ? a : b)
            : 0;
        final maxHeartRate = validHeartRates.isNotEmpty
            ? validHeartRates.reduce((a, b) => a > b ? a : b)
            : 0;

        weeklyData.add(
          HealthEntry.create(
            userId: 'current_user',
            heartRate: avgHeartRate,
            minHeartRate: minHeartRate,
            maxHeartRate: maxHeartRate,
            spo2: avgSpo2,
            stepCount: maxSteps,
            battery: avgBattery,
            chargingState: dayEntries.last.chargingState,
            sleepHours: dayEntries.last.sleepHours,
            sportsTime: dayEntries.last.sportsTime,
            screenStatus: dayEntries.last.screenStatus,
            timestamp: dayStart,
          ),
        );
      }
    }

    return weeklyData;
  }

  /// 월간 데이터: 최근 7개월 데이터를 월별로 처리
  /// 평균치 반환 (걸음수는 최대치)
  Future<List<HealthEntry>> getMonthlyData() async {
    final now = DateTime.now();
    List<HealthEntry> monthlyData = [];

    // 최근 7개월 처리
    for (int monthOffset = 6; monthOffset >= 0; monthOffset--) {
      final targetMonth = DateTime(now.year, now.month - monthOffset, 1);
      final nextMonth = DateTime(targetMonth.year, targetMonth.month + 1, 1);

      final monthEntries = await LocalDbService.getEntriesForRange(
        targetMonth,
        nextMonth,
      );

      if (monthEntries.isNotEmpty) {
        // 월별 평균치 계산 (0값 제외)
        final validHeartRates = monthEntries
            .map((e) => e.heartRate)
            .where((hr) => hr > 0)
            .toList();
        final validSpo2 = monthEntries
            .map((e) => e.spo2)
            .where((spo2) => spo2 > 0)
            .toList();
        final validBattery = monthEntries
            .map((e) => e.battery)
            .where((battery) => battery > 0)
            .toList();

        final avgHeartRate = validHeartRates.isNotEmpty
            ? validHeartRates.reduce((a, b) => a + b) ~/ validHeartRates.length
            : 0;
        final avgSpo2 = validSpo2.isNotEmpty
            ? validSpo2.reduce((a, b) => a + b) ~/ validSpo2.length
            : 0;
        final avgBattery = validBattery.isNotEmpty
            ? validBattery.reduce((a, b) => a + b) ~/ validBattery.length
            : 0;

        // 걸음수는 최대값 사용
        final maxSteps = monthEntries
            .map((e) => e.stepCount)
            .reduce((a, b) => a > b ? a : b);

        // 심박수 최대/최소값
        final minHeartRate = validHeartRates.isNotEmpty
            ? validHeartRates.reduce((a, b) => a < b ? a : b)
            : 0;
        final maxHeartRate = validHeartRates.isNotEmpty
            ? validHeartRates.reduce((a, b) => a > b ? a : b)
            : 0;

        monthlyData.add(
          HealthEntry.create(
            userId: 'current_user',
            heartRate: avgHeartRate,
            minHeartRate: minHeartRate,
            maxHeartRate: maxHeartRate,
            spo2: avgSpo2,
            stepCount: maxSteps,
            battery: avgBattery,
            chargingState: monthEntries.last.chargingState,
            sleepHours: monthEntries.last.sleepHours,
            sportsTime: monthEntries.last.sportsTime,
            screenStatus: monthEntries.last.screenStatus,
            timestamp: targetMonth,
          ),
        );
      }
    }

    return monthlyData;
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
