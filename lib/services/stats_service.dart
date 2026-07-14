import 'package:flutter/material.dart';
import 'package:gym_tracker/enums/enums.dart';
import 'package:gym_tracker/models/workout_log.dart';
import 'package:gym_tracker/services/database_service.dart';

class StatsService {
  static int calculateWeeklyStreak() {
    final rawLogs = DatabaseService.logsBox.values;
    if (rawLogs.isEmpty) return 0;

    final List<DateTime> workoutDates = rawLogs
        .map((logMap) => WorkoutLog.fromMap(logMap as Map).startTime)
        .toList();

    if (workoutDates.isEmpty) return 0;

    workoutDates.sort((a, b) => a.compareTo(b));

    final Set<DateTime> workoutWeeks = workoutDates.map((date) {
      final daysToSubtract = date.weekday - 1;
      final monday = date.subtract(Duration(days: daysToSubtract));
      return DateTime(monday.year, monday.month, monday.day);
    }).toSet();

    final List<DateTime> sortedWeeks = workoutWeeks.toList()
      ..sort((a, b) => b.compareTo(a));

    if (sortedWeeks.isEmpty) return 0;

    final now = DateTime.now();
    final currentWeekMonday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final currentWeekMondayDate = DateTime(
        currentWeekMonday.year, currentWeekMonday.month, currentWeekMonday.day);

    final lastWorkoutWeek = sortedWeeks.first;
    final differenceInDays =
        currentWeekMondayDate.difference(lastWorkoutWeek).inDays;

    if (differenceInDays > 7) {
      return 0;
    }

    int streak = 0;
    DateTime expectedWeek = lastWorkoutWeek;

    for (var week in sortedWeeks) {
      if (week == expectedWeek) {
        streak++;
        expectedWeek = expectedWeek.subtract(const Duration(days: 7));
      } else {
        break;
      }
    }

    return streak;
  }

  static bool isStreakActiveThisWeek() {
    final rawLogs = DatabaseService.logsBox.values;
    if (rawLogs.isEmpty) return false;

    final now = DateTime.now();
    // Găsim Lunea din săptămâna curentă la ora 00:00:00
    final daysToSubtract = now.weekday - 1;
    final mondayThisWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysToSubtract));

    // Verificăm dacă există vreun antrenament început după Luni, ora 00:00
    return rawLogs.any((logMap) {
      final log = WorkoutLog.fromMap(logMap as Map);
      return log.startTime.isAfter(mondayThisWeek) ||
          log.startTime.isAtSameMomentAs(mondayThisWeek);
    });
  }

  // Workout Stats
  static (double, int) getPreviousSetRaw({
    required int exerciseId,
    required int setIndex,
    required SetType currentType,
    required List<dynamic> activeExercises,
  }) {
    try {
      final logs = DatabaseService.logsBox.values.toList()
        ..sort((a, b) {
          final logA = WorkoutLog.fromMap(a as Map);
          final logB = WorkoutLog.fromMap(b as Map);
          return logB.startTime.compareTo(logA.startTime);
        });

      final bool isCurrentWarmup = currentType == SetType.warmup;

      for (var rawLog in logs) {
        final log = WorkoutLog.fromMap(rawLog as Map);

        // 🔧 FIX: Tratăm ambele cazuri de "started" (dacă starea e enum sau String)
        final isStarted = log.status == WorkoutStatus.started ||
            log.status.toString().contains('started');
        if (isStarted) continue;

        final exercise = log.exercises.firstWhere(
          (ex) => ex.exerciseId == exerciseId,
          orElse: () => null as dynamic,
        );

        if (exercise != null) {
          // 🚀 CURĂȚARE: Nu mai mapăm/convertim nimic. Facem doar cast direct la List<LoggedSet>
          final List<LoggedSet> pastSets = List<LoggedSet>.from(exercise.sets);

          final matchingPastSets = pastSets
              .where((s) => (s.type == SetType.warmup) == isCurrentWarmup)
              .toList();

          final currentEx =
              activeExercises.firstWhere((ex) => ex.exerciseId == exerciseId);

          // 🚀 CURĂȚARE: Facem cast direct și aici pentru siguranță
          final List<LoggedSet> currentSets =
              List<LoggedSet>.from(currentEx.sets);

          final relativeCategoryIndex = currentSets
              .sublist(0, setIndex)
              .where((s) => (s.type == SetType.warmup) == isCurrentWarmup)
              .length;

          if (matchingPastSets.length > relativeCategoryIndex) {
            final prevSet = matchingPastSets[relativeCategoryIndex];
            return (prevSet.weight, prevSet.reps);
          }
        }
      }
    } catch (e) {
      debugPrint("Eroare la calcularea Previous: $e");
    }
    return (0.0, 0); // Valoare implicită dacă nu găsește nimic
  }
}
