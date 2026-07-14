import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gym_tracker/models/models.dart';

class DatabaseService {
  // Box-urile globale expuse ca proprietăți statice
  static late Box exercisesBox;
  static late Box routinesBox;
  static late Box logsBox;
  static late Box routineFoldersBox; // Noul box pentru v2.0.0
  static late Box settingsBox;

  /// 🚀 Inițializarea completă a bazei de date
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);

    // Deschidem toate cutiile necesare
    exercisesBox = await Hive.openBox('exercises');
    routinesBox = await Hive.openBox('routines');
    logsBox = await Hive.openBox('workout_logs');
    routineFoldersBox =
        await Hive.openBox('routine_folders'); // Adăugat pentru foldere
    settingsBox = await Hive.openBox('settings');

    // Executăm popularea inițială dacă este nevoie
    await _seedDatabaseFromJsonIfNeeded();

    // Rulăm migrarea automată pentru backwards compatibility
    await _runMigrations();
  }

  /// 🌱 Seed-ul tău smart din JSON mutat aici
  static Future<void> _seedDatabaseFromJsonIfNeeded() async {
    if (exercisesBox.isEmpty) {
      try {
        final String jsonString =
            await rootBundle.loadString('assets/exercises_init.json');
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
      debugPrint(
          '🚀 [Migration] Rutinele din v1.1.0 au fost mutate în folderul implicit!');
    }
  }
}
