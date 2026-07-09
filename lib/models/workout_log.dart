import 'dart:convert';

import 'package:gym_tracker/enums/workout_status.dart';

// Model pentru un singur set efectuat si salvat in istoric
class LoggedSet {
  final double weight;
  final int reps;

  const LoggedSet({
    required this.weight,
    required this.reps,
  });

  Map<String, dynamic> toMap() => {
        'weight': weight,
        'reps': reps,
      };

  factory LoggedSet.fromMap(Map<dynamic, dynamic> map) => LoggedSet(
        weight: (map['weight'] ?? 0.0).toDouble(),
        reps: (map['reps'] ?? 0).toInt(),
      );
}

// Model pentru exercitiu logat
class LoggedExercise {
  final String name;
  final List<LoggedSet> sets;

  const LoggedExercise({
    required this.name,
    required this.sets,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'sets': sets.map((s) => s.toMap()).toList(),
      };

  factory LoggedExercise.fromMap(Map<dynamic, dynamic> map) {
    final List<dynamic> rawSets = map['sets'] ?? [];
    return LoggedExercise(
      name: map['name'] as String,
      sets: rawSets.map((s) => LoggedSet.fromMap(s as Map)).toList(),
    );
  }
}

class WorkoutLog {
  DateTime startTime;
  DateTime? endTime;
  String routineTitle;
  List<LoggedExercise> exercises;
  WorkoutStatus status;

  WorkoutLog({
    required this.startTime,
    this.endTime,
    required this.routineTitle,
    required this.exercises,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'routineTitle': routineTitle,
        'exercises': exercises.map((e) => e.toMap()).toList(),
        'status': status.name,
      };

  factory WorkoutLog.fromMap(Map<dynamic, dynamic> map) {
    final List<dynamic> rawExercises = map['exercises'] ?? [];

    return WorkoutLog(
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: map['endTime'] != null
          ? DateTime.parse(map['endTime'] as String)
          : null,
      routineTitle: map['routineTitle'] as String,
      exercises:
          rawExercises.map((e) => LoggedExercise.fromMap(e as Map)).toList(),
      status: WorkoutStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => WorkoutStatus.started,
      ),
    );
  }

  // -----------------------------
  // Metode specifice
  int get durationInMinutes {
    if (endTime == null) return 0;
    return endTime!.difference(startTime).inMinutes;
  }

  double get totalVolume {
    double volume = 0;
    for (var ex in exercises) {
      for (var set in ex.sets) {
        volume += set.reps * set.weight;
      }
    }
    return volume;
  }
}
