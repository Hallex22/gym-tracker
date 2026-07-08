import 'dart:convert';
import 'package:flutter/material.dart';
import '../main.dart'; // Avem nevoie de box-urile globale (exercisesBox și logsBox)
import '../models/models.dart';

class ActiveWorkoutPage extends StatefulWidget {
  final Routine routine;
  const ActiveWorkoutPage({super.key, required this.routine});

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage> {
  final List<Map<String, dynamic>> _activeExercises = [];

  @override
  void initState() {
    super.initState();
    _initializeWorkout();
  }

  // Pregătim structura antrenamentului pornind de la exercițiile de bază ale rutinei
  void _initializeWorkout() {
    for (var exercise in widget.routine.exercises) {
      _activeExercises.add({
        'name': exercise.name,
        'sets': <Map<String, dynamic>>[
          {'weight': 0.0, 'reps': 0}
        ],
      });
    }
  }

  // Funcție care deschide un dialog cu TOATE exercițiile din JSON (salvate în exercisesBox) pentru a adăuga unul nou
  void _addNewExerciseDynamically() {
    final allExercises =
        exercisesBox.values.map((e) => Exercise.fromMap(e as Map)).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add alternative exercise'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: allExercises.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(allExercises[index].name),
                subtitle: Text(
                    allExercises[index].muscleGroup.name.toUpperCase(),
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () {
                  setState(() {
                    _activeExercises.add({
                      'name': allExercises[index].name,
                      'sets': [
                        {'weight': 0.0, 'reps': 0}
                      ],
                    });
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // Salvarea istorică în Hive
  Future<void> _finishWorkout() async {
    final log = WorkoutLog(
      date: DateTime.now(),
      routineTitle: widget.routine.title,
      workoutDataJson: jsonEncode(_activeExercises),
    );

    // Adăugăm log-ul direct în cutia de istoric din Hive
    await logsBox.add(log.toMap());

    if (!mounted) return;
    Navigator.pop(context); // Ne întoarcem la ecranul principal
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Workout saved successfully! 💪')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routine.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green, size: 30),
            onPressed: _finishWorkout,
          )
        ],
      ),
      body: ListView.builder(
        itemCount: _activeExercises.length,
        itemBuilder: (context, exIndex) {
          final exercise = _activeExercises[exIndex];
          final sets = exercise['sets'] as List<Map<String, dynamic>>;

          return Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(exercise['name'],
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () {
                          setState(() {
                            _activeExercises.removeAt(exIndex);
                          });
                        },
                      )
                    ],
                  ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 50,
                            child: Text('Set',
                                style: TextStyle(color: Colors.grey))),
                        Expanded(
                            child: Text('Weight (kg)',
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center)),
                        Expanded(
                            child: Text('Reps',
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center)),
                      ],
                    ),
                  ),
                  ...sets.map((set) {
                    int setIndex = sets.indexOf(set);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          SizedBox(
                              width: 50,
                              child: Text('${setIndex + 1}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold))),

                          // Input Greutate
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: TextFormField(
                                initialValue: set['weight'] == 0.0
                                    ? ''
                                    : set['weight'].toString(),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4)),
                                onChanged: (value) {
                                  set['weight'] = double.tryParse(value) ?? 0.0;
                                },
                              ),
                            ),
                          ),

                          // Input Repetări
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: TextFormField(
                                initialValue: set['reps'] == 0
                                    ? ''
                                    : set['reps'].toString(),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4)),
                                onChanged: (value) {
                                  set['reps'] = int.tryParse(value) ?? 0;
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            // Copiază inteligent kilogramele/repetările de la setul anterior
                            double lastWeight =
                                sets.isNotEmpty ? sets.last['weight'] : 0.0;
                            int lastReps =
                                sets.isNotEmpty ? sets.last['reps'] : 0;
                            sets.add({'weight': lastWeight, 'reps': lastReps});
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Set'),
                      ),
                      if (sets.length > 1)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              sets.removeLast();
                            });
                          },
                          child: const Text('Remove Last Set',
                              style: TextStyle(color: Colors.redAccent)),
                        )
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
            onPressed: _addNewExerciseDynamically,
            icon: const Icon(Icons.fitness_center),
            label: const Text('Add/Change Alternative Exercise'),
          ),
        ),
      ),
    );
  }
}
