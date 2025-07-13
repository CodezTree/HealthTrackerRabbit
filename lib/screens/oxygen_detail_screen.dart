import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rabbithole_health_tracker_new/models/health_entry.dart';
import 'package:rabbithole_health_tracker_new/providers/health_provider.dart';

class OxygenDetailScreen extends ConsumerStatefulWidget {
  const OxygenDetailScreen({super.key});

  @override
  ConsumerState<OxygenDetailScreen> createState() => _OxygenDetailScreenState();
}

class _OxygenDetailScreenState extends ConsumerState<OxygenDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 차트 데이터 상태
  List<HealthEntry> dailyData = [];
  List<HealthEntry> weeklyData = [];
  List<HealthEntry> monthlyData = [];
  bool isLoading = true;

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

  // 산소포화도 상태에 따른 색상 반환
  Color getOxygenColor(int spo2) {
    if (spo2 >= 95) {
      return const Color(0xFF26A0E4); // 정상 - 파란색
    } else if (spo2 >= 90) {
      return const Color(0xFFDF7548); // 주의 - 주황색
    } else {
      return const Color(0xFFE92430); // 심각 - 빨간색
    }
  }

  // 산소포화도 상태 텍스트 반환
  String getOxygenStatus(int spo2) {
    if (spo2 >= 95) {
      return "정상";
    } else if (spo2 >= 90) {
      return "저산소증 주의";
    } else {
      return "저산소증 심각";
    }
  }

  Widget _buildCurrentOxygenCard(int currentSpo2, int minSpo2, int maxSpo2) {
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
              color: getOxygenColor(currentSpo2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.water_drop,
                  color: getOxygenColor(currentSpo2),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  "오늘의 산소포화도",
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

          // 메인 산소포화도 표시
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  getOxygenColor(currentSpo2).withOpacity(0.1),
                  getOxygenColor(currentSpo2).withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: getOxygenColor(currentSpo2).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 진행률 바 (80-100% 범위)
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: (currentSpo2 - 80) / 20, // 80-100% 범위를 0-1로 변환
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      getOxygenColor(currentSpo2),
                    ),
                    strokeWidth: 8,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "$currentSpo2",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: getOxygenColor(currentSpo2),
                      ),
                    ),
                    Text(
                      "%",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: getOxygenColor(currentSpo2).withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: getOxygenColor(currentSpo2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        getOxygenStatus(currentSpo2),
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
                  value: minSpo2,
                  icon: Icons.keyboard_arrow_down,
                  color: const Color(0xFFE53E3E),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMinMaxCard(
                  label: "오늘 최고",
                  value: maxSpo2,
                  icon: Icons.keyboard_arrow_up,
                  color: const Color(0xFF48BB78),
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
            "$value%",
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
              Icon(Icons.water_drop_outlined, size: 48, color: Colors.grey),
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

    final progress = (entry.spo2 - 80) / 20; // 80-100% 범위를 0-1로 변환
    final oxygenColor = getOxygenColor(entry.spo2);

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

          // 산소포화도 바
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${entry.spo2}%",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: oxygenColor,
                      ),
                    ),
                    Text(
                      getOxygenStatus(entry.spo2),
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
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: oxygenColor,
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
          Icon(Icons.water_drop, color: oxygenColor, size: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthData = ref.watch(healthDataProvider);
    final currentSpo2 = healthData.currentSpo2;
    final minSpo2 = healthData.minSpo2;
    final maxSpo2 = healthData.maxSpo2;

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
          "산소포화도 상세",
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
                child: _buildCurrentOxygenCard(currentSpo2, minSpo2, maxSpo2),
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
