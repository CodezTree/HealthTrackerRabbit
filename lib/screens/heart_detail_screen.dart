import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:rabbithole_health_tracker_new/models/health_entry.dart';
import 'package:rabbithole_health_tracker_new/providers/health_provider.dart';

class HeartDetailScreen extends ConsumerStatefulWidget {
  const HeartDetailScreen({super.key});

  @override
  ConsumerState<HeartDetailScreen> createState() => _HeartDetailScreenState();
}

class _HeartDetailScreenState extends ConsumerState<HeartDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const double maxY = 200;
  static const double minY = 200;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  Widget _buildChartView(List<HealthEntry> entries) {
    if (entries.isEmpty) {
      return const Center(child: Text("데이터가 없습니다 🥲"));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth - 52;
        final barGap = chartWidth / (entries.length * 2);
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildBarChart(entries),
            ),
            for (int i = 0; i < entries.length; i++) ...[
              Positioned(
                left: barGap * i * 2 + barGap + 18,
                bottom:
                    200 / (maxY + minY) * entries[i].maxHeartRate + 160 + 12,
                child: Text(
                  "${entries[i].maxHeartRate}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6098B8),
                  ),
                ),
              ),
              Positioned(
                left: barGap * i * 2 + barGap + 18,
                top: 200 / (maxY + minY) * entries[i].minHeartRate + 140 + 4,
                child: Text(
                  "${entries[i].minHeartRate}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF73B7DC),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBarChart(List<HealthEntry> entries) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        maxY: maxY,
        minY: -minY,
        barGroups: entries
            .map(
              (e) => BarChartGroupData(
                x: entries.indexOf(e),
                barRods: [
                  BarChartRodData(
                    fromY: -minY,
                    toY: maxY,
                    width: 16,
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    rodStackItems: [
                      BarChartRodStackItem(
                        -minY,
                        -e.minHeartRate.toDouble(),
                        Colors.transparent,
                      ),
                      BarChartRodStackItem(
                        -e.minHeartRate.toDouble(),
                        0,
                        const Color(0xFFA8E0FF),
                      ),
                      BarChartRodStackItem(
                        0,
                        e.maxHeartRate.toDouble(),
                        const Color(0xFF6CA2C0),
                      ),
                      BarChartRodStackItem(
                        e.maxHeartRate.toDouble(),
                        maxY,
                        Colors.transparent,
                      ),
                    ],
                  ),
                ],
              ),
            )
            .toList(),
        backgroundColor: Colors.white,
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(y: 0, color: Colors.grey.shade300, strokeWidth: 1),
          ],
        ),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, _) {
                int idx = value.toInt();
                if (idx >= entries.length) return const Text('');
                final dt = entries[idx].timestamp;
                if (_tabController.index == 0) {
                  return Text(
                    "${dt.hour.toString().padLeft(2, '0')}:00",
                    style: const TextStyle(fontSize: 10),
                  );
                } else if (_tabController.index == 1) {
                  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
                  return Text(
                    weekdays[dt.weekday - 1],
                    style: const TextStyle(fontSize: 10),
                  );
                } else {
                  return Text(
                    "${dt.month}월",
                    style: const TextStyle(fontSize: 10),
                  );
                }
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: false),
        groupsSpace: 0,
      ),
      swapAnimationDuration: Duration.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthData = ref.watch(healthDataProvider);
    final currentHeart = healthData.currentHeartRate;
    final minHeart = healthData.minHeartRate;
    final maxHeart = healthData.maxHeartRate;

    return Scaffold(
      body: Container(
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
            children: [
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Top title bar with icon and label
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F8FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite, color: Color(0xFF6CA2C0)),
                          SizedBox(width: 8),
                          Text(
                            "심박",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6CA2C0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Left-aligned large heart & bpm, right-aligned heart legend
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    size: 120,
                                    color: getHeartColor(currentHeart),
                                  ),
                                  Text(
                                    "$currentHeart\nbpm",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      height: 0.8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(width: 24),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _HeartLevel(
                                  color: Color(0xFF6CA2C0),
                                  label: "정상수치",
                                ),
                                SizedBox(height: 8),
                                _HeartLevel(
                                  color: Color(0xFFDF7548),
                                  label: "약간 높음",
                                ),
                                SizedBox(height: 8),
                                _HeartLevel(
                                  color: Color(0xFFE92430),
                                  label: "매우 높음",
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // EKG image
                    Container(
                      width: double.infinity,
                      height: 80,
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      child: Image.asset(
                        'assets/images/heart_background.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Min/Max display
                    const Text(
                      "3시간\n최저 / 최고 심박",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: Color(0xFF6392AE),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.favorite,
                              size: 84,
                              color: getHeartColor(minHeart),
                            ),
                            Text(
                              "$minHeart\nbpm",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                height: 0.9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.favorite,
                              size: 84,
                              color: getHeartColor(maxHeart),
                            ),
                            Text(
                              "$maxHeart\nbpm",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                height: 0.9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Tabs and chart
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF6CA2C0),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFF6CA2C0),
                      tabs: const [
                        Tab(text: "오늘"),
                        Tab(text: "주간"),
                        Tab(text: "월간"),
                      ],
                    ),
                    SizedBox(
                      height: 280,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildChartView(healthData.today),
                          _buildChartView(healthData.week),
                          _buildChartView(healthData.month),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Heart legend widget
class _HeartLevel extends StatelessWidget {
  final Color color;
  final String label;

  const _HeartLevel({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.favorite, size: 24, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ],
    );
  }
}
