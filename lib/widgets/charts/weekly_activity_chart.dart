import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/theme/app_theme.dart';

import '../../services/stats_service.dart';

class WeeklyActivityChart extends StatelessWidget {
  final int weeksCount;

  const WeeklyActivityChart({super.key, this.weeksCount = 8});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              Text(
                'Last $weeksCount Weeks',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
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

                          if (data.length > 4 && index % 2 != 0) return const SizedBox.shrink();

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

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: workoutsCount.toDouble(),
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        // Culoarea de bază a barei (va fi vizibilă doar dacă sunt 0 antrenamente, ca o schiță)
                        color: workoutsCount > 0
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant.withOpacity(0.3),

                        // 💡 MAGIC ZONE: Segmentăm bara folosind stack-uri!
                        rodStackItems: workoutsCount == 0
                            ? [] // Dacă nu avem antrenamente, nu desenăm segmente
                            : List.generate(workoutsCount * 2 - 1, (stackIndex) {
                                // Generăm alternativ: segment de culoare -> linie de separare -> segment de culoare
                                final isSeparator = stackIndex % 2 != 0;
                                final int segmentIdx = stackIndex ~/ 2;

                                if (isSeparator) {
                                  // Acesta este „rostul” dintre cărămizi
                                  return BarChartRodStackItem(
                                    segmentIdx + 1 - (separatorThicknes / 10), // start
                                    segmentIdx + 1, // end
                                    separatorColor,
                                  );
                                } else {
                                  // Aceasta este cărămida propriu-zisă (antrenamentul)
                                  return BarChartRodStackItem(
                                    segmentIdx.toDouble(),
                                    (segmentIdx + 1) - (segmentIdx < workoutsCount - 1 ? (separatorThicknes / 10) : 0),
                                    theme.colorScheme.primary,
                                  );
                                }
                              }),

                        // Fundalul barelor (până la limita maximă de sus)
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
