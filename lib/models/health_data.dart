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
  int get minHeartRate => latest?.minHeartRate ?? 0;
  int get maxHeartRate => latest?.maxHeartRate ?? 0;

  // 산소포화도 getter
  int get currentSpo2 => latest?.spo2 ?? 0;

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
