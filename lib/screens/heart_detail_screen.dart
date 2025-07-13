import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rabbithole_health_tracker_new/models/health_entry.dart';
import 'package:rabbithole_health_tracker_new/providers/health_provider.dart';

class HeartDetailScreen extends ConsumerStatefulWidget {
  const HeartDetailScreen({super.key});

  @override
  ConsumerState<HeartDetailScreen> createState() => _HeartDetailScreenState();
}

class _HeartDetailScreenState extends ConsumerState<HeartDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _heartAnimationController;
  late Animation<double> _heartAnimation;

  // 차트 데이터 상태
  List<HealthEntry> dailyData = [];
  List<HealthEntry> weeklyData = [];
  List<HealthEntry> monthlyData = [];
  bool isLoading = true;

  // Add heart rate thresholds
  static const int normalThreshold = 100;
  static const int highThreshold = 120;

  // Function to determine heart color based on BPM
  Color getHeartColor(int bpm) {
    if (bpm <= normalThreshold) {
      return const Color(0xFF6CA2C0); // 정상수치
    } else if (bpm <= highThreshold) {
      return const Color(0xFFDF7548); // 약간 높음
    } else {
      return const Color(0xFFE92430); // 매우 높음
    }
  }

  String getHeartStatus(int bpm) {
    if (bpm <= normalThreshold) {
      return "정상"; // 정상수치
    } else if (bpm <= highThreshold) {
      return "약간 높음"; // 약간 높음
    } else {
      return "매우 높음"; // 매우 높음
    }
  }

  void _updateHeartAnimation(int heartRate) {
    // 심박수에 따라 애니메이션 속도 조절 (60-200 BPM 범위)
    // 정상 심박수 60-100bpm -> 1.0-1.5초 주기
    // 높은 심박수 100-200bpm -> 0.6-1.0초 주기
    double animationDuration;
    if (heartRate <= 60) {
      animationDuration = 1.5;
    } else if (heartRate <= 100) {
      animationDuration = 1.5 - (heartRate - 60) * 0.5 / 40; // 1.5 -> 1.0
    } else {
      animationDuration = 1.0 - (heartRate - 100) * 0.4 / 100; // 1.0 -> 0.6
    }

    _heartAnimationController.duration = Duration(
      milliseconds: (animationDuration * 1000).round(),
    );
    _heartAnimationController.repeat(reverse: true);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // 하트 애니메이션 컨트롤러 초기화
    _heartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // 하트 크기 애니메이션 (0.8배 ~ 1.2배)
    _heartAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _heartAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _loadChartData();

    // 기본 애니메이션 시작
    _heartAnimationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _heartAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadChartData() async {
    setState(() {
      isLoading = true;
    });

    final healthNotifier = ref.read(healthDataProvider.notifier);

    try {
      final daily = await healthNotifier.getDailyData();
      final weekly = await healthNotifier.getWeeklyData();
      final monthly = await healthNotifier.getMonthlyData();

      setState(() {
        dailyData = daily;
        weeklyData = weekly;
        monthlyData = monthly;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('차트 데이터 로드 오류: $e');
    }
  }

  Widget _buildCurrentHeartCard(int currentHeart, int minHeart, int maxHeart) {
    // 심박수 변경시 애니메이션 업데이트
    _updateHeartAnimation(currentHeart);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
              color: getHeartColor(currentHeart).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite,
                  color: getHeartColor(currentHeart),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  "오늘의 심박수",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 메인 심박수 표시
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  getHeartColor(currentHeart).withOpacity(0.1),
                  getHeartColor(currentHeart).withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: getHeartColor(currentHeart).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 애니메이션 적용된 하트 아이콘
                AnimatedBuilder(
                  animation: _heartAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _heartAnimation.value,
                      child: Icon(
                        Icons.favorite,
                        size: 80,
                        color: getHeartColor(currentHeart).withOpacity(0.3),
                      ),
                    );
                  },
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "$currentHeart",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: getHeartColor(currentHeart),
                      ),
                    ),
                    Text(
                      "BPM",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: getHeartColor(currentHeart).withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: getHeartColor(currentHeart),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        getHeartStatus(currentHeart),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 최대/최소 표시
          Row(
            children: [
              Expanded(
                child: _buildMinMaxCard(
                  label: "오늘 최저",
                  value: minHeart,
                  icon: Icons.keyboard_arrow_down,
                  color: const Color(0xFF4299E1),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMinMaxCard(
                  label: "오늘 최고",
                  value: maxHeart,
                  icon: Icons.keyboard_arrow_up,
                  color: const Color(0xFFE53E3E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMinMaxCard({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            "$value",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataView(List<HealthEntry> entries, int tabIndex) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.heart_broken, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "데이터가 없습니다",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _buildDataCard(entry, tabIndex, index);
      },
    );
  }

  Widget _buildDataCard(HealthEntry entry, int tabIndex, int index) {
    String timeLabel;
    if (tabIndex == 0) {
      timeLabel = "${entry.timestamp.hour.toString().padLeft(2, '0')}:00";
    } else if (tabIndex == 1) {
      const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
      timeLabel = weekdays[entry.timestamp.weekday - 1];
    } else {
      timeLabel = "${entry.timestamp.month}월";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 시간 표시
          SizedBox(
            width: 60,
            child: Text(
              timeLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A5568),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // 심박수 바
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${entry.heartRate} BPM",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: getHeartColor(entry.heartRate),
                      ),
                    ),
                    Text(
                      "${entry.minHeartRate}-${entry.maxHeartRate}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: Colors.grey.shade200,
                  ),
                  child: Stack(
                    children: [
                      // 심박수 바
                      FractionallySizedBox(
                        widthFactor: (entry.heartRate / 200).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: getHeartColor(entry.heartRate),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 상태 표시
          Icon(Icons.favorite, color: getHeartColor(entry.heartRate), size: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthData = ref.watch(healthDataProvider);
    final currentHeart = healthData.currentHeartRate;
    final minHeart = healthData.minHeartRate;
    final maxHeart = healthData.maxHeartRate;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "심박수 상세",
          style: TextStyle(
            color: Colors.white,
            fontSize: 27, // 18 * 1.5 = 27
            fontWeight: FontWeight.w600,
          ),
        ),
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
      body: Column(
        children: [
          // 그라데이션 배경 영역 (고정)
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
              child: _buildCurrentHeartCard(currentHeart, minHeart, maxHeart),
            ),
          ),

          // 탭 및 데이터 표시 영역 (확장 가능)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                  // 탭 바 (고정)
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF6CA2C0),
                      unselectedLabelColor: const Color(0xFF718096),
                      indicatorColor: const Color(0xFF6CA2C0),
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 24, // 16 * 1.5 = 24
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 24, // 16 * 1.5 = 24
                      ),
                      onTap: (index) {
                        setState(() {
                          // 탭 변경 시 UI 업데이트
                        });
                      },
                      tabs: const [
                        Tab(text: "오늘"),
                        Tab(text: "주간"),
                        Tab(text: "월간"),
                      ],
                    ),
                  ),

                  // 탭 내용 (스크롤 가능)
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDataView(dailyData, 0),
                        _buildDataView(weeklyData, 1),
                        _buildDataView(monthlyData, 2),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
