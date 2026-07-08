import 'exercise.dart';

class Routine {
  String title;
  String? description;
  List<Exercise> exercises;

  Routine({required this.title, this.description, required this.exercises});

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'exercises': exercises.map((e) => e.toMap()).toList(),
      };

  factory Routine.fromMap(Map<dynamic, dynamic> map) => Routine(
        title: map['title'] as String,
        description: map['description'] as String?,
        exercises: (map['exercises'] as List)
            .map((e) => Exercise.fromMap(e as Map))
            .toList(),
      );
}
