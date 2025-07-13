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

  void _goToDetail(BuildContext context, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OxygenDetailScreen()),
    );
  }

  void _callEmergency() async {
    const emergencyNumber = 'tel:119';
    if (await canLaunchUrl(Uri.parse(emergencyNumber))) {
      await launchUrl(Uri.parse(emergencyNumber));
    } else {
      debugPrint("전화 연결 실패");
    }
  }

  @override
  Widget build(BuildContext context) {
    final healthData = ref.watch(healthDataProvider);
    final heart = healthData.currentHeartRate;
    final minHeart = healthData.minHeartRate;
    final maxHeart = healthData.maxHeartRate;
    final oxygen = healthData.currentSpo2;
    final steps = healthData.currentSteps;
    final battery = healthData.batteryLevel;
    final isCharging = healthData.isCharging;

    final kcal = (steps * 0.04).toStringAsFixed(1);

    // 최신 건강 데이터의 타임스탬프를 사용, 없으면 현재 시간
    final latestTimestamp = healthData.latest?.timestamp ?? DateTime.now();
    final dateText =
        "${latestTimestamp.year}.${latestTimestamp.month.toString().padLeft(2, '0')}.${latestTimestamp.day.toString().padLeft(2, '0')} ${latestTimestamp.hour.toString().padLeft(2, '0')}시";

    final isConnected = ref.watch(connectionStateProvider);

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

    return Scaffold(
      body: Stack(
        children: <Widget>[
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.6837],
                colors: [Color(0xFF79ABC7), Colors.white],
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Top bar with emergency notification button and refresh button
                  Container(
                    height: 36,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 새로고침 버튼 (왼쪽)
                        Positioned(
                          left: 16,
                          top: 0,
                          child: IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () {
                              debugPrint('🔄 수동 새로고침 시작');
                              _loadLatestHealthData();
                            },
                          ),
                        ),
                        Positioned(
                          left: 0,
                          child: IconButton(
                            icon: const Icon(
                              Icons.science,
                              color: Colors.white,
                            ),
                            onPressed: () async {
                              final bleService = ref.read(bleServiceProvider);

                              if (!isConnected) {
                                final success = await bleService
                                    .tryReconnectFromSavedDevice();
                                if (!success) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('재연결에 실패했습니다.'),
                                      ),
                                    );
                                  }
                                  return;
                                }
                              }

                              await bleService.testBackgroundDataCollection();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('백그라운드 데이터 수집 테스트를 시작했습니다.'),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        Positioned(
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 6,
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(18),
                                bottomLeft: Radius.circular(18),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.notifications,
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content with proper padding
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Date and title
                        Text(
                          "TODAY $dateText",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Summary donut
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 8),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 80,
                                height: 80,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.blue.shade100,
                                      ),
                                    ),
                                    const Text(
                                      "정상",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.directions_walk,
                                          size: 16,
                                          color: Colors.blueGrey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "오늘 $steps보 걸음",
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.favorite,
                                          size: 16,
                                          color: Colors.redAccent,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "심박수 $heart bpm",
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.water_drop,
                                          size: 16,
                                          color: Colors.lightBlue,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "산소포화도 $oxygen%",
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.local_fire_department,
                                          size: 16,
                                          color: Colors.orange,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "칼로리 소모량: $kcal kcal",
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Card: Heart rate
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HeartDetailScreen(),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.only(
                              top: 0,
                              bottom: 0,
                              left: 20,
                              right: 0,
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              // Removed DecorationImage for heart background
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 8),
                              ],
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: SizedBox(
                              height: 72,
                              child: Stack(
                                children: [
                                  // Heart background image with left-to-right fade
                                  Positioned.fill(
                                    child: ShaderMask(
                                      shaderCallback: (Rect bounds) {
                                        return const LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black,
                                          ],
                                        ).createShader(bounds);
                                      },
                                      blendMode: BlendMode.dstIn,
                                      child: Image.asset(
                                        'assets/images/heart_background.png',
                                        fit: BoxFit.cover,
                                        alignment: Alignment.centerRight,
                                      ),
                                    ),
                                  ),
                                  // Decorative heart icon behind bpm text, upper-right
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 0,
                                        right: 4,
                                      ),
                                      child: Icon(
                                        Icons.favorite,
                                        color: getHeartColor(heart),
                                        size: 80,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        alignment: Alignment.centerLeft,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF99BCD0,
                                                  ),
                                                  width: 1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                color: const Color(0xFFFFFFFF),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.favorite,
                                                    color: Colors.redAccent,
                                                    size: 18,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    "심박",
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF6392AE),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              right: 25,
                                            ),
                                            child: Text.rich(
                                              TextSpan(
                                                text: "$heart\n",
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  height: 1.0,
                                                ),
                                                children: const [
                                                  TextSpan(
                                                    text: "bpm",
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Card: Steps
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StepsDetailScreen(),
                              ),
                            );
                          },
                          child: (() {
                            final kcal = (steps * 0.04).toStringAsFixed(1);
                            const int dailyGoal = 16000;
                            final double progress = steps / dailyGoal;
                            final double percent = (progress * 100).clamp(
                              0,
                              100,
                            );
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Bordered, rounded, light background label for "걸음"
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFFFF),
                                      border: Border.all(
                                        color: const Color(0xFF99BCD0),
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.directions_walk,
                                          color: Colors.blueGrey,
                                          size: 18,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          "걸음",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF6392AE),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Color(0xFF6392AE),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "보행 시간: 1h 21m",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6392AE),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.local_fire_department,
                                        size: 16,
                                        color: Color(0xFF6392AE),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "칼로리 소모량: $kcal kcal",
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6392AE),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.alt_route,
                                        size: 16,
                                        color: Color(0xFF6392AE),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "이동 거리: 5.41km",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6392AE),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.speed,
                                        size: 16,
                                        color: Color(0xFF6392AE),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "속도: 3.11km/h",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6392AE),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "걸음 목표 달성도",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF6392AE),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // Add Row with 0 and 100 labels above the progress bar
                                      const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "0",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFFA8E0FF),
                                            ),
                                          ),
                                          Text(
                                            "100",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFFA8E0FF),
                                            ),
                                          ),
                                        ],
                                      ),
                                      LinearProgressIndicator(
                                        value: progress.clamp(0, 1),
                                        minHeight: 8,
                                        backgroundColor: const Color.fromARGB(
                                          255,
                                          243,
                                          243,
                                          243,
                                        ),
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              Color(0xFFA8E0FF),
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${percent.toStringAsFixed(1)}%",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFA8E0FF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          })(),
                        ),
                        // Card: Oxygen
                        GestureDetector(
                          onTap: () => _goToDetail(context, "oxygen"),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 8),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Label with icon and box background (styled like "걸음"/"심박") - move to top left
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFFFF),
                                    border: Border.all(
                                      color: const Color(0xFF99BCD0),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.water_drop,
                                        color: Colors.lightBlue,
                                        size: 18,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "산소포화도",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF6392AE),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Row with 측정 시간 (left) and value (right)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _getFormattedLastMeasurementTime(
                                        healthData.latest,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF6CA2C0),
                                      ),
                                    ),
                                    // Animated oxygen percentage with blue gaseous circle
                                    _AnimatedOxygenBubble(value: "$oxygen%"),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _ExpandableInfoSheet(battery: battery, isCharging: isCharging),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Row(
            children: [
              Icon(
                isConnected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                color: isConnected ? Colors.blue : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isConnected ? '링이 연결되었습니다.' : '링이 연결되지 않았습니다.',
                  style: TextStyle(
                    color: isConnected ? Colors.black : Colors.grey,
                  ),
                ),
              ),
              // 측정 버튼 수정 -> 바로 측정
              ElevatedButton(
                onPressed: () async {
                  final bleService = ref.read(bleServiceProvider);
                  final isConnectedNow = ref.read(connectionStateProvider);

                  // Attempt reconnection only when not connected
                  if (!isConnectedNow) {
                    final success = await bleService
                        .tryReconnectFromSavedDevice();
                    if (!success) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('재연결에 실패했습니다.')),
                        );
                      }
                      return;
                    }
                  }

                  // Connected, request instant measurement
                  await bleService.startInstantHealthMeasurement();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('즉시 측정을 시작했습니다.')),
                    );
                  }
                },
                child: const Text('바로 측정'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final bleService = ref.read(bleServiceProvider);
                  final isConnectedNow = ref.read(connectionStateProvider);

                  if (!isConnectedNow) {
                    final success = await bleService
                        .tryReconnectFromSavedDevice();
                    if (!success) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('재연결에 실패했습니다.')),
                        );
                      }
                      return;
                    }
                  }

                  try {
                    await bleService.requestCurrentData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('현재 데이터를 요청했습니다.')),
                      );
                    }
                  } catch (_) {}
                },
                child: const Text('수신'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final bleService = ref.read(bleServiceProvider);
                  final isConnectedNow = ref.read(connectionStateProvider);

                  if (!isConnectedNow) {
                    final success = await bleService
                        .tryReconnectFromSavedDevice();
                    if (!success) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('재연결에 실패했습니다.')),
                        );
                      }
                      return;
                    }
                  }

                  try {
                    await bleService.resetDeviceData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('기기 데이터를 초기화했습니다.')),
                      );
                    }
                  } catch (_) {}
                },
                child: const Text('초기화'),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// Animated oxygen bubble widget using AnimationController loop
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
        // Enlarge the bubble significantly
        const double bubbleSize = 120;
        const double textFontSize = 30;
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
                                  Color(0xFF26A0E4), // Center blue
                                  Color(0xFF26A0E4), // Strong blue
                                  Color(0xFFB6E4FC), // Light blue
                                  Color(
                                    0xFFFFFFFF,
                                  ), // Fade to white (soft glow)
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

// ExpandableInfoSheet widget as a bottom panel
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
    const double collapsedHeight = 59.5; // 70의 15% 감소 (70 * 0.85)
    const double expandedHeight = 153; // 180의 15% 감소 (180 * 0.85)

    // Battery level logic
    final Color batteryColor = widget.battery < 20
        ? Colors.red
        : widget.battery < 50
        ? Colors.yellow
        : const Color(0xFF6CA2C0);

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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, -2),
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
                        Icon(
                          widget.isCharging
                              ? Icons.battery_charging_full
                              : Icons.battery_full,
                          color: batteryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "남은 배터리 잔량",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: batteryColor,
                            fontSize: 25,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "${widget.battery}%",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: batteryColor,
                      ),
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  const Text(
                    "연결된 링 MAC 주소",
                    style: TextStyle(color: Color(0xFF6CA2C0), fontSize: 14),
                  ),
                  Text(
                    macAddress ?? '로딩 중...',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF385A70),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "사용자 ID",
                    style: TextStyle(color: Color(0xFF6CA2C0), fontSize: 14),
                  ),
                  Text(
                    userId ?? '로딩 중...',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF385A70),
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
