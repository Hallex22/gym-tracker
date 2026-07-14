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

  @override
  void initState() {
    super.initState();
    _settingsBox = DatabaseService.settingsBox;
    _loadSettings();
  }

  void _loadSettings() {
    final Map? rawSettings = _settingsBox.get('appSettings') as Map?;
    setState(() {
      _currentSettings = rawSettings != null
          ? AppSettings.fromMap(rawSettings)
          : const AppSettings(); // Valori default din clasă

      _weightController.text = _currentSettings.bodyWeight.toStringAsFixed(1);
    });
  }

  // Funcție centralizată care salvează tot obiectul modificat în Hive
  Future<void> _saveSettings(AppSettings newSettings) async {
    setState(() {
      _currentSettings = newSettings;
    });
    await _settingsBox.put('appSettings', newSettings.toMap());
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
            color: context.bg.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: context.borderMuted.withOpacity(0.5)),
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
                            theme: newTheme, // Noua temă
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
            color: context.bg.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: context.borderMuted.withOpacity(0.5)),
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
                        _saveSettings(
                          AppSettings(
                            unitSystem: newUnit, // Noua unitate de măsură
                            bodyWeight: _currentSettings.bodyWeight,
                            enableSoundEffects: _currentSettings.enableSoundEffects,
                            theme: _currentSettings.theme,
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

          // --- SECȚIUNEA: GREUTATE CORPORALĂ ---
          Card(
            elevation: 0,
            color: context.bg.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: context.borderMuted.withOpacity(0.5)),
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
                              hintText: 'e.g. 75.0',
                              hintStyle: TextStyle(color: context.textMuted),
                            ),
                            onChanged: (val) {
                              final double? parsedWeight = double.tryParse(val);
                              if (parsedWeight != null && parsedWeight > 0) {
                                _saveSettings(
                                  AppSettings(
                                    unitSystem: _currentSettings.unitSystem,
                                    bodyWeight: parsedWeight, // Noua greutate
                                    enableSoundEffects: _currentSettings.enableSoundEffects,
                                    theme: _currentSettings.theme,
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

          // --- SECȚIUNEA: ALTE SETĂRI ---
          _buildSectionHeader('Extra'),
          Card(
            elevation: 0,
            color: context.bg.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: context.borderMuted.withOpacity(0.5)),
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
                    enableSoundEffects: value, // Noua stare a sunetului
                    theme: _currentSettings.theme,
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