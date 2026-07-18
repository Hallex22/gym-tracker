import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce/hive.dart';
import '../../enums/enums.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart'; // Importă extensiile tale context.bg, context.text etc.
import '../../models/app_settings.dart'; // Ajustează calea către clasa ta AppSettings

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Box _settingsBox;

  // Obiectul local care va ține starea setărilor active
  late AppSettings _currentSettings;

  final TextEditingController _weightController = TextEditingController();

  // Opțiuni predefinite pentru timpul de odihnă (în secunde)
  static const List<int> _timerDurationOptions = [30, 45, 60, 90, 120, 150, 180, 240, 300];

  @override
  void initState() {
    super.initState();
    _settingsBox = DatabaseService.settingsBox;
    _loadSettings();
  }

  // Încarcă setările și face conversia greutății salvate în kg pentru afișarea în UI
  void _loadSettings() {
    final Map? rawSettings = _settingsBox.get('appSettings') as Map?;
    setState(() {
      _currentSettings =
          rawSettings != null ? AppSettings.fromMap(rawSettings) : const AppSettings(); // Valori default din clasă

      _updateWeightControllerValue(_currentSettings);
    });
  }

  // Actualizează textul din controller în funcție de unitatea de măsură curentă
  void _updateWeightControllerValue(AppSettings settings) {
    // Convertim greutatea din kg în unitatea de afișare (kg sau lbs) folosind enum-ul tău
    final double displayWeight = settings.unitSystem.toDisplay(settings.bodyWeight);

    // Formatăm textul folosind metoda nativă din enum (elimină .0 dacă e număr întreg)
    _weightController.text = settings.unitSystem.formatWeight(displayWeight);
  }

  // Funcție centralizată care salvează tot obiectul modificat în Hive
  Future<void> _saveSettings(AppSettings newSettings) async {
    setState(() {
      _currentSettings = newSettings;
    });
    await _settingsBox.put('appSettings', newSettings.toMap());
  }

  // Ajută la formatarea secundelor într-un format prietenos pentru Dropdown (ex: 90 -> "1:30 min")
  String _formatDurationLabel(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    if (minutes == 0) return '$seconds s';
    if (seconds == 0) return '$minutes min';
    return '$minutes:${seconds.toString().padLeft(2, '0')} min';
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: const Text('Settings ⚙️'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- SECȚIUNEA: ASPECT (THEME) ---
          _buildSectionHeader('Appearance'),
          Card(
            elevation: 0,
            color: context.bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: context.borderMuted),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette_outlined, color: context.primary),
                      const SizedBox(width: 12),
                      Text(
                        'App Theme',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: context.text,
                        ),
                      ),
                    ],
                  ),
                  DropdownButton<AppThemeMode>(
                    value: _currentSettings.theme,
                    dropdownColor: context.bg,
                    style: TextStyle(color: context.text, fontSize: 15),
                    underline: const SizedBox(),
                    borderRadius: BorderRadius.circular(8),
                    items: const [
                      DropdownMenuItem(
                        value: AppThemeMode.dark,
                        child: Text('Dark Mode 🌙'),
                      ),
                      DropdownMenuItem(
                        value: AppThemeMode.light,
                        child: Text('Light Mode ☀️'),
                      ),
                    ],
                    onChanged: (AppThemeMode? newTheme) {
                      if (newTheme != null) {
                        _saveSettings(
                          AppSettings(
                            unitSystem: _currentSettings.unitSystem,
                            bodyWeight: _currentSettings.bodyWeight,
                            enableSoundEffects: _currentSettings.enableSoundEffects,
                            theme: newTheme,
                            enableAutoRestTimer: _currentSettings.enableAutoRestTimer,
                            defaultRestTimerDuration: _currentSettings.defaultRestTimerDuration,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- SECȚIUNEA: PREFERINȚE (UNITĂȚI) ---
          _buildSectionHeader('Preferences'),
          Card(
            elevation: 0,
            color: context.bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: context.borderMuted),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.scale_outlined, color: context.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Weight Unit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: context.text,
                        ),
                      ),
                    ],
                  ),
                  DropdownButton<UnitSystem>(
                    value: _currentSettings.unitSystem,
                    dropdownColor: context.bg,
                    style: TextStyle(color: context.text, fontSize: 15),
                    underline: const SizedBox(),
                    borderRadius: BorderRadius.circular(8),
                    items: const [
                      DropdownMenuItem(
                        value: UnitSystem.kg,
                        child: Text('Kilograms (kg)'),
                      ),
                      DropdownMenuItem(
                        value: UnitSystem.lbs,
                        child: Text('Pounds (lbs)'),
                      ),
                    ],
                    onChanged: (UnitSystem? newUnit) {
                      if (newUnit != null) {
                        // Când se schimbă unitatea, salvăm preferința, dar păstrăm greutatea corpului neschimbată în fundal (în kg).
                        final AppSettings updatedSettings = AppSettings(
                          unitSystem: newUnit,
                          bodyWeight: _currentSettings.bodyWeight,
                          enableSoundEffects: _currentSettings.enableSoundEffects,
                          theme: _currentSettings.theme,
                          enableAutoRestTimer: _currentSettings.enableAutoRestTimer,
                          defaultRestTimerDuration: _currentSettings.defaultRestTimerDuration,
                        );
                        _saveSettings(updatedSettings);
                        // Recalculăm valoarea textului din căsuța de greutate pe baza noii unități selectate
                        _updateWeightControllerValue(updatedSettings);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- SECȚIUNEA: GREUTATE CORPORALĂ ---
          Card(
            elevation: 0,
            color: context.bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: context.borderMuted),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.accessibility_new_outlined, color: context.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Body Weight',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: context.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Used to calculate volume for bodyweight exercises like pull-ups, push-ups, and dips.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 45,
                          child: TextField(
                            controller: _weightController,
                            style: TextStyle(color: context.text),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              hintText: _currentSettings.unitSystem == UnitSystem.lbs ? 'e.g. 165.0' : 'e.g. 75.0',
                              hintStyle: TextStyle(color: context.textMuted),
                            ),
                            onChanged: (val) {
                              final double? parsedInputValue = double.tryParse(val);
                              if (parsedInputValue != null && parsedInputValue > 0) {
                                // Folosim direct toStorage din enum ca să scăpăm de duplicarea factorului de conversie!
                                double weightInKg = _currentSettings.unitSystem.toStorage(parsedInputValue);
                                _saveSettings(
                                  AppSettings(
                                    unitSystem: _currentSettings.unitSystem,
                                    bodyWeight: weightInKg, // Salvat permanent în KG în baza de date!
                                    enableSoundEffects: _currentSettings.enableSoundEffects,
                                    theme: _currentSettings.theme,
                                    enableAutoRestTimer: _currentSettings.enableAutoRestTimer,
                                    defaultRestTimerDuration: _currentSettings.defaultRestTimerDuration,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: context.bgLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _currentSettings.unitSystem.label, // "kg" sau "lbs"
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: context.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- 🆕 SECȚIUNEA: REST TIMER ⏱️ ---
          _buildSectionHeader('Rest Timer'),
          Card(
            elevation: 0,
            color: context.bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: context.borderMuted),
            ),
            child: Column(
              children: [
                // Comutator pentru pornire automată
                SwitchListTile(
                  secondary: Icon(Icons.auto_awesome_outlined, color: context.primary),
                  title: Text(
                    'Auto Start Timer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: context.text,
                    ),
                  ),
                  subtitle: Text(
                    'Start rest after checking off a set',
                    style: TextStyle(color: context.textMuted, fontSize: 12),
                  ),
                  value: _currentSettings.enableAutoRestTimer,
                  onChanged: (bool value) {
                    _saveSettings(
                      AppSettings(
                        unitSystem: _currentSettings.unitSystem,
                        bodyWeight: _currentSettings.bodyWeight,
                        enableSoundEffects: _currentSettings.enableSoundEffects,
                        theme: _currentSettings.theme,
                        enableAutoRestTimer: value,
                        defaultRestTimerDuration: _currentSettings.defaultRestTimerDuration,
                      ),
                    );
                  },
                ),
                Divider(
                  height: 1,
                  color: context.borderMuted,
                  indent: 16,
                  endIndent: 16,
                ),
                // Dropdown pentru durata de odihnă implicită (FĂRĂ OVERFLOW!)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      Icon(Icons.hourglass_empty_rounded, color: context.primary),
                      const SizedBox(width: 12),
                      // 💡 Expanded forțează textele să ocupe doar spațiul disponibil și să nu dea push la Dropdown în afara ecranului
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Default Duration',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: context.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Default rest in seconds', // Afișează clar că e în secunde
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12), // Spațiu de siguranță între text și Dropdown
                      DropdownButton<int>(
                        value: _currentSettings.defaultRestTimerDuration,
                        dropdownColor: context.bg,
                        style: TextStyle(color: context.text, fontSize: 15),
                        underline: const SizedBox(),
                        borderRadius: BorderRadius.circular(8),
                        menuMaxHeight: 250,
                        items: _timerDurationOptions.map<DropdownMenuItem<int>>((int duration) {
                          return DropdownMenuItem<int>(
                            value: duration,
                            child: Text('$duration s'), // ⏱️ Format direct în secunde (ex: "90 s")
                          );
                        }).toList(),
                        onChanged: (int? newDuration) {
                          if (newDuration != null) {
                            _saveSettings(
                              AppSettings(
                                unitSystem: _currentSettings.unitSystem,
                                bodyWeight: _currentSettings.bodyWeight,
                                enableSoundEffects: _currentSettings.enableSoundEffects,
                                theme: _currentSettings.theme,
                                enableAutoRestTimer: _currentSettings.enableAutoRestTimer,
                                defaultRestTimerDuration: newDuration,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- SECȚIUNEA: ALTE SETĂRI ---
          _buildSectionHeader('Extra'),
          Card(
            elevation: 0,
            color: context.bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: context.borderMuted),
            ),
            child: SwitchListTile(
              secondary: Icon(Icons.volume_up_outlined, color: context.primary),
              title: Text(
                'Sound Effects',
                style: TextStyle(color: context.text),
              ),
              subtitle: Text(
                'Play sound when timer finishes',
                style: TextStyle(color: context.textMuted),
              ),
              value: _currentSettings.enableSoundEffects,
              onChanged: (bool value) {
                _saveSettings(
                  AppSettings(
                    unitSystem: _currentSettings.unitSystem,
                    bodyWeight: _currentSettings.bodyWeight,
                    enableSoundEffects: value,
                    theme: _currentSettings.theme,
                    enableAutoRestTimer: _currentSettings.enableAutoRestTimer,
                    defaultRestTimerDuration: _currentSettings.defaultRestTimerDuration,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: context.primary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
