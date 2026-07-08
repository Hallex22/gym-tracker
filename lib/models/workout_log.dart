class WorkoutLog {
  DateTime date;
  String routineTitle;
  String workoutDataJson;

  WorkoutLog({
    required this.date,
    required this.routineTitle,
    required this.workoutDataJson,
  });

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'routineTitle': routineTitle,
        'workoutDataJson': workoutDataJson,
      };

  factory WorkoutLog.fromMap(Map<dynamic, dynamic> map) => WorkoutLog(
        date: DateTime.parse(map['date'] as String),
        routineTitle: map['routineTitle'] as String,
        workoutDataJson: map['workoutDataJson'] as String,
      );
}
