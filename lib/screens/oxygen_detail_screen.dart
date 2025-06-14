import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  // 산소포화도 상태에 따른 색상 반환
  Color _getOxygenStatusColor(int spo2) {
    if (spo2 >= 95) {
      return const Color(0xFF26A0E4); // 정상
    } else if (spo2 >= 90) {
      return const Color(0xFFDF7548); // 주의
    } else {
      return const Color(0xFFE92430); // 심각
    }
  }

  // 산소포화도 상태 텍스트 반환
  String _getOxygenStatusText(int spo2) {
    if (spo2 >= 95) {
      return "정상";
    } else if (spo2 >= 90) {
      return "저산소증 주의";
    } else {
      return "저산소증 심각";
    }
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
          return entry.spo2;
        }

        // 최대값 계산 (차트의 maxY 값)
        double maxValue = 100; // 산소포화도는 항상 100이 최대

        // 텍스트 위치 계산을 위한 Y 오프셋
        double getTextYOffset(int value) {
          final ratio = value / maxValue;
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
                  "${getCurrentValue(entries[i])}%",
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
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        maxY: 100,
        minY: 80, // 산소포화도는 보통 80% 이하로 떨어지지 않음
        barGroups: entries
            .map(
              (e) => BarChartGroupData(
                x: entries.indexOf(e),
                barRods: [
                  BarChartRodData(
                    fromY: 80,
                    toY: e.spo2.toDouble(),
                    width: 16,
                    color: _getOxygenStatusColor(e.spo2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
            )
            .toList(),
        backgroundColor: Colors.white,
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
    final currentSpo2 = healthData.currentSpo2;
    final statusColor = _getOxygenStatusColor(currentSpo2);
    final statusText = _getOxygenStatusText(currentSpo2);

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
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                child: Container(
                  width: double.infinity,
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 24),
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
                            Icon(Icons.water_drop, color: Color(0xFF6CA2C0)),
                            SizedBox(width: 8),
                            Text(
                              "산소포화도",
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
                      // Animated oxygen bubble
                      SizedBox(
                        height: 160,
                        child: _AnimatedOxygenBubble(
                          value: "$currentSpo2%",
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Status text
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
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

// Animated oxygen bubble widget
class _AnimatedOxygenBubble extends StatefulWidget {
  final String value;
  final Color color;

  const _AnimatedOxygenBubble({required this.value, required this.color});

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
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: 0.95,
                                colors: [
                                  widget.color,
                                  widget.color,
                                  widget.color.withOpacity(0.5),
                                  widget.color.withOpacity(0.2),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.4, 0.5, 0.7, 1.0],
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
