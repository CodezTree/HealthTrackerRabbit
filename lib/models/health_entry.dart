class HealthEntry {
  int? id;
  String userId;
  int heartRate; // 현재 심박수
  int minHeartRate; // 최소 심박수
  int maxHeartRate; // 최대 심박수
  int spo2;
  int stepCount;
  int battery;
  int chargingState;
  double sleepHours;
  int sportsTime;
  int screenStatus;
  DateTime timestamp;

  HealthEntry({
    this.id,
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

  HealthEntry.create({
    this.id,
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
    return HealthEntry(
      id: map['id'] as int?,
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
    final map = {
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

    if (id != null) {
      map['id'] = id!;
    }

    return map;
  }

  void updateHeartRateStats(int newHeartRate) {
    heartRate = newHeartRate;
    minHeartRate = newHeartRate < minHeartRate ? newHeartRate : minHeartRate;
    maxHeartRate = newHeartRate > maxHeartRate ? newHeartRate : maxHeartRate;
  }
}
