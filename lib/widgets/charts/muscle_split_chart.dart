import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/enums/enums.dart';
import 'package:gym_tracker/models/models.dart';
import 'package:gym_tracker/services/database_service.dart';

import '../../theme/app_theme.dart';

class MuscleSplitChart extends StatefulWidget {
  final int? daysRange;

  const MuscleSplitChart({super.key, this.daysRange = 30});

  @override
  State<MuscleSplitChart> createState() => _MuscleSplitChartState();
}

class _MuscleSplitChartState extends State<MuscleSplitChart> {
  int _touchedIndex = -1;
  int _totalPhysicalSets = 0;

  Map<MuscleGroup, double> _calculateMuscleSplit() {
    final Map<MuscleGroup, double> muscleScores = {};
    _totalPhysicalSets = 0;

    final DateTime now = DateTime.now();
    final DateTime? cutoffDate = widget.daysRange != null ? now.subtract(Duration(days: widget.daysRange!)) : null;

    try {
      final logsRaw = DatabaseService.logsBox.values;

      for (final rawLog in logsRaw) {
        final WorkoutLog log =
            rawLog is WorkoutLog ? rawLog : WorkoutLog.fromMap(Map<String, dynamic>.from(rawLog as Map));

        // Verificăm doar antrenamentele finalizate și filtrate după dată
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

          // 1. Primary Muscles (100% / 1.0)
          for (final target in exercise.primaryMuscles) {
            final group = target.group;
            muscleScores[group] = (muscleScores[group] ?? 0.0) + (completedSets * 1.0);
          }

          // 2. Secondary Muscles (50% / 0.5)
          for (final target in exercise.secondaryMuscles) {
            final group = target.group;
            muscleScores[group] = (muscleScores[group] ?? 0.0) + (completedSets * 0.5);
          }

          // 3. Tertiary Muscles (25% / 0.25)
          for (final target in exercise.tertiaryMuscles) {
            final group = target.group;
            muscleScores[group] = (muscleScores[group] ?? 0.0) + (completedSets * 0.25);
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
        height: 180,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline_rounded, size: 40, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(
              'No muscle recruitment data yet.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete workouts to see your split distribution.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 11),
            ),
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
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Donut Chart cu Pondere
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
                    sortedEntries.length > 5 ? 5 : sortedEntries.length,
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
          Divider(height: 1, color: context.primary.withOpacity(0.2)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.daysRange != null ? 'Last ${widget.daysRange} days total' : 'All time total',
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
