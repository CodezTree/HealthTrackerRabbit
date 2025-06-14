import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
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

  static const int dailyGoal = 10000; // 일일 목표 걸음수

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
        final effectiveChartHeight = constraints.maxHeight * 0.9;
        const textOffset = 40.0;

        // 현재 값을 계산하는 함수
        int getCurrentValue(HealthEntry entry) {
          if (_tabController.index == 2) {
            return (entry.stepCount /
                    DateTime(
                      entry.timestamp.year,
                      entry.timestamp.month + 1,
                      0,
                    ).day)
                .round();
          }
          return entry.stepCount;
        }

        // 최대값 계산 (차트의 maxY 값)
        double maxValue = 0;
        for (var entry in entries) {
          final currentValue = getCurrentValue(entry).toDouble();
          if (currentValue > maxValue) {
            maxValue = currentValue;
          }
        }
        final graphMaxY = (maxValue * 1.25).ceilToDouble();

        // 텍스트 위치 계산을 위한 Y 오프셋
        double getTextYOffset(int value) {
          final ratio = value / graphMaxY;
          return (ratio * effectiveChartHeight) + textOffset;
        }

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildBarChart(entries),
            ),
            for (int i = 0; i < entries.length; i++) ...[
              Positioned(
                left: barGap * i * 2 + barGap + 12,
                bottom: getTextYOffset(getCurrentValue(entries[i])),
                child: Text(
                  "${getCurrentValue(entries[i])}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6098B8),
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
    // 현재 데이터의 최대값 계산
    double maxValue = 0;
    for (var entry in entries) {
      final currentValue = _tabController.index == 2
          ? (entry.stepCount /
                    DateTime(
                      entry.timestamp.year,
                      entry.timestamp.month + 1,
                      0,
                    ).day)
                .toDouble()
          : entry.stepCount.toDouble();
      if (currentValue > maxValue) {
        maxValue = currentValue;
      }
    }

    // 최대값의 1.25배를 maxY로 설정
    maxValue = (maxValue * 1.25).ceilToDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        maxY: maxValue,
        minY: 0,
        barGroups: entries
            .map(
              (e) => BarChartGroupData(
                x: entries.indexOf(e),
                barRods: [
                  BarChartRodData(
                    fromY: 0,
                    toY: _tabController.index == 2
                        ? (e.stepCount /
                              DateTime(
                                e.timestamp.year,
                                e.timestamp.month + 1,
                                0,
                              ).day)
                        : e.stepCount.toDouble(),
                    width: 16,
                    color: const Color(0xFF6CA2C0),
                    borderRadius: BorderRadius.circular(6),
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
    final currentSteps = healthData.currentSteps;
    final progress = currentSteps / dailyGoal;
    final remainingSteps = dailyGoal - currentSteps;
    final kcal = (currentSteps * 0.04).toStringAsFixed(1);
    final distance = (currentSteps * 0.0007).toStringAsFixed(2);

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
                          Icon(Icons.directions_walk, color: Color(0xFF6CA2C0)),
                          SizedBox(width: 8),
                          Text(
                            "걸음수",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6CA2C0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Steps progress
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 160,
                          height: 160,
                          child: CircularProgressIndicator(
                            value: progress,
                            backgroundColor: const Color(0xFFE8F3FA),
                            color: const Color(0xFF6CA2C0),
                            strokeWidth: 12,
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              "$currentSteps",
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF385A70),
                              ),
                            ),
                            const Text(
                              "걸음",
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF6CA2C0),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Remaining steps
                    Text(
                      "목표까지 $remainingSteps 걸음",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6CA2C0),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StepsStat(
                          icon: Icons.local_fire_department,
                          value: kcal,
                          unit: "kcal",
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey.shade300,
                        ),
                        _StepsStat(
                          icon: Icons.straighten,
                          value: distance,
                          unit: "km",
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
                        physics: const NeverScrollableScrollPhysics(),
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

class _StepsStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;

  const _StepsStat({
    required this.icon,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF6CA2C0), size: 24),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 16, color: Color(0xFF385A70)),
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: " $unit"),
            ],
          ),
        ),
      ],
    );
  }
}
