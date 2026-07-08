import 'muscle_group.dart';

class Exercise {
  String name;
  MuscleGroup muscleGroup;

  Exercise({required this.name, required this.muscleGroup});

  Map<String, dynamic> toMap() => {
        'name': name,
        'muscleGroup': muscleGroup.name,
      };

  factory Exercise.fromMap(Map<dynamic, dynamic> map) => Exercise(
        name: map['name'] as String,
        muscleGroup: MuscleGroup.values.firstWhere(
          (e) => e.name == map['muscleGroup'],
          orElse: () => MuscleGroup.core,
        ),
      );
}
