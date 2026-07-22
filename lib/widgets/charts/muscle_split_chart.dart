import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/enums/enums.dart';
import 'package:gym_tracker/models/models.dart';
import 'package:gym_tracker/services/database_service.dart';
import '../../theme/app_theme.dart';

enum MuscleSplitTimeframe {
  days7(7, 'Last 7 Days'),
  days30(30, 'Last 30 Days'),
  days90(90, 'Last 90 Days'),
  allTime(null, 'All Time');

  final int? days;
  final String label;
  const MuscleSplitTimeframe(this.days, this.label);
}

class MuscleSplitChart extends StatefulWidget {
  final int? initialDaysRange;

  const MuscleSplitChart({super.key, this.initialDaysRange = 30});

  @override
  State<MuscleSplitChart> createState() => _MuscleSplitChartState();
}

class _MuscleSplitChartState extends State<MuscleSplitChart> {
  late MuscleSplitTimeframe _selectedTimeframe;
  int _touchedIndex = -1;
  int _totalPhysicalSets = 0;

  @override
  void initState() {
    super.initState();
    _selectedTimeframe = MuscleSplitTimeframe.values.firstWhere(
      (e) => e.days == widget.initialDaysRange,
      orElse: () => MuscleSplitTimeframe.days30,
    );
  }

  Map<HighLevelMuscleGroup, double> _calculateMuscleSplit() {
    final Map<HighLevelMuscleGroup, double> muscleScores = {};
    _totalPhysicalSets = 0;

    final DateTime now = DateTime.now();
    final int? daysRange = _selectedTimeframe.days;
    final DateTime? cutoffDate = daysRange != null ? now.subtract(Duration(days: daysRange)) : null;

    try {
      final logsRaw = DatabaseService.logsBox.values;

      for (final rawLog in logsRaw) {
        final WorkoutLog log =
            rawLog is WorkoutLog ? rawLog : WorkoutLog.fromMap(Map<String, dynamic>.from(rawLog as Map));

        if (log.status != WorkoutStatus.finished) continue;
        if (cutoffDate != null && log.startTime.isBefore(cutoffDate)) continue;

        for (final loggedExercise in log.exercises) {
          final rawExercise = DatabaseService.exercisesBox.get(loggedExercise.exerciseId);
          if (rawExercise == null) continue;

          final Exercise exercise =
              rawExercise is Exercise ? rawExercise : Exercise.fromMap(Map<String, dynamic>.from(rawExercise as Map));

          final int completedSets = loggedExercise.sets.where((s) => s.isCompleted || s.reps > 0).length;

          if (completedSets == 0) continue;

          _totalPhysicalSets += completedSets;

          // Helper intern pentru adăugarea scorului direct în grupa HighLevel
          void addScore(MuscleGroup targetGroup, double weight) {
            final highLevel = HighLevelMuscleGroup.fromMuscleGroup(targetGroup);
            if (highLevel == HighLevelMuscleGroup.other) return; // Ignorăm necunoscutele dacă e cazul
            muscleScores[highLevel] = (muscleScores[highLevel] ?? 0.0) + (completedSets * weight);
          }

          // 1. Primary Muscles (100% / 1.0)
          for (final target in exercise.primaryMuscles) {
            addScore(target.group, 1.0);
          }

          // 2. Secondary Muscles (50% / 0.5)
          for (final target in exercise.secondaryMuscles) {
            addScore(target.group, 0.5);
          }

          // 3. Tertiary Muscles (25% / 0.25)
          for (final target in exercise.tertiaryMuscles) {
            addScore(target.group, 0.25);
          }
        }
      }
    } catch (e) {
      debugPrint('Error calculating weighted muscle split: $e');
    }

    return muscleScores;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _calculateMuscleSplit();

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
          children: [
            // Header cu titlu + Dropdown (chiar și pe stare goală)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Muscle Recruitment 🎯',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: context.bgLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<MuscleSplitTimeframe>(
                      value: _selectedTimeframe,
                      icon: Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.primary),
                      dropdownColor: context.bgLight,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      onChanged: (MuscleSplitTimeframe? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedTimeframe = newValue;
                            _touchedIndex = -1;
                          });
                        }
                      },
                      items: MuscleSplitTimeframe.values.map((MuscleSplitTimeframe tf) {
                        return DropdownMenuItem<MuscleSplitTimeframe>(
                          value: tf,
                          child: Text(tf.label),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.pie_chart_outline_rounded, size: 40, color: context.textMuted.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(
              'No muscle recruitment data yet.',
              style: TextStyle(color: context.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete workouts to see your split distribution.',
              style: TextStyle(color: context.textMuted.withOpacity(0.7), fontSize: 11),
            ),
            const Spacer(),
          ],
        ),
      );
    }

    final double totalWeightedScore = data.values.fold<double>(0.0, (sum, score) => sum + score);
    final sortedEntries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

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
                'Muscle Recruitment 🎯',
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
                  child: DropdownButton<MuscleSplitTimeframe>(
                    value: _selectedTimeframe,
                    icon: Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.primary),
                    dropdownColor: context.bgLight,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    onChanged: (MuscleSplitTimeframe? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedTimeframe = newValue;
                          _touchedIndex = -1;
                        });
                      }
                    },
                    items: MuscleSplitTimeframe.values.map((MuscleSplitTimeframe tf) {
                      return DropdownMenuItem<MuscleSplitTimeframe>(
                        value: tf,
                        child: Text(tf.label),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Donut Chart + Legendă
          Row(
            children: [
              // Donut Chart
              SizedBox(
                height: 150,
                width: 150,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    sections: List.generate(sortedEntries.length, (i) {
                      final isTouched = i == _touchedIndex;
                      final entry = sortedEntries[i];
                      final percentage = (entry.value / totalWeightedScore) * 100;

                      return PieChartSectionData(
                        color: entry.key.color,
                        value: entry.value,
                        title: '${percentage.toStringAsFixed(0)}%',
                        radius: isTouched ? 40.0 : 34.0,
                        titleStyle: TextStyle(
                          fontSize: isTouched ? 12 : 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: const [Shadow(color: Colors.black38, blurRadius: 2)],
                        ),
                      );
                    }),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Legendă
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    sortedEntries.length,
                    (i) {
                      final entry = sortedEntries[i];
                      final percentage = ((entry.value / totalWeightedScore) * 100).toStringAsFixed(1);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.0),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: entry.key.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.key.displayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: i == _touchedIndex ? FontWeight.bold : FontWeight.w500,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '$percentage%',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: context.borderMuted),
          const SizedBox(height: 8),

          // Subsol dinamic în funcție de opțiunea selectată
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedTimeframe.days != null ? 'Last ${_selectedTimeframe.days} days total' : 'All time total',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              ),
              Text(
                '$_totalPhysicalSets completed sets',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
