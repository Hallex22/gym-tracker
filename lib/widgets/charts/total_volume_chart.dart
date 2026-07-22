import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/enums/enums.dart';
import 'package:gym_tracker/models/models.dart';
import 'package:gym_tracker/services/database_service.dart';
import 'package:gym_tracker/theme/app_theme.dart';

enum VolumeTimeframe {
  weekly('Weekly'),
  monthly('Monthly');

  final String label;
  const VolumeTimeframe(this.label);
}

class TotalVolumeChart extends StatefulWidget {
  const TotalVolumeChart({super.key});

  @override
  State<TotalVolumeChart> createState() => _TotalVolumeChartState();
}

class _TotalVolumeChartState extends State<TotalVolumeChart> {
  VolumeTimeframe _selectedTimeframe = VolumeTimeframe.weekly;
  int _touchedIndex = -1;

  // --- CALCULUL VOLUMULUI (SĂPTĂMÂNAL / LUNAR) ---
  List<MapEntry<String, double>> _calculateVolumeData() {
    final Map<String, double> volumeMap = {};
    final DateTime now = DateTime.now();

    try {
      // 1. Pre-populăm harta cu intervalele fixe (inițializate cu 0.0)
      if (_selectedTimeframe == VolumeTimeframe.weekly) {
        // Găsim ziua de Luni din săptămâna curentă
        final currentMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        
        // Generăm ultimele 8 săptămâni
        for (int i = 7; i >= 0; i--) {
          final startOfWeek = currentMonday.subtract(Duration(days: i * 7));
          final monthName = _getShortMonthName(startOfWeek.month);
          final key = '${startOfWeek.day} $monthName';
          volumeMap[key] = 0.0;
        }
      } else {
        // Generăm ultimele 6 luni (doar numele lunii pe axa X: 'Jul', 'Jun' etc.)
        for (int i = 5; i >= 0; i--) {
          final monthDate = DateTime(now.year, now.month - i, 1);
          final monthName = _getShortMonthName(monthDate.month);
          final key = monthName;
          volumeMap[key] = 0.0;
        }
      }

      // 2. Parcurgem antrenamentele și adăugăm volumul în slot-ul corespunzător
      final logsRaw = DatabaseService.logsBox.values;

      for (final rawLog in logsRaw) {
        final WorkoutLog log =
            rawLog is WorkoutLog ? rawLog : WorkoutLog.fromMap(Map<String, dynamic>.from(rawLog as Map));

        if (log.status != WorkoutStatus.finished) continue;

        final DateTime date = log.startTime;
        String key;

        if (_selectedTimeframe == VolumeTimeframe.weekly) {
          final startOfWeek = DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));
          final monthName = _getShortMonthName(startOfWeek.month);
          key = '${startOfWeek.day} $monthName';
        } else {
          key = _getShortMonthName(date.month);
        }

        // Adăugăm volumul DOAR dacă cheia există deja în intervalul generat
        if (volumeMap.containsKey(key)) {
          volumeMap[key] = volumeMap[key]! + log.totalVolume;
        }
      }
    } catch (e) {
      debugPrint('Error calculating total volume trend: $e');
    }

    return volumeMap.entries.toList();
  }

  String _getShortMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _formatVolumeValue(double volumeKg) {
    if (volumeKg >= 1000) {
      final double tons = volumeKg / 1000;
      return '${tons.toStringAsFixed(tons >= 10 ? 0 : 1)}t';
    }
    return '${volumeKg.toInt()} kg';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _calculateVolumeData();

    if (data.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderMuted),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart_rounded, size: 40, color: context.textMuted.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(
              'No volume data available yet.',
              style: TextStyle(color: context.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete workouts to track your progressive overload.',
              style: TextStyle(color: context.textMuted.withOpacity(0.7), fontSize: 11),
            ),
          ],
        ),
      );
    }

    final double maxVolume = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderMuted),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        children: [
          // Header cu titlu + Dropdown Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Volume Load Trend 🏋️‍♂️',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              // Dropdown
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: context.bgLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<VolumeTimeframe>(
                    value: _selectedTimeframe,
                    icon: Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.primary),
                    dropdownColor: context.bgLight,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    onChanged: (VolumeTimeframe? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedTimeframe = newValue;
                          _touchedIndex = -1;
                        });
                      }
                    },
                    items: VolumeTimeframe.values.map((VolumeTimeframe timeframe) {
                      return DropdownMenuItem<VolumeTimeframe>(
                        value: timeframe,
                        child: Text(timeframe.label),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Graficul propriu-zis (BarChart)
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVolume == 0 ? 100 : maxVolume * 1.15,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 12,
                    getTooltipColor: (group) => context.bgLight,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = data[groupIndex].key;
                      final volume = rod.toY;

                      // Construim eticheta completă pentru tooltip
                      String fullLabel = label;
                      if (_selectedTimeframe == VolumeTimeframe.monthly) {
                        final DateTime now = DateTime.now();
                        final targetDate = DateTime(now.year, now.month - (5 - groupIndex), 1);
                        fullLabel = '$label ${targetDate.year}'; // ex: "Jul 2026"
                      }

                      return BarTooltipItem(
                        '$fullLabel\n',
                        TextStyle(
                          color: context.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: '${volume.toStringAsFixed(0)} kg',
                            style: TextStyle(
                              color: context.textMuted,
                              fontWeight: FontWeight.normal,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          barTouchResponse == null ||
                          barTouchResponse.spot == null) {
                        _touchedIndex = -1;
                        return;
                      }
                      _touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                    });
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final int index = value.toInt();
                        if (index < 0 || index >= data.length) return const SizedBox.shrink();

                        if (_selectedTimeframe == VolumeTimeframe.weekly && data.length > 5 && index % 2 != 0) {
                          return const SizedBox.shrink();
                        }

                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 6,
                          child: Text(
                            data[index].key,
                            style: TextStyle(
                              color: index == _touchedIndex
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: index == _touchedIndex ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: context.textMuted.withOpacity(0.1), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(data.length, (index) {
                  final isTouched = index == _touchedIndex;
                  final volume = data[index].value;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: volume,
                        color: isTouched ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.65),
                        width: _selectedTimeframe == VolumeTimeframe.weekly ? 14 : 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),

          const SizedBox(height: 8),
          Divider(height: 1, color: context.borderMuted),
          const SizedBox(height: 8),

          // Total înregistrat în perioada curentă
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedTimeframe == VolumeTimeframe.weekly ? 'Last 8 weeks total' : 'Last 6 months total',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              ),
              Text(
                _formatVolumeValue(data.fold<double>(0.0, (sum, item) => sum + item.value)),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}