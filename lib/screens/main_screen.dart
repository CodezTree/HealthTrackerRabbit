import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rabbithole_health_tracker_new/providers/health_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'heart_detail_screen.dart';
import 'steps_detail_screen.dart';
import 'oxygen_detail_screen.dart';
import 'dart:ui';
import 'package:rabbithole_health_tracker_new/providers/connection_provider.dart';
import 'package:rabbithole_health_tracker_new/providers/ble_provider.dart';
import 'package:rabbithole_health_tracker_new/utils/device_storage.dart';
import 'package:rabbithole_health_tracker_new/utils/token_storage.dart';
import 'package:rabbithole_health_tracker_new/services/local_db_service.dart';
import 'package:rabbithole_health_tracker_new/models/health_entry.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // 앱 생명주기 감지를 위한 옵저버 등록
    WidgetsBinding.instance.addObserver(this);

    // 화면 진입 시 DB에서 최신 건강 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLatestHealthData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 앱이 포그라운드로 돌아올 때 최신 데이터 로드
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 앱이 포그라운드로 돌아왔습니다 - 최신 데이터 로드');
      _loadLatestHealthData();
    }
  }

  /// 최신 건강 데이터를 로드하는 메서드
  Future<void> _loadLatestHealthData() async {
    try {
      // 네이티브 데이터 동기화 먼저 시도
      await LocalDbService.syncNativeHealthData();

      // health_provider 업데이트
      await ref.read(healthDataProvider.notifier).loadInitialData();

      debugPrint('✅ 최신 건강 데이터 로드 완료');
    } catch (e) {
      debugPrint('❌ 건강 데이터 로드 오류: $e');
    }
  }

  /// 최신 측정 시간을 포맷하여 반환
  String _getFormattedLastMeasurementTime(HealthEntry? latest) {
    if (latest == null) {
      return "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} 기준";
    }

    final measurementTime = latest.timestamp;
    final now = DateTime.now();
    final diff = now.difference(measurementTime);

    if (diff.inMinutes < 1) {
      return "방금 전 측정";
    } else if (diff.inMinutes < 60) {
      return "${diff.inMinutes}분 전 측정";
    } else if (diff.inHours < 24) {
      return "${diff.inHours}시간 전 측정";
    } else {
      return "${measurementTime.hour.toString().padLeft(2, '0')}:${measurementTime.minute.toString().padLeft(2, '0')} 측정";
    }
  }

  // 심박수에 따른 색상 결정
  Color getHeartColor(int bpm) {
    if (bpm <= 100) {
      return const Color(0xFF6CA2C0); // 정상수치
    } else if (bpm <= 120) {
      return const Color(0xFFDF7548); // 약간 높음
    } else {
      return const Color(0xFFE92430); // 매우 높음
    }
  }

  // 걸음수에 따른 색상 결정
  Color getStepsColor(int steps) {
    const int dailyGoal = 10000;
    if (steps >= dailyGoal) {
      return const Color(0xFF48BB78); // 목표 달성 - 초록
    } else if (steps >= dailyGoal * 0.7) {
      return const Color(0xFF6CA2C0); // 70% 이상 - 파랑
    } else if (steps >= dailyGoal * 0.5) {
      return const Color(0xFFDF7548); // 50% 이상 - 주황
    } else {
      return const Color(0xFFE53E3E); // 50% 미만 - 빨강
    }
  }

  // 산소포화도에 따른 색상 결정
  Color getOxygenColor(int spo2) {
    if (spo2 >= 95) {
      return const Color(0xFF26A0E4); // 정상 - 파란색
    } else if (spo2 >= 90) {
      return const Color(0xFFDF7548); // 주의 - 주황색
    } else {
      return const Color(0xFFE92430); // 심각 - 빨간색
    }
  }

  Widget _buildSummaryCard(int heart, int steps, int oxygen, String kcal) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 제목
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6CA2C0).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.health_and_safety,
                  color: Color(0xFF6CA2C0),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  "종합 건강 상태",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 건강 상태 표시
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6CA2C0).withOpacity(0.1),
              border: Border.all(
                color: const Color(0xFF6CA2C0).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.health_and_safety,
                  color: Color(0xFF6CA2C0),
                  size: 32,
                ),
                SizedBox(height: 4),
                Text(
                  "정상",
                  style: TextStyle(
                    fontSize: 24, // 16 * 1.5 = 24
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6CA2C0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 건강 데이터 요약
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildHealthSummaryItem(
                icon: Icons.favorite,
                label: "심박수",
                value: "$heart",
                unit: "bpm",
                color: getHeartColor(heart),
              ),
              _buildHealthSummaryItem(
                icon: Icons.directions_walk,
                label: "걸음수",
                value: "$steps",
                unit: "걸음",
                color: getStepsColor(steps),
              ),
              _buildHealthSummaryItem(
                icon: Icons.water_drop,
                label: "산소포화도",
                value: "$oxygen",
                unit: "%",
                color: getOxygenColor(oxygen),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 칼로리 정보
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  "칼로리 소모량: $kcal kcal",
                  style: const TextStyle(
                    fontSize: 21, // 14 * 1.5 = 21
                    color: Color(0xFF4A5568),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24, // 16 * 1.5 = 24
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 15,
            color: color.withOpacity(0.8),
          ), // 10 * 1.5 = 15
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF718096),
          ), // 11 * 1.5 = 16.5 ≈ 16
        ),
      ],
    );
  }

  Widget _buildHeartCard(int heart, int minHeart, int maxHeart) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HeartDetailScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // 좌측 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: getHeartColor(heart).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite,
                          color: getHeartColor(heart),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          "심박수",
                          style: TextStyle(
                            fontSize: 21, // 14 * 1.5 = 21
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 현재 심박수
                  Row(
                    children: [
                      Text(
                        "$heart",
                        style: TextStyle(
                          fontSize: 42, // 28 * 1.5 = 42
                          fontWeight: FontWeight.bold,
                          color: getHeartColor(heart),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "BPM",
                        style: TextStyle(
                          fontSize: 21, // 14 * 1.5 = 21
                          color: getHeartColor(heart).withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 최소/최대 정보
                  Row(
                    children: [
                      Text(
                        "최저 $minHeart",
                        style: const TextStyle(
                          fontSize: 18, // 12 * 1.5 = 18
                          color: Color(0xFF718096),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "최고 $maxHeart",
                        style: const TextStyle(
                          fontSize: 18, // 12 * 1.5 = 18
                          color: Color(0xFF718096),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 우측 하트 아이콘
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: getHeartColor(heart).withOpacity(0.1),
              ),
              child: Icon(
                Icons.favorite,
                color: getHeartColor(heart),
                size: 40,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsCard(int steps) {
    const int dailyGoal = 10000;
    final progress = (steps / dailyGoal).clamp(0.0, 1.0);
    final kcal = (steps * 0.04).toStringAsFixed(1);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StepsDetailScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: getStepsColor(steps).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.directions_walk,
                    color: getStepsColor(steps),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    "걸음수",
                    style: TextStyle(
                      fontSize: 21, // 14 * 1.5 = 21
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                // 좌측 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 현재 걸음수
                      Row(
                        children: [
                          Text(
                            "$steps",
                            style: TextStyle(
                              fontSize: 36, // 24 * 1.5 = 36
                              fontWeight: FontWeight.bold,
                              color: getStepsColor(steps),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "걸음",
                            style: TextStyle(
                              fontSize: 21, // 14 * 1.5 = 21
                              color: getStepsColor(steps).withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 칼로리 정보
                      Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            size: 14,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$kcal kcal",
                            style: const TextStyle(
                              fontSize: 18, // 12 * 1.5 = 18
                              color: Color(0xFF718096),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 우측 진행률 표시
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          getStepsColor(steps),
                        ),
                        strokeWidth: 6,
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${(progress * 100).round()}%",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: getStepsColor(steps),
                            ),
                          ),
                          const Text(
                            "목표",
                            style: TextStyle(
                              fontSize: 8,
                              color: Color(0xFF718096),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 목표 달성도 바
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "목표 달성도",
                  style: TextStyle(fontSize: 12, color: Color(0xFF718096)),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    getStepsColor(steps),
                  ),
                  minHeight: 6,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOxygenCard(
    int oxygen,
    int minOxygen,
    int maxOxygen,
    String measurementTime,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OxygenDetailScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // 좌측 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: getOxygenColor(oxygen).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.water_drop,
                          color: getOxygenColor(oxygen),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          "산소포화도",
                          style: TextStyle(
                            fontSize: 21, // 14 * 1.5 = 21
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 현재 산소포화도
                  Row(
                    children: [
                      Text(
                        "$oxygen",
                        style: TextStyle(
                          fontSize: 42, // 28 * 1.5 = 42
                          fontWeight: FontWeight.bold,
                          color: getOxygenColor(oxygen),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "%",
                        style: TextStyle(
                          fontSize: 21, // 14 * 1.5 = 21
                          color: getOxygenColor(oxygen).withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 측정 시간
                  Text(
                    measurementTime,
                    style: const TextStyle(
                      fontSize: 16, // 11 * 1.5 = 16.5 ≈ 16
                      color: Color(0xFF718096),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // 최소/최대 정보
                  Row(
                    children: [
                      Text(
                        "최저 $minOxygen%",
                        style: const TextStyle(
                          fontSize: 18, // 12 * 1.5 = 18
                          color: Color(0xFF718096),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "최고 $maxOxygen%",
                        style: const TextStyle(
                          fontSize: 18, // 12 * 1.5 = 18
                          color: Color(0xFF718096),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 우측 애니메이션 버블
            _AnimatedOxygenBubble(value: "$oxygen%"),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthData = ref.watch(healthDataProvider);
    final heart = healthData.currentHeartRate;
    final minHeart = healthData.minHeartRate;
    final maxHeart = healthData.maxHeartRate;
    final oxygen = healthData.currentSpo2;
    final minOxygen = healthData.minSpo2;
    final maxOxygen = healthData.maxSpo2;
    final steps = healthData.currentSteps;
    final battery = healthData.batteryLevel;
    final isCharging = healthData.isCharging;

    final kcal = (steps * 0.04).toStringAsFixed(1);

    // 최신 건강 데이터의 타임스탬프를 사용, 없으면 현재 시간
    final latestTimestamp = healthData.latest?.timestamp ?? DateTime.now();
    final dateText =
        "${latestTimestamp.year}.${latestTimestamp.month.toString().padLeft(2, '0')}.${latestTimestamp.day.toString().padLeft(2, '0')} ${latestTimestamp.hour.toString().padLeft(2, '0')}시";

    final isConnected = ref.watch(connectionStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isConnected
                    ? const Color(0xFF4299E1)
                    : Colors.grey.shade400,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: isConnected
                  ? const Color(0xFF4299E1)
                  : Colors.grey.shade500,
              size: 22,
            ),
          ),
        ),
        title: Text(
          "TODAY $dateText",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24, // 16 * 1.5 = 24
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          // 응급 알림 버튼
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: const Icon(
              Icons.notifications,
              size: 20,
              color: Colors.white,
            ),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF79ABC7), Color(0xFF6CA2C0)],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // 그라데이션 배경 영역
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF6CA2C0), Color(0xFFF7FAFC)],
                      stops: [0.0, 0.3],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      children: [
                        // 종합 건강 상태 카드
                        _buildSummaryCard(heart, steps, oxygen, kcal),
                        const SizedBox(height: 16),

                        // 심박수 카드
                        _buildHeartCard(heart, minHeart, maxHeart),
                        const SizedBox(height: 16),

                        // 걸음수 카드
                        _buildStepsCard(steps),
                        const SizedBox(height: 16),

                        // 산소포화도 카드
                        _buildOxygenCard(
                          oxygen,
                          minOxygen,
                          maxOxygen,
                          _getFormattedLastMeasurementTime(healthData.latest),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 60), // 바텀시트 공간 확보 (100 → 120)
              ],
            ),
          ),
          // 배터리 정보 바텀시트
          _ExpandableInfoSheet(battery: battery, isCharging: isCharging),
        ],
      ),
    );
  }
}

// 산소포화도 애니메이션 버블 (기존 코드 유지)
class _AnimatedOxygenBubble extends StatefulWidget {
  final String value;
  const _AnimatedOxygenBubble({required this.value});

  @override
  State<_AnimatedOxygenBubble> createState() => _AnimatedOxygenBubbleState();
}

class _AnimatedOxygenBubbleState extends State<_AnimatedOxygenBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: -10,
      end: 10,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        const double bubbleSize = 80;
        const double textFontSize = 20;
        return SizedBox(
          width: bubbleSize,
          height: bubbleSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: Offset(0, _animation.value),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: 0.9,
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                          child: Container(
                            width: bubbleSize,
                            height: bubbleSize,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: 0.95,
                                colors: [
                                  Color(0xFF26A0E4),
                                  Color(0xFF26A0E4),
                                  Color(0xFFB6E4FC),
                                  Color(0xFFFFFFFF),
                                  Colors.transparent,
                                ],
                                stops: [0.0, 0.4, 0.5, 0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      widget.value,
                      style: const TextStyle(
                        fontSize: textFontSize,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// 배터리 정보 바텀시트 (기존 코드 유지)
class _ExpandableInfoSheet extends StatefulWidget {
  final int battery;
  final bool isCharging;

  const _ExpandableInfoSheet({required this.battery, required this.isCharging});

  @override
  State<_ExpandableInfoSheet> createState() => _ExpandableInfoSheetState();
}

class _ExpandableInfoSheetState extends State<_ExpandableInfoSheet> {
  bool isExpanded = false;
  String? macAddress;
  String? userId;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfo = await DeviceStorage.getDeviceInfo();
      final userIdFromStorage = await TokenStorage.getUserId();

      setState(() {
        macAddress = deviceInfo?['id'] ?? '연결된 기기 없음';
        userId = userIdFromStorage ?? '로그인 필요';
      });
    } catch (e) {
      setState(() {
        macAddress = '정보 로드 실패';
        userId = '정보 로드 실패';
      });
    }
  }

  void toggle() => setState(() => isExpanded = !isExpanded);

  @override
  Widget build(BuildContext context) {
    const double collapsedHeight = 65;
    const double expandedHeight = 220; // 190 → 220으로 증가

    // 배터리 레벨에 따른 색상 시스템 개선
    Color getBatteryColor() {
      if (widget.battery >= 60) {
        return const Color(0xFF48BB78); // 60% 이상 - 초록색 (안전)
      } else if (widget.battery >= 30) {
        return const Color(0xFF26A0E4); // 30-59% - 파란색 (보통)
      } else if (widget.battery >= 15) {
        return const Color(0xFFDF7548); // 15-29% - 주황색 (주의)
      } else {
        return const Color(0xFFE53E3E); // 15% 미만 - 빨간색 (위험)
      }
    }

    String getBatteryStatus() {
      if (widget.battery >= 60) {
        return "충분";
      } else if (widget.battery >= 30) {
        return "보통";
      } else if (widget.battery >= 15) {
        return "부족";
      } else {
        return "위험";
      }
    }

    final batteryColor = getBatteryColor();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: isExpanded ? expandedHeight : collapsedHeight,
        child: GestureDetector(
          onTap: toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ), // 10 → 8로 감소
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border.all(
                color: batteryColor.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
                BoxShadow(
                  color: batteryColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: batteryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            widget.isCharging
                                ? Icons.battery_charging_full
                                : Icons.battery_full,
                            color: batteryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "남은 배터리 잔량",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: batteryColor,
                                fontSize: 24, // 16 * 1.5 = 24
                              ),
                            ),
                            Text(
                              getBatteryStatus(),
                              style: TextStyle(
                                fontSize: 18, // 12 * 1.5 = 18
                                color: batteryColor.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: batteryColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: batteryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        "${widget.battery}%",
                        style: const TextStyle(
                          fontSize: 30, // 20 * 1.5 = 30
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 10), // 14 → 10으로 감소
                  Container(
                    padding: const EdgeInsets.all(10), // 12 → 10으로 감소
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "연결된 링 MAC 주소",
                              style: TextStyle(
                                color: Color(0xFF6CA2C0),
                                fontSize: 18, // 12 * 1.5 = 18
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2), // 4 → 2로 감소
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            macAddress ?? '로딩 중...',
                            style: const TextStyle(
                              fontSize: 24, // 16 * 1.5 = 24
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF385A70),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8), // 10 → 8로 감소
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "사용자 ID",
                              style: TextStyle(
                                color: Color(0xFF6CA2C0),
                                fontSize: 18, // 12 * 1.5 = 18
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Icon(
                              Icons.person_outline,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2), // 4 → 2로 감소
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            userId ?? '로딩 중...',
                            style: const TextStyle(
                              fontSize: 24, // 16 * 1.5 = 24
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF385A70),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
