// Model pentru un singur set efectuat si salvat in istoric
import '../enums/enums.dart';

class LoggedSet {
  final double weight;
  final int reps;
  final SetType type;
  final bool isCompleted;

  const LoggedSet({
    required this.weight,
    required this.reps,
    this.type = SetType.normal,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() => {
        'weight': weight,
        'reps': reps,
        'type': type.name,
        'isCompleted': isCompleted,
      };

  factory LoggedSet.fromMap(Map<dynamic, dynamic> map) => LoggedSet(
        weight: (map['weight'] ?? 0.0).toDouble(),
        reps: (map['reps'] ?? 0).toInt(),
        type: SetType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => SetType.normal,
        ),
        isCompleted: map['isCompleted'] as bool? ?? false,
      );

  double get setVolume {
    double volume = 0;
    volume += weight * reps;
    return volume;
  }
}

//  -------------------------------------
// Model pentru exercitiu logat
class LoggedExercise {
  final int exerciseId;
  final List<LoggedSet> sets;

  const LoggedExercise({
    required this.exerciseId,
    required this.sets,
  });

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'sets': sets.map((s) => s.toMap()).toList(),
      };

  factory LoggedExercise.fromMap(Map<dynamic, dynamic> map) {
    final List<dynamic> rawSets = map['sets'] ?? [];
    return LoggedExercise(
      exerciseId: (map['exerciseId'] as num?)?.toInt() ?? 1,
      sets: rawSets.map((s) => LoggedSet.fromMap(s as Map)).toList(),
    );
  }

  // Metode pe LoggedExercise
  double get exerciseVolume {
    double volume = 0;
    for (var set in sets) {
      if (set.type != SetType.warmup) {
        volume += set.setVolume;
      }
    }
    return volume;
  }

  int get completedSetsCount {
    int count = 0;
    count += sets.where((set) => set.reps > 0 && set.type != SetType.warmup).length;
    return count;
  }

  double get maxWeight {
    if (sets.isEmpty) return 0.0;
    return sets.map((s) => s.weight).reduce((a, b) => a > b ? a : b);
  }

  double get estimated1RM {
    if (sets.isEmpty) return 0.0;
    double highest1RM = 0.0;
    for (var set in sets) {
      if (set.reps > 0) {
        double current1RM = set.weight * (1 + set.reps / 30.0);
        if (current1RM > highest1RM) highest1RM = current1RM;
      }
    }
    return highest1RM;
  }
}

class WorkoutLog {
  DateTime startTime;
  DateTime? endTime;
  String routineTitle;
  List<LoggedExercise> exercises;
  WorkoutStatus status;
  String? notes;

  WorkoutLog({
    required this.startTime,
    this.endTime,
    required this.routineTitle,
    required this.exercises,
    required this.status,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'routineTitle': routineTitle,
        'exercises': exercises.map((e) => e.toMap()).toList(),
        'status': status.name,
        'notes': notes,
      };

  factory WorkoutLog.fromMap(Map<dynamic, dynamic> map) {
    final List<dynamic> rawExercises = map['exercises'] ?? [];

    return WorkoutLog(
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime'] as String) : null,
      routineTitle: map['routineTitle'] as String,
      exercises: rawExercises.map((e) => LoggedExercise.fromMap(e as Map)).toList(),
      status: WorkoutStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => WorkoutStatus.started,
      ),
      notes: map['notes'] as String?
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
      volume += ex.exerciseVolume;
    }
    return volume;
  }

  int get totalSetsCount {
    int count = 0;
    for (var ex in exercises) {
      count += ex.sets.length;
    }
    return count;
  }

  int get completedSetsCount {
    int count = 0;
    for (var ex in exercises) {
      count += ex.completedSetsCount;
    }
    return count;
  }

  String get formattedDuration {
    if (endTime == null) return "In progress...";
    final duration = endTime!.difference(startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '$minutes min';
    }
  }
}
