import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
      // 1. Citim fișierul JSON text din folderul assets
      final String jsonString =
          await rootBundle.loadString('assets/exercises_init.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);

      // 2. Parcurgem lista și salvăm fiecare exercițiu în Hive sub formă de Map
      for (var item in jsonList) {
        // Mapăm array-ul de string-uri din JSON în Enums pentru listă
        final List<dynamic> rawGroups = item['muscleGroups'] ?? [];
        final List<MuscleGroup> parsedGroups = rawGroups.map((g) {
          return MuscleGroup.values.firstWhere(
            (e) => e.name == g,
            orElse: () => MuscleGroup.core,
          );
        }).toList();

        if (parsedGroups.isEmpty) parsedGroups.add(MuscleGroup.core);

        final exercise = Exercise(
          name: item['name'] as String,
          muscleGroups: parsedGroups,
          equipment: Equipment.values.firstWhere(
            (e) => e.name == item['equipment'],
            orElse: () => Equipment.bodyweight,
          ),
          mechanics: Mechanics.values.firstWhere(
            (e) => e.name == item['mechanics'],
            orElse: () => Mechanics.compound,
          ),
          instructions: List<String>.from(item['instructions'] ?? []),
          assetImagePath: item['assetImagePath'] as String?,
        );

        // Folosim numele ca cheie unică (put în loc de add)
        await exercisesBox.put(exercise.name, exercise.toMap());
      }

      // 3. Generăm automat și o rutină "Full Body" ca să ai pe ce da click în ecranul principal
      if (exercisesBox.isNotEmpty && routinesBox.isEmpty) {
        final initialExercises = exercisesBox.values
            .take(3)
            .map((e) => Exercise.fromMap(e as Map))
            .toList();

        final sampleRoutine = Routine(
          title: 'Full Body Starter',
          description: 'Loaded completely from your custom JSON list.',
          exercises: initialExercises,
        );

        await routinesBox.add(sampleRoutine.toMap());
      }

      debugPrint('✅ Hive base successfully seeded from new JSON schema!');
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
      title: 'Gym Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const MainNavigationHub(),
    );
  }
}
