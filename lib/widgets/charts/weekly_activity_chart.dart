import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/theme/app_theme.dart';

import '../../services/stats_service.dart';

enum ConsistencyTimeframe {
  weeks4(4, 'Last 4 Weeks'),
  weeks8(8, 'Last 8 Weeks'),
  weeks12(12, 'Last 12 Weeks');

  final int weeks;
  final String label;
  const ConsistencyTimeframe(this.weeks, this.label);
}

class WeeklyActivityChart extends StatefulWidget {
  final int initialWeeksCount;

  const WeeklyActivityChart({super.key, this.initialWeeksCount = 8});

  @override
  State<WeeklyActivityChart> createState() => _WeeklyActivityChartState();
}

class _WeeklyActivityChartState extends State<WeeklyActivityChart> {
  late ConsistencyTimeframe _selectedTimeframe;

  @override
  void initState() {
    super.initState();
    // Inițializăm starea pe baza opțiunii celei mai apropiate de prop-ul primit
    _selectedTimeframe = ConsistencyTimeframe.values.firstWhere(
      (e) => e.weeks == widget.initialWeeksCount,
      orElse: () => ConsistencyTimeframe.weeks8,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final int weeksCount = _selectedTimeframe.weeks;
    final data = StatsService.getWorkoutsPerWeek(weeksCount);

    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    // Găsim numărul maxim de antrenamente într-o săptămână pentru a scala axa Y
    final double maxWorkouts = data.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();
    // Ne asigurăm că avem o valoare minimă rezonabilă pe axa Y (ex: măcar 4 bare de ghidaj)
    final double yLimit = maxWorkouts < 4 ? 4 : maxWorkouts + 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderMuted),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header cu titlu + Dropdown Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Consistency ⚡',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              // Dropdown subtil
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: context.bgLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ConsistencyTimeframe>(
                    value: _selectedTimeframe,
                    icon: Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.primary),
                    dropdownColor: context.bgLight,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    onChanged: (ConsistencyTimeframe? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedTimeframe = newValue;
                        });
                      }
                    },
                    items: ConsistencyTimeframe.values.map((ConsistencyTimeframe tf) {
                      return DropdownMenuItem<ConsistencyTimeframe>(
                        value: tf,
                        child: Text(tf.label),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: yLimit,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 12,
                    getTooltipColor: (group) => context.bgLight,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      // Extragere interval complet din cheie (ex: "15 Jul - 21 Jul")
                      final parts = data[groupIndex].key.split('|');
                      final startLabel = parts.first;
                      final endLabel = parts.length > 1 ? parts.last : '';

                      final String dateRange = '$startLabel - $endLabel';
                      final int count = rod.toY.toInt();

                      return BarTooltipItem(
                        '$dateRange\n',
                        TextStyle(
                          color: context.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: '$count workout${count == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: context.textMuted,
                              fontWeight: FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final int index = value.toInt();
                          if (index < 0 || index >= data.length) return const SizedBox.shrink();

                          // Ascundem etichetele intermediare dacă sunt prea multe săptămâni pentru a evita suprapunerea
                          if (data.length > 6 && index % 2 != 0) return const SizedBox.shrink();

                          // Spargem cheia ca să luăm doar data de start "15 Jul"
                          final startLabel = data[index].key.split('|').first;

                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 8,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                startLabel,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        // Afișăm doar numere întregi pe axa Y
                        if (value % 1 != 0) return const SizedBox.shrink();
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: context.textMuted.withOpacity(0.1), strokeWidth: 1, dashArray: null),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(data.length, (index) {
                  final int workoutsCount = data[index].value;
                  final Color separatorColor = context.text.withOpacity(0.5);
                  const double separatorThicknes = 0.8;

                  // Ajustăm lățimea barei în funcție de numărul de săptămâni afișate
                  final double barWidth = weeksCount > 8 ? 10 : 16;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: workoutsCount.toDouble(),
                        width: barWidth,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        color: workoutsCount > 0
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant.withOpacity(0.3),
                        rodStackItems: workoutsCount == 0
                            ? []
                            : List.generate(workoutsCount * 2 - 1, (stackIndex) {
                                final isSeparator = stackIndex % 2 != 0;
                                final int segmentIdx = stackIndex ~/ 2;

                                if (isSeparator) {
                                  return BarChartRodStackItem(
                                    segmentIdx + 1 - (separatorThicknes / 10),
                                    segmentIdx + 1,
                                    separatorColor,
                                  );
                                } else {
                                  return BarChartRodStackItem(
                                    segmentIdx.toDouble(),
                                    (segmentIdx + 1) - (segmentIdx < workoutsCount - 1 ? (separatorThicknes / 10) : 0),
                                    theme.colorScheme.primary,
                                  );
                                }
                              }),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: yLimit,
                          color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.5),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}