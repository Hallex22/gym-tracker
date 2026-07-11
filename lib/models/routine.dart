import 'dart:convert';

import 'package:gym_tracker/enums/grip.dart';

import '../enums/enums.dart';
import '../main.dart';
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

  // -------------------------------
  // Metode pentru rutina
  String toShareCode() {
    // 1. Extragem doar numele exercițiilor, nu tot obiectul complet
    final List<String> exerciseNames = exercises.map((e) => e.name).toList();

    // 2. Creăm un map ultra-compact doar cu ce ne trebuie
    final minimalMap = {
      't': title,
      'd': description,
      'e': exerciseNames, // Listă simplă de String-uri ["Push-up", "Squat"]
    };

    // 3. Convertim în JSON și apoi în Base64
    final jsonString = jsonEncode(minimalMap);
    final bytes = utf8.encode(jsonString);
    return base64.encode(bytes);
  }

  // TODO de actualizat
  static Routine? fromShareCode(String code) {
    try {
      final decodedBytes = base64.decode(code.trim());
      final jsonString = utf8.decode(decodedBytes);
      final minimalMap = jsonDecode(jsonString) as Map;

      final String title = minimalMap['t'] ?? 'Imported Routine';
      final String description = minimalMap['d'] ?? '';
      final List<dynamic> exerciseNames = minimalMap['e'] ?? [];

      final List<Exercise> reconstructedExercises = [];

      for (var name in exerciseNames) {
        final rawExercise = exercisesBox.get(name);

        if (rawExercise != null) {
          reconstructedExercises.add(Exercise.fromMap(rawExercise as Map));
        } else {
          reconstructedExercises.add(Exercise(
              id: 100,
              name: name.toString(),
              sourceUrl: '/',
              instructions: [],
              mechanic: Mechanic.isolation,
              difficulty: Difficulty.beginner,
              equipment: Equipment.bodyweight,
              primaryMuscles: [],
              secondaryMuscles: [],
              tertiaryMuscles: [],
              grips: [Grip.none]));
        }
      }

      // 4. Returnăm obiectul Routine complet format conform regulilor POO
      return Routine(
        title: title,
        description: description,
        exercises: reconstructedExercises,
      );
    } catch (e) {
      return null; // Cod corupt sau invalid
    }
  }
}
