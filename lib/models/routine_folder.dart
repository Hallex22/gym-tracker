class RoutineFolder {
  final String id;
  String name;
  final DateTime createdAt;
  List<dynamic> routineKeys;

  RoutineFolder({
    required this.id,
    required this.name,
    required this.createdAt,
    List<dynamic>? routineKeys,
  }) : this.routineKeys = routineKeys ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'routineKeys': routineKeys,
    };
  }

  factory RoutineFolder.fromMap(Map<dynamic, dynamic> map) {
    return RoutineFolder(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      routineKeys: List<dynamic>.from(map['routineKeys'] ?? []),
    );
  }
}
