import '../enums/enums.dart';

// -------------------------------------
// Model pentru un singur set efectuat si salvat in istoric
class LoggedSet {
  final double weight; // Conține deja greutatea efectivă (Ex: 75kg bodyweight + 0kg extra = 75.0)
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

  /// Volum direct: Greutate x Repetări
  double get setVolume => weight * reps;

  /// Helper static apelat din UI pentru calculat greutatea ce urmează a fi salvată
  static double calculateEffectiveWeight({
    required double typedWeight,
    required Equipment equipment,
    required double currentBodyweight,
  }) {
    switch (equipment) {
      case Equipment.bodyweight:
        return currentBodyweight + typedWeight;
      // În caz de exerciții asistate pe viitor:
      // case Equipment.assisted:
      //   return (currentBodyweight - typedWeight) > 0 ? currentBodyweight - typedWeight : 0.0;
      default:
        return typedWeight;
    }
  }
}

// -------------------------------------
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

  /// Volumul total pe exercițiu (doar seturile cu reps > 0 și care NU sunt warmup)
  double get exerciseVolume {
    double volume = 0;
    for (var set in sets) {
      if (set.reps > 0 && set.type != SetType.warmup) {
        volume += set.setVolume;
      }
    }
    return volume;
  }

  /// Numărul de seturi valide executate (reps > 0 și non-warmup)
  int get completedSetsCount {
    return sets.where((set) => set.reps > 0 && set.type != SetType.warmup).length;
  }

  /// Greutatea maximă ridicată în cadrul exercițiului
  double get maxWeight {
    final validSets = sets.where((s) => s.reps > 0 && s.type != SetType.warmup).toList();
    if (validSets.isEmpty) return 0.0;
    return validSets.map((s) => s.weight).reduce((a, b) => a > b ? a : b);
  }

  /// Estimare 1RM pe baza celei mai bune performanțe
  double get estimated1RM {
    double highest1RM = 0.0;
    for (var set in sets) {
      if (set.reps > 0 && set.type != SetType.warmup) {
        double current1RM = set.weight * (1 + set.reps / 30.0);
        if (current1RM > highest1RM) highest1RM = current1RM;
      }
    }
    return highest1RM;
  }
}

// -------------------------------------
// Model pentru antrenamentul întreg
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
      notes: map['notes'] as String?,
    );
  }

  int get durationInMinutes {
    if (endTime == null) return 0;
    return endTime!.difference(startTime).inMinutes;
  }

  /// Volumul total al antrenamentului (adună direct ex.exerciseVolume)
  double get totalVolume {
    double volume = 0;
    for (var ex in exercises) {
      volume += ex.exerciseVolume;
    }
    return volume;
  }

  /// Numărul total de seturi introduse
  int get totalSetsCount {
    int count = 0;
    for (var ex in exercises) {
      count += ex.sets.length;
    }
    return count;
  }

  /// Numărul total de seturi valide (reps > 0 și fără warmup)
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
