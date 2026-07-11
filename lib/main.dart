import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'theme/app_theme.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'enums/enums.dart';
import 'models/models.dart';
import 'navigation/main_navigation_hub.dart';

// Box-urile globale pe care le importăm în celelalte pagini
late Box exercisesBox;
late Box routinesBox;
late Box logsBox;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Găsim folderul sigur unde sistemul de operare ne lasă să salvăm datele
  final dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);

  // Deschidem bazele de date (cutiile) pentru exerciții, rutine și istoric
  exercisesBox = await Hive.openBox('exercises');
  routinesBox = await Hive.openBox('routines');
  logsBox = await Hive.openBox('workout_logs');

  // Dacă vrei să forțezi curățarea datelor vechi (la schimbarea de modele),
  // poți decomenta linia de mai jos o singură dată:
  await exercisesBox.clear();
  await routinesBox.clear();
  await logsBox.clear();

  // Dacă aplicația e proaspăt instalată, citim JSON-ul din assets și populăm Hive
  await _seedDatabaseFromJsonIfNeeded();

  runApp(const GymTrackerApp());
}

Future<void> _seedDatabaseFromJsonIfNeeded() async {
  if (exercisesBox.isEmpty) {
    try {
      // 1. Citim fișierul JSON brut din assets
      final String jsonString =
          await rootBundle.loadString('assets/exercises_init.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);

      for (var item in jsonList) {
        if (item is Map<String, dynamic>) {
          final exercise = Exercise.fromJson(item);
          await exercisesBox.put(exercise.id, exercise.toMap());
        }
      }

      // 3. Generăm o rutină "Full Body Starter" ca demo
      if (exercisesBox.isNotEmpty && routinesBox.isEmpty) {
        // Luăm primele 3 exerciții din baza proaspăt populată
        final initialExercises = exercisesBox.values
            .take(3)
            .map((e) => Exercise.fromMap(e as Map))
            .toList();

        final sampleRoutine = Routine(
          title: 'Full Body Starter 🏋️‍♂️',
          description: 'A sample routine generated as a starter',
          exercises: initialExercises,
        );

        await routinesBox.add(sampleRoutine.toMap());
      }

      debugPrint(
          '✅ Hive database successfully seeded using the smart Exercise.fromJson factory!');
    } catch (e) {
      debugPrint('❌ Error seeding Hive database: $e');
    }
  }
}

class GymTrackerApp extends StatelessWidget {
  const GymTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GymTracker',
      theme: AppTheme.darkTheme,
      home: const MainNavigationHub(),
    );
  }
}
