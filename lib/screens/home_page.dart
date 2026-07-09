import 'package:flutter/material.dart';
import 'package:gym_tracker/enums/workout_status.dart';
import 'package:gym_tracker/screens/routines/routine_detail_page.dart';
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
  List<MapEntry<dynamic, Routine>> _routineEntries = [];
  WorkoutLog? _activeWorkout;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final entries = routinesBox.toMap().entries.map((entry) {
      return MapEntry(entry.key, Routine.fromMap(entry.value as Map));
    }).toList();

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
      MaterialPageRoute(
          builder: (context) => ActiveWorkoutPage(routine: routine)),
    );
    _loadData();
  }

  void _showActiveWorkoutAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workout in Progress ⚠️'),
        content: const Text(
            'You already have an active workout session. Please finish or cancel the current session before starting a new one.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  // --- DRAWER-UL DE JOS PENTRU OPȚIUNI (MODAL BOTTOM SHEET) ---
  void _showRoutineOptionsSheet(
      BuildContext context, Routine routine, dynamic routineKey) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    routine.title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Divider(),

                // 1. View Routine
                ListTile(
                  leading: Icon(Icons.visibility_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('View Routine'),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoutineDetailPage(
                            routine: routine, routineKey: routineKey),
                      ),
                    );
                    _loadData();
                  },
                ),

                // 2. Edit Routine
                ListTile(
                  leading: const Icon(Icons.edit_outlined,
                      color: Colors
                          .orangeAccent), // Lăsat portocaliu pentru UX intuitiv de editare
                  title: const Text('Edit Routine'),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoutineFormPage(
                            routine: routine, routineKey: routineKey),
                      ),
                    );
                    _loadData();
                  },
                ),

                // 3. Share Routine
                ListTile(
                  leading: Icon(Icons.share_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  title: const Text('Share Routine'),
                  subtitle: Text('Future feature 🚀',
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Sharing will be available in a future update!')),
                    );
                  },
                ),
                const Divider(),

                // 4. Delete Routine (Cu prompt de confirmare)
                ListTile(
                  leading:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Delete Routine',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmationDialog(
                        context, routineKey, routine.title);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- DIALOGUL DE CONFIRMARE PENTRU ȘTERGERE ---
  void _showDeleteConfirmationDialog(
      BuildContext context, dynamic routineKey, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Routine? 🚨'),
        content: Text(
            'Are you sure you want to delete "$title"? This will not affect your workout history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              )),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await routinesBox.delete(routineKey);
              if (!context.mounted) return;
              Navigator.pop(context);
              _loadData();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"$title" deleted.')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GymTracker'),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Card(
                    color: Colors.amber.withOpacity(
                        0.12), // Păstrat un pic amber pentru atenție (Avertisment)
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Colors.amber, width: 1.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: const CircleAvatar(
                        backgroundColor: Colors.amber,
                        child: Icon(Icons.fitness_center, color: Colors.black),
                      ),
                      title: const Text('CURRENT WORKOUT',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(_activeWorkout!.routineTitle,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          color: Colors.amber, size: 16),
                      onTap: () {
                        _navigateToActiveWorkout(Routine(
                            title: _activeWorkout!.routineTitle,
                            exercises: []));
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // 2. BUTONUL: START EMPTY WORKOUT
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.12),
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.4),
                          width: 1),
                    ),
                    onPressed: _startEmptyWorkout,
                    icon: const Icon(Icons.add),
                    label: const Text('Start Empty Workout',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.only(left: 18.0, top: 16.0, bottom: 8.0),
                child: Text('Routines',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant)), // Text Muted global
              ),

              // 3. LISTA DE RUTINE
              if (_routineEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                      child: Text(
                          'No routines found. Create your first one below!',
                          style: Theme.of(context).textTheme.bodyMedium)),
                )
              else
                ..._routineEntries.map((entry) {
                  final routineKey = entry.key;
                  final routine = entry.value;

                  final String exercisesPreview = routine.exercises.isEmpty
                      ? "No exercises added yet"
                      : routine.exercises.map((e) => e.name).join(', ');

                  return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => RoutineDetailPage(
                                      routine: routine,
                                      routineKey: routineKey)));
                          _loadData();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Titlul și cele 3 puncte orizontale
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      routine.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.more_horiz,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                                    onPressed: () => _showRoutineOptionsSheet(
                                        context, routine, routineKey),
                                  ),
                                ],
                              ),

                              // Lista compactă cu numele exercițiilor (Folosește bodyMedium text-muted automat)
                              Text(
                                exercisesPreview,
                                style: Theme.of(context).textTheme.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 16),

                              // Noul buton modern pentru începerea antrenamentului
                              SizedBox(
                                width: double.infinity,
                                height: 40,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.12),
                                    foregroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 0),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _tryStartWorkout(routine),
                                  icon: const Icon(Icons.play_arrow, size: 18),
                                  label: const Text('Start Workout',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ));
                }),

              const SizedBox(height: 12),

              // 4. BUTONUL DE LA FINAL: NEW ROUTINE
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withOpacity(0.2),
                        width: 1,
                        style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: Icon(Icons.playlist_add,
                      color: Theme.of(context).colorScheme.primary),
                  title: Text('New Routine',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold)),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const RoutineFormPage()),
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
