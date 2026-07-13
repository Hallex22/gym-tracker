import 'dart:convert';

class Routine {
  String title;
  String? description;
  List<RoutineExercise>
      exercises; // 💡 Schimbat din List<Exercise> în List<RoutineExercise>

  Routine({required this.title, this.description, required this.exercises});

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        // Convertim lista de RoutineExercise în Maps
        'exercises': exercises.map((e) => e.toMap()).toList(),
      };

  factory Routine.fromMap(Map<dynamic, dynamic> map) => Routine(
        title: map['title'] as String,
        description: map['description'] as String?,
        exercises: (map['exercises'] as List)
            .map((e) => RoutineExercise.fromMap(e as Map))
            .toList(),
      );

  // -----------------------------------------------------------------------
  // METODE SHARE CODE (IMPROVED: Acum salvează și numărul de seturi compact!)
  // -----------------------------------------------------------------------
  String toShareCode() {
    // Mapăm exercițiile în perechi ultra-compacte: ID-ul original și numărul de seturi
    final List<Map<String, dynamic>> minimalExercises = exercises.map((e) {
      return {
        'id': e
            .exerciseId, // 💡 Salvăm ID-ul/Cheia unică a exercițiului pentru o corelare perfectă la import
        's': e.targetSetsCount, // Numărul de seturi țintă
      };
    }).toList();

    // Structura finală compactă a rutinei
    final minimalMap = {
      't': title,
      'd': description,
      'e': minimalExercises,
    };

    // Transformăm în JSON -> Bytes -> Base64 string
    final jsonString = jsonEncode(minimalMap);
    final bytes = utf8.encode(jsonString);
    return base64.encode(bytes);
  }

  static Routine? fromShareCode(String code) {
    try {
      final decodedBytes = base64.decode(code.trim());
      final jsonString = utf8.decode(decodedBytes);
      final minimalMap = jsonDecode(jsonString) as Map;

      final String title = minimalMap['t'] ?? 'Imported Routine';
      final String description = minimalMap['d'] ?? '';
      final List<dynamic> sharedExercises = minimalMap['e'] ?? [];

      final List<RoutineExercise> reconstructedExercises = [];

      for (var item in sharedExercises) {
        final exerciseData = item as Map;
        final dynamic exerciseId = exerciseData['id'];
        final int sets = exerciseData['s'] as int? ?? 3;

        if (exerciseId == null) continue;

        reconstructedExercises.add(RoutineExercise(
          exerciseId: exerciseId,
          targetSetsCount: sets,
        ));
      }

      return Routine(
        title: title,
        description: description,
        exercises: reconstructedExercises,
      );
    } catch (e) {
      return null;
    }
  }
}

// Exercise specific rutina
class RoutineExercise {
  final int exerciseId; // ID-ul către exercițiul global din exercisesBox
  int targetSetsCount; // Eliminat 'final' ca să poți face setState pe el când dai + sau - la seturi în UI

  RoutineExercise({
    required this.exerciseId,
    this.targetSetsCount = 3, // Valoare implicită
  });

  // Convertire în Map pentru stocare în Hive
  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'targetSetsCount': targetSetsCount,
      };

  // Construire obiect din datele stocate în Hive
  factory RoutineExercise.fromMap(Map<dynamic, dynamic> map) => RoutineExercise(
        exerciseId: map['exerciseId'] as int,
        targetSetsCount: map['targetSetsCount'] as int? ?? 3,
      );
}
