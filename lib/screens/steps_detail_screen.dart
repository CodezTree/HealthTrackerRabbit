import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rabbithole_health_tracker_new/models/health_entry.dart';
import 'package:rabbithole_health_tracker_new/providers/health_provider.dart';

class StepsDetailScreen extends ConsumerStatefulWidget {
  const StepsDetailScreen({super.key});

  @override
  ConsumerState<StepsDetailScreen> createState() => _StepsDetailScreenState();
}

class _StepsDetailScreenState extends ConsumerState<StepsDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 차트 데이터 상태
  List<HealthEntry> dailyData = [];
  List<HealthEntry> weeklyData = [];
  List<HealthEntry> monthlyData = [];
  bool isLoading = true;

  static const int dailyGoal = 10000; // 일일 목표 걸음수

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadChartData();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Color getStepsColor(int steps) {
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

  String getStepsStatus(int steps) {
    if (steps >= dailyGoal) {
      return "목표 달성!";
    } else if (steps >= dailyGoal * 0.7) {
      return "잘하고 있어요";
    } else if (steps >= dailyGoal * 0.5) {
      return "조금 더 걸어봐요";
    } else {
      return "더 활발하게!";
    }
  }

  Widget _buildCurrentStepsCard(int currentSteps) {
    final progress = (currentSteps / dailyGoal).clamp(0.0, 1.0);
    final remainingSteps = dailyGoal - currentSteps;
    final kcal = (currentSteps * 0.04).toStringAsFixed(1);
    final distance = (currentSteps * 0.0007).toStringAsFixed(2);

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
              color: getStepsColor(currentSteps).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.directions_walk,
                  color: getStepsColor(currentSteps),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  "오늘의 걸음수",
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

          // 메인 걸음수 표시
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  getStepsColor(currentSteps).withOpacity(0.1),
                  getStepsColor(currentSteps).withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: getStepsColor(currentSteps).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 진행률 바
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      getStepsColor(currentSteps),
                    ),
                    strokeWidth: 8,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "$currentSteps",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: getStepsColor(currentSteps),
                      ),
                    ),
                    Text(
                      "걸음",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: getStepsColor(currentSteps).withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: getStepsColor(currentSteps),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        getStepsStatus(currentSteps),
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
          const SizedBox(height: 16),

          // 목표까지 남은 걸음수
          if (remainingSteps > 0)
            Text(
              "목표까지 $remainingSteps 걸음",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: getStepsColor(currentSteps).withOpacity(0.8),
              ),
            )
          else
            Text(
              "목표를 달성했어요! 🎉",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: getStepsColor(currentSteps),
              ),
            ),
          const SizedBox(height: 24),

          // 칼로리 및 거리 정보
          Row(
            children: [
              Expanded(
                child: _buildStatsCard(
                  label: "칼로리",
                  value: kcal,
                  unit: "kcal",
                  icon: Icons.local_fire_department,
                  color: const Color(0xFFE53E3E),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatsCard(
                  label: "거리",
                  value: distance,
                  unit: "km",
                  icon: Icons.straighten,
                  color: const Color(0xFF4299E1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard({
    required String label,
    required String value,
    required String unit,
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
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 16, color: color),
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: " $unit"),
              ],
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
              Icon(
                Icons.directions_walk_outlined,
                size: 48,
                color: Colors.grey,
              ),
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

    // 월간 데이터의 경우 일평균 계산
    final displaySteps = tabIndex == 2
        ? (entry.stepCount /
                  DateTime(
                    entry.timestamp.year,
                    entry.timestamp.month + 1,
                    0,
                  ).day)
              .round()
        : entry.stepCount;

    final progress = (displaySteps / dailyGoal).clamp(0.0, 1.0);
    final stepColor = getStepsColor(displaySteps);

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

          // 걸음수 바
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${displaySteps.toStringAsFixed(0)} 걸음",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: stepColor,
                      ),
                    ),
                    Text(
                      "${(progress * 100).toStringAsFixed(0)}%",
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
                      // 진행률 바
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: stepColor,
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
          Icon(Icons.directions_walk, color: stepColor, size: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthData = ref.watch(healthDataProvider);
    final currentSteps = healthData.currentSteps;

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
          "걸음수 상세",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
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
      body: SingleChildScrollView(
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
                child: _buildCurrentStepsCard(currentSteps),
              ),
            ),

            // 탭 및 데이터 표시 영역
            Container(
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
                  // 탭 바
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
                        fontSize: 16,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
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

                  // 탭 내용
                  SizedBox(
                    height: 400,
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
