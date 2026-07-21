import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gym_tracker/models/models.dart';

import '../enums/enums.dart';
import '../models/app_settings.dart';

class DatabaseService {
  // Box-urile globale expuse ca proprietăți statice
  static late Box exercisesBox;
  static late Box routinesBox;
  static late Box logsBox;
  static late Box routineFoldersBox; // Noul box pentru v2.0.0
  static late Box settingsBox;
  static late Box bodyweightBox;

  /// 🚀 Inițializarea completă a bazei de date
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);

    // Deschidem toate cutiile necesare
    exercisesBox = await Hive.openBox('exercises');
    routinesBox = await Hive.openBox('routines');
    logsBox = await Hive.openBox('workout_logs');
    routineFoldersBox = await Hive.openBox('routine_folders'); // Adăugat pentru foldere
    settingsBox = await Hive.openBox('settings');
    bodyweightBox = await Hive.openBox('bodyweightBox');

    // Executăm popularea inițială dacă este nevoie
    await _seedDatabaseFromJsonIfNeeded();

    // Rulăm migrarea automată pentru backwards compatibility
    await _runMigrations();
  }

  /// 🌱 Seed-ul tău smart din JSON mutat aici
  static Future<void> _seedDatabaseFromJsonIfNeeded() async {
    if (exercisesBox.isEmpty) {
      try {
        final String jsonString = await rootBundle.loadString('assets/exercises_init.json');
        final List<dynamic> jsonList = jsonDecode(jsonString);

        for (var item in jsonList) {
          if (item is Map<String, dynamic>) {
            final exercise = Exercise.fromJson(item);
            await exercisesBox.put(exercise.id, exercise.toMap());
          }
        }
        debugPrint('✅ Hive database successfully seeded!');
      } catch (e) {
        debugPrint('❌ Error seeding Hive database: $e');
      }
    }
  }

  /// 🛡️ Logica inteligentă pentru migrarea rutinelor vechi în noul folder (v2.0.0)
  static Future<void> _runMigrations() async {
    if (routineFoldersBox.isEmpty && routinesBox.isNotEmpty) {
      final defaultFolder = RoutineFolder(
        id: 'default_folder',
        name: 'My Routines 📋',
        createdAt: DateTime.now(),
        routineKeys: [],
      );

      // Mutăm cheile tuturor rutinelor vechi în acest folder nou
      for (var key in routinesBox.keys) {
        defaultFolder.routineKeys.add(key);
      }

      await routineFoldersBox.put(defaultFolder.id, defaultFolder.toMap());
      debugPrint('🚀 [Migration] Rutinele din v1.1.0 au fost mutate în folderul implicit!');
    }
  }

  // Utilitare
  static UnitSystem get globalUnit {
    if (!settingsBox.isOpen) return UnitSystem.kg; // Fallback de siguranță

    final Map? rawSettings = settingsBox.get('appSettings') as Map?;
    if (rawSettings == null) return UnitSystem.kg;

    final settings = AppSettings.fromMap(rawSettings);
    return settings.unitSystem;
  }

  static AppSettings? get appSettings {
    if (!settingsBox.isOpen) return null;
    final Map? rawSettings = settingsBox.get('appSettings') as Map?;
    if (rawSettings == null) return null;
    final settings = AppSettings.fromMap(rawSettings);
    return settings;
  }

  static double getLatestBodyweightInKg({double fallbackWeight = 75.0}) {
    final box = bodyweightBox;
    if (box.isEmpty) return fallbackWeight;

    final logs = box.values.whereType<Map>().map((map) => BodyweightLog.fromMap(map)).toList();

    if (logs.isEmpty) return fallbackWeight;

    logs.sort((a, b) => b.date.compareTo(a.date));
    return logs.first.weightInKg;
  }

  static Future<void> saveBodyweight(double weightInKg) async {
    final String id = DateTime.now().millisecondsSinceEpoch.toString();

    final newLog = BodyweightLog(
      id: id,
      date: DateTime.now(),
      weightInKg: weightInKg,
    );

    // Salvăm direct ca Map așa cum se așteaptă SettingsPage
    await bodyweightBox.put(id, newLog.toMap());
  }

  static Equipment getEquipmentForExerciseId(int id) {
    final box = DatabaseService.exercisesBox;
    final exerciseData = box.get(id);
    if (exerciseData != null) {
      if (exerciseData is Exercise) return exerciseData.equipment;
      if (exerciseData is Map) {
        final equipmentString = exerciseData['equipment'] as String?;
        return Equipment.values.firstWhere(
          (e) => e.name == equipmentString,
          orElse: () => Equipment.barbell,
        );
      }
    }
    return Equipment.barbell;
  }
}
