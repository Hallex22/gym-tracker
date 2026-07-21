import 'package:flutter/material.dart';
import 'package:gym_tracker/enums/enums.dart';
import 'package:gym_tracker/models/workout_log.dart';
import 'package:gym_tracker/services/database_service.dart';

class StatsService {
  static int calculateWeeklyStreak() {
    final rawLogs = DatabaseService.logsBox.values;
    if (rawLogs.isEmpty) return 0;

    final filteredLogs =
        rawLogs.map((logMap) => WorkoutLog.fromMap(logMap as Map)).where((log) => log.status == WorkoutStatus.finished);
    final List<DateTime> workoutDates = filteredLogs.map((log) => log.startTime).toList();

    if (workoutDates.isEmpty) return 0;

    workoutDates.sort((a, b) => a.compareTo(b));

    final Set<DateTime> workoutWeeks = workoutDates.map((date) {
      final daysToSubtract = date.weekday - 1;
      final monday = date.subtract(Duration(days: daysToSubtract));
      return DateTime(monday.year, monday.month, monday.day);
    }).toSet();

    final List<DateTime> sortedWeeks = workoutWeeks.toList()..sort((a, b) => b.compareTo(a));

    if (sortedWeeks.isEmpty) return 0;

    final now = DateTime.now();
    final currentWeekMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final currentWeekMondayDate = DateTime(currentWeekMonday.year, currentWeekMonday.month, currentWeekMonday.day);

    final lastWorkoutWeek = sortedWeeks.first;
    final differenceInDays = currentWeekMondayDate.difference(lastWorkoutWeek).inDays;

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
    final daysToSubtract = now.weekday - 1;
    final mondayThisWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysToSubtract));

    return rawLogs.any((logMap) {
      final log = WorkoutLog.fromMap(logMap as Map);
      return log.status == WorkoutStatus.finished &&
          (log.startTime.isAfter(mondayThisWeek) || log.startTime.isAtSameMomentAs(mondayThisWeek));
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
      // 1. Căutăm exercițiul activ într-un mod sigur (fără să crape dacă nu există în activeExercises)
      final currentEx = activeExercises.cast<dynamic>().firstWhere(
            (ex) => ex.exerciseId == exerciseId,
            orElse: () => null,
          );

      // Dacă exercițiul nu e în lista curentă activă, nu avem cum calcula relativeCategoryIndex
      if (currentEx == null) return (0.0, 0);

      // 2. Calculăm al câtelea set de ACEST TIP este cel curent
      final List<LoggedSet> currentSets = List<LoggedSet>.from(currentEx.sets);

      // Protecție: ne asigurăm că setIndex nu depășește lungimea listei curente
      final safeIndex = setIndex < currentSets.length ? setIndex : currentSets.length;
      final relativeCategoryIndex = currentSets.sublist(0, safeIndex).where((s) => s.type == currentType).length;

      // 3. Preluăm istoricul antrenamentelor sortat descrescător (cel mai recent primul)
      final logs = DatabaseService.logsBox.values.toList()
        ..sort((a, b) {
          final logA = WorkoutLog.fromMap(a as Map);
          final logB = WorkoutLog.fromMap(b as Map);
          return logB.startTime.compareTo(logA.startTime);
        });

      // 4. Parcurgem istoricul înapoi în timp
      for (var rawLog in logs) {
        final log = WorkoutLog.fromMap(rawLog as Map);

        // Ignorăm antrenamentele care sunt încă în desfășurare
        final isStarted = log.status == WorkoutStatus.started || log.status.toString().contains('started');
        if (isStarted) continue;

        // Căutăm exercițiul în acest log din istoric (folosim unde e sigur, fără casting 'as dynamic')
        final exerciseIndex = log.exercises.indexWhere((ex) => ex.exerciseId == exerciseId);

        if (exerciseIndex != -1) {
          final exercise = log.exercises[exerciseIndex];
          final List<LoggedSet> pastSets = List<LoggedSet>.from(exercise.sets);

          // Filtrăm doar seturile de același tip (Normal, Warmup, Drop etc.)
          final matchingPastSets = pastSets.where((s) => s.type == currentType).toList();

          // Dacă am găsit suficiente seturi de acest tip în sesiunea respectivă din trecut
          if (matchingPastSets.length > relativeCategoryIndex) {
            final prevSet = matchingPastSets[relativeCategoryIndex];
            return (prevSet.weight, prevSet.reps);
          }
          // 💡 NOTĂ: Dacă în acest antrenament nu au fost destule seturi de acest tip,
          // bucla va CUMPĂNI și va merge MAI DEPARTE la penultimul, antepenultimul etc.!
        }
      }
    } catch (e) {
      debugPrint("Eroare la calcularea Previous: $e");
    }

    return (0.0, 0); // Valoare implicită dacă nu găsește nicio potrivire în tot istoricul
  }

  static ExercisePRs getPersonalRecords(int exerciseId) {
    if (!DatabaseService.logsBox.isOpen) return const ExercisePRs();

    double heaviestWeight = 0.0;
    double best1RM = 0.0;
    double bestSetVolume = 0.0;
    double bestSessionVolume = 0.0;

    // Iterăm prin toate logurile salvate în Hive
    for (var value in DatabaseService.logsBox.values) {
      final log = WorkoutLog.fromMap(value as Map);

      // Ne interesează doar antrenamentele finalizate cu succes
      if (log.status != WorkoutStatus.finished) continue;

      double currentSessionExerciseVolume = 0.0;
      bool exerciseFoundInSession = false;

      for (var loggedExercise in log.exercises) {
        if (loggedExercise.exerciseId != exerciseId) continue;

        exerciseFoundInSession = true;

        for (var set in loggedExercise.sets) {
          final double weight = set.weight;
          final int reps = set.reps;

          if (reps <= 0) continue;

          // 1. Heaviest Weight
          if (weight > heaviestWeight) {
            heaviestWeight = weight;
          }

          // 2. Best Set Volume (Greutate x Repetări pe un singur set)
          final double setVolume = weight * reps;
          if (setVolume > bestSetVolume) {
            bestSetVolume = setVolume;
          }

          // 3. Best Estimated 1RM (Formula Epley)
          // 1RM se calculează doar dacă reps > 1 (pentru 1 rep, 1RM este chiar greutatea respectivă)
          double estimated1RM = reps == 1 ? weight : weight * (1 + reps / 30.0);

          if (estimated1RM > best1RM) {
            best1RM = estimated1RM;
          }

          // Adunăm volumul pentru sesiunea curentă a acestui exercițiu
          currentSessionExerciseVolume += setVolume;
        }
      }

      // 4. Best Session Volume (Volumul total pe acest exercițiu dintr-un workout complet)
      if (exerciseFoundInSession && currentSessionExerciseVolume > bestSessionVolume) {
        bestSessionVolume = currentSessionExerciseVolume;
      }
    }

    return ExercisePRs(
      heaviestWeight: heaviestWeight,
      best1RM: best1RM,
      bestSetVolume: bestSetVolume,
      bestSessionVolume: bestSessionVolume,
    );
  }

  static List<MapEntry<WorkoutLog, LoggedExercise>> getExerciseHistory(int exerciseId) {
    if (!DatabaseService.logsBox.isOpen) return [];

    final List<MapEntry<WorkoutLog, LoggedExercise>> history = [];

    for (var value in DatabaseService.logsBox.values) {
      final log = WorkoutLog.fromMap(value as Map);

      if (log.status != WorkoutStatus.finished) continue;

      for (var loggedExercise in log.exercises) {
        if (loggedExercise.exerciseId == exerciseId) {
          history.add(MapEntry(log, loggedExercise));
          break; // Trecem la următorul log dacă l-am găsit în această sesiune
        }
      }
    }

    // Sortăm istoricul descrescător după data de început (startTime) a antrenamentului
    history.sort((a, b) => b.key.startTime.compareTo(a.key.startTime));

    return history;
  }

  /// Returnează numărul de antrenamente finalizate în ultimele [weeksCount] săptămâni.
  /// Fiecare element conține numărul săptămânii (ca etichetă sau index) și numărul de antrenamente.
  static List<MapEntry<String, int>> getWorkoutsPerWeek(int weeksCount) {
    if (!DatabaseService.logsBox.isOpen) return [];

    // Inițializăm o listă pentru ultimele N săptămâni cu 0 antrenamente
    final DateTime now = DateTime.now();

    // Generăm intervalele pentru fiecare săptămână (de la cea mai veche la cea mai recentă)
    final List<MapEntry<DateTimeRange, int>> weeklyBuckets = [];

    for (int i = weeksCount - 1; i >= 0; i--) {
      // Calculăm începutul și sfârșitul săptămânii relative la săptămâna curentă
      final int daysToSubtract = i * 7;
      final DateTime endOfWeek = now.subtract(Duration(days: daysToSubtract));

      // Găsim începutul acestei săptămâni (acum 7 zile față de finalul ei)
      final DateTime startOfWeek = endOfWeek.subtract(const Duration(days: 7));

      weeklyBuckets.add(
        MapEntry(
          DateTimeRange(start: startOfWeek, end: endOfWeek),
          0, // Inițial pornim de la 0 antrenamente
        ),
      );
    }

    // Parcurgem logurile din baza de date și le distribuim în săptămânile corespunzătoare
    for (var value in DatabaseService.logsBox.values) {
      final log = WorkoutLog.fromMap(value as Map);

      if (log.status != WorkoutStatus.finished) continue;

      for (int i = 0; i < weeklyBuckets.length; i++) {
        final range = weeklyBuckets[i].key;
        if (log.startTime.isAfter(range.start) && log.startTime.isBefore(range.end)) {
          weeklyBuckets[i] = MapEntry(range, weeklyBuckets[i].value + 1);
          break;
        }
      }
    }

    // Formatăm rezultatul pentru grafic (ex: "S1", "S2" sau intervalul de date "15-21 Iul")
    return weeklyBuckets.map((bucket) {
      final start = bucket.key.start;
      final end = bucket.key.end;

      // Format simplificat: Zi/Lună (ex: "10/07") pentru începutul săptămânii
      final String label = '${start.day}/${start.month}';

      return MapEntry(label, bucket.value);
    }).toList();
  }
}

// Ceva
class ExercisePRs {
  final double heaviestWeight; // în kg (baza de date)
  final double best1RM; // în kg
  final double bestSetVolume; // în kg
  final double bestSessionVolume; // în kg

  const ExercisePRs({
    this.heaviestWeight = 0.0,
    this.best1RM = 0.0,
    this.bestSetVolume = 0.0,
    this.bestSessionVolume = 0.0,
  });
}
