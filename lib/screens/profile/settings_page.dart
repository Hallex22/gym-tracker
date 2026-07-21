import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce/hive.dart';

import '../../enums/enums.dart';
import '../../models/app_settings.dart';
import '../../models/bodyweight_log.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Box _settingsBox;
  late AppSettings _currentSettings;

  static const List<int> _timerDurationOptions = [30, 45, 60, 90, 120, 150, 180, 240, 300];

  @override
  void initState() {
    super.initState();
    _settingsBox = DatabaseService.settingsBox;
    _loadSettings();
  }

  void _loadSettings() {
    final Map? rawSettings = _settingsBox.get('appSettings') as Map?;
    setState(() {
      _currentSettings = rawSettings != null ? AppSettings.fromMap(rawSettings) : const AppSettings();
    });
  }

  Future<void> _saveSettings(AppSettings newSettings) async {
    setState(() {
      _currentSettings = newSettings;
    });
    await _settingsBox.put('appSettings', newSettings.toMap());
  }

  List<BodyweightLog> _getSortedBodyweightLogs() {
    final box = DatabaseService.bodyweightBox;

    final logs = box.values
        .whereType<Map>() // ne asigurăm că citim un Map
        .map((map) => BodyweightLog.fromMap(map))
        .toList();

    logs.sort((a, b) => b.date.compareTo(a.date));
    return logs;
  }

  // 📄 MODAL: Istoric și management greutate
// 📄 MODAL: Istoric și management greutate (UI Cizelat)
  void _showBodyweightHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final logs = _getSortedBodyweightLogs();

            return Padding(
              padding: EdgeInsets.only(
                top: 12,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.borderMuted,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Titlu & Subtitlu pe centru
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Body Weight History',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: context.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Track and manage your daily weight progress',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Lista cu intrări
                  if (logs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.scale_outlined,
                              size: 48,
                              color: context.textMuted.withOpacity(0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No weight entries logged yet.',
                              style: TextStyle(
                                fontSize: 14,
                                color: context.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: logs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          final displayWeight = _currentSettings.unitSystem.toDisplay(log.weightInKg);
                          final formattedWeight = _currentSettings.unitSystem.formatWeight(displayWeight);
                          final unitLabel = _currentSettings.unitSystem.label;

                          final String formattedDate =
                              '${log.date.day.toString().padLeft(2, '0')}.${log.date.month.toString().padLeft(2, '0')}.${log.date.year}';

                          return Container(
                            decoration: BoxDecoration(
                              color: context.bgDark.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.borderMuted.withOpacity(0.5)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              title: Text(
                                '$formattedWeight $unitLabel',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: context.text,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                formattedDate,
                                style: TextStyle(color: context.textMuted, fontSize: 13),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined, color: context.primary, size: 20),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      _showAddOrEditWeightDialog(
                                        existingLog: log,
                                        onSaved: () {
                                          setModalState(() {});
                                          setState(() {});
                                        },
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () async {
                                      await DatabaseService.bodyweightBox.delete(log.id);
                                      setModalState(() {});
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 20),

                  // 4. Butonul lat "Add Weight" în subsol
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        _showAddOrEditWeightDialog(
                          onSaved: () {
                            setModalState(() {});
                            setState(() {});
                          },
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'Add New Weight',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ✏️ DIALOG: Adăugare sau Editare (Salvare directă în bodyweightBox)
  void _showAddOrEditWeightDialog({
    BodyweightLog? existingLog,
    required VoidCallback onSaved,
  }) {
    final bool isEditing = existingLog != null;
    final logs = _getSortedBodyweightLogs();

    final initialDisplayVal = isEditing
        ? _currentSettings.unitSystem.toDisplay(existingLog.weightInKg)
        : (logs.isNotEmpty ? _currentSettings.unitSystem.toDisplay(logs.first.weightInKg) : 75.0);

    final controller = TextEditingController(
      text: _currentSettings.unitSystem.formatWeight(initialDisplayVal),
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.bg,
          title: Text(
            isEditing ? 'Edit Weight' : 'Log Body Weight',
            style: TextStyle(color: context.text),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                style: TextStyle(color: context.text),
                decoration: InputDecoration(
                  labelText: 'Weight (${_currentSettings.unitSystem.label})',
                  labelStyle: TextStyle(color: context.textMuted),
                  suffixText: _currentSettings.unitSystem.label,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: context.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: context.primary),
              onPressed: () async {
                final double? parsedVal = double.tryParse(controller.text);
                if (parsedVal != null && parsedVal > 0) {
                  final double weightInKg = _currentSettings.unitSystem.toStorage(parsedVal);

                  if (isEditing) {
                    final updatedLog = existingLog.copyWith(weightInKg: weightInKg);
                    // 👈 Adaugă .toMap() aici
                    await DatabaseService.bodyweightBox.put(updatedLog.id, updatedLog.toMap());
                  } else {
                    final String newId = DateTime.now().millisecondsSinceEpoch.toString();
                    final newLog = BodyweightLog(
                      id: newId,
                      date: DateTime.now(),
                      weightInKg: weightInKg,
                    );
                    // 👈 Adaugă .toMap() aici
                    await DatabaseService.bodyweightBox.put(newId, newLog.toMap());
                  }

                  if (mounted) {
                    Navigator.pop(dialogContext);
                    onSaved();
                  }
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Preluăm cea mai recentă greutate direct din boxul de istorice
    final logs = _getSortedBodyweightLogs();
    final double? latestKg = logs.isNotEmpty ? logs.first.weightInKg : null;

    final String formattedLatest = latestKg != null
        ? '${_currentSettings.unitSystem.formatWeight(_currentSettings.unitSystem.toDisplay(latestKg))} ${_currentSettings.unitSystem.label}'
        : 'N/A';

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
                            enableSoundEffects: _currentSettings.enableSoundEffects,
                            enableHapticFeedback: _currentSettings.enableHapticFeedback,
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
                        _saveSettings(
                          AppSettings(
                            unitSystem: newUnit,
                            enableSoundEffects: _currentSettings.enableSoundEffects,
                            enableHapticFeedback: _currentSettings.enableHapticFeedback,
                            theme: _currentSettings.theme,
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

          // --- SECȚIUNEA: GREUTATE CORPORALĂ ---
          _buildSectionHeader('Body Weight'),
          Card(
            elevation: 0,
            color: context.bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: context.borderMuted),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _showBodyweightHistorySheet,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.accessibility_new_outlined, color: context.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Weight',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: context.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to view history, edit or add entries',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.bgLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        formattedLatest,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.primary,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: context.textMuted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- SECȚIUNEA: REST TIMER ⏱️ ---
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
                        enableSoundEffects: _currentSettings.enableSoundEffects,
                        enableHapticFeedback: _currentSettings.enableHapticFeedback,
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      Icon(Icons.hourglass_empty_rounded, color: context.primary),
                      const SizedBox(width: 12),
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
                              'Default rest in seconds',
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
                      const SizedBox(width: 12),
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
                            child: Text('$duration s'),
                          );
                        }).toList(),
                        onChanged: (int? newDuration) {
                          if (newDuration != null) {
                            _saveSettings(
                              AppSettings(
                                unitSystem: _currentSettings.unitSystem,
                                enableSoundEffects: _currentSettings.enableSoundEffects,
                                enableHapticFeedback: _currentSettings.enableHapticFeedback,
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

          // --- SECȚIUNEA: EXTRA ---
          _buildSectionHeader('Extra'),
          Card(
            elevation: 0,
            color: context.bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: context.borderMuted),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.volume_up_outlined, color: context.primary),
                  title: Text(
                    'Sound Effects',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: context.text,
                    ),
                  ),
                  subtitle: Text(
                    'Play sound when timer finishes',
                    style: TextStyle(color: context.textMuted, fontSize: 12),
                  ),
                  value: _currentSettings.enableSoundEffects,
                  onChanged: (bool value) {
                    _saveSettings(
                      AppSettings(
                        unitSystem: _currentSettings.unitSystem,
                        enableSoundEffects: value,
                        enableHapticFeedback: _currentSettings.enableHapticFeedback,
                        theme: _currentSettings.theme,
                        enableAutoRestTimer: _currentSettings.enableAutoRestTimer,
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
                SwitchListTile(
                  secondary: Icon(Icons.vibration_outlined, color: context.primary),
                  title: Text(
                    'Haptic Feedback',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: context.text,
                    ),
                  ),
                  subtitle: Text(
                    'Vibrate on button taps, set completions and timer alert',
                    style: TextStyle(color: context.textMuted, fontSize: 12),
                  ),
                  value: _currentSettings.enableHapticFeedback,
                  onChanged: (bool value) {
                    _saveSettings(
                      AppSettings(
                        unitSystem: _currentSettings.unitSystem,
                        enableSoundEffects: _currentSettings.enableSoundEffects,
                        enableHapticFeedback: value,
                        theme: _currentSettings.theme,
                        enableAutoRestTimer: _currentSettings.enableAutoRestTimer,
                        defaultRestTimerDuration: _currentSettings.defaultRestTimerDuration,
                      ),
                    );
                  },
                ),
              ],
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
