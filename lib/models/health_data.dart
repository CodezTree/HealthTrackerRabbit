import 'health_entry.dart';

class HealthData {
  final HealthEntry? latest;
  final List<HealthEntry> today;
  final List<HealthEntry> week;
  final List<HealthEntry> month;

  HealthData({
    this.latest,
    required this.today,
    required this.week,
    required this.month,
  });

  // 심박수 관련 getter
  int get currentHeartRate => latest?.heartRate ?? 0;

  // 오늘 하루 전체 데이터에서 실제 최소/최대 심박수 계산
  int get minHeartRate {
    if (today.isEmpty) return currentHeartRate;
    final validHeartRates = today
        .map((e) => e.heartRate)
        .where((hr) => hr > 0)
        .toList();
    if (validHeartRates.isEmpty) return currentHeartRate;
    return validHeartRates.reduce((a, b) => a < b ? a : b);
  }

  int get maxHeartRate {
    if (today.isEmpty) return currentHeartRate;
    final validHeartRates = today
        .map((e) => e.heartRate)
        .where((hr) => hr > 0)
        .toList();
    if (validHeartRates.isEmpty) return currentHeartRate;
    return validHeartRates.reduce((a, b) => a > b ? a : b);
  }

  // 산소포화도 getter
  int get currentSpo2 => latest?.spo2 ?? 0;

  // 오늘 하루 전체 데이터에서 실제 최소/최대 산소포화도 계산
  int get minSpo2 {
    if (today.isEmpty) return currentSpo2;
    final validSpo2Values = today
        .map((e) => e.spo2)
        .where((spo2) => spo2 > 0)
        .toList();
    if (validSpo2Values.isEmpty) return currentSpo2;
    return validSpo2Values.reduce((a, b) => a < b ? a : b);
  }

  int get maxSpo2 {
    if (today.isEmpty) return currentSpo2;
    final validSpo2Values = today
        .map((e) => e.spo2)
        .where((spo2) => spo2 > 0)
        .toList();
    if (validSpo2Values.isEmpty) return currentSpo2;
    return validSpo2Values.reduce((a, b) => a > b ? a : b);
  }

  // 걸음수 관련 getter
  int get currentSteps => latest?.stepCount ?? 0;

  // 배터리 관련 getter
  int get batteryLevel => latest?.battery ?? 0;
  bool get isCharging => latest?.chargingState == 1;

  // 수면 시간
  double get sleepHours => latest?.sleepHours ?? 0.0;

  // 운동 시간 (초 단위)
  int get sportsTime => latest?.sportsTime ?? 0;

  // 화면 상태
  bool get isScreenOn => latest?.screenStatus == 1;
}
