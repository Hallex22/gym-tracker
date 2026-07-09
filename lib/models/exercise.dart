import '../enums/enums.dart';

class Exercise {
  final String name;
  final List<MuscleGroup> muscleGroups; // Lista completă (Prima poziție = Grupa Principală)
  final Equipment equipment;
  final Mechanics mechanics;
  final List<String> instructions;
  final String? assetImagePath;

  const Exercise({
    required this.name,
    required this.muscleGroups,
    required this.equipment,
    required this.mechanics,
    required this.instructions,
    this.assetImagePath,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        // Convertim lista de Enums într-o listă de String-uri pentru Hive
        'muscleGroups': muscleGroups.map((e) => e.name).toList(),
        'equipment': equipment.name,
        'mechanics': mechanics.name,
        'instructions': instructions,
        'assetImagePath': assetImagePath,
      };

  factory Exercise.fromMap(Map<dynamic, dynamic> map) {
    // Reconstruim lista de Enums din lista de String-uri salvată în Hive
    final List<dynamic> rawGroups = map['muscleGroups'] ?? [];
    final List<MuscleGroup> parsedGroups = rawGroups.map((groupName) {
      return MuscleGroup.values.firstWhere(
        (e) => e.name == groupName,
        orElse: () => MuscleGroup.chest,
      );
    }).toList();

    // Fallback în caz că lista salvată era goală din vreun motiv
    if (parsedGroups.isEmpty) {
      parsedGroups.add(MuscleGroup.chest);
    }

    return Exercise(
      name: map['name'] as String,
      muscleGroups: parsedGroups,
      equipment: Equipment.values.firstWhere(
        (e) => e.name == map['equipment'],
        orElse: () => Equipment.bodyweight,
      ),
      mechanics: Mechanics.values.firstWhere(
        (e) => e.name == map['mechanics'],
        orElse: () => Mechanics.compound,
      ),
      instructions: List<String>.from(map['instructions'] ?? []),
      assetImagePath: map['assetImagePath'] as String?,
    );
  }
}