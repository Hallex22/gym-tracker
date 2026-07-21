import '../enums/enums.dart';

class AppSettings {
  final UnitSystem unitSystem;
  final bool enableSoundEffects;
  final bool enableHapticFeedback;
  final AppThemeMode theme;

  final bool enableAutoRestTimer;
  final int defaultRestTimerDuration;

  const AppSettings({
    this.unitSystem = UnitSystem.kg,
    this.enableSoundEffects = true,
    this.enableHapticFeedback = true,
    this.theme = AppThemeMode.dark,
    this.enableAutoRestTimer = false,
    this.defaultRestTimerDuration = 90,
  });

  Map<String, dynamic> toMap() => {
        'unitSystem': unitSystem.name,
        'enableHapticFeedback': enableHapticFeedback,
        'enableSoundEffects': enableSoundEffects,
        'theme': theme.name,
        'enableAutoRestTimer': enableAutoRestTimer,
        'defaultRestTimerDuration': defaultRestTimerDuration,
      };

  factory AppSettings.fromMap(Map<dynamic, dynamic> map) {
    return AppSettings(
      unitSystem: UnitSystem.values.firstWhere(
        (e) => e.name == map['unitSystem'],
        orElse: () => UnitSystem.kg,
      ),
      enableSoundEffects: map['enableSoundEffects'] as bool? ?? true,
      enableHapticFeedback: map['enableHapticFeedback'] as bool? ?? true,
      theme: AppThemeMode.values.firstWhere(
        (e) => e.name == map['theme'],
        orElse: () => AppThemeMode.dark,
      ),
      enableAutoRestTimer: map['enableAutoRestTimer'] as bool? ?? false,
      defaultRestTimerDuration: map['defaultRestTimerDuration'] as int? ?? 90,
    );
  }
}
