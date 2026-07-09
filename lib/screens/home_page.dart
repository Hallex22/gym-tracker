import 'package:flutter/material.dart';
import 'package:gym_tracker/enums/workout_status.dart';
import 'package:gym_tracker/screens/routines/routine_form_page.dart';
import '../main.dart';
import '../models/models.dart';
import 'workout/active_workout_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Păstrăm perechile cheie-rutină din Hive pentru a putea face editarea corect
  List<MapEntry<dynamic, Routine>> _routineEntries = [];
  WorkoutLog? _activeWorkout;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    // 1. Încărcăm rutinele păstrându-le cheia unică din Hive (.toMap())
    final entries = routinesBox.toMap().entries.map((entry) {
      return MapEntry(entry.key, Routine.fromMap(entry.value as Map));
    }).toList();

    // 2. Căutăm dacă există vreun antrenament cu statusul 'started'
    WorkoutLog? active;
    for (var value in logsBox.values) {
      final log = WorkoutLog.fromMap(value as Map);
      if (log.status == WorkoutStatus.started) {
        active = log;
        break;
      }
    }

    setState(() {
      _routineEntries = entries;
      _activeWorkout = active;
    });
  }

  void _tryStartWorkout(Routine routine) {
    if (_activeWorkout != null) {
      _showActiveWorkoutAlert();
    } else {
      _navigateToActiveWorkout(routine);
    }
  }

  void _startEmptyWorkout() {
    if (_activeWorkout != null) {
      _showActiveWorkoutAlert();
    } else {
      final emptyRoutine = Routine(
        title: 'Empty Workout',
        description: 'Custom session',
        exercises: [],
      );
      _navigateToActiveWorkout(emptyRoutine);
    }
  }

  void _navigateToActiveWorkout(Routine routine) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ActiveWorkoutPage(routine: routine)),
    );
    _loadData(); 
  }

  void _showActiveWorkoutAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workout in Progress ⚠️'),
        content: const Text('You already have an active workout session. Please finish or cancel the current session before starting a new one.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GymTracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              // 1. ANTRENAMENTUL ÎN DESFĂȘURARE (Dacă există)
              if (_activeWorkout != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Card(
                    color: Colors.amber.withOpacity(0.15),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Colors.amber, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: const CircleAvatar(
                        backgroundColor: Colors.amber,
                        child: Icon(Icons.fitness_center, color: Colors.black),
                      ),
                      title: const Text('CURRENT WORKOUT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(_activeWorkout!.routineTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.amber, size: 16),
                      onTap: () {
                        _navigateToActiveWorkout(Routine(title: _activeWorkout!.routineTitle, exercises: []));
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // 2. BUTONUL: START EMPTY WORKOUT
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.withOpacity(0.2),
                      foregroundColor: Colors.blueAccent,
                      side: const BorderSide(color: Colors.blueAccent, width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _startEmptyWorkout,
                    icon: const Icon(Icons.add),
                    label: const Text('Start Empty Workout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.only(left: 18.0, top: 16.0, bottom: 8.0),
                child: Text('Routines', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),

              // 3. LISTA DE RUTINE
              if (_routineEntries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: Text('No routines found. Create your first one below!')),
                )
              else
                ..._routineEntries.map((entry) {
                  final routineKey = entry.key;
                  final routine = entry.value;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    elevation: 1,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(routine.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      subtitle: Text('${routine.exercises.length} exercises ${routine.description != null ? "• ${routine.description}" : ""}'),
                      
                      // Butonul verde de Play - DOAR ACESTA pornește antrenamentul
                      trailing: GestureDetector(
                        onTap: () => _tryStartWorkout(routine),
                        child: const CircleAvatar(
                          backgroundColor: Colors.green,
                          radius: 18,
                          child: Icon(Icons.play_arrow, color: Colors.white, size: 20),
                        ),
                      ),
                      
                      // Apăsarea pe restul cardului deschide pagina de editare
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoutineFormPage(routine: routine, routineKey: routineKey),
                          ),
                        );
                        _loadData(); // Reîncărcăm lista în caz că a editat sau șters ceva
                      },
                    ),
                  );
                }),

              const SizedBox(height: 12),

              // 4. BUTONUL DE LA FINAL: NEW ROUTINE
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: const Icon(Icons.playlist_add, color: Colors.blueAccent),
                  title: const Text('New Routine', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RoutineFormPage()),
                    );
                    _loadData();
                  },
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}