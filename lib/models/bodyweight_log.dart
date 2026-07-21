class BodyweightLog {
  final String id;
  final DateTime date;
  final double weightInKg;

  const BodyweightLog({
    required this.id,
    required this.date,
    required this.weightInKg,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'weightInKg': weightInKg,
    };
  }

  factory BodyweightLog.fromMap(Map<dynamic, dynamic> map) {
    return BodyweightLog(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      weightInKg: (map['weightInKg'] as num).toDouble(),
    );
  }

  BodyweightLog copyWith({
    String? id,
    DateTime? date,
    double? weightInKg,
  }) {
    return BodyweightLog(
      id: id ?? this.id,
      date: date ?? this.date,
      weightInKg: weightInKg ?? this.weightInKg,
    );
  }
}
