import 'package:isar/isar.dart';

part 'health_entry.g.dart';

@collection
class HealthEntry {
  Id id = Isar.autoIncrement;

  late String userId;
  late int heartRate; // 현재 심박수
  late int minHeartRate; // 최소 심박수
  late int maxHeartRate; // 최대 심박수
  late int spo2;
  late int stepCount;
  late int battery;
  late int chargingState;
  late double sleepHours;
  late int sportsTime;
  late int screenStatus;
  late DateTime timestamp;

  HealthEntry();

  HealthEntry.create({
    this.id = Isar.autoIncrement,
    required this.userId,
    required this.heartRate,
    required this.minHeartRate,
    required this.maxHeartRate,
    required this.spo2,
    required this.stepCount,
    required this.battery,
    required this.chargingState,
    required this.sleepHours,
    required this.sportsTime,
    required this.screenStatus,
    required this.timestamp,
  });

  factory HealthEntry.fromMap(Map<String, dynamic> map) {
    return HealthEntry.create(
      userId: map['userId'] as String,
      heartRate: map['heartRate'] as int,
      minHeartRate: map['minHeartRate'] as int,
      maxHeartRate: map['maxHeartRate'] as int,
      spo2: map['spo2'] as int,
      stepCount: map['stepCount'] as int,
      battery: map['battery'] as int,
      chargingState: map['chargingState'] as int,
      sleepHours: map['sleepHours'].toDouble(),
      sportsTime: map['sportsTime'] as int,
      screenStatus: map['screenStatus'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'heartRate': heartRate,
      'minHeartRate': minHeartRate,
      'maxHeartRate': maxHeartRate,
      'spo2': spo2,
      'stepCount': stepCount,
      'battery': battery,
      'chargingState': chargingState,
      'sleepHours': sleepHours,
      'sportsTime': sportsTime,
      'screenStatus': screenStatus,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  void updateHeartRateStats(int newHeartRate) {
    heartRate = newHeartRate;
    minHeartRate = newHeartRate < minHeartRate ? newHeartRate : minHeartRate;
    maxHeartRate = newHeartRate > maxHeartRate ? newHeartRate : maxHeartRate;
  }
}
