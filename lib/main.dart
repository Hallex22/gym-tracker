import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'models/models.dart';
import 'screens/home_page.dart';

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

  // Dacă aplicația e proaspăt instalată, citim JSON-ul din assets și populăm Hive
  await _seedDatabaseFromJsonIfNeeded();

  runApp(const GymTrackerApp());
}

Future<void> _seedDatabaseFromJsonIfNeeded() async {
  if (exercisesBox.isEmpty) {
    try {
      // 1. Citim fișierul JSON text din folderul assets
      final String jsonString = await rootBundle.loadString('assets/exercises_init.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);

      // 2. Parcurgem lista și salvăm fiecare exercițiu în Hive sub formă de Map
      for (var item in jsonList) {
        final exercise = Exercise(
          name: item['name'],
          muscleGroup: MuscleGroup.values.firstWhere(
            (e) => e.name == item['muscleGroup'],
            orElse: () => MuscleGroup.core,
          ),
        );
        await exercisesBox.add(exercise.toMap());
      }

      // 3. Generăm automat și o rutină "Full Body" ca să ai pe ce da click în ecranul principal
      if (exercisesBox.isNotEmpty) {
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
      
      debugPrint('✅ Hive base successfully seeded from JSON!');
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomePage(), // Deschide direct ecranul din lib/screens/home_page.dart
    );
  }
}