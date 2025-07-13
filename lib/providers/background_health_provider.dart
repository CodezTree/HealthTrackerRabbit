import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/local_db_service.dart';
import '../models/health_entry.dart';
import '../utils/token_storage.dart';

class BackgroundHealthProvider extends ChangeNotifier {
  static final BackgroundHealthProvider _instance =
      BackgroundHealthProvider._internal();
  factory BackgroundHealthProvider() => _instance;
  BackgroundHealthProvider._internal();

  // 수집된 데이터 임시 저장
  final Map<String, dynamic> _collectedData = {};

  int? _latestHeartRate;
  int? _latestSpo2;
  int? _latestStepCount;
  int? _latestBattery;
  String? _lastUpdateTime;

  // Getters
  int? get latestHeartRate => _latestHeartRate;
  int? get latestSpo2 => _latestSpo2;
  int? get latestStepCount => _latestStepCount;
  int? get latestBattery => _latestBattery;
  String? get lastUpdateTime => _lastUpdateTime;

  /// 백그라운드에서 수집된 데이터 처리
  void processBackgroundData(String dataType, int value, String timestamp) {
    print("🔵 백그라운드 데이터 수신: $dataType = $value (시간: $timestamp)");

    switch (dataType) {
      case 'heart':
        _latestHeartRate = value;
        break;
      case 'oxygen':
        _latestSpo2 = value;
        break;
      case 'steps':
        _latestStepCount = value;
        break;
      case 'battery':
        _latestBattery = value;
        break;
    }

    _collectedData[dataType] = {'value': value, 'timestamp': timestamp};

    _lastUpdateTime = DateTime.now().toIso8601String();
    notifyListeners();

    // 모든 필수 데이터가 수집되었는지 확인
    _checkAndSaveCompleteData();
  }

  /// 모든 필수 데이터(배터리, 심박수, 혈중산소, 걸음수)가 수집되었는지 확인하고 저장/전송
  void _checkAndSaveCompleteData() {
    final hasBattery = _collectedData.containsKey('battery');
    final hasHeart = _collectedData.containsKey('heart');
    final hasOxygen = _collectedData.containsKey('oxygen');
    final hasSteps = _collectedData.containsKey('steps');

    if (hasBattery && hasHeart && hasOxygen && hasSteps) {
      print("🟢 모든 필수 건강 데이터 수집 완료 - 저장 및 전송 시작");
      print(
        "🟡 수집된 데이터: 배터리: $_latestBattery%, 심박수: $_latestHeartRate, 산소: $_latestSpo2, 걸음수: $_latestStepCount",
      );

      // 데이터를 복사한 후 먼저 clear()로 동시성 문제 방지
      final dataToSave = Map<String, dynamic>.from(_collectedData);
      _collectedData.clear(); // 즉시 clear하여 중복 실행 방지

      // 복사된 데이터로 저장/전송 실행
      _saveAndSendDataWithCopy(dataToSave);
    } else {
      print(
        "🟡 데이터 수집 중... (배터리: $hasBattery, 심박수: $hasHeart, 산소: $hasOxygen, 걸음수: $hasSteps)",
      );
    }
  }

  /// 복사된 데이터를 사용하여 안전하게 저장/전송
  Future<void> _saveAndSendDataWithCopy(
    Map<String, dynamic> collectedData,
  ) async {
    try {
      final userId = await TokenStorage.getUserId();
      if (userId == null) {
        print("🔴 사용자 ID가 없어 데이터를 저장할 수 없음");
        return;
      }

      // 안전한 데이터 접근을 위한 null 체크
      final heartData = collectedData['heart'] as Map<String, dynamic>?;
      final oxygenData = collectedData['oxygen'] as Map<String, dynamic>?;
      final stepsData = collectedData['steps'] as Map<String, dynamic>?;
      final batteryData = collectedData['battery'] as Map<String, dynamic>?;

      // 필수 데이터 유효성 검증
      if (heartData == null ||
          oxygenData == null ||
          stepsData == null ||
          batteryData == null) {
        print("🔴 필수 건강 데이터가 누락됨 - 저장/전송 건너뜀");
        print("배터리: ${batteryData != null ? '✓' : '✗'}");
        print("심박수: ${heartData != null ? '✓' : '✗'}");
        print("혈중산소: ${oxygenData != null ? '✓' : '✗'}");
        print("걸음수: ${stepsData != null ? '✓' : '✗'}");
        return;
      }

      // 안전한 값 추출
      final heartRate = heartData['value'] as int? ?? 0;
      final spo2 = oxygenData['value'] as int? ?? 0;
      final stepCount = stepsData['value'] as int? ?? 0;
      final battery = batteryData['value'] as int? ?? 0;

      // 데이터 유효성 재확인
      if (heartRate <= 0 || spo2 <= 0 || stepCount < 0 || battery < 0) {
        print("🔴 유효하지 않은 건강 데이터 값 - 저장/전송 건너뜀");
        print("배터리: $battery%, 심박수: $heartRate, 혈중산소: $spo2, 걸음수: $stepCount");
        return;
      }

      print(
        "🟡 유효한 데이터 확인됨 - 배터리: $battery%, 심박수: $heartRate, 혈중산소: $spo2, 걸음수: $stepCount",
      );

      // HealthEntry 생성
      final healthEntry = HealthEntry.create(
        userId: userId,
        heartRate: heartRate,
        minHeartRate: heartRate, // 현재는 같은 값으로 설정
        maxHeartRate: heartRate, // 현재는 같은 값으로 설정
        spo2: spo2,
        stepCount: stepCount,
        battery: battery,
        chargingState: 0, // 기본값
        sleepHours: 0.0, // 기본값
        sportsTime: 0, // 기본값
        screenStatus: 0, // 기본값
        timestamp: DateTime.now(),
      );

      // 로컬 데이터베이스에 저장
      await LocalDbService.saveHealthEntry(healthEntry);
      print("🟢 로컬 데이터베이스에 건강 데이터 저장 완료");

      // API로 전송 (새로운 JSON 형태)
      final success = await ApiService.sendHealthData(
        heartRate: heartRate,
        spo2: spo2,
        stepCount: stepCount,
        bodyTemperature: 36.5, // 기본값 (링에서 체온 측정 시 업데이트 가능)
        systolicBP: 120, // 기본값 (향후 혈압 측정 기능 추가 시 업데이트)
        diastolicBP: 80, // 기본값
        bloodSugar: 98, // 기본값 (향후 혈당 측정 기능 추가 시 업데이트)
        battery: battery,
        chargingState: 0, // 기본값 (향후 충전 상태 감지 시 업데이트)
        sleepHours: 0.0, // 기본값 (향후 수면 분석 기능 추가 시 업데이트)
        sportsTime: 0, // 기본값 (향후 운동 시간 분석 기능 추가 시 업데이트)
        screenStatus: 0, // 기본값
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );

      if (success) {
        print("🟢 API로 건강 데이터 전송 성공");
      } else {
        print("🔴 API로 건강 데이터 전송 실패");
      }
    } catch (e) {
      print("🔴 데이터 저장/전송 오류: $e");
    }
  }

  /// 주기적으로 미전송 데이터를 API로 전송
  Future<void> sendPendingData() async {
    try {
      print("🟡 미전송 데이터 확인 및 전송 시작");

      // 최근 24시간의 데이터 중 미전송된 것들 가져오기
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final entries = await LocalDbService.getHealthEntries(
        startDate: yesterday,
        endDate: DateTime.now(),
      );

      if (entries.isEmpty) {
        print("🟡 전송할 미전송 데이터가 없음");
        return;
      }

      print("🟡 ${entries.length}개의 데이터 항목 전송 시도");

      int successCount = 0;
      for (final entry in entries) {
        final success = await ApiService.sendHealthData(
          heartRate: entry.heartRate,
          spo2: entry.spo2,
          stepCount: entry.stepCount,
          bodyTemperature: 36.5, // 기본값
          systolicBP: 120, // 기본값
          diastolicBP: 80, // 기본값
          bloodSugar: 98, // 기본값
          battery: entry.battery,
          chargingState: entry.chargingState,
          sleepHours: entry.sleepHours,
          sportsTime: entry.sportsTime,
          screenStatus: entry.screenStatus,
          timestamp: entry.timestamp.toUtc().toIso8601String(),
        );

        if (success) {
          successCount++;
        }

        // API 요청 간 간격 (서버 부하 방지)
        await Future.delayed(const Duration(milliseconds: 500));
      }

      print("🟢 총 ${entries.length}개 중 $successCount개 데이터 전송 성공");
    } catch (e) {
      print("🔴 미전송 데이터 처리 오류: $e");
    }
  }

  /// 데이터 리셋
  void clearData() {
    _latestHeartRate = null;
    _latestSpo2 = null;
    _latestStepCount = null;
    _latestBattery = null;
    _lastUpdateTime = null;
    _collectedData.clear();
    notifyListeners();
  }
}
