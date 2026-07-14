import '../enums/enums.dart';

class AppSettings {
  final UnitSystem unitSystem;
  final double bodyWeight;
  final bool enableSoundEffects;
  final AppThemeMode theme;

  const AppSettings(
      {this.unitSystem = UnitSystem.kg,
      this.bodyWeight = 75.0, // valoare implicită rezonabilă
      this.enableSoundEffects = true,
      this.theme = AppThemeMode.dark});

  Map<String, dynamic> toMap() => {
        'unitSystem': unitSystem.name,
        'bodyWeight': bodyWeight,
        'enableSoundEffects': enableSoundEffects,
        'theme': theme.name,
      };

  factory AppSettings.fromMap(Map<dynamic, dynamic> map) {
    return AppSettings(
      unitSystem: UnitSystem.values.firstWhere(
        (e) => e.name == map['unitSystem'],
        orElse: () => UnitSystem.kg,
      ),
      bodyWeight: (map['bodyWeight'] as num?)?.toDouble() ?? 75.0,
      enableSoundEffects: map['enableSoundEffects'] as bool? ?? true,
      theme: AppThemeMode.values.firstWhere(
        (e) => e.name == map['theme'],
        orElse: () => AppThemeMode.dark,
      ),
    );
  }
}
