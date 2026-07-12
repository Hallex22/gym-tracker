import 'package:flutter/material.dart';
import 'package:gym_tracker/screens/exercises/exercise_detail_page.dart';
import 'package:gym_tracker/screens/routines/routine_form_page.dart';
import '../../main.dart'; // Pentru acces la routinesBox și exercisesBox
import '../../models/models.dart';
import '../../widgets/app_actions_sheet.dart'; // 💡 Importul drawer-ului tău custom
import '../workout/active_workout_page.dart';

class RoutineDetailPage extends StatefulWidget {
  final Routine routine;
  final dynamic routineKey; // Cheia din Hive pentru a o putea trimite mai departe la editare/ștergere

  const RoutineDetailPage({
    super.key,
    required this.routine,
    required this.routineKey,
  });

  @override
  State<RoutineDetailPage> createState() => _RoutineDetailPageState();
}

class _RoutineDetailPageState extends State<RoutineDetailPage> {
  // --- DRAWER-UL TĂU CUSTOM PREMIUM PENTRU OPȚIUNI ---
  void _showRoutineOptionsSheet(BuildContext context) {
    final theme = Theme.of(context);

    AppActionsSheet.show(
      context: context,
      title: 'Routine Options ⚙️',
      subtitle: widget.routine.title,
      actions: [
        // 1. Editare Rutină
        SheetActionItem(
          icon: Icons.edit_outlined,
          label: 'Edit Routine Structure',
          color: Colors.orangeAccent,
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RoutineFormPage(
                  routine: widget.routine,
                  routineKey: widget.routineKey,
                ),
              ),
            );
            if (mounted) setState(() {});
          },
        ),

        // 2. Share Rutină (💡 ACUM ESTE FUNCȚIONAL!)
        SheetActionItem(
          icon: Icons.share_outlined,
          label: 'Share Routine Code',
          color: theme.colorScheme.primary,
          onPressed: () {
            // Generăm codul Base64 ultra-compact pe care l-am implementat în model
            final String shareCode = widget.routine.toShareCode();
            
            // Îl copiem direct în Clipboard (opțional, poți folosi și pachetul share_plus pe viitor)
            // Pentru moment, îl arătăm într-un dialog curat de unde îl poate copia
            _showShareCodeDialog(context, shareCode);
          },
        ),

        // 3. Ștergere Rutină
        SheetActionItem(
          icon: Icons.delete_outline,
          label: 'Delete Routine',
          color: Colors.redAccent,
          onPressed: () {
            _showDeleteConfirmationDialog(context);
          },
        ),
      ],
    );
  }

  // --- DIALOG AFIȘARE COD SHARE ---
  void _showShareCodeDialog(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Routine Share Code 📋'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Give this code to your friend. They can import it directly into their app:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            SelectableText(
              code,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.blueAccent),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // --- DIALOGUL DE CONFIRMARE PENTRU ȘTERGERE ---
  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Routine? 🚨'),
        content: Text('Are you sure you want to delete "${widget.routine.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await routinesBox.delete(widget.routineKey);
              if (!context.mounted) return;

              Navigator.pop(context); // Închidem dialogul
              Navigator.pop(context); // Ne întoarcem pe HomePage

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"${widget.routine.title}" deleted.')),
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Routine Preview'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Options',
            onPressed: () => _showRoutineOptionsSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- HEADER RUTINĂ ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Icon(Icons.layers, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.routine.title,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.routine.exercises.length} exercises included',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.primary.withOpacity(0.2)),

          // --- LISTA DE EXERCIȚII DIN RUTINĂ ---
          Expanded(
            child: widget.routine.exercises.isEmpty
                ? Center(
                    child: Text('This routine has no exercises yet.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  )
                : ListView.builder(
                    itemCount: widget.routine.exercises.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final routineExercise = widget.routine.exercises[index];

                      // 💡 SPARLA PRINCIPALĂ: Extragem obiectul full Exercise din cutia globală Hive
                      final rawExerciseData = exercisesBox.get(routineExercise.exerciseId);

                      // Dacă dintr-un motiv oarecare exercițiul nu mai există în baza locală, creăm un fallback vizual durabil
                      Exercise? fullExercise;
                      String exerciseName = 'Unknown Exercise';
                      String muscleGroup = 'Core';
                      String equipmentName = 'Bodyweight';

                      if (rawExerciseData != null) {
                        if (rawExerciseData is Map) {
                          fullExercise = Exercise.fromMap(rawExerciseData);
                        } else {
                          fullExercise = rawExerciseData as Exercise;
                        }
                        
                        exerciseName = fullExercise.name;
                        muscleGroup = fullExercise.primaryMuscles.isNotEmpty 
                            ? fullExercise.primaryMuscles.first.group.name 
                            : 'Target';
                        equipmentName = fullExercise.equipment.name.toUpperCase();
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            if (fullExercise != null) {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ExerciseDetailPage(exercise: fullExercise!),
                                  ));
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Row(
                              children: [
                                Text(
                                  '${index + 1}',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant, fontSize: 16),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exerciseName,
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${muscleGroup.toUpperCase()} • $equipmentName',
                                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                                // 💡 ELEMENT EXCLUSIV: Afișăm numărul de seturi preconfigurat (ex: 4 SETS)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${routineExercise.targetSetsCount} SETS',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant, size: 18),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // --- BUTONUL MARE DE START WORKOUT ---
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ActiveWorkoutPage(routine: widget.routine),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow, size: 24),
                  label: const Text(
                    'Start Workout',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}