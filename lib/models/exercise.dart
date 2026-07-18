import 'package:gym_tracker/enums/grip.dart';

import '../enums/enums.dart';

class Exercise {
  final int id;
  final String name;
  final String sourceUrl;

  final String? coverImage;

  final Equipment equipment;
  final Mechanic? mechanic;
  final Force? force;
  final List<Grip> grips;
  final Difficulty difficulty;
  final List<String> instructions;

  final List<MuscleTarget> primaryMuscles;
  final List<MuscleTarget> secondaryMuscles;
  final List<MuscleTarget> tertiaryMuscles;

  // Extra, nu se insereasa in bd
  final String? notes;

  const Exercise(
      {required this.id,
      required this.name,
      required this.sourceUrl,
      this.coverImage,
      required this.equipment,
      this.mechanic,
      this.force,
      required this.grips,
      required this.difficulty,
      required this.instructions,
      required this.primaryMuscles,
      required this.secondaryMuscles,
      required this.tertiaryMuscles,
      this.notes});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'sourceUrl': sourceUrl,
        'coverImage': coverImage,
        'equipment': equipment.name,
        'mechanic': mechanic?.name,
        'force': force?.name,
        'grips': grips.map((g) => g.name).toList(),
        'difficulty': difficulty.name,
        'instructions': instructions,
        'primaryMuscles': primaryMuscles.map((m) => m.toMap()).toList(),
        'secondaryMuscles': secondaryMuscles.map((m) => m.toMap()).toList(),
        'tertiaryMuscles': tertiaryMuscles.map((m) => m.toMap()).toList(),
        'notes': notes,
      };

  factory Exercise.fromMap(Map<dynamic, dynamic> map) {
    List<MuscleTarget> parseMuscleList(dynamic rawList) {
      if (rawList == null || rawList is! List) return [];
      return rawList.map((m) => MuscleTarget.fromMap(m as Map)).toList();
    }

    return Exercise(
      id: map['id'] as int? ?? 0,
      name: map['name'] as String? ?? '',
      sourceUrl: map['sourceUrl'] as String? ?? '',
      coverImage: map['coverImage'] as String?,
      equipment: Equipment.values.firstWhere(
        (e) => e.name == map['equipment'],
        orElse: () => Equipment.bodyweight,
      ),
      mechanic: map['mechanic'] != null ? Mechanic.values.firstWhere((m) => m.name == map['mechanic']) : null,
      force: map['force'] != null ? Force.values.firstWhere((f) => f.name == map['force']) : null,
      grips: (map['grips'] as List? ?? []).map((g) => Grip.values.firstWhere((v) => v.name == g)).toList(),
      difficulty: Difficulty.values.firstWhere(
        (d) => d.name == map['difficulty'],
        orElse: () => Difficulty.beginner,
      ),
      instructions: List<String>.from(map['instructions'] ?? []),
      primaryMuscles: parseMuscleList(map['primaryMuscles']),
      secondaryMuscles: parseMuscleList(map['secondaryMuscles']),
      tertiaryMuscles: parseMuscleList(map['tertiaryMuscles']),
      notes: map['notes'] as String?,
    );
  }

  factory Exercise.fromJson(Map<String, dynamic> json) {
    // Parsăm map-ul imbricat de mușchi din JSON-ul de scraping
    final musclesJson = json['muscles'] as Map<String, dynamic>? ?? {};

    List<MuscleTarget> parseMuscleListJson(dynamic list) {
      if (list == null || list is! List) return [];
      return list.map((m) => MuscleTarget.fromJson(m as Map<String, dynamic>)).toList();
    }

    return Exercise(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      coverImage: json['coverImage'] as String?,
      // Mapare sigură pentru Enum-uri din textul brut primit de la scraper
      equipment: Equipment.values.firstWhere(
        (e) => e.name.toLowerCase() == (json['equipment'] as String? ?? '').toLowerCase().trim(),
        orElse: () => Equipment.bodyweight,
      ),
      mechanic: json['mechanic'] != null
          ? Mechanic.values.firstWhere((m) => m.name.toLowerCase() == json['mechanic'].toString().toLowerCase().trim())
          : null,
      force: json['force'] != null
          ? Force.values.firstWhere((f) => f.name.toLowerCase() == json['force'].toString().toLowerCase().trim())
          : null,
      grips: (json['grips'] as List? ?? [])
          .map((g) => Grip.values.firstWhere((v) => v.name.toLowerCase() == g.toString().toLowerCase().trim()))
          .toList(),
      difficulty: Difficulty.values.firstWhere(
        (d) => d.name.toLowerCase() == (json['difficulty'] as String? ?? '').toLowerCase().trim(),
        orElse: () => Difficulty.beginner,
      ),
      instructions: List<String>.from(json['instructions'] ?? []),
      primaryMuscles: parseMuscleListJson(musclesJson['primary']),
      secondaryMuscles: parseMuscleListJson(musclesJson['secondary']),
      tertiaryMuscles: parseMuscleListJson(musclesJson['tertiary']),
      notes: json['notes'] as String?,
    );
  }

  Exercise copyWith({
    String? notes,
  }) {
    return Exercise(
      id: id,
      name: name,
      sourceUrl: sourceUrl,
      coverImage: coverImage,
      equipment: equipment,
      mechanic: mechanic,
      force: force,
      grips: grips,
      difficulty: difficulty,
      instructions: instructions,
      primaryMuscles: primaryMuscles,
      secondaryMuscles: secondaryMuscles,
      tertiaryMuscles: tertiaryMuscles,
      notes: notes, // Noua notă modificată
    );
  }
}

// ---------------------------------------------------
// Muscle Target
class MuscleTarget {
  final MuscleGroup group;
  final String? detail;

  const MuscleTarget({required this.group, this.detail});

  /// 💡 UX Benefit: Returnează detaliul specific dacă există, altfel grupa mare text.
  String get label => detail ?? group.name;

  // Pentru Scraper-ul tău JSON
  factory MuscleTarget.fromJson(Map<String, dynamic> json) {
    final rawGroup = json['group'] as String? ?? 'chest';
    return MuscleTarget(
      group: MuscleGroup.values.firstWhere(
        (e) => e.name.toLowerCase() == rawGroup.toLowerCase().trim(),
        orElse: () => MuscleGroup.unknown,
      ),
      detail: json['detail'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'group': group.name,
        'detail': detail,
      };

  // Pentru stocarea locală Hive
  Map<String, dynamic> toMap() => {
        'group': group.name,
        'detail': detail,
      };

  factory MuscleTarget.fromMap(Map<dynamic, dynamic> map) {
    return MuscleTarget(
      group: MuscleGroup.values.firstWhere(
        (e) => e.name == map['group'],
        orElse: () => MuscleGroup.unknown,
      ),
      detail: map['detail'] as String?,
    );
  }
}
